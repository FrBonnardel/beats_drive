package com.beats_drive

import android.content.ContentResolver
import android.content.ContentUris
import android.database.Cursor
import android.net.Uri
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream
import java.io.IOException

class MediaStorePlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var contentResolver: ContentResolver
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.beats_drive/media_store")
        channel.setMethodCallHandler(this)
        contentResolver = flutterPluginBinding.applicationContext.contentResolver
        context = flutterPluginBinding.applicationContext
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
            "getMusicFiles" -> {
                Thread {
                    try {
                        val musicFiles = queryMusicFiles()
                        result.success(musicFiles)
                    } catch (e: Exception) {
                        result.error("MEDIA_STORE_ERROR", e.message, null)
                    }
                }.start()
            }
            "getAlbumArtUri" -> {
                Thread {
                    try {
                        val albumId = call.argument<String>("albumId")
                        if (albumId != null) {
                            val uri = getAlbumArtUri(albumId)
                            result.success(uri?.toString())
                        } else {
                            result.error("INVALID_ALBUM_ID", "Album ID is required", null)
                        }
                    } catch (e: Exception) {
                        result.error("ALBUM_ART_ERROR", e.message, null)
                    }
                }.start()
            }
            "getAlbumId" -> {
                Thread {
                    try {
                        val filePath = call.argument<String>("filePath")
                        if (filePath != null) {
                            val albumId = getAlbumId(filePath)
                            result.success(albumId?.toString())
                        } else {
                            result.error("INVALID_FILE_PATH", "File path is required", null)
                        }
                    } catch (e: Exception) {
                        result.error("ALBUM_ID_ERROR", e.message, null)
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    private fun queryMusicFiles(columns: List<String>, result: Result) {
        try {
            val musicFiles = mutableListOf<Map<String, Any>>()
            
            val projection = arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.ALBUM,
                MediaStore.Audio.Media.DURATION,
                MediaStore.Audio.Media.DATA,
                MediaStore.Audio.Media.DATE_ADDED,
                MediaStore.Audio.Media.DATE_MODIFIED,
                MediaStore.Audio.Media.SIZE,
                MediaStore.Audio.Media.MIME_TYPE
            )
            
            val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
            val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"
            
            val cursor: Cursor? = contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                null,
                sortOrder
            )

            cursor?.use {
                val idColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val durationColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val dataColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                val dateAddedColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
                val dateModifiedColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
                val sizeColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val mimeTypeColumn = it.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)

                while (it.moveToNext()) {
                    val id = it.getLong(idColumn)
                    val contentUri = ContentUris.withAppendedId(
                        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                        id
                    )

                    val musicFile = mapOf(
                        "_id" to id.toString(),
                        "title" to (it.getString(titleColumn) ?: ""),
                        "artist" to (it.getString(artistColumn) ?: ""),
                        "album" to (it.getString(albumColumn) ?: ""),
                        "duration" to it.getLong(durationColumn),
                        "data" to (it.getString(dataColumn) ?: ""),
                        "date_added" to it.getLong(dateAddedColumn),
                        "date_modified" to it.getLong(dateModifiedColumn),
                        "size" to it.getLong(sizeColumn),
                        "mime_type" to (it.getString(mimeTypeColumn) ?: ""),
                        "uri" to contentUri.toString()
                    )
                    musicFiles.add(musicFile)
                }
            }

            result.success(musicFiles)
        } catch (e: Exception) {
            result.error("QUERY_ERROR", e.message, null)
        }
    }

    private fun queryMusicFiles(): List<Map<String, Any>> {
        val musicFiles = mutableListOf<Map<String, Any>>()
        val contentResolver: ContentResolver = context.contentResolver
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.ALBUM_ID
        )

        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val sortOrder = "${MediaStore.Audio.Media.DATE_ADDED} DESC"

        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            null,
            sortOrder
        )?.use { cursor ->
            val idColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media._ID)
            val titleColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
            val artistColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
            val albumColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
            val durationColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
            val dataColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
            val dateAddedColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)
            val dateModifiedColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_MODIFIED)
            val sizeColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
            val mimeTypeColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.MIME_TYPE)
            val albumIdColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumnIndex)
                val title = cursor.getString(titleColumnIndex) ?: "Unknown Title"
                val artist = cursor.getString(artistColumnIndex) ?: "Unknown Artist"
                val album = cursor.getString(albumColumnIndex) ?: "Unknown Album"
                val duration = cursor.getLong(durationColumnIndex)
                val data = cursor.getString(dataColumnIndex) ?: ""
                val dateAdded = cursor.getLong(dateAddedColumnIndex)
                val dateModified = cursor.getLong(dateModifiedColumnIndex)
                val size = cursor.getLong(sizeColumnIndex)
                val mimeType = cursor.getString(mimeTypeColumnIndex) ?: "audio/mpeg"
                val albumId = cursor.getLong(albumIdColumnIndex)

                val fileInfo = mapOf(
                    "_id" to id,
                    "title" to title,
                    "artist" to artist,
                    "album" to album,
                    "duration" to duration,
                    "path" to data,
                    "dateAdded" to dateAdded,
                    "dateModified" to dateModified,
                    "size" to size,
                    "mimeType" to mimeType,
                    "albumId" to albumId
                )
                musicFiles.add(fileInfo)
            }
        }
        return musicFiles
    }

    private fun getAlbumArtUri(albumId: String): Uri? {
        val contentResolver: ContentResolver = context.contentResolver
        val albumUri = MediaStore.Audio.Albums.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.Audio.Albums.ALBUM_ART)
        val selection = "${MediaStore.Audio.Albums._ID} = ?"
        val selectionArgs = arrayOf(albumId)

        contentResolver.query(
            albumUri,
            projection,
            selection,
            selectionArgs,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val albumArtColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Albums.ALBUM_ART)
                if (albumArtColumnIndex != -1) {
                    val albumArtPath = cursor.getString(albumArtColumnIndex)
                    if (albumArtPath != null) {
                        return Uri.parse(albumArtPath)
                    }
                }
            }
        }
        return null
    }

    private fun getAlbumId(filePath: String): Long? {
        val contentResolver: ContentResolver = context.contentResolver
        val projection = arrayOf(MediaStore.Audio.Media.ALBUM_ID)
        val selection = "${MediaStore.Audio.Media.DATA} = ?"
        val selectionArgs = arrayOf(filePath)

        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val albumIdColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)
                if (albumIdColumnIndex != -1) {
                    return cursor.getLong(albumIdColumnIndex)
                }
            }
        }
        return null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
} 