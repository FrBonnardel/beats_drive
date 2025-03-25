# Beats Drive 🎵

<div align="center">

![Beats Drive Logo](assets/icon/icon.png)

A modern, feature-rich music player application built with Flutter, offering a seamless music listening experience with a beautiful and intuitive user interface.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-blue.svg)](https://developer.android.com)

</div>

## 📋 Table of Contents
- [Features](#-features)
- [Getting Started](#-getting-started)
- [Project Structure](#-project-structure)
- [Technical Implementation](#-technical-implementation)
- [Configuration](#-configuration)
- [Contributing](#-contributing)
- [License](#-license)
- [Support](#-support)
- [Updates](#-updates)
- [Code References](#-code-references)

## ✨ Features

### 🎵 Music Library
- **Media Scanning**
  - Efficient pagination (50 items per page)
  - Smart caching system
  - Automatic media store detection
  - Support for internal/external storage
- **Filtering System**
  - Minimum duration (30 seconds)
  - Valid file path validation
  - Non-pending file filtering
  - Non-trashed file filtering
- **Metadata Support**
  - Basic info (title, artist, album)
  - Technical details (duration, track, year)
  - File info (size, path, dates)
  - Album art integration
- **Performance Features**
  - Quick loading with progress tracking
  - Background scanning
  - State persistence
  - Cache invalidation (5 minutes)
  - Full scan interval (1 hour)

### 🎧 Player
- **Core Features**
  - Robust audio playback (just_audio)
  - Provider pattern state management
  - Background playback support
  - State persistence
- **Playback Controls**
  - Play/pause with state persistence
  - Next/previous navigation
  - Shuffle and repeat modes
  - Progress bar with seeking
  - Volume control
- **UI Components**
  - Large album art (300x300)
  - Animated artwork transitions
  - Song information display
  - Progress tracking
  - Mini-player integration
- **Performance**
  - Memory-optimized album art
  - Error handling
  - Recovery mechanisms

### 📋 Playlist Management
- **Core Features**
  - Dynamic playlist handling
  - Queue management
  - State persistence
- **Playback Modes**
  - Shuffle toggle
  - Repeat modes (single/all/none)
- **Smart Features**
  - Context-aware generation
  - Auto-scroll to current song
- **UI Components**
  - Album art integration
  - Current song highlighting
  - Drag-and-drop reordering
  - Long-press options
- **Error Handling**
  - Loading states
  - Error recovery

### 🔔 Media Notifications
- **Core Features**
  - Persistent media controls
  - System integration
  - Background service
- **Controls**
  - Play/pause toggle
  - Next/previous track
  - Album art display
- **System Integration**
  - Lock screen controls
  - Notification center
  - Media session support
- **Service Management**
  - Continuous playback
  - State synchronization
  - Lifecycle management
- **UI Features**
  - Custom styling
  - Progress tracking
  - Click handling
  - Channel management

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio / VS Code with Flutter extensions
- Android device/emulator (Android 6.0+)
- Git

### Installation Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/beats_drive.git
   ```

2. Navigate to project directory:
   ```bash
   cd beats_drive
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

### Release Build
```bash
flutter build apk --release
```

## 🏗️ Project Structure

```
lib/
├── screens/          # Main app screens
│   ├── library_screen.dart    # Music library and browsing
│   ├── player_screen.dart     # Now playing screen
│   └── playlist_screen.dart   # Playlist management
├── providers/        # State management
│   ├── audio_provider.dart    # Audio playback control
│   └── music_provider.dart    # Music library management
├── services/         # Background services
│   ├── media_notification_service.dart  # Media notification handling
│   ├── playback_state_service.dart     # Playback state management
│   └── media_store_service.dart        # Media store interaction
├── models/          # Data models
│   └── music_models.dart
├── widgets/         # Reusable UI components
│   ├── mini_player.dart
│   ├── player_controls.dart
│   └── shared_widgets.dart
└── main.dart        # App entry point
```

## 💻 Technical Implementation

### Architecture Overview
- **State Management**: Provider pattern for reactive updates
  - Implementation: `lib/providers/audio_provider.dart`, `lib/providers/music_provider.dart`
- **Platform Integration**: Native Android functionality via platform channels
  - Implementation: `android/app/src/main/kotlin/com/beatsdrive/MainActivity.kt`
- **Background Processing**: Foreground service for playback/notifications
  - Implementation: `android/app/src/main/kotlin/com/beatsdrive/MediaNotificationService.kt`
- **Data Persistence**: SharedPreferences + Hive for state management
  - Implementation: `lib/services/media_store_service.dart`

### Core Components

#### Media Store Integration
- **Query System**
  - Implementation: `lib/services/media_store_service.dart`
  - Native: `android/app/src/main/kotlin/com/beatsdrive/MediaStorePlugin.kt`
- **Filtering System**
  - Implementation: `lib/services/media_store_service.dart`
  - Native: `android/app/src/main/kotlin/com/beatsdrive/MediaStorePlugin.kt`
- **Metadata System**
  - Implementation: `lib/services/media_store_service.dart`
  - Models: `lib/models/music_models.dart`

#### Media Notifications
- **Core Features**
  - Implementation: `lib/services/media_notification_service.dart`
  - Native: `android/app/src/main/kotlin/com/beatsdrive/MediaNotificationService.kt`
- **Service Management**
  - Implementation: `lib/services/media_notification_service.dart`
  - Native: `android/app/src/main/kotlin/com/beatsdrive/MediaNotificationService.kt`
- **Lifecycle Handling**
  - Implementation: `lib/services/media_notification_service.dart`
  - Native: `android/app/src/main/kotlin/com/beatsdrive/MediaNotificationService.kt`

#### Audio Playback
- **Playback System**
  - Implementation: `lib/providers/audio_provider.dart`
  - UI: `lib/screens/player_screen.dart`
- **Playlist Features**
  - Implementation: `lib/providers/audio_provider.dart`
  - UI: `lib/screens/playlist_screen.dart`
- **Background Support**
  - Implementation: `lib/services/playback_state_service.dart`
  - Native: `android/app/src/main/kotlin/com/beatsdrive/MediaNotificationService.kt`

### Performance Optimizations

#### Memory Management
- **Album Art System**
  - Implementation: `lib/services/media_store_service.dart`
  - UI: `lib/widgets/shared_widgets.dart`
- **List Optimization**
  - Implementation: `lib/screens/library_screen.dart`
  - UI: `lib/widgets/song_item.dart`
- **Resource Handling**
  - Implementation: `lib/providers/audio_provider.dart`
  - Native: `android/app/src/main/kotlin/com/beatsdrive/MediaNotificationService.kt`

#### Error Handling
- **Media Loading**
  - Implementation: `lib/services/media_store_service.dart`
  - UI: `lib/screens/library_screen.dart`
- **Playback System**
  - Implementation: `lib/providers/audio_provider.dart`
  - UI: `lib/screens/player_screen.dart`
- **State Management**
  - Implementation: `lib/services/playback_state_service.dart`
  - Native: `android/app/src/main/kotlin/com/beatsdrive/MediaNotificationService.kt`

## 🔧 Configuration

### Required Permissions
- **Storage Access**
  - `READ_EXTERNAL_STORAGE`: Music file access
  - `WRITE_EXTERNAL_STORAGE`: Playlist/settings storage
  - `MANAGE_EXTERNAL_STORAGE`: Media scanning
- **Media Playback**
  - `FOREGROUND_SERVICE`: Background playback
  - `WAKE_LOCK`: Sleep prevention
- **System Integration**
  - `POST_NOTIFICATIONS`: Media controls
  - `RECEIVE_BOOT_COMPLETED`: Service restoration

### Environment Setup
- **Android Configuration**
  - Minimum SDK: 23 (Android 6.0)
  - Target SDK: Latest stable
  - Multidex support
  - Media notification channel
- **Flutter Configuration**
  - Platform channels
  - Background service
  - Media session handling
- **Dependencies**
  - just_audio: Audio playback
  - provider: State management
  - shared_preferences: Settings storage
  - path_provider: File system access
  - audio_session: Audio focus handling

## 🤝 Contributing

### Development Guidelines
- **Code Style**
  - Flutter style guide compliance
  - Meaningful naming
  - Clear documentation
  - Focused functions
- **Testing Requirements**
  - Unit tests
  - Widget tests
  - Edge case testing
  - Platform verification
- **Documentation Standards**
  - README updates
  - API documentation
  - Code comments
  - Maintenance
- **Error Handling**
  - Graceful degradation
  - User messages
  - Error logging
  - Edge cases
- **Performance Guidelines**
  - Memory optimization
  - UI efficiency
  - Data structures
  - Performance profiling

### Pull Request Process
1. Fork repository
2. Create feature branch
3. Commit changes
4. Push branch
5. Create PR

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Contributors and maintainers
- Open source packages:
  - just_audio
  - provider
  - shared_preferences
  - path_provider
  - audio_session

## 💬 Support

For support:
1. Check the [FAQ](FAQ.md)
2. Search existing issues
3. Create new issue
4. Join [Discord server](https://discord.gg/your-server)

## 🔄 Updates

### Planned Features
- Offline mode
- Cloud backup
- Cross-platform support
- Advanced audio effects
- Theme customization
- Gesture controls
- Playlist sharing
- Audio format conversion

### Version History
- **v1.0.0** (Initial Release)
  - Basic music playback
  - Library management
  - Playlist support
  - Media notifications

## 📚 Code References

### Core Screens
- **Main Screen**: `lib/screens/main_screen.dart`
  - App navigation
  - Bottom navigation
  - Mini-player integration
- **Library Screen**: `lib/screens/library_screen.dart`
  - Music browsing
  - Search functionality
  - Sorting options
- **Player Screen**: `lib/screens/player_screen.dart`
  - Now playing view
  - Playback controls
  - Progress tracking
- **Playlist Screen**: `lib/screens/playlist_screen.dart`
  - Queue management
  - Playlist controls
  - Song reordering

### State Management
- **Audio Provider**: `lib/providers/audio_provider.dart`
  - Playback control
  - Queue management
  - State persistence
- **Music Provider**: `lib/providers/music_provider.dart`
  - Library management
  - Media scanning
  - Metadata handling

### Services
- **Media Store Service**: `lib/services/media_store_service.dart`
  - Media scanning
  - Metadata extraction
  - Cache management
- **Media Notification Service**: `lib/services/media_notification_service.dart`
  - Notification handling
  - Media controls
  - System integration
- **Playback State Service**: `lib/services/playback_state_service.dart`
  - State persistence
  - Background playback
  - Error recovery

### Native Implementation
- **Main Activity**: `android/app/src/main/kotlin/com/beatsdrive/MainActivity.kt`
  - Platform channel setup
  - Service initialization
  - Intent handling
- **Media Store Plugin**: `android/app/src/main/kotlin/com/beatsdrive/MediaStorePlugin.kt`
  - Media scanning
  - Metadata extraction
  - File handling
- **Media Notification Service**: `android/app/src/main/kotlin/com/beatsdrive/MediaNotificationService.kt`
  - Notification management
  - Media session
  - Background service

### UI Components
- **Mini Player**: `lib/widgets/mini_player.dart`
  - Compact player view
  - Quick controls
- **Player Controls**: `lib/widgets/player_controls.dart`
  - Playback buttons
  - Progress bar
- **Shared Widgets**: `lib/widgets/shared_widgets.dart`
  - Common UI elements
  - Album art handling
- **Song Item**: `lib/widgets/song_item.dart`
  - Song list items
  - Metadata display

### Models
- **Music Models**: `lib/models/music_models.dart`
  - Data structures
  - Type definitions
  - Serialization

---

<div align="center">
Made with ❤️ by the Beats Drive Team
</div>