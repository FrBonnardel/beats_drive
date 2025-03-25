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
  
  // Loading states
  bool _isInitialLoad = false;
  bool _isInitialLoadComplete = false;
  bool _isQuickLoading = false;
  bool _isQuickLoadComplete = false;
  bool _isFullScanComplete = false;
  bool _isScanning = false;
  String _quickLoadStatus = '';
  int _loadingProgress = 0;
  int _totalSongsToLoad = 0;
  
  // Pagination state
  static const int _defaultPageSize = 20;
  int _currentPage = 0;
  bool _hasMoreSongs = true;
  bool _isLoadingMore = false;
  
  // Add caches with size limits
  static const int _maxAlbumArtCacheSize = 50; // Reduced from 100
  static const int _maxAlbumArtDimension = 300; // Maximum dimension for cached album art
  final Map<String, Uint8List?> _albumArtCache = {};
  final Map<String, int> _albumArtLastAccess = {}; // Track last access time for LRU eviction
  final Map<String, Song> _songByUriCache = {};
  final Map<String, ValueNotifier<Uint8List?>> _albumArtNotifiers = {};
  final Map<String, Future<Uint8List?>> _albumArtLoadingFutures = {}; // Cache loading futures to prevent duplicate loads
  final Map<String, DateTime> _albumArtLoadTimes = {}; // Track when album art was loaded
  static const Duration _albumArtCacheDuration = Duration(hours: 24); // How long to keep album art in cache
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  final _backgroundScanCompleter = Completer<void>();
  final _songUpdateController = StreamController<Song>.broadcast();
  bool _backgroundScanComplete = false;

  // Add getters for loading states
  bool get isInitialLoad => _isInitialLoad;
  bool get isInitialLoadComplete => _isInitialLoadComplete;
  bool get isQuickLoading => _isQuickLoading;
  bool get isQuickLoadComplete => _isQuickLoadComplete;
  bool get isFullScanComplete => _isFullScanComplete;
  int get loadingProgress => _loadingProgress;
  int get totalSongsToLoad => _totalSongsToLoad;

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
  String get quickLoadStatus => _quickLoadStatus;

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
    _albumArtLastAccess.clear();
    _albumArtLoadingFutures.clear();
    _albumArtLoadTimes.clear();
  }

  // Add method to get song by URI with caching
  Future<Song?> getSongByUri(String uri) async {
    // Check cache first
    if (_songByUriCache.containsKey(uri)) {
      return _songByUriCache[uri];
    }

    // Try to find song in songs list
    final song = _songs.firstWhereOrNull((s) => s.uri == uri);
    if (song != null) {
      _songByUriCache[uri] = song;
      return song;
    }

    // Always get metadata from MediaStore
    try {
      final metadata = await MediaStoreService.getSongMetadata(uri);
      
      if (metadata != null) {
        final song = Song(
          id: metadata['_id']?.toString() ?? '',
          title: metadata['title']?.toString() ?? '',
          artist: metadata['artist']?.toString() ?? '',
          album: metadata['album']?.toString() ?? '',
          albumId: metadata['album_id']?.toString() ?? '',
          duration: metadata['duration'] as int? ?? 0,
          uri: uri,
          trackNumber: metadata['track'] as int? ?? 0,
          year: metadata['year'] as int? ?? 0,
          dateAdded: metadata['date_added'] as int? ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          albumArtUri: '',
        );
        
        _songByUriCache[uri] = song;
        return song;
      }
    } catch (e) {
      debugPrint('Error getting metadata from MediaStore: $e');
    }

    return null;
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

    // Process uncached URIs in smaller batches with longer delays
    const batchSize = 5; // Reduced batch size
    for (var i = 0; i < uncachedUris.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, uncachedUris.length);
      final batch = uncachedUris.sublist(i, end);
      
      try {
        final metadataList = await MediaStoreService.getSongsMetadata(batch);
        
        // Process each URI in the batch
        for (var j = 0; j < batch.length; j++) {
          final uri = batch[j];
          final metadata = j < metadataList.length ? metadataList[j] : null;
          
          if (metadata != null) {
            final song = Song(
              id: metadata['_id']?.toString() ?? '',
              title: metadata['title']?.toString() ?? '',
              artist: metadata['artist']?.toString() ?? '',
              album: metadata['album']?.toString() ?? '',
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
          }
        }
      } catch (e) {
        debugPrint('Error batch loading song metadata: $e');
      }
      
      // Add a longer delay between batches to prevent UI blocking
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return result;
  }

  Future<void> _initializeCache() async {
    debugPrint('Initializing cache...');
    await _cacheService.initialize();
    await loadFromCache();
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
    if (_status == MusicScanStatus.scanning) {
      debugPrint('Scan already in progress, skipping...');
      return false;
    }
    
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
    if (_status == MusicScanStatus.scanning) {
      debugPrint('Scan already in progress, skipping...');
      return;
    }
    
    if (_isFullScanComplete && !forceRescan) {
      debugPrint('Full scan already completed and not forcing rescan, skipping...');
      return;
    }
    
    debugPrint('Starting music scan (forceRescan: $forceRescan)');
    _status = MusicScanStatus.scanning;
    _isComplete = false;
    _error = null;
    _currentStatus = 'Loading music...';
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
          
          // Only start background scan if not already scanning and not forcing rescan
          if (!_isScanning && !forceRescan) {
            debugPrint('Starting background scan after cache load');
            unawaited(_startBackgroundScan(forceRescan: false));
          }
          return;
        }
      }

      // Start full scan
      await _startInitialLoad();
    } catch (e) {
      debugPrint('Error scanning music files: $e');
      await _handleError('Failed to scan music files: $e');
    }
  }

  Future<void> _startBackgroundScan({bool forceRescan = false}) async {
    if (_isScanning) {
      debugPrint('Background scan already in progress, skipping...');
      return;
    }
    
    if (_isFullScanComplete && !forceRescan) {
      debugPrint('Full scan already completed, skipping...');
      return;
    }
    
    _isScanning = true;
    _currentStatus = 'Loading remaining data...';
    notifyListeners();
    
    try {
      // Start background scan
      final isolate = await Isolate.spawn(_backgroundScanIsolate, {
        'forceRescan': forceRescan,
      });
      
      // Wait for scan to complete
      await _backgroundScanCompleter.future;
      
      _isFullScanComplete = true;
      _currentStatus = 'Library scan complete';
      notifyListeners();
    } catch (e) {
      debugPrint('Error in background scan: $e');
      _error = 'Failed to complete background scan: $e';
      _status = MusicScanStatus.error;
      notifyListeners();
    } finally {
      _isScanning = false;
    }
  }

  static Future<void> _backgroundScanIsolate(Map<String, dynamic> params) async {
    try {
      final forceRescan = params['forceRescan'] as bool;
      
      // Perform background scan
      final songs = await MediaStoreService.getSongsForPage(0, 1000); // Get up to 1000 songs
      
      // Process songs in batches
      const batchSize = 100;
      for (var i = 0; i < songs.length; i += batchSize) {
        final end = (i + batchSize < songs.length) ? i + batchSize : songs.length;
        final batch = songs.sublist(i, end);
        
        // Process batch
        await _processBatchInIsolate(batch);
        
        // Add delay to prevent UI blocking
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Complete the scan
      Isolate.exit();
    } catch (e) {
      debugPrint('Error in background scan isolate: $e');
      Isolate.exit();
    }
  }

  static Future<void> _processBatchInIsolate(List<Map<String, dynamic>> batch) async {
    for (final songData in batch) {
      try {
        final song = Song.fromMap(songData);
        // Process song data
        // Add to cache if needed
      } catch (e) {
        debugPrint('Error processing song in batch: $e');
      }
    }
  }

  Future<void> _updateCollections() async {
    if (_songs.isEmpty) return;
    
    // Only update collections if there are significant changes
    if (_albums.length > 0 && _songs.length == _albums.expand((a) => a.songs).length) {
      return;
    }

    // Process collections in a separate isolate
    final result = await compute(_processCollections, _songs);
    
    _albums = result['albums'] as List<Album>;
    _artists = result['artists'] as List<Artist>;
    
    // Sort everything
    _sortMusic(currentSortOption);
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

  Future<Uint8List?> loadAlbumArt(String songId, {bool forceReload = false}) async {
    if (songId.isEmpty) return null;

    // Update last access time for LRU
    _albumArtLastAccess[songId] = DateTime.now().millisecondsSinceEpoch;

    // Check if we need to force reload
    if (!forceReload) {
      // Check memory cache first
      if (_albumArtCache.containsKey(songId)) {
        final loadTime = _albumArtLoadTimes[songId];
        if (loadTime != null && DateTime.now().difference(loadTime) < _albumArtCacheDuration) {
          return _albumArtCache[songId];
        }
      }

      // Check if already loading
      if (_albumArtLoadingFutures.containsKey(songId)) {
        return _albumArtLoadingFutures[songId];
      }
    }

    // Create new loading future
    final loadingFuture = _loadAlbumArtFromSource(songId, forceReload: forceReload);
    _albumArtLoadingFutures[songId] = loadingFuture;
    
    try {
      final albumArt = await loadingFuture;
      if (albumArt != null) {
        _addToAlbumArtCache(songId, albumArt);
      }
      return albumArt;
    } finally {
      _albumArtLoadingFutures.remove(songId);
    }
  }

  Future<Uint8List?> _loadAlbumArtFromSource(String songId, {bool forceReload = false}) async {
    try {
      final song = _songs.firstWhereOrNull((s) => s.id == songId);
      if (song == null) return null;

      // Check disk cache first if not forcing reload
      if (!forceReload) {
        final cachedArt = await _cacheService.getCachedAlbumArt(songId);
        if (cachedArt != null) {
          final loadTime = _albumArtLoadTimes[songId];
          if (loadTime != null && DateTime.now().difference(loadTime) < _albumArtCacheDuration) {
            return Uint8List.fromList(cachedArt);
          }
        }
      }

      // Load from MediaStore
      final albumArt = await MediaStoreService.getAlbumArt(song.id);
      
      if (albumArt != null) {
        // Resize image if needed
        final resizedArt = await _resizeAlbumArt(albumArt);
        
        // Cache the resized album art
        await _cacheService.cacheAlbumArt(songId, resizedArt.toList());
        return resizedArt;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading album art: $e');
      return null;
    }
  }

  Future<Uint8List> _resizeAlbumArt(Uint8List originalImage) async {
    try {
      final codec = await instantiateImageCodec(originalImage);
      final frameInfo = await codec.getNextFrame();
      
      if (frameInfo.image.width <= _maxAlbumArtDimension && 
          frameInfo.image.height <= _maxAlbumArtDimension) {
        return originalImage;
      }

      final ratio = frameInfo.image.width / frameInfo.image.height;
      int targetWidth = _maxAlbumArtDimension;
      int targetHeight = _maxAlbumArtDimension;

      if (ratio > 1) {
        targetHeight = (_maxAlbumArtDimension / ratio).round();
      } else {
        targetWidth = (_maxAlbumArtDimension * ratio).round();
      }

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..filterQuality = FilterQuality.high;
      
      canvas.drawImageRect(
        frameInfo.image,
        Rect.fromLTWH(0, 0, frameInfo.image.width.toDouble(), frameInfo.image.height.toDouble()),
        Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        paint,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(targetWidth, targetHeight);
      final byteData = await img.toByteData(format: ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error resizing album art: $e');
      return originalImage;
    }
  }

  void _addToAlbumArtCache(String songId, Uint8List albumArt) {
    // Evict oldest items if cache is full
    while (_albumArtCache.length >= _maxAlbumArtCacheSize) {
      final oldestSongId = _albumArtLastAccess.entries
          .reduce((a, b) => a.value < b.value ? a : b)
          .key;
      _albumArtCache.remove(oldestSongId);
      _albumArtLastAccess.remove(oldestSongId);
      _albumArtLoadTimes.remove(oldestSongId);
    }

    // Add new item to cache
    _albumArtCache[songId] = albumArt;
    _albumArtLastAccess[songId] = DateTime.now().millisecondsSinceEpoch;
    _albumArtLoadTimes[songId] = DateTime.now();
  }

  // Add method to preload album art for visible songs
  Future<void> preloadAlbumArt(List<String> songIds) async {
    final futures = <Future<void>>[];
    
    for (final songId in songIds) {
      if (!_albumArtCache.containsKey(songId) && 
          !_albumArtLoadingFutures.containsKey(songId)) {
        futures.add(loadAlbumArt(songId).then((_) {}));
      }
    }
    
    // Wait for all preloads to complete
    await Future.wait(futures);
  }

  // Add method to clear old album art from cache
  void _cleanupOldAlbumArt() {
    final now = DateTime.now();
    final oldKeys = _albumArtLoadTimes.entries
        .where((entry) => now.difference(entry.value) > _albumArtCacheDuration)
        .map((entry) => entry.key)
        .toList();

    for (final key in oldKeys) {
      _albumArtCache.remove(key);
      _albumArtLastAccess.remove(key);
      _albumArtLoadTimes.remove(key);
    }
  }

  // Add method to clear caches when memory pressure is high
  void clearCaches() {
    debugPrint('Clearing caches to free memory');
    _albumArtCache.clear();
    _albumArtLastAccess.clear();
    _albumArtLoadingFutures.clear();
    _songByUriCache.clear();
    _albumArtNotifiers.clear();
    _albumArtLoadTimes.clear();
  }

  // Add getter for album art notifier
  ValueNotifier<Uint8List?>? getAlbumArtNotifier(String songId) {
    return _albumArtNotifiers[songId];
  }

  Future<void> playSong(BuildContext context, Song song) async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    
    // Stop any current playback
    await audioProvider.stop();

    // Create a playlist starting with the selected song
    final selectedIndex = _songs.indexWhere((s) => s.uri == song.uri);
    if (selectedIndex >= 0) {
      // Get songs before and after the selected song
      final visibleRange = 10; // Number of songs before and after current song
      final startIndex = (selectedIndex - visibleRange).clamp(0, _songs.length);
      final endIndex = (selectedIndex + visibleRange).clamp(0, _songs.length);
      
      // Create playlist with selected song first, followed by surrounding songs
      final playlist = <Song>[];
      playlist.add(song); // Add selected song first
      
      // Add songs before the selected song
      for (var i = selectedIndex - 1; i >= startIndex; i--) {
        playlist.add(_songs[i]);
      }
      
      // Add songs after the selected song
      for (var i = selectedIndex + 1; i < endIndex; i++) {
        playlist.add(_songs[i]);
      }
      
      // Get URIs for the playlist
      final uris = playlist.map((s) => s.uri).toList();
      
      // Update the playlist with URIs
      await audioProvider.updatePlaylist(uris);
      
      // Play the first song (which is the selected song)
      await audioProvider.selectSong(0);
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

  Future<List<Song>> loadFromCache() async {
    try {
      final cachedSongs = await _cacheService.getCachedSongs();
      if (cachedSongs.isNotEmpty) {
        _songs = cachedSongs;
        notifyListeners();
        return cachedSongs;
      }
      await _startInitialLoad();
      return [];
    } catch (e) {
      debugPrint('Error loading from cache: $e');
      await _startInitialLoad();
      return [];
    }
  }

  Stream<Song> get onSongUpdated => _songUpdateController.stream;

  Future<List<Song>> getQuickMediaStoreInfo({
    int page = 0,
    int pageSize = 20,
    bool forceRescan = false,
  }) async {
    try {
      final songsList = await MediaStoreService.getSongsForPage(page, pageSize);
      return songsList.map((song) => Song.fromMap(song)).toList();
    } catch (e) {
      debugPrint('Error getting quick media store info: $e');
      return [];
    }
  }

  Future<List<Song>> loadMoreSongs() async {
    if (_isLoadingMore || !_hasMoreSongs) {
      return [];
    }

    _isLoadingMore = true;
    try {
      final nextPage = _currentPage + 1;
      final newSongs = await getQuickMediaStoreInfo(page: nextPage);
      _isLoadingMore = false;
      return newSongs;
    } catch (e) {
      _isLoadingMore = false;
      debugPrint('Error loading more songs: $e');
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

  Future<List<Song>> getSongsPage(int page, int pageSize) async {
    try {
      final startIndex = page * pageSize;
      if (startIndex >= _songs.length) {
        return [];
      }
      
      final endIndex = (startIndex + pageSize).clamp(0, _songs.length);
      return _songs.sublist(startIndex, endIndex);
    } catch (e) {
      debugPrint('Error getting songs page: $e');
      return [];
    }
  }

  Future<void> quickLoad() async {
    if (_isQuickLoading || !_isInitialLoadComplete) {
      debugPrint('Quick load already in progress or initial load not complete, skipping...');
      return;
    }
    
    if (_isQuickLoadComplete) {
      debugPrint('Quick load already completed, skipping...');
      return;
    }
    
    _isQuickLoading = true;
    _quickLoadStatus = 'Starting quick load...';
    notifyListeners();
    
    try {
      // Load first 100 songs quickly for immediate access
      _quickLoadStatus = 'Quick loading songs...';
      notifyListeners();
      
      const quickLoadSize = 100;
      final quickSongs = await getQuickMediaStoreInfo(page: 0, pageSize: quickLoadSize);
      
      if (quickSongs.isNotEmpty) {
        _songs = quickSongs;
        _quickLoadStatus = 'Organizing music collections...';
        notifyListeners();
        
        // Process collections in a separate isolate
        final result = await compute(_processCollections, _songs);
        _albums = result['albums'] as List<Album>;
        _artists = result['artists'] as List<Artist>;
        
        // Sort collections
        _sortMusic(_currentSortOption);
        
        _isQuickLoadComplete = true;
        _quickLoadStatus = 'Quick load complete';
        notifyListeners();
        
        // Cache the processed data
        await _cacheData();
        
        // Start background scan for remaining songs
        if (!_isFullScanComplete && !_isScanning) {
          debugPrint('Starting background scan after quick load');
          unawaited(_startBackgroundScan(forceRescan: false));
        }
      } else {
        _quickLoadStatus = 'No songs found';
        _isQuickLoadComplete = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in quick load: $e');
      _error = 'Failed to load music: $e';
      _status = MusicScanStatus.error;
      notifyListeners();
    } finally {
      _isQuickLoading = false;
    }
  }

  Future<void> _cacheData() async {
    try {
      await _cacheService.cacheSongs(_songs);
    } catch (e) {
      debugPrint('Error caching data: $e');
    }
  }

  Future<void> _startInitialLoad() async {
    if (_isInitialLoad) {
      debugPrint('Initial load already in progress, skipping...');
      return;
    }
    
    _isInitialLoad = true;
    _currentStatus = 'Loading music library...';
    notifyListeners();
    
    try {
      // Initialize background isolate
      final rootToken = RootIsolateToken.instance;
      if (rootToken == null) {
        throw Exception('Failed to get root isolate token');
      }
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
      
      // Get all songs from MediaStore
      final songs = await MediaStoreService.getSongsForPage(0, 1000); // Get up to 1000 songs
      
      // Process songs in batches
      const batchSize = 50;
      _totalSongsToLoad = songs.length;
      _loadingProgress = 0;
      
      for (var i = 0; i < songs.length; i += batchSize) {
        final end = (i + batchSize < songs.length) ? i + batchSize : songs.length;
        final batch = songs.sublist(i, end);
        
        // Process batch
        await _processBatch(batch);
        
        // Update progress
        _loadingProgress = end;
        notifyListeners();
        
        // Add delay to prevent UI blocking
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Process collections after all songs are loaded
      _currentStatus = 'Organizing music collections...';
      notifyListeners();
      
      final result = await compute(_processCollections, _songs);
      _albums = result['albums'] as List<Album>;
      _artists = result['artists'] as List<Artist>;
      
      // Sort collections
      _sortMusic(_currentSortOption);
      
      // Cache the processed data
      await _cacheData();
      
      _isInitialLoad = false;
      _isInitialLoadComplete = true;
      _currentStatus = 'Library loaded successfully';
      notifyListeners();
    } catch (e) {
      debugPrint('Error in initial load: $e');
      _error = 'Failed to load music library: $e';
      _status = MusicScanStatus.error;
      _isInitialLoad = false;
      notifyListeners();
    }
  }

  Future<void> _processBatch(List<Map<String, dynamic>> batch) async {
    for (final songData in batch) {
      try {
        final song = Song.fromMap(songData);
        _songs.add(song);
        _songUpdateController.add(song);
      } catch (e) {
        debugPrint('Error processing song in batch: $e');
      }
    }
  }

  @override
  void dispose() {
    _cleanupOldAlbumArt();
    clearCaches();
    _songUpdateController.close();
    super.dispose();
  }
} 