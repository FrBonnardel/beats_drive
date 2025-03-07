import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../providers/audio_provider.dart';
import '../services/metadata_service.dart';
import 'dart:math';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredFiles = [];
  Map<String, Map<String, dynamic>> _metadataCache = {};
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeFilteredFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeFilteredFiles() {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    setState(() {
      _filteredFiles = musicProvider.musicFiles;
      _currentPage = 0;
    });
  }

  Future<void> _loadMetadataForPage() async {
    if (_isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    final startIndex = _currentPage * _pageSize;
    final endIndex = min(startIndex + _pageSize, _filteredFiles.length);
    
    for (var i = startIndex; i < endIndex; i++) {
      final filePath = _filteredFiles[i];
      if (!_metadataCache.containsKey(filePath)) {
        final metadata = await MetadataService.getMetadata(filePath);
        if (mounted) {
          setState(() {
            _metadataCache[filePath] = metadata;
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _currentPage++;
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMetadataForPage();
    }
  }

  void _filterFiles(String query) {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    if (query.isEmpty) {
      setState(() {
        _filteredFiles = musicProvider.musicFiles;
        _currentPage = 0;
        _metadataCache.clear();
      });
      _loadMetadataForPage();
    } else {
      setState(() {
        _filteredFiles = musicProvider.musicFiles.where((filePath) {
          final metadata = _metadataCache[filePath] ?? {};
          final title = metadata['title'] as String? ?? filePath.split('/').last;
          final artist = metadata['artist'] as String? ?? '';
          final album = metadata['album'] as String? ?? '';
          
          return title.toLowerCase().contains(query.toLowerCase()) ||
                 artist.toLowerCase().contains(query.toLowerCase()) ||
                 album.toLowerCase().contains(query.toLowerCase());
        }).toList();
        _currentPage = 0;
        _metadataCache.clear();
      });
      _loadMetadataForPage();
    }
  }

  Future<void> _showRescanConfirmation() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rescan Music Library'),
        content: const Text('This will scan your device for music files. This may take a few minutes. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              final musicProvider = Provider.of<MusicProvider>(context, listen: false);
              musicProvider.scanMusicFiles(forceRescan: true);
            },
            child: const Text('Rescan'),
          ),
        ],
      ),
    );
  }

  void _playRandom() {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    if (musicProvider.musicFiles.isEmpty) return;

    final random = Random();
    final randomIndex = random.nextInt(musicProvider.musicFiles.length);
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    audioProvider.updatePlaylist(musicProvider.musicFiles);
    audioProvider.selectSong(randomIndex);
  }

  Widget _buildMusicItem(Map<String, dynamic> metadata) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: metadata['albumArt'] != null
            ? Image.memory(
                metadata['albumArt'],
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey[800],
                    child: Icon(Icons.music_note, color: Colors.white),
                  );
                },
              )
            : Container(
                width: 56,
                height: 56,
                color: Colors.grey[800],
                child: Icon(Icons.music_note, color: Colors.white),
              ),
      ),
      title: Text(
        metadata['title'] ?? 'Unknown Title',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        metadata['artist'] ?? 'Unknown Artist',
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
      ),
      onTap: () {
        // Handle music item tap
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          Consumer<MusicProvider>(
            builder: (context, musicProvider, child) {
              if (musicProvider.isScanning) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${musicProvider.processedFiles}/${musicProvider.totalFiles}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _showRescanConfirmation,
              );
            },
          ),
        ],
      ),
      body: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          if (musicProvider.error.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    musicProvider.error,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _showRescanConfirmation,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (musicProvider.musicFiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No music files found'),
                  if (musicProvider.isScanning) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      musicProvider.currentStatus,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search music...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: _filterFiles,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _playRandom,
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Random'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _filteredFiles.length + (_isLoadingMore ? 1 : 0),
                  cacheExtent: 1000,
                  itemBuilder: (context, index) {
                    if (index == _filteredFiles.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final filePath = _filteredFiles[index];
                    final metadata = _metadataCache[filePath] ?? {};
                    final title = metadata['title'] as String? ?? filePath.split('/').last;
                    final artist = metadata['artist'] as String? ?? 'Unknown Artist';
                    final album = metadata['album'] as String? ?? '';
                    final albumArt = metadata['albumArt'];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: albumArt != null
                              ? Image.memory(
                                  albumArt,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 56,
                                      height: 56,
                                      color: Colors.grey[800],
                                      child: Icon(Icons.music_note, color: Colors.white),
                                    );
                                  },
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey[800],
                                  child: Icon(Icons.music_note, color: Colors.white),
                                ),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          artist,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        onTap: () {
                          final audioProvider = Provider.of<AudioProvider>(context, listen: false);
                          audioProvider.updatePlaylist(_filteredFiles);
                          audioProvider.selectSong(index);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 