import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../providers/music_provider.dart';
import '../providers/audio_provider.dart';
import '../models/music_models.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:math';
import '../widgets/mini_player.dart';
import 'package:beats_drive/widgets/song_list_item.dart';

class MusicItemTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onTap;
  final int index;

  const MusicItemTile({
    super.key,
    required this.file,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _AlbumArtWidget(file: file),
      title: Text(
        file['title'] ?? file['data'].toString().split('/').last,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        file['artist'] ?? 'Unknown Artist',
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

class _AlbumArtWidget extends StatelessWidget {
  final Map<String, dynamic> file;

  const _AlbumArtWidget({
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 56,
        height: 56,
        color: Colors.grey[800],
        child: file['albumArt'] != null
            ? Image.memory(
                file['albumArt'],
                fit: BoxFit.cover,
                cacheWidth: 112,
                cacheHeight: 112,
                errorBuilder: (context, error, stackTrace) {
                  return const _PlaceholderArt();
                },
              )
            : const _PlaceholderArt(),
      ),
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.music_note, color: Colors.white);
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _currentSort = SortOption.titleAsc;
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 50;
  int _currentPage = 0;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    Future.microtask(() async {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      if (musicProvider.songs.isEmpty) {
        await musicProvider.requestPermissionAndScan();
      }
    });
  }

  void _onScroll() {
    if (!_isLoadingMore && 
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      _loadMoreItems();
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore) return;

    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final totalItems = _tabController.index == 0 
        ? musicProvider.songs.length 
        : _tabController.index == 1 
            ? musicProvider.albums.length 
            : musicProvider.artists.length;

    final currentItems = (_currentPage + 1) * _pageSize;
    if (currentItems >= totalItems) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    // Simulate loading delay for smoother UX
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      _currentPage++;
      _isLoadingMore = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset pagination when dependencies change (e.g., when switching tabs)
        _currentPage = 0;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SortOptionsSheet(
        currentSort: _currentSort,
        onSortChanged: (sort) {
          setState(() => _currentSort = sort);
          Provider.of<MusicProvider>(context, listen: false).setSortOption(sort);
              Navigator.pop(context);
            },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
          Consumer<MusicProvider>(
            builder: (context, musicProvider, child) {
              if (musicProvider.isScanning) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => musicProvider.scanMusicFiles(forceRescan: true),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Songs'),
            Tab(text: 'Albums'),
            Tab(text: 'Artists'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSongsList(),
          _buildAlbumGrid(),
          _buildArtistsList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _tabController.index == 3 ? _createPlaylist : _playRandom,
        child: Icon(_tabController.index == 3 ? Icons.playlist_add : Icons.shuffle),
      ),
    );
  }

  Widget _buildSongsList() {
    return Consumer<MusicProvider>(
      builder: (context, provider, child) {
        final songs = provider.songs;
        if (songs.isEmpty) {
          return const Center(
            child: Text(
              'No songs found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final itemCount = (_currentPage + 1) * _pageSize;
        final displayedSongs = songs.take(itemCount).toList();

        return ListView.builder(
          controller: _scrollController,
          itemCount: displayedSongs.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == displayedSongs.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final song = displayedSongs[index];
            return SongListItem(song: song);
          },
        );
      },
    );
  }

  Widget _buildAlbumGrid() {
    return Consumer<MusicProvider>(
      builder: (context, provider, child) {
        final albums = provider.albums;
        if (albums.isEmpty) {
          return const Center(
            child: Text(
              'No albums found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final itemCount = (_currentPage + 1) * (_pageSize ~/ 2);
        final displayedAlbums = albums.take(itemCount).toList();

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: displayedAlbums.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == displayedAlbums.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final album = displayedAlbums[index];
            final firstSongId = album.songs.isNotEmpty ? album.songs.first.id : '';
            
            return InkWell(
              onTap: () => provider.playAlbum(context, album),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _buildAlbumArtForAlbum(firstSongId, provider),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    album.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${album.displayArtist} • ${album.songs.length} songs',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAlbumArtForAlbum(String songId, MusicProvider provider) {
    if (songId.isEmpty) return _buildAlbumContainer(null);
    
    return FutureBuilder<Uint8List?>(
      future: provider.loadAlbumArt(songId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildAlbumContainer(null, isLoading: true);
        }
        if (snapshot.hasError) {
          debugPrint('Error loading album art: ${snapshot.error}');
        }
        return _buildAlbumContainer(snapshot.data);
      },
    );
  }

  Widget _buildAlbumContainer(Uint8List? albumArt, {bool isLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            )
          : albumArt != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    albumArt,
                    fit: BoxFit.cover,
                    cacheWidth: 200,
                    cacheHeight: 200,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error displaying album art: $error');
                      return const _PlaceholderArt();
                    },
                  ),
                )
              : const _PlaceholderArt(),
    );
  }

  Widget _buildArtistsList() {
    return Consumer<MusicProvider>(
      builder: (context, provider, child) {
        final artists = provider.artists;
        if (artists.isEmpty) {
          return const Center(
            child: Text(
              'No artists found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[800],
                child: const Icon(Icons.person, color: Colors.white70),
              ),
              title: Text(
                artist.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${artist.totalAlbums} albums • ${artist.totalSongs} songs',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                // TODO: Navigate to artist detail screen
              },
            );
          },
        );
      },
    );
  }

  void _playRandom() {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    if (musicProvider.songs.isEmpty) return;

    final random = Random();
    final songs = musicProvider.songs;
    final randomIndex = random.nextInt(songs.length);
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    audioProvider.updatePlaylist(songs.map((s) => s.uri).toList());
    audioProvider.selectSong(randomIndex);
  }

  Future<void> _createPlaylist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _CreatePlaylistDialog(),
    );
    if (name != null && name.isNotEmpty) {
      await Provider.of<MusicProvider>(context, listen: false).createPlaylist(name);
    }
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

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

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
                    'No music found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some music to your device',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
      ),
    );
  }
} 