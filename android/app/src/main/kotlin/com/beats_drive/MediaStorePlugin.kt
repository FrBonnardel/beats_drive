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
import android.util.Log

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
            "getTotalSongCount" -> {
                Thread {
                    try {
                        val count = getTotalSongCount()
                        result.success(count)
                    } catch (e: Exception) {
                        result.error("COUNT_ERROR", "Failed to get total song count: ${e.message}", null)
                    }
                }.start()
            }
            "getSongMetadata" -> {
                Thread {
                    try {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("INVALID_URI", "URI is required", null)
                            return@Thread
                        }

                        val metadata = getSongMetadata(uri)
                        if (metadata != null) {
                            result.success(metadata)
                        } else {
                            result.error("METADATA_ERROR", "Could not find song metadata", null)
                        }
                    } catch (e: Exception) {
                        result.error("METADATA_ERROR", "Failed to get song metadata: ${e.message}", null)
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
                            result.error("ALBUM_ID_ERROR", "Could not find album ID", null)
                            return@Thread
                        }

                        val albumArt = getAlbumArt(albumId)
                        if (albumArt != null) {
                            result.success(albumArt)
                        } else {
                            result.error("ALBUM_ART_ERROR", "Could not find album art", null)
                        }
                    } catch (e: Exception) {
                        result.error("ALBUM_ART_ERROR", e.message, null)
                    }
                }.start()
            }
            "getSongsMetadata" -> {
                Thread {
                    try {
                        val uris = call.argument<List<String>>("uris")
                        if (uris == null) {
                            result.error("INVALID_URIS", "URIs list is required", null)
                            return@Thread
                        }

                        val metadataList = uris.map { uri ->
                            try {
                                getSongMetadata(uri)
                            } catch (e: Exception) {
                                Log.d("MediaStorePlugin", "Failed to get metadata for URI: $uri, error: ${e.message}")
                                null
                            }
                        }
                        result.success(metadataList)
                    } catch (e: Exception) {
                        result.error("METADATA_ERROR", "Failed to get songs metadata: ${e.message}", null)
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
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.DATA
        )

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

        val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

        try {
            Log.d("MediaStorePlugin", "Starting music files query with selection: $selection")
            
            // Query external storage
            val externalCursor = contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                null,
                sortOrder
            )

            if (externalCursor != null) {
                Log.d("MediaStorePlugin", "Found ${externalCursor.count} music files in external storage")
                processCursor(externalCursor, musicFiles)
            } else {
                Log.w("MediaStorePlugin", "External storage cursor is null")
            }

            // Query internal storage for Android 10 and above
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val internalCursor = contentResolver.query(
                    MediaStore.Audio.Media.INTERNAL_CONTENT_URI,
                    projection,
                    selection,
                    null,
                    sortOrder
                )

                if (internalCursor != null) {
                    Log.d("MediaStorePlugin", "Found ${internalCursor.count} music files in internal storage")
                    processCursor(internalCursor, musicFiles)
                } else {
                    Log.w("MediaStorePlugin", "Internal storage cursor is null")
                }
            }

            Log.d("MediaStorePlugin", "Total music files found: ${musicFiles.size}")
            return musicFiles
        } catch (e: Exception) {
            Log.e("MediaStorePlugin", "Error querying music files: ${e.message}")
            Log.e("MediaStorePlugin", "Stack trace: ${e.stackTraceToString()}")
            return emptyList()
        }
    }

    private fun processCursor(cursor: Cursor, musicFiles: MutableList<Map<String, Any?>>) {
        cursor.use {
            while (cursor.moveToNext()) {
                try {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID))
                    val albumId = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID))
                    val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                    val albumArtUri = ContentUris.withAppendedId(Uri.parse("content://media/external/audio/albumart"), albumId)
                    val data = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA))

                    // Verify the file exists and is accessible
                    try {
                        contentResolver.openFileDescriptor(contentUri, "r")?.close()
                    } catch (e: Exception) {
                        continue // Skip this file if it's not accessible
                    }

                    // Get raw values first
                    val rawTitle = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE))
                    val rawArtist = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST))
                    val rawAlbum = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM))

                    val song = mapOf(
                        "_id" to id,
                        "title" to (rawTitle ?: "Unknown Title"),
                        "artist" to (rawArtist ?: "Unknown Artist"),
                        "album" to (rawAlbum ?: "Unknown Album"),
                        "album_id" to albumId,
                        "duration" to cursor.getLongOrDefault(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)),
                        "track" to cursor.getIntOrDefault(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)),
                        "year" to cursor.getIntOrDefault(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)),
                        "date_added" to cursor.getLongOrDefault(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)),
                        "_data" to data,
                        "album_art_uri" to albumArtUri.toString()
                    )

                    musicFiles.add(song)
                } catch (e: Exception) {
                    continue // Skip this song if there's an error
                }
            }
        }
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
            val value = getString(columnIndex)
            if (value == null || value.trim().isEmpty()) {
                Log.d("MediaStorePlugin", "Empty or null value for column index $columnIndex")
                default
            } else {
                value
            }
        } catch (e: Exception) {
            Log.e("MediaStorePlugin", "Error getting string for column index $columnIndex: ${e.message}")
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

    private fun getSongMetadata(uri: String): Map<String, Any>? {
        val songUri = Uri.parse(uri)
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.YEAR
        )

        contentResolver.query(
            songUri,
            projection,
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return mapOf(
                    "id" to cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)),
                    "title" to (cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)) ?: ""),
                    "artist" to (cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)) ?: ""),
                    "album" to (cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)) ?: ""),
                    "duration" to cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)),
                    "dateAdded" to cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)),
                    "dateModified" to cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)),
                    "albumId" to cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)),
                    "trackNumber" to cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)),
                    "year" to cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)),
                    "uri" to uri
                )
            }
        }
        return null
    }

    private fun getAlbumArt(albumId: String): ByteArray? {
        val albumArtUri = getAlbumArtUri(albumId)
        return try {
            contentResolver.openInputStream(albumArtUri)?.use { inputStream ->
                val bitmap = BitmapFactory.decodeStream(inputStream)
                if (bitmap != null) {
                    ByteArrayOutputStream().use { stream ->
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                        stream.toByteArray()
                    }
                } else null
            }
        } catch (e: IOException) {
            null
        }
    }

    private fun getTotalSongCount(): Int {
        val selection = StringBuilder().apply {
            append("${MediaStore.Audio.Media.IS_MUSIC} != 0")
            append(" AND ${MediaStore.Audio.Media.DURATION} >= 30000")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                append(" AND ${MediaStore.Audio.Media.IS_PENDING} = 0")
            }
            append(" AND ${MediaStore.Audio.Media.DATA} IS NOT NULL")
            append(" AND ${MediaStore.Audio.Media.DATA} != ''")
        }.toString()

        var totalCount = 0

        // Count external storage
        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.Audio.Media._ID),
            selection,
            null,
            null
        )?.use { cursor ->
            totalCount += cursor.count
        }

        // Count internal storage for Android 10 and above
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            contentResolver.query(
                MediaStore.Audio.Media.INTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Audio.Media._ID),
                selection,
                null,
                null
            )?.use { cursor ->
                totalCount += cursor.count
            }
        }

        return totalCount
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
} 