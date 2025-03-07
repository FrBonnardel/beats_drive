import 'package:flutter/foundation.dart';
import '../services/music_scanner_service.dart';

class MusicProvider with ChangeNotifier {
  List<String> _musicFiles = [];
  bool _isScanning = false;
  String _error = '';

  List<String> get musicFiles => _musicFiles;
  bool get isScanning => _isScanning;
  String get error => _error;

  Future<void> scanMusicFiles() async {
    _isScanning = true;
    _error = '';
    notifyListeners();

    try {
      final hasPermission = await MusicScannerService.requestStoragePermission();
      if (!hasPermission) {
        _error = 'Storage permission denied. Please grant permission in Settings to access your music files.';
        _isScanning = false;
        notifyListeners();
        return;
      }

      _musicFiles = await MusicScannerService.scanMusicFiles();
      if (_musicFiles.isEmpty) {
        _error = 'No music files found. Make sure you have music files in your device.';
      } else {
        _error = '';
      }
    } catch (e) {
      _error = 'Error scanning music files: $e';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getMusicFileInfo(String filePath) async {
    return await MusicScannerService.getMusicFileInfo(filePath);
  }
} 