package com.beatsdrive

import android.content.ContentResolver
import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray
import org.json.JSONObject

class MediaStorePlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var contentObserver: ContentObserver? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.beatsdrive.media_store")
        context = flutterPluginBinding.applicationContext
        channel.setMethodCallHandler(this)
        
        // Register content observer for media changes
        contentObserver = object : ContentObserver(null) {
            override fun onChange(selfChange: Boolean) {
                super.onChange(selfChange)
                // Notify Flutter about media changes
                channel.invokeMethod("onMediaStoreChanged", null)
            }
        }
        
        // Register observer for both internal and external storage
        context.contentResolver.registerContentObserver(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            true,
            contentObserver!!
        )
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            context.contentResolver.registerContentObserver(
                MediaStore.Audio.Media.INTERNAL_CONTENT_URI,
                true,
                contentObserver!!
            )
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "queryMusicFiles" -> {
                val columns = call.argument<List<String>>("columns")
                if (columns == null) {
                    result.error("INVALID_ARGUMENTS", "Columns list cannot be null", null)
                    return
                }
                queryMusicFiles(columns, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun queryMusicFiles(columns: List<String>, result: Result) {
        try {
            val musicFiles = JSONArray()
            val projection = columns.toTypedArray()
            
            val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
            val sortOrder = "${MediaStore.Audio.Media.DATE_ADDED} DESC"
            
            // Query external storage
            context.contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                null,
                sortOrder
            )?.use { cursor ->
                processCursor(cursor, musicFiles)
            }
            
            // Query internal storage for Android 10 and above
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                context.contentResolver.query(
                    MediaStore.Audio.Media.INTERNAL_CONTENT_URI,
                    projection,
                    selection,
                    null,
                    sortOrder
                )?.use { cursor ->
                    processCursor(cursor, musicFiles)
                }
            }
            
            result.success(musicFiles.toString())
        } catch (e: Exception) {
            result.error("QUERY_ERROR", e.message, null)
        }
    }

    private fun processCursor(cursor: android.database.Cursor, musicFiles: JSONArray) {
        val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
        val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
        val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
        val albumColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
        val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
        val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
        val dateAddedColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
        val dateModifiedColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
        val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
        val mimeTypeColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)

        while (cursor.moveToNext()) {
            val file = JSONObject().apply {
                put("_id", cursor.getLong(idColumn))
                put("title", cursor.getString(titleColumn))
                put("artist", cursor.getString(artistColumn))
                put("album", cursor.getString(albumColumn))
                put("duration", cursor.getLong(durationColumn))
                put("data", cursor.getString(dataColumn))
                put("date_added", cursor.getLong(dateAddedColumn))
                put("date_modified", cursor.getLong(dateModifiedColumn))
                put("size", cursor.getLong(sizeColumn))
                put("mime_type", cursor.getString(mimeTypeColumn))
            }
            musicFiles.put(file)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        contentObserver?.let {
            context.contentResolver.unregisterContentObserver(it)
        }
    }
} 