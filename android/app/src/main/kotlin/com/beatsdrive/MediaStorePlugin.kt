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
    private var isScanning = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.beatsdrive.media_store")
        context = flutterPluginBinding.applicationContext
        channel.setMethodCallHandler(this)
        
        // Register content observer for media changes
        contentObserver = object : ContentObserver(null) {
            override fun onChange(selfChange: Boolean) {
                super.onChange(selfChange)
                // Only notify if we're not already scanning
                if (!isScanning) {
                    channel.invokeMethod("onMediaStoreChanged", null)
                }
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
                if (isScanning) {
                    result.error("SCAN_IN_PROGRESS", "A scan is already in progress", null)
                    return
                }
                
                val columns = call.argument<List<String>>("columns")
                if (columns == null) {
                    result.error("INVALID_ARGUMENTS", "Columns list cannot be null", null)
                    return
                }
                
                isScanning = true
                try {
                    queryMusicFiles(columns, result)
                } finally {
                    isScanning = false
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun queryMusicFiles(columns: List<String>, result: Result) {
        try {
            val musicFiles = JSONArray()
            val projection = columns.toTypedArray()
            
            val selection = StringBuilder().apply {
                append("${MediaStore.Audio.Media.IS_MUSIC} != 0")
                // Filter out files shorter than 30 seconds
                append(" AND ${MediaStore.Audio.Media.DURATION} >= 30000")
                // Ensure the file exists and is not pending
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    append(" AND ${MediaStore.Audio.Media.IS_PENDING} = 0")
                }
                // Filter out files with invalid paths
                append(" AND ${MediaStore.Audio.Media.DATA} IS NOT NULL")
                append(" AND ${MediaStore.Audio.Media.DATA} != ''")
                // Filter out files that are not accessible
                append(" AND ${MediaStore.Audio.Media.IS_TRASHED} = 0")
            }.toString()
            
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
        val idIndex = cursor.getColumnIndex(MediaStore.Audio.Media._ID)
        val titleIndex = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
        val artistIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
        val albumIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
        val albumIdIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)
        val durationIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
        val trackIndex = cursor.getColumnIndex(MediaStore.Audio.Media.TRACK)
        val yearIndex = cursor.getColumnIndex(MediaStore.Audio.Media.YEAR)
        val dateAddedIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)
        val dataIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)

        while (cursor.moveToNext()) {
            val song = JSONObject().apply {
                put("_id", cursor.getLong(idIndex))
                put("title", cursor.getString(titleIndex))
                put("artist", cursor.getString(artistIndex))
                put("album", cursor.getString(albumIndex))
                put("album_id", cursor.getLong(albumIdIndex))
                put("duration", cursor.getLong(durationIndex))
                put("track", cursor.getInt(trackIndex))
                put("year", cursor.getInt(yearIndex))
                put("date_added", cursor.getLong(dateAddedIndex))
                put("_data", cursor.getString(dataIndex))
            }
            musicFiles.put(song)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        contentObserver?.let {
            context.contentResolver.unregisterContentObserver(it)
        }
    }
} 