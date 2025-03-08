import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/media_store_service.dart';

class MusicProvider with ChangeNotifier {
  List<Map<String, dynamic>> _musicFiles = [];
  bool _isScanning = false;
  String _error = '';
  String _currentStatus = '';
  bool _isComplete = false;

  List<Map<String, dynamic>> get musicFiles => _musicFiles;
  bool get isScanning => _isScanning;
  String get error => _error;
  String get currentStatus => _currentStatus;
  bool get isComplete => _isComplete;

  // Constructor to set up media store change listener
  MusicProvider() {
    MediaStoreService.platform.setMethodCallHandler((call) async {
      if (call.method == 'onMediaStoreChanged') {
        debugPrint('Media store changed, refreshing music files');
        await scanMusicFiles(forceRescan: true);
      }
    });
  }

  Future<void> scanMusicFiles({bool forceRescan = false}) async {
    if (_isScanning) return;
    
    debugPrint('Starting music scan (forceRescan: $forceRescan)');
    _isScanning = true;
    _isComplete = false;
    _error = '';
    _currentStatus = 'Initializing...';
    _musicFiles.clear();
    notifyListeners();

    try {
      // Check if we have valid cached files
      if (!forceRescan && MediaStoreService.hasValidCache()) {
        debugPrint('Using cached files');
        await MediaStoreService.loadCache();
        _musicFiles = List<Map<String, dynamic>>.from(MediaStoreService.cache['files']);
        _currentStatus = 'Loaded ${_musicFiles.length} cached files';
        _isScanning = false;
        _isComplete = true;
        notifyListeners();
        return;
      }

      if (forceRescan) {
        debugPrint('Force rescan requested, clearing cache');
        await MediaStoreService.clearCache();
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
    _error = '';
    _currentStatus = 'Initializing...';
    _musicFiles.clear();
  }

  Future<void> _performScan() async {
    try {
      _currentStatus = 'Requesting permissions...';
      notifyListeners();

      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _handleError('Storage permission denied');
        return;
      }

      _currentStatus = 'Scanning music files...';
      notifyListeners();

      final files = await MediaStoreService.getMusicFiles();
      
      if (files.isEmpty) {
        _error = 'No music files found';
        _currentStatus = 'No music found';
        _isScanning = false;
        _isComplete = true;
      } else {
        _musicFiles = files;
        _currentStatus = 'Found ${files.length} files';
        _isScanning = false;
        _isComplete = true;
      }
      
      notifyListeners();
      debugPrint('Scan complete, found ${_musicFiles.length} files');
    } catch (e) {
      _handleError(e);
    }
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
    if (_isScanning) return false;
    
    try {
      _currentStatus = 'Requesting permissions...';
      notifyListeners();
      
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _handleError('Storage permission denied');
        return false;
      }

      await scanMusicFiles(forceRescan: forceRescan);
      return true;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  // Get music file info by ID
  Map<String, dynamic>? getMusicFileInfo(String id) {
    return _musicFiles.firstWhere(
      (file) => file['_id'].toString() == id,
      orElse: () => {},
    );
  }
} 