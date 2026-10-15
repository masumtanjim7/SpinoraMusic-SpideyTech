import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/glass_card.dart';
import '../../library/presentation/widgets/song_artwork.dart';
import '../application/player_controller.dart';
import 'widgets/up_next_queue_sheet.dart';

/// Full-screen dark glassmorphic Now Playing modal sheet.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  double? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerControllerProvider);
    final track = playerState.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final tt = Theme.of(context).textTheme;
    final totalDurationMs = playerState.duration.inMilliseconds;
    final currentPositionMs = _dragPosition?.toInt() ??
        playerState.position.inMilliseconds.clamp(0, totalDurationMs);

    final screenSize = MediaQuery.of(context).size;
    final shortest = screenSize.height < screenSize.width
        ? screenSize.height
        : screenSize.width;
    final artSize = (shortest * 0.65).clamp(160.0, 320.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient neon radial glows behind artwork
          Positioned(
            top: 100,
            left: screenSize.width * 0.15,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.purpleAccent.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 220,
            right: 20,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.cyanAccent.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Screen Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(height: 8),

                          // Top bar: Dismiss chevron, Title, Favorite toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                tooltip: 'Dismiss',
                              ),
                              Text(
                                'NOW PLAYING',
                                style: tt.labelMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  letterSpacing: 2.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      showModalBottomSheet<void>(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        isScrollControlled: true,
                                        builder: (context) =>
                                            const UpNextQueueSheet(),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.queue_music_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    tooltip: 'Up Next Queue',
                                  ),
                                  IconButton(
                                    onPressed: () => ref
                                        .read(playerControllerProvider.notifier)
                                        .toggleFavorite(),
                                    icon: Icon(
                                      track.isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: track.isFavorite
                                          ? AppColors.cyanAccent
                                          : Colors.white.withValues(alpha: 0.7),
                                      size: 26,
                                    ),
                                    tooltip: track.isFavorite
                                        ? 'Remove from Favorites'
                                        : 'Add to Favorites',
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Centerpiece: Large glassmorphic artwork card
                          Center(
                            child: AnimatedScale(
                              scale: playerState.isPlaying ? 1.02 : 0.96,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.purpleAccent.withValues(
                                        alpha: playerState.isPlaying ? 0.35 : 0.15,
                                      ),
                                      blurRadius: 40,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: GlassCard(
                                  width: artSize,
                                  height: artSize,
                                  borderRadius: BorderRadius.circular(32),
                                  padding: const EdgeInsets.all(12),
                                  child: SongArtwork.fromTrack(
                                    track,
                                    width: double.infinity,
                                    height: double.infinity,
                                    borderRadius: BorderRadius.circular(24),
                                    isCurrent: playerState.isPlaying,
                                    iconSize: 72,
                                    heroTag: 'now_playing_art_${track.id}',
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Track Info: Title and Artist
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${track.artist}${track.album != null ? ' • ${track.album}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Interactive Seek Slider & Timestamps
                          Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14,
                                  ),
                                  activeTrackColor: AppColors.cyanAccent,
                                  inactiveTrackColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  thumbColor: AppColors.cyanAccent,
                                  overlayColor:
                                      AppColors.cyanAccent.withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: totalDurationMs > 0
                                      ? currentPositionMs
                                          .clamp(0, totalDurationMs)
                                          .toDouble()
                                      : 0.0,
                                  max: totalDurationMs > 0
                                      ? totalDurationMs.toDouble()
                                      : 1.0,
                                  onChanged: (val) {
                                    setState(() {
                                      _dragPosition = val;
                                    });
                                  },
                                  onChangeEnd: (val) {
                                    ref
                                        .read(playerControllerProvider.notifier)
                                        .seek(Duration(milliseconds: val.toInt()));
                                    setState(() {
                                      _dragPosition = null;
                                    });
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatDuration(currentPositionMs),
                                      style: tt.labelSmall?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    Text(
                                      formatDuration(totalDurationMs),
                                      style: tt.labelSmall?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Transport Controls: Shuffle, Prev, Play/Pause, Next, Repeat
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Shuffle Button
                              IconButton(
                                onPressed: () => ref
                                    .read(playerControllerProvider.notifier)
                                    .toggleShuffle(),
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  color: playerState.isShuffled
                                      ? AppColors.cyanAccent
                                      : Colors.white.withValues(alpha: 0.45),
                                  size: 24,
                                ),
                                tooltip: playerState.isShuffled
                                    ? 'Shuffle: On'
                                    : 'Shuffle: Off',
                              ),

                              // Previous Track
                              IconButton(
                                onPressed: () => ref
                                    .read(playerControllerProvider.notifier)
                                    .previous(),
                                icon: const Icon(
                                  Icons.skip_previous_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                                tooltip: 'Previous Track',
                              ),

                              // Prominent Glowing Play / Pause Button
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.purpleGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.purpleAccent
                                          .withValues(alpha: 0.5),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: () => ref
                                      .read(playerControllerProvider.notifier)
                                      .togglePlayPause(),
                                  icon: playerState.isBuffering
                                      ? const SizedBox(
                                          width: 26,
                                          height: 26,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          playerState.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                  tooltip:
                                      playerState.isPlaying ? 'Pause' : 'Play',
                                ),
                              ),

                              // Next Track
                              IconButton(
                                onPressed: () => ref
                                    .read(playerControllerProvider.notifier)
                                    .next(),
                                icon: Icon(
                                  Icons.skip_next_rounded,
                                  color: playerState.hasNext ||
                                          playerState.loopMode == LoopMode.all
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                                  size: 36,
                                ),
                                tooltip: 'Next Track',
                              ),

                              // Repeat Mode Cycle Button
                              IconButton(
                                onPressed: () => ref
                                    .read(playerControllerProvider.notifier)
                                    .cycleLoopMode(),
                                icon: Icon(
                                  playerState.loopMode == LoopMode.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  color: playerState.loopMode != LoopMode.off
                                      ? AppColors.cyanAccent
                                      : Colors.white.withValues(alpha: 0.45),
                                  size: 24,
                                ),
                                tooltip:
                                    'Repeat: ${playerState.loopMode.name.toUpperCase()}',
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
