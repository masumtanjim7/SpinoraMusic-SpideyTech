import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service managing synchronization between Spinora playback state
/// and the native Android Home Screen App Widget (`SpinoraAppWidgetProvider`).
class HomeWidgetService {
  HomeWidgetService._();

  static const MethodChannel _channel = MethodChannel(
    'com.spideytech.spinora/widget',
  );

  static bool _initialized = false;
  static VoidCallback? _onPlayPause;
  static VoidCallback? _onNext;
  static VoidCallback? _onPrevious;

  /// Initializes the MethodChannel handler to receive widget button clicks.
  static void initialize({
    VoidCallback? onPlayPause,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
  }) {
    _onPlayPause = onPlayPause;
    _onNext = onNext;
    _onPrevious = onPrevious;

    if (_initialized) return;

    try {
      _initialized = true;

      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onWidgetAction') {
          final action = call.arguments as String?;
          switch (action) {
            case 'play_pause':
              _onPlayPause?.call();
              break;
            case 'next':
              _onNext?.call();
              break;
            case 'prev':
              _onPrevious?.call();
              break;
          }
        }
      });
    } catch (_) {
      // Ignored if binding or binary messenger is unavailable
      _initialized = false;
    }
  }

  /// Pushes current playback state to the native Android widget.
  static Future<void> updateWidget({
    required String? title,
    required String? artist,
    required bool isPlaying,
  }) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
      });
    } catch (_) {
      // Platform channels may be unavailable in unit tests or unsupported platforms
    }
  }
}
