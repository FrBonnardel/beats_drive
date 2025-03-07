package com.beats_drive

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MediaNotificationService : Service() {
    private lateinit var notificationManager: NotificationManager
    private lateinit var mediaSession: MediaSessionCompat
    private var currentNotification: Notification? = null
    private var currentTitle: String = ""
    private var currentAuthor: String = ""
    private var currentImage: ByteArray? = null
    private var isPlaying: Boolean = false
    private var flutterEngine: FlutterEngine? = null

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        mediaSession = MediaSessionCompat(this, "BeatsDriveMediaSession")
        createNotificationChannel()
        setupMediaSession()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Media Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Media playback controls"
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun setupMediaSession() {
        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() {
                super.onPlay()
                isPlaying = true
                updateNotification()
                sendCommandToFlutter(ACTION_PLAY)
            }

            override fun onPause() {
                super.onPause()
                isPlaying = false
                updateNotification()
                sendCommandToFlutter(ACTION_PAUSE)
            }

            override fun onSkipToNext() {
                super.onSkipToNext()
                sendCommandToFlutter(ACTION_NEXT)
            }

            override fun onSkipToPrevious() {
                super.onSkipToPrevious()
                sendCommandToFlutter(ACTION_PREVIOUS)
            }

            override fun onStop() {
                super.onStop()
                isPlaying = false
                updateNotification()
            }
        })
    }

    private fun sendCommandToFlutter(action: String) {
        flutterEngine?.let { engine ->
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                when (action) {
                    ACTION_PLAY -> "onPlay"
                    ACTION_PAUSE -> "onPause"
                    ACTION_NEXT -> "onNext"
                    ACTION_PREVIOUS -> "onPrevious"
                    else -> "unknown"
                },
                null
            )
        }
    }

    fun showNotification(title: String, author: String, image: ByteArray?, play: Boolean) {
        currentTitle = title
        currentAuthor = author
        currentImage = image
        isPlaying = play
        updateNotification()
    }

    private fun updateNotification() {
        val notification = createNotification()
        currentNotification = notification
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun createNotification(): Notification {
        // Create intent to open the app
        val contentIntent = Intent(this, FlutterActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Create service intents for media controls
        val playPauseIntent = Intent(this, MediaNotificationService::class.java).apply {
            action = if (isPlaying) ACTION_PAUSE else ACTION_PLAY
        }
        val playPausePendingIntent = PendingIntent.getService(
            this,
            1,
            playPauseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val nextIntent = Intent(this, MediaNotificationService::class.java).apply {
            action = ACTION_NEXT
        }
        val nextPendingIntent = PendingIntent.getService(
            this,
            2,
            nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val previousIntent = Intent(this, MediaNotificationService::class.java).apply {
            action = ACTION_PREVIOUS
        }
        val previousPendingIntent = PendingIntent.getService(
            this,
            3,
            previousIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(currentTitle)
            .setContentText(currentAuthor)
            .setContentIntent(contentPendingIntent)
            .setStyle(MediaStyle()
                .setMediaSession(mediaSession.sessionToken)
                .setShowActionsInCompactView(0, 1, 2))
            .addAction(android.R.drawable.ic_media_previous, "Previous", previousPendingIntent)
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "Pause" else "Play",
                playPausePendingIntent
            )
            .addAction(android.R.drawable.ic_media_next, "Next", nextPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)

        currentImage?.let { imageData ->
            val bitmap = BitmapFactory.decodeByteArray(imageData, 0, imageData.size)
            builder.setLargeIcon(bitmap)
        }

        return builder.build()
    }

    fun hideNotification() {
        notificationManager.cancel(NOTIFICATION_ID)
        currentNotification = null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "SHOW_NOTIFICATION" -> {
                val title = intent.getStringExtra("title") ?: ""
                val author = intent.getStringExtra("author") ?: ""
                val image = intent.getByteArrayExtra("image")
                val play = intent.getBooleanExtra("play", true)
                val engineId = intent.getStringExtra("flutterEngineId")
                if (engineId != null) {
                    flutterEngine = FlutterEngineCache.getInstance().get(engineId)
                }
                showNotification(title, author, image, play)
            }
            "HIDE_NOTIFICATION" -> {
                hideNotification()
            }
            ACTION_PLAY -> mediaSession.controller.transportControls.play()
            ACTION_PAUSE -> mediaSession.controller.transportControls.pause()
            ACTION_NEXT -> mediaSession.controller.transportControls.skipToNext()
            ACTION_PREVIOUS -> mediaSession.controller.transportControls.skipToPrevious()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        mediaSession.release()
    }

    companion object {
        private const val CHANNEL_ID = "media_playback_channel"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL = "com.beats_drive/media_notification"

        const val ACTION_PLAY = "com.beats_drive.PLAY"
        const val ACTION_PAUSE = "com.beats_drive.PAUSE"
        const val ACTION_NEXT = "com.beats_drive.NEXT"
        const val ACTION_PREVIOUS = "com.beats_drive.PREVIOUS"
    }
} 