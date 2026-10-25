import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme.dart';
import '../../../core/audio/track.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/glass_card.dart';
import '../../library/presentation/widgets/song_artwork.dart';
import '../application/player_controller.dart';
import 'widgets/audio_tools_sheets.dart';
import 'widgets/lyrics_view.dart';
import 'widgets/up_next_queue_sheet.dart';

/// Full-screen glassmorphic Now Playing modal sheet.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  double? _dragPosition;
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerControllerProvider);
    final track = playerState.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final tt = Theme.of(context).textTheme;
    final isLight = context.isLight;
    final totalDurationMs = playerState.duration.inMilliseconds;
    final currentPositionMs =
        _dragPosition?.toInt() ??
        playerState.position.inMilliseconds.clamp(0, totalDurationMs);

    final screenSize = MediaQuery.of(context).size;
    final shortest = screenSize.height < screenSize.width
        ? screenSize.height
        : screenSize.width;
    final artSize = (shortest * 0.65).clamp(160.0, 320.0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Dual ambient glow blobs behind artwork
          Positioned(
            top: 60,
            left: screenSize.width * 0.05,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.purpleAccent.withValues(
                      alpha: isLight
                          ? (playerState.isPlaying ? 0.22 : 0.12)
                          : (playerState.isPlaying ? 0.45 : 0.25),
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isLight ? AppColors.lightAccent : AppColors.cyanAccent)
                        .withValues(
                          alpha: isLight
                              ? (playerState.isPlaying ? 0.18 : 0.08)
                              : (playerState.isPlaying ? 0.35 : 0.18),
                        ),
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
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: context.primaryText,
                                  size: 32,
                                ),
                                tooltip: 'Dismiss',
                              ),
                              Text(
                                'NOW PLAYING',
                                style: tt.labelMedium?.copyWith(
                                  color: context.secondaryText,
                                  letterSpacing: 2.5,
                                  fontWeight: FontWeight.w700,
                                ),
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
                                      ? Colors.pinkAccent
                                      : context.secondaryText,
                                  size: 26,
                                ),
                                tooltip: track.isFavorite
                                    ? 'Remove from Favorites'
                                    : 'Add to Favorites',
                              ),
                            ],
                          ),

                          SizedBox(height: _showLyrics ? 8 : 12),

                          // Centerpiece: Deeper layered glassmorphic artwork card or Live scrolling lyrics card
                          Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              width: _showLyrics
                                  ? constraints.maxWidth
                                  : artSize,
                              height: _showLyrics
                                  ? (screenSize.height * 0.42).clamp(
                                      340.0,
                                      380.0,
                                    )
                                  : artSize,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(
                                        begin: 0.95,
                                        end: 1.0,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _showLyrics
                                    ? LiveLyricsCard(
                                        key: const ValueKey('live_lyrics_card'),
                                        track: track,
                                        width: constraints.maxWidth,
                                        height: (screenSize.height * 0.42)
                                            .clamp(340.0, 380.0),
                                        onClose: () =>
                                            setState(() => _showLyrics = false),
                                      )
                                    : GestureDetector(
                                        key: const ValueKey('artwork_card'),
                                        onTap: () =>
                                            setState(() => _showLyrics = true),
                                        child: AnimatedScale(
                                          scale: playerState.isPlaying
                                              ? 1.02
                                              : 0.96,
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(36),
                                              border: Border.all(
                                                color: isLight
                                                    ? Colors.white
                                                    : Colors.white.withValues(
                                                        alpha:
                                                            playerState
                                                                .isPlaying
                                                            ? 0.22
                                                            : 0.10,
                                                      ),
                                                width: 1.5,
                                              ),
                                              boxShadow: isLight
                                                  ? [
                                                      BoxShadow(
                                                        color: AppColors
                                                            .purpleAccent
                                                            .withValues(
                                                              alpha: 0.18,
                                                            ),
                                                        blurRadius: 36,
                                                        spreadRadius: 1,
                                                      ),
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.05,
                                                            ),
                                                        blurRadius: 20,
                                                        offset: const Offset(
                                                          0,
                                                          8,
                                                        ),
                                                      ),
                                                    ]
                                                  : [
                                                      BoxShadow(
                                                        color: AppColors
                                                            .purpleAccent
                                                            .withValues(
                                                              alpha:
                                                                  playerState
                                                                      .isPlaying
                                                                  ? 0.40
                                                                  : 0.18,
                                                            ),
                                                        blurRadius: 44,
                                                        spreadRadius: 2,
                                                      ),
                                                      BoxShadow(
                                                        color: AppColors
                                                            .cyanAccent
                                                            .withValues(
                                                              alpha:
                                                                  playerState
                                                                      .isPlaying
                                                                  ? 0.25
                                                                  : 0.10,
                                                            ),
                                                        blurRadius: 28,
                                                        offset: const Offset(
                                                          0,
                                                          10,
                                                        ),
                                                      ),
                                                    ],
                                            ),
                                            child: GlassCard(
                                              width: artSize,
                                              height: artSize,
                                              borderRadius:
                                                  BorderRadius.circular(32),
                                              padding: const EdgeInsets.all(12),
                                              child: SongArtwork.fromTrack(
                                                track,
                                                width: double.infinity,
                                                height: double.infinity,
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                                isCurrent:
                                                    playerState.isPlaying,
                                                iconSize: 72,
                                                heroTag:
                                                    'now_playing_art_${track.id}',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          SizedBox(height: _showLyrics ? 12 : 20),

                          // Track Info & Inline Status Badges
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.headlineSmall?.copyWith(
                                    color: context.primaryText,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${track.artist}${track.album != null ? ' • ${track.album}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodyMedium?.copyWith(
                                    color: context.secondaryText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Inline status badge row: Source/Format, Favorite status, and Queue position
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  // Source / Format pill badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLight
                                          ? Colors.black.withValues(alpha: 0.04)
                                          : Colors.white.withValues(
                                              alpha: 0.07,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isLight
                                            ? Colors.black.withValues(
                                                alpha: 0.08,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          track.source == TrackSource.local
                                              ? Icons.music_note_rounded
                                              : Icons.cloud_rounded,
                                          size: 13,
                                          color: context.primaryAccent,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          track.source == TrackSource.local
                                              ? 'LOCAL AUDIO'
                                              : 'STREAMING',
                                          style: tt.labelSmall?.copyWith(
                                            color: context.secondaryText,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Interactive Favorite pill badge
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => ref
                                        .read(playerControllerProvider.notifier)
                                        .toggleFavorite(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: track.isFavorite
                                            ? Colors.pinkAccent.withValues(
                                                alpha: isLight ? 0.12 : 0.18,
                                              )
                                            : (isLight
                                                  ? Colors.black.withValues(
                                                      alpha: 0.04,
                                                    )
                                                  : Colors.white.withValues(
                                                      alpha: 0.06,
                                                    )),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: track.isFavorite
                                              ? Colors.pinkAccent.withValues(
                                                  alpha: 0.45,
                                                )
                                              : (isLight
                                                    ? Colors.black.withValues(
                                                        alpha: 0.08,
                                                      )
                                                    : Colors.white.withValues(
                                                        alpha: 0.12,
                                                      )),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            track.isFavorite
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            size: 13,
                                            color: track.isFavorite
                                                ? Colors.pinkAccent
                                                : context.secondaryText,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            track.isFavorite
                                                ? 'FAVORITE'
                                                : 'ADD FAVORITE',
                                            style: tt.labelSmall?.copyWith(
                                              color: track.isFavorite
                                                  ? Colors.pinkAccent
                                                  : context.secondaryText,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.8,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  if (playerState.queue.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLight
                                            ? Colors.black.withValues(
                                                alpha: 0.04,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.06,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isLight
                                              ? Colors.black.withValues(
                                                  alpha: 0.08,
                                                )
                                              : Colors.white.withValues(
                                                  alpha: 0.12,
                                                ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.queue_music_rounded,
                                            size: 13,
                                            color: AppColors.purpleAccent,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'TRACK ${playerState.currentIndex + 1}/${playerState.queue.length}',
                                            style: tt.labelSmall?.copyWith(
                                              color: context.secondaryText,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),

                          SizedBox(height: _showLyrics ? 8 : 14),

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
                                  activeTrackColor: context.primaryAccent,
                                  inactiveTrackColor: isLight
                                      ? Colors.black.withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.12),
                                  thumbColor: context.primaryAccent,
                                  overlayColor: context.primaryAccent
                                      .withValues(alpha: 0.2),
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
                                        .seek(
                                          Duration(milliseconds: val.toInt()),
                                        );
                                    setState(() {
                                      _dragPosition = null;
                                    });
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatDuration(currentPositionMs),
                                      style: tt.labelSmall?.copyWith(
                                        color: context.secondaryText,
                                      ),
                                    ),
                                    Text(
                                      formatDuration(totalDurationMs),
                                      style: tt.labelSmall?.copyWith(
                                        color: context.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: _showLyrics ? 8 : 12),

                          // Refined Pill-Shaped Transport Control Bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(44),
                              color: context.glassTileBg,
                              border: Border.all(
                                color: context.glassTileBorder,
                                width: 1,
                              ),
                              boxShadow: isLight
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Shuffle Button
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  decoration: BoxDecoration(
                                    color: playerState.isShuffleEnabled
                                        ? context.primaryAccent.withValues(
                                            alpha: isLight ? 0.12 : 0.18,
                                          )
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: playerState.isShuffleEnabled
                                          ? context.primaryAccent.withValues(
                                              alpha: isLight ? 0.35 : 0.45,
                                            )
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                    boxShadow: playerState.isShuffleEnabled
                                        ? [
                                            BoxShadow(
                                              color: context.primaryAccent
                                                  .withValues(
                                                    alpha: isLight ? 0.2 : 0.3,
                                                  ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: IconButton(
                                    onPressed: () => ref
                                        .read(playerControllerProvider.notifier)
                                        .toggleShuffle(),
                                    icon: Icon(
                                      Icons.shuffle_rounded,
                                      color: playerState.isShuffleEnabled
                                          ? context.primaryAccent
                                          : context.secondaryText,
                                      size: 22,
                                    ),
                                    tooltip: playerState.isShuffleEnabled
                                        ? 'Shuffle: On'
                                        : 'Shuffle: Off',
                                  ),
                                ),

                                // Previous Track
                                IconButton(
                                  onPressed: () => ref
                                      .read(playerControllerProvider.notifier)
                                      .previous(),
                                  icon: Icon(
                                    Icons.skip_previous_rounded,
                                    color: context.primaryText,
                                    size: 32,
                                  ),
                                  tooltip: 'Previous Track',
                                ),

                                // Prominent Glowing Play / Pause Button
                                Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: isLight
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFF7C3AED),
                                              Color(0xFFE63946),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : AppColors.purpleGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (isLight
                                                    ? const Color(0xFF7C3AED)
                                                    : AppColors.purpleAccent)
                                                .withValues(
                                                  alpha: isLight ? 0.35 : 0.6,
                                                ),
                                        blurRadius: 22,
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
                                            width: 24,
                                            height: 24,
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
                                            size: 36,
                                          ),
                                    tooltip: playerState.isPlaying
                                        ? 'Pause'
                                        : 'Play',
                                  ),
                                ),

                                // Next Track
                                IconButton(
                                  onPressed: () => ref
                                      .read(playerControllerProvider.notifier)
                                      .next(),
                                  icon: Icon(
                                    Icons.skip_next_rounded,
                                    color:
                                        playerState.hasNext ||
                                            playerState.loopMode == LoopMode.all
                                        ? context.primaryText
                                        : context.secondaryText.withValues(
                                            alpha: 0.3,
                                          ),
                                    size: 32,
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
                                        ? context.primaryAccent
                                        : context.secondaryText,
                                    size: 22,
                                  ),
                                  tooltip:
                                      'Repeat: ${playerState.loopMode.name.toUpperCase()}',
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: _showLyrics ? 10 : 16),

                          // Compact Glassmorphic Audio Tools Action Row (Sleep Timer, Playback Speed, Lyrics, Queue, Info)
                          AudioToolsActionRow(
                            playerState: playerState,
                            track: track,
                            isLyricsActive: _showLyrics,
                            onToggleLyrics: () =>
                                setState(() => _showLyrics = !_showLyrics),
                            onOpenQueue: () {
                              showModalBottomSheet<void>(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => const UpNextQueueSheet(),
                              );
                            },
                          ),

                          SizedBox(height: _showLyrics ? 10 : 16),
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
