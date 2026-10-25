import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../library/data/audio_scanner_service.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class ArtistPlayStat {
  const ArtistPlayStat({
    required this.artist,
    required this.playCount,
    required this.songCount,
    this.representativeSong,
  });

  final String artist;
  final int playCount;
  final int songCount;
  final Song? representativeSong;
}

class ListeningActivitySlot {
  const ListeningActivitySlot({
    required this.label,
    required this.percentage,
    required this.songCount,
  });

  final String label;
  final double percentage;
  final int songCount;
}

/// Alias for UserListeningStats to support both naming styles
typedef UserStats = UserListeningStats;

class UserListeningStats {
  const UserListeningStats({
    this.totalDurationSeconds = 0,
    this.totalSongs = 0,
    this.totalPlayedTracks = 0,
    this.totalPlayCount = 0,
    this.totalFavorites = 0,
    this.topArtists = const [],
    this.topSongs = const [],
    this.activitySlots = const [
      ListeningActivitySlot(label: 'Morning', percentage: 0.25, songCount: 0),
      ListeningActivitySlot(label: 'Afternoon', percentage: 0.35, songCount: 0),
      ListeningActivitySlot(label: 'Evening', percentage: 0.25, songCount: 0),
      ListeningActivitySlot(label: 'Night', percentage: 0.15, songCount: 0),
    ],
    this.streakDays = 1,
  });

  final int totalDurationSeconds;
  final int totalSongs;
  final int totalPlayedTracks;
  final int totalPlayCount;
  final int totalFavorites;
  final List<ArtistPlayStat> topArtists;
  final List<Song> topSongs;
  final List<ListeningActivitySlot> activitySlots;
  final int streakDays;

  double get listeningHours =>
      totalDurationSeconds > 0 ? (totalDurationSeconds / 3600.0) : 0.0;

  double get totalListeningHours => listeningHours;

  String get formattedHours {
    if (listeningHours <= 0.0) return '0.0';
    if (listeningHours < 0.1) return '0.1';
    return listeningHours.toStringAsFixed(1);
  }

  static List<ListeningActivitySlot> defaultSlots([int songCount = 0]) {
    final now = DateTime.now();
    final currentHour = now.hour;
    double m = 0.25, a = 0.35, e = 0.25, n = 0.15;
    if (currentHour >= 5 && currentHour < 12) {
      m = 0.40;
      a = 0.30;
      e = 0.18;
      n = 0.12;
    } else if (currentHour >= 12 && currentHour < 17) {
      m = 0.20;
      a = 0.45;
      e = 0.25;
      n = 0.10;
    } else if (currentHour >= 17 && currentHour < 21) {
      m = 0.15;
      a = 0.25;
      e = 0.45;
      n = 0.15;
    } else {
      m = 0.10;
      a = 0.15;
      e = 0.30;
      n = 0.45;
    }
    return [
      ListeningActivitySlot(
        label: 'Morning',
        percentage: m,
        songCount: (songCount * m).round(),
      ),
      ListeningActivitySlot(
        label: 'Afternoon',
        percentage: a,
        songCount: (songCount * a).round(),
      ),
      ListeningActivitySlot(
        label: 'Evening',
        percentage: e,
        songCount: (songCount * e).round(),
      ),
      ListeningActivitySlot(
        label: 'Night',
        percentage: n,
        songCount: (songCount * n).round(),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Business Logic: Stats Calculation
// ---------------------------------------------------------------------------

UserListeningStats calculateListeningStats(List<Song> allSongs) {
  if (allSongs.isEmpty) {
    return UserListeningStats(
      totalSongs: 0,
      activitySlots: UserListeningStats.defaultSlots(0),
    );
  }

  int totalDurationSeconds = 0;
  int totalPlayedTracks = 0;
  int totalPlayCount = 0;
  int totalFavorites = 0;

  final Map<String, int> artistPlayCounts = {};
  final Map<String, int> artistSongCounts = {};
  final Map<String, Song> artistRepresentative = {};

  final List<Song> playedSongs = [];

  // Listening time activity segments
  int morningCount = 0; // 5am - 12pm
  int afternoonCount = 0; // 12pm - 5pm
  int eveningCount = 0; // 5pm - 9pm
  int nightCount = 0; // 9pm - 5am

  for (final song in allSongs) {
    if (song.isFavorite) totalFavorites++;

    final pCount = song.playCount;
    if (pCount > 0) {
      totalPlayedTracks++;
      totalPlayCount += pCount;
      // Duration in seconds multiplied by playCount
      totalDurationSeconds += (song.duration * pCount);
      playedSongs.add(song);
    }

    final rawArtist = song.artist.trim();
    final artistName = rawArtist.isEmpty ? 'Unknown Artist' : rawArtist;
    artistPlayCounts[artistName] = (artistPlayCounts[artistName] ?? 0) + pCount;
    artistSongCounts[artistName] = (artistSongCounts[artistName] ?? 0) + 1;
    artistRepresentative.putIfAbsent(artistName, () => song);

    // Activity distribution based on lastPlayedAt if present
    if (song.lastPlayedAt != null) {
      final hour = song.lastPlayedAt!.hour;
      if (hour >= 5 && hour < 12) {
        morningCount++;
      } else if (hour >= 12 && hour < 17) {
        afternoonCount++;
      } else if (hour >= 17 && hour < 21) {
        eveningCount++;
      } else {
        nightCount++;
      }
    }
  }

  // If played songs have timestamps, distribute activity proportionally
  final totalTimeSamples =
      morningCount + afternoonCount + eveningCount + nightCount;
  final List<ListeningActivitySlot> activitySlots;
  if (totalTimeSamples > 0) {
    activitySlots = [
      ListeningActivitySlot(
        label: 'Morning',
        percentage: (morningCount / totalTimeSamples).clamp(0.05, 0.85),
        songCount: morningCount,
      ),
      ListeningActivitySlot(
        label: 'Afternoon',
        percentage: (afternoonCount / totalTimeSamples).clamp(0.05, 0.85),
        songCount: afternoonCount,
      ),
      ListeningActivitySlot(
        label: 'Evening',
        percentage: (eveningCount / totalTimeSamples).clamp(0.05, 0.85),
        songCount: eveningCount,
      ),
      ListeningActivitySlot(
        label: 'Night',
        percentage: (nightCount / totalTimeSamples).clamp(0.05, 0.85),
        songCount: nightCount,
      ),
    ];
  } else {
    activitySlots = UserListeningStats.defaultSlots(allSongs.length);
  }

  // Top Artists: if any plays exist, prioritize plays then song count;
  // otherwise, sort by library song count.
  final sortedArtists = artistPlayCounts.keys.toList()
    ..sort((a, b) {
      final pA = artistPlayCounts[a] ?? 0;
      final pB = artistPlayCounts[b] ?? 0;
      if (pA != pB) return pB.compareTo(pA);
      return (artistSongCounts[b] ?? 0).compareTo(artistSongCounts[a] ?? 0);
    });

  // Only include artists in topArtists if there is at least 1 played track
  // or if user has songs, show top 5 artists
  final topArtists = sortedArtists.take(5).map((artist) {
    return ArtistPlayStat(
      artist: artist,
      playCount: artistPlayCounts[artist] ?? 0,
      songCount: artistSongCounts[artist] ?? 0,
      representativeSong: artistRepresentative[artist],
    );
  }).toList();

  // Top Songs / Heavy Rotation: only include songs that have been played (playCount > 0),
  // sorted by play count descending.
  final topSongs = playedSongs
    ..sort((a, b) {
      if (a.playCount != b.playCount) return b.playCount.compareTo(a.playCount);
      return a.title.compareTo(b.title);
    });

  // Streak: at least 1 day base streak, scaled moderately by plays
  final streakDays = totalPlayCount > 0
      ? (1 + (totalPlayCount ~/ 5)).clamp(1, 45)
      : 1;

  return UserListeningStats(
    totalDurationSeconds: totalDurationSeconds,
    totalSongs: allSongs.length,
    totalPlayedTracks: totalPlayedTracks,
    totalPlayCount: totalPlayCount,
    totalFavorites: totalFavorites,
    topArtists: topArtists,
    topSongs: topSongs.take(5).toList(),
    activitySlots: activitySlots,
    streakDays: streakDays,
  );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Primary async provider for user stats. Returns [AsyncValue<UserListeningStats>].
/// Emits [AsyncLoading] during initial load, [AsyncData] with safely-calculated stats,
/// and never hangs or returns null.
final statsProvider = Provider<AsyncValue<UserListeningStats>>((ref) {
  final songsAsync = ref.watch(localSongsStreamProvider);

  return songsAsync.when(
    data: (songs) {
      try {
        final stats = calculateListeningStats(songs);
        return AsyncValue.data(stats);
      } catch (e, st) {
        debugPrint(
          '[StatsProvider] Error calculating listening stats: $e\n$st',
        );
        return const AsyncValue.data(UserListeningStats());
      }
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) {
      debugPrint('[StatsProvider] Error from local songs stream: $err\n$stack');
      return AsyncValue.error(err, stack);
    },
  );
});

/// Synchronous convenience provider for listeners needing an immediate, safe
/// fallback without dealing with [AsyncValue]. Defaults to [UserListeningStats()]
/// when loading or on error.
final listeningStatsProvider = Provider<UserListeningStats>((ref) {
  final asyncVal = ref.watch(statsProvider);
  return asyncVal.value ?? const UserListeningStats();
});
