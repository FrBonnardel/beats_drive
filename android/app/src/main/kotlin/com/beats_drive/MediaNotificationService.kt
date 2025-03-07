package com.beats_drive

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MediaNotificationService(private val context: Context) {
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val mediaSession = MediaSessionCompat(context, "BeatsDriveMediaSession")
    private var currentNotification: Notification? = null
    private var currentTitle: String = ""
    private var currentAuthor: String = ""
    private var currentImage: ByteArray? = null
    private var isPlaying: Boolean = false

    init {
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
            }

            override fun onPause() {
                super.onPause()
                isPlaying = false
                updateNotification()
            }

            override fun onSkipToNext() {
                super.onSkipToNext()
                // Handle next track
            }

            override fun onSkipToPrevious() {
                super.onSkipToPrevious()
                // Handle previous track
            }

            override fun onStop() {
                super.onStop()
                isPlaying = false
                updateNotification()
            }
        })
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
        val playPauseIntent = Intent(context, FlutterActivity::class.java).apply {
            action = if (isPlaying) ACTION_PAUSE else ACTION_PLAY
        }
        val playPausePendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            playPauseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val nextIntent = Intent(context, FlutterActivity::class.java).apply {
            action = ACTION_NEXT
        }
        val nextPendingIntent = PendingIntent.getBroadcast(
            context,
            1,
            nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val previousIntent = Intent(context, FlutterActivity::class.java).apply {
            action = ACTION_PREVIOUS
        }
        val previousPendingIntent = PendingIntent.getBroadcast(
            context,
            2,
            previousIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(currentTitle)
            .setContentText(currentAuthor)
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

    companion object {
        private const val CHANNEL_ID = "media_playback_channel"
        private const val NOTIFICATION_ID = 1

        const val ACTION_PLAY = "com.beats_drive.PLAY"
        const val ACTION_PAUSE = "com.beats_drive.PAUSE"
        const val ACTION_NEXT = "com.beats_drive.NEXT"
        const val ACTION_PREVIOUS = "com.beats_drive.PREVIOUS"
    }
} 