import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/track.dart';
import '../../../core/database/app_database.dart';
import '../../../features/player/application/player_controller.dart';
import '../../../features/player/presentation/mini_player.dart';
import '../../library/presentation/widgets/song_artwork.dart';
import '../application/smart_mixes_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smart Mix Detail Screen — Lucid Glass Dedicated Playlist View
// ─────────────────────────────────────────────────────────────────────────────

class SmartMixDetailScreen extends ConsumerWidget {
  const SmartMixDetailScreen({super.key, required this.mix});

  final SmartMixInfo mix;

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTotalDuration(List<Song> songs) {
    final totalMs = songs.fold<int>(0, (sum, s) => sum + s.duration);
    final d = Duration(milliseconds: totalMs);
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  void _playAll(WidgetRef ref) {
    if (mix.songs.isEmpty) return;
    final tracks = mix.songs.map(Track.fromSong).toList();
    ref
        .read(playerControllerProvider.notifier)
        .playTrack(tracks.first, queue: tracks);
  }

  void _shufflePlay(WidgetRef ref) {
    if (mix.songs.isEmpty) return;
    ref
        .read(playerControllerProvider.notifier)
        .playPlaylist(mix.songs, shuffle: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final hasMiniplayer = playerState.hasTrack;
    final currentTrackId = playerState.currentTrack?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background ambient gradient blobs
          _buildAmbientBlobs(context),

          // Main scroll view
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Dynamic Artwork Banner & App Bar
              SliverAppBar(
                expandedHeight: 290,
                pinned: true,
                elevation: 0,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF08070F).withValues(alpha: 0.65)
                            : Colors.white.withValues(alpha: 0.85),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.9),
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : const Color(0xFF0F111A),
                        size: 16,
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Full-bleed artwork banner
                      SmartMixArtworkView(
                        mix: mix,
                        borderRadius: 0,
                        showVignette: true,
                      ),

                      // Frosted glass metadata bottom banner
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Pill badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: mix.accentColor.withValues(alpha: 0.25),
                                border: Border.all(
                                  color: mix.accentColor.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    mix.icon,
                                    color: mix.accentColor,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'SMART PICK',
                                    style: TextStyle(
                                      color: mix.accentColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Title
                            Text(
                              mix.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Subtitle
                            Text(
                              mix.subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Info badges row
                            Row(
                              children: [
                                _InfoChip(
                                  icon: Icons.music_note_rounded,
                                  label: '${mix.songs.length} songs',
                                ),
                                const SizedBox(width: 8),
                                _InfoChip(
                                  icon: Icons.timer_outlined,
                                  label: _formatTotalDuration(mix.songs),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons & header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dual Action Buttons: Play All & Shuffle Mix
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _playAll(ref),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      mix.accentColor,
                                      mix.secondaryColor,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: mix.accentColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Play All',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _shufflePlay(ref),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.white.withValues(alpha: 0.85),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.9),
                                  ),
                                  boxShadow: isDark
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shuffle_rounded,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F111A),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Shuffle Mix',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F111A),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section Label
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'TRACKS (${mix.songs.length})',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.45)
                                        : const Color(0xFF5C6275),
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          Text(
                            mix.title,
                            style: TextStyle(
                              color: mix.accentColor.withValues(alpha: 0.75),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Empty state
              if (mix.songs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 40,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white.withValues(alpha: 0.85),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.9),
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            mix.icon,
                            color: mix.accentColor.withValues(alpha: 0.5),
                            size: 40,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No songs in this mix yet',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F111A),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Scan your local music files or play tracks to populate ${mix.title}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : const Color(0xFF5C6275),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                // Track list sliver
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final song = mix.songs[index];
                      final isPlayingThis =
                          currentTrackId == 'local_${song.id}';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () {
                            final tracks = mix.songs
                                .map(Track.fromSong)
                                .toList();
                            ref
                                .read(playerControllerProvider.notifier)
                                .playTrack(tracks[index], queue: tracks);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: isPlayingThis
                                  ? mix.accentColor.withValues(
                                      alpha: isDark ? 0.12 : 0.10,
                                    )
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.03)
                                        : Colors.white.withValues(alpha: 0.85)),
                              border: Border.all(
                                color: isPlayingThis
                                    ? mix.accentColor.withValues(alpha: 0.35)
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.white.withValues(
                                              alpha: 0.9,
                                            )),
                              ),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                            ),
                            child: Row(
                              children: [
                                // Index or playing indicator
                                SizedBox(
                                  width: 26,
                                  child: isPlayingThis
                                      ? Icon(
                                          Icons.graphic_eq_rounded,
                                          color: mix.accentColor,
                                          size: 18,
                                        )
                                      : Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.35,
                                                  )
                                                : const Color(0xFF5C6275),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 8),

                                // Song Artwork
                                SongArtwork.fromSong(
                                  song,
                                  size: 46,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                const SizedBox(width: 12),

                                // Title and Artist
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isPlayingThis
                                              ? mix.accentColor
                                              : (isDark
                                                    ? Colors.white
                                                    : const Color(0xFF0F111A)),
                                          fontSize: 14,
                                          fontWeight: isPlayingThis
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.5,
                                                )
                                              : const Color(0xFF5C6275),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Trailing info: duration & playCount badge
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatDuration(song.duration),
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.4,
                                              )
                                            : const Color(0xFF5C6275),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (song.playCount > 0) ...[
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.06,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                        ),
                                        child: Text(
                                          '${song.playCount} plays',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.45,
                                                  )
                                                : const Color(0xFF5C6275),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: mix.songs.length),
                  ),
                ),

              // Bottom padding for MiniPlayer
              SliverToBoxAdapter(
                child: SizedBox(height: hasMiniplayer ? 110 : 32),
              ),
            ],
          ),

          // Floating MiniPlayer
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: MiniPlayer(bottomPadding: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBlobs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -60,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  mix.accentColor.withValues(alpha: isDark ? 0.22 : 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 250,
          left: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  mix.secondaryColor.withValues(alpha: isDark ? 0.15 : 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF08070F).withValues(alpha: 0.65),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
