import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class MediaNotificationService {
  static const platform = MethodChannel('com.beats_drive/media_notification');
  static final _playController = StreamController<void>.broadcast();
  static final _pauseController = StreamController<void>.broadcast();
  static final _stopController = StreamController<void>.broadcast();
  static final _nextController = StreamController<void>.broadcast();
  static final _previousController = StreamController<void>.broadcast();
  static final _notificationClickController = StreamController<void>.broadcast();

  static Future<void> initialize() async {
    debugPrint('MediaNotificationService: Initializing...');
    platform.setMethodCallHandler(_handleMethod);
    debugPrint('MediaNotificationService: Method handler set');
  }

  static Future<void> _handleMethod(MethodCall call) async {
    debugPrint('MediaNotificationService: Received method call: ${call.method}');
    switch (call.method) {
      case 'onPlay':
        debugPrint('MediaNotificationService: Handling play event');
        _playController.add(null);
        break;
      case 'onPause':
        debugPrint('MediaNotificationService: Handling pause event');
        _pauseController.add(null);
        break;
      case 'onStop':
        debugPrint('MediaNotificationService: Handling stop event');
        _stopController.add(null);
        break;
      case 'onNext':
        debugPrint('MediaNotificationService: Handling next event');
        _nextController.add(null);
        break;
      case 'onPrevious':
        debugPrint('MediaNotificationService: Handling previous event');
        _previousController.add(null);
        break;
      case 'onNotificationClick':
        debugPrint('MediaNotificationService: Handling notification click event');
        _notificationClickController.add(null);
        debugPrint('MediaNotificationService: Notification click event broadcasted');
        break;
      default:
        debugPrint('MediaNotificationService: Unknown method call: ${call.method}');
        throw PlatformException(
          code: 'Unimplemented',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  static Future<void> showNotification({
    required String title,
    required String author,
    Uint8List? image,
    bool play = true,
  }) async {
    debugPrint('MediaNotificationService: Showing notification for $title by $author');
    try {
      await platform.invokeMethod('showNotification', {
        'title': title,
        'author': author,
        'image': image?.toList(),
        'play': play,
      });
      debugPrint('MediaNotificationService: Notification shown successfully');
    } on PlatformException catch (e) {
      debugPrint('MediaNotificationService: Error showing notification: ${e.message}');
      rethrow;
    }
  }

  static Future<void> hideNotification() async {
    debugPrint('MediaNotificationService: Hiding notification');
    try {
      await platform.invokeMethod('hideNotification');
      debugPrint('MediaNotificationService: Notification hidden successfully');
    } on PlatformException catch (e) {
      debugPrint('MediaNotificationService: Error hiding notification: ${e.message}');
      rethrow;
    }
  }

  static Stream<void> get onPlay => _playController.stream;
  static Stream<void> get onPause => _pauseController.stream;
  static Stream<void> get onStop => _stopController.stream;
  static Stream<void> get onNext => _nextController.stream;
  static Stream<void> get onPrevious => _previousController.stream;
  static Stream<void> get onNotificationClick => _notificationClickController.stream;
} 