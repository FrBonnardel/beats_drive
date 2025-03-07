import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class AudioProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _currentSong = 'No Song Selected';
  String _currentArtist = 'No Artist';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  List<String> _playlist = [];
  int _currentIndex = 0;

  AudioProvider() {
    _initAudioPlayer();
    _loadMockData();
  }

  void _initAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
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

  void _loadMockData() {
    _playlist = [
      'Song 1 - Artist 1',
      'Song 2 - Artist 2',
      'Song 3 - Artist 3',
      'Song 4 - Artist 4',
      'Song 5 - Artist 5',
    ];
    _updateCurrentSong();
  }

  bool get isPlaying => _isPlaying;
  String get currentSong => _currentSong;
  String get currentArtist => _currentArtist;
  Duration get duration => _duration;
  Duration get position => _position;
  List<String> get playlist => _playlist;
  int get currentIndex => _currentIndex;

  Future<void> play() async {
    try {
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
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      _updateCurrentSong();
    }
  }

  Future<void> previous() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      _updateCurrentSong();
    }
  }

  void _updateCurrentSong() {
    if (_playlist.isNotEmpty) {
      final songInfo = _playlist[_currentIndex].split(' - ');
      _currentSong = songInfo[0];
      _currentArtist = songInfo[1];
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
} 