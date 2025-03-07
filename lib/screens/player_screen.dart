import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/audio_provider.dart';
import '../services/metadata_service.dart';

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
    
    if (audioProvider.currentSong != null) {
      final song = audioProvider.currentSong!;
      final metadata = await MetadataService.getMetadata(song);
      
      if (mounted) {
        setState(() {
          _metadata = metadata;
          _isLoading = false;
        });
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

          final song = audioProvider.currentSong;
          if (song == null) {
            return const Center(child: Text('No song playing'));
          }

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
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 300,
                              height: 300,
                              color: Colors.grey[800],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.music_note, 
                                    size: 100, 
                                    color: Colors.white.withOpacity(0.5)
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Album Art',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    : Container(
                        width: 300,
                        height: 300,
                        color: Colors.grey[800],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_note, 
                              size: 100, 
                              color: Colors.white.withOpacity(0.5)
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Album Art',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        Text(audioProvider.position.toString().split('.').first),
                        Text(audioProvider.duration.toString().split('.').first),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: audioProvider.previous,
                  ),
                  IconButton(
                    icon: Icon(audioProvider.isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      if (audioProvider.isPlaying) {
                        audioProvider.pause();
                      } else {
                        audioProvider.play();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: audioProvider.next,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
} 