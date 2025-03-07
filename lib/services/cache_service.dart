import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CacheService {
  static const String _musicFilesKey = 'music_files';
  static const String _lastScanKey = 'last_scan';
  static const String _cacheVersionKey = 'cache_version';
  static const String _forceRescanKey = 'force_rescan';
  static const int _currentCacheVersion = 1;

  static Future<void> clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('Cache cleared successfully');
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  static Future<bool> hasScanData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasFiles = prefs.containsKey('${_musicFilesKey}_0');
      final hasVersion = prefs.containsKey(_cacheVersionKey);
      final version = prefs.getInt(_cacheVersionKey) ?? 0;
      return hasFiles && hasVersion && version == _currentCacheVersion;
    } catch (e) {
      debugPrint('Error checking scan data: $e');
      return false;
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