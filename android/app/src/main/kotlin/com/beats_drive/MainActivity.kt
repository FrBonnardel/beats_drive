package com.beats_drive

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.beats_drive/media_notification"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)
        
        // Register MediaStorePlugin
        flutterEngine.plugins.add(MediaStorePlugin())
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                        putExtra("flutterEngineId", "my_engine_id")
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
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        when (intent.action) {
            MediaNotificationService.ACTION_PLAY -> {
                MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, CHANNEL)
                    .invokeMethod("onPlay", null)
            }
            MediaNotificationService.ACTION_PAUSE -> {
                MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, CHANNEL)
                    .invokeMethod("onPause", null)
            }
            MediaNotificationService.ACTION_NEXT -> {
                MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, CHANNEL)
                    .invokeMethod("onNext", null)
            }
            MediaNotificationService.ACTION_PREVIOUS -> {
                MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, CHANNEL)
                    .invokeMethod("onPrevious", null)
            }
        }
    }
} 