import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/audio_provider.dart';
import '../providers/music_provider.dart';
import '../screens/player_screen.dart';
import '../screens/playlist_screen.dart';
import '../screens/library_screen.dart';
import '../widgets/mini_player.dart';
import '../services/media_notification_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<LibraryScreenState> _libraryScreenKey = GlobalKey();
  StreamSubscription? _notificationClickSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('MainScreen: Initializing...');
    
    // Start quick loading when the screen is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('MainScreen: Post frame callback - starting quick load');
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      musicProvider.quickLoad();
    });

    // Listen for notification clicks
    debugPrint('MainScreen: Setting up notification click listener');
    _notificationClickSubscription = MediaNotificationService.onNotificationClick.listen((_) {
      debugPrint('MainScreen: Notification clicked, current index: $_selectedIndex');
      if (!mounted) {
        debugPrint('MainScreen: Widget not mounted, cannot handle notification click');
        return;
      }
      debugPrint('MainScreen: Navigating to player screen (index 1)');
      setState(() => _selectedIndex = 1); // Switch to player screen
      debugPrint('MainScreen: Navigation complete, new index: $_selectedIndex');
    });
    debugPrint('MainScreen: Notification click listener setup complete');
  }

  @override
  void dispose() {
    debugPrint('MainScreen: Disposing...');
    _notificationClickSubscription?.cancel();
    debugPrint('MainScreen: Notification click subscription cancelled');
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) return;
    debugPrint('MainScreen: Navigation - Switching from screen ${_getScreenName(_selectedIndex)} to ${_getScreenName(index)}');
    setState(() => _selectedIndex = index);
  }

  void _showSortDialog() {
    if (_selectedIndex == 0) {
      _libraryScreenKey.currentState?.showSortDialog();
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
              icon: const Icon(Icons.sort),
              onPressed: _showSortDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _libraryScreenKey.currentState?.refresh();
              },
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
          Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    LibraryScreen(key: _libraryScreenKey),
                    const PlayerScreen(),
                    const PlaylistScreen(),
                  ],
                ),
              ),
              if (_selectedIndex != 1) // Don't show MiniPlayer on PlayerScreen
                const MiniPlayer(),
            ],
          ),
          // Add loading overlay
          Consumer<MusicProvider>(
            builder: (context, musicProvider, child) {
              if (!musicProvider.isInitialLoad && !musicProvider.isQuickLoading) {
                return const SizedBox.shrink();
              }
              
              return Positioned.fill(
                child: Material(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                  child: SafeArea(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            musicProvider.isInitialLoad 
                                ? 'Loading music library... (${musicProvider.loadingProgress} of ${musicProvider.totalSongsToLoad})'
                                : musicProvider.quickLoadStatus,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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

  String _getScreenName(int index) {
    switch (index) {
      case 0:
        return 'Library';
      case 1:
        return 'Now Playing';
      case 2:
        return 'Playlist';
      default:
        return 'Unknown';
    }
  }
} 