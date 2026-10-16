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

/// Formats a [Duration] countdown into `mm:ss` or `h:mm:ss`.
String formatCountdown(Duration duration) {
  if (duration <= Duration.zero) return '0:00';
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

/// Formats a [DateTime] into a friendly human-readable timestamp (e.g. `Oct 16, 2026 • 8:45 PM`).
String formatDateTime(DateTime dateTime) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final month = months[dateTime.month - 1];
  final day = dateTime.day;
  final year = dateTime.year;
  final hour = dateTime.hour == 0
      ? 12
      : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';

  return '$month $day, $year • $hour:$minute $period';
}
