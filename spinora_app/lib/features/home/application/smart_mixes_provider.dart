import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../features/library/data/audio_scanner_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smart Mix Info Model
// ─────────────────────────────────────────────────────────────────────────────

class SmartMixInfo {
  final String id;
  final String title;
  final String subtitle;
  final String assetImagePath;
  final Color accentColor;
  final Color secondaryColor;
  final IconData icon;
  final List<Song> songs;

  const SmartMixInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.assetImagePath,
    required this.accentColor,
    required this.secondaryColor,
    required this.icon,
    required this.songs,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Forgotten Favorites Session Cache (Prevents Wild Mid-Session Reordering)
// ─────────────────────────────────────────────────────────────────────────────

class ForgottenFavoritesSessionNotifier extends Notifier<List<int>?> {
  @override
  List<int>? build() => null;

  void setSessionIds(List<int> ids) {
    state = ids;
  }

  void invalidate() {
    state = null;
  }
}

final forgottenFavoritesSessionProvider =
    NotifierProvider<ForgottenFavoritesSessionNotifier, List<int>?>(
      ForgottenFavoritesSessionNotifier.new,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Deterministic Smart Mixes Provider
// ─────────────────────────────────────────────────────────────────────────────

final smartMixesProvider = Provider<List<SmartMixInfo>>((ref) {
  final songsAsync = ref.watch(localSongsStreamProvider);
  final allSongs = songsAsync.value ?? [];
  final songMap = {for (final s in allSongs) s.id: s};

  // 1. Top 10 Most Played (Deterministic)
  final mostPlayed = [...allSongs]
    ..sort((a, b) {
      final pcComp = b.playCount.compareTo(a.playCount);
      if (pcComp != 0) return pcComp;
      return a.id.compareTo(b.id);
    });
  final top10Filtered = mostPlayed
      .where((s) => s.playCount > 0)
      .take(10)
      .toList();
  final top10Final = top10Filtered.isNotEmpty
      ? top10Filtered
      : allSongs.take(10).toList();

  // 2. Forgotten Favorites (Session-memoized, deterministic)
  final sessionIds = ref.watch(forgottenFavoritesSessionProvider);
  List<Song> forgotten;

  if (sessionIds != null &&
      sessionIds.isNotEmpty &&
      sessionIds.every((id) => songMap.containsKey(id))) {
    // Preserve the session-cached order without mutating mid-playback
    forgotten = sessionIds.map((id) => songMap[id]!).toList();
  } else {
    // Select tracks where isFavorite == true sorted by oldest lastPlayedAt (nulls first)
    final favorites = allSongs.where((s) => s.isFavorite).toList()
      ..sort((a, b) {
        if (a.lastPlayedAt == null && b.lastPlayedAt == null) {
          return a.id.compareTo(b.id);
        }
        if (a.lastPlayedAt == null) return -1;
        if (b.lastPlayedAt == null) return 1;
        final dateComp = a.lastPlayedAt!.compareTo(b.lastPlayedAt!);
        if (dateComp != 0) return dateComp;
        return a.id.compareTo(b.id);
      });

    final favIds = favorites.map((s) => s.id).toSet();

    // Fill remaining slots deterministically with playCount == 0 (lowest playCount)
    // sorted by dateAdded ascending (oldest tracks in library, i.e., id ascending)
    final remaining = allSongs.where((s) => !favIds.contains(s.id)).toList()
      ..sort((a, b) {
        final pcComp = a.playCount.compareTo(b.playCount);
        if (pcComp != 0) return pcComp;
        return a.id.compareTo(b.id);
      });

    final needed = math.max(0, 15 - favorites.length);
    forgotten = [...favorites, ...remaining.take(needed)];

    if (forgotten.isNotEmpty) {
      final ids = forgotten.map((s) => s.id).toList();
      Future.microtask(() {
        ref.read(forgottenFavoritesSessionProvider.notifier).setSessionIds(ids);
      });
    }
  }

  // 3. Late Night Chill (Deterministic calm selection)
  final lateNight = [...allSongs]
    ..sort((a, b) {
      // Prioritize duration >= 180s (3 min) tracks, then stable hash
      final durA = a.duration >= 180000 ? 1 : 0;
      final durB = b.duration >= 180000 ? 1 : 0;
      if (durA != durB) return durB.compareTo(durA);
      final hashA =
          (a.title.hashCode ^ (a.artist.hashCode * 31) ^ 0x3B82F6) & 0x7FFFFFFF;
      final hashB =
          (b.title.hashCode ^ (b.artist.hashCode * 31) ^ 0x3B82F6) & 0x7FFFFFFF;
      return hashA.compareTo(hashB);
    });
  final lateNightMix = lateNight.take(15).toList();

  // 4. Spidey Vibe (Signature Spider-Verse Crimson & Electric Violet high-energy mix)
  final spidey = [...allSongs]
    ..sort((a, b) {
      final hashA =
          (a.title.hashCode ^
              (a.artist.hashCode * 17) ^
              (a.id * 101) ^
              0xFF2A5F) &
          0x7FFFFFFF;
      final hashB =
          (b.title.hashCode ^
              (b.artist.hashCode * 17) ^
              (b.id * 101) ^
              0xFF2A5F) &
          0x7FFFFFFF;
      return hashB.compareTo(hashA);
    });
  final spideyMix = spidey.take(15).toList();

  // 5. Full Library (Deterministic by date added / id descending)
  final fullLibrary = [...allSongs]..sort((a, b) => b.id.compareTo(a.id));

  return [
    SmartMixInfo(
      id: 'top_10',
      title: 'Top 10 Most Played',
      subtitle: 'Your most repeated anthems',
      assetImagePath: 'assets/images/top_10_most_played.png',
      accentColor: const Color(0xFF8B5CF6),
      secondaryColor: const Color(0xFFFF758F),
      icon: Icons.trending_up_rounded,
      songs: top10Final,
    ),
    SmartMixInfo(
      id: 'forgotten_favorites',
      title: 'Forgotten Favorites',
      subtitle: 'Rediscover hidden gems from your library',
      assetImagePath: 'assets/images/forgotten_favorites.png',
      accentColor: const Color(0xFFFF758F),
      secondaryColor: const Color(0xFF8B5CF6),
      icon: Icons.history_rounded,
      songs: forgotten,
    ),
    SmartMixInfo(
      id: 'late_night_chill',
      title: 'Late Night Chill',
      subtitle: 'Mellow nocturnal vibes to unwind',
      assetImagePath: 'assets/images/late_night_chill.png',
      accentColor: const Color(0xFF3B82F6),
      secondaryColor: const Color(0xFF06B6D4),
      icon: Icons.nightlight_round,
      songs: lateNightMix,
    ),
    SmartMixInfo(
      id: 'spidey_vibe',
      title: 'Spidey Vibe',
      subtitle: 'Spider-Verse high-octane energy',
      assetImagePath: 'assets/images/spidey_vibe.png',
      accentColor: const Color(0xFFFF2A5F),
      secondaryColor: const Color(0xFF8B5CF6),
      icon: Icons.electric_bolt_rounded,
      songs: spideyMix,
    ),
    SmartMixInfo(
      id: 'full_library',
      title: 'Full Library',
      subtitle: 'All your tracks in one place',
      assetImagePath: 'assets/images/full_library.png',
      accentColor: const Color(0xFF10B981),
      secondaryColor: const Color(0xFF059669),
      icon: Icons.library_music_rounded,
      songs: fullLibrary,
    ),
  ];
});

// ─────────────────────────────────────────────────────────────────────────────
// Smart Mix Artwork View (Image Asset with Bespoke CustomPainter Fallback)
// ─────────────────────────────────────────────────────────────────────────────

class SmartMixArtworkView extends StatelessWidget {
  const SmartMixArtworkView({
    super.key,
    required this.mix,
    this.borderRadius = 22,
    this.showVignette = true,
  });

  final SmartMixInfo mix;
  final double borderRadius;
  final bool showVignette;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dynamic Asset Image with CustomPainter Fallback
          Image.asset(
            mix.assetImagePath,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              return CustomPaint(
                painter: _SmartMixArtPainter(
                  mixId: mix.id,
                  primaryColor: mix.accentColor,
                  secondaryColor: mix.secondaryColor,
                ),
              );
            },
          ),

          // Neon Mesh Glow Overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.3,
                colors: [
                  mix.accentColor.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Frosted Dark Glass Vignette
          if (showVignette)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF08070F).withValues(alpha: 0.45),
                    const Color(0xFF08070F).withValues(alpha: 0.90),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

          // Outer Glass Border
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: mix.accentColor.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bespoke CustomPainter for Each Smart Mix
// ─────────────────────────────────────────────────────────────────────────────

class _SmartMixArtPainter extends CustomPainter {
  const _SmartMixArtPainter({
    required this.mixId,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final String mixId;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Deep cosmic background
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor.withValues(alpha: 0.45),
          const Color(0xFF0A0815),
          secondaryColor.withValues(alpha: 0.35),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    if (mixId == 'spidey_vibe') {
      _paintSpideyVibe(canvas, size);
    } else if (mixId == 'late_night_chill') {
      _paintLateNightChill(canvas, size);
    } else if (mixId == 'forgotten_favorites') {
      _paintForgottenFavorites(canvas, size);
    } else if (mixId == 'top_10') {
      _paintTop10(canvas, size);
    } else {
      _paintFullLibrary(canvas, size);
    }
  }

  void _paintSpideyVibe(Canvas canvas, Size size) {
    // Spider-Verse neon radial core
    final corePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.4, -0.3),
        radius: 0.8,
        colors: [
          primaryColor.withValues(alpha: 0.6),
          secondaryColor.withValues(alpha: 0.2),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, corePaint);

    // Dynamic web-lattice geometric lines
    final linePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width * 0.7, size.height * 0.3);
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi) / 4;
      final end = Offset(
        center.dx + math.cos(angle) * size.width * 0.9,
        center.dy + math.sin(angle) * size.width * 0.9,
      );
      canvas.drawLine(center, end, linePaint);
    }

    for (double r = 25; r < size.width * 0.8; r += 28) {
      final webPath = Path();
      for (int i = 0; i <= 8; i++) {
        final angle = (i * math.pi) / 4;
        final pt = Offset(
          center.dx + math.cos(angle) * r,
          center.dy + math.sin(angle) * r,
        );
        if (i == 0) {
          webPath.moveTo(pt.dx, pt.dy);
        } else {
          webPath.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(webPath, linePaint);
    }
  }

  void _paintLateNightChill(Canvas canvas, Size size) {
    // Moonlit celestial disc
    final moonCenter = Offset(size.width * 0.75, size.height * 0.3);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.7),
          primaryColor.withValues(alpha: 0.2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: moonCenter, radius: 60));
    canvas.drawCircle(moonCenter, 60, glowPaint);

    final moonPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(moonCenter, 20, moonPaint);

    // Mountain silhouettes
    final mountainPath = Path();
    mountainPath.moveTo(0, size.height);
    mountainPath.lineTo(0, size.height * 0.7);
    mountainPath.lineTo(size.width * 0.35, size.height * 0.5);
    mountainPath.lineTo(size.width * 0.65, size.height * 0.65);
    mountainPath.lineTo(size.width, size.height * 0.45);
    mountainPath.lineTo(size.width, size.height);
    mountainPath.close();

    final mountainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          secondaryColor.withValues(alpha: 0.4),
          const Color(0xFF08070F),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(mountainPath, mountainPaint);
  }

  void _paintForgottenFavorites(Canvas canvas, Size size) {
    // Celestial heart/star orb
    final orbCenter = Offset(size.width * 0.7, size.height * 0.35);
    final orbGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.65),
          secondaryColor.withValues(alpha: 0.2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: orbCenter, radius: 70));
    canvas.drawCircle(orbCenter, 70, orbGlow);

    // Concentric rings
    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(orbCenter, 28, ringPaint);
    canvas.drawCircle(orbCenter, 46, ringPaint);

    // Memory wave curve
    final wavePath = Path();
    wavePath.moveTo(0, size.height * 0.6);
    wavePath.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.4,
      size.width,
      size.height * 0.7,
    );
    wavePath.lineTo(size.width, size.height);
    wavePath.lineTo(0, size.height);
    wavePath.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          secondaryColor.withValues(alpha: 0.35),
          const Color(0xFF08070F),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(wavePath, wavePaint);
  }

  void _paintTop10(Canvas canvas, Size size) {
    // High-energy radiant sonic rings
    final center = Offset(size.width * 0.8, size.height * 0.25);
    final coreGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.8),
          secondaryColor.withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 80));
    canvas.drawCircle(center, 80, coreGlow);

    // Dynamic sonic equalizer arcs
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (double r = 20; r <= 60; r += 14) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        math.pi * 0.8,
        math.pi * 0.9,
        false,
        arcPaint,
      );
    }
  }

  void _paintFullLibrary(Canvas canvas, Size size) {
    // Emerald cyber lattice
    final linePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final glow = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomRight,
        radius: 0.9,
        colors: [primaryColor.withValues(alpha: 0.45), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant _SmartMixArtPainter oldDelegate) =>
      oldDelegate.mixId != mixId ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor;
}
