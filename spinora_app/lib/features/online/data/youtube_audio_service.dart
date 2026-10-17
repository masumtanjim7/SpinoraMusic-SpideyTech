import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../../core/database/app_database.dart';

/// Service wrapping [YoutubeExplode] to provide online YouTube audio search
/// and direct live audio stream URL extraction.
class YoutubeAudioService {
  YoutubeAudioService({YoutubeExplode? ytClient})
      : _yt = ytClient ?? YoutubeExplode();

  final YoutubeExplode _yt;

  /// Generates a deterministic virtual negative integer ID from a YouTube video ID
  /// so it never collides with positive Drift auto-increment IDs.
  static int generateVirtualId(String videoId) {
    return -1 * (videoId.hashCode.abs() % 2147483647 + 1);
  }

  /// Searches YouTube videos matching [query], filters out overly long mixes,
  /// and maps each result into a unified Drift [Song] data model.
  Future<List<Song>> searchSongs(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    try {
      final searchResults = await _yt.search.search(trimmed);
      final songs = <Song>[];

      for (final video in searchResults) {
        // Filter out live streams or mixes longer than 25 minutes
        final duration = video.duration;
        if (duration != null && duration.inMinutes > 25) {
          continue;
        }

        // High resolution thumbnail fallback
        final thumbnail = video.thumbnails.highResUrl.isNotEmpty
            ? video.thumbnails.highResUrl
            : video.thumbnails.standardResUrl;

        songs.add(
          Song(
            id: generateVirtualId(video.id.value),
            title: video.title,
            artist: video.author,
            album: 'YouTube Stream',
            duration: duration?.inMilliseconds ?? 0,
            filePath: 'yt://${video.id.value}',
            albumArtPath: thumbnail,
            isFavorite: false,
            playCount: 0,
            isCustomEdited: false,
            isHidden: false,
          ),
        );
      }

      return List.unmodifiable(songs);
    } catch (e, st) {
      debugPrint(
          '[YoutubeAudioService] Error searching videos for "$query": $e');
      if (kDebugMode) {
        debugPrint(st.toString());
      }
      return const [];
    }
  }

  /// Fetches the video stream manifest and selects the best audio-only stream,
  /// returning its direct media playback URL.
  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      final audioOnlyStreams = manifest.audioOnly;
      if (audioOnlyStreams.isNotEmpty) {
        final bestAudio = audioOnlyStreams.withHighestBitrate();
        return bestAudio.url.toString();
      }

      // Fallback to muxed audio stream if audio-only is not returned
      final bestFallback = manifest.audio.withHighestBitrate();
      return bestFallback.url.toString();
    } catch (e, st) {
      debugPrint(
          '[YoutubeAudioService] Error extracting audio stream for $videoId: $e');
      if (kDebugMode) {
        debugPrint(st.toString());
      }
      rethrow;
    }
  }

  void dispose() {
    _yt.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final youtubeAudioServiceProvider = Provider<YoutubeAudioService>((ref) {
  final service = YoutubeAudioService();
  ref.onDispose(service.dispose);
  return service;
});

final onlineSearchResultsProvider =
    FutureProvider.family<List<Song>, String>((ref, query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];
  final service = ref.watch(youtubeAudioServiceProvider);
  return service.searchSongs(trimmed);
});
