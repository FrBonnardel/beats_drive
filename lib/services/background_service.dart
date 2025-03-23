import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/music_models.dart';
import '../services/cache_service.dart';
import 'package:hive/hive.dart';
import 'media_store_service.dart';

@pragma('vm:entry-point')
void backgroundHandler(List<dynamic> args) async {
  final SendPort sendPort = args[0];
  final RootIsolateToken rootToken = args[1];
  
  try {
    debugPrint('BackgroundHandler: Initializing binary messenger');
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
    
    debugPrint('BackgroundHandler: Initializing Hive');
    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);
    
    debugPrint('BackgroundHandler: Initializing cache service');
    final cacheService = CacheService();
    await cacheService.initialize();
    
    debugPrint('BackgroundHandler: Querying music files');
    final channel = MethodChannel('com.beats_drive/media_store');
    final musicFiles = await channel.invokeMethod('queryMusicFiles');
    
    debugPrint('BackgroundHandler: Processing ${(musicFiles as List).length} music files');
    final songs = (musicFiles as List).map((file) {
      final title = file['title']?.toString() ?? 'Unknown Title';
      final artist = file['artist']?.toString() ?? 'Unknown Artist';
      final album = file['album']?.toString() ?? 'Unknown Album';
      final uri = file['uri']?.toString() ?? '';
      final data = file['data']?.toString() ?? '';

      debugPrint('BackgroundHandler: Processing song: $title by $artist');
      final songUri = uri.isNotEmpty ? uri : data;

      return Song(
        id: file['_id']?.toString() ?? '',
        uri: songUri,
        title: title,
        artist: artist,
        album: album,
        albumId: file['album_id']?.toString() ?? '',
        duration: file['duration'] ?? 0,
        trackNumber: file['track'] ?? 0,
        year: file['year'] ?? 0,
        dateAdded: file['date_added'] ?? DateTime.now().millisecondsSinceEpoch,
        albumArtUri: file['album_art_uri']?.toString() ?? '',
      );
    }).toList();
    
    debugPrint('BackgroundHandler: Sending ${songs.length} songs back to main isolate');
    sendPort.send(songs);
  } catch (e) {
    debugPrint('BackgroundHandler: Error in background scan: $e');
    sendPort.send('Error in background scan: $e');
  }
}

class BackgroundService {
  static final _songStreamController = StreamController<List<Song>>.broadcast();
  static Stream<List<Song>> get songStream => _songStreamController.stream;
  static bool _isScanning = false;
  static const int _batchSize = 20;
  static const Duration _batchDelay = Duration(milliseconds: 500);
  static const int _maxConcurrentOperations = 2;
  static Isolate? _scanIsolate;
  static ReceivePort? _receivePort;

  final CacheService _cacheService;

  BackgroundService(this._cacheService);

  static Future<void> scheduleMusicScan() async {
    if (_isScanning) return;
    _isScanning = true;

    try {
      _receivePort = ReceivePort();
      _scanIsolate = await Isolate.spawn(
        _scanMusicFiles,
        _receivePort!.sendPort,
      );

      _receivePort!.listen((message) {
        if (message is List<Song>) {
          _songStreamController.add(message);
        } else if (message == 'DONE') {
          _cleanupScan();
        }
      });

    } catch (e) {
      debugPrint('Error scheduling music scan: $e');
      _cleanupScan();
    }
  }

  static void _cleanupScan() {
    _scanIsolate?.kill();
    _scanIsolate = null;
    _receivePort?.close();
    _receivePort = null;
    _isScanning = false;
  }

  static Future<void> _scanMusicFiles(SendPort sendPort) async {
    try {
      int offset = 0;
      bool hasMore = true;
      final List<Song> allSongs = [];

      while (hasMore) {
        // Get a batch of songs
        final songsList = await MediaStoreService.getSongsForPage(
          offset ~/ _batchSize,
          _batchSize,
        );

        if (songsList.isEmpty) {
          hasMore = false;
          break;
        }

        // Convert to Song objects
        final songs = songsList.map((song) => Song(
          id: song['_id']?.toString() ?? '',
          title: song['title']?.toString() ?? 'Unknown Title',
          artist: song['artist']?.toString() ?? 'Unknown Artist',
          album: song['album']?.toString() ?? 'Unknown Album',
          albumId: song['album_id']?.toString() ?? '',
          duration: song['duration'] as int? ?? 0,
          uri: song['_data']?.toString() ?? '',
          albumArtUri: '',
          trackNumber: song['track'] as int? ?? 0,
          year: song['year'] as int? ?? 0,
          dateAdded: song['date_added'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        )).toList();

        allSongs.addAll(songs);
        sendPort.send(songs);

        offset += songsList.length;
        await Future.delayed(_batchDelay);
      }

      // Process metadata and album art in batches
      for (var i = 0; i < allSongs.length; i += _batchSize) {
        final batch = allSongs.sublist(
          i,
          (i + _batchSize).clamp(0, allSongs.length),
        );

        // Process metadata and album art concurrently but with limits
        final futures = <Future>[];
        for (final song in batch) {
          if (futures.length >= _maxConcurrentOperations) {
            await Future.wait(futures);
            futures.clear();
          }

          futures.add(_processMetadata(song));
          futures.add(_processAlbumArt(song));
        }

        await Future.wait(futures);
        await Future.delayed(_batchDelay);
      }

      sendPort.send('DONE');
    } catch (e) {
      debugPrint('Error in background scan: $e');
      sendPort.send('DONE');
    }
  }

  static Future<Song?> _processMetadata(Song song) async {
    try {
      final metadata = await MediaStoreService.getSongMetadata(song.uri);
      if (metadata != null) {
        final updatedSong = song.copyWith(
          title: metadata['title']?.toString() ?? song.title,
          artist: metadata['artist']?.toString() ?? song.artist,
          album: metadata['album']?.toString() ?? song.album,
          albumId: metadata['album_id']?.toString() ?? song.albumId,
          duration: metadata['duration'] as int? ?? song.duration,
          trackNumber: metadata['track'] as int? ?? song.trackNumber,
          year: metadata['year'] as int? ?? song.year,
        );
        return updatedSong;
      }
    } catch (e) {
      debugPrint('Error processing metadata for ${song.title}: $e');
    }
    return null;
  }

  static Future<Song?> _processAlbumArt(Song song) async {
    try {
      final albumArt = await MediaStoreService.getAlbumArt(song.id);
      if (albumArt != null) {
        final updatedSong = song.copyWith(
          albumArtUri: 'memory://${song.id}',
        );
        return updatedSong;
      }
    } catch (e) {
      debugPrint('Error processing album art for ${song.title}: $e');
    }
    return null;
  }

  static void dispose() {
    _cleanupScan();
    _songStreamController.close();
  }

  Future<void> initializeService() async {
    await _cacheService.initialize();
  }
} 