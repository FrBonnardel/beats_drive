import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beats_drive/providers/audio_provider.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Music Library'),
            actions: [
              IconButton(
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
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: audioProvider.playlist.length,
            itemBuilder: (context, index) {
              final songInfo = audioProvider.playlist[index].split(' - ');
              final song = songInfo[0];
              final artist = songInfo[1];
              final isPlaying = index == audioProvider.currentIndex;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      song.isNotEmpty ? song[0] : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    song,
                    style: TextStyle(
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                      color: isPlaying
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  subtitle: Text(artist),
                  trailing: IconButton(
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
                leading: const Icon(Icons.playlist_add),
                title: const Text('Add to Playlist'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement add to playlist
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite_border),
                title: const Text('Add to Favorites'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement add to favorites
                },
              ),
              ListTile(
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

  void _showSongInfo(BuildContext context, String songInfo) {
    final parts = songInfo.split(' - ');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Song Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Title: ${parts[0]}'),
              const SizedBox(height: 8),
              Text('Artist: ${parts[1]}'),
              const SizedBox(height: 8),
              const Text('Duration: 3:45'), // TODO: Add actual duration
              const SizedBox(height: 8),
              const Text('Genre: Pop'), // TODO: Add actual genre
            ],
          ),
          actions: [
            TextButton(
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
        final songInfo = audioProvider.playlist[index].split(' - ');
        final song = songInfo[0];
        final artist = songInfo[1];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              song.isNotEmpty ? song[0] : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(song),
          subtitle: Text(artist),
          onTap: () {
            audioProvider.selectSong(index);
            close(context, song);
          },
        );
      },
    );
  }
} 