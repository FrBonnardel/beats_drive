import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../providers/audio_provider.dart';
import 'dart:math';

class MusicItemTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onTap;

  const MusicItemTile({
    Key? key,
    required this.file,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(file['_id']),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 56,
          height: 56,
          color: Colors.grey[800],
          child: file['albumArt'] != null
              ? Image.memory(
                  file['albumArt'],
                  fit: BoxFit.cover,
                  cacheWidth: 112, // 2x for high DPI screens
                  cacheHeight: 112,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error loading album art: $error');
                    return const Icon(Icons.music_note, color: Colors.white);
                  },
                )
              : const Icon(Icons.music_note, color: Colors.white),
        ),
      ),
      title: Text(
        file['title'] ?? file['data'].toString().split('/').last,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        file['artist'] ?? 'Unknown Artist',
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredFiles = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeLibrary();
  }

  Future<void> _initializeLibrary() async {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    
    // If no music files, request permission and scan
    if (musicProvider.musicFiles.isEmpty) {
      await musicProvider.requestPermissionAndScan();
    }
    
    // Initialize filtered files
    setState(() {
      _filteredFiles = musicProvider.musicFiles;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update filtered files when music provider changes
    final musicProvider = Provider.of<MusicProvider>(context);
    setState(() {
      _filteredFiles = musicProvider.musicFiles;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterFiles(String query) {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    if (query.isEmpty) {
      setState(() {
        _filteredFiles = musicProvider.musicFiles;
      });
    } else {
      setState(() {
        _filteredFiles = musicProvider.musicFiles.where((file) {
          final fileName = file['data'].toString().split('/').last.toLowerCase();
          final title = file['title']?.toString().toLowerCase() ?? fileName;
          final artist = file['artist']?.toString().toLowerCase() ?? '';
          final album = file['album']?.toString().toLowerCase() ?? '';
          
          final searchQuery = query.toLowerCase();
          return title.contains(searchQuery) ||
                 artist.contains(searchQuery) ||
                 album.contains(searchQuery);
        }).toList();
      });
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
    audioProvider.updatePlaylist(musicProvider.musicFiles.map((file) => file['data'] as String).toList());
    audioProvider.selectSong(randomIndex);
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
                        musicProvider.currentStatus,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => musicProvider.scanMusicFiles(forceRescan: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
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
                  Icon(
                    Icons.music_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No music found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some music to your device',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search music...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  onChanged: _filterFiles,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _filteredFiles.length,
                  cacheExtent: 100, // Cache more items for smoother scrolling
                  itemBuilder: (context, index) {
                    final file = _filteredFiles[index];
                    return MusicItemTile(
                      key: ValueKey(file['_id']),
                      file: file,
                      onTap: () {
                        final audioProvider = Provider.of<AudioProvider>(context, listen: false);
                        audioProvider.updatePlaylist(_filteredFiles.map((f) => f['data'] as String).toList());
                        audioProvider.selectSong(index);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _playRandom,
        child: const Icon(Icons.shuffle),
      ),
    );
  }
} 