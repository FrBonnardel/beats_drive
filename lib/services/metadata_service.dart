import 'dart:io';
import 'package:just_audio/just_audio.dart';

class MetadataService {
  static Future<Map<String, dynamic>> getMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {};
      }

      final player = AudioPlayer();
      final audioSource = AudioSource.file(filePath);
      await player.setAudioSource(audioSource);
      await player.load();
      
      // Get the filename as title
      final fileName = file.path.split('/').last;
      
      return {
        'title': fileName,
        'artist': '',
        'album': '',
        'year': 0,
        'genre': '',
        'comment': '',
        'track': 0,
        'albumArt': null,
        'mimeType': null,
      };
    } catch (e) {
      print('Error reading metadata: $e');
      return {};
    }
  }
} 