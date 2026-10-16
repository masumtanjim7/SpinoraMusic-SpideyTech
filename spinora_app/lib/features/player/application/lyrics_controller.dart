import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/track.dart';
import '../../../core/database/app_database.dart';
import '../data/online_lyrics_service.dart';

// ---------------------------------------------------------------------------
// Lyrics Fetch State
// ---------------------------------------------------------------------------

@immutable
class LyricsFetchState {
  const LyricsFetchState({
    this.isFetching = false,
    this.activeSongId,
    this.errorMessage,
  });

  final bool isFetching;
  final int? activeSongId;
  final String? errorMessage;

  LyricsFetchState copyWith({
    bool? isFetching,
    int? activeSongId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LyricsFetchState(
      isFetching: isFetching ?? this.isFetching,
      activeSongId: activeSongId ?? this.activeSongId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// Lyrics Controller
// ---------------------------------------------------------------------------

class LyricsController extends Notifier<LyricsFetchState> {
  @override
  LyricsFetchState build() {
    return const LyricsFetchState();
  }

  final Set<int> _inFlightSongIds = {};

  /// Checks if lyrics are already currently being fetched for [songId].
  bool isSongFetching(int songId) =>
      state.isFetching && state.activeSongId == songId;

  /// Triggers background automatic lyrics fetching for a [Track] if not already cached.
  void triggerAutoFetchForTrack(Track track) {
    if (track.source != TrackSource.local || !track.id.startsWith('local_')) {
      return;
    }
    final songId = int.tryParse(track.id.replaceFirst('local_', ''));
    if (songId == null) return;

    Future.microtask(() async {
      try {
        final db = ref.read(appDatabaseProvider);
        final song = await db.getSongById(songId);
        if (song != null) {
          triggerAutoFetch(song);
        }
      } catch (e) {
        debugPrint('[LyricsController] Error auto-fetching for track: $e');
      }
    });
  }

  /// Triggers background automatic lyrics fetching for a [Song] if lyrics are empty.
  void triggerAutoFetch(Song song) {
    // 1. If song already has cached lyrics in Drift, do nothing
    if (song.lyrics != null && song.lyrics!.trim().isNotEmpty) {
      return;
    }

    // 2. If a local .lrc or .txt file exists next to the audio file, do nothing
    try {
      final audioPath = song.filePath;
      final dotIndex = audioPath.lastIndexOf('.');
      final basePath =
          dotIndex != -1 ? audioPath.substring(0, dotIndex) : audioPath;
      if (File('$basePath.lrc').existsSync() ||
          File('$basePath.txt').existsSync()) {
        return;
      }
    } catch (_) {}

    // 3. Avoid duplicate in-flight requests for the same song
    if (_inFlightSongIds.contains(song.id)) {
      return;
    }

    // Run fetch in background
    refetchLyrics(song);
  }

  /// Manually or automatically fetches lyrics from online providers and caches to Drift.
  ///
  /// Returns `true` if lyrics were found and cached, `false` otherwise.
  Future<bool> refetchLyrics(
    Song song, {
    String? customQuery,
  }) async {
    final songId = song.id;
    if (_inFlightSongIds.contains(songId)) return false;

    _inFlightSongIds.add(songId);
    state = state.copyWith(
      isFetching: true,
      activeSongId: songId,
      clearError: true,
    );

    try {
      final onlineService = ref.read(onlineLyricsServiceProvider);
      final db = ref.read(appDatabaseProvider);

      final fetched = await onlineService.fetchLyricsForSong(
        song,
        customQuery: customQuery,
      );

      if (fetched != null && fetched.trim().isNotEmpty) {
        // Save into Drift database permanently for offline use
        await db.updateSongLyrics(songId, fetched.trim());
        state = state.copyWith(
          isFetching: false,
          activeSongId: null,
          clearError: true,
        );
        return true;
      } else {
        state = state.copyWith(
          isFetching: false,
          activeSongId: null,
          errorMessage: 'No lyrics found online for "${customQuery ?? song.title}".',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[LyricsController] Lyrics fetch failed: $e');
      state = state.copyWith(
        isFetching: false,
        activeSongId: null,
        errorMessage: 'Network error fetching lyrics: $e',
      );
      return false;
    } finally {
      _inFlightSongIds.remove(songId);
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

/// Provider for managing online lyrics fetching lifecycle.
final lyricsControllerProvider =
    NotifierProvider<LyricsController, LyricsFetchState>(
  LyricsController.new,
);

/// Exposes whether any lyrics are actively being fetched online.
final isFetchingLyricsProvider = Provider<bool>((ref) {
  return ref.watch(lyricsControllerProvider).isFetching;
});
