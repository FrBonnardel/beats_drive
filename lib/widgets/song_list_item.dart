import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beats_drive/models/music_models.dart';
import 'package:beats_drive/providers/music_provider.dart';

class SongListItem extends StatelessWidget {
  final Song song;

  const SongListItem({
    Key? key,
    required this.song,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);

    return ListTile(
      leading: _buildAlbumArt(provider),
      title: Text(
        song.displayTitle,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${song.displayArtist} • ${song.displayAlbum}',
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatDuration(song.duration),
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
        ),
      ),
      onTap: () => provider.playSong(context, song),
    );
  }

  Widget _buildAlbumArt(MusicProvider provider) {
    return FutureBuilder<Uint8List?>(
      future: provider.loadAlbumArt(song.id),
      builder: (context, snapshot) {
        return _buildAlbumArtContainer(snapshot.data);
      },
    );
  }

  Widget _buildAlbumArtContainer(Uint8List? albumArt) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: albumArt != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                albumArt,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                cacheWidth: 100,
                cacheHeight: 100,
              ),
            )
          : const Icon(Icons.music_note, color: Colors.white70),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
} 