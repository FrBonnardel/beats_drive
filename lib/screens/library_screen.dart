import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beats_drive/providers/audio_provider.dart';
import 'package:beats_drive/providers/music_provider.dart';
import 'package:beats_drive/services/music_scanner_service.dart';
import 'package:beats_drive/services/cache_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    // Request permissions, clear cache, and scan music on launch
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      
      // Request storage permission
      final hasPermission = await MusicScannerService.requestStoragePermission();
      if (hasPermission) {
        // Clear cache on first launch
        await CacheService.clearCache();
        // Scan for music files
        await musicProvider.scanMusicFiles();
        if (musicProvider.musicFiles.isNotEmpty) {
          audioProvider.updatePlaylist(musicProvider.musicFiles);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AudioProvider, MusicProvider>(
      builder: (context, audioProvider, musicProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Music Library'),
            actions: [
              IconButton(
                key: const ValueKey('shuffle_play_button'),
                icon: const Icon(Icons.shuffle),
                tooltip: 'Play all randomly',
                onPressed: () {
                  if (audioProvider.playlist.isNotEmpty) {
                    audioProvider.toggleShuffle();
                    audioProvider.selectSong(0);
                    audioProvider.play();
                  }
                },
              ),
              IconButton(
                key: const ValueKey('refresh_button'),
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await musicProvider.scanMusicFiles();
                  if (musicProvider.musicFiles.isNotEmpty) {
                    audioProvider.updatePlaylist(musicProvider.musicFiles);
                  }
                },
              ),
              IconButton(
                key: const ValueKey('search_button'),
                icon: const Icon(Icons.search),
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: MusicSearchDelegate(audioProvider),
                  );
                },
              ),
            ],
          ),
          body: musicProvider.isScanning
              ? Stack(
                  children: [
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.6,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'Found ${musicProvider.musicFiles.length} music files',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ],
                )
              : musicProvider.error.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            musicProvider.error,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            key: const ValueKey('retry_button'),
                            onPressed: () {
                              musicProvider.scanMusicFiles();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: audioProvider.playlist.length,
                      itemBuilder: (context, index) {
                        final filePath = audioProvider.playlist[index];
                        final fileName = filePath.split('/').last;
                        final isPlaying = index == audioProvider.currentIndex;

                        return Card(
                          key: ValueKey('song_card_$index'),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                fileName.isNotEmpty ? fileName[0] : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              fileName,
                              style: TextStyle(
                                fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                color: isPlaying
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                            subtitle: Text(filePath),
                            trailing: IconButton(
                              key: ValueKey('more_button_$index'),
                              icon: const Icon(Icons.more_vert),
                              onPressed: () {
                                _showSongOptions(context, audioProvider, index);
                              },
                            ),
                            onTap: () {
                              audioProvider.selectSong(index);
                            },
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }

  void _showSongOptions(BuildContext context, AudioProvider audioProvider, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('add_to_playlist_option'),
                leading: const Icon(Icons.playlist_add),
                title: const Text('Add to Playlist'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement add to playlist
                },
              ),
              ListTile(
                key: const ValueKey('add_to_favorites_option'),
                leading: const Icon(Icons.favorite_border),
                title: const Text('Add to Favorites'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement add to favorites
                },
              ),
              ListTile(
                key: const ValueKey('song_info_option'),
                leading: const Icon(Icons.info_outline),
                title: const Text('Song Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showSongInfo(context, audioProvider.playlist[index]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSongInfo(BuildContext context, String filePath) {
    final fileName = filePath.split('/').last;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Song Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Title: $fileName'),
              const SizedBox(height: 8),
              Text('Path: $filePath'),
              const SizedBox(height: 8),
              const Text('Duration: 3:45'), // TODO: Add actual duration
              const SizedBox(height: 8),
              const Text('Genre: Local Music'), // TODO: Add actual genre
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('close_dialog_button'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class MusicSearchDelegate extends SearchDelegate<String> {
  final AudioProvider audioProvider;

  MusicSearchDelegate(this.audioProvider);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        key: const ValueKey('clear_search_button'),
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      key: const ValueKey('back_button'),
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    audioProvider.setSearchQuery(query);
    return ListView.builder(
      itemCount: audioProvider.playlist.length,
      itemBuilder: (context, index) {
        final filePath = audioProvider.playlist[index];
        final fileName = filePath.split('/').last;

        return ListTile(
          key: ValueKey('search_result_$index'),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              fileName.isNotEmpty ? fileName[0] : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(fileName),
          subtitle: Text(filePath),
          onTap: () {
            audioProvider.selectSong(index);
            close(context, fileName);
          },
        );
      },
    );
  }
} 