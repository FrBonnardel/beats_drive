import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/media_notification_service.dart';
import '../models/music_models.dart';
import '../providers/music_provider.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _playlist = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffleEnabled = false;
  bool _isRepeatEnabled = false;
  final _songChangeController = StreamController<Song?>.broadcast();
  final _currentSongNotifier = ValueNotifier<Song?>(null);
  final _audioSourceCache = <String, AudioSource>{};
  late final MusicProvider _musicProvider;
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

  AudioProvider() {
    _initProvider();
    _setupMediaNotificationListeners();
    _setupAudioPlayer();
    _restoreState();
  }

  Future<void> _initProvider() async {
    _musicProvider = MusicProvider();
  }

  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Restore playlist
      final playlistJson = prefs.getStringList(_playlistKey);
      if (playlistJson != null && playlistJson.isNotEmpty) {
        _playlist = playlistJson;
        
        // Restore current index
        _currentIndex = prefs.getInt(_currentIndexKey) ?? -1;
        
        // Restore playback state
        _isPlaying = prefs.getBool(_isPlayingKey) ?? false;
        _isShuffleEnabled = prefs.getBool(_isShuffleEnabledKey) ?? false;
        _isRepeatEnabled = prefs.getBool(_isRepeatEnabledKey) ?? false;
        
        // Restore position
        final positionMillis = prefs.getInt(_positionKey) ?? 0;
        _position = Duration(milliseconds: positionMillis);

        // Set up audio source and restore playback
        if (_playlist.isNotEmpty) {
          final sources = <AudioSource>[];
          for (var uri in _playlist) {
            if (!_audioSourceCache.containsKey(uri)) {
              final source = uri.startsWith('content://')
                  ? AudioSource.uri(Uri.parse(uri))
                  : AudioSource.file(uri);
              _audioSourceCache[uri] = source;
              sources.add(source);
            }
          }

          if (sources.isNotEmpty) {
            final playlist = ConcatenatingAudioSource(children: sources);
            await _audioPlayer.setAudioSource(playlist);
            
            // Restore playback position and state
            if (_currentIndex >= 0) {
              await _audioPlayer.seek(_position, index: _currentIndex);
              if (_isPlaying) {
                await _audioPlayer.play();
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error restoring audio state: $e');
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

  void _setupMediaNotificationListeners() {
    MediaNotificationService.onPlay.listen((_) => play());
    MediaNotificationService.onPause.listen((_) => pause());
    MediaNotificationService.onNext.listen((_) => next());
    MediaNotificationService.onPrevious.listen((_) => previous());
    MediaNotificationService.onStop.listen((_) => stop());
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _handleSongCompletion();
      }
      _saveState();
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((position) {
      _position = position;
      _updateMediaNotification();
      _saveState();
      notifyListeners();
    });

    _audioPlayer.currentIndexStream.listen((index) async {
      if (index != null && index != _currentIndex) {
        _currentIndex = index;
        await _updateCurrentSong();
        _saveState();
        notifyListeners();
        debugPrint('AudioProvider: Current index changed to: $index');
      }
    });
  }

  Future<void> _updateCurrentSong() async {
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      final uri = _playlist[_currentIndex];
      try {
        final song = await _musicProvider.getSongByUri(uri);
        _currentSongNotifier.value = song;
        _songChangeController.add(song);
        await _updateMediaNotification();
        debugPrint('AudioProvider: Updated current song: ${song.title}');
      } catch (e) {
        debugPrint('Error updating current song: $e');
      }
    }
  }

  Future<void> _updateMediaNotification() async {
    final song = _currentSongNotifier.value;
    if (song != null) {
      await MediaNotificationService.showNotification(
        title: song.title,
        author: song.artist,
        image: null,
        play: _isPlaying,
      );
    }
  }

  Future<void> play() async {
    try {
      await _audioPlayer.play();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    await MediaNotificationService.hideNotification();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
  }

  Future<void> previous() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _audioPlayer.seek(Duration.zero, index: _currentIndex);
      await _audioPlayer.play();
    }
  }

  Future<void> next() async {
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await _audioPlayer.seek(Duration.zero, index: _currentIndex);
      await _audioPlayer.play();
    }
  }

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    if (_isShuffleEnabled) {
      _shuffledIndices.shuffle();
      _audioPlayer.setShuffleModeEnabled(true);
    } else {
      _shuffledIndices = List.generate(_playlist.length, (index) => index);
      _audioPlayer.setShuffleModeEnabled(false);
    }
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeatEnabled = !_isRepeatEnabled;
    _audioPlayer.setLoopMode(_isRepeatEnabled ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  void _handleSongCompletion() async {
    if (_isRepeatEnabled) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } else if (_currentIndex < _playlist.length - 1) {
      await next();
    }
  }

  Future<void> updatePlaylist(List<String> uris) async {
    _playlist = List<String>.from(uris);
    _currentIndex = -1;
    await _audioPlayer.stop();
    _audioSourceCache.clear();

    final sources = <AudioSource>[];
    for (var uri in uris) {
      if (!_audioSourceCache.containsKey(uri)) {
        final source = uri.startsWith('content://')
            ? AudioSource.uri(Uri.parse(uri))
            : AudioSource.file(uri);
        _audioSourceCache[uri] = source;
        sources.add(source);
      }
    }

    if (sources.isNotEmpty) {
      final playlist = ConcatenatingAudioSource(children: sources);
      await _audioPlayer.setAudioSource(playlist);
      _saveState();
      debugPrint('Successfully set initial audio source with ${sources.length} tracks');
      
      // Preload metadata for all songs in the playlist
      for (var uri in uris) {
        _musicProvider.getSongByUri(uri).then((song) {
          debugPrint('AudioProvider: Preloaded metadata for: ${song.title}');
        });
      }
    }
  }

  Future<void> selectSong(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    try {
      _currentIndex = index;
      final song = await _musicProvider.getSongByUri(_playlist[index]);
      _currentSongNotifier.value = song;
      _songChangeController.add(song);
      
      await _audioPlayer.seek(Duration.zero, index: index);
      await _audioPlayer.play();
      _saveState();
      debugPrint('AudioProvider: Selected song: ${song.title}');
    } catch (e) {
      debugPrint('Error selecting song: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _songChangeController.close();
    MediaNotificationService.hideNotification();
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
  AudioPlayer get audioPlayer => _audioPlayer;
  String get searchQuery => _searchQuery;
} 