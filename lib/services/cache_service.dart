import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'dart:isolate';

class CacheService {
  static const String _songsKey = 'cached_songs';
  static const String _albumArtKey = 'album_art_';
  static const String _lastScanKey = 'last_scan_time';
  static const String _songHashKey = 'songs_hash';
  static const Duration _cacheValidityDuration = Duration(hours: 24);
  static const int _maxCacheSize = 1000; // Maximum number of songs to cache
  
  late SharedPreferences _prefs;
  Box<Map>? _songCache;
  final Map<String, Song> _memoryCache = {};
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _songCache = await Hive.openBox<Map>('songs');
    _loadMemoryCache();
  }

  void _loadMemoryCache() {
    try {
      final songs = _songCache?.values.map((songMap) {
        return Song.fromJson(Map<String, dynamic>.from(songMap));
      }).toList() ?? [];
      
      // Only keep the most recent songs in memory
      songs.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      for (var song in songs.take(_maxCacheSize)) {
        _memoryCache[song.uri] = song;
      }
    } catch (e) {
      debugPrint('Error loading memory cache: $e');
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
    final allSongs = getCachedSongs();
    final startIndex = page * pageSize;
    if (startIndex >= allSongs.length) return [];
    
    final endIndex = (startIndex + pageSize).clamp(0, allSongs.length);
    return allSongs.sublist(startIndex, endIndex);
  }

  Future<void> cacheSongsForPage(int page, List<Song> songs) async {
    final allSongs = getCachedSongs();
    final startIndex = page * songs.length;
    
    // If this is the first page, clear existing songs
    if (page == 0) {
      allSongs.clear();
    }
    
    // Ensure the list is large enough
    while (allSongs.length < startIndex + songs.length) {
      allSongs.add(Song.empty());
    }
    
    // Replace songs at the correct indices
    for (var i = 0; i < songs.length; i++) {
      allSongs[startIndex + i] = songs[i];
    }
    
    // Remove any trailing empty songs
    while (allSongs.isNotEmpty && allSongs.last == Song.empty()) {
      allSongs.removeLast();
    }
    
    await cacheSongs(allSongs);
  }

  Future<void> cacheSongs(List<Song> songs) async {
    try {
      // Update memory cache
      _memoryCache.clear();
      for (var song in songs.take(_maxCacheSize)) {
        _memoryCache[song.uri] = song;
      }

      // Cache songs in Hive in a separate isolate
      await compute(_cacheSongsInIsolate, {
        'songs': songs,
        'maxCacheSize': _maxCacheSize,
      });
      
      // Update metadata
      await _updateLastScanTime();
      await _updateSongsHash(songs);
    } catch (e) {
      debugPrint('Error caching songs: $e');
    }
  }

  // Cache songs in a separate isolate
  static Future<void> _cacheSongsInIsolate(Map<String, dynamic> params) async {
    final songs = params['songs'] as List<Song>;
    final maxCacheSize = params['maxCacheSize'] as int;
    
    final box = await Hive.openBox<Map>('songs');
    await box.clear();
    
    final songsMap = {
      for (var song in songs.take(maxCacheSize))
        song.uri: song.toJson()
    };
    await box.putAll(songsMap);
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

  Future<bool> hasMusicLibraryChanged(List<Song> newSongs) async {
    final oldHash = _prefs.getString(_songHashKey);
    if (oldHash == null) return true;
    
    final newHash = newSongs.map((s) => s.uri).join(',').hashCode.toString();
    return oldHash != newHash;
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
  }
}