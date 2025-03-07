import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:io';

class AudioProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _currentSong = 'No Song Selected';
  String _currentArtist = 'No Artist';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  List<String> _playlist = [];
  List<String> _filteredPlaylist = [];
  int _currentIndex = 0;
  String _searchQuery = '';
  bool _isShuffleEnabled = false;
  bool _isRepeatEnabled = false;
  List<int> _shuffleOrder = [];

  AudioProvider() {
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
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
      notifyListeners();
    });
  }

  void _handleSongCompletion() {
    if (_isRepeatEnabled) {
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
    } else {
      next();
    }
  }

  void updatePlaylist(List<String> musicFiles) {
    _playlist = musicFiles;
    _filteredPlaylist = _playlist;
    if (_currentIndex >= _playlist.length) {
      _currentIndex = 0;
    }
    _updateCurrentSong();
    notifyListeners();
  }

  bool get isPlaying => _isPlaying;
  String get currentSong => _currentSong;
  String get currentArtist => _currentArtist;
  Duration get duration => _duration;
  Duration get position => _position;
  List<String> get playlist => _filteredPlaylist;
  int get currentIndex => _currentIndex;
  String get searchQuery => _searchQuery;
  bool get isShuffleEnabled => _isShuffleEnabled;
  bool get isRepeatEnabled => _isRepeatEnabled;

  set currentIndex(int value) {
    if (value >= 0 && value < _playlist.length) {
      _currentIndex = value;
      _updateCurrentSong();
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _filterPlaylist();
    notifyListeners();
  }

  void _filterPlaylist() {
    if (_searchQuery.isEmpty) {
      _filteredPlaylist = _playlist;
    } else {
      _filteredPlaylist = _playlist.where((filePath) {
        final fileName = filePath.split('/').last.toLowerCase();
        return fileName.contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  void removeFromPlaylist(int index) {
    if (index >= 0 && index < _playlist.length) {
      _playlist.removeAt(index);
      if (_currentIndex == index) {
        if (_playlist.isEmpty) {
          _currentIndex = 0;
          _currentSong = 'No Song Selected';
          _currentArtist = 'No Artist';
        } else if (_currentIndex >= _playlist.length) {
          _currentIndex = _playlist.length - 1;
        }
        _updateCurrentSong();
      } else if (_currentIndex > index) {
        _currentIndex--;
      }
      _filterPlaylist();
      notifyListeners();
    }
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

  Future<void> play() async {
    try {
      if (_playlist.isEmpty) return;
      final filePath = _playlist[_currentIndex];
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  Future<void> next() async {
    if (_isShuffleEnabled && _shuffleOrder.isNotEmpty) {
      final currentShuffleIndex = _shuffleOrder.indexOf(_currentIndex);
      if (currentShuffleIndex < _shuffleOrder.length - 1) {
        _currentIndex = _shuffleOrder[currentShuffleIndex + 1];
      } else {
        _generateShuffleOrder();
        _currentIndex = _shuffleOrder[0];
      }
    } else if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
    }
    _updateCurrentSong();
    await play();
  }

  Future<void> previous() async {
    if (_isShuffleEnabled && _shuffleOrder.isNotEmpty) {
      final currentShuffleIndex = _shuffleOrder.indexOf(_currentIndex);
      if (currentShuffleIndex > 0) {
        _currentIndex = _shuffleOrder[currentShuffleIndex - 1];
      } else {
        _generateShuffleOrder();
        _currentIndex = _shuffleOrder.last;
      }
    } else if (_currentIndex > 0) {
      _currentIndex--;
    }
    _updateCurrentSong();
    await play();
  }

  void selectSong(int index) {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      _updateCurrentSong();
      play();
    }
  }

  void _updateCurrentSong() {
    if (_playlist.isNotEmpty) {
      final filePath = _playlist[_currentIndex];
      final fileName = filePath.split('/').last;
      _currentSong = fileName;
      _currentArtist = 'Local Music'; // This will be updated with metadata
      notifyListeners();
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('Error seeking audio: $e');
    }
  }

  Future<void> restart() async {
    try {
      await _audioPlayer.seek(Duration.zero);
      if (!_isPlaying) {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('Error restarting audio: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
} 