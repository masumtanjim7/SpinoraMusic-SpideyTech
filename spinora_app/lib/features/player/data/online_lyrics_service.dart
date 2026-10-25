import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/database/app_database.dart';

// ---------------------------------------------------------------------------
// Cleaned Track Metadata Model
// ---------------------------------------------------------------------------

@immutable
class CleanedTrackMetadata {
  const CleanedTrackMetadata({required this.title, required this.artist});

  final String title;
  final String artist;

  @override
  String toString() =>
      'CleanedTrackMetadata(artist: "$artist", title: "$title")';
}

// ---------------------------------------------------------------------------
// Metadata Cleaning Utilities
// ---------------------------------------------------------------------------

/// Implementation for cleaning raw audio tags and filenames.
String cleanQueryTextHelper(String input) {
  if (input.trim().isEmpty) return '';

  var text = input;

  // 1. Remove common audio file extensions
  text = text.replaceAll(
    RegExp(r'\.(mp3|m4a|flac|wav|ogg|aac|wma|opus)\b', caseSensitive: false),
    '',
  );

  // 2. Remove bracketed / isolated bitrates (e.g. [320kbps], (128 kbps), _320kbps, 320kbps)
  text = text.replaceAll(
    RegExp(
      r'[\(\[\{]?\s*(320|256|192|128)\s*(kbps|kb/s|k)?\s*[\)\]\}]?',
      caseSensitive: false,
    ),
    '',
  );

  // 3. Remove common website watermarks, domains, and audio source tags
  text = text.replaceAll(RegExp(r'www\.[^\s]+', caseSensitive: false), '');
  text = text.replaceAll(
    RegExp(
      r'\[?\b[a-zA-Z0-9_\-]+\.(com|net|org|in|co|pk|me|io|info|biz|site|cc|xyz|club|mp3)\b\]?',
      caseSensitive: false,
    ),
    '',
  );
  text = text.replaceAll(
    RegExp(
      r'\b(pagalworld|djpunjab|songspk|naasongs|mp3mad|hungama|gaana|wynk|mr-jatt|bestwap|masstamilan|sensongs)\b',
      caseSensitive: false,
    ),
    '',
  );

  // 3.5. Convert underscores to spaces (common in filenames before metadata cleaning)
  text = text.replaceAll('_', ' ');

  // 4. Remove bracketed / parenthesized tags like (Official Video), [320kbps], (Lyrics), (Lyrics Video), [Official]
  text = text.replaceAll(
    RegExp(
      r'[\(\[\{]\s*(official(\s*(video|audio|music\s*video|lyric\s*video|lyrics\s*video|4k|hd))?|lyrics?(\s*video)?|visualizer|remastered|remaster|hd|4k|audio|video|full\s*song|clean|explicit|bonus\s*track|version|original)[\)\]\}]',
      caseSensitive: false,
    ),
    '',
  );

  // 5. Remove bracketed featuring tags: (feat. Artist), [ft. Artist]
  text = text.replaceAll(
    RegExp(
      r'[\(\[]\s*(feat|ft|featuring)\.?\s+[^)\]]+[\)\]]',
      caseSensitive: false,
    ),
    '',
  );

  // 6. Remove trailing bare featuring clauses: "Song Title feat. Someone"
  text = text.replaceAll(
    RegExp(r'\b(feat|ft|featuring)\.?\s+.*$', caseSensitive: false),
    '',
  );

  // 7. Remove any empty leftover brackets: [], (), {}
  text = text.replaceAll(RegExp(r'[\(\[\{]\s*[\)\]\}]'), '');

  // 8. Convert underscores to spaces
  text = text.replaceAll('_', ' ');

  // 9. Normalize whitespace and clean outer punctuation / hyphens
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAll(RegExp(r'^[-–—\s/|\\]+|[-–—\s/|\\]+$'), '').trim();

  return text;
}

/// Cleans raw audio tags and filenames by stripping common download watermarks,
/// promotional tags, bitrates, file extensions, and featured artist clutter.
String cleanQueryText(String input) => cleanQueryTextHelper(input);

/// Implementation for normalizing both title and artist.
CleanedTrackMetadata cleanSongMetadataHelper({
  required String rawTitle,
  required String rawArtist,
}) {
  var artist = cleanQueryTextHelper(rawArtist);
  var title = cleanQueryTextHelper(rawTitle);

  final isUnknownArtist =
      artist.isEmpty ||
      artist.toLowerCase() == '<unknown>' ||
      artist.toLowerCase() == 'unknown artist' ||
      artist.toLowerCase() == 'unknown' ||
      artist.toLowerCase() == 'various artists' ||
      artist.toLowerCase() == 'artist';

  if (isUnknownArtist && title.contains(' - ')) {
    final parts = title.split(' - ');
    if (parts.length >= 2) {
      final potentialArtist = cleanQueryTextHelper(parts[0]);
      final potentialTitle = cleanQueryTextHelper(parts.sublist(1).join(' - '));
      if (potentialArtist.isNotEmpty && potentialTitle.isNotEmpty) {
        artist = potentialArtist;
        title = potentialTitle;
      }
    }
  }

  return CleanedTrackMetadata(title: title, artist: artist);
}

/// Normalizes both title and artist, automatically splitting "Artist - Title"
/// if the artist tag is missing, unknown, or generic.
CleanedTrackMetadata cleanSongMetadata({
  required String rawTitle,
  required String rawArtist,
}) => cleanSongMetadataHelper(rawTitle: rawTitle, rawArtist: rawArtist);

// ---------------------------------------------------------------------------
// Online Lyrics Service
// ---------------------------------------------------------------------------

/// Service responsible for querying online lyrics providers (LRCLIB primary,
/// secondary fallback) with smart query sanitization and timeout protection.
class OnlineLyricsService {
  OnlineLyricsService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String _lrclibHost = 'lrclib.net';
  static const String _userAgent =
      'SpinoraMusic/1.0.0 (https://github.com/masumtanjim7)';
  static const Duration _requestTimeout = Duration(seconds: 6);

  /// Strips bracketed tags, extensions, bitrates, and watermarks from [input].
  static String cleanQueryText(String input) => cleanQueryTextHelper(input);

  /// Sanitizes raw song titles and artists, splitting "Artist - Title" if artist is unknown.
  static CleanedTrackMetadata cleanSongMetadata({
    required String rawTitle,
    required String rawArtist,
  }) => cleanSongMetadataHelper(rawTitle: rawTitle, rawArtist: rawArtist);

  /// Fetches lyrics for a given Drift [Song] record.
  ///
  /// Returns raw synced `.lrc` lyrics if available, fallback plain text lyrics,
  /// or `null` if no match is found or if offline.
  Future<String?> fetchLyricsForSong(Song song, {String? customQuery}) async {
    final cleaned = cleanSongMetadata(
      rawTitle: song.title,
      rawArtist: song.artist,
    );

    return fetchLyrics(
      title: cleaned.title,
      artist: cleaned.artist,
      durationMs: song.duration,
      customQuery: customQuery,
    );
  }

  /// Searches for lyrics with sanitized title, artist, and optional duration.
  Future<String?> fetchLyrics({
    required String title,
    required String artist,
    int? durationMs,
    String? customQuery,
  }) async {
    // 1. Step A: Primary search via LRCLIB
    try {
      final lrclibResult = await _searchLrclib(
        title: title,
        artist: artist,
        durationMs: durationMs,
        customQuery: customQuery,
      );
      if (lrclibResult != null && lrclibResult.trim().isNotEmpty) {
        return lrclibResult.trim();
      }
    } catch (e) {
      debugPrint('[OnlineLyricsService] LRCLIB search error: $e');
    }

    // 2. Step B: Secondary fallback search (e.g. lyrics.ovh or secondary public API)
    try {
      final fallbackResult = await _searchFallbackLyrics(
        title: title,
        artist: artist,
      );
      if (fallbackResult != null && fallbackResult.trim().isNotEmpty) {
        return fallbackResult.trim();
      }
    } catch (e) {
      debugPrint('[OnlineLyricsService] Fallback search error: $e');
    }

    return null;
  }

  /// Queries LRCLIB search endpoint.
  Future<String?> _searchLrclib({
    required String title,
    required String artist,
    int? durationMs,
    String? customQuery,
  }) async {
    List<dynamic> items = [];

    final headers = {'User-Agent': _userAgent, 'Accept': 'application/json'};

    if (customQuery != null && customQuery.trim().isNotEmpty) {
      // Direct query via custom user input
      final uri = Uri.https(_lrclibHost, '/api/search', {
        'q': customQuery.trim(),
      });
      items = await _executeLrclibRequest(uri, headers);
    } else {
      // 1. Precise track_name & artist_name query
      if (title.isNotEmpty && artist.isNotEmpty) {
        final uri = Uri.https(_lrclibHost, '/api/search', {
          'track_name': title,
          'artist_name': artist,
        });
        items = await _executeLrclibRequest(uri, headers);
      }

      // 2. If empty, retry with general 'q' search
      if (items.isEmpty && title.isNotEmpty) {
        final query = artist.isNotEmpty ? '$artist $title' : title;
        final uri = Uri.https(_lrclibHost, '/api/search', {'q': query});
        items = await _executeLrclibRequest(uri, headers);
      }
    }

    if (items.isEmpty) return null;

    // Filter and score candidates
    return _pickBestLrclibMatch(items, durationMs: durationMs);
  }

  Future<List<dynamic>> _executeLrclibRequest(
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded;
        }
      }
    } on SocketException {
      // Offline
      return [];
    } on TimeoutException {
      // Network slow/unreachable
      return [];
    } catch (e) {
      debugPrint('[OnlineLyricsService] Request failed for $uri: $e');
    }
    return [];
  }

  /// Selects the best match from LRCLIB results:
  /// - Strongly prioritizes synced lyrics over plain text lyrics (+1000 score).
  /// - Closest duration matching if track duration is known.
  String? _pickBestLrclibMatch(List<dynamic> items, {int? durationMs}) {
    Map<String, dynamic>? bestMatch;
    double bestScore = -double.infinity;

    final targetDurationSec = (durationMs != null && durationMs > 0)
        ? durationMs / 1000.0
        : null;

    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;

      final synced = raw['syncedLyrics'] as String?;
      final plain = raw['plainLyrics'] as String?;

      final hasSynced = synced != null && synced.trim().isNotEmpty;
      final hasPlain = plain != null && plain.trim().isNotEmpty;

      if (!hasSynced && !hasPlain) continue;

      double score = 0.0;

      // Heavy bonus for synced lyrics
      if (hasSynced) {
        score += 1000.0;
      }

      // Duration penalty if duration delta is significant
      final itemDuration = (raw['duration'] as num?)?.toDouble();
      if (targetDurationSec != null &&
          itemDuration != null &&
          itemDuration > 0) {
        final delta = (itemDuration - targetDurationSec).abs();
        score -= delta * 2.0;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = raw;
      }
    }

    if (bestMatch == null) return null;

    final synced = bestMatch['syncedLyrics'] as String?;
    if (synced != null && synced.trim().isNotEmpty) {
      return synced.trim();
    }

    final plain = bestMatch['plainLyrics'] as String?;
    if (plain != null && plain.trim().isNotEmpty) {
      return plain.trim();
    }

    return null;
  }

  /// Secondary fallback lyrics search (lyrics.ovh free public API).
  Future<String?> _searchFallbackLyrics({
    required String title,
    required String artist,
  }) async {
    if (title.isEmpty || artist.isEmpty) return null;

    try {
      final uri = Uri.https(
        'api.lyrics.ovh',
        '/v1/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}',
      );

      final response = await _client
          .get(
            uri,
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final lyrics = decoded['lyrics'] as String?;
          if (lyrics != null && lyrics.trim().isNotEmpty) {
            return lyrics.trim();
          }
        }
      }
    } catch (_) {
      // Fallback is non-fatal
    }

    return null;
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

/// Provider providing the singleton [OnlineLyricsService].
final onlineLyricsServiceProvider = Provider<OnlineLyricsService>((ref) {
  final service = OnlineLyricsService();
  return service;
});
