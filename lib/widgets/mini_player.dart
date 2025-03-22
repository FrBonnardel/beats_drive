import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../screens/player_screen.dart';

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

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlayerScreen(),
                  ),
                );
              },
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
                child: Row(
                  children: [
                    // Album Art
                    Container(
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FutureBuilder<Uint8List?>(
                        future: musicProvider.loadAlbumArt(song.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            debugPrint('Error loading album art: ${snapshot.error}');
                          }
                          return snapshot.data != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    cacheWidth: 100,
                                    cacheHeight: 100,
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint('Error displaying album art: $error');
                                      return const Icon(Icons.music_note, color: Colors.white70);
                                    },
                                  ),
                                )
                              : const Icon(Icons.music_note, color: Colors.white70);
                        },
                      ),
                    ),
                    // Song Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              song.artist,
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
                    ),
                    // Play/Pause Button
                    IconButton(
                      icon: Icon(
                        audioProvider.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                      ),
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
              ),
            );
          },
        );
      },
    );
  }
} 