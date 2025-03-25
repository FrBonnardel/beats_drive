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
import 'package:beats_drive/widgets/song_item.dart';
import '../widgets/shared_widgets.dart';
import '../services/cache_service.dart';
import '../widgets/album_item.dart';
import '../widgets/artist_item.dart';
import '../widgets/paginated_grid_list.dart';
import '../widgets/song_options_bottom_sheet.dart';

// Static widgets
class _LibraryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onSortPressed;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _LibraryAppBar({
    required this.onSortPressed,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: TextField(
        autofocus: false,
        decoration: InputDecoration(
          hintText: 'Search songs, albums, or artists',
          border: InputBorder.none,
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onSearchChanged(''),
                )
              : null,
        ),
        onChanged: onSearchChanged,
        controller: TextEditingController(text: searchQuery),
      ),
      actions: [
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
      child: SingleChildScrollView(
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
  late TabController _tabController;
  int _currentTab = 0;
  SortOption _currentSort = SortOption.titleAsc;
  String _searchQuery = '';

  // Separate state for each tab
  final Map<int, bool> _isLoading = {
    0: false, // Songs tab
    1: false, // Albums tab
    2: false, // Artists tab
  };
  final Map<int, String?> _errors = {
    0: null, // Songs tab
    1: null, // Albums tab
    2: null, // Artists tab
  };
  final Map<int, int> _currentPages = {
    0: 0, // Songs tab
    1: 0, // Albums tab
    2: 0, // Artists tab
  };
  final Map<int, bool> _hasMore = {
    0: true, // Songs tab
    1: true, // Albums tab
    2: true, // Artists tab
  };
  static const int _pageSize = 20;

  void refresh() {
    _resetPagination();
    _songs.clear();
    _albums.clear();
    _artists.clear();
    _loadContentForTab(_currentTab);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
      
      // Load content for the selected tab if it's empty
      _loadContentForTab(_currentTab);
    });

    // Listen to music provider updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      musicProvider.addListener(_onMusicProviderUpdate);
      
      // Listen to individual song updates
      musicProvider.onSongUpdated.listen((song) {
        if (!mounted) return;
        
        setState(() {
          // Add the song if it matches the search criteria
          if (_matchesSearchQuery(song)) {
            final existingIndex = _songs.indexWhere((s) => s.uri == song.uri);
            if (existingIndex != -1) {
              _songs[existingIndex] = song;
            } else {
              _songs.add(song);
            }
            _sortSongs(_songs);
          }
        });
      });
      
      // Load initial content from cache
      _loadInitialContent();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    musicProvider.removeListener(_onMusicProviderUpdate);
    super.dispose();
  }

  void _loadContentForTab(int tab) {
    switch (tab) {
      case 0:
        if (_songs.isEmpty) _loadMoreSongs(forceReload: true);
        break;
      case 1:
        if (_albums.isEmpty) _loadMoreAlbums(forceReload: true);
        break;
      case 2:
        if (_artists.isEmpty) _loadMoreArtists(forceReload: true);
        break;
    }
  }

  void _onMusicProviderUpdate() {
    if (!mounted) return;
    
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    
    // Handle complete refresh if needed
    if (musicProvider.songs.isEmpty) {
      setState(() {
        _songs.clear();
        _albums.clear();
        _artists.clear();
        _resetPagination();
      });
      return;
    }

    // Load any missing songs
    final availableSongs = musicProvider.songs;
    final missingSongs = availableSongs.where(
      (song) => !_songs.any((s) => s.uri == song.uri)
    ).toList();
    
    if (missingSongs.isNotEmpty) {
      _loadMissingSongs(missingSongs);
    }
  }

  bool _matchesSearchQuery(Song song) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return song.title.toLowerCase().contains(query) ||
           song.artist.toLowerCase().contains(query) ||
           song.album.toLowerCase().contains(query);
  }

  Future<void> _loadMissingSongs(List<Song> missingSongs) async {
    if (!mounted) return;
    
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final songUris = missingSongs.map((s) => s.uri).toList();
    
    try {
      final songs = await musicProvider.getSongsByUris(songUris);
      if (!mounted) return;
      
      // Filter and sort songs outside of setState
      final filteredSongs = songs.where((song) {
        if (_matchesSearchQuery(song) && !_songs.any((s) => s.uri == song.uri)) {
          return true;
        }
        return false;
      }).toList();
      
      if (filteredSongs.isNotEmpty) {
        _sortSongs(filteredSongs);
        
        setState(() {
          _songs.addAll(filteredSongs);
        });
      }
    } catch (e) {
      debugPrint('Error loading missing songs: $e');
    }
  }

  void _resetPagination() {
    _currentPages[0] = 0;
    _currentPages[1] = 0;
    _currentPages[2] = 0;
    _hasMore[0] = true;
    _hasMore[1] = true;
    _hasMore[2] = true;
  }

  Future<void> _loadInitialContent() async {
    try {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      
      // Get cached songs for the first page
      final cachedSongs = await musicProvider.getSongsPage(0, _pageSize);
      
      if (mounted) {
        setState(() {
          _songs.clear();
          _songs.addAll(cachedSongs);
          _sortSongs(_songs);
          _isLoading[0] = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial content: $e');
      if (mounted) {
        setState(() {
          _errors[0] = 'Failed to load songs: $e';
          _isLoading[0] = false;
        });
      }
    }
  }

  Future<void> _loadMoreSongs({bool forceReload = false}) async {
    if (_isLoading[0]! || (!_hasMore[0]! && !forceReload)) return;

    if (!mounted) return;

    // Use a microtask to avoid setState during build
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _isLoading[0] = true;
        _errors[0] = null;
        if (forceReload) {
          _songs.clear();
          _currentPages[0] = 0;
          _hasMore[0] = true;
        }
      });
    });

    try {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      
      // Try to get songs from cache first
      final cachedSongs = await musicProvider.getSongsPage(_currentPages[0]!, _pageSize);
      
      if (cachedSongs.isNotEmpty) {
        if (!mounted) return;

        // Filter songs based on search query and remove duplicates
        final filteredSongs = cachedSongs.where((song) {
          if (_searchQuery.isEmpty) return true;
          return song.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 song.artist.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 song.album.toLowerCase().contains(_searchQuery.toLowerCase());
        }).where((song) => !_songs.any((s) => s.uri == song.uri)).toList();

        // Sort songs according to current sort option
        _sortSongs(filteredSongs);
        
        if (!mounted) return;
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            // Add new songs
            _songs.addAll(filteredSongs);
            _currentPages[0] = _currentPages[0]! + 1;
            _hasMore[0] = filteredSongs.length == _pageSize;
            _isLoading[0] = false;
          });
        });
        return;
      }

      // If no cached songs, get from MediaStore
      final availableSongs = musicProvider.songs;
      if (_currentPages[0]! * _pageSize >= availableSongs.length && !forceReload) {
        if (!mounted) return;
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            _hasMore[0] = false;
            _isLoading[0] = false;
          });
        });
        return;
      }

      final songUris = availableSongs
          .skip(_currentPages[0]! * _pageSize)
          .take(_pageSize)
          .map((song) => song.uri)
          .toList();

      if (songUris.isEmpty) {
        if (!mounted) return;
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            _isLoading[0] = false;
            _hasMore[0] = false;
          });
        });
        return;
      }

      final allSongs = await musicProvider.getSongsByUris(songUris);

      if (!mounted) return;

      // Filter songs based on search query and remove duplicates
      final filteredSongs = allSongs.where((song) {
        if (_searchQuery.isEmpty) return true;
        return song.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               song.artist.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               song.album.toLowerCase().contains(_searchQuery.toLowerCase());
      }).where((song) => !_songs.any((s) => s.uri == song.uri)).toList();

      // Sort songs according to current sort option
      _sortSongs(filteredSongs);
      
      if (!mounted) return;
      Future.microtask(() {
        if (!mounted) return;
        setState(() {
          // Add new songs
          _songs.addAll(filteredSongs);
          _currentPages[0] = _currentPages[0]! + 1;
          _hasMore[0] = songUris.length == _pageSize;
          _isLoading[0] = false;
        });
      });
    } catch (e) {
      if (!mounted) return;
      Future.microtask(() {
        if (!mounted) return;
        setState(() {
          _errors[0] = 'Failed to load songs: $e';
          _isLoading[0] = false;
        });
      });
    }
  }

  void _sortSongs(List<Song> songs) {
    switch (_currentSort) {
      case SortOption.titleAsc:
        songs.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.titleDesc:
        songs.sort((a, b) => b.title.compareTo(a.title));
        break;
      case SortOption.artistAsc:
        songs.sort((a, b) => a.artist.compareTo(b.artist));
        break;
      case SortOption.artistDesc:
        songs.sort((a, b) => b.artist.compareTo(a.artist));
        break;
      case SortOption.albumAsc:
        songs.sort((a, b) => a.album.compareTo(b.album));
        break;
      case SortOption.albumDesc:
        songs.sort((a, b) => b.album.compareTo(a.album));
        break;
      case SortOption.dateAddedAsc:
        songs.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case SortOption.dateAddedDesc:
        songs.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case SortOption.durationAsc:
        songs.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case SortOption.durationDesc:
        songs.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }
  }

  Future<void> _loadMoreAlbums({bool forceReload = false}) async {
    if (_isLoading[1]! || (!_hasMore[1]! && !forceReload)) return;

    setState(() {
      _isLoading[1] = true;
      _errors[1] = null;
      if (forceReload) {
        _albums.clear();
        _currentPages[1] = 0;
        _hasMore[1] = true;
      }
    });

    try {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      final allAlbums = musicProvider.albums
          .skip(_currentPages[1]! * _pageSize)
          .take(_pageSize)
          .toList();

      if (mounted) {
        setState(() {
          // Filter albums based on search query
          final filteredAlbums = allAlbums.where((album) {
            if (_searchQuery.isEmpty) return true;
            return album.name.toLowerCase().contains(_searchQuery) ||
                   album.artist.toLowerCase().contains(_searchQuery);
          }).toList();

          _albums.addAll(filteredAlbums);
          _currentPages[1] = _currentPages[1]! + 1;
          _hasMore[1] = allAlbums.length == _pageSize;
          _isLoading[1] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errors[1] = 'Failed to load albums: $e';
          _isLoading[1] = false;
        });
      }
    }
  }

  Future<void> _loadMoreArtists({bool forceReload = false}) async {
    if (_isLoading[2]! || (!_hasMore[2]! && !forceReload)) return;

    setState(() {
      _isLoading[2] = true;
      _errors[2] = null;
      if (forceReload) {
        _artists.clear();
        _currentPages[2] = 0;
        _hasMore[2] = true;
      }
    });

    try {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      final allArtists = musicProvider.artists
          .skip(_currentPages[2]! * _pageSize)
          .take(_pageSize)
          .toList();

      if (mounted) {
        setState(() {
          // Filter artists based on search query
          final filteredArtists = allArtists.where((artist) {
            if (_searchQuery.isEmpty) return true;
            return artist.name.toLowerCase().contains(_searchQuery);
          }).toList();

          _artists.addAll(filteredArtists);
          _currentPages[2] = _currentPages[2]! + 1;
          _hasMore[2] = allArtists.length == _pageSize;
          _isLoading[2] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errors[2] = 'Failed to load artists: $e';
          _isLoading[2] = false;
        });
      }
    }
  }

  void _handleSongTap(Song song) {
    debugPrint('LibraryScreen: Song tapped - Title: ${song.title}, URI: ${song.uri}');
    
    // Find the index of the selected song
    final selectedIndex = _songs.indexWhere((s) => s.uri == song.uri);
    debugPrint('LibraryScreen: Selected song index in _songs list: $selectedIndex');
    
    if (selectedIndex == -1) {
      debugPrint('LibraryScreen: Error - Selected song not found in _songs list');
      return;
    }

    // Calculate the range of songs to include in the playlist
    final startIndex = max(0, selectedIndex - 7);
    final endIndex = min(_songs.length, selectedIndex + 10);
    debugPrint('LibraryScreen: Creating playlist from index $startIndex to $endIndex');

    // Create a playlist with the selected song and surrounding songs
    final playlistSongs = _songs.sublist(startIndex, endIndex);
    debugPrint('LibraryScreen: Playlist created with ${playlistSongs.length} songs');
    debugPrint('LibraryScreen: First song in playlist: ${playlistSongs.first.title}');
    debugPrint('LibraryScreen: Last song in playlist: ${playlistSongs.last.title}');

    // Get URIs for the playlist
    final uris = playlistSongs.map((s) => s.uri).toList();
    debugPrint('LibraryScreen: First URI in playlist: ${uris.first}\n');
    debugPrint('LibraryScreen: Last URI in playlist: ${uris.last}');

    // Update the audio provider with the new playlist and start playing
    debugPrint('LibraryScreen: Updating audio provider playlist...');
    final playlistIndex = selectedIndex - startIndex;
    debugPrint('LibraryScreen: Playing song at playlist index: $playlistIndex');
    debugPrint('LibraryScreen: Song to be played: ${song.title}');
    
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    audioProvider.updatePlaylist(uris, selectedIndex: playlistIndex).then((_) {
      audioProvider.play();
    });
  }

  void _handleSongLongPress(Song song) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SongOptionsBottomSheet(song: song),
    );
  }

  void _handleAlbumTap(Album album) {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    // Create a new playlist with all songs from the album
    final playlist = album.songs.map((song) => song.uri).toList();
    audioProvider.updatePlaylist(playlist);
    audioProvider.selectSong(0);
    audioProvider.play();
  }

  void _handleAlbumLongPress(Album album) {
    // TODO: Show album options
  }

  void _handleArtistTap(Artist artist) {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    // Create a new playlist with all songs from the artist
    final playlist = artist.songs.map((song) => song.uri).toList();
    audioProvider.updatePlaylist(playlist);
    audioProvider.selectSong(0);
    audioProvider.play();
  }

  void _handleArtistLongPress(Artist artist) {
    // TODO: Show artist options
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _LibraryAppBar(
        onSortPressed: showSortDialog,
        searchQuery: _searchQuery,
        onSearchChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
            // Reset pagination when search changes
            _currentPages[0] = 0;
            _currentPages[1] = 0;
            _currentPages[2] = 0;
            _songs.clear();
            _albums.clear();
            _artists.clear();
            _hasMore[0] = true;
            _hasMore[1] = true;
            _hasMore[2] = true;
          });
          // Reload content for current tab
          _loadContentForTab(_currentTab);
        },
      ),
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
                  isLoading: _isLoading[0]!,
                  hasMore: _hasMore[0]!,
                  onLoadMore: _loadMoreSongs,
                  onRetry: () {
                    setState(() {
                      _errors[0] = null;
                      _currentPages[0] = 0;
                      _songs.clear();
                      _hasMore[0] = true;
                    });
                    _loadMoreSongs();
                  },
                  onSongTap: _handleSongTap,
                  onSongLongPress: _handleSongLongPress,
                ),
                // Albums tab
                PaginatedGridList<Album>(
                  items: _albums,
                  isLoading: _isLoading[1]!,
                  hasMore: _hasMore[1]!,
                  error: _errors[1],
                  onLoadMore: _loadMoreAlbums,
                  onRetry: () {
                    setState(() {
                      _errors[1] = null;
                      _currentPages[1] = 0;
                      _albums.clear();
                      _hasMore[1] = true;
                    });
                    _loadMoreAlbums();
                  },
                  onItemTap: _handleAlbumTap,
                  onItemLongPress: _handleAlbumLongPress,
                  itemBuilder: (album) => AlbumItem(
                    album: album,
                    onTap: () => _handleAlbumTap(album),
                    onLongPress: () => _handleAlbumLongPress(album),
                  ),
                  crossAxisCount: 1,
                  isList: true,
                ),
                // Artists tab
                PaginatedGridList<Artist>(
                  items: _artists,
                  isLoading: _isLoading[2]!,
                  hasMore: _hasMore[2]!,
                  error: _errors[2],
                  onLoadMore: _loadMoreArtists,
                  onRetry: () {
                    setState(() {
                      _errors[2] = null;
                      _currentPages[2] = 0;
                      _artists.clear();
                      _hasMore[2] = true;
                    });
                    _loadMoreArtists();
                  },
                  onItemTap: _handleArtistTap,
                  onItemLongPress: _handleArtistLongPress,
                  itemBuilder: (artist) => ArtistItem(
                    artist: artist,
                    onTap: () => _handleArtistTap(artist),
                    onLongPress: () => _handleArtistLongPress(artist),
                  ),
                  crossAxisCount: 1,
                  isList: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
} 