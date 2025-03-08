import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../screens/player_screen.dart';
import '../models/music_models.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AudioProvider, MusicProvider>(
      builder: (context, audioProvider, musicProvider, child) {
        if (audioProvider.playlist.isEmpty || audioProvider.currentIndex < 0) {
          return const SizedBox.shrink();
        }

        final currentUri = audioProvider.playlist[audioProvider.currentIndex];
        final currentSong = musicProvider.songs.firstWhere(
          (song) => song.uri == currentUri,
          orElse: () => Song(
            id: '',
            title: currentUri.split('/').last,
            artist: 'Unknown Artist',
            album: 'Unknown Album',
            albumId: '',
            duration: 0,
            uri: currentUri,
            trackNumber: 0,
            year: 0,
            dateAdded: 0,
            albumArtUri: '',
          ),
        );

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PlayerScreen()),
            );
          },
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Album Art
                FutureBuilder<Uint8List?>(
                  future: currentSong.id.isNotEmpty 
                    ? musicProvider.loadAlbumArt(currentSong.id)
                    : Future.value(null),
                  builder: (context, snapshot) {
                    return Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: snapshot.hasData && snapshot.data != null
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
                // Song Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSong.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        currentSong.artist,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: audioProvider.previous,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    IconButton(
                      icon: Icon(
                        audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: () {
                        if (audioProvider.isPlaying) {
                          audioProvider.pause();
                        } else {
                          audioProvider.play();
                        }
                      },
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: audioProvider.next,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 