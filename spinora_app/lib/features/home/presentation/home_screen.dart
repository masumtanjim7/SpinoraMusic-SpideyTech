import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/track.dart';
import '../../../core/database/app_database.dart';
import '../../../features/library/data/audio_scanner_service.dart';
import '../../../features/player/application/player_controller.dart';
import '../../../features/player/presentation/mini_player.dart';
import '../../../features/profile/application/user_profile_provider.dart';
import '../../../features/profile/presentation/edit_profile_sheet.dart';
import '../../library/presentation/widgets/song_artwork.dart';

// ---------------------------------------------------------------------------
// Home Screen — Lucid Glass Personalized Dashboard
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;

    return Scaffold(
      backgroundColor: const Color(0xFF08070F),
      body: Stack(
        children: [
          _buildAmbientBlobs(),
          SafeArea(
            child: Column(
              children: [
                _TopHeader(profile: profile),
                Expanded(
                  child: _DashboardBody(profile: profile),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: MiniPlayer(bottomPadding: 16),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _GlassBottomNav(),
    );
  }

  Widget _buildAmbientBlobs() {
    return Stack(children: [
      Positioned(top: -40, left: -80, child: Container(width: 320, height: 320,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [const Color(0xFF8B5CF6).withValues(alpha: 0.18), Colors.transparent])))),
      Positioned(top: 200, right: -60, child: Container(width: 260, height: 260,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [const Color(0xFFFF758F).withValues(alpha: 0.12), Colors.transparent])))),
      Positioned(bottom: 120, left: 40, child: Container(width: 200, height: 200,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [const Color(0xFF3B82F6).withValues(alpha: 0.1), Colors.transparent])))),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Top Header
// ---------------------------------------------------------------------------

class _TopHeader extends ConsumerWidget {
  const _TopHeader({required this.profile});
  final UserProfile? profile;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Late night vibes';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile?.displayName ?? 'Music Lover';
    final tt = Theme.of(context).textTheme;
    final avatarPath = profile?.avatarPath;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFFF758F)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text('SPINORA', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
          ]),
        ),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_greeting(), style: tt.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.45))),
          Text(name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => EditProfileSheet.show(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: avatarPath == null ? const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFFF758F)],
                begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
              image: avatarPath != null ? DecorationImage(image: FileImage(File(avatarPath)), fit: BoxFit.cover) : null,
              boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4), blurRadius: 10)],
            ),
            child: avatarPath == null ? const Center(child: Icon(Icons.person_rounded, color: Colors.white, size: 20)) : null,
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard Body
// ---------------------------------------------------------------------------

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.profile});
  final UserProfile? profile;

  void _playCollection(WidgetRef ref, List<Song> songs) {
    if (songs.isEmpty) return;
    final tracks = songs.map(Track.fromSong).toList();
    ref.read(playerControllerProvider.notifier).playTrack(tracks.first, queue: tracks);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(localSongsStreamProvider);
    final recentAsync = ref.watch(recentlyPlayedSongsStreamProvider);
    final playerState = ref.watch(playerControllerProvider);

    final allSongs = songsAsync.value ?? [];
    final recentSongs = recentAsync.value ?? [];

    final mostPlayed = [...allSongs]..sort((a, b) => b.playCount.compareTo(a.playCount));
    final top10 = mostPlayed.where((s) => s.playCount > 0).take(10).toList();

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final forgotten = allSongs.where((s) =>
      s.playCount > 0 && s.lastPlayedAt != null && s.lastPlayedAt!.isBefore(thirtyDaysAgo)).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    final rotation = recentSongs.take(6).toList();
    final hasMiniplayer = playerState.hasTrack;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, 20, 0, hasMiniplayer ? 110 : 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (profile?.vibeSubtitle != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(profile!.vibeSubtitle,
              style: TextStyle(color: const Color(0xFFFF758F).withValues(alpha: 0.75),
                fontSize: 13, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic))),
        const SizedBox(height: 20),

        _HeroCard(allSongs: allSongs, recentSongs: recentSongs),
        const SizedBox(height: 24),

        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('SMART PICKS', style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.6, fontWeight: FontWeight.w700))),
        const SizedBox(height: 12),

        SizedBox(height: 130,
          child: ListView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _SmartCard(icon: Icons.trending_up_rounded, label: 'Top 10\nMost Played', count: top10.length,
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                onTap: top10.isEmpty ? null : () => _playCollection(ref, top10)),
              const SizedBox(width: 12),
              _SmartCard(icon: Icons.history_rounded, label: 'Forgotten\nFavorites', count: forgotten.length,
                gradient: const LinearGradient(colors: [Color(0xFFFF758F), Color(0xFFFF4D6D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                onTap: forgotten.isEmpty ? null : () => _playCollection(ref, forgotten)),
              const SizedBox(width: 12),
              _SmartCard(icon: Icons.library_music_rounded, label: 'Full\nLibrary', count: allSongs.length,
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                onTap: () => context.push('/library')),
            ],
          ),
        ),
        const SizedBox(height: 28),

        if (rotation.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('YOUR ROTATION', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.6, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(onTap: () => context.push('/library'),
                child: Text('See all', style: TextStyle(color: const Color(0xFF8B5CF6).withValues(alpha: 0.85),
                  fontSize: 12, fontWeight: FontWeight.w600))),
            ])),
          const SizedBox(height: 12),
          _RotationGrid(songs: rotation),
          const SizedBox(height: 28),
        ],

        if (recentSongs.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('RECENTLY PLAYED', style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.6, fontWeight: FontWeight.w700))),
          const SizedBox(height: 12),
          _RecentList(songs: recentSongs),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Card
// ---------------------------------------------------------------------------

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.allSongs, required this.recentSongs});
  final List<Song> allSongs;
  final List<Song> recentSongs;

  String _heroLabel() {
    final h = DateTime.now().hour;
    if (h < 12) return 'MORNING RITUALS';
    if (h < 17) return 'AFTERNOON DRIVE';
    if (h < 21) return 'EVENING FLOW';
    return 'LATE NIGHT VIBES';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final songCount = allSongs.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          if (allSongs.isNotEmpty) {
            final tracks = allSongs.map(Track.fromSong).toList();
            ref.read(playerControllerProvider.notifier).playTrack(tracks.first, queue: tracks);
          } else {
            context.push('/library');
          }
        },
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(colors: [Color(0xFF1E0A3C), Color(0xFF0D1A3A)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 8))],
          ),
          child: Stack(children: [
            Positioned(right: -30, top: -30, child: Container(width: 160, height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFFFF758F).withValues(alpha: 0.15), Colors.transparent])))),
            Positioned(left: 100, bottom: -20, child: Container(width: 100, height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFF8B5CF6).withValues(alpha: 0.2), Colors.transparent])))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFFFF758F).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFFFF758F).withValues(alpha: 0.35))),
                  child: Text(_heroLabel(), style: const TextStyle(color: Color(0xFFFF758F),
                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5))),
                const Spacer(),
                Text(songCount == 0 ? 'Scan your library' : '$songCount songs ready',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Row(children: [
                  Text(songCount == 0 ? 'Tap to go to library' : 'Tap to start playing',
                    style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.55))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFFFF758F), Color(0xFF8B5CF6)]),
                      boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5), blurRadius: 12)]),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Smart Card
// ---------------------------------------------------------------------------

class _SmartCard extends StatelessWidget {
  const _SmartCard({required this.icon, required this.label, required this.count,
    required this.gradient, this.onTap});
  final IconData icon;
  final String label;
  final int count;
  final Gradient gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: gradient),
              child: Icon(icon, color: Colors.white, size: 18)),
            const Spacer(),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 4),
            Text('$count songs', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rotation Grid (2 columns)
// ---------------------------------------------------------------------------

class _RotationGrid extends ConsumerWidget {
  const _RotationGrid({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 2.8,
          crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: songs.length,
        itemBuilder: (_, i) {
          final s = songs[i];
          return GestureDetector(
            onTap: () {
              final track = Track.fromSong(s);
              ref.read(playerControllerProvider.notifier).playTrack(track, queue: [track]);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09))),
              child: Row(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  child: SongArtwork.fromSong(s, size: 48, borderRadius: BorderRadius.zero)),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10)),
                  ])),
                const SizedBox(width: 4),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recently Played List
// ---------------------------------------------------------------------------

class _RecentList extends ConsumerWidget {
  const _RecentList({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final display = songs.take(8).toList();

    return Column(
      children: display.map((s) {
        final isCurrentTrack = ref.watch(playerControllerProvider).currentTrack?.id == 'local_${s.id}';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: GestureDetector(
            onTap: () {
              final track = Track.fromSong(s);
              ref.read(playerControllerProvider.notifier).playTrack(track, queue: [track]);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isCurrentTrack
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: isCurrentTrack
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.07))),
              child: Row(children: [
                SongArtwork.fromSong(s, size: 44, borderRadius: BorderRadius.circular(10), isCurrent: isCurrentTrack),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.5))),
                ])),
                if (isCurrentTrack)
                  const Icon(Icons.equalizer_rounded, color: Color(0xFF8B5CF6), size: 18)
                else
                  Icon(Icons.play_circle_outline_rounded, color: Colors.white.withValues(alpha: 0.3), size: 20),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass Bottom Nav Bar
// ---------------------------------------------------------------------------

class _GlassBottomNav extends ConsumerWidget {
  const _GlassBottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0C18).withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07)))),
      child: SafeArea(top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _NavItem(icon: Icons.home_rounded, label: 'Home', isActive: true, onTap: () {}),
            _NavItem(icon: Icons.library_music_rounded, label: 'Library', isActive: false,
              onTap: () => context.push('/library')),
            _NavItem(icon: Icons.search_rounded, label: 'Search', isActive: false,
              onTap: () => context.push('/library')),
            _NavItem(icon: Icons.person_rounded, label: 'Profile', isActive: false,
              onTap: () => EditProfileSheet.show(context)),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label,
    required this.isActive, required this.onTap});
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isActive ? const Color(0xFF8B5CF6).withValues(alpha: 0.2) : Colors.transparent),
            child: Icon(icon, size: 22,
              color: isActive ? const Color(0xFF8B5CF6) : Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive ? const Color(0xFF8B5CF6) : Colors.white.withValues(alpha: 0.4))),
        ]),
      ),
    );
  }
}
