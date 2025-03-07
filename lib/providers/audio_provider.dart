import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:io';
import 'package:beats_drive/services/metadata_service.dart';
import 'package:flutter/material.dart';
import '../services/media_notification_service.dart';

class AudioProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Map<String, dynamic>? _currentMetadata;
  String _searchQuery = '';
  bool _isShuffleEnabled = false;
  bool _isRepeatEnabled = false;
  List<int> _shuffleOrder = [];
  String _currentSong = '';
  String _currentArtist = '';

  AudioProvider() {
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _handleSongCompletion();
      }
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((position) {
      _position = position;
      _updateMediaNotification();
      notifyListeners();
    });

    _audioPlayer.currentIndexStream.listen((index) async {
      _currentIndex = index ?? 0;
      if (index != null && index < _playlist.length) {
        _currentSong = _playlist[index].split('/').last;
        // Get metadata for the current song
        _currentMetadata = await MetadataService.getMetadata(_playlist[index]);
        _currentArtist = _currentMetadata?['artist'] ?? 'Unknown Artist';
        _updateMediaNotification();
      }
      notifyListeners();
    });
  }

  void _updateMediaNotification() {
    if (_currentMetadata != null) {
      MediaNotificationService.showNotification(
        title: _currentMetadata!['title'] ?? "Unknown Title",
        author: _currentMetadata!['artist'] ?? "Unknown Artist",
        image: _currentMetadata!['albumArt'],
        play: _isPlaying,
      );
    }
  }

  Future<void> updatePlaylist(List<String> files) async {
    // Only update if the playlist is different
    if (_playlist != files) {
      _playlist = files;
      await _audioPlayer.setAudioSource(
        ConcatenatingAudioSource(
          children: files.map((file) => AudioSource.file(file)).toList(),
        ),
      );
      // Get metadata for the current song if we have one
      if (_currentIndex >= 0 && _currentIndex < files.length) {
        _currentMetadata = await MetadataService.getMetadata(files[_currentIndex]);
        _currentArtist = _currentMetadata?['artist'] ?? 'Unknown Artist';
        _currentSong = files[_currentIndex].split('/').last;
      } else if (files.isNotEmpty) {
        _currentMetadata = await MetadataService.getMetadata(files[0]);
        _currentArtist = _currentMetadata?['artist'] ?? 'Unknown Artist';
        _currentSong = files[0].split('/').last;
      }
      notifyListeners();
    }
  }

  Future<void> selectSong(int index) async {
    if (index >= 0 && index < _playlist.length) {
      await _audioPlayer.seek(Duration.zero, index: index);
      await _audioPlayer.play();
    }
  }

  Future<void> play() async {
    await _audioPlayer.play();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    await MediaNotificationService.hideNotification();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
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

  void _handleSongCompletion() {
    if (_isRepeatEnabled) {
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
    } else if (_currentIndex < _playlist.length - 1) {
      selectSong(_getNextIndex());
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
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
  AudioPlayer get audioPlayer => _audioPlayer;
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

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    if (_isShuffleEnabled) {
      _generateShuffleOrder();
    }
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeatEnabled = !_isRepeatEnabled;
    notifyListeners();
  }

  void _generateShuffleOrder() {
    _shuffleOrder = List.generate(_playlist.length, (index) => index);
    _shuffleOrder.shuffle();
  }

  int _getNextIndex() {
    if (_isShuffleEnabled) {
      final currentShuffleIndex = _shuffleOrder.indexOf(_currentIndex);
      if (currentShuffleIndex < _shuffleOrder.length - 1) {
        return _shuffleOrder[currentShuffleIndex + 1];
      }
      _generateShuffleOrder();
      return _shuffleOrder[0];
    }
    return _currentIndex + 1;
  }
} 