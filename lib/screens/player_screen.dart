import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../services/metadata_service.dart';
import '../services/media_notification_service.dart';
import '../services/playback_state_service.dart';
import '../models/music_models.dart';
import '../screens/playlist_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Map<String, dynamic>? _metadata;
  bool _isLoading = true;
  StreamSubscription? _audioSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlayer();
    });
  }

  Future<void> _initializePlayer() async {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    
    if (musicProvider.songs.isEmpty) {
      await musicProvider.scanMusicFiles();
    }
    
    // Get the current song's metadata if any is playing
    if (audioProvider.currentIndex >= 0 && audioProvider.currentIndex < audioProvider.playlist.length) {
      final currentUri = audioProvider.playlist[audioProvider.currentIndex];
      final song = musicProvider.songs.firstWhere(
        (song) => song.uri == currentUri,
        orElse: () => Song(
          id: '',
          title: 'Unknown Title',
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
      _metadata = {
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
      };
      
      // Load album art
      final albumArt = await musicProvider.loadAlbumArt(song.id);
      if (albumArt != null) {
        _metadata!['albumArt'] = albumArt;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _setupMediaNotificationListener() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    _audioSubscription = audioProvider.currentIndexStream.listen((index) async {
      if (index != null && index < audioProvider.playlist.length) {
        await _loadMetadata();
      }
    });
  }

  Future<void> _loadMetadata() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);

    if (audioProvider.currentIndex >= 0 && audioProvider.currentIndex < audioProvider.playlist.length) {
      final currentUri = audioProvider.playlist[audioProvider.currentIndex];
      final song = musicProvider.songs.firstWhere(
        (song) => song.uri == currentUri,
        orElse: () => Song(
          id: '',
          title: 'Unknown Title',
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

      _metadata = {
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
      };

      // Load album art
      final albumArt = await musicProvider.loadAlbumArt(song.id);
      if (albumArt != null && mounted) {
        setState(() {
          _metadata!['albumArt'] = albumArt;
        });
      } else {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlaylistScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (audioProvider.playlist.isEmpty) {
            return const Center(
              child: Text(
                'No song playing',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final currentSong = audioProvider.getCurrentSong();
          final metadata = audioProvider.currentMetadata;

          return Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Album Art
                    Container(
                      width: 300,
                      height: 300,
                      margin: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: metadata?['albumArt'] != null
                            ? Image.memory(
                                metadata!['albumArt'] as Uint8List,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.music_note,
                                  size: 80,
                                  color: Colors.white70,
                                ),
                              ),
                      ),
                    ),
                    // Song Info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Text(
                            currentSong.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentSong.artist,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[400],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentSong.album,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        inactiveTrackColor: Colors.grey[800],
                        thumbColor: Theme.of(context).colorScheme.primary,
                        overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: audioProvider.position.inMilliseconds.toDouble(),
                        max: audioProvider.duration.inMilliseconds.toDouble(),
                        onChanged: (value) {
                          audioProvider.seek(Duration(milliseconds: value.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(audioProvider.position),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                          Text(
                            _formatDuration(audioProvider.duration),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Playback Controls
              Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        audioProvider.isShuffleEnabled
                            ? Icons.shuffle
                            : Icons.shuffle_outlined,
                        color: audioProvider.isShuffleEnabled
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[400],
                      ),
                      onPressed: audioProvider.toggleShuffle,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 32),
                      color: Colors.white,
                      onPressed: audioProvider.previous,
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: IconButton(
                        icon: Icon(
                          audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 32,
                        ),
                        color: Colors.white,
                        onPressed: () {
                          if (audioProvider.isPlaying) {
                            audioProvider.pause();
                          } else {
                            audioProvider.play();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 32),
                      color: Colors.white,
                      onPressed: audioProvider.next,
                    ),
                    IconButton(
                      icon: Icon(
                        audioProvider.isRepeatEnabled
                            ? Icons.repeat
                            : Icons.repeat_outlined,
                        color: audioProvider.isRepeatEnabled
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[400],
                      ),
                      onPressed: audioProvider.toggleRepeat,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
} 