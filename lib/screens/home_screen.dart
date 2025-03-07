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
  final Map<int, Widget> _screens = {};

  Widget _getScreen(int index) {
    if (!_screens.containsKey(index)) {
      switch (index) {
        case 0:
          _screens[index] = const LibraryScreen();
          break;
        case 1:
          _screens[index] = const PlayerScreen();
          break;
        case 2:
          _screens[index] = const PlaylistScreen();
          break;
      }
    }
    return _screens[index]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _getScreen(_selectedIndex),
          if (_selectedIndex != 1) // Hide MiniPlayer on Player screen (index 1)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 56,
        child: NavigationBar(
          height: 56,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
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
      ),
    );
  }
} 