import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/audio/track.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../library/data/audio_scanner_service.dart';
import '../../library/presentation/widgets/song_artwork.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/mini_player.dart';
import '../../../core/navigation/lucid_page_transition.dart';
import '../../../core/widgets/lucid_cascade_item.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/stats_provider.dart';
import '../application/user_profile_provider.dart';
import 'edit_profile_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.showMiniPlayer = true});

  final bool showMiniPlayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value ?? const UserProfile();
    final statsAsync = ref.watch(statsProvider);
    final playerState = ref.watch(playerControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: showMiniPlayer
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.transparent,
      body: Stack(
        children: [
          // Ambient Background Blobs
          _AmbientProfileGlow(isDark: isDark),

          // Main Scrollable Dashboard
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top App Bar Header (Always rendered)
                _ProfileAppBar(
                  onEditProfile: () => EditProfileSheet.show(context),
                  onOpenSettings: () {
                    Navigator.of(context).push(
                      LucidGlassPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),

                // Scrollable Body guarded with Riverpod AsyncValue.when
                Expanded(
                  child: statsAsync.when(
                    data: (stats) => _ProfileContentBody(
                      profile: profile,
                      stats: stats,
                      playerState: playerState,
                      ref: ref,
                    ),
                    loading: () =>
                        _ProfileLoadingSkeleton(playerState: playerState),
                    error: (error, stack) {
                      debugPrint(
                        '[ProfileScreen] Error loading stats: $error\n$stack',
                      );
                      return _ProfileErrorFallback(
                        profile: profile,
                        playerState: playerState,
                        error: error,
                        onRetry: () {
                          ref.invalidate(localSongsStreamProvider);
                          ref.invalidate(statsProvider);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // MiniPlayer
          if (showMiniPlayer)
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Content Body (Guarded Render Tree)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileContentBody extends StatelessWidget {
  const _ProfileContentBody({
    required this.profile,
    required this.stats,
    required this.playerState,
    required this.ref,
  });

  final UserProfile profile;
  final UserListeningStats? stats;
  final dynamic playerState;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final safeStats = stats ?? const UserListeningStats();
    final topArtists = safeStats.topArtists;
    final topSongs = safeStats.topSongs;
    final tick = ref.watch(tabEntryTicksProvider.select((t) => t[3]));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom +
            (playerState.hasTrack ? 150.0 : 100.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero Card: "Your Music Universe"
          LucidCascadeItem(
            index: 0,
            triggerKey: tick,
            child: _MusicUniverseHero(
              profile: profile,
              stats: safeStats,
              onEdit: () => EditProfileSheet.show(context),
            ),
          ),
          const SizedBox(height: 24),

          // 2. Stat Grid Cards (4 Metrics)
          LucidCascadeItem(
            index: 1,
            triggerKey: tick,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  title: 'LISTENING METRICS',
                  icon: Icons.insights_rounded,
                ),
                const SizedBox(height: 12),
                _StatCardsGrid(stats: safeStats),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 3. Listening Activity Breakdown (Futuristic Progress Bars)
          LucidCascadeItem(
            index: 2,
            triggerKey: tick,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  title: 'LISTENING ACTIVITY & FLOW',
                  icon: Icons.graphic_eq_rounded,
                ),
                const SizedBox(height: 12),
                _ListeningActivityCard(stats: safeStats),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 4. Top Artists in Your Orbit
          LucidCascadeItem(
            index: 3,
            triggerKey: tick,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'TOP ARTISTS IN YOUR ORBIT',
                  icon: Icons.bubble_chart_rounded,
                  actionText: topArtists.isNotEmpty ? 'View Library' : null,
                  onActionTap: () => context.push('/library'),
                ),
                const SizedBox(height: 12),
                if (topArtists.isNotEmpty)
                  _TopArtistsList(
                    artists: topArtists,
                    onArtistTap: (artist) => context.push('/library'),
                  )
                else
                  const _EmptyInsightCard(
                    icon: Icons.bubble_chart_outlined,
                    title: 'No Artists in Orbit Yet',
                    message: 'Start playing music to unlock insights! Your most streamed artists will orbit here.',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 5. Heavy Rotation (Top Tracks)
          LucidCascadeItem(
            index: 4,
            triggerKey: tick,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  title: 'YOUR HEAVY ROTATION',
                  icon: Icons.local_fire_department_rounded,
                ),
                const SizedBox(height: 12),
                if (topSongs.isNotEmpty)
                  _HeavyRotationList(
                    songs: topSongs,
                    onPlaySong: (song) {
                      final track = Track.fromSong(song);
                      final queue = topSongs.map(Track.fromSong).toList();
                      ref
                          .read(playerControllerProvider.notifier)
                          .playTrack(track, queue: queue);
                    },
                  )
                else
                  const _EmptyInsightCard(
                    icon: Icons.local_fire_department_outlined,
                    title: 'No Heavy Rotation Yet',
                    message: 'Start playing music to unlock insights! Songs you repeat will automatically appear here.',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading Skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileLoadingSkeleton extends StatelessWidget {
  const _ProfileLoadingSkeleton({required this.playerState});

  final dynamic playerState;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final baseShimmer = isLight
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.08);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 12, 20, playerState.hasTrack ? 120 : 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sleek Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF8B5CF6),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'SYNCING LISTENING INSIGHTS...',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Skeleton Hero Card
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.white.withValues(alpha: 0.90)
                  : const Color(0xFF141226).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: baseShimmer),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: baseShimmer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 130,
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: baseShimmer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 90,
                            height: 14,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: baseShimmer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: baseShimmer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Skeleton 4 Metric Cards
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.45,
            children: List.generate(4, (_) {
              return Container(
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.white.withValues(alpha: 0.90)
                      : const Color(0xFF141226).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: baseShimmer),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Fallback
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileErrorFallback extends StatelessWidget {
  const _ProfileErrorFallback({
    required this.profile,
    required this.playerState,
    required this.onRetry,
    required this.error,
  });

  final UserProfile profile;
  final dynamic playerState;
  final VoidCallback onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 12, 20, playerState.hasTrack ? 120 : 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sleek Error Notice Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isLight
                  ? const Color(0xFFFFF1F2)
                  : const Color(0xFF2C131A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF4E88).withValues(alpha: 0.35),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4E88).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sync_problem_rounded,
                    color: Color(0xFFFF4E88),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insights Inactive',
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF881337)
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Showing offline fallback stats. Tap to retry.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF9F1239)
                              : Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4E88)
                        .withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Color(0xFFFF4E88),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Render guarded dashboard with default 0-initialized stats
          _MusicUniverseHero(
            profile: profile,
            stats: const UserListeningStats(),
            onEdit: () => EditProfileSheet.show(context),
          ),
          const SizedBox(height: 24),

          const _SectionHeader(
            title: 'LISTENING METRICS',
            icon: Icons.insights_rounded,
          ),
          const SizedBox(height: 12),
          const _StatCardsGrid(stats: UserListeningStats()),
          const SizedBox(height: 28),

          const _SectionHeader(
            title: 'LISTENING ACTIVITY & FLOW',
            icon: Icons.graphic_eq_rounded,
          ),
          const SizedBox(height: 12),
          const _ListeningActivityCard(stats: UserListeningStats()),
          const SizedBox(height: 28),

          _SectionHeader(
            title: 'TOP ARTISTS IN YOUR ORBIT',
            icon: Icons.bubble_chart_rounded,
            actionText: 'View Library',
            onActionTap: () => context.push('/library'),
          ),
          const SizedBox(height: 12),
          const _EmptyInsightCard(
            icon: Icons.bubble_chart_outlined,
            title: 'No Artists in Orbit Yet',
            message: 'Start playing music to unlock insights! Your top artists will orbit here.',
          ),
          const SizedBox(height: 28),

          const _SectionHeader(
            title: 'YOUR HEAVY ROTATION',
            icon: Icons.local_fire_department_rounded,
          ),
          const SizedBox(height: 12),
          const _EmptyInsightCard(
            icon: Icons.local_fire_department_outlined,
            title: 'No Heavy Rotation Yet',
            message: 'Start playing music to unlock insights! Spin your favorite songs to see them featured here.',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambient Glow
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientProfileGlow extends StatelessWidget {
  const _AmbientProfileGlow({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -40,
          right: -60,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED))
                      .withValues(alpha: isDark ? 0.16 : 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 260,
          left: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFFFF758F) : const Color(0xFFFF85A1))
                      .withValues(alpha: isDark ? 0.12 : 0.06),
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

// ─────────────────────────────────────────────────────────────────────────────
// App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileAppBar extends StatelessWidget {
  const _ProfileAppBar({
    required this.onEditProfile,
    required this.onOpenSettings,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFFF758F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insights_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'INSIGHTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Edit Profile',
            onPressed: onEditProfile,
            icon: Icon(
              Icons.edit_outlined,
              size: 20,
              color: isLight ? const Color(0xFF0F111A) : Colors.white,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onOpenSettings,
            icon: Icon(
              Icons.settings_outlined,
              size: 20,
              color: isLight ? const Color(0xFF0F111A) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.actionText,
    this.onActionTap,
  });

  final String title;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final labelColor = isLight
        ? const Color(0xFF5C6275)
        : Colors.white.withValues(alpha: 0.5);

    return Row(
      children: [
        Icon(icon, size: 15, color: labelColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        if (actionText != null && onActionTap != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionText!,
              style: const TextStyle(
                color: Color(0xFF8B5CF6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Hero Card: "Your Music Universe"
// ─────────────────────────────────────────────────────────────────────────────

class _MusicUniverseHero extends StatelessWidget {
  const _MusicUniverseHero({
    required this.profile,
    required this.stats,
    required this.onEdit,
  });

  final UserProfile profile;
  final UserListeningStats? stats;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final avatarPath = profile.avatarPath;
    final name = profile.displayName.isNotEmpty
        ? profile.displayName
        : 'Music Lover';
    final vibe = profile.vibeSubtitle.isNotEmpty
        ? profile.vibeSubtitle
        : 'Cosmic Listener';
    final safeStats = stats ?? const UserListeningStats();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? [Colors.white.withValues(alpha: 0.95), const Color(0xFFF3F0FF)]
              : [
                  const Color(0xFF1E1435).withValues(alpha: 0.85),
                  const Color(0xFF0F0B1A).withValues(alpha: 0.95),
                ],
        ),
        border: Border.all(
          color: isLight
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.25)
              : const Color(0xFF8B5CF6).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6)
                .withValues(alpha: isLight ? 0.12 : 0.22),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar with glowing ring
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: avatarPath == null
                        ? const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFFF758F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    image: avatarPath != null
                        ? DecorationImage(
                            image: FileImage(File(avatarPath)),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: avatarPath == null
                      ? const Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),

              // Name, Vibe & Streak
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF0F111A)
                                  : Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF00E5FF),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vibe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFF758F),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Cosmic Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6)
                              .withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFFFD56B),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${safeStats.streakDays} DAY STREAK',
                            style: const TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Divider
          Divider(
            color: isLight
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.08),
            height: 1,
          ),
          const SizedBox(height: 16),

          // Bottom Quick Summary Row
          Row(
            children: [
              Expanded(
                child: _UniverseQuickStat(
                  label: 'Hours Logged',
                  value: safeStats.formattedHours,
                  unit: 'hrs',
                  color: const Color(0xFF00E5FF),
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: isLight
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              Expanded(
                child: _UniverseQuickStat(
                  label: 'Plays Recorded',
                  value: '${safeStats.totalPlayCount}',
                  unit: 'spins',
                  color: const Color(0xFFFF758F),
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: isLight
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              Expanded(
                child: _UniverseQuickStat(
                  label: 'Library Size',
                  value: '${safeStats.totalSongs}',
                  unit: 'tracks',
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UniverseQuickStat extends StatelessWidget {
  const _UniverseQuickStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLight ? const Color(0xFF0F111A) : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isLight
                ? const Color(0xFF5C6275)
                : Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Stat Cards Grid (4 Cards)
// ─────────────────────────────────────────────────────────────────────────────

class _StatCardsGrid extends StatelessWidget {
  const _StatCardsGrid({required this.stats});
  final UserListeningStats? stats;

  @override
  Widget build(BuildContext context) {
    final safeStats = stats ?? const UserListeningStats();

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        _MetricCard(
          title: 'Total Songs Played',
          value: '${safeStats.totalPlayedTracks}',
          subtitle: 'Active rotation',
          icon: Icons.play_circle_fill_rounded,
          accentColor: const Color(0xFF00E5FF),
        ),
        _MetricCard(
          title: 'Favorite Artists',
          value: '${safeStats.topArtists.length}',
          subtitle: 'In heavy orbit',
          icon: Icons.people_alt_rounded,
          accentColor: const Color(0xFF8B5CF6),
        ),
        _MetricCard(
          title: 'Listening Time',
          value: safeStats.formattedHours,
          subtitle: 'Hours enjoyed',
          icon: Icons.timer_rounded,
          accentColor: const Color(0xFFFF9E44),
        ),
        _MetricCard(
          title: 'Liked Tracks',
          value: '${safeStats.totalFavorites}',
          subtitle: 'Starred songs',
          icon: Icons.favorite_rounded,
          accentColor: const Color(0xFFFF758F),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.92)
            : const Color(0xFF141226).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.10),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isLight ? const Color(0xFF0F111A) : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLight ? const Color(0xFF0F111A) : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLight
                      ? const Color(0xFF5C6275)
                      : Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Listening Activity Breakdown Card
// ─────────────────────────────────────────────────────────────────────────────

class _ListeningActivityCard extends StatelessWidget {
  const _ListeningActivityCard({required this.stats});
  final UserListeningStats? stats;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final slots = (stats?.activitySlots.isNotEmpty == true)
        ? stats!.activitySlots
        : UserListeningStats.defaultSlots();

    final colors = [
      const Color(0xFFFF9E44), // Morning
      const Color(0xFF00D2FF), // Afternoon
      const Color(0xFFFF4E88), // Evening
      const Color(0xFF9D50BB), // Night
    ];

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.92)
            : const Color(0xFF141226).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.10),
          width: 1.1,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_rounded,
                color: Color(0xFF8B5CF6),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Day vs Night Rhythm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isLight ? const Color(0xFF0F111A) : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Multi-Segment Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: Row(
                children: List.generate(slots.length, (index) {
                  final slot = slots[index];
                  final flex = (slot.percentage * 100).round().clamp(1, 100);
                  return Expanded(
                    flex: flex,
                    child: Container(color: colors[index % colors.length]),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(slots.length, (index) {
              final slot = slots[index];
              final pct = (slot.percentage * 100).round();
              return Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors[index % colors.length],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            slot.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF5C6275)
                                  : Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$pct%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF0F111A)
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Top Artists in Your Orbit List
// ─────────────────────────────────────────────────────────────────────────────

class _TopArtistsList extends StatelessWidget {
  const _TopArtistsList({required this.artists, required this.onArtistTap});

  final List<ArtistPlayStat> artists;
  final ValueChanged<String> onArtistTap;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.92)
            : const Color(0xFF141226).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.10),
          width: 1.1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: artists.length,
          separatorBuilder: (_, _) => Divider(
            color: isLight
                ? Colors.black.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.06),
            height: 1,
          ),
          itemBuilder: (context, index) {
            final item = artists[index];
            final rank = index + 1;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              onTap: () => onArtistTap(item.artist),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        color: rank == 1
                            ? const Color(0xFFFFD56B)
                            : (isLight
                                  ? const Color(0xFF8E95A8)
                                  : Colors.white38),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6)
                              .withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: item.representativeSong != null
                          ? SongArtwork.fromSong(
                              item.representativeSong!,
                              size: 44,
                              borderRadius: BorderRadius.zero,
                            )
                          : const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ],
              ),
              title: Text(
                item.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLight ? const Color(0xFF0F111A) : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                '${item.songCount} songs • ${item.playCount} plays',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLight ? const Color(0xFF5C6275) : Colors.white60,
                  fontSize: 11,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF8B5CF6),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Heavy Rotation (Top Tracks)
// ─────────────────────────────────────────────────────────────────────────────

class _HeavyRotationList extends StatelessWidget {
  const _HeavyRotationList({required this.songs, required this.onPlaySong});

  final List<Song> songs;
  final ValueChanged<Song> onPlaySong;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.92)
            : const Color(0xFF141226).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.10),
          width: 1.1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: songs.length,
          separatorBuilder: (_, _) => Divider(
            color: isLight
                ? Colors.black.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.06),
            height: 1,
          ),
          itemBuilder: (context, index) {
            final song = songs[index];

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              onTap: () => onPlaySong(song),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: SongArtwork.fromSong(
                    song,
                    size: 44,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLight ? const Color(0xFF0F111A) : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                '${song.artist} • ${song.playCount} plays',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLight ? const Color(0xFF5C6275) : Colors.white60,
                  fontSize: 11,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Empty Insights Placeholder Card
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyInsightCard extends StatelessWidget {
  const _EmptyInsightCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.90)
            : const Color(0xFF141226).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLight
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
              : const Color(0xFF8B5CF6).withValues(alpha: 0.20),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8B5CF6)
                  .withValues(alpha: isLight ? 0.12 : 0.18),
            ),
            child: Icon(icon, color: const Color(0xFF8B5CF6), size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isLight ? const Color(0xFF0F111A) : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isLight ? const Color(0xFF5C6275) : Colors.white60,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
