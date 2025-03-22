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

@pragma('vm:entry-point')
void backgroundHandler(List<dynamic> args) async {
  final SendPort sendPort = args[0];
  final RootIsolateToken rootToken = args[1];
  
  try {
    // Initialize the binary messenger
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
    
    // Initialize Hive in the isolate
    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);
    
    // Initialize cache service
    await CacheService.initialize();
    
    // Query music files using MediaStore
    final channel = MethodChannel('com.beats_drive/media_store');
    final musicFiles = await channel.invokeMethod('queryMusicFiles');
    
    // Process the results
    final songs = (musicFiles as List).map((file) {
      final title = file['title']?.toString() ?? 'Unknown Title';
      final artist = file['artist']?.toString() ?? 'Unknown Artist';
      final album = file['album']?.toString() ?? 'Unknown Album';
      final uri = file['uri']?.toString() ?? '';
      final data = file['data']?.toString() ?? '';

      // Use the content URI if available, otherwise use the file path
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
    
    sendPort.send(songs);
  } catch (e) {
    sendPort.send('Error in background scan: $e');
  }
}

class BackgroundService {
  static Isolate? _isolate;
  static ReceivePort? _receivePort;
  static final _controller = StreamController<List<Song>>.broadcast();
  static bool _isInitialized = false;

  static Stream<List<Song>> get songStream => _controller.stream;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final rootToken = RootIsolateToken.instance;
      if (rootToken == null) {
        print('Error: RootIsolateToken is null');
        return;
      }

      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(
        backgroundHandler,
        [_receivePort!.sendPort, rootToken],
      );

      _receivePort!.listen((message) {
        if (message is List<Song>) {
          _controller.add(message);
        } else if (message is String && message.startsWith('Error')) {
          print(message);
        }
      });

      _isInitialized = true;
    } catch (e) {
      print('Error initializing background service: $e');
      await stopBackgroundTask();
    }
  }

  static Future<void> stopBackgroundTask() async {
    if (_isolate != null) {
      _isolate!.kill();
      _isolate = null;
    }
    if (_receivePort != null) {
      _receivePort!.close();
      _receivePort = null;
    }
    await _controller.close();
    _isInitialized = false;
  }

  static Future<void> scheduleMusicScan() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  static Future<void> scheduleMetadataUpdate(String uri) async {
    // This will be implemented later when we add metadata extraction
    return;
  }
} 