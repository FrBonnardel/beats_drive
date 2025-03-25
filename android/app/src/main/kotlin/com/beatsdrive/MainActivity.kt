package com.beatsdrive

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull

class MainActivity: FlutterActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.beats_drive/media_notification"
    private lateinit var channel: MethodChannel

    companion object {
        const val ACTION_PLAY = "com.beats_drive.PLAY"
        const val ACTION_PAUSE = "com.beats_drive.PAUSE"
        const val ACTION_NEXT = "com.beats_drive.NEXT"
        const val ACTION_PREVIOUS = "com.beats_drive.PREVIOUS"
        const val ACTION_NOTIFICATION_CLICK = "com.beats_drive.NOTIFICATION_CLICK"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "Configuring Flutter Engine")
        
        // Cache the FlutterEngine for use by the service
        FlutterEngineCache.getInstance().put("main_engine", flutterEngine)

        // Register MediaStorePlugin
        flutterEngine.plugins.add(MediaStorePlugin())

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: ""
                    val author = call.argument<String>("author") ?: ""
                    val imageList = call.argument<List<Int>>("image")
                    val image = imageList?.map { it.toByte() }?.toByteArray()
                    val play = call.argument<Boolean>("play") ?: true

                    val intent = Intent(this, Class.forName("com.beatsdrive.MediaNotificationService")).apply {
                        action = "SHOW_NOTIFICATION"
                        putExtra("title", title)
                        putExtra("author", author)
                        putExtra("image", image)
                        putExtra("play", play)
                        putExtra("flutterEngineId", "main_engine")
                    }
                    startService(intent)
                    result.success(null)
                }
                "hideNotification" -> {
                    val intent = Intent(this, Class.forName("com.beatsdrive.MediaNotificationService")).apply {
                        action = "HIDE_NOTIFICATION"
                    }
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate called with intent action: ${intent.action}")
        handleIntent(intent)
    }

    override fun onStart() {
        super.onStart()
        Log.d(TAG, "onStart: Activity started")
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume: Activity resumed")
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause: Activity paused")
    }

    override fun onStop() {
        super.onStop()
        Log.d(TAG, "onStop: Activity stopped")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy: Activity destroyed")
    }

    override fun onRestart() {
        super.onRestart()
        Log.d(TAG, "onRestart: Activity restarted")
    }

    override fun onNewIntent(@NonNull intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent called with action: ${intent.action}")
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        Log.d(TAG, "Handling intent with action: ${intent.action}")
        when (intent.action) {
            ACTION_PLAY -> {
                Log.d(TAG, "Received PLAY action")
                channel.invokeMethod("onPlay", null)
            }
            ACTION_PAUSE -> {
                Log.d(TAG, "Received PAUSE action")
                channel.invokeMethod("onPause", null)
            }
            ACTION_NEXT -> {
                Log.d(TAG, "Received NEXT action")
                channel.invokeMethod("onNext", null)
            }
            ACTION_PREVIOUS -> {
                Log.d(TAG, "Received PREVIOUS action")
                channel.invokeMethod("onPrevious", null)
            }
            ACTION_NOTIFICATION_CLICK -> {
                Log.d(TAG, "Received NOTIFICATION_CLICK action")
                // Ensure the activity is brought to front
                moveTaskToFront()
                channel.invokeMethod("onNotificationClick", null)
            }
            else -> {
                Log.d(TAG, "Received unknown action: ${intent.action}")
            }
        }
    }

    private fun moveTaskToFront() {
        try {
            // Get the task that contains this activity
            val activityManager = getSystemService(ACTIVITY_SERVICE)
            val tasks = activityManager?.javaClass?.getMethod("getAppTasks")?.invoke(activityManager) as? List<*>
            tasks?.firstOrNull()?.javaClass?.getMethod("moveToFront")?.invoke(tasks.firstOrNull())
            Log.d(TAG, "Successfully moved task to front")
        } catch (e: Exception) {
            Log.e(TAG, "Error moving task to front: ${e.message}")
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        Log.d(TAG, "onSaveInstanceState: Saving instance state")
    }

    override fun onRestoreInstanceState(savedInstanceState: Bundle) {
        super.onRestoreInstanceState(savedInstanceState)
        Log.d(TAG, "onRestoreInstanceState: Restoring instance state")
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        Log.d(TAG, "onWindowFocusChanged: Window focus changed to $hasFocus")
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        Log.d(TAG, "onUserLeaveHint: User left the app")
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        Log.d(TAG, "onTrimMemory: Memory trim level $level")
    }

    override fun onLowMemory() {
        super.onLowMemory()
        Log.d(TAG, "onLowMemory: System is running low on memory")
    }
} 