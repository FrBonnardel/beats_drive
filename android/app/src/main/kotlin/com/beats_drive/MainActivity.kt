package com.beats_drive

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private lateinit var mediaNotificationService: MediaNotificationService
    private val CHANNEL = "com.beats_drive/media_notification"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mediaNotificationService = MediaNotificationService(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: ""
                    val author = call.argument<String>("author") ?: ""
                    val image = call.argument<ByteArray>("image")
                    val play = call.argument<Boolean>("play") ?: true
                    mediaNotificationService.showNotification(title, author, image, play)
                    result.success(null)
                }
                "hideNotification" -> {
                    mediaNotificationService.hideNotification()
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