import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../library/presentation/widgets/song_artwork.dart';
import '../../application/player_controller.dart';

/// Dark glassmorphic modal sheet displaying the active playback queue.
class UpNextQueueSheet extends ConsumerWidget {
  const UpNextQueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final queue = playerState.queue;
    final currentIndex = playerState.currentIndex;
    final tt = Theme.of(context).textTheme;
    final isLight = context.isLight;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.96)
            : const Color(0xFF13111C).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.6),
            blurRadius: 32,
            spreadRadius: 6,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pill drag handle
            Center(
              child: Container(
                width: 36,
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

            // Header: Title, Count Badge, and Close Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cyanAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.cyanAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.queue_music_rounded,
                    color: AppColors.cyanAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Up Next Queue',
                  style: tt.titleMedium?.copyWith(
                    color: context.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${queue.length}',
                    style: TextStyle(
                      color: isLight
                          ? AppColors.purpleAccent
                          : AppColors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: context.secondaryText,
                    size: 26,
                  ),
                  tooltip: 'Close',
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.08),
              height: 1,
            ),
            const SizedBox(height: 8),

            // Queue List or Empty State
            if (queue.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        size: 44,
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Playback Queue is Empty',
                        style: tt.titleSmall?.copyWith(
                          color: context.primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Play a song or playlist from your music library.',
                        style: tt.bodySmall?.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: queue.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    final isCurrent = index == currentIndex;

                    return Dismissible(
                      key: Key('queue_track_${track.id}_$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      onDismissed: (_) {
                        ref
                            .read(playerControllerProvider.notifier)
                            .removeFromQueue(index);
                      },
                      child: Material(
                        color: isCurrent
                            ? (isLight
                                  ? AppColors.purpleAccent.withValues(
                                      alpha: 0.12,
                                    )
                                  : AppColors.purpleAccent.withValues(
                                      alpha: 0.16,
                                    ))
                            : (isLight
                                  ? Colors.black.withValues(alpha: 0.02)
                                  : Colors.white.withValues(alpha: 0.04)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isCurrent
                                ? (isLight
                                      ? AppColors.purpleAccent.withValues(
                                          alpha: 0.45,
                                        )
                                      : AppColors.cyanAccent.withValues(
                                          alpha: 0.5,
                                        ))
                                : (isLight
                                      ? Colors.black.withValues(alpha: 0.06)
                                      : Colors.white.withValues(alpha: 0.06)),
                            width: isCurrent ? 1.4 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            ref
                                .read(playerControllerProvider.notifier)
                                .jumpToIndex(index);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                SongArtwork.fromTrack(
                                  track,
                                  size: 44,
                                  borderRadius: BorderRadius.circular(10),
                                  isCurrent: isCurrent,
                                  iconSize: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (isCurrent) ...[
                                            Container(
                                              margin: const EdgeInsets.only(
                                                right: 6,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    (isLight
                                                            ? AppColors
                                                                  .purpleAccent
                                                            : AppColors
                                                                  .cyanAccent)
                                                        .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'NOW',
                                                style: TextStyle(
                                                  color: isLight
                                                      ? AppColors.purpleAccent
                                                      : AppColors.cyanAccent,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                          Expanded(
                                            child: Text(
                                              track.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isCurrent
                                                    ? (isLight
                                                          ? AppColors
                                                                .purpleAccent
                                                          : AppColors
                                                                .cyanAccent)
                                                    : context.primaryText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${track.artist}${track.album != null ? ' • ${track.album}' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.secondaryText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatDuration(track.durationMs),
                                  style: TextStyle(
                                    color: isCurrent
                                        ? (isLight
                                              ? AppColors.purpleAccent
                                              : AppColors.cyanAccent)
                                        : context.secondaryText,
                                    fontSize: 12,
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: context.secondaryText,
                                    size: 18,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  tooltip: 'Remove from Queue',
                                  onPressed: () {
                                    ref
                                        .read(playerControllerProvider.notifier)
                                        .removeFromQueue(index);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
