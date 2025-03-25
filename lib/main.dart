import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'providers/music_provider.dart';
import 'providers/audio_provider.dart';
import 'screens/main_screen.dart';
import 'services/background_service.dart';
import 'services/cache_service.dart';
import 'models/music_models.dart';
import 'widgets/player_controls.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  
  // Register Hive adapters
  Hive.registerAdapter(SongAdapter());
  Hive.registerAdapter(AlbumAdapter());

  // Initialize services
  final cacheService = CacheService();
  await cacheService.initialize();
  final musicProvider = MusicProvider(cacheService);
  final audioProvider = AudioProvider(musicProvider, cacheService);

  // Initialize the app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MusicProvider>.value(value: musicProvider),
        ChangeNotifierProvider<AudioProvider>.value(value: audioProvider),
        Provider<CacheService>.value(value: cacheService),
      ],
      child: const MyApp(),
    ),
  );

  // Start background initialization after the app is running
  // This ensures the UI loads first
  WidgetsBinding.instance.addPostFrameCallback((_) {
    musicProvider.requestPermissionAndScan();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beats Drive',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
