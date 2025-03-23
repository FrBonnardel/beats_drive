import 'package:flutter/material.dart';
import '../models/music_models.dart';
import 'song_list_item.dart';
import 'paginated_grid_list.dart';

class SongItem extends StatelessWidget {
  final List<Song> songs;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Function(Song) onSongTap;
  final Function(Song) onSongLongPress;
  final Widget? emptyView;
  final Widget? loadingIndicator;
  final Widget? errorView;

  const SongItem({
    Key? key,
    required this.songs,
    required this.isLoading,
    required this.hasMore,
    required this.onLoadMore,
    required this.onRetry,
    required this.onSongTap,
    required this.onSongLongPress,
    this.error,
    this.emptyView,
    this.loadingIndicator,
    this.errorView,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PaginatedGridList<Song>(
      items: songs,
      isLoading: isLoading,
      hasMore: hasMore,
      error: error,
      onLoadMore: onLoadMore,
      onRetry: onRetry,
      onItemTap: onSongTap,
      onItemLongPress: onSongLongPress,
      itemBuilder: (song) => SongListItem(
        song: song,
        onTap: () => onSongTap(song),
        onLongPress: () => onSongLongPress(song),
      ),
      crossAxisCount: 1,
      isList: true,
    );
  }
} 