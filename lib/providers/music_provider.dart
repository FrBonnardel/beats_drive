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
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';
import '../services/cache_service.dart';
import '../services/background_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:isolate';

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
  final CacheService _cacheService;
  List<Song> _songs = [];
  List<Album> _albums = [];
  List<Artist> _artists = [];
  List<Playlist> _playlists = [];
  MusicScanStatus _status = MusicScanStatus.initial;
  String? _error;
  String _currentStatus = 'Loading...';
  bool _isComplete = false;
  SortOption _currentSortOption = SortOption.titleAsc;
  static const _channel = MethodChannel('com.beats_drive/media_store');
  
  // Add caches
  final Map<String, Uint8List?> _albumArtCache = {};
  final Map<String, Song> _songByUriCache = {};
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  final _backgroundScanCompleter = Completer<void>();
  final _songUpdateController = StreamController<Song>.broadcast();

  MusicProvider(this._cacheService) {
    _initializeCache();
    MediaStoreService.platform.setMethodCallHandler((call) async {
      if (call.method == 'onMediaStoreChanged') {
        debugPrint('Media store changed, refreshing music files');
        _clearCaches();
        await scanMusicFiles(forceRescan: true);
      }
    });
  }

  void _clearCaches() {
    _albumArtCache.clear();
    _songByUriCache.clear();
  }

  // Add method to get song by URI with caching
  Future<Song> getSongByUri(String uri) async {
    debugPrint('MusicProvider: Getting song for URI: $uri');
    
    // Check cache first
    if (_songByUriCache.containsKey(uri)) {
      final cachedSong = _songByUriCache[uri]!;
      debugPrint('MusicProvider: Found song in cache:');
      debugPrint('  - Title: ${cachedSong.title}');
      debugPrint('  - Artist: ${cachedSong.artist}');
      debugPrint('  - Album: ${cachedSong.album}');
      debugPrint('  - Album ID: ${cachedSong.albumId}');
      return cachedSong;
    }

    // Try to find song in songs list
    final song = _songs.firstWhereOrNull((s) => s.uri == uri);
    if (song != null) {
      debugPrint('MusicProvider: Found song in songs list:');
      debugPrint('  - Title: ${song.title}');
      debugPrint('  - Artist: ${song.artist}');
      debugPrint('  - Album: ${song.album}');
      debugPrint('  - Album ID: ${song.albumId}');
      _songByUriCache[uri] = song;
      return song;
    }

    // If not found, get metadata from MediaStore
    debugPrint('MusicProvider: Getting metadata from MediaStore for URI: $uri');
    try {
      final metadata = await MediaStoreService.getSongMetadata(uri);
      
      if (metadata != null) {
        final song = Song(
          id: metadata['_id']?.toString() ?? '',
          title: metadata['title']?.toString() ?? 'Unknown Title',
          artist: metadata['artist']?.toString() ?? 'Unknown Artist',
          album: metadata['album']?.toString() ?? 'Unknown Album',
          albumId: metadata['album_id']?.toString() ?? '',
          duration: metadata['duration'] as int? ?? 0,
          uri: uri,
          trackNumber: metadata['track'] as int? ?? 0,
          year: metadata['year'] as int? ?? 0,
          dateAdded: metadata['date_added'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          albumArtUri: '',
        );
        
        debugPrint('MusicProvider: Created song from MediaStore:');
        debugPrint('  - Title: ${song.title}');
        debugPrint('  - Artist: ${song.artist}');
        debugPrint('  - Album: ${song.album}');
        debugPrint('  - Album ID: ${song.albumId}');
        
        _songByUriCache[uri] = song;
        return song;
      }
    } catch (e) {
      debugPrint('Error getting metadata from MediaStore: $e');
    }

    // If all else fails, create a basic song
    debugPrint('MusicProvider: Creating basic song info for URI: $uri');
    final basicSong = Song(
      id: '',
      title: 'Unknown Title',
      artist: 'Unknown Artist',
      album: 'Unknown Album',
      albumId: '',
      duration: 0,
      uri: uri,
      trackNumber: 0,
      year: 0,
      dateAdded: DateTime.now().millisecondsSinceEpoch,
      albumArtUri: '',
    );
    
    _songByUriCache[uri] = basicSong;
    return basicSong;
  }

  Future<List<Song>> getSongsByUris(List<String> uris) async {
    final List<Song> result = [];
    final List<String> uncachedUris = [];
    
    // First check cache for all URIs
    for (final uri in uris) {
      if (_songByUriCache.containsKey(uri)) {
        result.add(_songByUriCache[uri]!);
      } else {
        uncachedUris.add(uri);
      }
    }

    if (uncachedUris.isEmpty) {
      return result;
    }

    // Batch load metadata for uncached songs
    try {
      final metadataList = await MediaStoreService.getSongsMetadata(uncachedUris);
      for (var i = 0; i < uncachedUris.length; i++) {
        final uri = uncachedUris[i];
        final metadata = metadataList[i];
        
        if (metadata != null) {
          final song = Song(
            id: metadata['_id']?.toString() ?? '',
            title: metadata['title']?.toString() ?? 'Unknown Title',
            artist: metadata['artist']?.toString() ?? 'Unknown Artist',
            album: metadata['album']?.toString() ?? 'Unknown Album',
            albumId: metadata['album_id']?.toString() ?? '',
            duration: metadata['duration'] as int? ?? 0,
            uri: uri,
            trackNumber: metadata['track'] as int? ?? 0,
            year: metadata['year'] as int? ?? 0,
            dateAdded: metadata['date_added'] as int? ?? DateTime.now().millisecondsSinceEpoch,
            albumArtUri: '',
          );
          
          _songByUriCache[uri] = song;
          result.add(song);
        } else {
          // Create basic song if metadata not found
          final basicSong = Song(
            id: '',
            title: 'Unknown Title',
            artist: 'Unknown Artist',
            album: 'Unknown Album',
            albumId: '',
            duration: 0,
            uri: uri,
            trackNumber: 0,
            year: 0,
            dateAdded: DateTime.now().millisecondsSinceEpoch,
            albumArtUri: '',
          );
          _songByUriCache[uri] = basicSong;
          result.add(basicSong);
        }
      }
    } catch (e) {
      debugPrint('Error batch loading song metadata: $e');
    }

    return result;
  }

  // Getters
  List<Song> get songs => _songs;
  List<Album> get albums => _albums;
  List<Artist> get artists => _artists;
  List<Playlist> get playlists => _playlists;
  bool get isScanning => _status == MusicScanStatus.scanning;
  String get error => _error ?? '';
  String get currentStatus => _currentStatus;
  bool get isComplete => _isComplete;
  SortOption get currentSortOption => _currentSortOption;

  Future<void> _initializeCache() async {
    await _cacheService.initialize();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    final cachedSongs = _cacheService.getCachedSongs();
    if (cachedSongs.isNotEmpty) {
      _songs = cachedSongs;
      _updateCollections();
      notifyListeners();
    }
  }

  Future<bool> requestPermissionAndScan({bool forceRescan = false}) async {
    if (_status == MusicScanStatus.scanning) return false;
    
    try {
      _status = MusicScanStatus.requestingPermissions;
      _isComplete = false;
      _error = null;
      _currentStatus = 'Requesting permissions...';
      notifyListeners();

      bool hasPermission = false;
      
      if (Platform.isAndroid) {
        debugPrint('Requesting Android permissions...');
        hasPermission = await _requestAndroidPermissions();
        if (!hasPermission) {
          debugPrint('Android permissions not granted');
          _status = MusicScanStatus.noPermission;
          _error = 'Storage permission is required to scan music files';
          notifyListeners();
          return false;
        }
        debugPrint('Android permissions granted, starting scan');
        await scanMusicFiles(forceRescan: forceRescan);
      } else {
        // For other platforms, assume permission granted
        hasPermission = true;
        await scanMusicFiles(forceRescan: forceRescan);
      }

      return hasPermission;
    } catch (e) {
      debugPrint('Error in requestPermissionAndScan: $e');
      await _handleError('Failed to scan music files: $e');
      return false;
    }
  }

  Future<bool> _requestAndroidPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidVersion = await _getAndroidVersion();
        debugPrint('Android version: $androidVersion');
        
        if (androidVersion >= 33) {
          // Android 13 and above
          debugPrint('Requesting audio permission for Android 13+');
          final status = await Permission.audio.request();
          debugPrint('Audio permission status: ${status.name}');
          return status.isGranted;
        } else if (androidVersion >= 29) {
          // Android 10-12
          debugPrint('Requesting storage permission for Android 10-12');
          final status = await Permission.storage.request();
          debugPrint('Storage permission status: ${status.name}');
          return status.isGranted;
        } else {
          // Android 9 and below
          debugPrint('Requesting manage external storage permission for Android 9 and below');
          final status = await Permission.manageExternalStorage.request();
          debugPrint('Manage external storage permission status: ${status.name}');
          return status.isGranted;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting Android permissions: $e');
      await _handleError('Error requesting Android permissions: $e');
      return false;
    }
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt;
    }
    return 0;
  }

  Future<void> scanMusicFiles({bool forceRescan = false}) async {
    if (_status == MusicScanStatus.scanning) return;
    
    debugPrint('Starting music scan (forceRescan: $forceRescan)');
    _status = MusicScanStatus.scanning;
    _isComplete = false;
    _error = null;
    _currentStatus = 'Scanning music files...';
    notifyListeners();

    try {
      // Try loading from cache first if not forcing rescan
      if (!forceRescan) {
        _currentStatus = 'Loading cached data...';
        notifyListeners();
        
        final cachedSongs = _cacheService.getCachedSongs();
        if (cachedSongs.isNotEmpty) {
          _songs = cachedSongs;
          _updateCollections();
          _status = MusicScanStatus.completed;
          _isComplete = true;
          _currentStatus = 'Loaded from cache';
          notifyListeners();
          debugPrint('Successfully loaded ${_songs.length} songs from cache');
          return;
        }
      }

      // Subscribe to background service results
      final subscription = BackgroundService.songStream.listen((songs) {
        debugPrint('Received ${songs.length} songs from background service');
        _processMusicFiles(songs);
      }, onError: (error) {
        debugPrint('Error from background service: $error');
        _handleError('Failed to scan music files: $error');
      });

      // Schedule background scan
      await BackgroundService.scheduleMusicScan();

      // Wait for the first result or timeout after 30 seconds
      await Future.delayed(const Duration(seconds: 30));
      subscription.cancel();

      if (_songs.isEmpty) {
        _handleError('No songs found after scanning');
      }

    } catch (e) {
      debugPrint('Error scanning music files: $e');
      await _handleError('Failed to scan music files: $e');
    }
  }

  Future<void> _processMusicFiles(List<Song> songs) async {
    debugPrint('Processing ${songs.length} music files');
    
    // Check if the music library has changed
    final hasChanged = await _cacheService.hasMusicLibraryChanged(songs);
    if (!hasChanged && !_cacheService.shouldRescan()) {
      debugPrint('Music library unchanged, using cached data');
      _songs = _cacheService.getCachedSongs();
      await _updateCollections();
      _status = MusicScanStatus.completed;
      _isComplete = true;
      _currentStatus = 'Loaded from cache';
      notifyListeners();
      return;
    }

    _songs = songs;
    _albums.clear();
    _artists.clear();
    _clearCaches();

    // Process files in chunks to avoid UI blocking
    const chunkSize = 100;
    final Map<String, Album> albumMap = {};
    final Map<String, List<Album>> artistAlbums = {};

    // Process chunks in parallel using isolates
    final chunks = <List<Song>>[];
    for (var i = 0; i < songs.length; i += chunkSize) {
      chunks.add(songs.skip(i).take(chunkSize).toList());
    }

    // Process each chunk in parallel
    final results = await Future.wait(
      chunks.map((chunk) => compute(_processChunk, chunk)),
    );

    // Combine results
    for (final result in results) {
      final chunkAlbumMap = result['albumMap'] as Map<String, Album>;
      final chunkArtistAlbums = result['artistAlbums'] as Map<String, List<Album>>;

      for (final entry in chunkAlbumMap.entries) {
        if (!albumMap.containsKey(entry.key)) {
          albumMap[entry.key] = entry.value;
        } else {
          albumMap[entry.key]!.songs.addAll(entry.value.songs);
        }
      }

      for (final entry in chunkArtistAlbums.entries) {
        if (!artistAlbums.containsKey(entry.key)) {
          artistAlbums[entry.key] = entry.value;
        } else {
          artistAlbums[entry.key]!.addAll(entry.value);
        }
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
    _sortMusic(_currentSortOption);

    // Cache the processed data
    await _cacheService.cacheSongs(_songs);

    // Update status
    _status = MusicScanStatus.completed;
    _isComplete = true;
    _currentStatus = 'Scan completed';
    notifyListeners();
  }

  // Process a chunk of songs in a separate isolate
  static Map<String, dynamic> _processChunk(List<Song> chunk) {
    final Map<String, Album> albumMap = {};
    final Map<String, List<Album>> artistAlbums = {};

    for (final song in chunk) {
      try {
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

    return {
      'albumMap': albumMap,
      'artistAlbums': artistAlbums,
    };
  }

  Future<void> _updateCollections() async {
    // Process collections in a separate isolate
    final result = await compute(_processCollections, _songs);
    
    _albums = result['albums'] as List<Album>;
    _artists = result['artists'] as List<Artist>;
    
    // Sort everything
    _sortMusic(_currentSortOption);
  }

  // Process collections in a separate isolate
  static Map<String, dynamic> _processCollections(List<Song> songs) {
    final Map<String, Album> albumMap = {};
    final Map<String, List<Album>> artistAlbums = {};

    for (final song in songs) {
      try {
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

    // Create artists
    final artists = artistAlbums.entries.map((entry) {
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

    return {
      'albums': albumMap.values.toList(),
      'artists': artists,
    };
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
        songs: songs,
        year: firstSong.year,
        albumArtUri: firstSong.albumArtUri,
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
    if (songId.isEmpty) return null;

    // Check memory cache first
    if (_albumArtCache.containsKey(songId)) {
      debugPrint('MusicProvider: Found album art in memory cache for song: $songId');
      return _albumArtCache[songId];
    }

    // Check disk cache
    final cachedArt = await _cacheService.getCachedAlbumArt(songId);
    if (cachedArt != null) {
      debugPrint('MusicProvider: Found album art in disk cache for song: $songId');
      final uint8List = Uint8List.fromList(cachedArt);
      _albumArtCache[songId] = uint8List;
      return uint8List;
    }

    // Load from MediaStore
    try {
      final song = _songs.firstWhereOrNull((s) => s.id == songId);
      if (song == null) {
        debugPrint('MusicProvider: Song not found for ID: $songId');
        return null;
      }

      debugPrint('MusicProvider: Loading album art from MediaStore for song: ${song.title}');
      final albumArt = await MediaStoreService.getAlbumArt(song.id);
      
      if (albumArt != null) {
        debugPrint('MusicProvider: Successfully loaded album art from MediaStore');
        // Cache the album art
        await _cacheService.cacheAlbumArt(songId, albumArt.toList());
        _albumArtCache[songId] = albumArt;
        return albumArt;
      } else {
        debugPrint('MusicProvider: No album art found in MediaStore');
        return null;
      }
    } catch (e) {
      debugPrint('Error loading album art: $e');
      return null;
    }
  }

  Future<void> playSong(BuildContext context, Song song) async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    debugPrint('Attempting to play song: ${song.title} (URI: ${song.uri})');

    // Stop any current playback
    await audioProvider.stop();

    // Load the selected song's metadata first
    final selectedSong = await getSongByUri(song.uri);
    audioProvider.currentSongNotifier.value = selectedSong;

    // Get all songs in the current view based on sort option
    List<Song> currentSongs = List.from(_songs);
    debugPrint('Total songs in current view: ${currentSongs.length}');
    _applySorting(currentSongs);

    // Get URIs for all songs
    final uris = currentSongs.map((s) => s.uri).toList();
    debugPrint('First few URIs in playlist:');
    for (var i = 0; i < min(3, uris.length); i++) {
      debugPrint('[$i]: ${uris[i]}');
    }
    
    // Find the index of the selected song
    final selectedIndex = currentSongs.indexWhere((s) => s.uri == song.uri);
    debugPrint('Selected song index: $selectedIndex');
    
    if (selectedIndex >= 0) {
      // Update the playlist with all URIs
      debugPrint('Updating playlist in AudioProvider...');
      await audioProvider.updatePlaylist(uris);
      
      // Play the selected song
      debugPrint('Playing song at index $selectedIndex');
      await audioProvider.selectSong(selectedIndex);
    } else {
      debugPrint('Error: Could not find selected song in playlist');
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

  Future<void> playAlbum(BuildContext context, Album album) async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);

    // Get URIs for all songs in the album
    final uris = album.songs.map((s) => s.uri).toList();
    
    // Update the playlist with album URIs
    await audioProvider.updatePlaylist(uris);
    
    // Start playing from the first song
    await audioProvider.selectSong(0);
  }

  Future<void> loadFromCache() async {
    debugPrint('Loading songs from cache...');
    try {
      final cachedSongs = _cacheService.getCachedSongs();
      if (cachedSongs.isNotEmpty) {
        _songs = cachedSongs;
        _updateCollections();
        _status = MusicScanStatus.completed;
        _isComplete = true;
        _currentStatus = 'Loaded from cache';
        notifyListeners();
        debugPrint('Successfully loaded ${_songs.length} songs from cache');
        return;
      }
      debugPrint('No songs found in cache');
    } catch (e) {
      debugPrint('Error loading from cache: $e');
      _status = MusicScanStatus.error;
      _error = 'Failed to load cached songs';
      notifyListeners();
    }
  }

  Stream<Song> get onSongUpdated => _songUpdateController.stream;

  Future<List<Song>> getQuickMediaStoreInfo({int page = 0, int pageSize = 20}) async {
    try {
      // First check the cache for this page
      final cachedSongs = await _cacheService.getCachedSongsForPage(page, pageSize);
      if (cachedSongs.isNotEmpty) {
        if (page == 0) {
          _songs = cachedSongs;
        } else {
          _songs.addAll(cachedSongs);
        }
        return cachedSongs;
      }

      // If no cache, get quick info from MediaStore with pagination
      final songsList = await MediaStoreService.getSongsForPage(page, pageSize);
      
      final newSongs = songsList.map((song) => Song(
        id: song['_id']?.toString() ?? '',
        title: song['title']?.toString() ?? 'Unknown Title',
        artist: song['artist']?.toString() ?? 'Unknown Artist',
        album: song['album']?.toString() ?? 'Unknown Album',
        albumId: song['album_id']?.toString() ?? '',
        duration: song['duration'] as int? ?? 0,
        uri: song['_data']?.toString() ?? '',
        albumArtUri: '',  // Will be loaded lazily
        trackNumber: song['track'] as int? ?? 0,
        year: song['year'] as int? ?? 0,
        dateAdded: song['date_added'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      )).toList();

      // Cache the basic song info for this page
      await _cacheService.cacheSongsForPage(page, newSongs);
      
      if (page == 0) {
        _songs = newSongs;
      } else {
        _songs.addAll(newSongs);
      }
      
      return newSongs;
    } catch (e) {
      debugPrint('Error getting quick MediaStore info: $e');
      _hasError = true;
      _errorMessage = e.toString();
      return [];
    }
  }

  Future<int> getTotalSongCount() async {
    try {
      return await MediaStoreService.getTotalSongCount();
    } catch (e) {
      debugPrint('Error getting total song count: $e');
      return 0;
    }
  }

  Future<void> startBackgroundScan({
    int batchSize = 50,
    Duration delayBetweenBatches = const Duration(milliseconds: 500),
    int maxConcurrentOperations = 2,
  }) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final totalSongs = _songs.length;
      var processedCount = 0;
      final batches = <List<Song>>[];

      // Split songs into batches
      for (var i = 0; i < totalSongs; i += batchSize) {
        batches.add(_songs.skip(i).take(batchSize).toList());
      }

      // Process batches with limited concurrency
      final activeFutures = <Future>[];
      
      for (final batch in batches) {
        // Wait if we've reached max concurrent operations
        while (activeFutures.length >= maxConcurrentOperations) {
          await Future.wait(activeFutures.take(1));
          activeFutures.removeAt(0);
        }

        // Process batch
        final future = Future(() async {
          await _processBatch(batch);
          processedCount += batch.length;
          
          // Notify progress
          debugPrint('Processed $processedCount of $totalSongs songs');
          
          // Add delay between batches
          await Future.delayed(delayBetweenBatches);
        });

        activeFutures.add(future);
      }

      // Wait for remaining operations to complete
      await Future.wait(activeFutures);
      
      // Update collections and notify listeners
      await _updateCollections();
      _backgroundScanCompleter.complete();
    } catch (e) {
      debugPrint('Error in background scan: $e');
      _hasError = true;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _processBatch(List<Song> songs) async {
    for (final song in songs) {
      try {
        // Load and cache album art
        final albumArt = await MediaStoreService.getAlbumArt(song.id);
        if (albumArt != null) {
          await _cacheService.cacheAlbumArt(song.id, albumArt.toList());
          _albumArtCache[song.id] = albumArt;
        }

        // Load and cache full metadata
        final metadata = await MediaStoreService.getSongMetadata(song.uri);
        if (metadata != null) {
          final updatedSong = song.copyWith(
            title: metadata['title']?.toString() ?? song.title,
            artist: metadata['artist']?.toString() ?? song.artist,
            album: metadata['album']?.toString() ?? song.album,
            albumId: metadata['album_id']?.toString() ?? song.albumId,
            duration: metadata['duration'] as int? ?? song.duration,
            trackNumber: metadata['track'] as int? ?? song.trackNumber,
            year: metadata['year'] as int? ?? song.year,
          );

          // Update song in cache
          _songByUriCache[song.uri] = updatedSong;
          
          // Update song in main list
          final index = _songs.indexWhere((s) => s.id == song.id);
          if (index != -1) {
            _songs[index] = updatedSong;
          }

          // Notify song update
          _songUpdateController.add(updatedSong);
        }
      } catch (e) {
        debugPrint('Error processing song ${song.title}: $e');
        continue;
      }
    }
  }

  @override
  void dispose() {
    _songUpdateController.close();
    super.dispose();
  }
} 