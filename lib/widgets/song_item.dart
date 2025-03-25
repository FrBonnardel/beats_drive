import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_provider.dart';
import 'paginated_grid_list.dart';

class SongListItem extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const SongListItem({
    Key? key,
    required this.song,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final notifier = musicProvider.getAlbumArtNotifier(song.id);
    if (notifier == null) {
      return Container(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : null,
        child: ListTile(
          key: ValueKey(song.id),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          leading: SizedBox(
            width: 56,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                color: Colors.grey[800],
                child: const Icon(Icons.music_note, color: Colors.white70),
              ),
            ),
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
          trailing: Text(
            _formatDuration(song.duration),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      );
    }
    final duration = _formatDuration(song.duration);

    return Container(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: RepaintBoundary(
        child: ListTile(
          key: ValueKey(song.id),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          leading: SizedBox(
            width: 56,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ValueListenableBuilder<Uint8List?>(
                valueListenable: notifier,
                builder: (context, albumArt, child) {
                  if (albumArt == null) {
                    return Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, color: Colors.white70),
                    );
                  }
                  return Image.memory(
                    albumArt,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.music_note, color: Colors.white70),
                      );
                    },
                  );
                },
              ),
            ),
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
          trailing: Text(
            duration,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class SongItem extends StatefulWidget {
  final List<Song> songs;
  final bool isLoading;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Function(Song) onSongTap;
  final Function(Song) onSongLongPress;
  final ScrollController? scrollController;
  final int? selectedIndex;

  const SongItem({
    super.key,
    required this.songs,
    required this.isLoading,
    required this.hasMore,
    required this.onLoadMore,
    required this.onRetry,
    required this.onSongTap,
    required this.onSongLongPress,
    this.scrollController,
    this.selectedIndex,
  });

  @override
  State<SongItem> createState() => _SongItemState();
}

class _SongItemState extends State<SongItem> {
  final Map<String, ValueNotifier<Uint8List?>> _albumArtNotifiers = {};

  @override
  void dispose() {
    // Properly dispose of all ValueNotifiers
    for (var notifier in _albumArtNotifiers.values) {
      notifier.dispose();
    }
    _albumArtNotifiers.clear();
    super.dispose();
  }

  ValueNotifier<Uint8List?> _getAlbumArtNotifier(String songId) {
    if (!_albumArtNotifiers.containsKey(songId)) {
      _albumArtNotifiers[songId] = ValueNotifier<Uint8List?>(null);
    }
    return _albumArtNotifiers[songId]!;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      itemCount: widget.songs.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.songs.length) {
          if (widget.isLoading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          widget.onLoadMore();
          return const SizedBox.shrink();
        }

        final song = widget.songs[index];
        final isSelected = widget.selectedIndex == index;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          leading: SizedBox(
            width: 48,
            height: 48,
            child: Consumer<MusicProvider>(
              builder: (context, musicProvider, child) {
                return FutureBuilder<Uint8List?>(
                  future: musicProvider.loadAlbumArt(song.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    
                    final albumArt = snapshot.data;
                    if (albumArt != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.memory(
                          albumArt,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.music_note);
                          },
                        ),
                      );
                    }
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.music_note),
                    );
                  },
                );
              },
            ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          subtitle: Text(
            '${song.artist} • ${song.album}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.7) : null,
            ),
          ),
          selected: isSelected,
          onTap: () => widget.onSongTap(song),
          onLongPress: () => widget.onSongLongPress(song),
        );
      },
    );
  }
} 