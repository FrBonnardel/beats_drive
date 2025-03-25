package com.beats_drive

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import com.beats_drive.MediaStorePlugin
import androidx.annotation.NonNull

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.beats_drive/media_notification"
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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

                    val intent = Intent(this, MediaNotificationService::class.java).apply {
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
                    val intent = Intent(this, MediaNotificationService::class.java).apply {
                        action = "HIDE_NOTIFICATION"
                    }
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("MainActivity", "onNewIntent called with action: ${intent.action}")
        setIntent(intent)  // Update the intent with the new one
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        Log.d("MainActivity", "Handling intent with action: ${intent?.action}")
        when (intent?.action) {
            MediaNotificationService.ACTION_PLAY -> {
                Log.d("MainActivity", "Handling PLAY action")
                channel.invokeMethod("onPlay", null)
            }
            MediaNotificationService.ACTION_PAUSE -> {
                Log.d("MainActivity", "Handling PAUSE action")
                channel.invokeMethod("onPause", null)
            }
            MediaNotificationService.ACTION_NEXT -> {
                Log.d("MainActivity", "Handling NEXT action")
                channel.invokeMethod("onNext", null)
            }
            MediaNotificationService.ACTION_PREVIOUS -> {
                Log.d("MainActivity", "Handling PREVIOUS action")
                channel.invokeMethod("onPrevious", null)
            }
            MediaNotificationService.ACTION_NOTIFICATION_CLICK -> {
                Log.d("MainActivity", "Notification click detected, invoking method channel")
                channel.invokeMethod("onNotificationClick", null)
            }
            else -> {
                Log.d("MainActivity", "No specific action to handle")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "onCreate called with intent action: ${intent?.action}")
        handleIntent(intent)
    }
} 