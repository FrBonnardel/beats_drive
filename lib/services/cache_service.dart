import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:typed_data';
import '../models/music_models.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CacheService {
  static const String _musicFilesKey = 'music_files';
  static const String _lastScanKey = 'lastScan';
  static const String _cacheVersionKey = 'cache_version';
  static const String _forceRescanKey = 'force_rescan';
  static const int _currentCacheVersion = 1;
  static const String _songBox = 'songs';
  static const String _albumArtBox = 'albumArt';
  static Box<Map>? _songCache;
  static Box<List<int>>? _albumArtCache;
  static Box<dynamic>? _metadataCache;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();
      
      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(SongAdapter());
      }
      
      // Open boxes with retry mechanism
      _songCache = await _openBoxWithRetry<Map>(_songBox);
      _albumArtCache = await _openBoxWithRetry<List<int>>(_albumArtBox);
      _metadataCache = await _openBoxWithRetry('metadata');
      
      _isInitialized = true;
      debugPrint('Cache service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing cache service: $e');
      await _handleCacheError();
    }
  }

  static Future<Box<T>> _openBoxWithRetry<T>(String name, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await Hive.openBox<T>(name);
      } catch (e) {
        attempts++;
        debugPrint('Failed to open box $name (attempt $attempts): $e');
        if (attempts == maxRetries) rethrow;
        
        // Delete the box and try again
        await Hive.deleteBoxFromDisk(name);
        await Future.delayed(Duration(milliseconds: 100 * attempts));
      }
    }
    throw Exception('Failed to open box $name after $maxRetries attempts');
  }

  static Future<void> _handleCacheError() async {
    try {
      _isInitialized = false;
      
      // Close boxes if they're open
      await _songCache?.close();
      await _albumArtCache?.close();
      await _metadataCache?.close();
      
      // Delete boxes from disk
      await Hive.deleteBoxFromDisk(_songBox);
      await Hive.deleteBoxFromDisk(_albumArtBox);
      await Hive.deleteBoxFromDisk('metadata');
      
      // Try to reinitialize
      _songCache = await _openBoxWithRetry<Map>(_songBox);
      _albumArtCache = await _openBoxWithRetry<List<int>>(_albumArtBox);
      _metadataCache = await _openBoxWithRetry('metadata');
      
      _isInitialized = true;
      debugPrint('Cache service reinitialized after error');
    } catch (e) {
      debugPrint('Failed to reinitialize cache service: $e');
      _isInitialized = false;
    }
  }

  static Future<void> cacheSongs(List<Song> songs) async {
    try {
      if (_songCache == null) {
        debugPrint('Song cache not initialized');
        return;
      }

      await _songCache?.clear();
      final songsMap = {
        for (var song in songs)
          song.uri: song.toMap()
      };
      await _songCache?.putAll(songsMap);
      await _metadataCache?.put(_lastScanKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('CacheService: Saved ${songs.length} songs to cache');
    } catch (e) {
      debugPrint('Error saving songs to cache: $e');
    }
  }

  static List<Song> getCachedSongs() {
    try {
      if (_songCache == null) {
        debugPrint('CacheService: Song cache not initialized');
        return [];
      }

      final songs = _songCache!.values
          .map((songMap) => Song.fromMap(Map<String, dynamic>.from(songMap)))
          .toList();
      
      debugPrint('CacheService: Loaded ${songs.length} songs from existing cache');
      return songs;
    } catch (e) {
      debugPrint('Error loading songs from cache: $e');
      return [];
    }
  }

  static Future<void> cacheAlbumArt(String songId, Uint8List albumArt) async {
    try {
      if (_albumArtCache == null) {
        debugPrint('Album art cache not initialized');
        return;
      }

      await _albumArtCache?.put(songId, albumArt);
      debugPrint('Cached album art for song $songId');
    } catch (e) {
      debugPrint('Error caching album art: $e');
    }
  }

  static Uint8List? getCachedAlbumArt(String songId) {
    try {
      if (_albumArtCache == null) {
        debugPrint('Album art cache not initialized');
        return null;
      }

      final data = _albumArtCache?.get(songId);
      if (data != null) {
        return Uint8List.fromList(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving cached album art: $e');
      return null;
    }
  }

  static bool shouldRescan() {
    try {
      if (_metadataCache == null) {
        debugPrint('Metadata cache not initialized');
        return true;
      }

      final lastScan = _metadataCache?.get(_lastScanKey) as int?;
      if (lastScan == null) return true;
      
      final lastScanTime = DateTime.fromMillisecondsSinceEpoch(lastScan);
      final now = DateTime.now();
      return now.difference(lastScanTime).inHours >= 1; // Rescan every hour
    } catch (e) {
      debugPrint('Error checking rescan status: $e');
      return true;
    }
  }

  static Future<void> clearCache() async {
    try {
      await _songCache?.clear();
      await _albumArtCache?.clear();
      await _metadataCache?.clear();
      debugPrint('Cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  static Future<void> saveMusicFiles(List<String> files) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      debugPrint('Saving ${files.length} music files to cache');
      
      // Save files in chunks to avoid memory issues
      final chunkSize = 1000;
      for (var i = 0; i < files.length; i += chunkSize) {
        final chunk = files.skip(i).take(chunkSize).toList();
        await prefs.setString('${_musicFilesKey}_${i ~/ chunkSize}', jsonEncode(chunk));
        debugPrint('Saved chunk ${(i ~/ chunkSize) + 1} with ${chunk.length} files');
      }
      
      await prefs.setInt(_lastScanKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_cacheVersionKey, _currentCacheVersion);
      await prefs.setBool(_forceRescanKey, false);
      debugPrint('Cache save complete with ${files.length} total files');
    } catch (e) {
      debugPrint('Error saving music files: $e');
    }
  }

  static Future<List<String>> loadMusicFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      debugPrint('Loading music files from cache');
      
      // Check cache version
      final version = prefs.getInt(_cacheVersionKey) ?? 0;
      if (version != _currentCacheVersion) {
        debugPrint('Cache version mismatch: $version != $_currentCacheVersion, clearing cache');
        await clearCache();
        return [];
      }

      // Check if we have any cached files
      final hasFiles = prefs.containsKey('${_musicFilesKey}_0');
      if (!hasFiles) {
        debugPrint('No cached files found');
        return [];
      }

      final List<String> allFiles = [];
      var chunkIndex = 0;
      
      while (true) {
        final chunkJson = prefs.getString('${_musicFilesKey}_$chunkIndex');
        if (chunkJson == null) break;
        
        final List<dynamic> chunk = jsonDecode(chunkJson);
        allFiles.addAll(chunk.cast<String>());
        debugPrint('Loaded chunk $chunkIndex with ${chunk.length} files');
        chunkIndex++;
      }
      
      debugPrint('Cache load complete with ${allFiles.length} total files');
      return allFiles;
    } catch (e) {
      debugPrint('Error loading music files: $e');
      return [];
    }
  }

  static Future<bool> needsRescan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final forceRescan = prefs.getBool(_forceRescanKey) ?? false;
      return forceRescan;
    } catch (e) {
      print('Error checking scan status: $e');
      return true;
    }
  }

  static Future<void> setForceRescan(bool force) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_forceRescanKey, force);
    } catch (e) {
      print('Error setting force rescan: $e');
    }
  }

  static Future<DateTime?> getLastScanTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastScanKey);
      return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
    } catch (e) {
      debugPrint('Error getting last scan time: $e');
      return null;
    }
  }

  static Future<void> setLastScanTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastScanKey, time.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error setting last scan time: $e');
    }
  }
} 