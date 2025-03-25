import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/media_notification_service.dart';
import '../models/music_models.dart';
import '../providers/music_provider.dart';
import '../services/cache_service.dart';

class AudioProvider extends ChangeNotifier {
  AudioPlayer? _audioPlayer;
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final Map<String, AudioSource> _audioSourceCache = {};
  final MusicProvider _musicProvider;
  
  List<String> _playlist = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffleEnabled = false;
  bool _isRepeatEnabled = false;
  final _songChangeController = StreamController<Song?>.broadcast();
  final _currentSongNotifier = ValueNotifier<Song?>(null);
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String _searchQuery = '';
  List<int> _shuffledIndices = [];
  static const String _playlistKey = 'last_playlist';
  static const String _currentIndexKey = 'last_current_index';
  static const String _isPlayingKey = 'last_is_playing';
  static const String _isShuffleEnabledKey = 'last_shuffle_enabled';
  static const String _isRepeatEnabledKey = 'last_repeat_enabled';
  static const String _positionKey = 'last_position';
  final CacheService _cacheService;
  Song? _currentSong;
  String? _currentUri;
  bool _isLoading = false;
  bool _isAudioPlayerInitialized = false;
  Completer<void> _initCompleter = Completer<void>();

  AudioProvider(this._musicProvider, this._cacheService) {
    _initializeAudioPlayer();
  }

  Future<void> _initializeAudioPlayer() async {
    if (_isAudioPlayerInitialized) return;

    try {
      // Dispose of any existing player
      await _audioPlayer?.dispose();
      _audioPlayer = null;

      // Initialize audio session
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      
      // Create audio player with proper configuration
      _audioPlayer = AudioPlayer(
        handleInterruptions: true,
        handleAudioSessionActivation: true,
      );
      
      // Set up audio player
      _setupAudioPlayer();
      
      _isAudioPlayerInitialized = true;
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      
      // Load state after initialization
      await _loadState();
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
      _isAudioPlayerInitialized = false;
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
      // Reset the completer for next attempt
      _initCompleter = Completer<void>();
    }
  }

  Future<void> _loadState() async {
    try {
      // Wait for audio player to be initialized
      while (!_isAudioPlayerInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final prefs = await SharedPreferences.getInstance();
      
      // Restore playlist
      final playlistJson = prefs.getString('playlist');
      if (playlistJson != null) {
        final List<dynamic> playlistData = json.decode(playlistJson);
        _playlist = playlistData.map((uri) => uri as String).toList();
        
        // Only proceed if playlist is not empty
        if (_playlist.isNotEmpty) {
          // Restore current index
          _currentIndex = prefs.getInt('currentIndex') ?? 0;
          if (_currentIndex >= _playlist.length) {
            _currentIndex = 0;
          }
          
          // Restore playback state
          final wasPlaying = prefs.getBool('wasPlaying') ?? false;
          
          // Restore position
          final position = prefs.getInt('position') ?? 0;
          
          // Update current song
          final uri = _playlist[_currentIndex];
          final song = await _musicProvider.getSongByUri(uri);
          if (song != null) {
            _currentSong = song;
            _currentSongNotifier.value = song;
            _songChangeController.add(song);
            
            // Set position and state
            await _audioPlayer!.seek(Duration(milliseconds: position));
            if (wasPlaying) {
              await _audioPlayer!.play();
            }
          } else {
            debugPrint('AudioProvider: Could not retrieve song metadata for URI: $uri');
            // Skip this song and move to the next one
            if (_currentIndex < _playlist.length - 1) {
              await selectSong(_currentIndex + 1);
            } else {
              await stop();
            }
          }
        } else {
          // Reset state if playlist is empty
          _currentIndex = -1;
          _currentSong = null;
          _currentSongNotifier.value = null;
          _songChangeController.add(null);
          await stop();
        }
      }
    } catch (e) {
      debugPrint('Error loading state: $e');
      // Reset state on error
      _playlist = [];
      _currentIndex = -1;
      _currentSong = null;
      _currentSongNotifier.value = null;
      _songChangeController.add(null);
      await stop();
    }
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save playlist
      await prefs.setStringList(_playlistKey, _playlist);
      
      // Save current index
      await prefs.setInt(_currentIndexKey, _currentIndex);
      
      // Save playback state
      await prefs.setBool(_isPlayingKey, _isPlaying);
      await prefs.setBool(_isShuffleEnabledKey, _isShuffleEnabled);
      await prefs.setBool(_isRepeatEnabledKey, _isRepeatEnabled);
      
      // Save position
      await prefs.setInt(_positionKey, _position.inMilliseconds);
    } catch (e) {
      debugPrint('Error saving audio state: $e');
    }
  }

  void _setupAudioPlayer() {
    if (_audioPlayer == null) return;

    _audioPlayer!.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _handleSongCompletion();
      }
      _saveState();
      notifyListeners();
    });

    _audioPlayer!.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    // Debounce position updates to reduce UI updates
    Timer? _positionDebounceTimer;
    _audioPlayer!.positionStream.listen((position) {
      _position = position;
      positionNotifier.value = position;  // Update position notifier immediately
      
      _positionDebounceTimer?.cancel();
      _positionDebounceTimer = Timer(const Duration(milliseconds: 1000), () {  // Increased debounce time
        if (_isPlaying) {  // Only update notification and save state if playing
          _updateMediaNotification();
          _saveState();
          notifyListeners();
        }
      });
    });

    _audioPlayer!.currentIndexStream.listen((index) async {
      if (index != null && index != _currentIndex) {
        _currentIndex = index;
        unawaited(_updateCurrentSong());  // Update song info in background
        _saveState();
        notifyListeners();
        debugPrint('AudioProvider: Current index changed to: $index');
      }
    });
  }

  Future<void> _updateCurrentSong() async {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) {
      _currentSong = null;
      _currentSongNotifier.value = null;
      _songChangeController.add(null);
      return;
    }
    
    final uri = _playlist[_currentIndex];
    try {
      final song = await _musicProvider.getSongByUri(uri);
      if (song != null) {
        _currentSong = song;
        _currentSongNotifier.value = song;
        _songChangeController.add(song);
        await _updateMediaNotification();
        debugPrint('AudioProvider: Updated current song: ${song.title}');
      } else {
        debugPrint('AudioProvider: Could not retrieve song metadata for URI: $uri');
        // Skip this song and move to the next one
        if (_currentIndex < _playlist.length - 1) {
          await selectSong(_currentIndex + 1);
        } else {
          await stop();
        }
      }
    } catch (e) {
      debugPrint('Error updating current song: $e');
      // Skip this song and move to the next one
      if (_currentIndex < _playlist.length - 1) {
        await selectSong(_currentIndex + 1);
      } else {
        await stop();
      }
    }
  }

  Future<void> _updateMediaNotification() async {
    if (_currentSong == null) return;
    
    try {
      final song = _currentSong!;
      final artwork = await _musicProvider.loadAlbumArt(song.id);
      
      // Don't update the audio source here since it's managed by the playlist
      await _audioPlayer!.setLoopMode(_isRepeatEnabled ? LoopMode.one : LoopMode.off);
      await _audioPlayer!.setVolume(1.0);
    } catch (e) {
      debugPrint('Error updating media notification: $e');
    }
  }

  Future<void> play() async {
    if (_currentIndex >= 0 && !_isLoading) {
      try {
        await _audioPlayer!.play();
        _isPlaying = true;
        _saveState();
        notifyListeners();
      } catch (e) {
        debugPrint('Error playing audio: $e');
      }
    }
  }

  Future<void> pause() async {
    if (!_isLoading) {
      try {
        await _audioPlayer!.pause();
        _isPlaying = false;
        _saveState();
        notifyListeners();
      } catch (e) {
        debugPrint('Error pausing audio: $e');
      }
    }
  }

  Future<void> stop() async {
    if (!_isLoading) {
      try {
        await _audioPlayer!.stop();
        _isPlaying = false;
        _position = Duration.zero;
        _currentUri = null;
        _saveState();
        notifyListeners();
      } catch (e) {
        debugPrint('Error stopping audio: $e');
      }
    }
  }

  Future<void> seek(Duration position) async {
    if (!_isLoading) {
      try {
        await _audioPlayer!.seek(position);
        _position = position;
        notifyListeners();
      } catch (e) {
        debugPrint('Error seeking audio: $e');
      }
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer!.setVolume(volume);
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  Future<void> previous() async {
    if (_currentIndex > 0 && !_isLoading) {
      await selectSong(_currentIndex - 1);
    }
  }

  Future<void> next() async {
    if (_currentIndex < _playlist.length - 1 && !_isLoading) {
      await selectSong(_currentIndex + 1);
    }
  }

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    if (_isShuffleEnabled) {
      _shuffledIndices.shuffle();
      _audioPlayer!.setShuffleModeEnabled(true);
    } else {
      _shuffledIndices = List.generate(_playlist.length, (index) => index);
      _audioPlayer!.setShuffleModeEnabled(false);
    }
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeatEnabled = !_isRepeatEnabled;
    _audioPlayer!.setLoopMode(_isRepeatEnabled ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  Future<void> _handleSongCompletion() async {
    if (_playlist.isEmpty) {
      await stop();
      return;
    }

    if (_isRepeatEnabled) {
      // Replay current song
      await _audioPlayer!.seek(Duration.zero);
      await _audioPlayer!.play();
    } else if (_currentIndex < _playlist.length - 1) {
      // Play next song
      await selectSong(_currentIndex + 1);
    } else {
      // End of playlist
      await stop();
    }
  }

  Future<void> updatePlaylist(List<String> uris, {int? selectedIndex}) async {
    debugPrint('AudioProvider: Updating playlist with ${uris.length} songs');
    if (uris.isEmpty) {
      debugPrint('AudioProvider: Empty playlist, resetting state');
      _currentIndex = 0;
      _playlist = [];
      _currentSong = null;
      notifyListeners();
      return;
    }

    debugPrint('AudioProvider: First URI in new playlist: ${uris.first}');
    debugPrint('AudioProvider: Last URI in new playlist: ${uris.last}');

    try {
      // Reset state
      _currentIndex = 0;
      _playlist = uris;
      _currentSong = null;
      notifyListeners();

      // Create audio sources for each URI
      final sources = <AudioSource>[];
      for (final uri in uris) {
        final song = await _musicProvider.getSongByUri(uri);
        if (song != null) {
          debugPrint('AudioProvider: Creating audio source for song: ${song.title}');
          sources.add(AudioSource.uri(Uri.file(uri)));
        }
      }

      if (sources.isEmpty) {
        debugPrint('AudioProvider: No valid sources found');
        return;
      }

      debugPrint('AudioProvider: Setting audio source with ${sources.length} tracks');
      
      // Set the audio source
      await _audioPlayer!.setAudioSource(ConcatenatingAudioSource(children: sources));
      
      // If we have a selected index, use it
      if (selectedIndex != null && selectedIndex >= 0 && selectedIndex < sources.length) {
        debugPrint('AudioProvider: Setting selected index: $selectedIndex');
        _currentIndex = selectedIndex;
        await _audioPlayer!.seek(Duration.zero, index: selectedIndex);
      }
      
      await _updateCurrentSong();
    } catch (e) {
      debugPrint('AudioProvider: Error updating playlist: $e');
      _currentIndex = 0;
      _playlist = [];
      _currentSong = null;
      notifyListeners();
    }
  }

  Future<void> selectSong(int index) async {
    if (index < 0 || index >= _playlist.length || _isLoading) {
      debugPrint('AudioProvider: Invalid song selection - index: $index, playlist length: ${_playlist.length}');
      return;
    }

    try {
      _isLoading = true;
      final uri = _playlist[index];
      debugPrint('AudioProvider: Selecting song at index $index, URI: $uri');
      
      // Verify the song exists and has metadata before playing
      final song = await _musicProvider.getSongByUri(uri);
      if (song == null) {
        debugPrint('AudioProvider: Could not retrieve metadata for song at index $index');
        return;
      }
      debugPrint('AudioProvider: Selected song metadata - Title: ${song.title}, Artist: ${song.artist}');

      // Update the current index and song
      _currentIndex = index;
      _currentUri = uri;
      _currentSong = song;
      _currentSongNotifier.value = song;
      _songChangeController.add(song);

      // Seek to the selected song
      await _audioPlayer!.seek(Duration.zero, index: index);
      
      debugPrint('AudioProvider: Seeking to song at index $index: ${song.title}');
    } catch (e) {
      debugPrint('AudioProvider: Error selecting song: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> addToPlaylist(String uri) async {
    if (!_playlist.contains(uri)) {
      _playlist.add(uri);
      final source = AudioSource.uri(Uri.parse(uri));
      _audioSourceCache[uri] = source;
      
      // Update audio source
      final sources = <AudioSource>[];
      for (var playlistUri in _playlist) {
        sources.add(_audioSourceCache[playlistUri]!);
      }
      final playlist = ConcatenatingAudioSource(children: sources);
      await _audioPlayer!.setAudioSource(playlist);
      
      _saveState();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _songChangeController.close();
    _currentSongNotifier.dispose();
    positionNotifier.dispose();
    _audioSourceCache.clear();
    super.dispose();
  }

  // Getters
  List<String> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isShuffleEnabled => _isShuffleEnabled;
  bool get isRepeatEnabled => _isRepeatEnabled;
  Stream<Song?> get onSongChanged => _songChangeController.stream;
  ValueNotifier<Song?> get currentSongNotifier => _currentSongNotifier;
  Duration get position => _position;
  Duration get duration => _duration;
  AudioPlayer get audioPlayer => _audioPlayer!;
  String get searchQuery => _searchQuery;

  // Update the position notifier when position changes
  void updatePosition(Duration position) {
    positionNotifier.value = position;
    _position = position;
    notifyListeners();
  }

  Stream<bool> get playingStream => _audioPlayer!.playerStateStream.map((state) => state.playing);
  
  // Add positionStream getter
  Stream<Duration> get positionStream => _audioPlayer!.positionStream;
} 