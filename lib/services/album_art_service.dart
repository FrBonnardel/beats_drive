import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

class AlbumArtService {
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();
  static const String _cacheKeyPrefix = 'album_art_';
  static const Duration _cacheDuration = Duration(days: 7);

  static Future<String?> getAlbumArtUri(String albumId) async {
    try {
      final result = await const MethodChannel('com.beats_drive/media_store')
          .invokeMethod('getAlbumArtUri', {'albumId': albumId});
      return result as String?;
    } catch (e) {
      debugPrint('Error getting album art URI: $e');
      return null;
    }
  }

  static Future<Uint8List?> getAlbumArt(String albumId) async {
    try {
      // Check cache first
      final cacheKey = _cacheKeyPrefix + albumId;
      final file = await _cacheManager.getFileFromCache(cacheKey);
      
      if (file != null) {
        return await file.file.readAsBytes();
      }

      // Get URI from MediaStore
      final uri = await getAlbumArtUri(albumId);
      if (uri == null) return null;

      // Download and cache the image
      final response = await http.get(Uri.parse(uri));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await _cacheManager.putFile(
          cacheKey,
          bytes,
          maxAge: _cacheDuration,
        );
        return bytes;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting album art: $e');
      return null;
    }
  }

  static Future<void> clearCache() async {
    try {
      await _cacheManager.emptyCache();
    } catch (e) {
      debugPrint('Error clearing album art cache: $e');
    }
  }
} 