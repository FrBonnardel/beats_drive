import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class MediaNotificationService {
  static const platform = MethodChannel('com.beats_drive/media_notification');
  static final _playController = StreamController<void>.broadcast();
  static final _pauseController = StreamController<void>.broadcast();
  static final _stopController = StreamController<void>.broadcast();
  static final _nextController = StreamController<void>.broadcast();
  static final _previousController = StreamController<void>.broadcast();

  static Future<void> initialize() async {
    platform.setMethodCallHandler(_handleMethod);
  }

  static Future<void> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onPlay':
        _playController.add(null);
        break;
      case 'onPause':
        _pauseController.add(null);
        break;
      case 'onStop':
        _stopController.add(null);
        break;
      case 'onNext':
        _nextController.add(null);
        break;
      case 'onPrevious':
        _previousController.add(null);
        break;
      default:
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
    try {
      await platform.invokeMethod('showNotification', {
        'title': title,
        'author': author,
        'image': image?.toList(),
        'play': play,
      });
    } on PlatformException catch (e) {
      print('Error showing notification: ${e.message}');
    }
  }

  static Future<void> hideNotification() async {
    try {
      await platform.invokeMethod('hideNotification');
    } on PlatformException catch (e) {
      print('Error hiding notification: ${e.message}');
    }
  }

  static Stream<void> get onPlay => _playController.stream;
  static Stream<void> get onPause => _pauseController.stream;
  static Stream<void> get onStop => _stopController.stream;
  static Stream<void> get onNext => _nextController.stream;
  static Stream<void> get onPrevious => _previousController.stream;
} 