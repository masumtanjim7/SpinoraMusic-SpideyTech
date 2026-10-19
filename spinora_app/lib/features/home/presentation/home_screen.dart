import 'dart:io';
import 'dart:math' as math;

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
import '../../../features/settings/presentation/settings_screen.dart';
import '../../library/presentation/widgets/song_artwork.dart';
import '../application/smart_mixes_provider.dart';
import 'smart_mix_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen — Lucid Glass Personalized Dashboard
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedNav = 0;

  void _onNavTap(int index) {
    if (index == 1) {
      context.push('/library');
      return;
    }
    if (index == 2) {
      context.push('/library');
      return;
    }
    if (index == 3) {
      EditProfileSheet.show(context);
      return;
    }
    if (index == 4) {
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const SettingsScreen(),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
      return;
    }
    setState(() => _selectedNav = index);
  }

  @override
  Widget build(BuildContext context) {
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
                Expanded(child: _DashboardBody(profile: profile)),
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
      bottomNavigationBar: _GlassBottomNav(
        selectedIndex: _selectedNav,
        onTap: _onNavTap,
      ),
    );
  }

  Widget _buildAmbientBlobs() {
    return Stack(children: [
      Positioned(
          top: -40,
          left: -80,
          child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                    Colors.transparent
                  ])))),
      Positioned(
          top: 200,
          right: -60,
          child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFFFF758F).withValues(alpha: 0.12),
                    Colors.transparent
                  ])))),
      Positioned(
          bottom: 120,
          left: 40,
          child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    Colors.transparent
                  ])))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Header
// ─────────────────────────────────────────────────────────────────────────────

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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 3))
            ],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text('SPINORA',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4)),
          ]),
        ),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_greeting(),
              style: tt.labelSmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.45))),
          Text(name,
              style: tt.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => EditProfileSheet.show(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: avatarPath == null
                  ? const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFFF758F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight)
                  : null,
              image: avatarPath != null
                  ? DecorationImage(
                      image: FileImage(File(avatarPath)), fit: BoxFit.cover)
                  : null,
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    blurRadius: 10)
              ],
            ),
            child: avatarPath == null
                ? const Center(
                    child: Icon(Icons.person_rounded,
                        color: Colors.white, size: 20))
                : null,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Body
// ─────────────────────────────────────────────────────────────────────────────

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
    final smartMixes = ref.watch(smartMixesProvider);

    final allSongs = songsAsync.value ?? [];
    final recentSongs = recentAsync.value ?? [];

    final rotation = recentSongs.take(8).toList();
    final hasMiniplayer = playerState.hasTrack;

    // Top artists: group songs by artist and pick a representative
    final artistMap = <String, Song>{};
    for (final s in allSongs) {
      if (!artistMap.containsKey(s.artist)) {
        artistMap[s.artist] = s;
      }
    }
    final topArtists = artistMap.values.take(8).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, 20, 0, hasMiniplayer ? 110 : 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Vibe subtitle
        if (profile?.vibeSubtitle != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              profile!.vibeSubtitle,
              style: TextStyle(
                  color: const Color(0xFFFF758F).withValues(alpha: 0.75),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic),
            ),
          ),
        const SizedBox(height: 20),

        // ── Hero Card
        _HeroCard(allSongs: allSongs, recentSongs: recentSongs, profile: profile),
        const SizedBox(height: 24),

        // ── Smart Picks
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('SMART PICKS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: smartMixes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final mix = smartMixes[index];
              return _SmartPickCard(
                mix: mix,
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (_, _, _) => SmartMixDetailScreen(mix: mix),
                      transitionsBuilder: (_, animation, _, child) =>
                          FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    ),
                  );
                },
                onQuickPlay: mix.songs.isEmpty
                    ? null
                    : () => _playCollection(ref, mix.songs),
              );
            },
          ),
        ),
        const SizedBox(height: 28),

        // ── Your Rotation (tall portrait cards)
        if (rotation.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                child: Text('YOUR ROTATION',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: () => context.push('/library'),
                child: Text('See all',
                    style: TextStyle(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _RotationCarousel(songs: rotation),
          const SizedBox(height: 28),
        ],

        // ── Artists in Your Orbit
        if (topArtists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('ARTISTS IN YOUR ORBIT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.4),
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          _ArtistsOrbitRow(artists: topArtists, ref: ref, allSongs: allSongs),
          const SizedBox(height: 28),
        ],

        // ── Recently Played
        if (recentSongs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('RECENTLY PLAYED',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.4),
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          _RecentList(songs: recentSongs),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Moonlit Cosmic Hero Painter
// ─────────────────────────────────────────────────────────────────────────────

class _CosmicHeroPainter extends CustomPainter {
  const _CosmicHeroPainter({required this.hour, required this.animValue});
  final int hour;
  final double animValue; // 0.0 → 1.0 looping

  @override
  void paint(Canvas canvas, Size size) {
    final isNight = hour >= 21 || hour < 6;
    final isEvening = hour >= 18;

    // --- Aurora waves ---
    final auroraColors = isNight
        ? [const Color(0xFF8B5CF6), const Color(0xFF3B82F6), const Color(0xFF10B981)]
        : [const Color(0xFFFF758F), const Color(0xFF8B5CF6), const Color(0xFFFF4D6D)];

    for (var i = 0; i < 3; i++) {
      final phase = animValue * 2 * math.pi + i * (2 * math.pi / 3);
      final waveY = size.height * 0.55 + math.sin(phase) * 18;
      final path = Path();
      path.moveTo(0, waveY);
      for (double x = 0; x <= size.width; x += 4) {
        final y = waveY +
            math.sin((x / size.width) * math.pi * 3 + phase) * 14 -
            i * 20;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            auroraColors[i].withValues(alpha: 0.18),
            auroraColors[(i + 1) % 3].withValues(alpha: 0.08),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(path, paint);
    }

    // --- Horizon silhouette ---
    final horizonPaint = Paint()
      ..color = (isNight
              ? const Color(0xFF0D0A1A)
              : const Color(0xFF1A0D2E))
          .withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final horizonPath = Path();
    horizonPath.moveTo(0, size.height * 0.72);
    horizonPath.cubicTo(
        size.width * 0.2, size.height * 0.65,
        size.width * 0.5, size.height * 0.70,
        size.width, size.height * 0.68);
    horizonPath.lineTo(size.width, size.height);
    horizonPath.lineTo(0, size.height);
    horizonPath.close();
    canvas.drawPath(horizonPath, horizonPaint);

    // --- Moon (night) or Sun glow (day) ---
    if (isEvening) {
      final moonX = size.width * 0.78;
      final moonY = size.height * 0.22;
      final moonPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(moonX, moonY), 14, moonPaint);

      // Glow halo
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(moonX, moonY), radius: 36));
      canvas.drawCircle(Offset(moonX, moonY), 36, haloPaint);
    }

    // --- Neon mesh glow nodes ---
    final rng = math.Random(42);
    final nodeCount = isNight ? 18 : 10;
    for (var i = 0; i < nodeCount; i++) {
      final nx = rng.nextDouble() * size.width;
      final ny = rng.nextDouble() * size.height * 0.65;
      final sparkle = (math.sin(animValue * 2 * math.pi + i) + 1) / 2;
      final nodePaint = Paint()
        ..color = auroraColors[i % auroraColors.length]
            .withValues(alpha: 0.6 * sparkle + 0.1);
      canvas.drawCircle(Offset(nx, ny), 1.5, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicHeroPainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Card — Layered Lucid Glass Visual Hero Banner
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends ConsumerStatefulWidget {
  const _HeroCard({
    required this.allSongs,
    required this.recentSongs,
    required this.profile,
  });
  final List<Song> allSongs;
  final List<Song> recentSongs;
  final UserProfile? profile;

  @override
  ConsumerState<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends ConsumerState<_HeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _heroLabel() {
    final h = DateTime.now().hour;
    if (h < 6) return 'LATE NIGHT VIBES';
    if (h < 12) return 'MORNING RITUALS';
    if (h < 17) return 'AFTERNOON DRIVE';
    if (h < 21) return 'EVENING FLOW';
    return 'LATE NIGHT VIBES';
  }

  String _heroHeadline() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Stay a little after hours.';
    if (h < 12) return 'Set the tone for today.';
    if (h < 17) return 'Keep the momentum going.';
    if (h < 21) return 'Wind down with good sound.';
    return 'Stay a little after hours.';
  }

  @override
  Widget build(BuildContext context) {
    final songCount = widget.allSongs.length;
    final name = widget.profile?.displayName ?? 'You';
    final previewSongs = {
      ...widget.recentSongs.take(3),
      ...widget.allSongs.take(3),
    }.take(4).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          if (widget.allSongs.isNotEmpty) {
            final tracks = widget.allSongs.map(Track.fromSong).toList()..shuffle();
            ref
                .read(playerControllerProvider.notifier)
                .playTrack(tracks.first, queue: tracks);
          } else {
            context.push('/library');
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Layer 1: Cosmic background painter
                    CustomPaint(
                      painter: _CosmicHeroPainter(
                        hour: DateTime.now().hour,
                        animValue: _ctrl.value,
                      ),
                    ),

                    // Dark vignette
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            const Color(0xFF1E0A3C).withValues(alpha: 0.55),
                            const Color(0xFF08070F).withValues(alpha: 0.82),
                          ],
                        ),
                      ),
                    ),

                    // Border glow
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        ),
                      ),
                    ),

                    // Foreground content
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color:
                                  const Color(0xFFFF758F).withValues(alpha: 0.15),
                              border: Border.all(
                                  color: const Color(0xFFFF758F)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Text(_heroLabel(),
                                style: const TextStyle(
                                    color: Color(0xFFFF758F),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5)),
                          ),

                          const Spacer(),

                          // Headline
                          Text(_heroHeadline(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.2)),

                          const SizedBox(height: 6),

                          // Subtitle + play button row
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    songCount == 0
                                        ? 'Tap to scan your library'
                                        : '$songCount songs ready • For $name',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.55),
                                        fontSize: 11),
                                  ),
                                  if (previewSongs.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    _OverlappingAvatarRow(songs: previewSongs),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Glowing neon play button
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFFFF758F)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 20,
                                      spreadRadius: 2),
                                ],
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 26),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Mini row of overlapping circular album art thumbnails
class _OverlappingAvatarRow extends StatelessWidget {
  const _OverlappingAvatarRow({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    const size = 26.0;
    const overlap = 10.0;
    final display = songs.take(4).toList();
    return SizedBox(
      height: size,
      width: (size + (display.length - 1) * (size - overlap)).clamp(size, 120),
      child: Stack(
        children: List.generate(display.length, (i) {
          return Positioned(
            left: i * (size - overlap),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF08070F).withValues(alpha: 0.8),
                    width: 1.5),
              ),
              child: ClipOval(
                child: SongArtwork.fromSong(display[i],
                    size: size, borderRadius: BorderRadius.zero),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smart Pick Card — Dynamic Artwork Banner + Lucid Glass
// ─────────────────────────────────────────────────────────────────────────────

class _SmartPickCard extends StatelessWidget {
  const _SmartPickCard({
    required this.mix,
    this.onTap,
    this.onQuickPlay,
  });

  final SmartMixInfo mix;
  final VoidCallback? onTap;
  final VoidCallback? onQuickPlay;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: mix.accentColor.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dynamic Artwork Banner (Asset image with CustomPainter Fallback)
            SmartMixArtworkView(
              mix: mix,
              borderRadius: 22,
              showVignette: true,
            ),

            // Foreground Text Content & Interactive Play Button
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge top-left
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: mix.accentColor.withValues(alpha: 0.3),
                      border: Border.all(
                          color: mix.accentColor.withValues(alpha: 0.5)),
                    ),
                    child: Icon(mix.icon, color: mix.accentColor, size: 14),
                  ),
                  const Spacer(),

                  // Mix Title
                  Text(
                    mix.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black87,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Song Count and Floating Play Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${mix.songs.length} songs',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Floating Quick-Play Button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onQuickPlay ?? onTap,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: mix.accentColor.withValues(alpha: 0.9),
                            boxShadow: [
                              BoxShadow(
                                color: mix.accentColor.withValues(alpha: 0.6),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rotation Carousel — Tall Lucid Glass Portrait Cards
// ─────────────────────────────────────────────────────────────────────────────

class _RotationCarousel extends ConsumerWidget {
  const _RotationCarousel({required this.songs});
  final List<Song> songs;

  String _moodTag(Song s) {
    if (s.playCount >= 10) return 'Energetic • ${s.playCount} plays';
    if (s.playCount >= 3) return '${s.playCount} plays';
    return 'Fresh Track';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final s = songs[i];
          final isCurrentTrack =
              ref.watch(playerControllerProvider).currentTrack?.id == 'local_${s.id}';

          return GestureDetector(
            onTap: () {
              final track = Track.fromSong(s);
              final queue = songs.map(Track.fromSong).toList();
              ref
                  .read(playerControllerProvider.notifier)
                  .playTrack(track, queue: queue);
            },
            child: Container(
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: isCurrentTrack
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Full-bleed artwork (top 70%)
                    SongArtwork.fromSong(s,
                        width: 140,
                        height: 220,
                        borderRadius: BorderRadius.zero,
                        fit: BoxFit.cover,
                        isCurrent: isCurrentTrack),

                    // Frosted glass footer overlay
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF08070F).withValues(alpha: 0.75),
                              const Color(0xFF08070F).withValues(alpha: 0.95),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(s.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: (isCurrentTrack
                                        ? const Color(0xFF00E5FF)
                                        : const Color(0xFF8B5CF6))
                                    .withValues(alpha: 0.2),
                              ),
                              child: Text(_moodTag(s),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: isCurrentTrack
                                          ? const Color(0xFF00E5FF)
                                          : const Color(0xFF8B5CF6),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Glass play button — bottom-right of image area
                    Positioned(
                      right: 8,
                      bottom: 60,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8)
                          ],
                        ),
                        child: Icon(
                          isCurrentTrack
                              ? Icons.equalizer_rounded
                              : Icons.play_arrow_rounded,
                          color: isCurrentTrack
                              ? const Color(0xFF00E5FF)
                              : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),

                    // Active track highlight border
                    if (isCurrentTrack)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
                              width: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Artists in Your Orbit — Circular Avatar Row
// ─────────────────────────────────────────────────────────────────────────────

class _ArtistsOrbitRow extends StatelessWidget {
  const _ArtistsOrbitRow({
    required this.artists,
    required this.ref,
    required this.allSongs,
  });
  final List<Song> artists;
  final WidgetRef ref;
  final List<Song> allSongs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: artists.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final song = artists[i];
          return GestureDetector(
            onTap: () {
              final artistSongs = allSongs.where((s) => s.artist == song.artist).toList();
              if (artistSongs.isNotEmpty) {
                final tracks = artistSongs.map(Track.fromSong).toList();
                ref
                    .read(playerControllerProvider.notifier)
                    .playTrack(tracks.first, queue: tracks);
              }
            },
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                    border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        width: 1.5),
                  ),
                  child: ClipOval(
                    child: SongArtwork.fromSong(song,
                        size: 60, borderRadius: BorderRadius.zero),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: Text(song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recently Played List
// ─────────────────────────────────────────────────────────────────────────────

class _RecentList extends ConsumerWidget {
  const _RecentList({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final display = songs.take(8).toList();

    return Column(
      children: display.map((s) {
        final isCurrentTrack =
            ref.watch(playerControllerProvider).currentTrack?.id == 'local_${s.id}';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: GestureDetector(
            onTap: () {
              final track = Track.fromSong(s);
              ref
                  .read(playerControllerProvider.notifier)
                  .playTrack(track, queue: [track]);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isCurrentTrack
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                    color: isCurrentTrack
                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.07)),
              ),
              child: Row(children: [
                SongArtwork.fromSong(s,
                    size: 44,
                    borderRadius: BorderRadius.circular(10),
                    isCurrent: isCurrentTrack),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        Text(s.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.5))),
                      ]),
                ),
                if (isCurrentTrack)
                  const Icon(Icons.equalizer_rounded,
                      color: Color(0xFF8B5CF6), size: 18)
                else
                  Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.3), size: 20),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Bottom Nav Bar (5 tabs)
// ─────────────────────────────────────────────────────────────────────────────

class _GlassBottomNav extends StatelessWidget {
  const _GlassBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0C18).withValues(alpha: 0.92),
        border:
            Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isActive: selectedIndex == 0,
                  onTap: () => onTap(0)),
              _NavItem(
                  icon: Icons.library_music_rounded,
                  label: 'Library',
                  isActive: selectedIndex == 1,
                  onTap: () => onTap(1)),
              _NavItem(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  isActive: selectedIndex == 2,
                  onTap: () => onTap(2)),
              _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isActive: selectedIndex == 3,
                  onTap: () => onTap(3)),
              _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isActive: selectedIndex == 4,
                  onTap: () => onTap(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isActive
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
            child: Icon(icon,
                size: 22,
                color: isActive
                    ? const Color(0xFF8B5CF6)
                    : Colors.white.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? const Color(0xFF8B5CF6)
                      : Colors.white.withValues(alpha: 0.4))),
        ]),
      ),
    );
  }
}
