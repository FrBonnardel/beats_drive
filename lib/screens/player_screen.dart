import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beats_drive/providers/audio_provider.dart';
import 'package:beats_drive/services/metadata_service.dart';
import 'dart:typed_data';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Uint8List? _albumArt;
  String _albumTitle = '';

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    if (audioProvider.currentSong.isNotEmpty) {
      final metadata = await MetadataService.getMetadata(audioProvider.playlist[audioProvider.currentIndex]);
      if (mounted) {
        setState(() {
          _albumArt = metadata['albumArt'] as Uint8List?;
          _albumTitle = metadata['album'] as String? ?? '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Now Playing'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Album Art
                  Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                      image: _albumArt != null
                          ? DecorationImage(
                              image: MemoryImage(_albumArt!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _albumArt == null
                        ? Center(
                            child: Text(
                              audioProvider.currentSong.isNotEmpty
                                  ? audioProvider.currentSong[0]
                                  : '?',
                              style: const TextStyle(
                                fontSize: 48,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 32),
                  // Song Info
                  Text(
                    audioProvider.currentSong,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    audioProvider.currentArtist,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (_albumTitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _albumTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  // Progress Bar
                  Slider(
                    value: audioProvider.position.inSeconds.toDouble(),
                    max: audioProvider.duration.inSeconds.toDouble(),
                    onChanged: (value) {
                      audioProvider.seek(Duration(seconds: value.toInt()));
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(audioProvider.position),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        Text(
                          _formatDuration(audioProvider.duration),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Playback Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: audioProvider.isShuffleEnabled
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        tooltip: audioProvider.isShuffleEnabled 
                            ? 'Disable random playback' 
                            : 'Enable random playback',
                        onPressed: () {
                          audioProvider.toggleShuffle();
                          if (audioProvider.isShuffleEnabled) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Random playback enabled'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Random playback disabled'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: audioProvider.previous,
                      ),
                      FloatingActionButton(
                        onPressed: () {
                          if (audioProvider.isPlaying) {
                            audioProvider.pause();
                          } else {
                            audioProvider.play();
                          }
                        },
                        child: Icon(
                          audioProvider.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: audioProvider.next,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.repeat,
                          color: audioProvider.isRepeatEnabled
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        onPressed: audioProvider.toggleRepeat,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
} 