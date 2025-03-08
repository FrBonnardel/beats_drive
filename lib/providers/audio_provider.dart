import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:io';
import 'package:beats_drive/services/metadata_service.dart';
import 'package:flutter/material.dart';
import '../services/media_notification_service.dart';
import '../services/playback_state_service.dart';
import '../services/app_state_service.dart';
import '../services/playlist_generator_service.dart';
import '../models/music_models.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';

class AudioProvider with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  List<String> _playlist = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffleEnabled = false;
  List<int> _shuffledIndices = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Map<String, dynamic>? _currentMetadata;
  String _searchQuery = '';
  bool _isRepeatEnabled = false;
  String _currentSong = '';
  String _currentArtist = '';
  static const _channel = MethodChannel('com.beats_drive/media_store');
  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  AudioProvider() {
    _setupMediaNotificationListeners();
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _handleSongCompletion();
      }
      _updateMediaNotification();
      notifyListeners();
    });

    _player.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    _player.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && index != _currentIndex) {
        _currentIndex = index;
        _updateMediaNotification();
        notifyListeners();
      }
    });

    _setupAudioPlayer();
  }

  void _setupMediaNotificationListeners() {
    MediaNotificationService.onPlay.listen((_) => play());
    MediaNotificationService.onPause.listen((_) => pause());
    MediaNotificationService.onNext.listen((_) => next());
    MediaNotificationService.onPrevious.listen((_) => previous());
    MediaNotificationService.onStop.listen((_) => stop());
  }

  Future<void> _restoreState() async {
    final state = await AppStateService.getAppState();
    
    // Restore playlist
    if (state['playlist'] != null && state['playlist'].isNotEmpty) {
      _playlist = List<String>.from(state['playlist']);
      await _player.setAudioSource(
        ConcatenatingAudioSource(
          children: _playlist.map((file) => AudioSource.file(file)).toList(),
        ),
      );
    }

    // Restore playback state
    if (state['currentSong'] != null && _playlist.isNotEmpty) {
      final lastPlayedIndex = _playlist.indexWhere(
        (file) => file.split('/').last == state['currentSong'],
      );

      if (lastPlayedIndex != -1) {
        _currentIndex = lastPlayedIndex;
        await _player.seek(state['position'], index: lastPlayedIndex);
        // Only restore playing state if it was playing before
        if (state['isPlaying'] == true) {
          await _player.play();
        }
      }
    }

    // Restore shuffle and repeat settings
    _isShuffleEnabled = state['isShuffleEnabled'] ?? false;
    _isRepeatEnabled = state['isRepeatEnabled'] ?? false;

    notifyListeners();
  }

  void _saveState() {
    if (_currentSong.isNotEmpty) {
      AppStateService.saveAppState(
        lastScreen: 'player',
        playlist: _playlist,
        currentSong: _currentSong,
        position: _position,
        isPlaying: _isPlaying,
        isShuffleEnabled: _isShuffleEnabled,
        isRepeatEnabled: _isRepeatEnabled,
      );
    }
  }

  void _setupAudioPlayer() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _handleSongCompletion();
      }
      _saveState();
      notifyListeners();
    });

    _player.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    _player.positionStream.listen((position) {
      _position = position;
      _updateMediaNotification();
      _saveState();
      notifyListeners();
    });

    _player.currentIndexStream.listen((index) async {
      _currentIndex = index ?? 0;
      if (index != null && index < _playlist.length) {
        _currentSong = _playlist[index].split('/').last;
        // Get metadata for the current song
        _currentMetadata = await MetadataService.getMetadata(_playlist[index]);
        _currentArtist = _currentMetadata?['artist'] ?? 'Unknown Artist';
        _updateMediaNotification();
        _saveState();
      }
      notifyListeners();
    });
  }

  void _updateMediaNotification() {
    if (_context == null || _currentIndex < 0 || _currentIndex >= _playlist.length) {
      return;
    }

    final song = getCurrentSong();
    final musicProvider = Provider.of<MusicProvider>(_context!, listen: false);

    // Update current metadata
    _currentMetadata = {
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
    };
    _currentSong = song.title;
    _currentArtist = song.artist;

    // Load album art and show notification
    if (song.id.isNotEmpty) {
      musicProvider.loadAlbumArt(song.id).then((albumArt) {
        if (albumArt != null) {
          _currentMetadata!['albumArt'] = albumArt;
          MediaNotificationService.showNotification(
            title: song.title,
            author: song.artist,
            image: albumArt,
            play: _isPlaying,
          );
        }
        notifyListeners();
      });
    } else {
      MediaNotificationService.showNotification(
        title: song.title,
        author: song.artist,
        image: null,
        play: _isPlaying,
      );
      notifyListeners();
    }
  }

  Future<void> updatePlaylist(List<String> uris) async {
    if (uris.isEmpty) return;

    debugPrint('Updating playlist with ${uris.length} songs');
    debugPrint('First URI: ${uris.first}');

    _playlist = uris;
    _currentIndex = 0;
    _shuffledIndices = List.generate(uris.length, (index) => index);

    try {
      debugPrint('Creating audio sources...');
      final sources = await Future.wait(
        uris.map((uri) => _getAudioSource(uri))
      );

      debugPrint('Setting audio source with ${sources.length} items...');
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: 0,
      );
      debugPrint('Audio source set successfully');
    } catch (e) {
      debugPrint('Error setting audio source: $e');
    }
  }

  Future<AudioSource> _getAudioSource(String uri) async {
    try {
      debugPrint('Creating AudioSource for URI: $uri');
      final parsedUri = Uri.parse(uri);
      debugPrint('Parsed URI scheme: ${parsedUri.scheme}');
      debugPrint('Parsed URI path: ${parsedUri.path}');
      debugPrint('Parsed URI query: ${parsedUri.query}');
      // Create an AudioSource directly from the content URI
      final source = AudioSource.uri(parsedUri, tag: uri);
      debugPrint('AudioSource created successfully');
      return source;
    } catch (e) {
      debugPrint('Error getting audio source: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> selectSong(int index) async {
    debugPrint('Selecting song at index $index (playlist length: ${_playlist.length})');
    if (index >= 0 && index < _playlist.length) {
      debugPrint('Seeking to beginning of song at index $index');
      await _player.seek(Duration.zero, index: index);
      debugPrint('Starting playback');
      await _player.play();
      debugPrint('Playback started');
    } else {
      debugPrint('Invalid index: $index');
    }
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    await MediaNotificationService.hideNotification();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _filterPlaylist();
    notifyListeners();
  }

  void _filterPlaylist() {
    if (_searchQuery.isEmpty) {
      _playlist = _playlist;
    } else {
      _playlist = _playlist.where((file) {
        final fileName = file.toLowerCase();
        return fileName.contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  void _handleSongCompletion() async {
    if (_isRepeatEnabled) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      // Mark current song as played
      if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
        await PlaylistGeneratorService.markSongAsPlayed(_playlist[_currentIndex]);
      }

      // Check if we have unplayed songs
      final hasUnplayed = await PlaylistGeneratorService.hasUnplayedSongs();
      if (hasUnplayed) {
        // Get remaining songs and find the next unplayed song
        final remainingSongs = await PlaylistGeneratorService.getRemainingSongs();
        if (remainingSongs.isNotEmpty) {
          final nextSong = remainingSongs.first;
          final nextIndex = _playlist.indexOf(nextSong);
          if (nextIndex != -1) {
            await selectSong(nextIndex);
          }
        }
      } else {
        // All songs have been played, generate a new playlist for the next day
        await generateDailyPlaylist();
        if (_playlist.isNotEmpty) {
          await selectSong(0);
        }
      }
    }
  }

  @override
  void dispose() {
    _saveState(); // Save state before disposing
    _player.dispose();
    MediaNotificationService.hideNotification();
    super.dispose();
  }

  Future<void> next() async {
    if (_currentIndex < _playlist.length - 1) {
      await selectSong(_currentIndex + 1);
    }
  }

  Future<void> previous() async {
    if (_currentIndex > 0) {
      await selectSong(_currentIndex - 1);
    }
  }

  void removeFromPlaylist(int index) {
    if (index >= 0 && index < _playlist.length) {
      _playlist.removeAt(index);
      if (index == _currentIndex) {
        if (_playlist.isEmpty) {
          stop();
        } else {
          selectSong(0);
        }
      } else if (index < _currentIndex) {
        _currentIndex--;
      }
      notifyListeners();
    }
  }

  // Getters
  List<String> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  Map<String, dynamic>? get currentMetadata => _currentMetadata;
  AudioPlayer get audioPlayer => _player;
  String get searchQuery => _searchQuery;
  bool get isShuffleEnabled => _isShuffleEnabled;
  bool get isRepeatEnabled => _isRepeatEnabled;
  String get currentSong => _currentSong;
  String get currentArtist => _currentArtist;

  // Add setter for currentIndex
  set currentIndex(int value) {
    if (value >= 0 && value < _playlist.length) {
      _currentIndex = value;
      if (_playlist.isNotEmpty) {
        _currentSong = _playlist[value].split('/').last;
        // Get metadata for the current song
        MetadataService.getMetadata(_playlist[value]).then((metadata) {
          _currentMetadata = metadata;
          _currentArtist = metadata['artist'] ?? 'Unknown Artist';
          _updateMediaNotification();
          notifyListeners();
        });
      }
      notifyListeners();
    }
  }

  // Add setMetadata method
  void setMetadata(Map<String, dynamic> metadata) {
    _currentMetadata = metadata;
    _currentArtist = metadata['artist'] ?? 'Unknown Artist';
    _updateMediaNotification();
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    _isShuffleEnabled = !_isShuffleEnabled;
    if (_isShuffleEnabled) {
      _shuffledIndices.shuffle();
      await _player.setShuffleModeEnabled(true);
    } else {
      _shuffledIndices = List.generate(_playlist.length, (index) => index);
      await _player.setShuffleModeEnabled(false);
    }
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeatEnabled = !_isRepeatEnabled;
    notifyListeners();
  }

  Future<void> restorePlaybackState() async {
    final state = await PlaybackStateService.getPlaybackState();
    if (state['currentSong'] != null && _playlist.isNotEmpty) {
      // Find the index of the last played song
      final lastPlayedIndex = _playlist.indexWhere(
        (file) => file.split('/').last == state['currentSong'],
      );

      if (lastPlayedIndex != -1) {
        _currentIndex = lastPlayedIndex;
        await _player.seek(state['position'], index: lastPlayedIndex);
        if (state['isPlaying']) {
          await _player.play();
        }
      }
    }
  }

  Future<void> generateDailyPlaylist() async {
    if (_playlist.isEmpty) return;
    
    final dailyPlaylist = await PlaylistGeneratorService.generateDailyPlaylist(_playlist);
    await updatePlaylist(dailyPlaylist);
  }

  // Add getCurrentSong method to get the current song from MusicProvider
  Song getCurrentSong() {
    if (_context == null || _currentIndex < 0 || _currentIndex >= _playlist.length) {
      return Song(
        id: '',
        title: 'No song playing',
        artist: 'Unknown Artist',
        album: 'Unknown Album',
        albumId: '',
        duration: 0,
        uri: '',
        trackNumber: 0,
        year: 0,
        dateAdded: 0,
        albumArtUri: '',
      );
    }

    final currentUri = _playlist[_currentIndex];
    final musicProvider = Provider.of<MusicProvider>(_context!, listen: false);
    
    return musicProvider.songs.firstWhere(
      (song) => song.uri == currentUri,
      orElse: () => Song(
        id: '',
        title: currentUri.split('/').last,
        artist: 'Unknown Artist',
        album: 'Unknown Album',
        albumId: '',
        duration: 0,
        uri: currentUri,
        trackNumber: 0,
        year: 0,
        dateAdded: 0,
        albumArtUri: '',
      ),
    );
  }
} 