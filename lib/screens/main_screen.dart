import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../screens/player_screen.dart';
import '../screens/playlist_screen.dart';
import '../screens/library_screen.dart';
import '../widgets/mini_player.dart';
import '../widgets/shared_widgets.dart';

// Static widgets
class _MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onPlaylistPressed;

  const _MainAppBar({required this.onPlaylistPressed});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Now Playing'),
      actions: [
        IconButton(
          icon: const Icon(Icons.playlist_play),
          onPressed: onPlaylistPressed,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Static navigation bar
class _MainNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const _MainNavigationBar({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.library_music_outlined),
          selectedIcon: Icon(Icons.library_music),
          label: 'Library',
        ),
        NavigationDestination(
          icon: Icon(Icons.play_circle_outline),
          selectedIcon: Icon(Icons.play_circle),
          label: 'Player',
        ),
        NavigationDestination(
          icon: Icon(Icons.playlist_play_outlined),
          selectedIcon: Icon(Icons.playlist_play),
          label: 'Playlist',
        ),
      ],
    );
  }
}

// Static screen container with RepaintBoundary
class _ScreenContainer extends StatelessWidget {
  final Widget child;

  const _ScreenContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: child,
    );
  }
}

// Static screens list
class _ScreensList extends StatelessWidget {
  final List<Widget> screens;

  const _ScreensList({required this.screens});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: screens,
      ),
    );
  }
}

// Dynamic mini player container
class _DynamicMiniPlayer extends StatelessWidget {
  final int currentIndex;

  const _DynamicMiniPlayer({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    if (currentIndex == 1) return const SizedBox.shrink();

    return const Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: MiniPlayer(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final List<Widget> _screens;
  int _selectedIndex = 0;
  final GlobalKey<LibraryScreenState> _libraryScreenKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _screens = [
      LibraryScreen(key: _libraryScreenKey),
      const PlayerScreen(),
      const PlaylistScreen(),
    ];
  }

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  void _showSortDialog() {
    if (_selectedIndex == 0) {
      _libraryScreenKey.currentState?.showSortDialog();
    }
  }

  void _showSearchDialog() {
    if (_selectedIndex == 0) {
      _libraryScreenKey.currentState?.showSearchDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 1 ? null : AppBar(
        title: Text(_getAppBarTitle()),
        actions: [
          if (_selectedIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _showSearchDialog,
            ),
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: _showSortDialog,
            ),
          ],
          if (_selectedIndex == 2) ...[
            IconButton(
              icon: const Icon(Icons.shuffle),
              onPressed: () {
                final audioProvider = Provider.of<AudioProvider>(context, listen: false);
                audioProvider.toggleShuffle();
              },
              color: Provider.of<AudioProvider>(context).isShuffleEnabled
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.repeat),
              onPressed: () {
                final audioProvider = Provider.of<AudioProvider>(context, listen: false);
                audioProvider.toggleRepeat();
              },
              color: Provider.of<AudioProvider>(context).isRepeatEnabled
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          if (_selectedIndex != 1) // Don't show MiniPlayer on PlayerScreen
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
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle),
            label: 'Now Playing',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_music),
            label: 'Playlist',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Library';
      case 1:
        return 'Now Playing';
      case 2:
        return 'Playlist';
      default:
        return 'Beats Drive';
    }
  }
} 