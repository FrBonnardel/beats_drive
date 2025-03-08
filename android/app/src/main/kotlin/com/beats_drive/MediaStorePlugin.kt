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
import android.os.Build
import android.os.ParcelFileDescriptor
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
                Thread {
                    try {
                        val musicFiles = queryMusicFiles()
                        result.success(musicFiles)
                    } catch (e: Exception) {
                        result.error("QUERY_ERROR", "Failed to query music files: ${e.message}", null)
                    }
                }.start()
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
            "getAlbumId" -> {
                Thread {
                    try {
                        val songId = call.argument<String>("songId")
                        if (songId != null) {
                            val albumId = getAlbumId(songId)
                            result.success(albumId)
                        } else {
                            result.error("INVALID_SONG_ID", "Song ID is required", null)
                        }
                    } catch (e: Exception) {
                        result.error("ALBUM_ID_ERROR", e.message, null)
                    }
                }.start()
            }
            "getAlbumArt" -> {
                Thread {
                    try {
                        val songId = call.argument<String>("songId")
                        if (songId == null) {
                            result.error("INVALID_SONG_ID", "Song ID is required", null)
                            return@Thread
                        }
                        
                        val albumId = getAlbumId(songId)
                        if (albumId == null) {
                            result.success(null)
                            return@Thread
                        }

                        try {
                            val albumArtUri = getAlbumArtUri(albumId)
                            contentResolver.openInputStream(albumArtUri)?.use { inputStream ->
                                val bitmap = BitmapFactory.decodeStream(inputStream)
                                if (bitmap != null) {
                                    ByteArrayOutputStream().use { stream ->
                                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                                        result.success(stream.toByteArray())
                                        return@Thread
                                    }
                                }
                            }
                            result.success(null)
                        } catch (e: IOException) {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.error("ALBUM_ART_ERROR", "Failed to get album art: ${e.message}", null)
                    }
                }.start()
            }
            "openFile" -> {
                Thread {
                    try {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("INVALID_URI", "URI is required", null)
                            return@Thread
                        }

                        try {
                            val contentUri = Uri.parse(uri)
                            val fd = contentResolver.openFileDescriptor(contentUri, "r")
                            if (fd != null) {
                                result.success(fd.detachFd())
                            } else {
                                result.error("FILE_ERROR", "Could not open file descriptor", null)
                            }
                        } catch (e: Exception) {
                            result.error("FILE_ERROR", "Failed to open file: ${e.message}", null)
                        }
                    } catch (e: Exception) {
                        result.error("FILE_ERROR", "Failed to process file: ${e.message}", null)
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    private fun queryMusicFiles(): List<Map<String, Any?>> {
        val musicFiles = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.YEAR,
            MediaStore.Audio.Media.DATE_ADDED
        )

        val selection = StringBuilder().apply {
            append("${MediaStore.Audio.Media.IS_MUSIC} != 0")
            // Filter out files shorter than 30 seconds
            append(" AND ${MediaStore.Audio.Media.DURATION} >= 30000")
            // Ensure the file exists and is not pending
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                append(" AND ${MediaStore.Audio.Media.IS_PENDING} = 0")
            }
        }.toString()

        val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

        return contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            null,
            sortOrder
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                try {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID))
                    val albumId = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID))
                    val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                    val albumArtUri = ContentUris.withAppendedId(Uri.parse("content://media/external/audio/albumart"), albumId)

                    // Verify the file exists and is accessible
                    try {
                        contentResolver.openFileDescriptor(contentUri, "r")?.close()
                    } catch (e: Exception) {
                        continue // Skip this file if it's not accessible
                    }

                    musicFiles.add(mapOf(
                        "_id" to id.toString(),
                        "title" to cursor.getStringOrDefault(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)),
                        "artist" to cursor.getStringOrDefault(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)),
                        "album" to cursor.getStringOrDefault(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)),
                        "album_id" to albumId.toString(),
                        "duration" to cursor.getIntOrDefault(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)),
                        "uri" to contentUri.toString(),
                        "track" to cursor.getIntOrDefault(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)),
                        "year" to cursor.getIntOrDefault(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)),
                        "date_added" to cursor.getLongOrDefault(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)),
                        "album_art_uri" to albumArtUri.toString()
                    ))
                } catch (e: Exception) {
                    // Skip this entry if there's an error
                    continue
                }
            }
            musicFiles
        } ?: emptyList()
    }

    private fun getAlbumId(songId: String): String? {
        return contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.Audio.Media.ALBUM_ID),
            "${MediaStore.Audio.Media._ID} = ?",
            arrayOf(songId),
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)).toString()
            } else null
        }
    }

    private fun getAlbumArtUri(albumId: String): Uri {
        return ContentUris.withAppendedId(Uri.parse("content://media/external/audio/albumart"), albumId.toLong())
    }

    private fun Cursor.getStringOrDefault(columnIndex: Int, default: String = ""): String {
        return try {
            getString(columnIndex) ?: default
        } catch (e: Exception) {
            default
        }
    }

    private fun Cursor.getIntOrDefault(columnIndex: Int, default: Int = 0): Int {
        return try {
            getInt(columnIndex)
        } catch (e: Exception) {
            default
        }
    }

    private fun Cursor.getLongOrDefault(columnIndex: Int, default: Long = 0): Long {
        return try {
            getLong(columnIndex)
        } catch (e: Exception) {
            default
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
} 