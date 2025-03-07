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
  Map<String, dynamic> _metadata = {};

  @override
  void initState() {
    super.initState();
    // Add listener for song changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final audioProvider = Provider.of<AudioProvider>(context, listen: false);
        audioProvider.addListener(_onAudioProviderChanged);
        _loadMetadata();
      }
    });
  }

  @override
  void dispose() {
    if (mounted) {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      audioProvider.removeListener(_onAudioProviderChanged);
    }
    super.dispose();
  }

  void _onAudioProviderChanged() {
    if (mounted) {
      _loadMetadata();
    }
  }

  Future<void> _loadMetadata() async {
    if (!mounted) return;
    
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    if (audioProvider.currentSong.isNotEmpty && audioProvider.currentSong != 'No Song Selected') {
      try {
        final metadata = await MetadataService.getMetadata(audioProvider.playlist[audioProvider.currentIndex]);
        if (mounted) {
          setState(() {
            _metadata = metadata;
            _albumArt = metadata['albumArt'] as Uint8List?;
          });
        }
      } catch (e) {
        debugPrint('Error loading metadata: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        final title = _metadata['title'] as String? ?? audioProvider.currentSong;
        final artist = _metadata['artist'] as String? ?? audioProvider.currentArtist;
        final album = _metadata['album'] as String? ?? '';
        final year = _metadata['year'] as String? ?? '';
        final genre = _metadata['genre'] as String? ?? '';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Now Playing'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
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
                                  child: Icon(
                                    Icons.music_note,
                                    size: 100,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 32),
                        // Song Info with horizontal scrolling
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width - 48,
                                child: Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 20,
                                      ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: MediaQuery.of(context).size.width - 48,
                                child: Text(
                                  artist,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (album.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width - 48,
                                  child: Text(
                                    album,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              if (year.isNotEmpty || genre.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width - 48,
                                  child: Text(
                                    [
                                      if (year.isNotEmpty) year,
                                      if (year.isNotEmpty && genre.isNotEmpty) ' • ',
                                      if (genre.isNotEmpty) genre,
                                    ].join(''),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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
                      ],
                    ),
                  ),
                ),
              ),
              // Fixed bottom controls
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
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
                    IconButton(
                      icon: const Icon(Icons.restart_alt),
                      onPressed: audioProvider.restart,
                      tooltip: 'Restart current song',
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
              ),
            ],
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