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
    final playerState = ref.watch(playerControllerProvider);
    final track = playerState.currentTrack;

    if (!playerState.hasTrack || track == null) {
      return const SizedBox.shrink();
    }

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
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: playerState.progressRatio,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? AppColors.cyanAccent : const Color(0xFF7C3AED),
                      ),
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
                        isCurrent: playerState.isPlaying,
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
                          icon: playerState.isBuffering
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  playerState.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                          tooltip: playerState.isPlaying ? 'Pause' : 'Play',
                        ),
                      ),

                      // Next Button
                      IconButton(
                        onPressed: playerState.hasNext
                            ? () => ref
                                  .read(playerControllerProvider.notifier)
                                  .next()
                            : null,
                        icon: const Icon(Icons.skip_next_rounded),
                        color: playerState.hasNext
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
