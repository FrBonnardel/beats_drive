import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:beats_drive/screens/loading_screen.dart';
import 'package:beats_drive/providers/audio_provider.dart';
import 'package:beats_drive/providers/music_provider.dart';
import 'services/media_notification_service.dart';
import 'package:beats_drive/screens/home_screen.dart';
import 'package:beats_drive/screens/player_screen.dart';
import 'package:beats_drive/screens/playlist_screen.dart';
import 'package:beats_drive/services/app_state_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MediaNotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) {
            final provider = AudioProvider();
            provider.setContext(context);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AudioProvider, MusicProvider>(
          create: (context) => MusicProvider(
            audioProvider: Provider.of<AudioProvider>(context, listen: false),
          ),
          update: (context, audioProvider, previous) =>
              previous ?? MusicProvider(audioProvider: audioProvider),
        ),
      ],
      child: MaterialApp(
        title: 'Beats Drive',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.poppinsTextTheme(
            Theme.of(context).textTheme,
          ),
        ),
        home: const AppScaffold(),
      ),
    );
  }
}

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _restoreScreenState();
  }

  Future<void> _restoreScreenState() async {
    final state = await AppStateService.getAppState();
    final lastScreen = state['lastScreen'] as String;
    
    setState(() {
      switch (lastScreen) {
        case 'player':
          _currentIndex = 1;
          break;
        case 'library':
          _currentIndex = 0;
          break;
        case 'playlist':
          _currentIndex = 2;
          break;
        default:
          _currentIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          PlayerScreen(),
          PlaylistScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Save the current screen
          AppStateService.saveAppState(
            lastScreen: _getScreenName(index),
            playlist: context.read<AudioProvider>().playlist,
            currentSong: context.read<AudioProvider>().currentSong,
            position: context.read<AudioProvider>().position,
            isPlaying: context.read<AudioProvider>().isPlaying,
            isShuffleEnabled: context.read<AudioProvider>().isShuffleEnabled,
            isRepeatEnabled: context.read<AudioProvider>().isRepeatEnabled,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            selectedIcon: Icon(Icons.music_note),
            label: 'Now Playing',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_music_outlined),
            selectedIcon: Icon(Icons.queue_music),
            label: 'Playlist',
          ),
        ],
      ),
    );
  }

  String _getScreenName(int index) {
    switch (index) {
      case 0:
        return 'library';
      case 1:
        return 'player';
      case 2:
        return 'playlist';
      default:
        return 'library';
    }
  }
}
