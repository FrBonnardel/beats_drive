import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackStateService {
  static const String _lastPlayedKey = 'last_played';
  static const String _lastPositionKey = 'last_position';
  static const String _isPlayingKey = 'is_playing';

  static Future<void> savePlaybackState({
    required String currentSong,
    required Duration position,
    required bool isPlaying,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPlayedKey, currentSong);
    await prefs.setInt(_lastPositionKey, position.inSeconds);
    await prefs.setBool(_isPlayingKey, isPlaying);
  }

  static Future<Map<String, dynamic>> getPlaybackState() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'currentSong': prefs.getString(_lastPlayedKey),
      'position': Duration(seconds: prefs.getInt(_lastPositionKey) ?? 0),
      'isPlaying': prefs.getBool(_isPlayingKey) ?? false,
    };
  }

  static Future<void> clearPlaybackState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPlayedKey);
    await prefs.remove(_lastPositionKey);
    await prefs.remove(_isPlayingKey);
  }
} 