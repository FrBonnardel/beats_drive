import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MusicScannerService {
  static final List<String> _musicExtensions = [
    '.mp3', '.m4a', '.wav', '.aac', '.ogg', '.flac'
  ];

  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 10 (API level 29) and above
      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }
      
      // For Android 9 (API level 28) and below
      if (await Permission.storage.request().isGranted) {
        return true;
      }

      // If permissions are denied, check if we need to show rationale
      if (await Permission.storage.status.isDenied) {
        // Show rationale dialog
        return false;
      }
    }
    return false;
  }

  static Future<List<String>> scanMusicFiles() async {
    List<String> musicFiles = [];
    
    try {
      if (Platform.isAndroid) {
        // For Android 10+ we need to use specific directories
        final musicDir = Directory('/storage/emulated/0/Music');
        final downloadDir = Directory('/storage/emulated/0/Download');
        
        if (await musicDir.exists()) {
          try {
            final files = await _scanDirectory(musicDir.path);
            musicFiles.addAll(files);
            print('Found ${files.length} music files in Music directory');
          } catch (e) {
            print('Error scanning Music directory: $e');
          }
        } else {
          print('Music directory does not exist');
        }

        if (await downloadDir.exists()) {
          try {
            final files = await _scanDirectory(downloadDir.path);
            musicFiles.addAll(files);
            print('Found ${files.length} music files in Download directory');
          } catch (e) {
            print('Error scanning Download directory: $e');
          }
        } else {
          print('Download directory does not exist');
        }

        // Try to get additional storage directories
        final externalDirs = await getExternalStorageDirectories();
        if (externalDirs != null) {
          for (var dir in externalDirs) {
            try {
              final files = await _scanDirectory(dir.path);
              musicFiles.addAll(files);
              print('Found ${files.length} music files in external directory ${dir.path}');
            } catch (e) {
              print('Error scanning external directory ${dir.path}: $e');
            }
          }
        }
      } else {
        // For iOS and other platforms
        final documentsDir = await getExternalStorageDirectory();
        if (documentsDir != null) {
          musicFiles.addAll(await _scanDirectory(documentsDir.path));
        }
      }

      print('Total music files found: ${musicFiles.length}');
    } catch (e) {
      print('Error scanning music files: $e');
    }

    return musicFiles;
  }

  static Future<List<String>> _scanDirectory(String path) async {
    List<String> musicFiles = [];
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        print('Directory does not exist: $path');
        return musicFiles;
      }

      await for (var entity in dir.list(recursive: true)) {
        if (entity is File) {
          final extension = entity.path.toLowerCase();
          if (_musicExtensions.any((ext) => extension.endsWith(ext))) {
            musicFiles.add(entity.path);
          }
        }
      }
    } catch (e) {
      print('Error scanning directory $path: $e');
    }
    return musicFiles;
  }

  static Future<Map<String, dynamic>> getMusicFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('File does not exist: $filePath');
        return {};
      }

      final stat = await file.stat();
      return {
        'path': filePath,
        'name': file.path.split('/').last,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
        'extension': file.path.split('.').last.toLowerCase(),
      };
    } catch (e) {
      print('Error getting file info for $filePath: $e');
      return {};
    }
  }
} 