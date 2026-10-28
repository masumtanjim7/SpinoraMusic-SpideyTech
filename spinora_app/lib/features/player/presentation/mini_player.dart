import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/lucid_pressable_card.dart';
import '../../../shared/glass_card.dart';
import '../../library/presentation/widgets/song_artwork.dart';
import '../application/player_controller.dart';
import 'now_playing_screen.dart';

/// Floating glassmorphic mini-player bar anchored to the bottom of the screen.
///
/// Automatically hides when no track is loaded in [PlayerController].
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.bottomPadding = 16.0});

  final double bottomPadding;

  void _openNowPlaying(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const NowPlayingScreen(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerControllerProvider.select((s) => s.currentTrack),
    );
    if (track == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = ref.watch(
      playerControllerProvider.select((s) => s.isPlaying),
    );
    final isBuffering = ref.watch(
      playerControllerProvider.select((s) => s.isBuffering),
    );
    final canSkipNext = ref.watch(
      playerControllerProvider.select(
        (s) => s.hasNext || (s.isShuffled && s.queue.length > 1),
      ),
    );
    final durationMs = ref.watch(
      playerControllerProvider.select((s) => s.duration.inMilliseconds),
    );

    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      child: LucidPressableCard(
        borderRadius: 24,
        onTap: () => _openNowPlaying(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: AppColors.purpleAccent.withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : AppTheme.lightCardShadow,
          ),
          child: GlassCard(
            borderRadius: BorderRadius.circular(24),
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Subtle progress indicator line along the top curved edge
                // Isolated into a lightweight ValueListenableBuilder so only this
                // 3px bar repaints on position ticks.
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: SizedBox(
                    height: 3,
                    child: _MiniPlayerProgressBar(
                      durationMs: durationMs > 0 ? durationMs : track.durationMs,
                      isDark: isDark,
                    ),
                  ),
                ),

                // Track details and quick player controls
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Square rounded album artwork thumbnail
                      SongArtwork.fromTrack(
                        track,
                        size: 46,
                        borderRadius: BorderRadius.circular(12),
                        isCurrent: isPlaying,
                        iconSize: 24,
                        heroTag: 'mini_player_art_${track.id}',
                      ),
                      const SizedBox(width: 12),

                      // Track Title and Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F111A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.65)
                                    : const Color(0xFF5C6275),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Previous Button
                      IconButton(
                        onPressed: () => ref
                            .read(playerControllerProvider.notifier)
                            .previous(),
                        icon: const Icon(Icons.skip_previous_rounded),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF0F111A).withValues(alpha: 0.85),
                        iconSize: 22,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Previous',
                      ),

                      // Play / Pause glowing gradient button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isDark
                              ? AppColors.purpleGradient
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF7C3AED),
                                    Color(0xFFE63946),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isDark
                                          ? AppColors.purpleAccent
                                          : const Color(0xFF7C3AED))
                                      .withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => ref
                              .read(playerControllerProvider.notifier)
                              .togglePlayPause(),
                          icon: isBuffering
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                          tooltip: isPlaying ? 'Pause' : 'Play',
                        ),
                      ),

                      // Next Button
                      IconButton(
                        onPressed: canSkipNext
                            ? () => ref
                                  .read(playerControllerProvider.notifier)
                                  .next()
                            : null,
                        icon: const Icon(Icons.skip_next_rounded),
                        color: canSkipNext
                            ? (isDark
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : const Color(0xFF0F111A)
                                        .withValues(alpha: 0.85))
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : const Color(0xFF5C6275)
                                        .withValues(alpha: 0.25)),
                        iconSize: 22,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Next',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerProgressBar extends ConsumerWidget {
  const _MiniPlayerProgressBar({
    required this.durationMs,
    required this.isDark,
  });

  final int durationMs;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posListenable = ref.watch(playerPositionListenableProvider);
    final fallbackPositionMs = ref.watch(
      playerControllerProvider.select((s) => s.position.inMilliseconds),
    );

    return ValueListenableBuilder<Duration>(
      valueListenable: posListenable,
      builder: (context, pos, _) {
        final effectivePosMs = pos.inMilliseconds > 0
            ? pos.inMilliseconds
            : fallbackPositionMs;
        final ratio = durationMs > 0
            ? (effectivePosMs / durationMs).clamp(0.0, 1.0)
            : 0.0;

        return LinearProgressIndicator(
          value: ratio,
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          valueColor: AlwaysStoppedAnimation<Color>(
            isDark ? AppColors.cyanAccent : const Color(0xFF7C3AED),
          ),
        );
      },
    );
  }
}
