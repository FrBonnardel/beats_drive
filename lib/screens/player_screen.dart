import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../services/media_notification_service.dart';
import '../services/playback_state_service.dart';
import '../models/music_models.dart';
import '../screens/playlist_screen.dart';

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.music_note,
      size: 100,
      color: Colors.white54,
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late AudioProvider audioProvider;
  late MusicProvider musicProvider;
  bool _isLoading = true;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  Uint8List? _albumArt;
  Song? _currentSong;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  Timer? _updateTimer;
  DateTime _lastPositionUpdate = DateTime.now();
  static const _positionUpdateInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    // Initialize providers
    audioProvider = Provider.of<AudioProvider>(context, listen: false);
    musicProvider = Provider.of<MusicProvider>(context, listen: false);
    _setupSubscriptions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update providers if they change
    audioProvider = Provider.of<AudioProvider>(context);
    musicProvider = Provider.of<MusicProvider>(context);
  }

  void _setupSubscriptions() {
    // Song change subscription
    _audioSubscription?.cancel();
    _audioSubscription = audioProvider.onSongChanged.listen((song) async {
      if (mounted) {
        try {
          // Get the current song from the playlist
          final currentIndex = audioProvider.currentIndex;
          if (currentIndex >= 0 && currentIndex < audioProvider.playlist.length) {
            final uri = audioProvider.playlist[currentIndex];
            final updatedSong = await musicProvider.getSongByUri(uri);
            
            if (mounted) {
              setState(() {
                _currentSong = updatedSong;
                _isLoading = false;
              });
              _loadAlbumArt(updatedSong);
            }
          }
        } catch (e) {
          debugPrint('Error getting song from MediaStore: $e');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    });

    // Position subscription - update every 500ms instead of continuously
    _positionSubscription?.cancel();
    _positionSubscription = audioProvider.audioPlayer.positionStream.listen((position) {
      if (mounted) {
        final now = DateTime.now();
        if (now.difference(_lastPositionUpdate) >= _positionUpdateInterval) {
          setState(() {
            _position = position;
          });
          _lastPositionUpdate = now;
        }
      }
    });

    // Duration subscription
    _durationSubscription?.cancel();
    _durationSubscription = audioProvider.audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      }
    });

    // Playback state subscription
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted && audioProvider.isPlaying != _isPlaying) {
        setState(() {
          _isPlaying = audioProvider.isPlaying;
        });
      }
    });

    // Initial song load
    final currentIndex = audioProvider.currentIndex;
    if (currentIndex >= 0 && currentIndex < audioProvider.playlist.length) {
      final uri = audioProvider.playlist[currentIndex];
      musicProvider.getSongByUri(uri).then((song) {
        if (mounted) {
          setState(() {
            _currentSong = song;
            _isLoading = false;
          });
          _loadAlbumArt(song);
        }
      });
    }
  }

  Future<void> _loadAlbumArt(Song song) async {
    if (song.id.isNotEmpty) {
      final albumArt = await musicProvider.loadAlbumArt(song.id);
      if (albumArt != null && mounted) {
        setState(() {
          _albumArt = albumArt;
        });
      }
    }
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Material(
            color: Colors.transparent,
            child: _buildPlayerContent(),
          );
  }

  Widget _buildPlayerContent() {
    final song = _currentSong ?? Song(
      id: '',
      title: 'No Song',
      artist: 'Unknown Artist',
      album: 'Unknown Album',
      albumId: '',
      duration: 0,
      uri: '',
      albumArtUri: '',
      trackNumber: 0,
      year: 0,
      dateAdded: DateTime.now().millisecondsSinceEpoch,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Album Art
        Container(
          width: 300,
          height: 300,
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FutureBuilder<Uint8List?>(
              future: musicProvider.loadAlbumArt(song.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  debugPrint('Error loading album art: ${snapshot.error}');
                }
                return snapshot.data != null
                    ? Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        width: 300,
                        height: 300,
                        cacheWidth: 600,
                        cacheHeight: 600,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Error displaying album art: $error');
                          return const _PlaceholderArt();
                        },
                      )
                    : const _PlaceholderArt();
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Song Info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Text(
                song.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                song.artist,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                song.album,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white60,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        // Playback Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 40),
              onPressed: () => audioProvider.previous(),
            ),
            const SizedBox(width: 20),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 40,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (_isPlaying) {
                    audioProvider.pause();
                  } else {
                    audioProvider.play();
                  }
                },
              ),
            ),
            const SizedBox(width: 20),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 40),
              onPressed: () => audioProvider.next(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Progress Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              if (_duration.inMilliseconds > 0)
                Slider(
                  value: _position.inMilliseconds.toDouble(),
                  max: _duration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    audioProvider.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
} 