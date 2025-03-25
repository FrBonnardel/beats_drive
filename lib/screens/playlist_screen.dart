import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../models/music_models.dart';
import '../widgets/song_item.dart';
import '../widgets/song_options_bottom_sheet.dart';
import '../widgets/shared_widgets.dart';
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
  late AudioProvider _audioProvider;

  @override
  void initState() {
    super.initState();
    _audioProvider = Provider.of<AudioProvider>(context, listen: false);
    _audioProvider.addListener(_onAudioProviderUpdate);
    _loadInitialSongs();
  }

  @override
  void dispose() {
    _audioProvider.removeListener(_onAudioProviderUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  void _onAudioProviderUpdate() {
    _loadInitialSongs();
    // Scroll to current song whenever the audio provider updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToCurrentSong();
      }
    });
  }

  void _scrollToCurrentSong() {
    if (!_scrollController.hasClients) return;
    
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final currentIndex = audioProvider.currentIndex;
    
    if (currentIndex != null && currentIndex >= 0) {
      final itemHeight = 72.0; // Height of each song item
      final screenHeight = MediaQuery.of(context).size.height;
      final appBarHeight = AppBar().preferredSize.height;
      final topPadding = MediaQuery.of(context).padding.top;
      
      // Calculate the target offset that will position the current song at the top
      // We subtract the app bar height and status bar height to account for the non-scrollable areas
      final offset = (currentIndex * itemHeight) - (topPadding + appBarHeight);
      
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
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
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);

      // Batch load all songs at once
      final uris = _audioProvider.playlist;
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
      audioProvider.selectSong(index).then((_) {
        audioProvider.play();
      });
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
    final songs = audioProvider.playlist
        .map((uri) => songCache[uri])
        .where((song) => song != null)
        .cast<Song>()
        .toList();

    return SongItem(
      songs: songs,
      isLoading: false,
      hasMore: false,
      onLoadMore: () {},
      onRetry: () {},
      onSongTap: onSongTap,
      onSongLongPress: onSongLongPress,
      scrollController: scrollController,
      selectedIndex: audioProvider.currentIndex,
    );
  }
}

String _formatDuration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
} 