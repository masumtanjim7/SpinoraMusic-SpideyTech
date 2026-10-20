import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../firebase_options.dart';
import 'app_flavor.dart';
import 'spidey_app.dart';

/// Shared startup function called by both entry points.
///
/// Overrides [appFlavorProvider] with the flavor chosen at compile time so
/// every provider and widget in the tree can read it without any platform
/// channel or BuildConfig access.
Future<void> bootstrap(AppFlavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Background Audio & Media3 ─────────────────────────────────────────────
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.spideytech.spinora.channel.audio',
    androidNotificationChannelName: 'Spinora Playback',
    androidNotificationChannelDescription:
        'Spinora Music background playback and lock screen controls',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
    androidShowNotificationBadge: true,
    notificationColor: const Color(0xFF00E5FF),
  );
  // ──────────────────────────────────────────────────────────────────────────

  // ── Firebase ──────────────────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Explicitly enable collection so crashes are reported even in debug mode.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  // Catch Flutter framework errors (e.g. build exceptions).
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Catch async errors that escape the Flutter framework (Dart zone errors).
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  // ─────────────────────────────────────────────────────────────────────────

  runApp(
    ProviderScope(
      overrides: [
        appFlavorProvider.overrideWithValue(flavor),
      ],
      child: const SpideyApp(),
    ),
  );
}
