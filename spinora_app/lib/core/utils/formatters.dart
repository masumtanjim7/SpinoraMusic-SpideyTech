/// Helper utilities for formatting data across Spinora.
library;

/// Formats milliseconds into a human-readable duration string (`m:ss` or `h:mm:ss`).
String formatDuration(int durationMs) {
  if (durationMs <= 0) return '0:00';
  final duration = Duration(milliseconds: durationMs);
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;

  final secondsStr = seconds.toString().padLeft(2, '0');

  if (hours > 0) {
    final minutesStr = minutes.toString().padLeft(2, '0');
    return '$hours:$minutesStr:$secondsStr';
  }

  return '$minutes:$secondsStr';
}
