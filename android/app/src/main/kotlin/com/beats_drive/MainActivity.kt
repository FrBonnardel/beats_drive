package com.beats_drive

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import com.beats_drive.MediaStorePlugin

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.beats_drive/media_notification"
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Cache the FlutterEngine for use by the service
        FlutterEngineCache.getInstance().put("main_engine", flutterEngine)

        // Register MediaStorePlugin
        flutterEngine.plugins.add(MediaStorePlugin())

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: ""
                    val author = call.argument<String>("author") ?: ""
                    val image = call.argument<ByteArray>("image")
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
        when (intent.action) {
            MediaNotificationService.ACTION_PLAY -> {
                methodChannel.invokeMethod("onPlay", null)
            }
            MediaNotificationService.ACTION_PAUSE -> {
                methodChannel.invokeMethod("onPause", null)
            }
            MediaNotificationService.ACTION_NEXT -> {
                methodChannel.invokeMethod("onNext", null)
            }
            MediaNotificationService.ACTION_PREVIOUS -> {
                methodChannel.invokeMethod("onPrevious", null)
            }
        }
    }
} 