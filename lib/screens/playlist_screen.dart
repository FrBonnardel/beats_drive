import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../models/music_models.dart';
import '../widgets/song_list_item.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/song_item.dart';
import '../screens/library_screen.dart';

// Static widgets
class _PlaylistAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AudioProvider audioProvider;

  const _PlaylistAppBar({required this.audioProvider});

  @override
  Widget build(BuildContext context) {
    return AppBar(
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
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
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
            message,
            style: Theme.of(context).textTheme.titleMedium,
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

class _EmptyPlaylistView extends StatelessWidget {
  const _EmptyPlaylistView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No songs in playlist',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, Song> _songCache = {};
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

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
      final itemHeight = 72.0;
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
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);

      // Batch load all songs at once
      final uris = audioProvider.playlist;
      final songs = await musicProvider.getSongsByUris(uris);
      
      if (mounted) {
        setState(() {
          for (var i = 0; i < uris.length; i++) {
            _songCache[uris[i]] = songs[i];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading playlist: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load playlist';
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
    }
  }

  void _handleSongLongPress(Song song) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SongOptionsBottomSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AudioProvider, MusicProvider>(
      builder: (context, audioProvider, musicProvider, child) {
        if (_hasError) {
          return _ErrorView(
            message: _errorMessage ?? 'An error occurred',
            onRetry: _loadInitialSongs,
          );
        }

        if (_isLoading) {
          return const _LoadingIndicator();
        }

        if (audioProvider.playlist.isEmpty) {
          return const _EmptyPlaylistView();
        }

        return _PlaylistContent(
          songCache: _songCache,
          audioProvider: audioProvider,
          musicProvider: musicProvider,
          scrollController: _scrollController,
          onSongTap: _handleSongTap,
          onSongLongPress: _handleSongLongPress,
        );
      },
    );
  }
}

// Static playlist content widget
class _PlaylistContent extends StatelessWidget {
  final Map<String, Song> songCache;
  final AudioProvider audioProvider;
  final MusicProvider musicProvider;
  final ScrollController scrollController;
  final Function(Song) onSongTap;
  final Function(Song) onSongLongPress;

  const _PlaylistContent({
    required this.songCache,
    required this.audioProvider,
    required this.musicProvider,
    required this.scrollController,
    required this.onSongTap,
    required this.onSongLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListView.builder(
        controller: scrollController,
        itemCount: audioProvider.playlist.length,
        itemBuilder: (context, index) {
          final uri = audioProvider.playlist[index];
          final song = songCache[uri];
          final isSelected = index == audioProvider.currentIndex;

          return _SongListItem(
            uri: uri,
            song: song,
            index: index,
            audioProvider: audioProvider,
            musicProvider: musicProvider,
            isSelected: isSelected,
            onTap: () => onSongTap(song!),
            onLongPress: () => onSongLongPress(song!),
          );
        },
      ),
    );
  }
}

// Static song list item widget
class _SongListItem extends StatelessWidget {
  final String uri;
  final Song? song;
  final int index;
  final AudioProvider audioProvider;
  final MusicProvider musicProvider;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SongListItem({
    required this.uri,
    required this.song,
    required this.index,
    required this.audioProvider,
    required this.musicProvider,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        leading: SizedBox(
          width: 48,
          height: 48,
          child: _buildAlbumArt(),
        ),
        title: Text(
          song?.title ?? uri.split('/').last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song != null ? '${song!.artist} • ${song!.album}' : 'Loading...',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: song != null ? onTap : null,
        onLongPress: song != null ? onLongPress : null,
      ),
    );
  }

  Widget _buildAlbumArt() {
    if (song == null) return const _AlbumArtPlaceholder();

    return FutureBuilder<Uint8List?>(
      future: musicProvider.loadAlbumArt(song!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AlbumArtLoadingIndicator();
        }
        
        if (snapshot.hasError) {
          debugPrint('Error loading album art: ${snapshot.error}');
          return const _AlbumArtPlaceholder();
        }

        final albumArt = snapshot.data;
        if (albumArt == null) {
          return const _AlbumArtPlaceholder();
        }

        return _AlbumArtContainer(
          child: Image.memory(
            albumArt,
            fit: BoxFit.cover,
            cacheWidth: 96,
            cacheHeight: 96,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error displaying album art: $error');
              return const _AlbumArtPlaceholder();
            },
          ),
        );
      },
    );
  }
}

String _formatDuration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
} 