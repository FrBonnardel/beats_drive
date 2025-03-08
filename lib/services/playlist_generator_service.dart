import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class PlaylistGeneratorService {
  static const String _lastGeneratedDateKey = 'last_generated_date';
  static const String _lastPlaylistKey = 'daily_playlist';
  static const String _playedSongsKey = 'played_songs';

  static Future<List<String>> generateDailyPlaylist(List<String> allSongs) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final lastGeneratedDate = DateTime.parse(
      prefs.getString(_lastGeneratedDateKey) ?? DateTime(2000).toIso8601String(),
    );

    // Check if we need to generate a new playlist
    if (!_isSameDay(today, lastGeneratedDate)) {
      return await _generateNewPlaylist(allSongs, prefs);
    }

    // Return existing playlist if it exists
    final existingPlaylist = prefs.getStringList(_lastPlaylistKey);
    if (existingPlaylist != null && existingPlaylist.isNotEmpty) {
      return existingPlaylist;
    }

    // Generate new playlist if none exists
    return await _generateNewPlaylist(allSongs, prefs);
  }

  static Future<List<String>> _generateNewPlaylist(
    List<String> allSongs,
    SharedPreferences prefs,
  ) async {
    // Create a seeded random number generator using today's date
    final seed = _getDateSeed(DateTime.now());
    final random = Random(seed);

    // Create a copy of the songs list and shuffle it
    final shuffledSongs = List<String>.from(allSongs);
    _shuffleWithSeed(shuffledSongs, random);

    // Save the new playlist and date
    await prefs.setStringList(_lastPlaylistKey, shuffledSongs);
    await prefs.setString(_lastGeneratedDateKey, DateTime.now().toIso8601String());
    await prefs.setStringList(_playedSongsKey, []); // Reset played songs

    return shuffledSongs;
  }

  static int _getDateSeed(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  static void _shuffleWithSeed(List<String> list, Random random) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }

  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  static Future<void> markSongAsPlayed(String songPath) async {
    final prefs = await SharedPreferences.getInstance();
    final playedSongs = prefs.getStringList(_playedSongsKey) ?? [];
    if (!playedSongs.contains(songPath)) {
      playedSongs.add(songPath);
      await prefs.setStringList(_playedSongsKey, playedSongs);
    }
  }

  static Future<List<String>> getRemainingSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final playlist = prefs.getStringList(_lastPlaylistKey) ?? [];
    final playedSongs = prefs.getStringList(_playedSongsKey) ?? [];
    return playlist.where((song) => !playedSongs.contains(song)).toList();
  }

  static Future<bool> hasUnplayedSongs() async {
    final remainingSongs = await getRemainingSongs();
    return remainingSongs.isNotEmpty;
  }

  static Future<void> resetPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastGeneratedDateKey);
    await prefs.remove(_lastPlaylistKey);
    await prefs.remove(_playedSongsKey);
  }
} 