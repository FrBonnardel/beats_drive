import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:beats_drive/screens/loading_screen.dart';
import 'package:beats_drive/providers/audio_provider.dart';
import 'package:beats_drive/providers/music_provider.dart';
import 'services/media_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MediaNotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AudioProvider()),
        ChangeNotifierProvider(create: (context) => MusicProvider()),
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
        home: const LoadingScreen(),
      ),
    );
  }
}
