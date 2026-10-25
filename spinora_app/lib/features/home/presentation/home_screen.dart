import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/track.dart';
import '../../../core/database/app_database.dart';
import '../../../features/library/data/audio_scanner_service.dart';
import '../../../features/player/application/player_controller.dart';
import '../../../features/profile/application/user_profile_provider.dart';
import '../../../features/profile/presentation/edit_profile_sheet.dart';
import '../../../shared/live_audio_waveform.dart';
import '../../library/presentation/widgets/song_artwork.dart';
import '../application/smart_mixes_provider.dart';
import '../../../core/navigation/lucid_page_transition.dart';
import '../../../core/widgets/lucid_cascade_item.dart';
import '../../../core/widgets/lucid_pressable_card.dart';
import 'main_scaffold.dart';
import 'smart_mix_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen — Lucid Glass Personalized Dashboard
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const MainScaffold();
  }
}

/// The main dashboard body view hosted within [MainScaffold]'s tab 0.
class HomeDashboardView extends ConsumerWidget {
  const HomeDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;

    return Stack(
      children: [
        _buildAmbientBlobs(context),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              LucidCascadeItem(
                index: 0,
                triggerKey: ref.watch(
                  tabEntryTicksProvider.select((t) => t[0]),
                ),
                child: _TopHeader(profile: profile),
              ),
              Expanded(child: _DashboardBody(profile: profile)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmbientBlobs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned(
          top: -40,
          left: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED))
                      .withValues(alpha: isDark ? 0.18 : 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 200,
          right: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFFFF758F) : const Color(0xFFFF85A1))
                      .withValues(alpha: isDark ? 0.12 : 0.07),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: 40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFF3B82F6) : const Color(0xFF60A5FA))
                      .withValues(alpha: isDark ? 0.1 : 0.06),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
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
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'SPINORA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _greeting(),
                style: tt.labelSmall?.copyWith(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.45)
                      : const Color(0xFF5C6275),
                ),
              ),
              Text(
                name,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF0F111A),
                ),
              ),
            ],
          ),
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
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: avatarPath == null
                  ? const Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
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
    ref
        .read(playerControllerProvider.notifier)
        .playTrack(tracks.first, queue: tracks);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(localSongsStreamProvider);
    final recentAsync = ref.watch(recentlyPlayedSongsStreamProvider);
    final playerState = ref.watch(playerControllerProvider);
    final smartMixes = ref.watch(smartMixesProvider);
    final tick = ref.watch(tabEntryTicksProvider.select((t) => t[0]));

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : const Color(0xFF5C6275);

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomPad = bottomInset + (hasMiniplayer ? 150.0 : 100.0);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, 20, 0, bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 20),

          // ── Hero Card
          LucidCascadeItem(
            index: 1,
            triggerKey: tick,
            child: _HeroCard(
              allSongs: allSongs,
              recentSongs: recentSongs,
              profile: profile,
            ),
          ),
          const SizedBox(height: 24),

          // ── Smart Picks
          LucidCascadeItem(
            index: 2,
            triggerKey: tick,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'SMART PICKS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                            LucidGlassPageRoute<void>(
                              builder: (_) => SmartMixDetailScreen(mix: mix),
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
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Your Rotation (tall portrait cards)
          if (rotation.isNotEmpty) ...[
            LucidCascadeItem(
              index: 3,
              triggerKey: tick,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'YOUR ROTATION',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: labelColor,
                                  letterSpacing: 1.6,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/library'),
                          child: Text(
                            'See all',
                            style: TextStyle(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RotationCarousel(songs: rotation),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],

          // ── Artists in Your Orbit
          if (topArtists.isNotEmpty) ...[
            LucidCascadeItem(
              index: 4,
              triggerKey: tick,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'ARTISTS IN YOUR ORBIT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: labelColor,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ArtistsOrbitRow(
                    artists: topArtists,
                    ref: ref,
                    allSongs: allSongs,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],

          // ── Recently Played
          if (recentSongs.isNotEmpty) ...[
            LucidCascadeItem(
              index: 5,
              triggerKey: tick,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'RECENTLY PLAYED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: labelColor,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RecentList(songs: recentSongs),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Moonlit Cosmic Hero Painter
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Cinematic Time-of-Day Matrix & Models
// ─────────────────────────────────────────────────────────────────────────────

enum _TimeSlot { morning, afternoon, evening, night }

class _HeroSlotData {
  const _HeroSlotData({
    required this.slot,
    required this.badge,
    required this.subtitle,
    required this.headlines,
    required this.gradientColors,
    required this.accentColor,
    required this.orbColor,
  });

  final _TimeSlot slot;
  final String badge;
  final String subtitle;
  final List<String> headlines;
  final List<Color> gradientColors;
  final Color accentColor;
  final Color orbColor;

  static _HeroSlotData resolve(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) {
      // Morning (5:00 AM – 12:00 PM)
      return const _HeroSlotData(
        slot: _TimeSlot.morning,
        badge: 'MORNING FLOW',
        subtitle: 'Fresh and Energizing',
        headlines: [
          'Rise and shine with a soundtrack.',
          'Brewing up your morning mix.',
          'Start the day on the right note.',
        ],
        gradientColors: [Color(0xFFFF9E44), Color(0xFFFF5E7E)],
        accentColor: Color(0xFFFF9E44),
        orbColor: Color(0xFFFFD56B),
      );
    } else if (hour >= 12 && hour < 17) {
      // Afternoon (12:00 PM – 5:00 PM)
      return const _HeroSlotData(
        slot: _TimeSlot.afternoon,
        badge: 'MIDDAY GROOVE',
        subtitle: 'Upbeat and Focused',
        headlines: [
          'Power through the afternoon.',
          'Keep the momentum going.',
          'Your midday rhythm is ready.',
        ],
        gradientColors: [Color(0xFF00D2FF), Color(0xFF7A5CFF)],
        accentColor: Color(0xFF00D2FF),
        orbColor: Color(0xFF70E1FF),
      );
    } else if (hour >= 17 && hour < 21) {
      // Evening (5:00 PM – 9:00 PM)
      return const _HeroSlotData(
        slot: _TimeSlot.evening,
        badge: 'GOLDEN HOUR',
        subtitle: 'Warm and Mellow',
        headlines: [
          'Ease into the evening.',
          'Chasing the sunset vibes.',
          'Unwind from the day\'s noise.',
        ],
        gradientColors: [Color(0xFFFF4E88), Color(0xFF6A1B9A)],
        accentColor: Color(0xFFFF4E88),
        orbColor: Color(0xFFFF758F),
      );
    } else {
      // Night (9:00 PM – 5:00 AM)
      return const _HeroSlotData(
        slot: _TimeSlot.night,
        badge: 'LATE NIGHT VIBES',
        subtitle: 'Cozy and Amazing',
        headlines: [
          'Stay a little after hours.',
          'Lost in the midnight frequencies.',
          'Soundtracks for the quiet hours.',
        ],
        gradientColors: [Color(0xFF9D50BB), Color(0xFFFF5E99)],
        accentColor: Color(0xFF8B5CF6),
        orbColor: Color(0xFFE0E7FF),
      );
    }
  }

  String headlineFor(DateTime now) {
    // Deterministically pick based on day of year & hour slot so it's stable throughout the hour/session
    final index = (now.year * 366 + now.day + now.hour) % headlines.length;
    return headlines[index];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cinematic Time-of-Day Canvas Painter
// ─────────────────────────────────────────────────────────────────────────────

class _CinematicHeroPainter extends CustomPainter {
  const _CinematicHeroPainter({
    required this.slotData,
    required this.animValue,
    required this.isPlaying,
    required this.tiltOffset,
  });

  final _HeroSlotData slotData;
  final double animValue; // 0.0 -> 1.0 continuous ticker
  final bool isPlaying;
  final Offset tiltOffset; // -1.0 .. 1.0 parallax normalized

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pulse = math.sin(animValue * 2 * math.pi);
    final orbPulseScale = isPlaying
        ? 1.0 + (pulse * 0.14)
        : 1.0 + (pulse * 0.05);

    // Parallax displacements
    final midShiftX = tiltOffset.dx * 6.0;
    final midShiftY = tiltOffset.dy * 4.0;

    // ── 1. Sky Gradient Base
    final skyGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        slotData.gradientColors.first.withValues(alpha: 0.35),
        slotData.gradientColors.last.withValues(alpha: 0.20),
        const Color(0xFF08070F).withValues(alpha: 0.90),
      ],
      stops: const [0.0, 0.45, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = skyGradient.createShader(rect));

    // ── 2. Time-Slot Specific Celestial Sky & Dynamics
    switch (slotData.slot) {
      case _TimeSlot.morning:
        _paintMorningSky(canvas, size, animValue, orbPulseScale);
        break;
      case _TimeSlot.afternoon:
        _paintAfternoonSky(canvas, size, animValue, isPlaying);
        break;
      case _TimeSlot.evening:
        _paintEveningSky(canvas, size, animValue, orbPulseScale);
        break;
      case _TimeSlot.night:
        _paintNightSky(canvas, size, animValue, orbPulseScale);
        break;
    }

    // ── 3. Middle Animated Hills (with parallax shift)
    _paintMiddleHills(canvas, size, animValue, midShiftX, midShiftY);

    // ── 4. Foreground Silhouette Hills
    _paintForegroundSilhouettes(canvas, size);

    // ── 5. Time-Slot Foreground Particle Accents
    if (slotData.slot == _TimeSlot.morning) {
      _paintMorningDewParticles(canvas, size, animValue);
    } else if (slotData.slot == _TimeSlot.evening) {
      _paintEveningFireflies(canvas, size, animValue);
    }
  }

  void _paintMorningSky(Canvas canvas, Size size, double t, double pulseScale) {
    // Rising sun ascending slightly in top-right
    final sunCenter = Offset(
      size.width * 0.82,
      size.height * (0.24 - math.sin(t * math.pi) * 0.04),
    );
    final sunRadius = 20.0 * pulseScale;

    // Sun outer halo
    final haloPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              slotData.orbColor.withValues(alpha: 0.45),
              const Color(0xFFFF9E44).withValues(alpha: 0.20),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: sunCenter, radius: sunRadius * 3.5),
          );
    canvas.drawCircle(sunCenter, sunRadius * 3.5, haloPaint);

    // Sun core
    final sunPaint = Paint()
      ..color = slotData.orbColor.withValues(alpha: 0.95)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // Horizontal drifting fog / mist layers
    for (int i = 0; i < 3; i++) {
      final layerShift = (t + i * 0.33) % 1.0;
      final mistY = size.height * (0.50 + i * 0.08);
      final mistPath = Path();
      mistPath.moveTo(-size.width * 0.2, mistY);
      for (double x = -size.width * 0.2; x <= size.width * 1.2; x += 12) {
        final yOffset =
            math.sin(
              (x / size.width) * 4 * math.pi + layerShift * 2 * math.pi,
            ) *
            6;
        mistPath.lineTo(x, mistY + yOffset);
      }
      mistPath.lineTo(size.width * 1.2, mistY + 22);
      mistPath.lineTo(-size.width * 0.2, mistY + 22);
      mistPath.close();

      final mistPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.06 - (i * 0.015))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(mistPath, mistPaint);
    }
  }

  void _paintMorningDewParticles(Canvas canvas, Size size, double t) {
    final rng = math.Random(101);
    for (int i = 0; i < 18; i++) {
      final baseX = rng.nextDouble() * size.width;
      final speed = 0.3 + (rng.nextDouble() * 0.7);
      final currentY =
          (size.height * 0.95) -
          (((t * speed + (i * 0.055)) % 1.0) * size.height * 0.65);
      final driftX = baseX + math.sin(t * 2 * math.pi + i) * 12;
      final particleAlpha =
          ((math.sin(t * 2 * math.pi + i) + 1) / 2) * 0.5 + 0.15;
      final dewRadius = 1.2 + (rng.nextDouble() * 1.8);

      final pPaint = Paint()
        ..color = const Color(0xFFFFE082)
            .withValues(alpha: particleAlpha.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawCircle(Offset(driftX, currentY), dewRadius, pPaint);
    }
  }

  void _paintAfternoonSky(Canvas canvas, Size size, double t, bool isPlaying) {
    // Breeze wind lines sweeping across the upper sky
    final breezePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2;

    for (int i = 0; i < 4; i++) {
      final lineProgress = (t * (isPlaying ? 1.4 : 0.8) + i * 0.25) % 1.0;
      final startX = -60.0 + lineProgress * (size.width + 120.0);
      final y = size.height * (0.18 + i * 0.11);
      final length = 45.0 + (i * 12.0);

      breezePaint.color = const Color(0xFF00D2FF).withValues(
        alpha: (0.15 + (math.sin(lineProgress * math.pi) * 0.25)).clamp(
          0.0,
          1.0,
        ),
      );
      final path = Path();
      path.moveTo(startX, y);
      path.quadraticBezierTo(
        startX + (length * 0.5),
        y - 4,
        startX + length,
        y + 2,
      );
      canvas.drawPath(path, breezePaint);
    }
  }

  void _paintEveningSky(Canvas canvas, Size size, double t, double pulseScale) {
    // Synthwave melting sun behind ridges
    final sunCenter = Offset(size.width * 0.76, size.height * 0.52);
    final sunRadius = 26.0 * pulseScale;

    // Glowing sun rays / disc
    final sunPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFD166),
              const Color(0xFFFF4E88).withValues(alpha: 0.9),
              Colors.transparent,
            ],
            stops: const [0.3, 0.7, 1.0],
          ).createShader(
            Rect.fromCircle(center: sunCenter, radius: sunRadius * 2.2),
          );
    canvas.drawCircle(sunCenter, sunRadius * 2.2, sunPaint);

    // Synthwave horizontal blinds cutouts on sun
    final cutPaint = Paint()
      ..color = const Color(0xFF08070F).withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final y = sunCenter.dy + (i * 4.5);
      canvas.drawLine(
        Offset(sunCenter.dx - sunRadius, y),
        Offset(sunCenter.dx + sunRadius, y),
        cutPaint,
      );
    }

    // Tiny flock of minimal vector birds gliding across upper sky
    final birdSpeed = (t * 0.35) % 1.0;
    final flockX = -40 + birdSpeed * (size.width + 80);
    final birdPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final bx = flockX - (i * 14.0);
      final by =
          size.height * 0.22 + (i * 6.0) + math.sin(t * 4 * math.pi + i) * 3;
      final wingPath = Path();
      wingPath.moveTo(bx - 4, by - 2);
      wingPath.quadraticBezierTo(bx - 2, by, bx, by - 2);
      wingPath.quadraticBezierTo(bx + 2, by, bx + 4, by - 2);
      canvas.drawPath(wingPath, birdPaint);
    }
  }

  void _paintEveningFireflies(Canvas canvas, Size size, double t) {
    // Organic wandering firefly specks around the lower right (play button vicinity)
    final rng = math.Random(77);
    final targetArea = Offset(size.width * 0.82, size.height * 0.78);

    for (int i = 0; i < 8; i++) {
      final angle =
          rng.nextDouble() * 2 * math.pi +
          (t * 2 * math.pi * (i.isEven ? 1 : -1));
      final radius = 12.0 + rng.nextDouble() * 38.0;
      final fx = targetArea.dx + math.cos(angle) * radius;
      final fy = targetArea.dy + math.sin(angle) * (radius * 0.65);
      final twinkle = ((math.sin(t * 6 * math.pi + i * 2) + 1) / 2) * 0.8 + 0.2;

      final fPaint = Paint()
        ..color = const Color(0xFFFFF176)
            .withValues(alpha: twinkle.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(Offset(fx, fy), 1.8, fPaint);
    }
  }

  void _paintNightSky(Canvas canvas, Size size, double t, double pulseScale) {
    // 1. Drifting aurora borealis ribbon
    for (int i = 0; i < 3; i++) {
      final phase = t * 2 * math.pi + i * (2 * math.pi / 3);
      final waveY = size.height * 0.36 + math.sin(phase) * 12;
      final path = Path();
      path.moveTo(0, waveY);
      for (double x = 0; x <= size.width; x += 6) {
        final y =
            waveY +
            math.sin((x / size.width) * math.pi * 2.8 + phase) * 16 -
            (i * 12);
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height * 0.85);
      path.lineTo(0, size.height * 0.85);
      path.close();

      final auroraColors = [
        const Color(0xFF8B5CF6).withValues(alpha: 0.16),
        const Color(0xFF00D2FF).withValues(alpha: 0.10),
        const Color(0xFF10B981).withValues(alpha: 0.06),
      ];

      final aPaint = Paint()
        ..shader = LinearGradient(
          colors: [auroraColors[i % auroraColors.length], Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(path, aPaint);
    }

    // 2. Twinkling starfield dots
    final rng = math.Random(54);
    for (int i = 0; i < 22; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * (size.height * 0.58);
      final twinkle =
          ((math.sin(t * 4 * math.pi + (i * 1.7)) + 1) / 2) * 0.7 + 0.15;
      final sRadius = 0.8 + (rng.nextDouble() * 1.2);

      final sPaint = Paint()
        ..color = Colors.white.withValues(alpha: twinkle.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(sx, sy), sRadius, sPaint);
    }

    // 3. Diagonal shooting star every 8 seconds (derived from animValue looping over 8s)
    final shootingProgress = (t * 2.5) % 1.0;
    if (shootingProgress < 0.35) {
      final prog = shootingProgress / 0.35;
      final startX = size.width * 0.95 - (prog * size.width * 0.6);
      final startY = size.height * 0.05 + (prog * size.height * 0.45);
      final tailLength = 40.0 * (1.0 - prog);

      final shootPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: (1.0 - prog).clamp(0.0, 1.0)),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(startX, startY, tailLength, tailLength))
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + tailLength * 0.8, startY - tailLength * 0.5),
        shootPaint,
      );
    }

    // 4. Breathing halo glowing moon in top-right
    final moonCenter = Offset(size.width * 0.80, size.height * 0.22);
    final moonRadius = 16.0 * pulseScale;

    // Glowing halo
    final haloPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFC4B5FD).withValues(alpha: 0.35),
              const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: moonCenter, radius: moonRadius * 3.2),
          );
    canvas.drawCircle(moonCenter, moonRadius * 3.2, haloPaint);

    // Moon body
    final moonPaint = Paint()
      ..color = const Color(0xFFF8FAFC).withValues(alpha: 0.95)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(moonCenter, moonRadius, moonPaint);

    // Subtle moon crater shadow
    final craterPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.25);
    canvas.drawCircle(
      Offset(moonCenter.dx + 4, moonCenter.dy - 3),
      4,
      craterPaint,
    );
    canvas.drawCircle(
      Offset(moonCenter.dx - 3, moonCenter.dy + 4),
      3,
      craterPaint,
    );
  }

  void _paintMiddleHills(
    Canvas canvas,
    Size size,
    double t,
    double shiftX,
    double shiftY,
  ) {
    final hillPath = Path();
    final isAfternoon = slotData.slot == _TimeSlot.afternoon;

    // If afternoon, audio-reactive / lively sine wave hill curves that speed up with playback
    final speedMultiplier = (isAfternoon && isPlaying) ? 2.2 : 1.0;
    final wavePhase = t * 2 * math.pi * speedMultiplier;

    hillPath.moveTo(0, size.height * 0.65 + shiftY);
    for (double x = 0; x <= size.width; x += 8) {
      final normX = x / size.width;
      final ripple = isAfternoon
          ? math.sin(normX * 4 * math.pi + wavePhase) * 6
          : math.sin(normX * 2 * math.pi + wavePhase * 0.5) * 3;
      final y =
          (size.height * 0.60) +
          (math.sin(normX * math.pi) * 14) +
          ripple +
          shiftY;
      hillPath.lineTo(x + shiftX, y);
    }
    hillPath.lineTo(size.width + shiftX, size.height);
    hillPath.lineTo(shiftX, size.height);
    hillPath.close();

    final hillColor = slotData.slot == _TimeSlot.night
        ? const Color(0xFF130E26)
        : (slotData.slot == _TimeSlot.morning
              ? const Color(0xFF2E1530)
              : const Color(0xFF1E1435));

    final hillPaint = Paint()
      ..shader =
          LinearGradient(
            colors: [
              hillColor.withValues(alpha: 0.65),
              const Color(0xFF08070F).withValues(alpha: 0.85),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
          );

    canvas.drawPath(hillPath, hillPaint);
  }

  void _paintForegroundSilhouettes(Canvas canvas, Size size) {
    // Signature card silhouette hill structure
    final fgPath = Path();
    fgPath.moveTo(0, size.height * 0.74);
    fgPath.cubicTo(
      size.width * 0.25,
      size.height * 0.66,
      size.width * 0.55,
      size.height * 0.72,
      size.width,
      size.height * 0.68,
    );
    fgPath.lineTo(size.width, size.height);
    fgPath.lineTo(0, size.height);
    fgPath.close();

    final fgPaint = Paint()
      ..shader =
          LinearGradient(
            colors: [
              const Color(0xFF0D0A1A).withValues(alpha: 0.75),
              const Color(0xFF08070F).withValues(alpha: 0.95),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4),
          );

    canvas.drawPath(fgPath, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _CinematicHeroPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Card — Layered Lucid Glass Visual Hero Banner with 3D Tilt & Micro-Interactions
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
  late final AnimationController _tickerCtrl;
  Offset _tilt = Offset.zero; // Parallax normalized (-1.0 to 1.0)
  Offset _simulatedTilt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _tickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _tickerCtrl.dispose();
    super.dispose();
  }

  void _updatePointerTilt(Offset localPos, Size size) {
    final dx = ((localPos.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
    final dy = ((localPos.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);
    setState(() => _tilt = Offset(dx, dy));
  }

  void _resetPointerTilt() {
    setState(() => _tilt = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final songCount = widget.allSongs.length;
    final name = widget.profile?.displayName ?? 'You';
    final previewSongs = {
      ...widget.recentSongs.take(3),
      ...widget.allSongs.take(3),
    }.take(4).toList();

    final now = DateTime.now();
    final slotData = _HeroSlotData.resolve(now);
    final headline = slotData.headlineFor(now);

    final playerState = ref.watch(playerControllerProvider);
    final currentTrack = playerState.currentTrack;
    final isTrackFromMix =
        currentTrack != null &&
        widget.allSongs.any(
          (s) =>
              currentTrack.id == 'local_${s.id}' ||
              currentTrack.id == 'online_${s.id}' ||
              currentTrack.uri == s.filePath ||
              currentTrack.uri == Uri.file(s.filePath).toString(),
        );
    final isHeroActive = playerState.isPlaying && isTrackFromMix;

    void handlePlayAction() {
      if (widget.allSongs.isEmpty) {
        context.push('/library');
        return;
      }
      if (isHeroActive) {
        ref.read(playerControllerProvider.notifier).togglePlayPause();
      } else if (playerState.hasTrack && isTrackFromMix) {
        ref.read(playerControllerProvider.notifier).togglePlayPause();
      } else {
        ref
            .read(playerControllerProvider.notifier)
            .playPlaylist(widget.allSongs, shuffle: true);
      }
    }

    void openHeroPlaylist() {
      if (widget.allSongs.isEmpty) {
        context.push('/library');
        return;
      }

      final heroMix = SmartMixInfo(
        id: 'library_mix',
        title: headline,
        subtitle: songCount == 0
            ? 'For $name'
            : '$songCount songs ready • For $name',
        assetImagePath: '',
        accentColor: slotData.accentColor,
        secondaryColor: const Color(0xFFFF758F),
        icon: Icons.auto_awesome_rounded,
        songs: widget.allSongs,
      );

      Navigator.of(context).push(
        LucidGlassPageRoute<void>(
          builder: (_) => SmartMixDetailScreen(mix: heroMix),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;
          const cardHeight = 200.0;

          return LucidPressableCard(
            borderRadius: 28,
            onTap: openHeroPlaylist,
            child: MouseRegion(
              onHover: (event) => _updatePointerTilt(
                event.localPosition,
                Size(cardWidth, cardHeight),
              ),
              onExit: (_) => _resetPointerTilt(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SizedBox(
                  height: cardHeight,
                  child: AnimatedBuilder(
                    animation: _tickerCtrl,
                    builder: (context, child) {
                      final t = _tickerCtrl.value;

                      // Gentle idle gyroscope wobble if pointer isn't dragging
                      _simulatedTilt = Offset(
                        math.sin(t * 2 * math.pi) * 0.35,
                        math.cos(t * 2 * math.pi) * 0.25,
                      );
                      final effectiveTilt = _tilt == Offset.zero
                          ? _simulatedTilt
                          : _tilt;

                      // Foreground text/buttons shift opposite to middle hills for 3D depth
                      final fgShiftX = -effectiveTilt.dx * 12.0;
                      final fgShiftY = -effectiveTilt.dy * 8.0;

                      // Glassmorphic pill metallic shimmer cycle (every 5 seconds)
                      final shimmerCycle = (t * (8.0 / 5.0)) % 1.0;

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Layer 1: Time-of-Day Cinematic Animated Canvas
                          CustomPaint(
                            painter: _CinematicHeroPainter(
                              slotData: slotData,
                              animValue: t,
                              isPlaying: isHeroActive,
                              tiltOffset: effectiveTilt,
                            ),
                          ),

                          // Layer 2: Lucid Glass Vignette Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: [
                                  const Color(0xFF1E0A3C)
                                      .withValues(alpha: 0.35),
                                  const Color(0xFF08070F)
                                      .withValues(alpha: 0.78),
                                ],
                              ),
                            ),
                          ),

                          // Layer 3: Glassmorphic Border Glow
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: slotData.accentColor.withValues(
                                  alpha: 0.35,
                                ),
                                width: 1.2,
                              ),
                            ),
                          ),

                          // Layer 4: Foreground Interactive Content (Parallax shifted)
                          Transform.translate(
                            offset: Offset(fgShiftX, fgShiftY),
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Shimmering Badge Pill
                                  _ShimmerBadgePill(
                                    label: slotData.badge,
                                    color: slotData.accentColor,
                                    shimmerProgress: shimmerCycle,
                                  ),

                                  const Spacer(),

                                  // Dynamic Headline (Deterministic per time slot)
                                  Flexible(
                                    child: Text(
                                      headline,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  // Subtitle & Interactive Play Button Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              songCount == 0
                                                  ? 'Tap to scan your library • For $name'
                                                  : '$songCount songs ready • For $name',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.75,
                                                ),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (previewSongs.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              _OverlappingAvatarRow(
                                                songs: previewSongs,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Reactively Glowing / Rotating Play Button
                                      _HeroPlayButton(
                                        isPlaying: isHeroActive,
                                        accentColor: slotData.accentColor,
                                        animValue: t,
                                        onTap: handlePlayAction,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
        },
      ),
    );
  }
}

/// Hero Play Button with Rotating Outer Glow Ring on active playback
class _HeroPlayButton extends StatelessWidget {
  const _HeroPlayButton({
    required this.isPlaying,
    required this.accentColor,
    required this.animValue,
    this.onTap,
  });

  final bool isPlaying;
  final Color accentColor;
  final double animValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rotationAngle = animValue * 2 * math.pi;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Rotating outer glow ring when music is actively playing from this mix
            if (isPlaying)
              Transform.rotate(
                angle: rotationAngle,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.8),
                        const Color(0xFFFF758F).withValues(alpha: 0.2),
                        Colors.transparent,
                        accentColor.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),

            // Core Round Play/Pause Button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentColor, const Color(0xFFFF758F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(
                      alpha: isPlaying ? 0.75 : 0.45,
                    ),
                    blurRadius: isPlaying ? 20 : 12,
                    spreadRadius: isPlaying ? 2 : 1,
                  ),
                ],
              ),
              child: Center(
                child: LiveAudioWaveform(
                  isPlaying: isPlaying,
                  color: Colors.white,
                  size: 22,
                  barCount: 4,
                  pausedIcon: Icons.play_arrow_rounded,
                  pausedIconSize: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmering Badge Pill with a diagonal metallic sweep every 5 seconds
class _ShimmerBadgePill extends StatelessWidget {
  const _ShimmerBadgePill({
    required this.label,
    required this.color,
    required this.shimmerProgress,
  });

  final String label;
  final Color color;
  final double shimmerProgress; // 0.0 -> 1.0

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black.withValues(alpha: 0.35),
              border: Border.all(
                color: color.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          // Metallic diagonal sweep overlay
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final sweepX = -w + (shimmerProgress * (w * 2.5));
                return Transform.translate(
                  offset: Offset(sweepX, 0),
                  child: Transform.rotate(
                    angle: -0.4,
                    child: Container(
                      width: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0.0),
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
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: SongArtwork.fromSong(
                  display[i],
                  size: size,
                  borderRadius: BorderRadius.zero,
                ),
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
  const _SmartPickCard({required this.mix, this.onTap, this.onQuickPlay});

  final SmartMixInfo mix;
  final VoidCallback? onTap;
  final VoidCallback? onQuickPlay;

  @override
  Widget build(BuildContext context) {
    return LucidPressableCard(
      borderRadius: 22,
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
            SmartMixArtworkView(mix: mix, borderRadius: 22, showVignette: true),

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
                        color: mix.accentColor.withValues(alpha: 0.5),
                      ),
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
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
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

bool _isSongActive(PlayerState playerState, Song song) {
  if (!playerState.isPlaying) return false;
  final current = playerState.currentTrack;
  if (current == null) return false;
  return current.id == 'local_${song.id}' ||
      current.id == '${song.id}' ||
      current.id == 'online_${song.id}' ||
      current.uri == song.filePath ||
      current.uri == Uri.file(song.filePath).toString();
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
          final playerState = ref.watch(playerControllerProvider);
          final isTrackActive = _isSongActive(playerState, s);

          return LucidPressableCard(
            borderRadius: 20,
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
                    color: isTrackActive
                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Full-bleed artwork (top 70%)
                    SongArtwork.fromSong(
                      s,
                      width: 140,
                      height: 220,
                      borderRadius: BorderRadius.zero,
                      fit: BoxFit.cover,
                      isCurrent: isTrackActive,
                    ),

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
                            Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color:
                                    (isTrackActive
                                            ? const Color(0xFF00E5FF)
                                            : const Color(0xFF8B5CF6))
                                        .withValues(alpha: 0.2),
                              ),
                              child: Text(
                                _moodTag(s),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isTrackActive
                                      ? const Color(0xFF00E5FF)
                                      : const Color(0xFF8B5CF6),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Glass play button / active waveform indicator — bottom-right of image area
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
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: LiveAudioWaveform(
                          isPlaying: isTrackActive,
                          color: isTrackActive
                              ? const Color(0xFF00E5FF)
                              : Colors.white,
                          size: 16,
                          barCount: 4,
                          pausedIcon: Icons.play_arrow_rounded,
                          pausedIconSize: 16,
                        ),
                      ),
                    ),

                    // Active track highlight border
                    if (isTrackActive)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.7),
                            width: 2,
                          ),
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
              final artistSongs = allSongs
                  .where((s) => s.artist == song.artist)
                  .toList();
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
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: SongArtwork.fromSong(
                      song,
                      size: 60,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF5C6275),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: display.map((s) {
        final playerState = ref.watch(playerControllerProvider);
        final isTrackActive = _isSongActive(playerState, s);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: LucidPressableCard(
            borderRadius: 16,
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
                color: isTrackActive
                    ? const Color(0xFF8B5CF6)
                          .withValues(alpha: isDark ? 0.12 : 0.10)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.white.withValues(alpha: 0.85)),
                border: Border.all(
                  color: isTrackActive
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.white.withValues(alpha: 0.9)),
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  SongArtwork.fromSong(
                    s,
                    size: 44,
                    borderRadius: BorderRadius.circular(10),
                    isCurrent: isTrackActive,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F111A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          s.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : const Color(0xFF5C6275),
                          ),
                        ),
                      ],
                    ),
                  ),
                  LiveAudioWaveform(
                    isPlaying: isTrackActive,
                    color: isTrackActive
                        ? const Color(0xFF8B5CF6)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : const Color(0xFF5C6275).withValues(alpha: 0.6)),
                    size: 20,
                    barCount: 4,
                    pausedIcon: Icons.play_circle_outline_rounded,
                    pausedIconSize: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
