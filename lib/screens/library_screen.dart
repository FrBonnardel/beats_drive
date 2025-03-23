import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'dart:async';
import '../providers/music_provider.dart';
import '../providers/audio_provider.dart';
import '../models/music_models.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:math';
import '../widgets/mini_player.dart';
import 'package:beats_drive/widgets/song_list_item.dart';
import '../widgets/shared_widgets.dart';
import '../services/cache_service.dart';
import '../screens/loading_screen.dart';
import '../widgets/album_item.dart';
import '../widgets/artist_item.dart';
import '../widgets/paginated_grid_list.dart';
import '../widgets/song_options_bottom_sheet.dart';
import '../widgets/song_item.dart';

// Static widgets
class _LibraryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onSortPressed;
  final VoidCallback onSearchPressed;

  const _LibraryAppBar({
    required this.onSortPressed,
    required this.onSearchPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Library'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: onSearchPressed,
        ),
        IconButton(
          icon: const Icon(Icons.sort),
          onPressed: onSortPressed,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AlbumArtContainer extends StatelessWidget {
  final Widget child;
  final double size;

  const _AlbumArtContainer({
    required this.child,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: child,
      ),
    );
  }
}

class _AlbumArtPlaceholder extends StatelessWidget {
  const _AlbumArtPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.music_note, color: Colors.white70);
  }
}

class _AlbumArtLoadingIndicator extends StatelessWidget {
  const _AlbumArtLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String message;
  final String? subMessage;

  const _EmptyView({
    required this.message,
    this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          if (subMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              subMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _SortOptionsSheet extends StatelessWidget {
  final SortOption currentSort;
  final ValueChanged<SortOption> onSortChanged;

  const _SortOptionsSheet({
    required this.currentSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Sort by'),
            tileColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
          _buildSortOption(context, 'Title (A-Z)', SortOption.titleAsc),
          _buildSortOption(context, 'Title (Z-A)', SortOption.titleDesc),
          _buildSortOption(context, 'Artist (A-Z)', SortOption.artistAsc),
          _buildSortOption(context, 'Artist (Z-A)', SortOption.artistDesc),
          _buildSortOption(context, 'Album (A-Z)', SortOption.albumAsc),
          _buildSortOption(context, 'Album (Z-A)', SortOption.albumDesc),
          _buildSortOption(context, 'Date Added (Newest)', SortOption.dateAddedDesc),
          _buildSortOption(context, 'Date Added (Oldest)', SortOption.dateAddedAsc),
          _buildSortOption(context, 'Duration (Shortest)', SortOption.durationAsc),
          _buildSortOption(context, 'Duration (Longest)', SortOption.durationDesc),
        ],
      ),
    );
  }

  Widget _buildSortOption(BuildContext context, String title, SortOption option) {
    return ListTile(
      title: Text(title),
      leading: Radio<SortOption>(
        value: option,
        groupValue: currentSort,
        onChanged: (value) => onSortChanged(value!),
      ),
      onTap: () => onSortChanged(option),
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  _CreatePlaylistDialogState createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Playlist'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Playlist name',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  final List<Song> _songs = [];
  final List<Album> _albums = [];
  final List<Artist> _artists = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  String? _error;
  late TabController _tabController;
  int _currentTab = 0;
  SortOption _currentSort = SortOption.titleAsc;

  void showSortDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SortOptionsSheet(
        currentSort: _currentSort,
        onSortChanged: (option) {
          setState(() {
            _currentSort = option;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search songs, albums, or artists',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            // TODO: Implement search functionality
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });
    _loadMoreSongs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      final songs = await musicProvider.getSongsByUris(
        musicProvider.songs
            .skip(_currentPage * _pageSize)
            .take(_pageSize)
            .map((song) => song.uri)
            .toList(),
      );

      if (mounted) {
        setState(() {
          _songs.addAll(songs);
          _currentPage++;
          _hasMore = songs.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load songs: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreAlbums() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      final albums = musicProvider.albums
          .skip(_currentPage * _pageSize)
          .take(_pageSize)
          .toList();

      if (mounted) {
        setState(() {
          _albums.addAll(albums);
          _currentPage++;
          _hasMore = albums.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load albums: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreArtists() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      final artists = musicProvider.artists
          .skip(_currentPage * _pageSize)
          .take(_pageSize)
          .toList();

      if (mounted) {
        setState(() {
          _artists.addAll(artists);
          _currentPage++;
          _hasMore = artists.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load artists: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _handleSongTap(Song song) {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final index = audioProvider.playlist.indexOf(song.uri);
    if (index != -1) {
      audioProvider.selectSong(index);
      audioProvider.play();
    } else {
      // If song is not in playlist, add it and play
      audioProvider.addToPlaylist(song.uri);
      audioProvider.selectSong(audioProvider.playlist.length - 1);
      audioProvider.play();
    }
  }

  void _handleSongLongPress(Song song) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SongOptionsBottomSheet(song: song),
    );
  }

  void _handleAlbumTap(Album album) {
    // TODO: Navigate to album detail screen
  }

  void _handleAlbumLongPress(Album album) {
    // TODO: Show album options
  }

  void _handleArtistTap(Artist artist) {
    // TODO: Navigate to artist detail screen
  }

  void _handleArtistLongPress(Artist artist) {
    // TODO: Show artist options
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Songs'),
              Tab(text: 'Albums'),
              Tab(text: 'Artists'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Songs tab
                SongItem(
                  songs: _songs,
                  isLoading: _isLoading,
                  hasMore: _hasMore,
                  error: _error,
                  onLoadMore: _loadMoreSongs,
                  onRetry: () {
                    setState(() {
                      _error = null;
                      _currentPage = 0;
                      _songs.clear();
                      _hasMore = true;
                    });
                    _loadMoreSongs();
                  },
                  onSongTap: _handleSongTap,
                  onSongLongPress: _handleSongLongPress,
                ),
                // Albums tab
                PaginatedGridList(
                  items: _albums,
                  isLoading: _isLoading,
                  hasMore: _hasMore,
                  error: _error,
                  onLoadMore: _loadMoreAlbums,
                  onRetry: () {
                    setState(() {
                      _error = null;
                      _currentPage = 0;
                      _albums.clear();
                      _hasMore = true;
                    });
                    _loadMoreAlbums();
                  },
                  onItemTap: _handleAlbumTap,
                  onItemLongPress: _handleAlbumLongPress,
                  itemBuilder: (album) => AlbumItem(album: album),
                  crossAxisCount: 2,
                ),
                // Artists tab
                PaginatedGridList(
                  items: _artists,
                  isLoading: _isLoading,
                  hasMore: _hasMore,
                  error: _error,
                  onLoadMore: _loadMoreArtists,
                  onRetry: () {
                    setState(() {
                      _error = null;
                      _currentPage = 0;
                      _artists.clear();
                      _hasMore = true;
                    });
                    _loadMoreArtists();
                  },
                  onItemTap: _handleArtistTap,
                  onItemLongPress: _handleArtistLongPress,
                  itemBuilder: (artist) => ArtistItem(artist: artist),
                  crossAxisCount: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SongListItem extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const SongListItem({
    Key? key,
    required this.song,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: song.albumArtUri.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                song.albumArtUri,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note),
              ),
            )
          : const Icon(Icons.music_note),
      title: Text(song.title),
      subtitle: Text(song.artist),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class SongOptionsBottomSheet extends StatelessWidget {
  final Song song;

  const SongOptionsBottomSheet({
    Key? key,
    required this.song,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            song.title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            song.artist,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Add to Playlist'),
            onTap: () {
              // TODO: Implement add to playlist functionality
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Add to Favorites'),
            onTap: () {
              // TODO: Implement add to favorites functionality
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Song Info'),
            onTap: () {
              // TODO: Implement song info functionality
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
} 