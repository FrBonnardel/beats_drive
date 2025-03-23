import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'providers/music_provider.dart';
import 'providers/audio_provider.dart';
import 'screens/loading_screen.dart';
import 'screens/main_screen.dart';
import 'services/background_service.dart';
import 'services/cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize services
  final cacheService = CacheService();
  await cacheService.initialize();
  final musicProvider = MusicProvider(cacheService);
  final audioProvider = AudioProvider(cacheService);

  // Request permissions and start quick scan
  await musicProvider.requestPermissionAndScan();

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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beats Drive',
      theme: ThemeData.dark(useMaterial3: true),
      initialRoute: '/main',
      routes: {
        '/': (context) => const LoadingScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}
