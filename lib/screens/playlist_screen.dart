import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beats_drive/providers/audio_provider.dart';
import 'package:beats_drive/services/metadata_service.dart';
import 'dart:typed_data';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  Map<String, Map<String, dynamic>> _metadataCache = {};

  @override
  void initState() {
    super.initState();
    _loadMetadataForPlaylist();
  }

  Future<void> _loadMetadataForPlaylist() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    for (final filePath in audioProvider.playlist) {
      if (!_metadataCache.containsKey(filePath)) {
        final metadata = await MetadataService.getMetadata(filePath);
        if (mounted) {
          setState(() {
            _metadataCache[filePath] = metadata;
          });
        }
      }
    }
  }

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
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = audioProvider.playlist.removeAt(oldIndex);
              audioProvider.playlist.insert(newIndex, item);
              if (audioProvider.currentIndex == oldIndex) {
                audioProvider.currentIndex = newIndex;
              } else if (audioProvider.currentIndex > oldIndex &&
                  audioProvider.currentIndex <= newIndex) {
                audioProvider.currentIndex--;
              } else if (audioProvider.currentIndex < oldIndex &&
                  audioProvider.currentIndex >= newIndex) {
                audioProvider.currentIndex++;
              }
            },
            itemBuilder: (context, index) {
              final filePath = audioProvider.playlist[index];
              final metadata = _metadataCache[filePath] ?? {};
              final title = metadata['title'] as String? ?? filePath.split('/').last;
              final artist = metadata['artist'] as String? ?? 'Unknown Artist';
              final albumArt = metadata['albumArt'] as Uint8List?;
              final isPlaying = index == audioProvider.currentIndex;

              return Card(
                key: ValueKey('playlist_item_$index'),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: albumArt != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.memory(
                            albumArt,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(
                            title.isNotEmpty ? title[0] : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                  title: Text(
                    title,
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
                          _showRemoveConfirmation(context, audioProvider, index);
                        },
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                  onTap: () {
                    audioProvider.selectSong(index);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showRemoveConfirmation(BuildContext context, AudioProvider audioProvider, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Song'),
          content: const Text('Are you sure you want to remove this song from the playlist?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                audioProvider.removeFromPlaylist(index);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }
} 