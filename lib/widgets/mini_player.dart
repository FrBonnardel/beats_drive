import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../screens/player_screen.dart';

// Static widgets
class _MiniPlayerContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _MiniPlayerContainer({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _AlbumArtContainer extends StatelessWidget {
  final Widget child;

  const _AlbumArtContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
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

class _SongInfo extends StatelessWidget {
  final String title;
  final String artist;

  const _SongInfo({
    required this.title,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              artist,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isPlaying ? Icons.pause : Icons.play_arrow,
        color: Colors.white,
      ),
      onPressed: onPressed,
    );
  }
}

class _AlbumArtBuilder extends StatelessWidget {
  final String songId;
  final MusicProvider musicProvider;

  const _AlbumArtBuilder({
    required this.songId,
    required this.musicProvider,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = musicProvider.getAlbumArtNotifier(songId);
    if (notifier == null) {
      return const _AlbumArtPlaceholder();
    }

    return ValueListenableBuilder<Uint8List?>(
      valueListenable: notifier,
      builder: (context, albumArt, child) {
        if (albumArt == null) {
          // Load album art if not already loaded
          musicProvider.loadAlbumArt(songId);
          return const _AlbumArtLoadingIndicator();
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            albumArt,
            fit: BoxFit.cover,
            cacheWidth: 100,
            cacheHeight: 100,
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

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<AudioProvider, MusicProvider>(
      builder: (context, audioProvider, musicProvider, child) {
        return ValueListenableBuilder<Song?>(
          valueListenable: audioProvider.currentSongNotifier,
          builder: (context, song, child) {
            if (song == null) return const SizedBox.shrink();

            return _MiniPlayerContainer(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlayerScreen(),
                  ),
                );
              },
              child: Row(
                children: [
                  _AlbumArtContainer(
                    child: _AlbumArtBuilder(
                      songId: song.id,
                      musicProvider: musicProvider,
                    ),
                  ),
                  _SongInfo(
                    title: song.title,
                    artist: song.artist,
                  ),
                  _PlayPauseButton(
                    isPlaying: audioProvider.isPlaying,
                    onPressed: () {
                      if (audioProvider.isPlaying) {
                        audioProvider.pause();
                      } else {
                        audioProvider.play();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
} 