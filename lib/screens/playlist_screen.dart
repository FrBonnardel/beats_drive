import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../models/music_models.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  Map<String, Song> _songCache = {};
  Map<String, Uint8List?> _artworkCache = {};

  @override
  void initState() {
    super.initState();
    _loadSongsForPlaylist();
  }

  Future<void> _loadSongsForPlaylist() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);

    for (final uri in audioProvider.playlist) {
      if (!_songCache.containsKey(uri)) {
        final song = musicProvider.songs.firstWhere(
          (song) => song.uri == uri,
          orElse: () => Song(
            id: '',
            title: uri.split('/').last,
            artist: 'Unknown Artist',
            album: 'Unknown Album',
            albumId: '',
            duration: 0,
            uri: uri,
            trackNumber: 0,
            year: 0,
            dateAdded: 0,
            albumArtUri: '',
          ),
        );

        if (mounted) {
          setState(() {
            _songCache[uri] = song;
          });

          // Load album art
          if (song.id.isNotEmpty) {
            final albumArt = await musicProvider.loadAlbumArt(song.id);
            if (mounted) {
              setState(() {
                _artworkCache[uri] = albumArt;
              });
            }
          }
        }
      }
    }
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
                icon: const Icon(Icons.shuffle),
                onPressed: audioProvider.toggleShuffle,
                color: audioProvider.isShuffleEnabled
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.repeat),
                onPressed: audioProvider.toggleRepeat,
                color: audioProvider.isRepeatEnabled
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ],
          ),
          body: audioProvider.playlist.isEmpty
              ? const Center(
                  child: Text(
                    'No songs in playlist',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(8),
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
                    final uri = audioProvider.playlist[index];
                    final song = _songCache[uri];
                    final albumArt = _artworkCache[uri];
                    final isPlaying = index == audioProvider.currentIndex;

                    return ListTile(
                      key: Key('playlist_item_$index'),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: albumArt != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(
                                  albumArt,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.music_note, color: Colors.white70),
                      ),
                      title: Text(
                        song?.title ?? uri.split('/').last,
                        style: TextStyle(
                          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                          color: isPlaying
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song?.artist ?? 'Unknown Artist',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPlaying)
                            Icon(
                              Icons.volume_up,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(song?.duration ?? 0),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(
                              Icons.drag_handle,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => audioProvider.selectSong(index),
                    );
                  },
                ),
        );
      },
    );
  }
} 