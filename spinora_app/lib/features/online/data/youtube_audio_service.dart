import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../../core/database/app_database.dart';

/// Service wrapping [YoutubeExplode] to provide online YouTube audio search
/// and direct live audio streaming via a local HTTP proxy server and temp caching.
class YoutubeAudioService {
  YoutubeAudioService({
    YoutubeExplode? ytClient,
    http.Client? httpClient,
  })  : _yt = ytClient ?? YoutubeExplode(),
        _httpClient = httpClient ?? http.Client();

  final YoutubeExplode _yt;
  final http.Client _httpClient;
  HttpServer? _proxyServer;
  final Map<String, AudioStreamInfo> _activeStreamInfos = {};

  /// Returns the local port the proxy is listening on, if started.
  int? get proxyPort => _proxyServer?.port;

  /// Dedicated temp directory for caching YouTube audio streams.
  Directory get _cacheDir {
    final dir = Directory('${Directory.systemTemp.path}/spinora_yt_cache');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Generates a deterministic virtual negative integer ID from a YouTube video ID
  /// so it never collides with positive Drift auto-increment IDs.
  static int generateVirtualId(String videoId) {
    return -1 * (videoId.hashCode.abs() % 2147483647 + 1);
  }

  /// Ensures the lightweight local loopback HTTP proxy server is running.
  Future<void> _ensureProxyServer() async {
    if (_proxyServer != null) return;
    try {
      _proxyServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      debugPrint('[YoutubeAudioService] Started local audio proxy on http://127.0.0.1:${_proxyServer!.port}');
      _proxyServer!.listen(_handleProxyRequest, onError: (e) {
        debugPrint('[YoutubeAudioService] Local proxy error: $e');
      });
    } catch (e, st) {
      debugPrint('[YoutubeAudioService] Failed to bind local proxy server: $e');
      if (kDebugMode) debugPrint(st.toString());
      rethrow;
    }
  }

  /// Handles incoming HTTP GET/HEAD requests from ExoPlayer.
  Future<void> _handleProxyRequest(HttpRequest request) async {
    try {
      final segments = request.uri.pathSegments;
      if (segments.length != 2 || segments.first != 'stream') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final videoId = segments[1];
      final cacheFile = File('${_cacheDir.path}/yt_$videoId.m4a');

      // 1. If file is already fully cached, serve with full Range support
      if (cacheFile.existsSync() && cacheFile.lengthSync() > 10000) {
        final totalLength = cacheFile.lengthSync();
        final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

        request.response.headers.contentType = ContentType('audio', 'mp4');
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

        if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
          final parts = rangeHeader.substring(6).split('-');
          final start = int.tryParse(parts[0]) ?? 0;
          final end = (parts.length > 1 && parts[1].isNotEmpty)
              ? int.tryParse(parts[1])
              : totalLength - 1;
          final effectiveEnd = (end ?? totalLength - 1).clamp(start, totalLength - 1);
          final chunkLength = effectiveEnd - start + 1;

          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$effectiveEnd/$totalLength',
          );
          request.response.headers.contentLength = chunkLength;

          if (request.method == 'HEAD') {
            await request.response.close();
            return;
          }

          await request.response.addStream(cacheFile.openRead(start, effectiveEnd + 1));
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentLength = totalLength;

        if (request.method == 'HEAD') {
          await request.response.close();
          return;
        }

        await request.response.addStream(cacheFile.openRead());
        await request.response.close();
        return;
      }

      // 2. Not yet cached: stream through _yt.videos.streamsClient.get(streamInfo)
      final streamInfo = _activeStreamInfos[videoId] ?? await _resolveBestStreamInfo(videoId);
      if (streamInfo == null) {
        debugPrint('[YoutubeAudioService] Stream info missing for $videoId');
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final mimeType = streamInfo.codec.mimeType;
      final contentType = mimeType.contains('webm')
          ? ContentType('audio', 'webm')
          : ContentType('audio', 'mp4');

      request.response.headers.contentType = contentType;
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (streamInfo.size.totalBytes > 0) {
        request.response.headers.contentLength = streamInfo.size.totalBytes;
      }

      if (request.method == 'HEAD') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final byteStream = _yt.videos.streamsClient.get(streamInfo);
      final tempFile = File('${_cacheDir.path}/yt_$videoId.tmp');
      final fileSink = tempFile.openWrite();

      bool clientDisconnected = false;
      try {
        await for (final chunk in byteStream) {
          if (!clientDisconnected) {
            try {
              request.response.add(chunk);
            } catch (_) {
              clientDisconnected = true;
            }
          }
          fileSink.add(chunk);
        }
        if (!clientDisconnected) {
          await request.response.close();
        }
        await fileSink.flush();
        await fileSink.close();

        // If download succeeded and has substantial data, rename to complete cache file
        if (tempFile.existsSync() && tempFile.lengthSync() > 10000) {
          if (cacheFile.existsSync()) {
            try {
              cacheFile.deleteSync();
            } catch (_) {}
          }
          await tempFile.rename(cacheFile.path);
          debugPrint('[YoutubeAudioService] Cached stream file for $videoId (${cacheFile.lengthSync()} bytes)');
        }
      } catch (e) {
        debugPrint('[YoutubeAudioService] Stream piping interrupted for $videoId: $e');
        try {
          await request.response.close();
        } catch (_) {}
        try {
          await fileSink.close();
        } catch (_) {}
        if (tempFile.existsSync()) {
          try {
            tempFile.deleteSync();
          } catch (_) {}
        }
      }
    } catch (e, st) {
      debugPrint('[YoutubeAudioService] Error processing proxy request: $e');
      if (kDebugMode) debugPrint(st.toString());
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Searches YouTube videos matching [query], filters out overly long mixes,
  /// and maps each result into a unified Drift [Song] data model.
  /// If the internal `_yt.search.search` fails on short queries (e.g. `_Map.getT` error),
  /// it automatically falls back to YouTube's InnerTube search.
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

      if (songs.isEmpty) {
        return await _searchSongsInnerTube(trimmed);
      }

      return List.unmodifiable(songs);
    } catch (e, st) {
      debugPrint(
          '[YoutubeAudioService] _yt.search.search failed for "$query" ($e). Falling back to InnerTube search...');
      if (kDebugMode) {
        debugPrint(st.toString());
      }
      return _searchSongsInnerTube(trimmed);
    }
  }

  /// Fallback search querying YouTube InnerTube API directly to avoid rich-shelf crashes.
  Future<List<Song>> _searchSongsInnerTube(String query) async {
    try {
      final url = Uri.parse(
          'https://www.youtube.com/youtubei/v1/search?prettyPrint=false');
      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        body: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20240101.00.00',
              'hl': 'en',
              'gl': 'US',
            }
          },
          'query': query,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
            '[YoutubeAudioService] InnerTube search returned status ${response.statusCode}');
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final sections = data['contents']?['twoColumnSearchResultsRenderer']
              ?['primaryContents']?['sectionListRenderer']?['contents']
          as List?;

      final songs = <Song>[];
      if (sections != null) {
        for (final section in sections) {
          final itemSection =
              section['itemSectionRenderer']?['contents'] as List?;
          if (itemSection == null) continue;
          for (final item in itemSection) {
            final videoRenderer =
                item['videoRenderer'] as Map<String, dynamic>?;
            if (videoRenderer == null) continue;

            final videoId = videoRenderer['videoId'] as String?;
            if (videoId == null || videoId.isEmpty) continue;

            final titleRuns = videoRenderer['title']?['runs'] as List?;
            final title = (titleRuns != null && titleRuns.isNotEmpty)
                ? (titleRuns.first['text'] as String?) ?? 'Unknown Title'
                : (videoRenderer['title']?['simpleText'] as String?) ??
                    'Unknown Title';

            final ownerRuns = (videoRenderer['ownerText']?['runs'] as List?) ??
                (videoRenderer['shortBylineText']?['runs'] as List?);
            final author = (ownerRuns != null && ownerRuns.isNotEmpty)
                ? (ownerRuns.first['text'] as String?) ?? 'YouTube'
                : 'YouTube';

            final lengthText =
                videoRenderer['lengthText']?['simpleText'] as String?;
            final durationMs = parseDurationText(lengthText);

            // Filter out mixes longer than 25 minutes
            if (durationMs > 1500000) {
              continue;
            }

            final thumbnails =
                videoRenderer['thumbnail']?['thumbnails'] as List?;
            final thumbnail = (thumbnails != null && thumbnails.isNotEmpty)
                ? (thumbnails.last['url'] as String?) ??
                    'https://i.ytimg.com/vi/$videoId/hqdefault.jpg'
                : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

            songs.add(
              Song(
                id: generateVirtualId(videoId),
                title: title,
                artist: author,
                album: 'YouTube Stream',
                duration: durationMs,
                filePath: 'yt://$videoId',
                albumArtPath: thumbnail,
                isFavorite: false,
                playCount: 0,
                isCustomEdited: false,
                isHidden: false,
              ),
            );
          }
        }
      }

      debugPrint(
          '[YoutubeAudioService] InnerTube search fallback found ${songs.length} songs for "$query"');
      return List.unmodifiable(songs);
    } catch (e, st) {
      debugPrint('[YoutubeAudioService] InnerTube search fallback error: $e');
      if (kDebugMode) {
        debugPrint(st.toString());
      }
      return const [];
    }
  }

  /// Parses YouTube duration text (e.g. "3:45", "1:12:30") into milliseconds.
  static int parseDurationText(String? text) {
    if (text == null || text.isEmpty) return 0;
    final parts = text.trim().split(':');
    int seconds = 0;
    for (final part in parts) {
      seconds = seconds * 60 + (int.tryParse(part) ?? 0);
    }
    return seconds * 1000;
  }

  /// Ensures the stream URL uses HTTPS scheme for secure playback.
  static String ensureHttps(String url) {
    if (url.startsWith('http://')) {
      return 'https://${url.substring(7)}';
    }
    return url;
  }

  /// Resolves the best working audio stream info across multiple [YoutubeApiClient]s,
  /// performing a quick verification check so 403-blocked clients are skipped.
  Future<AudioStreamInfo?> _resolveBestStreamInfo(
    String videoId, {
    bool fallback = false,
  }) async {
    final clientsToTry = fallback
        ? [
            YoutubeApiClient.safari,
            YoutubeApiClient.tv,
            YoutubeApiClient.android,
            YoutubeApiClient.ios,
          ]
        : [
            YoutubeApiClient.ios,
            YoutubeApiClient.android,
            YoutubeApiClient.safari,
            YoutubeApiClient.tv,
          ];

    for (final client in clientsToTry) {
      try {
        debugPrint('[YoutubeAudioService] Fetching manifest with $client for video: $videoId');
        final manifest = await _yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: [client],
        );
        final audioStreams = manifest.audioOnly;
        if (audioStreams.isEmpty) continue;

        AudioStreamInfo candidate;
        final mp4Streams = audioStreams
            .where((s) => s.container.name.toLowerCase() == 'mp4')
            .toList();
        if (mp4Streams.isNotEmpty) {
          candidate = mp4Streams.withHighestBitrate();
        } else {
          candidate = audioStreams.withHighestBitrate();
        }

        // Quick stream check: verify that the first chunk can be fetched without 403
        final testStream = _yt.videos.streamsClient.get(candidate);
        await testStream.first;
        debugPrint(
            '[YoutubeAudioService] Verified working client $client for $videoId (${candidate.container.name}, ${candidate.bitrate})');
        return candidate;
      } catch (e) {
        debugPrint('[YoutubeAudioService] Client $client failed for $videoId: $e');
      }
    }

    // Fallback to default getManifest
    try {
      debugPrint('[YoutubeAudioService] Attempting default getManifest for $videoId');
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      if (manifest.audioOnly.isNotEmpty) {
        final mp4Streams = manifest.audioOnly
            .where((s) => s.container.name.toLowerCase() == 'mp4')
            .toList();
        final candidate = mp4Streams.isNotEmpty
            ? mp4Streams.withHighestBitrate()
            : manifest.audioOnly.withHighestBitrate();
        final testStream = _yt.videos.streamsClient.get(candidate);
        await testStream.first;
        debugPrint('[YoutubeAudioService] Verified working stream from default manifest for $videoId');
        return candidate;
      } else if (manifest.muxed.isNotEmpty) {
        final candidate = manifest.muxed.withHighestBitrate();
        final testStream = _yt.videos.streamsClient.get(candidate);
        await testStream.first;
        return candidate;
      }
    } catch (e) {
      debugPrint('[YoutubeAudioService] Default getManifest failed for $videoId: $e');
    }

    return null;
  }

  /// Fetches audio stream and returns the local loopback proxy URL for ExoPlayer.
  /// ExoPlayer streams from our local proxy which handles chunking and YouTube headers natively.
  Future<String> getAudioStreamUrl(String videoId, {bool fallback = false}) async {
    await _ensureProxyServer();

    final cacheFile = File('${_cacheDir.path}/yt_$videoId.m4a');
    if (cacheFile.existsSync() && cacheFile.lengthSync() > 10000) {
      debugPrint('[YoutubeAudioService] Serving from local cache: ${cacheFile.path}');
      return 'http://127.0.0.1:${_proxyServer!.port}/stream/$videoId';
    }

    if (fallback) {
      _activeStreamInfos.remove(videoId);
    }

    final streamInfo = await _resolveBestStreamInfo(videoId, fallback: fallback);
    if (streamInfo == null) {
      throw Exception('Failed to resolve playable audio stream for video $videoId');
    }

    _activeStreamInfos[videoId] = streamInfo;
    return 'http://127.0.0.1:${_proxyServer!.port}/stream/$videoId';
  }

  void dispose() {
    _yt.close();
    _httpClient.close();
    _proxyServer?.close(force: true);
    _proxyServer = null;
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
