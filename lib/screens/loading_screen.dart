import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../providers/music_provider.dart';
import '../providers/audio_provider.dart';
import '../services/cache_service.dart';
import 'main_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _status = 'Initializing...';
  bool _isLoading = true;
  int _songsFound = 0;
  bool _loadedFromCache = false;

  @override
  void initState() {
    super.initState();
    debugPrint('LoadingScreen: Initializing...');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    try {
      setState(() {
        _status = 'Checking permissions...';
        _songsFound = 0;
        _loadedFromCache = false;
      });
      debugPrint('LoadingScreen: Checking permissions...');

      // Check Android version and request appropriate permissions
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      bool permissionsGranted = false;
      if (androidInfo.version.sdkInt >= 33) {
        debugPrint('LoadingScreen: Android 13+ detected, requesting audio permission');
        final audioStatus = await Permission.audio.request();
        permissionsGranted = audioStatus.isGranted;
        debugPrint('LoadingScreen: Audio permission status: ${audioStatus.name}');
      } else {
        debugPrint('LoadingScreen: Android <13 detected, requesting storage permission');
        final storageStatus = await Permission.storage.request();
        permissionsGranted = storageStatus.isGranted;
        debugPrint('LoadingScreen: Storage permission status: ${storageStatus.name}');
      }

      if (!permissionsGranted) {
        debugPrint('LoadingScreen: Permissions not granted');
        if (!mounted) return;
        _showPermissionDeniedDialog();
        return;
      }

      setState(() {
        _status = 'Initializing cache...';
        _songsFound = 0;
        _loadedFromCache = false;
      });
      debugPrint('LoadingScreen: Initializing cache service...');

      // Initialize cache service
      await CacheService.initialize();
      debugPrint('LoadingScreen: Cache service initialized');

      // Initialize music provider
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);

      setState(() {
        _status = 'Loading music library...';
        _songsFound = 0;
        _loadedFromCache = false;
      });
      debugPrint('LoadingScreen: Attempting to load music library from cache...');

      // Try loading from cache first
      await musicProvider.loadFromCache();
      debugPrint('LoadingScreen: Cache load attempt completed');

      // If no songs in cache or cache is invalid, do a full scan
      if (musicProvider.songs.isEmpty) {
        debugPrint('LoadingScreen: No songs found in cache, starting new scan...');
        setState(() {
          _status = 'Scanning music files...';
          _songsFound = 0;
          _loadedFromCache = false;
        });
        
        await musicProvider.requestPermissionAndScan();

        // Wait for songs to be processed and cached
        setState(() {
          _status = 'Processing music files...';
          _songsFound = 0;
          _loadedFromCache = false;
        });
        debugPrint('LoadingScreen: Processing scanned music files...');

        // Keep checking until songs are loaded or an error occurs
        while (musicProvider.isScanning && mounted) {
          setState(() {
            _songsFound = musicProvider.songs.length;
          });
          debugPrint('LoadingScreen: Scan in progress... Found $_songsFound songs');
          await Future.delayed(const Duration(milliseconds: 100));
        }
        debugPrint('LoadingScreen: Scan completed, saving to cache...');
      } else {
        setState(() {
          _songsFound = musicProvider.songs.length;
          _loadedFromCache = true;
        });
        debugPrint('LoadingScreen: Successfully loaded $_songsFound songs from existing cache');
      }

      if (!mounted) return;

      // Check if there was an error during scanning
      if (musicProvider.songs.isEmpty && !musicProvider.isScanning) {
        debugPrint('LoadingScreen: No music files found after scanning');
        setState(() {
          _status = 'No music files found';
          _isLoading = false;
          _songsFound = 0;
          _loadedFromCache = false;
        });
        return;
      }

      // Initialize audio provider and restore state
      debugPrint('LoadingScreen: Initializing audio provider and restoring state...');
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      await Future.delayed(const Duration(milliseconds: 500)); // Give time for state restoration
      debugPrint('LoadingScreen: State restoration completed');

      if (!mounted) return;

      debugPrint('LoadingScreen: Navigating to MainScreen');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } catch (e) {
      debugPrint('LoadingScreen: Error during initialization: $e');
      if (!mounted) return;
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
        _songsFound = 0;
        _loadedFromCache = false;
      });
    }
  }

  void _showPermissionDeniedDialog() {
    debugPrint('LoadingScreen: Showing permission denied dialog');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Storage permission is required to scan music files. '
          'Please grant the permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('LoadingScreen: User chose to retry permission request');
              Navigator.of(context).pop();
              _initialize();
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              debugPrint('LoadingScreen: User cancelled permission request');
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status),
            if (_songsFound > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$_songsFound songs found${_loadedFromCache ? ' (from cache)' : ' (from scan)'}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            if (!_isLoading)
              TextButton(
                onPressed: _initialize,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
} 