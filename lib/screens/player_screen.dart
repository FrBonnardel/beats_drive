import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/audio_provider.dart';
import '../services/metadata_service.dart';
import '../services/media_notification_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _metadata;
  StreamSubscription? _audioSubscription;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _setupAudioListener();
    _setupMediaNotificationListener();
  }

  void _setupMediaNotificationListener() {
    MediaNotificationService.onPlay.listen((_) {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      audioProvider.play();
    });

    MediaNotificationService.onPause.listen((_) {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      audioProvider.pause();
    });

    MediaNotificationService.onStop.listen((_) {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      audioProvider.stop();
    });

    MediaNotificationService.onNext.listen((_) {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      audioProvider.selectSong(audioProvider.currentIndex + 1);
    });

    MediaNotificationService.onPrevious.listen((_) {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      audioProvider.selectSong(audioProvider.currentIndex - 1);
    });
  }

  void _setupAudioListener() {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    _audioSubscription = audioProvider.audioPlayer.playerStateStream.listen((_) {
      if (mounted) {
        _loadMetadata();
      }
    });
  }

  Future<void> _loadMetadata() async {
    if (!mounted) return;
    
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    
    if (audioProvider.playlist.isNotEmpty && audioProvider.currentIndex < audioProvider.playlist.length) {
      final song = audioProvider.playlist[audioProvider.currentIndex];
      final metadata = await MetadataService.getMetadata(song);
      
      if (mounted) {
        setState(() {
          _metadata = metadata;
          _isLoading = false;
        });
        audioProvider.setMetadata(metadata);
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
      ),
      body: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (audioProvider.playlist.isEmpty) {
            return const Center(child: Text('No song playing'));
          }

          final song = audioProvider.playlist[audioProvider.currentIndex];
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Album Art
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _metadata?['albumArt'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _metadata!['albumArt'],
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Error loading album art: $error');
                            debugPrint('Stack trace: $stackTrace');
                            return _buildPlaceholderArtwork();
                          },
                        ),
                      )
                    : _buildPlaceholderArtwork(),
              ),
              const SizedBox(height: 20),
              
              // Song Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      _metadata?['title'] ?? song,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _metadata?['artist'] ?? 'Unknown Artist',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _metadata?['album'] ?? 'Unknown Album',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Slider(
                      value: audioProvider.position.inSeconds.toDouble(),
                      max: audioProvider.duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        audioProvider.seek(Duration(seconds: value.toInt()));
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(audioProvider.position),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _formatDuration(audioProvider.duration),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      audioProvider.isShuffleEnabled ? Icons.shuffle : Icons.shuffle_outlined,
                      size: 30,
                    ),
                    onPressed: () {
                      audioProvider.toggleShuffle();
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 40),
                    onPressed: () {
                      audioProvider.selectSong(audioProvider.currentIndex - 1);
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: Icon(
                      audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 60,
                    ),
                    onPressed: () {
                      if (audioProvider.isPlaying) {
                        audioProvider.pause();
                      } else {
                        audioProvider.play();
                      }
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 40),
                    onPressed: () {
                      audioProvider.selectSong(audioProvider.currentIndex + 1);
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: Icon(
                      audioProvider.isRepeatEnabled ? Icons.repeat_one : Icons.repeat,
                      size: 30,
                    ),
                    onPressed: () {
                      audioProvider.toggleRepeat();
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderArtwork() {
    return Container(
      width: 300,
      height: 300,
      color: Colors.grey[800],
      child: const Icon(
        Icons.music_note,
        size: 100,
        color: Colors.white54,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
} 