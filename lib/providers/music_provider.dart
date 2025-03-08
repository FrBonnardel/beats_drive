import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/media_store_service.dart';
import '../models/music_models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import '../providers/audio_provider.dart';
import 'dart:io';

enum MusicScanStatus {
  initial,
  requestingPermissions,
  scanning,
  completed,
  error,
  noPermission,
}

enum SortOption {
  titleAsc,
  titleDesc,
  artistAsc,
  artistDesc,
  albumAsc,
  albumDesc,
  dateAddedAsc,
  dateAddedDesc,
  durationAsc,
  durationDesc,
}

class MusicProvider extends ChangeNotifier {
  final AudioProvider? _audioProvider;
  List<Song> _songs = [];
  List<Album> _albums = [];
  List<Artist> _artists = [];
  List<Playlist> _playlists = [];
  MusicScanStatus _status = MusicScanStatus.initial;
  String _error = '';
  String _currentStatus = '';
  bool _isComplete = false;
  SortOption _currentSortOption = SortOption.titleAsc;
  static const _channel = MethodChannel('com.beats_drive/media_store');

  MusicProvider({AudioProvider? audioProvider}) : _audioProvider = audioProvider {
    MediaStoreService.platform.setMethodCallHandler((call) async {
      if (call.method == 'onMediaStoreChanged') {
        debugPrint('Media store changed, refreshing music files');
        await scanMusicFiles(forceRescan: true);
      }
    });
  }

  // Getters
  List<Song> get songs => _songs;
  List<Album> get albums => _albums;
  List<Artist> get artists => _artists;
  List<Playlist> get playlists => _playlists;
  bool get isScanning => _status == MusicScanStatus.scanning;
  String get error => _error;
  String get currentStatus => _currentStatus;
  bool get isComplete => _isComplete;
  SortOption get currentSortOption => _currentSortOption;

  Future<bool> requestPermissionAndScan({bool forceRescan = false}) async {
    if (_status == MusicScanStatus.scanning) return false;
    
    try {
      _status = MusicScanStatus.requestingPermissions;
      _isComplete = false;
      _error = '';
      _currentStatus = 'Requesting permissions...';
      notifyListeners();

      // Check Android version for appropriate permission request
      if (Platform.isAndroid) {
        if (await _requestAndroidPermissions() == false) {
          return false;
        }
      }

      await scanMusicFiles(forceRescan: forceRescan);
      return true;
    } catch (e) {
      await _handleError('Failed to scan music files: $e');
      return false;
    }
  }

  Future<bool> _requestAndroidPermissions() async {
    // For Android 13+ (API 33), we need READ_MEDIA_AUDIO permission
    if (await Permission.audio.status.isDenied) {
      final status = await Permission.audio.request();
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          await _handleError(
            'Audio permission permanently denied. Please enable it in Settings:\n'
            'Settings > Apps > Beats Drive > Permissions > Storage'
          );
        } else {
          await _handleError(
            'Audio permission denied. The app needs access to your music files.'
          );
        }
        _status = MusicScanStatus.noPermission;
        return false;
      }
    }

    // For Android 10-12, we need READ_EXTERNAL_STORAGE permission
    if (!await Permission.audio.isGranted) {
      if (await Permission.storage.status.isDenied) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (status.isPermanentlyDenied) {
            await _handleError(
              'Storage permission permanently denied. Please enable it in Settings:\n'
              'Settings > Apps > Beats Drive > Permissions > Storage'
            );
          } else {
            await _handleError(
              'Storage permission denied. The app needs access to your music files.'
            );
          }
          _status = MusicScanStatus.noPermission;
          return false;
        }
      }
    }

    return true;
  }

  Future<void> scanMusicFiles({bool forceRescan = false}) async {
    if (_status == MusicScanStatus.scanning) return;
    
    debugPrint('Starting music scan (forceRescan: $forceRescan)');
    _status = MusicScanStatus.scanning;
    _isComplete = false;
    _error = '';
    _currentStatus = 'Scanning music files...';
    notifyListeners();

    try {
      final List<dynamic>? files = await _channel.invokeMethod('queryMusicFiles');
      
      if (files == null || files.isEmpty) {
        _error = 'No music files found';
        _currentStatus = 'No music found';
        _status = MusicScanStatus.completed;
        _isComplete = true;
        notifyListeners();
        return;
      }

      debugPrint('Found ${files.length} music files');
      await _processMusicFiles(files);
      _currentStatus = 'Found ${_songs.length} files';
      debugPrint('Successfully processed ${_songs.length} music files');
      _status = MusicScanStatus.completed;
      _isComplete = true;
      notifyListeners();
    } on PlatformException catch (e) {
      debugPrint('Platform error scanning music files: $e');
      await _handleError('Failed to access music files: ${e.message}');
    } catch (e) {
      debugPrint('Error scanning music files: $e');
      await _handleError('Failed to scan music files: $e');
    }
  }

  Future<void> _processMusicFiles(List<dynamic> musicFiles) async {
    debugPrint('Processing ${musicFiles.length} music files');
    _songs.clear();
    _albums.clear();
    _artists.clear();

    final Map<String, Album> albumMap = {};
    final Map<String, List<Album>> artistAlbums = {};

    for (final file in musicFiles) {
      try {
        debugPrint('Processing file: ${file['title']} - URI: ${file['uri']}');
        final song = Song.fromMap(Map<String, dynamic>.from(file));
        _songs.add(song);

        // Create or update album
        final albumKey = '${song.album}_${song.artist}';
        if (!albumMap.containsKey(albumKey)) {
          albumMap[albumKey] = Album(
            id: albumKey,
            name: song.album,
            artist: song.artist,
            songs: [],
            year: song.year,
            albumArtUri: song.albumArtUri,
          );
        }
        albumMap[albumKey]!.songs.add(song);

        // Group albums by artist
        if (!artistAlbums.containsKey(song.artist)) {
          artistAlbums[song.artist] = [];
        }
        if (!artistAlbums[song.artist]!.contains(albumMap[albumKey])) {
          artistAlbums[song.artist]!.add(albumMap[albumKey]!);
        }
      } catch (e) {
        debugPrint('Error processing music file: $e');
        continue;
      }
    }

    debugPrint('Processed ${_songs.length} songs successfully');

    // Create artists and update collections
    _albums = albumMap.values.toList();
    _artists = artistAlbums.entries.map((entry) {
      final artistName = entry.key;
      final albums = entry.value;
      final songs = albums.expand((album) => album.songs).toList();
      
      return Artist(
        id: artistName,
        name: artistName,
        albums: albums,
        songs: songs,
      );
    }).toList();

    // Sort everything
    _songs.sort((a, b) => a.title.compareTo(b.title));
    _albums.sort((a, b) => a.name.compareTo(b.name));
    _artists.sort((a, b) => a.name.compareTo(b.name));

    // Sort songs within albums
    for (final album in _albums) {
      album.songs.sort((a, b) => (a.trackNumber).compareTo(b.trackNumber));
    }
  }

  void _organizeMusic() {
    // Group songs by album
    final albumGroups = groupBy(_songs, (Song s) => '${s.album}_${s.artist}');
    _albums = albumGroups.entries.map((entry) {
      final songs = entry.value;
      final firstSong = songs.first;
      return Album(
        id: entry.key,
        name: firstSong.album,
        artist: firstSong.artist,
        artwork: null, // We'll load this later when needed
        songs: songs,
        year: firstSong.year,
      );
    }).toList();

    // Group songs by artist
    final artistGroups = groupBy(_songs, (Song s) => s.artist);
    _artists = artistGroups.entries.map((entry) {
      final songs = entry.value;
      final artistAlbums = _albums.where((album) => album.artist == entry.key).toList();
      return Artist(
        id: entry.key,
        name: entry.key,
        albums: artistAlbums,
        songs: songs,
      );
    }).toList();
  }

  void setSortOption(SortOption option) {
    _currentSortOption = option;
    _sortMusic(option);
    notifyListeners();
  }

  void _sortMusic(SortOption option) {
    switch (option) {
      case SortOption.titleAsc:
        _songs.sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
        break;
      case SortOption.titleDesc:
        _songs.sort((a, b) => b.displayTitle.compareTo(a.displayTitle));
        break;
      case SortOption.artistAsc:
        _songs.sort((a, b) => a.displayArtist.compareTo(b.displayArtist));
        break;
      case SortOption.artistDesc:
        _songs.sort((a, b) => b.displayArtist.compareTo(a.displayArtist));
        break;
      case SortOption.albumAsc:
        _songs.sort((a, b) => a.displayAlbum.compareTo(b.displayAlbum));
        break;
      case SortOption.albumDesc:
        _songs.sort((a, b) => b.displayAlbum.compareTo(a.displayAlbum));
        break;
      case SortOption.dateAddedDesc:
        _songs.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case SortOption.dateAddedAsc:
        _songs.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case SortOption.durationAsc:
        _songs.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case SortOption.durationDesc:
        _songs.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }
  }

  Future<void> _handleError(dynamic error) async {
    debugPrint('Error: $error');
    _error = error.toString();
    _currentStatus = 'Error occurred';
    _status = MusicScanStatus.error;
    notifyListeners();
  }

  // Playlist Management
  Future<void> createPlaylist(String name) async {
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      songs: [],
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
    _playlists.add(playlist);
    notifyListeners();
    // TODO: Persist playlist
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((playlist) => playlist.id == playlistId);
    notifyListeners();
    // TODO: Remove from persistence
  }

  Future<void> addToPlaylist(String playlistId, Song song) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final playlist = _playlists[playlistIndex];
      if (!playlist.songs.contains(song)) {
        _playlists[playlistIndex] = playlist.copyWith(
          songs: [...playlist.songs, song],
        );
        notifyListeners();
        // TODO: Update persistence
      }
    }
  }

  Future<void> removeFromPlaylist(String playlistId, Song song) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final playlist = _playlists[playlistIndex];
      _playlists[playlistIndex] = playlist.copyWith(
        songs: playlist.songs.where((s) => s.id != song.id).toList(),
      );
      notifyListeners();
      // TODO: Update persistence
    }
  }

  Future<Uint8List?> loadAlbumArt(String songId) async {
    try {
      if (songId.isEmpty) return null;
      final result = await _channel.invokeMethod('getAlbumArt', {'songId': songId});
      if (result != null) {
        return result as Uint8List;
      }
    } catch (e) {
      debugPrint('Error loading album art: $e');
    }
    return null;
  }

  Future<void> playSong(Song song) async {
    if (_audioProvider == null) return;

    // Get all songs in the current view based on sort option
    List<Song> currentSongs = List.from(_songs);
    _applySorting(currentSongs);

    // Get URIs for all songs
    final uris = currentSongs.map((s) => s.uri).toList();
    
    // Find the index of the selected song
    final selectedIndex = currentSongs.indexWhere((s) => s.uri == song.uri);
    
    // Update the playlist with all URIs
    await _audioProvider!.updatePlaylist(uris);
    
    // Play the selected song
    if (selectedIndex >= 0) {
      await _audioProvider!.selectSong(selectedIndex);
    }
  }

  void _applySorting(List<Song> songs) {
    switch (_currentSortOption) {
      case SortOption.titleAsc:
        songs.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.titleDesc:
        songs.sort((a, b) => b.title.compareTo(a.title));
        break;
      case SortOption.artistAsc:
        songs.sort((a, b) => a.artist.compareTo(b.artist));
        break;
      case SortOption.artistDesc:
        songs.sort((a, b) => b.artist.compareTo(a.artist));
        break;
      case SortOption.albumAsc:
        songs.sort((a, b) => a.album.compareTo(b.album));
        break;
      case SortOption.albumDesc:
        songs.sort((a, b) => b.album.compareTo(a.album));
        break;
      case SortOption.dateAddedAsc:
        songs.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case SortOption.dateAddedDesc:
        songs.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case SortOption.durationAsc:
        songs.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case SortOption.durationDesc:
        songs.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }
  }

  Future<void> playAlbum(Album album) async {
    if (_audioProvider == null) return;

    // Get URIs for all songs in the album
    final uris = album.songs.map((s) => s.uri).toList();
    
    // Update the playlist with album URIs
    await _audioProvider!.updatePlaylist(uris);
    
    // Start playing from the first song
    await _audioProvider!.selectSong(0);
  }
} 