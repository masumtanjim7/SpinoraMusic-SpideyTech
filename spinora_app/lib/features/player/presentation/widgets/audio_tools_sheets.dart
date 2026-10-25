import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/audio/track.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../application/player_controller.dart';
import '../../../library/presentation/widgets/edit_song_dialog.dart';
import 'equalizer_sheet.dart';

// ---------------------------------------------------------------------------
// Helpers to Launch Audio Tool Sheets
// ---------------------------------------------------------------------------

export 'equalizer_sheet.dart' show showEqualizerSheet, EqualizerSheet;

void showSleepTimerSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const SleepTimerSheet(),
  );
}

void showPlaybackSpeedSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const PlaybackSpeedSheet(),
  );
}

void showTrackInfoSheet(BuildContext context, Track track) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => TrackInfoSheet(track: track),
  );
}

// ---------------------------------------------------------------------------
// Sleep Timer Bottom Sheet
// ---------------------------------------------------------------------------

class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final tt = Theme.of(context).textTheme;
    final isLight = context.isLight;

    final timerPresets = [
      const _TimerOption(label: '15 Minutes', duration: Duration(minutes: 15)),
      const _TimerOption(label: '30 Minutes', duration: Duration(minutes: 30)),
      const _TimerOption(label: '45 Minutes', duration: Duration(minutes: 45)),
      const _TimerOption(label: '60 Minutes', duration: Duration(minutes: 60)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.96)
            : AppColors.surface.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.7),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cyanAccent.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.bedtime_rounded,
                      size: 18,
                      color: AppColors.cyanAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SLEEP TIMER',
                    style: tt.titleMedium?.copyWith(
                      color: context.primaryText,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: context.secondaryText),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Active Timer Status Card (if running)
          if (playerState.isSleepTimerActive) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: isLight
                      ? [
                          AppColors.cyanAccent.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.8),
                        ]
                      : [
                          AppColors.deepPurple.withValues(alpha: 0.5),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                ),
                border: Border.all(
                  color: AppColors.cyanAccent.withValues(
                    alpha: isLight ? 0.4 : 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cyanAccent,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyanAccent.withValues(alpha: 0.7),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playerState.stopAtEndOfTrack
                              ? 'Pauses at end of current track'
                              : 'Pausing in ${formatCountdown(playerState.remainingSleepDuration ?? Duration.zero)}',
                          style: tt.titleSmall?.copyWith(
                            color: context.primaryText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Playback will fade/pause automatically',
                          style: tt.bodySmall?.copyWith(
                            color: context.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      controller.cancelSleepTimer();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.pinkAccent,
                      backgroundColor: Colors.pinkAccent.withValues(
                        alpha: 0.12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Timer Preset List
          for (final preset in timerPresets) ...[
            _TimerOptionTile(
              title: preset.label,
              subtitle: 'Pauses audio after ${preset.duration.inMinutes} mins',
              icon: Icons.timer_outlined,
              isSelected:
                  !playerState.stopAtEndOfTrack &&
                  playerState.remainingSleepDuration != null &&
                  (playerState.remainingSleepDuration!.inMinutes -
                              preset.duration.inMinutes)
                          .abs() <=
                      1,
              onTap: () {
                controller.setSleepTimer(preset.duration);
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),
          ],

          // End of Track Option
          _TimerOptionTile(
            title: 'End of Current Track',
            subtitle: 'Pauses when the active song finishes playing',
            icon: Icons.skip_next_rounded,
            isSelected: playerState.stopAtEndOfTrack,
            onTap: () {
              controller.setSleepTimerEndOfTrack();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _TimerOption {
  const _TimerOption({required this.label, required this.duration});
  final String label;
  final Duration duration;
}

class _TimerOptionTile extends StatelessWidget {
  const _TimerOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isLight = context.isLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cyanAccent.withValues(alpha: isLight ? 0.16 : 0.14)
              : (isLight
                    ? Colors.black.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.cyanAccent.withValues(alpha: 0.6)
                : (isLight
                      ? Colors.black.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.08)),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.cyanAccent.withValues(alpha: 0.2)
                    : (isLight
                          ? Colors.black.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.08)),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.cyanAccent
                    : context.secondaryText,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.bodyLarge?.copyWith(
                      color: isSelected
                          ? (isLight ? const Color(0xFF0D9488) : Colors.white)
                          : context.primaryText,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: context.secondaryText),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.cyanAccent,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Playback Speed Bottom Sheet
// ---------------------------------------------------------------------------

class PlaybackSpeedSheet extends ConsumerWidget {
  const PlaybackSpeedSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final tt = Theme.of(context).textTheme;
    final isLight = context.isLight;

    final speeds = [
      (0.75, '0.75x', 'Slower tempo'),
      (1.0, '1.0x', 'Normal speed'),
      (1.25, '1.25x', 'Slightly faster'),
      (1.5, '1.5x', 'Fast tempo'),
      (2.0, '2.0x', 'Double speed'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.96)
            : AppColors.surface.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.7),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.purpleAccent.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.speed_rounded,
                      size: 18,
                      color: AppColors.purpleAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PLAYBACK SPEED',
                    style: tt.titleMedium?.copyWith(
                      color: context.primaryText,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: context.secondaryText),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Options
          for (final (speed, label, desc) in speeds) ...[
            Builder(
              builder: (context) {
                final isSelected =
                    (playerState.playbackSpeed - speed).abs() < 0.01;
                return InkWell(
                  onTap: () {
                    controller.setPlaybackSpeed(speed);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.purpleAccent.withValues(
                              alpha: isLight ? 0.16 : 0.16,
                            )
                          : (isLight
                                ? Colors.black.withValues(alpha: 0.03)
                                : Colors.white.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.purpleAccent.withValues(alpha: 0.7)
                            : (isLight
                                  ? Colors.black.withValues(alpha: 0.06)
                                  : Colors.white.withValues(alpha: 0.08)),
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isLight
                                ? (isSelected
                                      ? AppColors.purpleAccent.withValues(
                                          alpha: 0.15,
                                        )
                                      : Colors.black.withValues(alpha: 0.05))
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: tt.labelMedium?.copyWith(
                              color: isSelected
                                  ? (isLight
                                        ? AppColors.purpleAccent
                                        : AppColors.cyanAccent)
                                  : context.primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            desc,
                            style: tt.bodyMedium?.copyWith(
                              color: context.secondaryText,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.purpleAccent,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Song Information Modal Sheet
// ---------------------------------------------------------------------------

class TrackInfoSheet extends ConsumerWidget {
  const TrackInfoSheet({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final isLight = context.isLight;

    final songId =
        (track.source == TrackSource.local && track.id.startsWith('local_'))
        ? int.tryParse(track.id.replaceFirst('local_', ''))
        : null;

    final songAsync = songId != null
        ? ref.watch(songByIdProvider(songId))
        : null;
    final song = songAsync?.asData?.value;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.98)
            : AppColors.surface.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.7),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cyanAccent.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.cyanAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'TRACK INFORMATION',
                    style: tt.titleMedium?.copyWith(
                      color: context.primaryText,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: context.secondaryText),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Title',
                  value: track.title,
                  icon: Icons.music_note_rounded,
                ),
                Divider(
                  height: 18,
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.06)
                      : Colors.white10,
                ),
                _InfoRow(
                  label: 'Artist',
                  value: track.artist,
                  icon: Icons.person_rounded,
                ),
                Divider(
                  height: 18,
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.06)
                      : Colors.white10,
                ),
                _InfoRow(
                  label: 'Album',
                  value: track.album ?? 'Unknown Album',
                  icon: Icons.album_rounded,
                ),
                Divider(
                  height: 18,
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.06)
                      : Colors.white10,
                ),
                _InfoRow(
                  label: 'Duration',
                  value: formatDuration(track.durationMs),
                  icon: Icons.timelapse_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Playback Statistics & Storage Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Play Count',
                  value: '${song?.playCount ?? 0} plays',
                  icon: Icons.bar_chart_rounded,
                  accentColor: AppColors.cyanAccent,
                ),
                Divider(
                  height: 18,
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.06)
                      : Colors.white10,
                ),
                _InfoRow(
                  label: 'Last Played',
                  value: song?.lastPlayedAt != null
                      ? formatDateTime(song!.lastPlayedAt!)
                      : 'Not played yet',
                  icon: Icons.history_rounded,
                  accentColor: AppColors.purpleAccent,
                ),
                Divider(
                  height: 18,
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.06)
                      : Colors.white10,
                ),
                _InfoRow(
                  label: 'Source',
                  value: track.source == TrackSource.local
                      ? 'Local Storage (Audio File)'
                      : 'Streaming Media',
                  icon: track.source == TrackSource.local
                      ? Icons.folder_rounded
                      : Icons.cloud_rounded,
                ),
                Divider(
                  height: 18,
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.06)
                      : Colors.white10,
                ),
                _InfoRow(
                  label: 'File Path',
                  value: song?.filePath ?? track.uri,
                  icon: Icons.insert_drive_file_outlined,
                  isSelectable: true,
                ),
              ],
            ),
          ),
          if (song != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  showEditSongDialog(context: context, song: song);
                },
                icon: const Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: AppColors.cyanAccent,
                ),
                label: const Text(
                  'Edit Tags',
                  style: TextStyle(
                    color: AppColors.cyanAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.cyanAccent.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.isSelectable = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final bool isSelectable;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: accentColor ?? context.secondaryText),
        const SizedBox(width: 12),
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: context.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: isSelectable
              ? SelectableText(
                  value,
                  style: tt.bodySmall?.copyWith(
                    color: context.primaryText,
                    fontFamily: 'monospace',
                  ),
                )
              : Text(
                  value,
                  style: tt.bodyMedium?.copyWith(
                    color: accentColor ?? context.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compact Audio Tools Action Row (embedded inside NowPlayingScreen)
// ---------------------------------------------------------------------------

class AudioToolsActionRow extends ConsumerWidget {
  const AudioToolsActionRow({
    super.key,
    required this.playerState,
    required this.track,
    required this.onOpenQueue,
    this.isLyricsActive = false,
    this.onToggleLyrics,
  });

  final PlayerState playerState;
  final Track track;
  final VoidCallback onOpenQueue;
  final bool isLyricsActive;
  final VoidCallback? onToggleLyrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTimerActive = playerState.isSleepTimerActive;
    final remainingTimer = playerState.remainingSleepDuration;
    final speed = playerState.playbackSpeed;
    final isLight = context.isLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLight
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: isLight ? AppTheme.lightCardShadow : null,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Sleep Timer Quick Button
            _ToolButton(
              icon: isTimerActive
                  ? Icons.bedtime_rounded
                  : Icons.bedtime_outlined,
              label: isTimerActive
                  ? (playerState.stopAtEndOfTrack
                        ? 'End Track'
                        : formatCountdown(remainingTimer ?? Duration.zero))
                  : 'Timer',
              isActive: isTimerActive,
              activeColor: AppColors.cyanAccent,
              onTap: () => showSleepTimerSheet(context),
              tooltip: isTimerActive ? 'Sleep Timer Active' : 'Set Sleep Timer',
            ),
            const SizedBox(width: 8),

            // 2. Playback Speed Quick Button
            _ToolButton(
              icon: Icons.speed_rounded,
              label: '${speed}x',
              isActive: (speed - 1.0).abs() > 0.01,
              activeColor: AppColors.purpleAccent,
              onTap: () => showPlaybackSpeedSheet(context),
              tooltip: 'Playback Speed (${speed}x)',
            ),
            const SizedBox(width: 8),

            // 3. Hardware Equalizer Quick Button
            _ToolButton(
              icon: Icons.tune_rounded,
              label: 'EQ',
              isActive: playerState.equalizerEnabled,
              activeColor: AppColors.cyanAccent,
              onTap: () => showEqualizerSheet(context),
              tooltip: playerState.equalizerEnabled
                  ? 'Equalizer Active (${playerState.equalizerPreset.displayName})'
                  : 'Audio Equalizer',
            ),
            const SizedBox(width: 8),

            // 4. Lyrics Quick Button
            _ToolButton(
              icon: Icons.lyrics_rounded,
              label: 'Lyrics',
              isActive: isLyricsActive,
              activeColor: AppColors.cyanAccent,
              onTap: onToggleLyrics ?? () {},
              tooltip: isLyricsActive ? 'Hide Lyrics' : 'Show Synced Lyrics',
            ),
            const SizedBox(width: 8),

            // 5. Up Next Queue Quick Button
            _ToolButton(
              icon: Icons.queue_music_rounded,
              label: 'Queue',
              isActive: false,
              activeColor: isLight ? context.primaryText : Colors.white70,
              onTap: onOpenQueue,
              tooltip: 'Up Next Queue (${playerState.queue.length})',
            ),
            const SizedBox(width: 8),

            // 6. Song Info Quick Button
            _ToolButton(
              icon: Icons.info_outline_rounded,
              label: 'Info',
              isActive: false,
              activeColor: isLight ? context.primaryText : Colors.white70,
              onTap: () => showTrackInfoSheet(context, track),
              tooltip: 'Song Information',
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: isLight ? 0.18 : 0.18)
                : (isLight
                      ? Colors.black.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? activeColor.withValues(alpha: 0.5)
                  : (isLight
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive
                    ? activeColor
                    : (isLight
                          ? context.secondaryText
                          : Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive
                      ? (isLight ? const Color(0xFF0F172A) : activeColor)
                      : context.primaryText,
                  letterSpacing: 0.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
