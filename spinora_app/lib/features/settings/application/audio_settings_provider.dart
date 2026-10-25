import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Crossfade Pure Math Calculations (Testable & Deterministic)
// ─────────────────────────────────────────────────────────────────────────────

/// Calculates the fade-out volume (from 1.0 down to 0.0) as the track nears its end.
double calculateFadeOutVolume({
  required Duration position,
  required Duration duration,
  required double crossfadeDurationSeconds,
}) {
  if (crossfadeDurationSeconds <= 0.0 || duration <= Duration.zero) {
    return 1.0;
  }

  final fadeMs = (crossfadeDurationSeconds * 1000).round();
  if (fadeMs <= 0) return 1.0;

  // Avoid fading out if track duration is shorter than twice the fade window
  if (duration.inMilliseconds <= fadeMs * 2) {
    return 1.0;
  }

  final remainingMs = duration.inMilliseconds - position.inMilliseconds;
  if (remainingMs > fadeMs) {
    return 1.0;
  }
  if (remainingMs <= 0) {
    return 0.0;
  }

  return (remainingMs / fadeMs).clamp(0.0, 1.0);
}

/// Calculates the fade-in volume (from 0.0 up to 1.0) as a new track starts.
double calculateFadeInVolume({
  required Duration elapsedSinceStart,
  required double crossfadeDurationSeconds,
}) {
  if (crossfadeDurationSeconds <= 0.0) {
    return 1.0;
  }

  final fadeMs = (crossfadeDurationSeconds * 1000).round();
  if (fadeMs <= 0) return 1.0;

  final elapsedMs = elapsedSinceStart.inMilliseconds;
  if (elapsedMs <= 0) return 0.0;
  if (elapsedMs >= fadeMs) return 1.0;

  return (elapsedMs / fadeMs).clamp(0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio Settings State & Riverpod Notifier
// ─────────────────────────────────────────────────────────────────────────────

const String _kCrossfadeEnabledKey = 'spinora_crossfade_enabled';
const String _kCrossfadeDurationKey = 'spinora_crossfade_duration';

@immutable
class AudioSettingsState {
  const AudioSettingsState({
    this.crossfadeEnabled = false,
    this.crossfadeDurationSeconds = 3.0,
  });

  final bool crossfadeEnabled;
  final double crossfadeDurationSeconds;

  Duration get fadeDuration =>
      Duration(milliseconds: (crossfadeDurationSeconds * 1000).round());

  AudioSettingsState copyWith({
    bool? crossfadeEnabled,
    double? crossfadeDurationSeconds,
  }) {
    return AudioSettingsState(
      crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
      crossfadeDurationSeconds:
          crossfadeDurationSeconds ?? this.crossfadeDurationSeconds,
    );
  }
}

class AudioSettingsNotifier extends Notifier<AudioSettingsState> {
  Future<void>? _initFuture;
  Future<void> get initialized => _initFuture ?? Future.value();

  @override
  AudioSettingsState build() {
    _initFuture = _loadPersistedSettings();
    return const AudioSettingsState();
  }

  Future<void> _loadPersistedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_kCrossfadeEnabledKey) ?? false;
      final duration = prefs.getDouble(_kCrossfadeDurationKey) ?? 3.0;
      state = AudioSettingsState(
        crossfadeEnabled: enabled,
        crossfadeDurationSeconds: duration.clamp(1.0, 8.0),
      );
    } catch (e) {
      debugPrint('[AudioSettingsNotifier] Error reading prefs: $e');
    }
  }

  Future<void> setCrossfadeEnabled(bool enabled) async {
    state = state.copyWith(crossfadeEnabled: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kCrossfadeEnabledKey, enabled);
    } catch (e) {
      debugPrint('[AudioSettingsNotifier] Error saving crossfade enabled: $e');
    }
  }

  Future<void> toggleCrossfade() async {
    await setCrossfadeEnabled(!state.crossfadeEnabled);
  }

  Future<void> setCrossfadeDuration(double durationSeconds) async {
    final clamped =
        (math.max(1.0, math.min(8.0, durationSeconds)) * 10).roundToDouble() /
        10.0;
    state = state.copyWith(crossfadeDurationSeconds: clamped);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kCrossfadeDurationKey, clamped);
    } catch (e) {
      debugPrint('[AudioSettingsNotifier] Error saving crossfade duration: $e');
    }
  }
}

final audioSettingsProvider =
    NotifierProvider<AudioSettingsNotifier, AudioSettingsState>(
      AudioSettingsNotifier.new,
    );
