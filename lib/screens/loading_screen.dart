import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import 'home_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  Future<void> _startScanning() async {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    await musicProvider.requestPermissionAndScan(forceRescan: false);
  }

  void _navigateToHome() {
    if (!mounted) return;
    
    // Use post-frame callback to ensure we're not in the middle of a build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      body: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          // Only navigate when we receive the complete scan message
          if (musicProvider.isComplete && !musicProvider.isScanning && musicProvider.currentStatus == 'All files processed successfully') {
            _navigateToHome();
          }

          return Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.white : theme.primaryColor,
                        ),
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        musicProvider.currentStatus,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (musicProvider.isScanning) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Found ${musicProvider.musicFiles.length} music files',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (musicProvider.totalFiles > 0) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 200,
                              height: 8,
                              child: LinearProgressIndicator(
                                value: musicProvider.totalFiles > 0
                                    ? musicProvider.processedFiles / musicProvider.totalFiles
                                    : null,
                                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark ? Colors.white : theme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (musicProvider.error.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.red[900]?.withOpacity(0.3)
                                : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            musicProvider.error,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.red[200] : Colors.red[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Continue in background button at the bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: _navigateToHome,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continue in Background'),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : Colors.black87,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      Text(
                        'Music scanning will continue',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 