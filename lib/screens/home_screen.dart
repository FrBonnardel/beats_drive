import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beats_drive/providers/audio_provider.dart';
import 'package:beats_drive/screens/library_screen.dart';
import 'package:beats_drive/screens/player_screen.dart';
import 'package:beats_drive/screens/playlist_screen.dart';
import 'package:beats_drive/widgets/mini_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const LibraryScreen(),
    const PlayerScreen(),
    const PlaylistScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_selectedIndex],
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle),
            label: 'Player',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_music),
            label: 'Playlist',
          ),
        ],
      ),
    );
  }
} 