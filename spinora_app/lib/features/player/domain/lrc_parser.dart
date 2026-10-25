import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/track.dart';
import '../../../core/database/app_database.dart';
import '../application/lyrics_controller.dart';
import '../data/online_lyrics_service.dart';

// ---------------------------------------------------------------------------
// Lyric Line & Parsed Lyrics Models
// ---------------------------------------------------------------------------

/// Represents a single line in a lyrics document with an optional timestamp.
@immutable
class LyricLine {
  const LyricLine({
    required this.timestamp,
    required this.text,
    this.isSynced = true,
  });

  /// Playback timestamp when this lyric line begins.
  final Duration timestamp;

  /// The lyric line text.
  final String text;

  /// Whether this line contains a valid playback timestamp.
  final bool isSynced;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricLine &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          text == other.text &&
          isSynced == other.isSynced;

  @override
  int get hashCode => timestamp.hashCode ^ text.hashCode ^ isSynced.hashCode;

  @override
  String toString() => isSynced ? '[${timestamp.inSeconds}s] $text' : text;
}

/// The result of parsing an LRC or plain text lyrics document.
@immutable
class ParsedLyrics {
  const ParsedLyrics({
    required this.lines,
    required this.isSynced,
    this.title,
    this.artist,
    this.album,
    this.by,
    this.offsetMs = 0,
  });

  final List<LyricLine> lines;
  final bool isSynced;
  final String? title;
  final String? artist;
  final String? album;
  final String? by;
  final int offsetMs;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  /// Finds the index of the active lyric line for the given playback [position].
  ///
  /// Returns -1 if no line is currently active (e.g. before the first lyric line).
  int activeIndexForPosition(Duration position) {
    if (lines.isEmpty || !isSynced) return -1;

    final adjustedPosition = position + Duration(milliseconds: offsetMs);

    if (adjustedPosition < lines.first.timestamp) {
      return -1;
    }

    for (int i = lines.length - 1; i >= 0; i--) {
      if (adjustedPosition >= lines[i].timestamp) {
        return i;
      }
    }

    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedLyrics &&
          runtimeType == other.runtimeType &&
          listEquals(lines, other.lines) &&
          isSynced == other.isSynced &&
          offsetMs == other.offsetMs;

  @override
  int get hashCode => Object.hash(Object.hashAll(lines), isSynced, offsetMs);
}

// ---------------------------------------------------------------------------
// LRC Parser
// ---------------------------------------------------------------------------

/// Lightweight, resilient LRC and plain text lyrics parser.
class LrcParser {
  const LrcParser._();

  static final _timestampRegex = RegExp(
    r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]',
  );
  static final _metadataRegex = RegExp(r'^\[([a-zA-Z]+):(.*)\]$');

  /// Parses standard [mm:ss.xx] / [mm:ss] timestamped lines or falls back to plain lines.
  static ParsedLyrics parse(String rawContent) {
    final cleanContent = rawContent
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final rawLines = cleanContent.split('\n');

    final parsedSyncedLines = <LyricLine>[];
    final plainLines = <String>[];

    String? title;
    String? artist;
    String? album;
    String? by;
    int offsetMs = 0;

    for (final rawLine in rawLines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Check for LRC metadata headers: [ar:Artist], [ti:Title], [offset:100], etc.
      final metaMatch = _metadataRegex.firstMatch(line);
      if (metaMatch != null) {
        final tag = metaMatch.group(1)?.toLowerCase();
        final value = metaMatch.group(2)?.trim() ?? '';
        switch (tag) {
          case 'ti':
            title = value;
            break;
          case 'ar':
            artist = value;
            break;
          case 'al':
            album = value;
            break;
          case 'by':
            by = value;
            break;
          case 'offset':
            offsetMs = int.tryParse(value) ?? 0;
            break;
        }
        continue;
      }

      // Check for timestamp tags in line (supports multiple timestamps: [00:10.00][00:20.00]Chorus)
      final timestampMatches = _timestampRegex.allMatches(line).toList();
      if (timestampMatches.isNotEmpty) {
        final lyricText = line.replaceAll(_timestampRegex, '').trim();

        for (final match in timestampMatches) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);

          int milliseconds = 0;
          final fractionStr = match.group(3);
          if (fractionStr != null) {
            if (fractionStr.length == 1) {
              milliseconds = int.parse(fractionStr) * 100;
            } else if (fractionStr.length == 2) {
              milliseconds = int.parse(fractionStr) * 10;
            } else {
              milliseconds = int.parse(fractionStr.substring(0, 3));
            }
          }

          final totalMs = (minutes * 60 + seconds) * 1000 + milliseconds;
          parsedSyncedLines.add(
            LyricLine(
              timestamp: Duration(milliseconds: totalMs),
              text: lyricText,
              isSynced: true,
            ),
          );
        }
      } else {
        plainLines.add(line);
      }
    }

    // If synced lines were found, sort chronologically
    if (parsedSyncedLines.isNotEmpty) {
      parsedSyncedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return ParsedLyrics(
        lines: List.unmodifiable(parsedSyncedLines),
        isSynced: true,
        title: title,
        artist: artist,
        album: album,
        by: by,
        offsetMs: offsetMs,
      );
    }

    // Fallback: Plain unsynced lyrics
    final unsyncedLines = plainLines
        .map(
          (text) =>
              LyricLine(timestamp: Duration.zero, text: text, isSynced: false),
        )
        .toList();

    return ParsedLyrics(
      lines: List.unmodifiable(unsyncedLines),
      isSynced: false,
      title: title,
      artist: artist,
      album: album,
      by: by,
      offsetMs: offsetMs,
    );
  }
}

// ---------------------------------------------------------------------------
// File Lookup & Lyrics Resolver
// ---------------------------------------------------------------------------

/// Resolves lyrics for a [Song] by checking:
/// Resolves lyrics for a [Song] using a multi-tier fallback system:
/// 1) `song.lyrics` in the database.
/// 2) If empty, checks for a matching `.lrc` or `.txt` file at `song.filePath`.
/// 3) If empty and [onlineLyricsService] is provided, fetches online via LRCLIB / fallback.
/// Automatically caches discovered lyrics into the database for future instant loads.
Future<String?> resolveSongLyrics({
  required Song song,
  required AppDatabase db,
  OnlineLyricsService? onlineLyricsService,
  String? customQuery,
}) async {
  // 1) Database check (unless customQuery was supplied)
  if (customQuery == null &&
      song.lyrics != null &&
      song.lyrics!.trim().isNotEmpty) {
    return song.lyrics;
  }

  // 2) File lookup (.lrc or .txt alongside audio file)
  if (customQuery == null) {
    try {
      final filePath = song.filePath;
      final dotIndex = filePath.lastIndexOf('.');
      final basePath = dotIndex != -1
          ? filePath.substring(0, dotIndex)
          : filePath;

      final lrcFile = File('$basePath.lrc');
      if (lrcFile.existsSync()) {
        final bytes = lrcFile.readAsBytesSync();
        final content = utf8.decode(bytes, allowMalformed: true).trim();
        if (content.isNotEmpty) {
          await db.updateSongLyrics(song.id, content);
          return content;
        }
      }

      final txtFile = File('$basePath.txt');
      if (txtFile.existsSync()) {
        final bytes = txtFile.readAsBytesSync();
        final content = utf8.decode(bytes, allowMalformed: true).trim();
        if (content.isNotEmpty) {
          await db.updateSongLyrics(song.id, content);
          return content;
        }
      }
    } catch (e) {
      // Non-fatal if filesystem lookup fails (e.g. test environment)
    }
  }

  // 3) Online lyrics fetch via LRCLIB / fallback
  if (onlineLyricsService != null) {
    try {
      final onlineLyrics = await onlineLyricsService.fetchLyricsForSong(
        song,
        customQuery: customQuery,
      );
      if (onlineLyrics != null && onlineLyrics.trim().isNotEmpty) {
        await db.updateSongLyrics(song.id, onlineLyrics.trim());
        return onlineLyrics.trim();
      }
    } catch (e) {
      debugPrint('[resolveSongLyrics] Online fetch failed: $e');
    }
  }

  return null;
}

// ---------------------------------------------------------------------------
// Lyrics Riverpod Stream Provider
// ---------------------------------------------------------------------------

/// Watches the lyrics for an active [Track] reactively.
final trackLyricsProvider = StreamProvider.family<ParsedLyrics, Track>((
  ref,
  track,
) {
  // If online track (e.g. YouTube stream)
  if (track.source == TrackSource.online || track.uri.startsWith('yt://')) {
    final cache = ref.watch(onlineLyricsCacheProvider);
    final cached = cache[track.id] ?? cache[track.uri];
    if (cached != null && cached.trim().isNotEmpty) {
      return Stream.value(LrcParser.parse(cached));
    }
    // Auto-trigger online fetch if not in cache
    ref.read(lyricsControllerProvider.notifier).triggerAutoFetchForTrack(track);
    return Stream.value(const ParsedLyrics(lines: [], isSynced: false));
  }

  final db = ref.watch(appDatabaseProvider);

  // Extract song ID if this is a local track (e.g. "local_42")
  final songId = track.id.startsWith('local_')
      ? int.tryParse(track.id.replaceFirst('local_', ''))
      : null;

  if (songId == null) {
    return Stream.value(const ParsedLyrics(lines: [], isSynced: false));
  }

  // Watch reactive song updates from Drift so edits reflect immediately
  return db.watchSongById(songId).asyncMap((song) async {
    if (song != null) {
      final raw = await resolveSongLyrics(song: song, db: db);
      if (raw != null && raw.trim().isNotEmpty) {
        return LrcParser.parse(raw);
      } else {
        // Auto-trigger background online fetch if lyrics are missing
        ref.read(lyricsControllerProvider.notifier).triggerAutoFetch(song);
      }
    }
    return const ParsedLyrics(lines: [], isSynced: false);
  });
});
