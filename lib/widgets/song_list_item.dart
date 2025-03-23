import 'dart:typed_data';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_provider.dart';
import '../services/cache_service.dart';
import '../widgets/shared_widgets.dart';
import 'package:image/image.dart' as img;

// Static widgets
class _AlbumArtContainer extends StatelessWidget {
  final Widget child;

  const _AlbumArtContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
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

class _SongInfo extends StatelessWidget {
  final String title;
  final String artist;
  final String album;

  const _SongInfo({
    required this.title,
    required this.artist,
    required this.album,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '$artist • $album',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _DurationText extends StatelessWidget {
  final String duration;
  static final Map<int, String> _durationCache = {};

  const _DurationText({required this.duration});

  static String formatDuration(int milliseconds) {
    if (_durationCache.containsKey(milliseconds)) {
      return _durationCache[milliseconds]!;
    }
    
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final formatted = '$minutes:$seconds';
    _durationCache[milliseconds] = formatted;
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      duration,
      style: TextStyle(
        color: Colors.grey[400],
        fontSize: 12,
      ),
    );
  }
}

class _AlbumArtBuilder extends StatelessWidget {
  final String songId;
  final MusicProvider musicProvider;
  final CacheService cacheService;
  static const int thumbnailSize = 100;
  static final LinkedHashMap<String, Uint8List> _memoryCache = LinkedHashMap();
  static const int _maxCacheSize = 100;

  const _AlbumArtBuilder({
    required this.songId,
    required this.musicProvider,
    required this.cacheService,
  });

  @override
  Widget build(BuildContext context) {
    // Check memory cache first
    if (_memoryCache.containsKey(songId)) {
      // Move to end to mark as recently used
      final albumArt = _memoryCache.remove(songId)!;
      _memoryCache[songId] = albumArt;
      return _buildAlbumArt(albumArt);
    }

    return FutureBuilder<Uint8List?>(
      future: _loadAlbumArt(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AlbumArtLoadingIndicator();
        }
        if (snapshot.hasError) {
          debugPrint('Error loading album art: ${snapshot.error}');
          return const _AlbumArtPlaceholder();
        }
        
        final albumArt = snapshot.data;
        if (albumArt != null) {
          // Remove oldest item if cache is full
          if (_memoryCache.length >= _maxCacheSize) {
            _memoryCache.remove(_memoryCache.keys.first);
          }
          _memoryCache[songId] = albumArt;
        }
        return _buildAlbumArt(albumArt);
      },
    );
  }

  Future<Uint8List?> _loadAlbumArt() async {
    try {
      // Try to get from cache first
      final cachedArt = await cacheService.getCachedAlbumArt(songId);
      if (cachedArt != null) {
        return await compute(resizeAlbumArt, {
          'data': Uint8List.fromList(cachedArt),
          'size': thumbnailSize,
        });
      }

      // If not in cache, load from provider
      final albumArt = await musicProvider.loadAlbumArt(songId);
      if (albumArt != null) {
        final resized = await compute(resizeAlbumArt, {
          'data': albumArt,
          'size': thumbnailSize,
        });
        
        // Cache the resized album art
        if (resized != null) {
          await cacheService.cacheAlbumArt(songId, resized.toList());
        }
        return resized;
      }
    } catch (e) {
      debugPrint('Error loading album art: $e');
    }
    return null;
  }

  Widget _buildAlbumArt(Uint8List? albumArt) {
    if (albumArt == null) return const _AlbumArtPlaceholder();

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          albumArt,
          width: thumbnailSize.toDouble(),
          height: thumbnailSize.toDouble(),
          fit: BoxFit.cover,
          cacheWidth: thumbnailSize,
          cacheHeight: thumbnailSize,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error displaying album art: $error');
            return const _AlbumArtPlaceholder();
          },
        ),
      ),
    );
  }
}

// Top-level function for compute
Uint8List? resizeAlbumArt(Map<String, dynamic> params) {
  try {
    final data = params['data'] as Uint8List;
    final size = params['size'] as int;
    
    final image = img.decodeImage(data);
    if (image == null) return null;
    
    final resized = img.copyResize(
      image,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  } catch (e) {
    debugPrint('Error resizing album art: $e');
    return null;
  }
}

class SongListItem extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SongListItem({
    Key? key,
    required this.song,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final cacheService = Provider.of<CacheService>(context);
    final duration = _DurationText.formatDuration(song.duration);

    return RepaintBoundary(
      child: ListTile(
        key: ValueKey(song.id),
        leading: _AlbumArtContainer(
          child: _AlbumArtBuilder(
            songId: song.id,
            musicProvider: musicProvider,
            cacheService: cacheService,
          ),
        ),
        title: _SongInfo(
          title: song.title,
          artist: song.artist,
          album: song.album,
        ),
        trailing: _DurationText(duration: duration),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
} 