import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../services/media_notification_service.dart';
import '../services/playback_state_service.dart';
import '../models/music_models.dart';
import '../screens/playlist_screen.dart';
import '../widgets/shared_widgets.dart';

// Static widgets
class _PlayerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PlayerAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Now Playing'),
      leading: IconButton(
        icon: const Icon(Icons.expand_more),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Static player controls
class _PlayerControls extends StatelessWidget {
  final AudioProvider audioProvider;

  const _PlayerControls({required this.audioProvider});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.shuffle),
          onPressed: audioProvider.toggleShuffle,
          color: audioProvider.isShuffleEnabled
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: audioProvider.previous,
        ),
        IconButton(
          icon: Icon(
            audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 48,
          ),
          onPressed: () {
            if (audioProvider.isPlaying) {
              audioProvider.pause();
            } else {
              audioProvider.play();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: audioProvider.next,
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
}

// Dynamic progress bar with isolated updates
class _ProgressBar extends StatefulWidget {
  final AudioProvider audioProvider;

  const _ProgressBar({required this.audioProvider});

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double _currentValue = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.audioProvider.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = widget.audioProvider.duration;
        
        // Update current value only when not dragging
        if (!_isDragging) {
          _currentValue = position.inMilliseconds.toDouble();
        }

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                thumbColor: Theme.of(context).colorScheme.primary,
                overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: _currentValue,
                max: duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  setState(() {
                    _currentValue = value;
                    _isDragging = true;
                  });
                },
                onChangeEnd: (value) {
                  setState(() {
                    _isDragging = false;
                    _currentValue = value;
                  });
                  widget.audioProvider.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(Duration(milliseconds: _currentValue.toInt())),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

// Static album art container
class _AlbumArtContainer extends StatelessWidget {
  final Widget child;

  const _AlbumArtContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}

// Static album art placeholder
class _AlbumArtPlaceholder extends StatelessWidget {
  const _AlbumArtPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.music_note, color: Colors.white70, size: 64);
  }
}

// Static album art loading indicator
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

// Static song info container
class _SongInfoContainer extends StatelessWidget {
  final String title;
  final String artist;
  final String album;

  const _SongInfoContainer({
    required this.title,
    required this.artist,
    required this.album,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          artist,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[400],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          album,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Song? _currentSong;
  Uint8List? _albumArt;
  bool _isLoading = true;
  String? _error;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentSong();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    
    // Listen to playlist changes
    audioProvider.addListener(_onPlaylistChanged);
    musicProvider.addListener(_onMusicProviderChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    
    audioProvider.removeListener(_onPlaylistChanged);
    musicProvider.removeListener(_onMusicProviderChanged);
    super.dispose();
  }

  void _onPlaylistChanged() {
    // Debounce the playlist change to prevent rapid rebuilds
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), _loadCurrentSong);
  }

  void _onMusicProviderChanged() {
    if (_currentSong != null) {
      _loadAlbumArt();
    }
  }

  Future<void> _loadCurrentSong() async {
    if (!mounted) return;

    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);

    final currentIndex = audioProvider.currentIndex;
    if (currentIndex == null || currentIndex < 0 || currentIndex >= audioProvider.playlist.length) {
      setState(() {
        _currentSong = null;
        _albumArt = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUri = audioProvider.playlist[currentIndex];
      final song = await musicProvider.getSongByUri(currentUri);
      
      if (mounted) {
        setState(() {
          _currentSong = song;
          _isLoading = false;
        });
        _loadAlbumArt();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load song: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAlbumArt() async {
    if (_currentSong == null) return;

    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    try {
      final albumArt = await musicProvider.loadAlbumArt(_currentSong!.id);
      if (mounted) {
        setState(() {
          _albumArt = albumArt;
        });
      }
    } catch (e) {
      debugPrint('Error loading album art: $e');
      if (mounted) {
        setState(() {
          _albumArt = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _PlayerAppBar(),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading song...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCurrentSong,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentSong == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 48),
            SizedBox(height: 16),
            Text('No song playing'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 32),
            _AlbumArtContainer(
              child: _albumArt != null
                  ? Image.memory(
                      _albumArt!,
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                      cacheHeight: 300,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Error displaying album art: $error');
                        return const _AlbumArtPlaceholder();
                      },
                    )
                  : const _AlbumArtPlaceholder(),
            ),
            const SizedBox(height: 32),
            _SongInfoContainer(
              title: _currentSong!.title,
              artist: _currentSong!.artist,
              album: _currentSong!.album,
            ),
            const SizedBox(height: 24),
            _ProgressBar(audioProvider: Provider.of<AudioProvider>(context)),
            const SizedBox(height: 16),
            _PlayerControls(audioProvider: Provider.of<AudioProvider>(context)),
          ],
        ),
      ),
    );
  }
} 