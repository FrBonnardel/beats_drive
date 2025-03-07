import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beats_drive/providers/audio_provider.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Music Library'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  // TODO: Implement search functionality
                },
              ),
            ],
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: audioProvider.playlist.length,
            itemBuilder: (context, index) {
              final songInfo = audioProvider.playlist[index].split(' - ');
              final song = songInfo[0];
              final artist = songInfo[1];
              final isPlaying = index == audioProvider.currentIndex;

              return Card(
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
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      // TODO: Implement song options menu
                    },
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