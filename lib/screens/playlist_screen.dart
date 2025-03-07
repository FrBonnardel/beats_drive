import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beats_drive/providers/audio_provider.dart';

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Current Playlist'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  // TODO: Implement playlist editing
                },
              ),
            ],
          ),
          body: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: audioProvider.playlist.length,
            onReorder: (oldIndex, newIndex) {
              // TODO: Implement playlist reordering
            },
            itemBuilder: (context, index) {
              final songInfo = audioProvider.playlist[index].split(' - ');
              final song = songInfo[0];
              final artist = songInfo[1];
              final isPlaying = index == audioProvider.currentIndex;

              return Card(
                key: ValueKey(song),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      song.isNotEmpty ? song[0] : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    song,
                    style: TextStyle(
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                      color: isPlaying
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  subtitle: Text(artist),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPlaying)
                        const Icon(
                          Icons.equalizer,
                          color: Colors.blue,
                        ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          // TODO: Implement remove from playlist
                        },
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                  onTap: () {
                    // TODO: Implement song selection
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
} 