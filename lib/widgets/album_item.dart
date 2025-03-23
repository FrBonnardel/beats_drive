import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_provider.dart';
import '../services/cache_service.dart';

class AlbumItem extends StatelessWidget {
  final Album album;

  const AlbumItem({
    Key? key,
    required this.album,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: album.albumArtUri != null && album.albumArtUri!.isNotEmpty
                  ? Image.network(
                      album.albumArtUri!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.album, color: Colors.white70),
                    )
                  : const Icon(Icons.album, color: Colors.white70),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          album.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          album.artist,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
} 