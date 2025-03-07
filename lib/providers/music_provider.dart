import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/music_scanner_service.dart';
import '../services/cache_service.dart';
import '../services/metadata_service.dart';
import 'dart:io';
import 'dart:isolate';

class MusicProvider with ChangeNotifier {
  final List<String> _musicFiles = [];
  bool _isScanning = false;
  String _error = '';
  int _totalFiles = 0;
  int _processedFiles = 0;
  String _currentStatus = '';
  bool _isComplete = false;
  static const int _directoryBatchSize = 10;
  static const int _fileBatchSize = 50;
  static const int _uiUpdateInterval = 100;

  List<String> get musicFiles => _musicFiles;
  bool get isScanning => _isScanning;
  String get error => _error;
  int get totalFiles => _totalFiles;
  int get processedFiles => _processedFiles;
  String get currentStatus => _currentStatus;
  bool get isComplete => _isComplete;

  Future<void> scanMusicFiles({bool forceRescan = false}) async {
    if (_isScanning) return;
    
    debugPrint('Starting music scan (forceRescan: $forceRescan)');
    _resetState();
    notifyListeners();

    try {
      // Check if we have valid cached files
      final cachedFiles = await CacheService.loadMusicFiles();
      final lastScanTime = await CacheService.getLastScanTime();
      final now = DateTime.now();
      
      // Only rescan if:
      // 1. Force rescan is requested
      // 2. No cached files exist
      // 3. Last scan was more than 24 hours ago
      if (!forceRescan && 
          cachedFiles.isNotEmpty && 
          lastScanTime != null && 
          now.difference(lastScanTime).inHours < 24) {
        debugPrint('Using cached files from ${lastScanTime.toString()}');
        _musicFiles.addAll(cachedFiles);
        _totalFiles = cachedFiles.length;
        _processedFiles = cachedFiles.length;
        _currentStatus = 'Loaded ${cachedFiles.length} cached files';
        _isScanning = false;
        _isComplete = true;
        notifyListeners();
        return;
      }

      if (forceRescan) {
        debugPrint('Force rescan requested, clearing cache');
        await CacheService.clearCache();
      }

      debugPrint('Starting new scan');
      await _performScan();
    } catch (e) {
      debugPrint('Error in scanMusicFiles: $e');
      _handleError(e);
    }
  }

  void _resetState() {
    _isScanning = true;
    _isComplete = false;
    _totalFiles = 0;
    _processedFiles = 0;
    _error = '';
    _currentStatus = 'Initializing...';
    _musicFiles.clear();
    notifyListeners();
  }

  Future<void> _loadFromCache() async {
    _currentStatus = 'Loading cached files...';
    notifyListeners();
    
    try {
      final cachedFiles = await CacheService.loadMusicFiles();
      if (cachedFiles.isEmpty) {
        debugPrint('No cached files found, performing new scan');
        await _performScan();
        return;
      }
      
      debugPrint('Loaded ${cachedFiles.length} files from cache');
      _musicFiles.addAll(cachedFiles);
      _totalFiles = cachedFiles.length;
      _processedFiles = cachedFiles.length;
      _completeScan();
    } catch (e) {
      debugPrint('Error loading from cache: $e');
      await _performScan();
    }
  }

  Future<void> _performScan() async {
    debugPrint('Initializing background scan');
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _scanInBackground,
      {
        'sendPort': receivePort.sendPort,
        'directoryBatchSize': _directoryBatchSize,
        'fileBatchSize': _fileBatchSize,
      },
    );

    debugPrint('Background isolate spawned, waiting for messages');
    await for (final message in receivePort) {
      if (message is Map<String, dynamic>) {
        debugPrint('Received message: ${message['type']}');
        _handleScanMessage(message);
      }
    }

    debugPrint('Scan complete, killing isolate');
    isolate.kill();
    await _saveToCache();
  }

  void _handleScanMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'progress':
        if (message['processed'] != null && message['total'] != null) {
          _processedFiles = message['processed'];
          _totalFiles = message['total'];
          _currentStatus = message['status'] ?? 'Scanning...';
          debugPrint('Progress update: $_processedFiles/$_totalFiles - $_currentStatus');
          notifyListeners();
        }
        break;
      case 'file':
        _musicFiles.add(message['path']);
        debugPrint('Added file: ${message['path']} (Total files: ${_musicFiles.length})');
        notifyListeners();
        break;
      case 'error':
        debugPrint('Received error: ${message['error']}');
        _handleError(message['error']);
        break;
      case 'status':
        _currentStatus = message['status'];
        debugPrint('Status update: $_currentStatus');
        notifyListeners();
        break;
      case 'complete':
        debugPrint('Received completion message');
        if (message['processed'] != null && message['total'] != null) {
          _processedFiles = message['processed'];
          _totalFiles = message['total'];
          _currentStatus = 'All files processed successfully';
          _isScanning = false;
          _isComplete = true;
          notifyListeners();
          debugPrint('Scan complete, isScanning: $_isScanning, isComplete: $_isComplete, files: ${_musicFiles.length}');
        }
        break;
    }
  }

  Future<void> _saveToCache() async {
    debugPrint('Starting cache save (${_musicFiles.length} files)');
    _currentStatus = 'Saving to cache...';
    notifyListeners();
    
    try {
      await CacheService.saveMusicFiles(_musicFiles);
      await CacheService.setLastScanTime(DateTime.now());
      debugPrint('Cache save complete');
      if (_processedFiles >= _totalFiles && _totalFiles > 0) {
        _completeScan();
      }
    } catch (e) {
      debugPrint('Error saving to cache: $e');
      _handleError('Failed to save cache: $e');
    }
  }

  void _completeScan() {
    debugPrint('Completing scan (${_musicFiles.length} files found)');
    if (_musicFiles.isEmpty) {
      _error = 'No music files found';
      _currentStatus = 'No music found';
      _isScanning = false;
      _isComplete = true;
    } else {
      _currentStatus = 'Ready';
      _isScanning = false;
      if (_processedFiles >= _totalFiles && _totalFiles > 0) {
        _isComplete = true;
      }
    }
    notifyListeners();
    debugPrint('Scan complete, isScanning: $_isScanning, isComplete: $_isComplete, files: ${_musicFiles.length}');
  }

  void _handleError(dynamic error) {
    debugPrint('Error: $error');
    _error = 'Error: $error';
    _currentStatus = 'Error occurred';
    _isScanning = false;
    _isComplete = true;
    notifyListeners();
  }

  Future<bool> requestPermissionAndScan({bool forceRescan = false}) async {
    try {
      _currentStatus = 'Requesting permissions...';
      notifyListeners();
      
      final hasPermission = await MusicScannerService.requestStoragePermission();
      if (!hasPermission) {
        _handleError('Storage permission denied');
        return false;
      }

      final isFirstLaunch = await CacheService.isFirstLaunch();
      if (isFirstLaunch) {
        _currentStatus = 'First launch, clearing cache...';
        notifyListeners();
        await CacheService.clearCache();
      }

      await scanMusicFiles(forceRescan: forceRescan);
      return true;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  static Future<void> _scanInBackground(Map<String, dynamic> params) async {
    final sendPort = params['sendPort'] as SendPort;
    final directoryBatchSize = params['directoryBatchSize'] as int;
    final fileBatchSize = params['fileBatchSize'] as int;

    debugPrint('Background scan started (batchSize: $fileBatchSize)');
    try {
      // Scan directories
      sendPort.send({'type': 'status', 'status': 'Scanning directories...'});
      debugPrint('Starting directory scan');
      final List<String> musicFiles = await _scanDirectories(directoryBatchSize);
      
      debugPrint('Directory scan complete, found ${musicFiles.length} files');
      if (musicFiles.isEmpty) {
        debugPrint('No music files found in directories');
        sendPort.send({'type': 'error', 'error': 'No music files found'});
        return;
      }

      // Set initial progress
      sendPort.send({
        'type': 'progress',
        'total': musicFiles.length,
        'processed': 0,
        'status': 'Found ${musicFiles.length} music files'
      });

      // Process files in batches
      for (var i = 0; i < musicFiles.length; i += fileBatchSize) {
        final batch = musicFiles.skip(i).take(fileBatchSize).toList();
        debugPrint('Processing batch ${(i ~/ fileBatchSize) + 1} (${batch.length} files)');
        
        for (final file in batch) {
          try {
            debugPrint('Processing file: $file');
            final metadata = await MetadataService.getMetadata(file);
            if (metadata.isNotEmpty) {
              debugPrint('Found valid metadata for: $file');
              sendPort.send({'type': 'file', 'path': file});
            } else {
              debugPrint('No metadata found for: $file');
            }
            
            // Update progress after each file is processed
            final progress = i + batch.indexOf(file) + 1;
            sendPort.send({
              'type': 'progress',
              'total': musicFiles.length,
              'processed': progress,
              'status': 'Processing file $progress of ${musicFiles.length}'
            });
          } catch (e) {
            debugPrint('Error processing file $file: $e');
            // Still update progress even if there's an error
            final progress = i + batch.indexOf(file) + 1;
            sendPort.send({
              'type': 'progress',
              'total': musicFiles.length,
              'processed': progress,
              'status': 'Processing file $progress of ${musicFiles.length}'
            });
          }
        }
      }

      // Send completion message only after all files are processed
      sendPort.send({
        'type': 'status',
        'status': 'All files processed successfully'
      });
      sendPort.send({
        'type': 'complete',
        'total': musicFiles.length,
        'processed': musicFiles.length
      });
      
      debugPrint('All files processed successfully');
    } catch (e) {
      debugPrint('Error in background scan: $e');
      sendPort.send({'type': 'error', 'error': 'Error scanning music files: $e'});
    }
  }

  static Future<List<String>> _scanDirectories(int batchSize) async {
    final List<String> musicFiles = [];
    final List<String> directories = ['/storage/emulated/0/Music'];
    debugPrint('Starting directory scan from ${directories.first}');
    
    while (directories.isNotEmpty) {
      final currentDirs = directories.take(batchSize).toList();
      directories.removeRange(0, currentDirs.length);
      debugPrint('Scanning ${currentDirs.length} directories (${directories.length} remaining)');
      
      final futures = currentDirs.map((dir) async {
        try {
          final dirList = await Directory(dir).list().toList();
          for (var entity in dirList) {
            if (entity is Directory) {
              directories.add(entity.path);
            } else if (entity is File && _isMusicFile(entity.path)) {
              musicFiles.add(entity.path);
            }
          }
        } catch (e) {
          debugPrint('Error scanning directory $dir: $e');
        }
      });

      await Future.wait(futures);
    }
    
    debugPrint('Directory scan complete, found ${musicFiles.length} music files');
    return musicFiles;
  }

  static bool _isMusicFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    return ['mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg'].contains(extension);
  }

  Future<Map<String, dynamic>> getMusicFileInfo(String filePath) async {
    return await MusicScannerService.getMusicFileInfo(filePath);
  }
} 