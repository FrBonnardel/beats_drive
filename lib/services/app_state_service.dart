import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppStateService {
  static const String _lastScreenKey = 'last_screen';
  static const String _lastPlaylistKey = 'last_playlist';
  static const String _lastSongKey = 'last_song';
  static const String _lastPositionKey = 'last_position';
  static const String _isPlayingKey = 'is_playing';
  static const String _shuffleEnabledKey = 'shuffle_enabled';
  static const String _repeatEnabledKey = 'repeat_enabled';

  static Future<void> saveAppState({
    required String lastScreen,
    required List<String> playlist,
    required String currentSong,
    required Duration position,
    required bool isPlaying,
    required bool isShuffleEnabled,
    required bool isRepeatEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastScreenKey, lastScreen);
    await prefs.setStringList(_lastPlaylistKey, playlist);
    await prefs.setString(_lastSongKey, currentSong);
    await prefs.setInt(_lastPositionKey, position.inSeconds);
    await prefs.setBool(_isPlayingKey, isPlaying);
    await prefs.setBool(_shuffleEnabledKey, isShuffleEnabled);
    await prefs.setBool(_repeatEnabledKey, isRepeatEnabled);
  }

  static Future<Map<String, dynamic>> getAppState() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'lastScreen': prefs.getString(_lastScreenKey) ?? 'home',
      'playlist': prefs.getStringList(_lastPlaylistKey) ?? [],
      'currentSong': prefs.getString(_lastSongKey),
      'position': Duration(seconds: prefs.getInt(_lastPositionKey) ?? 0),
      'isPlaying': prefs.getBool(_isPlayingKey) ?? false,
      'isShuffleEnabled': prefs.getBool(_shuffleEnabledKey) ?? false,
      'isRepeatEnabled': prefs.getBool(_repeatEnabledKey) ?? false,
    };
  }

  static Future<void> clearAppState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastScreenKey);
    await prefs.remove(_lastPlaylistKey);
    await prefs.remove(_lastSongKey);
    await prefs.remove(_lastPositionKey);
    await prefs.remove(_isPlayingKey);
    await prefs.remove(_shuffleEnabledKey);
    await prefs.remove(_repeatEnabledKey);
  }
} 