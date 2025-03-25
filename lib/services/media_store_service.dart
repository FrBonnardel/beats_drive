import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaStoreService {
  static const platform = MethodChannel('com.beats_drive/media_store');
  static const String _cacheFileName = 'music_cache.json';
  static const String _lastUpdateKey = 'last_media_store_update';
  static const String _lastScanKey = 'last_scan_time';
  static const Duration _cacheValidityDuration = Duration(minutes: 5);
  static const Duration _scanInterval = Duration(hours: 1);
  
  // MediaStore columns we want to query
  static const List<String> _columns = [
    '_id',
    'title',
    'artist',
    'album',
    'duration',
    'data',
    'date_added',
    'date_modified',
    'size',
    'mime_type',
    'album_id',
    'track',
    'year',
  ];

  // Cache structure
  static Map<String, dynamic> _cache = {};
  static DateTime? _lastUpdate;
  static DateTime? _lastScan;
  static SharedPreferences? _prefs;

  // Expose cache for internal use
  static Map<String, dynamic> get cache => _cache;

  // Initialize the service
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCache();
    _lastScan = DateTime.fromMillisecondsSinceEpoch(
      _prefs?.getInt(_lastScanKey) ?? 0
    );
  }

  // Get all music files from MediaStore with pagination
  static Future<List<Map<String, dynamic>>> getMusicFiles({
    int page = 0,
    int pageSize = 50,
    bool forceRefresh = false,
  }) async {
    try {
      // Check if we have a valid cache and not forcing refresh
      if (!forceRefresh && _cache.isNotEmpty && _lastUpdate != null) {
        final now = DateTime.now();
        final difference = now.difference(_lastUpdate!);
        
        // Use cache if it's still valid
        if (difference < _cacheValidityDuration) {
          final start = page * pageSize;
          final end = start + pageSize;
          final cachedFiles = List<Map<String, dynamic>>.from(_cache['files']);
          return cachedFiles.sublist(
            start,
            end > cachedFiles.length ? cachedFiles.length : end,
          );
        }
      }

      // Query MediaStore through platform channel with pagination
      final List<dynamic> result = await platform.invokeMethod('queryMusicFiles', {
        'columns': _columns,
        'page': page,
        'pageSize': pageSize,
      });

      // Convert result to List<Map>
      final List<Map<String, dynamic>> musicFiles = result.map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();

      // Update cache if this is the first page
      if (page == 0) {
        _cache = {
          'files': musicFiles,
          'lastUpdate': DateTime.now().toIso8601String(),
        };
        _lastUpdate = DateTime.now();
        await _saveCache();
      }

      return musicFiles;
    } catch (e) {
      debugPrint('Error querying music files: $e');
      rethrow;
    }
  }

  // Get songs for a specific page with basic metadata
  static Future<List<Map<String, dynamic>>> getSongsForPage(int page, int pageSize) async {
    try {
      final result = await platform.invokeMethod('queryMusicFiles', {
        'page': page,
        'pageSize': pageSize,
        'columns': _columns,
      });
      
      if (result == null) {
        debugPrint('No songs returned for page $page');
        return [];
      }
      
      final List<dynamic> songsList = result;
      return songsList.map((song) => Map<String, dynamic>.from(song)).toList();
    } catch (e) {
      debugPrint('Error getting songs for page $page: $e');
      return [];
    }
  }

  // Get full metadata for a list of songs
  static Future<List<Map<String, dynamic>>> getSongsMetadata(List<String> uris) async {
    try {
      final result = await platform.invokeMethod('getSongsMetadata', {'uris': uris});
      if (result == null) {
        debugPrint('No metadata returned for songs');
        return [];
      }
      
      final List<dynamic> resultList = result as List<dynamic>;
      return resultList.map((item) {
        if (item == null) {
          return null;
        }
        try {
          final metadata = Map<String, dynamic>.from(item);
          // Only include non-empty values
          final filteredMetadata = metadata.map((key, value) {
            if (value == null || (value is String && value.trim().isEmpty)) {
              return MapEntry(key, null);
            }
            return MapEntry(key, value);
          });
          return filteredMetadata;
        } catch (e) {
          debugPrint('Error converting metadata item: $e');
          return null;
        }
      }).whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('Error getting songs metadata from MediaStore: $e');
      return [];
    }
  }

  // Get metadata for a single song
  static Future<Map<String, dynamic>?> getSongMetadata(String uri) async {
    try {
      // Check cache first
      if (_cache.containsKey(uri)) {
        return _cache[uri];
      }

      final result = await platform.invokeMethod('getSongMetadata', {'uri': uri});
      if (result == null) {
        debugPrint('No metadata returned for song: $uri');
        return null;
      }

      final metadata = Map<String, dynamic>.from(result);
      _cache[uri] = metadata;
      return metadata;
    } catch (e) {
      debugPrint('Error getting song metadata from MediaStore: $e');
      return null;
    }
  }

  // Get album art for a song
  static Future<Uint8List?> getAlbumArt(String songId) async {
    try {
      final result = await platform.invokeMethod('getAlbumArt', {
        'songId': songId,
      });

      if (result != null) {
        return Uint8List.fromList(List<int>.from(result));
      }
      return null;
    } catch (e) {
      debugPrint('Error getting album art for song $songId: $e');
      return null;
    }
  }

  // Save cache to local storage
  static Future<void> _saveCache() async {
    try {
      final jsonString = jsonEncode(_cache);
      await _prefs?.setString(_cacheFileName, jsonString);
      await _prefs?.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving cache: $e');
    }
  }

  // Load cache from local storage
  static Future<void> _loadCache() async {
    try {
      final jsonString = _prefs?.getString(_cacheFileName);
      if (jsonString != null) {
        _cache = jsonDecode(jsonString);
        final lastUpdate = _prefs?.getInt(_lastUpdateKey);
        if (lastUpdate != null) {
          _lastUpdate = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
        }
      }
    } catch (e) {
      debugPrint('Error loading cache: $e');
    }
  }

  // Check if we need to perform a full scan
  static bool shouldPerformFullScan() {
    if (_lastScan == null) return true;
    
    final now = DateTime.now();
    return now.difference(_lastScan!) > _scanInterval;
  }

  // Update last scan time
  static Future<void> updateLastScanTime() async {
    _lastScan = DateTime.now();
    if (_prefs == null) await initialize();
    await _prefs?.setInt(_lastScanKey, _lastScan!.millisecondsSinceEpoch);
  }

  // Get total song count
  static Future<int> getTotalSongCount() async {
    try {
      final result = await platform.invokeMethod('getTotalSongCount', {});
      return result as int? ?? 0;
    } catch (e) {
      debugPrint('Error getting total song count: $e');
      return 0;
    }
  }

  // Clear cache
  static Future<void> clearCache() async {
    try {
      if (_prefs == null) await initialize();
      
      // Clear last update time
      await _prefs?.remove(_lastUpdateKey);
      
      // Clear cache file
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File('${cacheDir.path}/$_cacheFileName');
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      
      _cache = {};
      _lastUpdate = null;
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  // Get all songs from MediaStore
  static Future<List<Map<String, dynamic>>> getSongs() async {
    try {
      final result = await platform.invokeMethod('getSongs');
      return List<Map<String, dynamic>>.from(result ?? []);
    } catch (e) {
      debugPrint('Error getting songs from MediaStore: $e');
      return [];
    }
  }
} 