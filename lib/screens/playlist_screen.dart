import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../models/music_models.dart';
import '../widgets/song_list_item.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final ScrollController _scrollController = ScrollController();
  Map<String, Song> _songCache = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialSongs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToCurrentSong();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentSong() {
    if (!_scrollController.hasClients) return;
    
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final currentIndex = audioProvider.currentIndex;
    
    if (currentIndex != null && currentIndex >= 0) {
      final itemHeight = 72.0; // Estimated height of each list item
      final offset = currentIndex * itemHeight;
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadInitialSongs() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);

      for (final uri in audioProvider.playlist) {
        if (!_songCache.containsKey(uri)) {
          try {
            final song = await musicProvider.getSongByUri(uri);
            if (mounted) {
              setState(() {
                _songCache[uri] = song;
              });
            }
          } catch (e) {
            debugPrint('Error loading song for URI $uri: $e');
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AudioProvider, MusicProvider>(
      builder: (context, audioProvider, musicProvider, child) {
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
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: audioProvider.playlist.length,
                  itemBuilder: (context, index) {
                    final uri = audioProvider.playlist[index];
                    final song = _songCache[uri];
                    
                    if (song == null) {
                      return ListTile(
                        title: Text(uri.split('/').last),
                        subtitle: const Text('Loading...'),
                      );
                    }

                    return Container(
                      color: index == audioProvider.currentIndex
                          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                          : null,
                      child: ListTile(
                        leading: FutureBuilder<Uint8List?>(
                          future: musicProvider.loadAlbumArt(song.id),
                          builder: (context, snapshot) {
                            return Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: snapshot.data != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(Icons.music_note, color: Colors.white70),
                            );
                          },
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${song.artist} • ${song.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
} 