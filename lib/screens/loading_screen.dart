import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../providers/music_provider.dart';
import '../providers/audio_provider.dart';
import '../services/cache_service.dart';
import '../widgets/shared_widgets.dart';
import 'main_screen.dart';

// Static widgets
class _LoadingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _LoadingAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Loading'),
      automaticallyImplyLeading: false,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _LoadingContent extends StatelessWidget {
  final String status;
  final bool isLoading;
  final int songsFound;
  final bool loadedFromCache;
  final VoidCallback onRetry;

  const _LoadingContent({
    required this.status,
    required this.isLoading,
    required this.songsFound,
    required this.loadedFromCache,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            status,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (songsFound > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$songsFound songs found${loadedFromCache ? ' (from cache)' : ' (from scan)'}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          if (!isLoading)
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class _PermissionDeniedDialog extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _PermissionDeniedDialog({
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Permission Required'),
      content: const Text(
        'Storage permission is required to scan music files. '
        'Please grant the permission in your device settings.',
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: onRetry,
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}

class LoadingScreen extends StatefulWidget {
  final bool isRescan;

  const LoadingScreen({
    super.key,
    this.isRescan = false,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  bool _hasError = false;
  String? _errorMessage;
  int _songsFound = 0;
  bool _isLoading = true;
  bool _loadedFromCache = false;
  bool _isBackgroundScanRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    try {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      debugPrint('LoadingScreen: Starting permission request and scan');
      
      final hasPermission = await musicProvider.requestPermissionAndScan();
      debugPrint('LoadingScreen: Permission request result: $hasPermission');
      
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Storage permission is required to scan music files';
            _isLoading = false;
          });
        }
        return;
      }

      // If this is a rescan, wait for the full scan to complete
      if (widget.isRescan) {
        await musicProvider.songs;
        debugPrint('LoadingScreen: Songs loaded, count: ${musicProvider.songs.length}');
        
        if (mounted) {
          setState(() {
            _songsFound = musicProvider.songs.length;
            _isLoading = false;
          });
        }
      } else {
        // For initial load, try to load from cache first
        debugPrint('Loading songs from cache...');
        await musicProvider.loadFromCache();
        
        if (musicProvider.songs.isEmpty) {
          // If no cached songs, get quick MediaStore info
          final quickSongs = await musicProvider.getQuickMediaStoreInfo();
          if (mounted) {
            setState(() {
              _songsFound = quickSongs.length;
              _isLoading = false;
            });
          }

          // Start background scanning with resource limits
          _startBackgroundScan(musicProvider);
        } else {
          // Use cached songs
          if (mounted) {
            setState(() {
              _songsFound = musicProvider.songs.length;
              _loadedFromCache = true;
              _isLoading = false;
            });
          }
        }
      }

      // If no songs were found, show error
      if (_songsFound == 0) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'No music files found on your device';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('LoadingScreen: Error during initialization: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load music library: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startBackgroundScan(MusicProvider musicProvider) async {
    if (_isBackgroundScanRunning) return;

    setState(() => _isBackgroundScanRunning = true);

    try {
      // Start background scan with resource limits
      await musicProvider.startBackgroundScan(
        batchSize: 50, // Process 50 songs at a time
        delayBetweenBatches: const Duration(milliseconds: 500), // Add delay between batches
        maxConcurrentOperations: 2, // Limit concurrent operations
      );
    } finally {
      if (mounted) {
        setState(() => _isBackgroundScanRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _LoadingAppBar(),
      body: _hasError
          ? ErrorView(
              message: _errorMessage ?? 'An error occurred',
              onRetry: _initialize,
            )
          : _isLoading
              ? const LoadingIndicator(
                  message: 'Loading your music library...',
                )
              : _LoadingContent(
                  status: widget.isRescan 
                      ? 'Scan complete' 
                      : _isBackgroundScanRunning
                          ? 'Loading additional info in background...'
                          : 'Initial scan complete',
                  isLoading: _isBackgroundScanRunning,
                  songsFound: _songsFound,
                  loadedFromCache: _loadedFromCache,
                  onRetry: _initialize,
                ),
    );
  }
} 