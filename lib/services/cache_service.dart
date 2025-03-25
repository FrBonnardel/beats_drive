import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/widgets.dart';

class CacheService {
  static const String _songsKey = 'cached_songs';
  static const String _albumArtKey = 'album_art_';
  static const String _lastScanKey = 'last_scan_time';
  static const String _songHashKey = 'songs_hash';
  static const String _lastModifiedKey = 'last_modified_';
  static const Duration _cacheValidityDuration = Duration(hours: 24);
  static const int _maxCacheSize = 1000; // Maximum number of songs to cache
  static const int _maxAlbumArtCacheSize = 100; // Maximum number of album art images to cache
  
  late SharedPreferences _prefs;
  Box<Map>? _songCache;
  final Map<String, Song> _memoryCache = {};
  final Map<String, DateTime> _lastModifiedCache = {};
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SongAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AlbumAdapter());
    }
    _songCache = await Hive.openBox<Map>('songs');
    await _loadMemoryCache();
    await _loadLastModifiedCache();
  }

  Future<void> _loadMemoryCache() async {
    try {
      final songs = _songCache?.values.map((songMap) {
        return Song.fromJson(Map<String, dynamic>.from(songMap));
      }).toList() ?? [];
      
      // Sort by date added to ensure most recent songs are in memory
      songs.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      
      // Keep the most recent songs in memory
      for (var song in songs.take(_maxCacheSize)) {
        _memoryCache[song.uri] = song;
      }
    } catch (e) {
      debugPrint('Error loading memory cache: $e');
    }
  }

  Future<void> _loadLastModifiedCache() async {
    try {
      final keys = _prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_lastModifiedKey)) {
          final songUri = key.substring(_lastModifiedKey.length);
          final timestamp = _prefs.getInt(key);
          if (timestamp != null) {
            _lastModifiedCache[songUri] = DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading last modified cache: $e');
    }
  }

  List<Song> getCachedSongs() {
    try {
      return _memoryCache.values.toList();
    } catch (e) {
      debugPrint('Error getting cached songs: $e');
      return [];
    }
  }

  Future<List<Song>> getCachedSongsForPage(int page, int pageSize) async {
    try {
      final allSongs = getCachedSongs();
      final startIndex = page * pageSize;
      if (startIndex >= allSongs.length) {
        debugPrint('No more cached songs for page $page');
        return [];
      }
      
      final endIndex = (startIndex + pageSize).clamp(0, allSongs.length);
      final songs = allSongs.sublist(startIndex, endIndex);
      debugPrint('Retrieved ${songs.length} songs for page $page from cache');
      return songs;
    } catch (e) {
      debugPrint('Error getting cached songs for page: $e');
      return [];
    }
  }

  Future<void> cacheSongs(List<Song> songs) async {
    debugPrint('Caching ${songs.length} songs');
    try {
      final rootToken = RootIsolateToken.instance;
      if (rootToken == null) {
        throw Exception('Failed to get root isolate token');
      }
      
      await compute(_cacheSongsInBackground, {
        'songs': songs.map((s) => s.toJson()).toList(),
        'boxName': _songCache?.name ?? 'songs',
        'rootToken': rootToken,
      });
    } catch (e) {
      debugPrint('Error caching songs: $e');
    }
  }

  Future<void> _updateMemoryCache(List<Song> songs) async {
    const chunkSize = 100;
    for (var i = 0; i < songs.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, songs.length);
      final chunk = songs.sublist(i, end);
      
      for (var song in chunk) {
        _memoryCache[song.uri] = song;
      }
      
      // Allow UI to update between chunks
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> _updateMetadataForChunk(List<Song> chunk) async {
    await _updateLastScanTime();
    await _updateSongsHash(chunk);
    
    for (final song in chunk) {
      await _updateLastModified(song.uri, DateTime.now());
    }
  }

  static List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, list.length);
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  static Future<void> _cacheSongsInBackground(Map<String, dynamic> params) async {
    final songs = (params['songs'] as List).cast<Map<String, dynamic>>();
    final boxName = params['boxName'] as String;
    final rootToken = params['rootToken'] as RootIsolateToken;
    
    // Initialize background isolate messenger
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
    
    // Initialize Hive in the isolate
    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);
    
    // Register adapters if needed
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SongAdapter());
    }
    
    // Open the box
    final box = await Hive.openBox<Map>(boxName);
    
    // Clear existing data
    await box.clear();
    
    // Add songs in chunks
    const chunkSize = 100;
    for (var i = 0; i < songs.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, songs.length);
      final chunk = songs.sublist(i, end);
      
      await box.putAll(Map.fromEntries(
        chunk.map((songJson) {
          final song = Song.fromJson(songJson);
          return MapEntry(song.uri, songJson);
        })
      ));
    }
    
    // Close the box
    await box.close();
  }

  Future<List<int>?> getCachedAlbumArt(String songId) async {
    final artString = _prefs.getString('${_albumArtKey}$songId');
    if (artString == null) return null;
    
    try {
      final List<dynamic> artList = jsonDecode(artString);
      return artList.cast<int>();
    } catch (e) {
      debugPrint('Error decoding cached album art: $e');
      return null;
    }
  }

  Future<void> cacheAlbumArt(String songId, List<int> albumArt) async {
    try {
      // Check if we've reached the maximum cache size
      final keys = _prefs.getKeys();
      final albumArtKeys = keys.where((key) => key.startsWith(_albumArtKey)).toList();
      
      if (albumArtKeys.length >= _maxAlbumArtCacheSize) {
        // Remove the oldest album art
        final oldestKey = albumArtKeys.first;
        await _prefs.remove(oldestKey);
      }
      
      final artJson = jsonEncode(albumArt);
      await _prefs.setString('${_albumArtKey}$songId', artJson);
    } catch (e) {
      debugPrint('Error caching album art: $e');
    }
  }

  Future<void> _updateLastScanTime() async {
    await _prefs.setInt(_lastScanKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _updateSongsHash(List<Song> songs) async {
    final hash = songs.map((s) => s.uri).join(',').hashCode.toString();
    await _prefs.setString(_songHashKey, hash);
  }

  Future<void> _updateLastModified(String songUri, DateTime timestamp) async {
    await _prefs.setInt('$_lastModifiedKey$songUri', timestamp.millisecondsSinceEpoch);
    _lastModifiedCache[songUri] = timestamp;
  }

  Future<DateTime?> getLastModified(String songUri) async {
    if (_lastModifiedCache.containsKey(songUri)) {
      return _lastModifiedCache[songUri];
    }
    
    final timestamp = _prefs.getInt('$_lastModifiedKey$songUri');
    if (timestamp != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      _lastModifiedCache[songUri] = date;
      return date;
    }
    return null;
  }

  Future<bool> hasMusicLibraryChanged(List<Song> newSongs) async {
    final oldHash = _prefs.getString(_songHashKey);
    if (oldHash == null) return true;
    
    final newHash = newSongs.map((s) => s.uri).join(',').hashCode.toString();
    return oldHash != newHash;
  }

  Future<bool> hasSongChanged(String songUri, DateTime lastModified) async {
    final cachedLastModified = await getLastModified(songUri);
    if (cachedLastModified == null) return true;
    return lastModified.isAfter(cachedLastModified);
  }

  bool shouldRescan() {
    final lastScan = _prefs.getInt(_lastScanKey);
    if (lastScan == null) return true;
    
    final lastScanTime = DateTime.fromMillisecondsSinceEpoch(lastScan);
    final now = DateTime.now();
    return now.difference(lastScanTime) > _cacheValidityDuration;
  }

  Future<void> clearCache() async {
    await _prefs.clear();
    await _songCache?.clear();
    _memoryCache.clear();
    _lastModifiedCache.clear();
  }

  Future<void> removeSongFromCache(String songUri) async {
    _memoryCache.remove(songUri);
    await _prefs.remove('$_lastModifiedKey$songUri');
    await _songCache?.delete(songUri);
    _lastModifiedCache.remove(songUri);
  }
}