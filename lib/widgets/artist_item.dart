import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_provider.dart';
import '../services/cache_service.dart';

class ArtistItem extends StatelessWidget {
  final Artist artist;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const ArtistItem({
    Key? key,
    required this.artist,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final notifier = artist.songs.isNotEmpty ? musicProvider.getAlbumArtNotifier(artist.songs.first.id) : null;

    return Container(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: ListTile(
        key: ValueKey(artist.id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        leading: SizedBox(
          width: 56,
          height: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              color: Colors.grey[800],
              child: notifier == null
                  ? const Icon(Icons.person, color: Colors.white70)
                  : ValueListenableBuilder<Uint8List?>(
                      valueListenable: notifier,
                      builder: (context, albumArt, child) {
                        if (albumArt == null) {
                          // Load album art if not already loaded
                          if (artist.songs.isNotEmpty) {
                            musicProvider.loadAlbumArt(artist.songs.first.id);
                          }
                          return const Icon(Icons.person, color: Colors.white70);
                        }
                        return Image.memory(
                          albumArt,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Error displaying album art: $error');
                            return const Icon(Icons.person, color: Colors.white70);
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
        title: Text(
          artist.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${artist.totalAlbums} albums • ${artist.totalSongs} songs',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _formatDuration(artist.songs.fold(0, (sum, song) => sum + song.duration)),
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
} 