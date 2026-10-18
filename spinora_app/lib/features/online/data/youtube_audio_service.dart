import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../../core/database/app_database.dart';

/// Fully resolved direct audio stream with associated client headers and MIME metadata.
class ResolvedAudioStream {
  const ResolvedAudioStream({
    required this.url,
    required this.userAgent,
    this.referer,
    this.mimeType = 'audio/mp4',
    this.contentLength,
  });

  final String url;
  final String userAgent;
  final String? referer;
  final String mimeType;
  final int? contentLength;
}

/// Service providing online YouTube audio search and multi-stage unthrottled audio streaming
/// via a local HTTP proxy server with Range support, matching client headers, and temp caching.
class YoutubeAudioService {
  YoutubeAudioService({
    YoutubeExplode? ytClient,
    http.Client? httpClient,
  })  : _yt = ytClient ?? YoutubeExplode(),
        _httpClient = httpClient ?? http.Client();

  final YoutubeExplode _yt;
  final http.Client _httpClient;
  HttpServer? _proxyServer;
  final Map<String, ResolvedAudioStream> _activeResolvedStreams = {};

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

  /// Cleans titles and artist names into concise queries suitable for music fallback lookups.
  static String cleanSongQuery(String title, [String? artist]) {
    String cleaned = title;
    // Remove brackets containing common YouTube fluff like "(Official Video)", "[Music Video]", "[24/7 Live Stream]", etc.
    cleaned = cleaned.replaceAll(
      RegExp(
        r'[\(\[\{][^\)\]\}]*?(?:official|music|video|audio|lyric|lyrics|visualizer|hd|4k|remix|full|clean|extended|explicit|live|performance|prod\.|produced|stream|version)[^\)\]\}]*?[\)\]\}]',
        caseSensitive: false,
      ),
      ' ',
    );
    // Remove trailing delimiters like "- Official Video" or "| 4K"
    cleaned = cleaned.replaceAll(
      RegExp(r'[\-\|\–\—]\s*(?:official|music|video|audio|lyrics).*$', caseSensitive: false),
      ' ',
    );
    // Remove "feat." or "ft."
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:ft|feat)\.?\s+[^\(\[\-]+', caseSensitive: false),
      ' ',
    );
    // Remove standalone quality/type words like 4K, HD, 1080p, Official, Video
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:4k|8k|hd|1080p|720p|audio|video|official)\b', caseSensitive: false),
      ' ',
    );
    // Remove characters that confuse search APIs
    cleaned = cleaned.replaceAll(
      RegExp(r'[^\w\s\u0600-\u06FF\u0980-\u09FF\u0900-\u097F]'),
      ' ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (artist != null && artist.isNotEmpty) {
      final cleanArtist = artist.replaceAll(RegExp(r'VEVO|Official|Topic', caseSensitive: false), '').trim();
      final normCleaned = cleaned.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      final normArtist = cleanArtist.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      if (cleanArtist.isNotEmpty && !normCleaned.contains(normArtist)) {
        cleaned = '$cleanArtist $cleaned';
      }
    }
    return cleaned.trim();
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
      if (segments.length != 2 || (segments.first != 'stream' && segments.first != 'yt')) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final videoId = segments[1];
      final cacheFile = File('${_cacheDir.path}/yt_$videoId.m4a');

      // 1. If file is already fully cached, serve with full Range support
      if (cacheFile.existsSync() && cacheFile.lengthSync() > 10000) {
        await _serveLocalFile(request, cacheFile);
        return;
      }

      // 2. Lookup or resolve the stream
      var resolved = _activeResolvedStreams[videoId];
      if (resolved == null) {
        resolved = await _resolveAudioStream(videoId);
        if (resolved != null) {
          _activeResolvedStreams[videoId] = resolved;
        }
      }

      if (resolved == null) {
        debugPrint('[YoutubeAudioService] Could not resolve audio stream for $videoId');
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      await _streamFromRemote(request, videoId, resolved);
    } catch (e, st) {
      debugPrint('[YoutubeAudioService] Error processing proxy request: $e');
      if (kDebugMode) debugPrint(st.toString());
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Serves a locally cached audio file with full HTTP 206 Partial Content range support.
  Future<void> _serveLocalFile(HttpRequest request, File cacheFile) async {
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
      final effectiveEnd =
          (end ?? totalLength - 1).clamp(start, totalLength - 1);
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
  }

  /// Pipes remote stream bytes directly to ExoPlayer with matching client headers
  /// while concurrently caching to disk.
  Future<void> _streamFromRemote(
    HttpRequest request,
    String videoId,
    ResolvedAudioStream resolved,
  ) async {
    final cacheFile = File('${_cacheDir.path}/yt_$videoId.m4a');
    final tempFile = File('${_cacheDir.path}/yt_$videoId.tmp');

    final upstreamRequest = http.Request(request.method, Uri.parse(resolved.url));
    upstreamRequest.headers['User-Agent'] = resolved.userAgent;
    if (resolved.referer != null) {
      upstreamRequest.headers['Referer'] = resolved.referer!;
    }
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    if (rangeHeader != null) {
      upstreamRequest.headers[HttpHeaders.rangeHeader] = rangeHeader;
    }

    final upstreamResponse = await _httpClient.send(upstreamRequest);

    if (upstreamResponse.statusCode == HttpStatus.forbidden) {
      debugPrint('[YoutubeAudioService] Upstream returned 403 for $videoId on ${resolved.url}');
      _activeResolvedStreams.remove(videoId);
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    request.response.statusCode = upstreamResponse.statusCode;
    final cType = upstreamResponse.headers['content-type'] ?? resolved.mimeType;
    try {
      request.response.headers.contentType = ContentType.parse(cType);
    } catch (_) {
      request.response.headers.contentType = ContentType('audio', 'mp4');
    }
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

    if (upstreamResponse.headers['content-range'] != null) {
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        upstreamResponse.headers['content-range']!,
      );
    }
    if (upstreamResponse.contentLength != null && upstreamResponse.contentLength! > 0) {
      request.response.headers.contentLength = upstreamResponse.contentLength!;
    }

    if (request.method == 'HEAD') {
      await request.response.close();
      return;
    }

    // Only cache if reading from the beginning
    final bool shouldCache = (upstreamResponse.statusCode == HttpStatus.ok ||
        (rangeHeader != null && rangeHeader.startsWith('bytes=0-')));

    IOSink? fileSink;
    if (shouldCache) {
      fileSink = tempFile.openWrite();
    }

    bool clientDisconnected = false;
    try {
      await for (final chunk in upstreamResponse.stream) {
        if (!clientDisconnected) {
          try {
            request.response.add(chunk);
          } catch (_) {
            clientDisconnected = true;
          }
        }
        fileSink?.add(chunk);
      }
      if (!clientDisconnected) {
        await request.response.close();
      }
      if (fileSink != null) {
        await fileSink.flush();
        await fileSink.close();
        if (tempFile.existsSync() && tempFile.lengthSync() > 10000) {
          if (cacheFile.existsSync()) {
            try {
              cacheFile.deleteSync();
            } catch (_) {}
          }
          await tempFile.rename(cacheFile.path);
          debugPrint('[YoutubeAudioService] Successfully cached $videoId (${cacheFile.lengthSync()} bytes)');
        }
      }
    } catch (e) {
      debugPrint('[YoutubeAudioService] Error streaming from remote for $videoId: $e');
      try {
        await request.response.close();
      } catch (_) {}
      try {
        await fileSink?.close();
      } catch (_) {}
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    }
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
        final duration = video.duration;
        if (duration != null && duration.inMinutes > 25) {
          continue;
        }

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

  /// Layer 1: Resolves audio stream via youtube_explode_dart with requireWatchPage: false
  /// testing safari, ios, mweb, tv, and android clients individually without probing video streams 133 or 137.
  Future<ResolvedAudioStream?> _resolveLayer1YoutubeExplode(String videoId) async {
    final clientConfigs = [
      (
        name: 'safari',
        client: YoutubeApiClient.safari,
        userAgent:
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15',
      ),
      (
        name: 'ios',
        client: YoutubeApiClient.ios,
        userAgent:
            'com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)',
      ),
      (
        name: 'mweb',
        client: YoutubeApiClient.mweb,
        userAgent:
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
      ),
      (
        name: 'tv',
        client: YoutubeApiClient.tv,
        userAgent:
            'Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) Version/6.0 TV Safari/537.36',
      ),
      (
        name: 'android',
        client: YoutubeApiClient.android,
        userAgent:
            'com.google.android.youtube/19.45.38 (Linux; U; Android 14)',
      ),
    ];

    for (final cfg in clientConfigs) {
      try {
        debugPrint('[YoutubeAudioService] Probing Layer 1 client ${cfg.name} for $videoId (requireWatchPage: false)...');
        final manifest = await _yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: [cfg.client],
          requireWatchPage: false,
        );

        final audioStreams = manifest.audioOnly.toList();
        final candidateStreams = audioStreams.isNotEmpty
            ? audioStreams
            : manifest.muxed
                .where((s) => s.container.name == 'mp4' || s.codec.mimeType.contains('audio'))
                .toList();

        if (candidateStreams.isEmpty) continue;

        // Prioritize mp4 (itag 140), then highest bitrate
        candidateStreams.sort((a, b) {
          final isA140 = a.tag == 140 || a.container.name == 'mp4' || a.codec.mimeType.contains('mp4');
          final isB140 = b.tag == 140 || b.container.name == 'mp4' || b.codec.mimeType.contains('mp4');
          if (isA140 && !isB140) return -1;
          if (!isA140 && isB140) return 1;
          return b.bitrate.compareTo(a.bitrate);
        });

        for (final candidate in candidateStreams) {
          final rawUrl = candidate.url.toString();
          if (rawUrl.isEmpty) continue;

          try {
            final testReq = await _httpClient.get(
              Uri.parse(rawUrl),
              headers: {
                'User-Agent': cfg.userAgent,
                'Range': 'bytes=0-1024',
              },
            ).timeout(const Duration(seconds: 4));

            if (testReq.statusCode == 200 || testReq.statusCode == 206) {
              debugPrint(
                '[YoutubeAudioService] Resolved stream via Layer 1 (${cfg.name}) for $videoId (itag: ${candidate.tag})',
              );
              return ResolvedAudioStream(
                url: rawUrl,
                userAgent: cfg.userAgent,
                mimeType: candidate.codec.mimeType,
                contentLength: candidate.size.totalBytes,
              );
            }
          } catch (e) {
            debugPrint('[YoutubeAudioService] Layer 1 candidate probe error for ${cfg.name}: $e');
          }
        }
      } catch (e) {
        debugPrint('[YoutubeAudioService] Layer 1 client ${cfg.name} failed for $videoId: $e');
      }
    }
    return null;
  }

  /// Layer 2: Directly queries YouTube InnerTube player endpoint for exact videoId with VisitorData.
  Future<ResolvedAudioStream?> _resolveLayer2InnerTube(String videoId) async {
    // 1. Fetch visitorData from YouTube visitor_id endpoint
    String? visitorData;
    try {
      final vRes = await _httpClient.post(
        Uri.parse('https://www.youtube.com/youtubei/v1/visitor_id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20240101.00.00',
            }
          }
        }),
      ).timeout(const Duration(seconds: 3));

      if (vRes.statusCode == 200) {
        final vData = jsonDecode(vRes.body) as Map<String, dynamic>;
        visitorData = vData['responseContext']?['visitorData'] as String?;
      }
    } catch (_) {}

    final clientConfigs = [
      (
        clientName: 'WEB_EMBEDDED_PLAYER',
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        context: {
          'client': {
            'clientName': 'WEB_EMBEDDED_PLAYER',
            'clientVersion': '1.20240101.01.00',
            'hl': 'en',
            'gl': 'US',
            'visitorData': ?visitorData,
          },
          'thirdParty': {
            'embedUrl': 'https://www.youtube.com/embed/$videoId',
          }
        },
      ),
      (
        clientName: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
        userAgent:
            'Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) Version/6.0 TV Safari/537.36',
        context: {
          'client': {
            'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
            'clientVersion': '2.0',
            'hl': 'en',
            'gl': 'US',
            'visitorData': ?visitorData,
          },
          'thirdParty': {
            'embedUrl': 'https://www.youtube.com/embed/$videoId',
          }
        },
      ),
      (
        clientName: 'IOS',
        userAgent:
            'com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)',
        context: {
          'client': {
            'clientName': 'IOS',
            'clientVersion': '19.45.4',
            'deviceMake': 'Apple',
            'deviceModel': 'iPhone16,2',
            'hl': 'en',
            'gl': 'US',
            'visitorData': ?visitorData,
          }
        },
      ),
      (
        clientName: 'ANDROID_VR',
        userAgent:
            'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
        context: {
          'client': {
            'clientName': 'ANDROID_VR',
            'clientVersion': '1.60.19',
            'deviceMake': 'Oculus',
            'deviceModel': 'Quest',
            'androidSdkVersion': 34,
            'hl': 'en',
            'gl': 'US',
            'visitorData': ?visitorData,
          }
        },
      ),
      (
        clientName: 'ANDROID_TESTSUITE',
        userAgent:
            'com.google.android.youtube/1.9 (Linux; U; Android 9; test-user Build/PI)',
        context: {
          'client': {
            'clientName': 'ANDROID_TESTSUITE',
            'clientVersion': '1.9',
            'androidSdkVersion': 30,
            'hl': 'en',
            'gl': 'US',
            'visitorData': ?visitorData,
          }
        },
      ),
    ];

    for (final cfg in clientConfigs) {
      try {
        debugPrint('[YoutubeAudioService] Probing Layer 2 client ${cfg.clientName} for $videoId...');
        final response = await _httpClient.post(
          Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': cfg.userAgent,
          },
          body: jsonEncode({
            'context': cfg.context,
            'videoId': videoId,
            'playbackContext': {
              'contentPlaybackContext': {
                'html5Preference': 'HTML5_PREF_WANTS',
              }
            }
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final playability = data['playabilityStatus'] as Map<String, dynamic>?;
        if (playability != null && playability['status'] != 'OK') {
          debugPrint('[YoutubeAudioService] InnerTube ${cfg.clientName} unplayable: ${playability['reason'] ?? playability['status']}');
          continue;
        }

        final streamingData = data['streamingData'] as Map<String, dynamic>?;
        if (streamingData == null) continue;

        final rawFormats = <Map<String, dynamic>>[];
        if (streamingData['adaptiveFormats'] is List) {
          rawFormats.addAll(
            (streamingData['adaptiveFormats'] as List).cast<Map<String, dynamic>>(),
          );
        }
        if (streamingData['formats'] is List) {
          rawFormats.addAll(
            (streamingData['formats'] as List).cast<Map<String, dynamic>>(),
          );
        }

        final candidateFormats = rawFormats.where((f) {
          final mime = (f['mimeType'] as String? ?? '').toLowerCase();
          final isAudio = mime.startsWith('audio/') || f['audioQuality'] != null;
          final hasDirectUrl = f['url'] != null && (f['url'] as String).isNotEmpty;
          final isEncrypted = f['signatureCipher'] != null || f['cipher'] != null;
          return isAudio && hasDirectUrl && !isEncrypted;
        }).toList();

        if (candidateFormats.isEmpty) continue;

        candidateFormats.sort((a, b) {
          final mimeA = (a['mimeType'] as String? ?? '').toLowerCase();
          final mimeB = (b['mimeType'] as String? ?? '').toLowerCase();
          final aIsMp4 = mimeA.contains('mp4') || a['itag'] == 140;
          final bIsMp4 = mimeB.contains('mp4') || b['itag'] == 140;
          if (aIsMp4 && !bIsMp4) return -1;
          if (!aIsMp4 && bIsMp4) return 1;

          final bitrateA = (a['bitrate'] as num?)?.toInt() ?? 0;
          final bitrateB = (b['bitrate'] as num?)?.toInt() ?? 0;
          return bitrateB.compareTo(bitrateA);
        });

        for (final format in candidateFormats) {
          final rawUrl = format['url'] as String;
          final mime = (format['mimeType'] as String? ?? 'audio/mp4').split(';').first.trim();
          final clen = int.tryParse(format['contentLength']?.toString() ?? '');

          try {
            final testReq = await _httpClient.get(
              Uri.parse(rawUrl),
              headers: {
                'User-Agent': cfg.userAgent,
                'Range': 'bytes=0-1024',
              },
            ).timeout(const Duration(seconds: 4));

            if (testReq.statusCode == 200 || testReq.statusCode == 206) {
              debugPrint(
                '[YoutubeAudioService] Resolved stream via Layer 2 (${cfg.clientName}) for $videoId (itag: ${format['itag']})',
              );
              return ResolvedAudioStream(
                url: rawUrl,
                userAgent: cfg.userAgent,
                mimeType: mime,
                contentLength: clen,
              );
            }
          } catch (e) {
            debugPrint('[YoutubeAudioService] Stream range probe error for ${cfg.clientName}: $e');
          }
        }
      } catch (e) {
        debugPrint('[YoutubeAudioService] Layer 2 client ${cfg.clientName} error: $e');
      }
    }
    return null;
  }

  /// Layer 3: Queries public Piped & Invidious API instances by exact videoId.
  Future<ResolvedAudioStream?> _resolveLayer3PipedAndInvidious(String videoId) async {
    const defaultUa =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    final instances = [
      // Piped API instances (exact videoId stream route)
      (type: 'piped', url: 'https://pipedapi.kavin.rocks/streams/$videoId'),
      (type: 'piped', url: 'https://pipedapi.tokhmi.xyz/streams/$videoId'),
      (type: 'piped', url: 'https://api.piped.private.coffee/streams/$videoId'),
      (type: 'piped', url: 'https://pipedapi.leptons.xyz/streams/$videoId'),
      (type: 'piped', url: 'https://piped-api.lunar.icu/streams/$videoId'),
      // Invidious API instances (exact videoId video route)
      (type: 'invidious', url: 'https://inv.tux.pizza/api/v1/videos/$videoId'),
      (type: 'invidious', url: 'https://invidious.nerdvpn.de/api/v1/videos/$videoId'),
      (type: 'invidious', url: 'https://inv.nadeko.net/api/v1/videos/$videoId'),
      (type: 'invidious', url: 'https://invidious.private.coffee/api/v1/videos/$videoId'),
      (type: 'invidious', url: 'https://yewtu.be/api/v1/videos/$videoId'),
    ];

    for (final inst in instances) {
      try {
        final host = Uri.parse(inst.url).host;
        debugPrint('[YoutubeAudioService] Checking Layer 3 ($host) for exact videoId $videoId...');
        final res = await _httpClient
            .get(
              Uri.parse(inst.url),
              headers: {'User-Agent': defaultUa},
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode != 200) continue;

        final data = jsonDecode(res.body) as Map<String, dynamic>;

        if (inst.type == 'piped') {
          final audioStreams = (data['audioStreams'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final candidates = audioStreams.where((f) {
            final url = f['url'] as String?;
            return url != null && url.isNotEmpty;
          }).toList();

          if (candidates.isEmpty) continue;

          candidates.sort((a, b) {
            final isA140 = (a['format'] as String? ?? '').contains('M4A') ||
                (a['mimeType'] as String? ?? '').contains('mp4');
            final isB140 = (b['format'] as String? ?? '').contains('M4A') ||
                (b['mimeType'] as String? ?? '').contains('mp4');
            if (isA140 && !isB140) return -1;
            if (!isA140 && isB140) return 1;
            final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
            final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
            return brB.compareTo(brA);
          });

          for (final af in candidates) {
            final rawUrl = af['url'] as String;
            final clen = int.tryParse(af['contentLength']?.toString() ?? '');
            try {
              final testRes = await _httpClient.get(
                Uri.parse(rawUrl),
                headers: {
                  'User-Agent': defaultUa,
                  'Range': 'bytes=0-1024',
                },
              ).timeout(const Duration(seconds: 3));

              if (testRes.statusCode == 200 || testRes.statusCode == 206) {
                debugPrint('[YoutubeAudioService] Resolved stream via Layer 3 (Piped: $host) for $videoId');
                return ResolvedAudioStream(
                  url: rawUrl,
                  userAgent: defaultUa,
                  mimeType: (af['mimeType'] as String? ?? 'audio/mp4').split(';').first.trim(),
                  contentLength: clen,
                );
              }
            } catch (_) {}
          }
        } else {
          // Invidious format
          final adaptive = (data['adaptiveFormats'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final audioFormats = adaptive.where((f) {
            final type = (f['type'] as String? ?? '').toLowerCase();
            final url = f['url'] as String?;
            return type.startsWith('audio/') && url != null && url.isNotEmpty;
          }).toList();

          if (audioFormats.isEmpty) continue;

          audioFormats.sort((a, b) {
            final isA140 = a['itag'] == 140 || (a['type'] as String? ?? '').contains('mp4');
            final isB140 = b['itag'] == 140 || (b['type'] as String? ?? '').contains('mp4');
            if (isA140 && !isB140) return -1;
            if (!isA140 && isB140) return 1;
            final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
            final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
            return brB.compareTo(brA);
          });

          for (final af in audioFormats) {
            final rawUrl = af['url'] as String;
            final clen = int.tryParse(af['clen']?.toString() ?? '');
            try {
              final testRes = await _httpClient.get(
                Uri.parse(rawUrl),
                headers: {
                  'User-Agent': defaultUa,
                  'Range': 'bytes=0-1024',
                },
              ).timeout(const Duration(seconds: 3));

              if (testRes.statusCode == 200 || testRes.statusCode == 206) {
                debugPrint('[YoutubeAudioService] Resolved stream via Layer 3 (Invidious: $host) for $videoId');
                return ResolvedAudioStream(
                  url: rawUrl,
                  userAgent: defaultUa,
                  mimeType: (af['type'] as String? ?? 'audio/mp4').split(';').first.trim(),
                  contentLength: clen,
                );
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('[YoutubeAudioService] Layer 3 instance error: $e');
      }
    }
    return null;
  }

  /// 3-layer exact videoId audio resolver. NEVER queries third-party catalogs by text/title.
  Future<ResolvedAudioStream?> _resolveAudioStream(
    String videoId, {
    bool fallback = false,
  }) async {
    if (!fallback) {
      // 1. Layer 1: youtube_explode_dart multi-client with requireWatchPage: false
      final layer1Stream = await _resolveLayer1YoutubeExplode(videoId);
      if (layer1Stream != null) return layer1Stream;

      // 2. Layer 2: Direct InnerTube player API with VisitorData
      final layer2Stream = await _resolveLayer2InnerTube(videoId);
      if (layer2Stream != null) return layer2Stream;

      // 3. Layer 3: Exact videoId Piped / Invidious instances
      final layer3Stream = await _resolveLayer3PipedAndInvidious(videoId);
      if (layer3Stream != null) return layer3Stream;
    } else {
      // On retry/fallback: prioritize Layer 2, then Layer 3, then Layer 1
      final layer2Stream = await _resolveLayer2InnerTube(videoId);
      if (layer2Stream != null) return layer2Stream;

      final layer3Stream = await _resolveLayer3PipedAndInvidious(videoId);
      if (layer3Stream != null) return layer3Stream;

      final layer1Stream = await _resolveLayer1YoutubeExplode(videoId);
      if (layer1Stream != null) return layer1Stream;
    }

    return null;
  }

  /// Resolves the audio stream for the exact [videoId] and returns the local loopback proxy URL for ExoPlayer.
  /// ExoPlayer streams from our local proxy which handles Range requests, chunking,
  /// and exact matching client User-Agents without HTTP 403 errors.
  /// All streams strictly map to the tapped YouTube [videoId] (no title/text search fallbacks).
  Future<String> getAudioStreamUrl(
    String videoId, {
    String? title,
    String? artist,
    bool fallback = false,
  }) async {
    await _ensureProxyServer();

    final cacheFile = File('${_cacheDir.path}/yt_$videoId.m4a');
    if (cacheFile.existsSync() && cacheFile.lengthSync() > 10000) {
      debugPrint('[YoutubeAudioService] Serving exact video $videoId from local disk cache: ${cacheFile.path}');
      return 'http://127.0.0.1:${_proxyServer!.port}/stream/$videoId';
    }

    if (fallback) {
      _activeResolvedStreams.remove(videoId);
    }

    var resolved = _activeResolvedStreams[videoId];
    if (resolved == null || fallback) {
      resolved = await _resolveAudioStream(
        videoId,
        fallback: fallback,
      );
      if (resolved == null) {
        throw Exception('Failed to resolve playable audio stream for YouTube video $videoId');
      }
      _activeResolvedStreams[videoId] = resolved;
    }

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
