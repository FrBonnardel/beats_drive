import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class MediaStoreService {
  static const platform = MethodChannel('com.beats_drive/media_store');
  static const String _cacheFileName = 'music_cache.json';
  
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
  ];

  // Cache structure
  static Map<String, dynamic> _cache = {};
  static DateTime? _lastUpdate;

  // Expose cache for internal use
  static Map<String, dynamic> get cache => _cache;

  // Get all music files from MediaStore
  static Future<List<Map<String, dynamic>>> getMusicFiles() async {
    try {
      // Check if we have a valid cache
      if (_cache.isNotEmpty && _lastUpdate != null) {
        final now = DateTime.now();
        final difference = now.difference(_lastUpdate!);
        
        // Use cache if it's less than 5 minutes old
        if (difference.inMinutes < 5) {
          return List<Map<String, dynamic>>.from(_cache['files']);
        }
      }

      // Query MediaStore through platform channel
      final List<dynamic> result = await platform.invokeMethod('queryMusicFiles', {
        'columns': _columns,
      });

      // Convert result to List<Map>
      final List<Map<String, dynamic>> musicFiles = result.map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();

      // Update cache
      _cache = {
        'files': musicFiles,
        'lastUpdate': DateTime.now().toIso8601String(),
      };
      _lastUpdate = DateTime.now();

      // Save to local storage
      await _saveCache();

      return musicFiles;
    } catch (e) {
      print('Error querying music files: $e');
      rethrow;
    }
  }

  // Save cache to local storage
  static Future<void> _saveCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_cacheFileName');
      await file.writeAsString(jsonEncode(_cache));
    } catch (e) {
      print('Error saving cache: $e');
    }
  }

  // Load cache from local storage
  static Future<void> loadCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_cacheFileName');
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        _cache = jsonDecode(contents);
        _lastUpdate = DateTime.parse(_cache['lastUpdate']);
      }
    } catch (e) {
      print('Error loading cache: $e');
    }
  }

  // Clear cache
  static Future<void> clearCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_cacheFileName');
      
      if (await file.exists()) {
        await file.delete();
      }
      _cache = {};
      _lastUpdate = null;
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Check if we have valid cache
  static bool hasValidCache() {
    if (_cache.isEmpty || _lastUpdate == null) return false;
    
    final now = DateTime.now();
    final difference = now.difference(_lastUpdate!);
    return difference.inMinutes < 5;
  }
} 