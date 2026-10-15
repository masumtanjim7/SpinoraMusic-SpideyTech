import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/glass_card.dart';
import '../../library/presentation/widgets/song_artwork.dart';
import '../application/player_controller.dart';
import 'now_playing_screen.dart';

/// Floating glassmorphic mini-player bar anchored to the bottom of the screen.
///
/// Automatically hides when no track is loaded in [PlayerController].
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({
    super.key,
    this.bottomPadding = 16.0,
  });

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

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      child: GestureDetector(
        onTap: () => _openNowPlaying(context),
        behavior: HitTestBehavior.opaque,
        child: GlassCard(
          borderRadius: BorderRadius.circular(20),
          padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Neon progress indicator line along the top of the card
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: playerState.progressRatio,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.cyanAccent,
                  ),
                ),
              ),
            ),

            // Track details and player controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  // Album Art Thumbnail
                  SongArtwork.fromTrack(
                    track,
                    size: 44,
                    borderRadius: BorderRadius.circular(10),
                    isCurrent: playerState.isPlaying,
                    iconSize: 22,
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
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Previous Button
                  IconButton(
                    onPressed: () =>
                        ref.read(playerControllerProvider.notifier).previous(),
                    icon: const Icon(Icons.skip_previous_rounded),
                    color: Colors.white.withValues(alpha: 0.8),
                    iconSize: 24,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Previous',
                  ),

                  // Play / Pause Button with buffering spinner
                  IconButton.filled(
                    onPressed: () => ref
                        .read(playerControllerProvider.notifier)
                        .togglePlayPause(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.purpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                    ),
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
                            size: 24,
                          ),
                    tooltip: playerState.isPlaying ? 'Pause' : 'Play',
                  ),

                  // Next Button
                  IconButton(
                    onPressed: playerState.hasNext
                        ? () =>
                            ref.read(playerControllerProvider.notifier).next()
                        : null,
                    icon: const Icon(Icons.skip_next_rounded),
                    color: playerState.hasNext
                        ? Colors.white.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.25),
                    iconSize: 24,
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
    );
  }
}
