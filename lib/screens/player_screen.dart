import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beats_drive/providers/audio_provider.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Now Playing'),
            centerTitle: true,
          ),
          body: Padding(
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
                  ),
                  child: Center(
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
                  ),
                ),
                const SizedBox(height: 32),
                // Song Info
                Text(
                  audioProvider.currentSong,
                  style: Theme.of(context).textTheme.headlineSmall,
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
                const SizedBox(height: 32),
                // Progress Bar
                Slider(
                  value: audioProvider.position.inSeconds.toDouble(),
                  max: audioProvider.duration.inSeconds.toDouble(),
                  onChanged: (value) {
                    // TODO: Implement seek functionality
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(audioProvider.position),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        _formatDuration(audioProvider.duration),
                        style: Theme.of(context).textTheme.bodySmall,
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
                      icon: const Icon(Icons.shuffle),
                      onPressed: () {
                        // TODO: Implement shuffle functionality
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
                      icon: const Icon(Icons.repeat),
                      onPressed: () {
                        // TODO: Implement repeat functionality
                      },
                    ),
                  ],
                ),
              ],
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