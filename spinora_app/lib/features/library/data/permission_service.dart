import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns the current [PermissionStatus] without showing a system dialog.
///
/// Checks both [Permission.audio] (Android 13+) and [Permission.storage] (Android <= 12).
Future<PermissionStatus> checkAudioPermission() async {
  if (!Platform.isAndroid) return PermissionStatus.granted;
  final audioStatus = await Permission.audio.status;
  if (audioStatus.isGranted) return PermissionStatus.granted;
  final storageStatus = await Permission.storage.status;
  if (storageStatus.isGranted) return PermissionStatus.granted;
  return audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied
      ? PermissionStatus.permanentlyDenied
      : audioStatus;
}

/// Shows the system permission dialog if needed and returns the new status.
Future<PermissionStatus> requestAudioPermission() async {
  if (!Platform.isAndroid) return PermissionStatus.granted;
  final audioStatus = await Permission.audio.request();
  if (audioStatus.isGranted) return PermissionStatus.granted;
  final storageStatus = await Permission.storage.request();
  return storageStatus.isGranted ? PermissionStatus.granted : audioStatus;
}

/// Opens the app's system-settings page so the user can manually grant the
/// permission after "don't ask again" was chosen.
Future<void> openPermissionSettings() => openAppSettings();

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Exposes the *current* audio permission status as a [FutureProvider].
///
/// After calling [requestAudioPermission] invalidate this with
/// `ref.invalidate(audioPermissionStatusProvider)` to re-read the status.
final audioPermissionStatusProvider = FutureProvider<PermissionStatus>(
  (ref) => checkAudioPermission(),
);
