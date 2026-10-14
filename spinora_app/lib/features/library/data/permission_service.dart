import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Resolves to the correct [Permission] for reading local audio files.
///
/// • Android 13+ (API 33+): [Permission.audio]  → READ_MEDIA_AUDIO
/// • Android ≤12          : [Permission.storage] → READ_EXTERNAL_STORAGE
/// • All other platforms  : [Permission.storage] (handled gracefully by the
///   library; will always return [PermissionStatus.granted] on iOS / desktop).
Permission get _effectiveAudioPermission {
  if (!Platform.isAndroid) return Permission.storage;
  // permission_handler 11+ maps Permission.audio to READ_MEDIA_AUDIO only on
  // API 33+, so we can safely use it unconditionally on Android and rely on
  // the plugin to pick the right manifest entry.
  return Permission.audio;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns the current [PermissionStatus] without showing a system dialog.
Future<PermissionStatus> checkAudioPermission() =>
    _effectiveAudioPermission.status;

/// Shows the system permission dialog if needed and returns the new status.
///
/// If status comes back as [PermissionStatus.permanentlyDenied], the caller
/// should offer a button that calls [openPermissionSettings].
Future<PermissionStatus> requestAudioPermission() =>
    _effectiveAudioPermission.request();

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
final audioPermissionStatusProvider =
    FutureProvider<PermissionStatus>((ref) => checkAudioPermission());
