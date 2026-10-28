// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart'
    show StreamAudioResponse, StreamAudioSource;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../../core/database/app_database.dart';

/// Client-specific User-Agent strings matched dynamically to YouTube stream URLs (`c=` query parameter).
const String kYouTubeIosUserAgent =
    'com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X;)';
const String kYouTubeVrUserAgent =
    'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; en_US; Quest 2; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)';
const String kYouTubeSafariUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15';
const String kYouTubeAndroidUserAgent =
    'com.google.android.youtube/19.29.37 (Linux; U; Android 14; en_US) gzip';

/// Default HTTP headers passed to `AudioSource.uri` when a fallback header map is needed.
const Map<String, String> kYouTubeStreamHeaders = {
  'User-Agent': kYouTubeVrUserAgent,
  'Accept': '*/*',
  'Connection': 'keep-alive',
};

/// Fully resolved direct audio stream with associated client headers, MIME metadata,
/// and resolved `youtube_explode_dart` [StreamInfo] ([AudioOnlyStreamInfo]) kept in memory
/// for zero-re-fetch `YouTubeByteStreamSource` (`streamsClient.get(streamInfo)`) streaming.
class ResolvedAudioStream {
  const ResolvedAudioStream({
    required this.url,
    this.userAgent,
    this.referer,
    this.mimeType = 'audio/mp4',
    this.contentLength,
    this.streamInfo,
  });

  final String url;
  final String? userAgent;
  final String? referer;
  final String mimeType;
  final int? contentLength;
  final StreamInfo? streamInfo;

  /// Returns the resolved [AudioOnlyStreamInfo] if [streamInfo] is an audio-only stream.
  AudioOnlyStreamInfo? get audioOnlyStreamInfo =>
      streamInfo is AudioOnlyStreamInfo
          ? streamInfo as AudioOnlyStreamInfo
          : null;

  Uri get uri => Uri.parse(url);

  /// Clean MIME type (e.g. `audio/mp4`) stripped of codec parameters.
  String get cleanMimeType {
    final base = mimeType.split(';').first.trim();
    return base.isEmpty ? 'audio/mp4' : base;
  }

  /// Dynamically matches the HTTP `User-Agent` to the stream URL's `c=` query parameter.
  String? get matchedUserAgent => YoutubeAudioService.resolveUserAgentForUrl(
    uri,
    fallbackUserAgent: userAgent,
  );

  Map<String, String> get headers {
    final ua = matchedUserAgent;
    return {
      if (ua != null && ua.isNotEmpty) 'User-Agent': ua,
      'Accept': '*/*',
      'Connection': 'keep-alive',
      'Referer': ?referer,
    };
  }
}

/// Custom [StreamAudioSource] backed by `YoutubeExplode.videos.streamsClient.get(streamInfo)`
/// (which uses YouTube's required `&range=0-9898989` URL query parameter chunking) so ExoPlayer
/// reads a clean byte stream without ever getting `Response code: 403` from `googlevideo.com`.
class YouTubeByteStreamSource extends StreamAudioSource {
  YouTubeByteStreamSource({
    required this.videoId,
    required this.resolvedStream,
    required this.youtubeService,
    super.tag,
  });

  final String videoId;
  final ResolvedAudioStream resolvedStream;
  final YoutubeAudioService youtubeService;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final totalLength =
        resolvedStream.streamInfo?.size.totalBytes ??
        resolvedStream.contentLength;
    final effectiveStart = start ?? 0;
    final effectiveEnd = (end != null && totalLength != null)
        ? end.clamp(effectiveStart, totalLength)
        : (end ?? totalLength);
    final contentLength = effectiveEnd != null
        ? (effectiveEnd - effectiveStart)
        : null;

    final streamInfo = resolvedStream.streamInfo;
    if (streamInfo != null && effectiveStart == 0) {
      final rawStream = youtubeService.getRawByteStream(streamInfo);
      final boundedStream =
          (contentLength != null &&
              totalLength != null &&
              contentLength < totalLength)
          ? YoutubeAudioService.sliceByteStream(rawStream, 0, contentLength)
          : rawStream;
      return StreamAudioResponse(
        sourceLength: totalLength,
        contentLength: contentLength ?? totalLength,
        offset: 0,
        stream: boundedStream,
        contentType: 'audio/mp4',
      );
    }

    return youtubeService.openRangeStreamResponse(
      resolvedStream: resolvedStream,
      start: effectiveStart,
      end: effectiveEnd,
      totalLength: totalLength,
    );
  }
}

class _CachedStreamEntry {
  const _CachedStreamEntry({required this.stream, required this.cachedAt});

  final ResolvedAudioStream stream;
  final DateTime cachedAt;

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > const Duration(minutes: 30);
}

/// Service providing online YouTube audio search and unthrottled audio streaming
/// with fast `[ios, androidVr]` manifest resolution (`requireWatchPage: false`),
/// dynamic `c=` User-Agent matching, active request cancellation, and
/// `streamsClient.get(streamInfo)` byte streaming.
class YoutubeAudioService {
  YoutubeAudioService({YoutubeExplode? ytClient, http.Client? httpClient})
    : _yt = ytClient ?? YoutubeExplode(),
      _hasCustomYtClient = ytClient != null,
      _hasCustomHttpClient = httpClient != null,
      _httpClient = httpClient ?? http.Client();

  YoutubeExplode _yt;
  final bool _hasCustomYtClient;
  final bool _hasCustomHttpClient;
  final http.Client _httpClient;
  HttpServer? _proxyServer;
  final Map<String, _CachedStreamEntry> _streamCache = {};

  /// Active request token and videoId guard so stale Layer 2/3 loops cancel immediately
  /// when the user taps a new song.
  int _activeResolveToken = 0;
  String? _activeVideoId;

  /// Starts a new resolution request for [videoId], immediately invalidating any
  /// older in-flight resolution loops for previous songs.
  int beginResolveRequest(String videoId) {
    _activeVideoId = videoId;
    return ++_activeResolveToken;
  }

  /// Cancels any in-flight background stream resolution loops.
  void cancelActiveResolutions() {
    _activeVideoId = null;
    _activeResolveToken++;
  }

  bool _isRequestActive(String videoId, int? requestToken) {
    if (requestToken == null) return true;
    return _activeResolveToken == requestToken && _activeVideoId == videoId;
  }

  /// Inspects `streamInfo.url.queryParameters['c']` (upper-cased) and returns
  /// the matching client `User-Agent`:
  /// - `'IOS'`: `'com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X;)'`
  /// - `'ANDROID_VR'`: `'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; en_US; Quest 2; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)'`
  /// - `'SAFARI'` or `'WEB'`: `'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15'`
  /// - Otherwise: returns [fallbackUserAgent] or a matching Android client User-Agent (or null).
  static String? resolveUserAgentForUrl(
    Uri uri, {
    String? fallbackUserAgent,
  }) {
    final cParam = (uri.queryParameters['c'] ?? '').toUpperCase();
    if (cParam.contains('IOS')) {
      return kYouTubeIosUserAgent;
    }
    if (cParam.contains('ANDROID_VR')) {
      return kYouTubeVrUserAgent;
    }
    if (cParam.contains('SAFARI') || cParam.contains('WEB')) {
      return kYouTubeSafariUserAgent;
    }
    if (cParam.contains('ANDROID')) {
      return kYouTubeAndroidUserAgent;
    }
    if (fallbackUserAgent != null && fallbackUserAgent.isNotEmpty) {
      return fallbackUserAgent;
    }
    return null;
  }

  /// Slices a byte stream from [startOffset] for [maxBytes] bytes.
  static Stream<List<int>> sliceByteStream(
    Stream<List<int>> source,
    int startOffset,
    int? maxBytes,
  ) async* {
    int skipped = 0;
    int emitted = 0;
    await for (final chunk in source) {
      if (maxBytes != null && emitted >= maxBytes) break;
      int chunkStart = 0;
      if (skipped < startOffset) {
        final remainingToSkip = startOffset - skipped;
        if (chunk.length <= remainingToSkip) {
          skipped += chunk.length;
          continue;
        }
        chunkStart = remainingToSkip;
        skipped = startOffset;
      }
      int chunkEnd = chunk.length;
      if (maxBytes != null) {
        final remainingToEmit = maxBytes - emitted;
        if (chunkEnd - chunkStart > remainingToEmit) {
          chunkEnd = chunkStart + remainingToEmit;
        }
      }
      if (chunkEnd > chunkStart) {
        final slice = (chunkStart == 0 && chunkEnd == chunk.length)
            ? chunk
            : chunk.sublist(chunkStart, chunkEnd);
        emitted += slice.length;
        yield slice;
      }
    }
  }

  /// Recreates a fresh [YoutubeExplode] instance (closing the old one) so stale
  /// visitor sessions never block playback after 1-2 songs.
  void resetYoutubeClient() {
    if (_hasCustomYtClient) return;
    try {
      _yt.close();
    } catch (_) {}
    _yt = YoutubeExplode();
  }

  /// Invalidates any cached stream entry for [videoId].
  void invalidateStreamCache(String videoId) {
    _streamCache.remove(videoId);
  }

  /// Returns cached stream if available and not expired (30-min TTL).
  ResolvedAudioStream? _getCachedStream(String videoId) {
    final entry = _streamCache[videoId];
    if (entry != null && !entry.isExpired) {
      return entry.stream;
    }
    _streamCache.remove(videoId);
    return null;
  }

  /// Caches resolved stream in memory with current timestamp.
  void _cacheStream(String videoId, ResolvedAudioStream stream) {
    _streamCache[videoId] = _CachedStreamEntry(
      stream: stream,
      cachedAt: DateTime.now(),
    );
  }

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
      RegExp(
        r'[\-\|\–\—]\s*(?:official|music|video|audio|lyrics).*$',
        caseSensitive: false,
      ),
      ' ',
    );
    // Remove "feat." or "ft."
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:ft|feat)\.?\s+[^\(\[\-]+', caseSensitive: false),
      ' ',
    );
    // Remove standalone quality/type words like 4K, HD, 1080p, Official, Video
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:4k|8k|hd|1080p|720p|audio|video|official)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    // Remove characters that confuse search APIs
    cleaned = cleaned.replaceAll(
      RegExp(r'[^\w\s\u0600-\u06FF\u0980-\u09FF\u0900-\u097F]'),
      ' ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (artist != null && artist.isNotEmpty) {
      final cleanArtist = artist
          .replaceAll(RegExp(r'VEVO|Official|Topic', caseSensitive: false), '')
          .trim();
      final normCleaned = cleaned.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      final normArtist = cleanArtist
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
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
      debugPrint(
        '[YoutubeAudioService] Started local audio proxy on http://127.0.0.1:${_proxyServer!.port}',
      );
      _proxyServer!.listen(
        _handleProxyRequest,
        onError: (e) {
          debugPrint('[YoutubeAudioService] Local proxy error: $e');
        },
      );
    } catch (e, st) {
      debugPrint('[YoutubeAudioService] Failed to bind local proxy server: $e');
      if (kDebugMode) debugPrint(st.toString());
      rethrow;
    }
  }

  /// Handles incoming HTTP GET/HEAD requests from ExoPlayer.
  Future<void> _handleProxyRequest(HttpRequest request) async {
    try {
      String? videoId;
      final segments = request.uri.pathSegments;
      if (segments.isNotEmpty &&
          (segments.first == 'stream' || segments.first == 'yt')) {
        if (segments.length >= 2) {
          videoId = segments[1];
        } else if (request.uri.queryParameters.containsKey('id')) {
          videoId = request.uri.queryParameters['id'];
        }
      }

      if (videoId == null || videoId.isEmpty) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final cacheFile = File('${_cacheDir.path}/yt_$videoId.m4a');

      // 1. If file is already fully cached, serve with full Range support
      if (cacheFile.existsSync() && cacheFile.lengthSync() > 10000) {
        await _serveLocalFile(request, cacheFile);
        return;
      }

      // 2. Lookup or resolve the stream
      var resolved = _getCachedStream(videoId);
      if (resolved == null) {
        resolved = await _resolveAudioStream(videoId);
        if (resolved != null) {
          _cacheStream(videoId, resolved);
        }
      }

      if (resolved == null) {
        debugPrint(
          '[YoutubeAudioService] Could not resolve audio stream for $videoId',
        );
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
      final effectiveEnd = (end ?? totalLength - 1).clamp(
        start,
        totalLength - 1,
      );
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

      await request.response.addStream(
        cacheFile.openRead(start, effectiveEnd + 1),
      );
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

  /// Pipes remote stream bytes directly to ExoPlayer.
  /// When [resolved.streamInfo] is present and the request starts at byte 0, pipes
  /// `_yt.videos.streamsClient.get(streamInfo)` (which uses YouTube's required
  /// `&range=0-9898989` URL query parameter chunking) with `Content-Type: audio/mp4`
  /// and `Content-Length: streamInfo.size.totalBytes` so ExoPlayer never gets HTTP 403.
  Future<void> _streamFromRemote(
    HttpRequest request,
    String videoId,
    ResolvedAudioStream resolved,
  ) async {
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    int start = 0;
    int? end;
    final isRangeRequest =
        rangeHeader != null && rangeHeader.startsWith('bytes=');
    if (isRangeRequest) {
      final parts = rangeHeader.substring(6).split('-');
      start = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1 && parts[1].isNotEmpty) {
        end = int.tryParse(parts[1]);
      }
    }

    final streamInfo = resolved.streamInfo;
    if (streamInfo != null && start == 0) {
      final totalLength = streamInfo.size.totalBytes;
      final effectiveEnd = (end ?? (totalLength - 1)).clamp(
        0,
        totalLength > 0 ? totalLength - 1 : 0,
      );
      final chunkLength = (totalLength > 0 && effectiveEnd >= start)
          ? (effectiveEnd - start + 1)
          : totalLength;

      request.response.headers.contentType = ContentType('audio', 'mp4');
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

      if (isRangeRequest && totalLength > 0) {
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes 0-$effectiveEnd/$totalLength',
        );
        request.response.headers.contentLength = chunkLength;
      } else {
        request.response.statusCode = HttpStatus.ok;
        if (totalLength > 0) {
          request.response.headers.contentLength = totalLength;
        }
      }

      if (request.method == 'HEAD') {
        await request.response.close();
        return;
      }

      final rawStream = _yt.videos.streamsClient.get(streamInfo);
      final streamToPipe = (end != null && chunkLength < totalLength)
          ? sliceByteStream(rawStream, 0, chunkLength)
          : rawStream;

      StreamSubscription<List<int>>? subscription;
      bool isClosed = false;

      Future<void> closeResponse() async {
        if (isClosed) return;
        isClosed = true;
        try {
          await request.response.close();
        } catch (_) {}
      }

      subscription = streamToPipe.listen(
        (chunk) {
          if (!isClosed) {
            try {
              request.response.add(chunk);
            } catch (_) {
              subscription?.cancel();
              closeResponse();
            }
          }
        },
        onDone: () async {
          await closeResponse();
        },
        onError: (e) async {
          debugPrint(
            '[YoutubeAudioService] streamsClient.get proxy error for $videoId: $e',
          );
          await closeResponse();
        },
        cancelOnError: true,
      );

      request.response.done
          .then((_) {
            subscription?.cancel();
          })
          .catchError((_) {
            subscription?.cancel();
          });
      return;
    }

    final upstreamRequest = http.Request(
      request.method,
      Uri.parse(resolved.url),
    );
    final matchedUa = resolved.matchedUserAgent;
    if (matchedUa != null && matchedUa.isNotEmpty) {
      upstreamRequest.headers['User-Agent'] = matchedUa;
    }
    if (resolved.referer != null) {
      upstreamRequest.headers['Referer'] = resolved.referer!;
    }
    if (rangeHeader != null) {
      upstreamRequest.headers[HttpHeaders.rangeHeader] = rangeHeader;
    }

    final upstreamResponse = await _httpClient.send(upstreamRequest);

    if (upstreamResponse.statusCode == HttpStatus.forbidden) {
      debugPrint(
        '[YoutubeAudioService] Upstream returned 403 for $videoId on ${resolved.url}',
      );
      _streamCache.remove(videoId);
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    request.response.statusCode = upstreamResponse.statusCode;
    final cType =
        upstreamResponse.headers['content-type'] ?? resolved.cleanMimeType;
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
    if (upstreamResponse.contentLength != null &&
        upstreamResponse.contentLength! > 0) {
      request.response.headers.contentLength = upstreamResponse.contentLength!;
    }

    if (request.method == 'HEAD') {
      await request.response.close();
      return;
    }

    StreamSubscription<List<int>>? subscription;
    bool isClosed = false;

    Future<void> closeResponse() async {
      if (isClosed) return;
      isClosed = true;
      try {
        await request.response.close();
      } catch (_) {}
    }

    subscription = upstreamResponse.stream.listen(
      (chunk) {
        if (!isClosed) {
          try {
            request.response.add(chunk);
          } catch (_) {
            subscription?.cancel();
            closeResponse();
          }
        }
      },
      onDone: () async {
        await closeResponse();
      },
      onError: (e) async {
        debugPrint('[YoutubeAudioService] Stream error for $videoId: $e');
        await closeResponse();
      },
      cancelOnError: true,
    );

    // If client disconnects or aborts (e.g., song switch), cancel upstream immediately!
    request.response.done
        .then((_) {
          subscription?.cancel();
        })
        .catchError((_) {
          subscription?.cancel();
        });
  }

  /// Searches YouTube videos matching [query], filters out overly long mixes,
  /// and maps each result into a unified Drift [Song] data model.
  /// Prioritizes fast direct InnerTube JSON search (<300ms) with 4-second timeout,
  /// cleanly falling back to youtube_explode only if direct search returns empty.
  Future<List<Song>> searchSongs(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // 1. Fast direct InnerTube JSON search (<300ms)
    try {
      final innerTubeResults = await _searchSongsInnerTube(trimmed);
      if (innerTubeResults.isNotEmpty) {
        return innerTubeResults;
      }
    } catch (e) {
      debugPrint('[YoutubeAudioService] InnerTube fast search failed: $e');
    }

    // 2. Fallback to youtube_explode search only if direct search returned empty
    try {
      final searchResults = await _yt.search
          .search(trimmed)
          .timeout(const Duration(seconds: 4));
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

      return List.unmodifiable(songs);
    } catch (e, st) {
      debugPrint(
        '[YoutubeAudioService] youtube_explode search fallback error: $e',
      );
      if (kDebugMode) debugPrint(st.toString());
      return const [];
    }
  }

  /// Direct InnerTube API search (<300ms) for high-speed YouTube video queries.
  Future<List<Song>> _searchSongsInnerTube(String query) async {
    try {
      final url = Uri.parse(
        'https://www.youtube.com/youtubei/v1/search?prettyPrint=false',
      );
      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        body: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20240101.00.00',
              'hl': 'en',
              'gl': 'US',
            },
          },
          'query': query,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[YoutubeAudioService] InnerTube search returned status ${response.statusCode}',
        );
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final sections =
          data['contents']?['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents']
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

            final ownerRuns =
                (videoRenderer['ownerText']?['runs'] as List?) ??
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
        '[YoutubeAudioService] InnerTube search fallback found ${songs.length} songs for "$query"',
      );
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
  Future<ResolvedAudioStream?> _resolveLayer1YoutubeExplode(
    String videoId, {
    int? requestToken,
  }) async {
    final clientConfigs = [
      (
        name: 'safari',
        client: YoutubeApiClient.safari,
        userAgent: kYouTubeSafariUserAgent,
      ),
      (
        name: 'ios',
        client: YoutubeApiClient.ios,
        userAgent: kYouTubeIosUserAgent,
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
        userAgent: kYouTubeAndroidUserAgent,
      ),
    ];

    for (final cfg in clientConfigs) {
      if (!_isRequestActive(videoId, requestToken)) return null;
      try {
        debugPrint(
          '[YoutubeAudioService] Probing Layer 1 client ${cfg.name} for $videoId (requireWatchPage: false)...',
        );
        final manifest = await _yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [cfg.client],
              requireWatchPage: false,
            )
            .timeout(const Duration(seconds: 5));

        if (!_isRequestActive(videoId, requestToken)) return null;

        final best = selectBestAudioStream(manifest);
        if (best != null) {
          final rawUrl = ensureHttps(best.url.toString());
          if (rawUrl.isNotEmpty) {
            final matchedUa = resolveUserAgentForUrl(
              best.url,
              fallbackUserAgent: cfg.userAgent,
            );
            debugPrint(
              '[YoutubeAudioService] Resolved stream via Layer 1 (${cfg.name}) for $videoId (itag: ${best.tag})',
            );
            return ResolvedAudioStream(
              url: rawUrl,
              userAgent: matchedUa,
              mimeType: best.codec.mimeType,
              contentLength: best.size.totalBytes,
              streamInfo: best,
            );
          }
        }
      } catch (e) {
        debugPrint(
          '[YoutubeAudioService] Layer 1 client ${cfg.name} failed for $videoId: $e',
        );
      }
    }
    return null;
  }

  /// Layer 2: Directly queries YouTube InnerTube player endpoint for exact videoId with VisitorData.
  Future<ResolvedAudioStream?> _resolveLayer2InnerTube(
    String videoId, {
    int? requestToken,
  }) async {
    if (!_isRequestActive(videoId, requestToken)) return null;

    // 1. Fetch visitorData from YouTube visitor_id endpoint
    String? visitorData;
    try {
      final vRes = await _httpClient
          .post(
            Uri.parse('https://www.youtube.com/youtubei/v1/visitor_id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'context': {
                'client': {
                  'clientName': 'WEB',
                  'clientVersion': '2.20240101.00.00',
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (vRes.statusCode == 200) {
        final vData = jsonDecode(vRes.body) as Map<String, dynamic>;
        visitorData = vData['responseContext']?['visitorData'] as String?;
      }
    } catch (_) {}

    final clientConfigs = [
      (
        clientName: 'IOS',
        userAgent: kYouTubeIosUserAgent,
        context: {
          'client': {
            'clientName': 'IOS',
            'clientVersion': '19.29.1',
            'deviceMake': 'Apple',
            'deviceModel': 'iPhone16,2',
            'osVersion': '17.5.1.21F90',
            'hl': 'en',
            'gl': 'US',
            'visitorData': ?visitorData,
          },
        },
      ),
      (
        clientName: 'ANDROID_VR',
        userAgent: kYouTubeVrUserAgent,
        context: {
          'client': {
            'clientName': 'ANDROID_VR',
            'clientVersion': '1.56.21',
            'deviceMake': 'Oculus',
            'deviceModel': 'Quest 2',
            'androidSdkVersion': 32,
            'osVersion': '12',
            'hl': 'en',
            'gl': 'US',
            'visitorData': ?visitorData,
          },
        },
      ),
      (
        clientName: 'WEB_EMBEDDED_PLAYER',
        userAgent: kYouTubeSafariUserAgent,
        context: {
          'client': {
            'clientName': 'WEB_EMBEDDED_PLAYER',
            'clientVersion': '1.20240101.01.00',
            'hl': 'en',
            'gl': 'US',
            'visitorData': ?visitorData,
          },
          'thirdParty': {'embedUrl': 'https://www.youtube.com/embed/$videoId'},
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
          'thirdParty': {'embedUrl': 'https://www.youtube.com/embed/$videoId'},
        },
      ),
    ];

    for (final cfg in clientConfigs) {
      if (!_isRequestActive(videoId, requestToken)) return null;
      try {
        debugPrint(
          '[YoutubeAudioService] Probing Layer 2 client ${cfg.clientName} for $videoId...',
        );
        final response = await _httpClient
            .post(
              Uri.parse(
                'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
              ),
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
                  },
                },
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (!_isRequestActive(videoId, requestToken)) return null;
        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final playability = data['playabilityStatus'] as Map<String, dynamic>?;
        if (playability != null && playability['status'] != 'OK') {
          debugPrint(
            '[YoutubeAudioService] InnerTube ${cfg.clientName} unplayable: ${playability['reason'] ?? playability['status']}',
          );
          continue;
        }

        final streamingData = data['streamingData'] as Map<String, dynamic>?;
        if (streamingData == null) continue;

        final rawFormats = <Map<String, dynamic>>[];
        if (streamingData['adaptiveFormats'] is List) {
          rawFormats.addAll(
            (streamingData['adaptiveFormats'] as List)
                .cast<Map<String, dynamic>>(),
          );
        }
        if (streamingData['formats'] is List) {
          rawFormats.addAll(
            (streamingData['formats'] as List).cast<Map<String, dynamic>>(),
          );
        }

        final candidateFormats = rawFormats.where((f) {
          final mime = (f['mimeType'] as String? ?? '').toLowerCase();
          final isAudio =
              mime.startsWith('audio/') || f['audioQuality'] != null;
          final hasDirectUrl =
              f['url'] != null && (f['url'] as String).isNotEmpty;
          final isEncrypted =
              f['signatureCipher'] != null || f['cipher'] != null;
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
          if (!_isRequestActive(videoId, requestToken)) return null;
          final rawUrl = format['url'] as String;
          final mime = (format['mimeType'] as String? ?? 'audio/mp4')
              .split(';')
              .first
              .trim();
          final clen = int.tryParse(format['contentLength']?.toString() ?? '');
          final parsedUri = Uri.parse(rawUrl);
          final matchedUa =
              resolveUserAgentForUrl(
                parsedUri,
                fallbackUserAgent: cfg.userAgent,
              ) ??
              cfg.userAgent;

          try {
            final testReq = await _httpClient
                .get(
                  parsedUri,
                  headers: {
                    'User-Agent': matchedUa,
                    'Range': 'bytes=0-1024',
                  },
                )
                .timeout(const Duration(seconds: 3));

            if (testReq.statusCode == 200 || testReq.statusCode == 206) {
              debugPrint(
                '[YoutubeAudioService] Resolved stream via Layer 2 (${cfg.clientName}) for $videoId (itag: ${format['itag']})',
              );
              return ResolvedAudioStream(
                url: rawUrl,
                userAgent: matchedUa,
                mimeType: mime,
                contentLength: clen,
              );
            }
          } catch (e) {
            debugPrint(
              '[YoutubeAudioService] Stream range probe error for ${cfg.clientName}: $e',
            );
          }
        }
      } catch (e) {
        debugPrint(
          '[YoutubeAudioService] Layer 2 client ${cfg.clientName} error: $e',
        );
      }
    }
    return null;
  }

  /// Layer 3: Queries public Piped & Invidious API instances by exact videoId.
  /// Immediately aborts if [requestToken] is superseded by a newer song tap.
  Future<ResolvedAudioStream?> _resolveLayer3PipedAndInvidious(
    String videoId, {
    int? requestToken,
  }) async {
    if (!_isRequestActive(videoId, requestToken)) return null;

    const defaultUa = kYouTubeSafariUserAgent;

    final instances = [
      (type: 'piped', url: 'https://pipedapi.kavin.rocks/streams/$videoId'),
      (type: 'piped', url: 'https://api.piped.private.coffee/streams/$videoId'),
      (type: 'invidious', url: 'https://inv.nadeko.net/api/v1/videos/$videoId'),
      (
        type: 'invidious',
        url: 'https://invidious.nerdvpn.de/api/v1/videos/$videoId',
      ),
    ];

    for (final inst in instances) {
      if (!_isRequestActive(videoId, requestToken)) {
        debugPrint(
          '[YoutubeAudioService] Canceling stale Layer 3 loop for $videoId',
        );
        return null;
      }
      try {
        final host = Uri.parse(inst.url).host;
        debugPrint(
          '[YoutubeAudioService] Checking Layer 3 ($host) for exact videoId $videoId...',
        );
        final res = await _httpClient
            .get(Uri.parse(inst.url), headers: {'User-Agent': defaultUa})
            .timeout(const Duration(milliseconds: 2500));

        if (!_isRequestActive(videoId, requestToken)) return null;
        if (res.statusCode != 200) continue;

        final data = jsonDecode(res.body) as Map<String, dynamic>;

        if (inst.type == 'piped') {
          final audioStreams =
              (data['audioStreams'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
          final candidates = audioStreams.where((f) {
            final url = f['url'] as String?;
            return url != null && url.isNotEmpty;
          }).toList();

          if (candidates.isEmpty) continue;

          candidates.sort((a, b) {
            final isA140 =
                (a['format'] as String? ?? '').contains('M4A') ||
                (a['mimeType'] as String? ?? '').contains('mp4');
            final isB140 =
                (b['format'] as String? ?? '').contains('M4A') ||
                (b['mimeType'] as String? ?? '').contains('mp4');
            if (isA140 && !isB140) return -1;
            if (!isA140 && isB140) return 1;
            final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
            final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
            return brB.compareTo(brA);
          });

          for (final af in candidates) {
            if (!_isRequestActive(videoId, requestToken)) return null;
            final rawUrl = af['url'] as String;
            final clen = int.tryParse(af['contentLength']?.toString() ?? '');
            try {
              final testRes = await _httpClient
                  .get(
                    Uri.parse(rawUrl),
                    headers: {'User-Agent': defaultUa, 'Range': 'bytes=0-1024'},
                  )
                  .timeout(const Duration(seconds: 2));

              if (testRes.statusCode == 200 || testRes.statusCode == 206) {
                debugPrint(
                  '[YoutubeAudioService] Resolved stream via Layer 3 (Piped: $host) for $videoId',
                );
                return ResolvedAudioStream(
                  url: rawUrl,
                  userAgent: defaultUa,
                  mimeType: (af['mimeType'] as String? ?? 'audio/mp4')
                      .split(';')
                      .first
                      .trim(),
                  contentLength: clen,
                );
              }
            } catch (_) {}
          }
        } else {
          // Invidious format
          final adaptive =
              (data['adaptiveFormats'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          final audioFormats = adaptive.where((f) {
            final type = (f['type'] as String? ?? '').toLowerCase();
            final url = f['url'] as String?;
            return type.startsWith('audio/') && url != null && url.isNotEmpty;
          }).toList();

          if (audioFormats.isEmpty) continue;

          audioFormats.sort((a, b) {
            final isA140 =
                a['itag'] == 140 ||
                (a['type'] as String? ?? '').contains('mp4');
            final isB140 =
                b['itag'] == 140 ||
                (b['type'] as String? ?? '').contains('mp4');
            if (isA140 && !isB140) return -1;
            if (!isA140 && isB140) return 1;
            final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
            final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
            return brB.compareTo(brA);
          });

          for (final af in audioFormats) {
            if (!_isRequestActive(videoId, requestToken)) return null;
            final rawUrl = af['url'] as String;
            final clen = int.tryParse(af['clen']?.toString() ?? '');
            try {
              final testRes = await _httpClient
                  .get(
                    Uri.parse(rawUrl),
                    headers: {'User-Agent': defaultUa, 'Range': 'bytes=0-1024'},
                  )
                  .timeout(const Duration(seconds: 2));

              if (testRes.statusCode == 200 || testRes.statusCode == 206) {
                debugPrint(
                  '[YoutubeAudioService] Resolved stream via Layer 3 (Invidious: $host) for $videoId',
                );
                return ResolvedAudioStream(
                  url: rawUrl,
                  userAgent: defaultUa,
                  mimeType: (af['type'] as String? ?? 'audio/mp4')
                      .split(';')
                      .first
                      .trim(),
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

  /// Races multiple asynchronous resolver tasks in parallel and returns the first non-null result.
  Future<ResolvedAudioStream?> _raceFirstNonNull(
    List<Future<ResolvedAudioStream?> Function()> tasks,
  ) async {
    if (tasks.isEmpty) return null;
    final completer = Completer<ResolvedAudioStream?>();
    int remaining = tasks.length;

    for (final task in tasks) {
      task()
          .then((result) {
            if (!completer.isCompleted) {
              if (result != null) {
                completer.complete(result);
              } else {
                remaining--;
                if (remaining <= 0) {
                  completer.complete(null);
                }
              }
            }
          })
          .catchError((_) {
            if (!completer.isCompleted) {
              remaining--;
              if (remaining <= 0) {
                completer.complete(null);
              }
            }
          });
    }

    return completer.future;
  }

  /// Filters [manifest.audioOnly] to prioritize hardware-accelerated MP4/M4A
  /// container streams (`stream.container == StreamContainer.mp4` or
  /// `stream.codec.mimeType.contains('mp4')`, specifically targeting ~128kbps AAC `itag 140`)
  /// sorted by highest bitrate, and only falls back to WebM/muxed streams if no MP4
  /// audio-only stream exists.
  static StreamInfo? selectBestAudioStream(StreamManifest manifest) {
    final audioOnly = manifest.audioOnly.toList();
    if (audioOnly.isNotEmpty) {
      final mp4Streams = audioOnly.where((stream) {
        final mime = stream.codec.mimeType.toLowerCase();
        return stream.container == StreamContainer.mp4 ||
            mime.contains('mp4') ||
            stream.tag == 140;
      }).toList();

      if (mp4Streams.isNotEmpty) {
        mp4Streams.sort((a, b) {
          final aIs140 = a.tag == 140;
          final bIs140 = b.tag == 140;
          if (aIs140 && !bIs140) return -1;
          if (!aIs140 && bIs140) return 1;
          return b.bitrate.compareTo(a.bitrate);
        });
        return mp4Streams.first;
      }

      // Fallback to WebM/other audio-only streams sorted by highest bitrate
      audioOnly.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      return audioOnly.first;
    }

    // Last resort: check muxed streams if audioOnly is empty
    final muxed = manifest.muxed
        .where(
          (stream) =>
              stream.container == StreamContainer.mp4 ||
              stream.codec.mimeType.toLowerCase().contains('mp4') ||
              stream.codec.mimeType.toLowerCase().contains('audio'),
        )
        .toList();
    if (muxed.isNotEmpty) {
      muxed.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      return muxed.first;
    }

    return null;
  }

  /// Exposes `YoutubeExplode.videos.streamsClient.get(streamInfo)` for [YouTubeByteStreamSource].
  Stream<List<int>> getRawByteStream(StreamInfo streamInfo) {
    return _yt.videos.streamsClient.get(streamInfo);
  }

  /// Opens a chunked HTTP range stream response for [YouTubeByteStreamSource].
  /// Uses YouTube's `&range=start-end` query parameter chunking on `googlevideo.com` URLs
  /// and dynamically matches the `User-Agent` to the URL's `c=` parameter.
  Future<StreamAudioResponse> openRangeStreamResponse({
    required ResolvedAudioStream resolvedStream,
    required int start,
    int? end,
    int? totalLength,
  }) async {
    final effectiveEnd = (end != null && totalLength != null)
        ? end.clamp(start, totalLength)
        : (end ?? totalLength);
    final contentLength = effectiveEnd != null ? (effectiveEnd - start) : null;

    Stream<List<int>> byteStream() async* {
      final chunkSize = 512 * 1024; // 512 KB chunks
      int currentByte = start;
      final targetEndInclusive = effectiveEnd != null ? effectiveEnd - 1 : null;
      final baseUri = Uri.parse(resolvedStream.url);
      final matchedUa = resolvedStream.matchedUserAgent;

      while (targetEndInclusive == null || currentByte <= targetEndInclusive) {
        final chunkEnd = targetEndInclusive != null
            ? (currentByte + chunkSize - 1).clamp(
                currentByte,
                targetEndInclusive,
              )
            : (currentByte + chunkSize - 1);

        final isGoogleVideo = baseUri.host.contains('googlevideo.com');
        final chunkUri = isGoogleVideo
            ? baseUri.replace(
                queryParameters: {
                  ...baseUri.queryParameters,
                  'range': '$currentByte-$chunkEnd',
                },
              )
            : baseUri;

        final req = http.Request('GET', chunkUri);
        if (matchedUa != null && matchedUa.isNotEmpty) {
          req.headers['User-Agent'] = matchedUa;
        }
        req.headers['Accept'] = '*/*';
        req.headers['Connection'] = 'keep-alive';
        if (resolvedStream.referer != null) {
          req.headers['Referer'] = resolvedStream.referer!;
        }
        if (!isGoogleVideo) {
          req.headers['Range'] = 'bytes=$currentByte-$chunkEnd';
        }

        final streamedRes = await _httpClient
            .send(req)
            .timeout(const Duration(seconds: 8));
        if (streamedRes.statusCode != 200 && streamedRes.statusCode != 206) {
          throw HttpException(
            'YouTube range request failed with HTTP ${streamedRes.statusCode}',
            uri: chunkUri,
          );
        }

        int bytesReceivedInChunk = 0;
        await for (final data in streamedRes.stream) {
          bytesReceivedInChunk += data.length;
          yield data;
        }

        if (bytesReceivedInChunk == 0) break;
        currentByte += bytesReceivedInChunk;

        if (!isGoogleVideo && streamedRes.statusCode == 200) {
          break;
        }
      }
    }

    return StreamAudioResponse(
      sourceLength: totalLength,
      contentLength: contentLength,
      offset: start,
      stream: byteStream(),
      contentType: 'audio/mp4',
    );
  }

  /// Resolver 1: Fast Manifest Resolution (`youtube_explode_dart`) with `requireWatchPage: false`.
  /// - NEVER uses `YoutubeApiClient.androidMusic` (which returns HTTP 400).
  /// - Calls `streamsClient.getManifest(videoId, ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr], requireWatchPage: false)`
  ///   so it skips downloading the heavy HTML watch page and resolves in ~1 second.
  /// - If that fails, tries `YoutubeApiClient.safari` and `YoutubeApiClient.tv` individually with `requireWatchPage: false`.
  /// - Matches HTTP `User-Agent` dynamically to `streamInfo.url.queryParameters['c']`.
  Future<ResolvedAudioStream?> _resolveFastManifest(
    String videoId, {
    bool forceFreshClient = false,
    int? requestToken,
  }) async {
    if (!_isRequestActive(videoId, requestToken)) return null;

    if (forceFreshClient) {
      resetYoutubeClient();
    }

    StreamInfo? bestStream;

    // 1. Primary fast call: [ios, androidVr] with requireWatchPage: false (~1 second)
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(
            videoId,
            ytClients: [
              YoutubeApiClient.ios,
              YoutubeApiClient.androidVr,
            ],
            requireWatchPage: false,
          )
          .timeout(const Duration(seconds: 6));

      bestStream = selectBestAudioStream(manifest);
    } catch (e) {
      debugPrint(
        '[YoutubeAudioService] Primary [ios, androidVr] getManifest failed for $videoId: $e',
      );
    }

    // 2. If primary failed, try safari and tv individually with requireWatchPage: false
    if (bestStream == null) {
      final fallbackClients = [
        (name: 'safari', client: YoutubeApiClient.safari),
        (name: 'tv', client: YoutubeApiClient.tv),
      ];
      for (final entry in fallbackClients) {
        if (!_isRequestActive(videoId, requestToken)) return null;
        try {
          final fallbackManifest = await _yt.videos.streamsClient
              .getManifest(
                videoId,
                ytClients: [entry.client],
                requireWatchPage: false,
              )
              .timeout(const Duration(seconds: 5));
          bestStream = selectBestAudioStream(fallbackManifest);
          if (bestStream != null) {
            debugPrint(
              '[YoutubeAudioService] Fallback getManifest (${entry.name}) succeeded for $videoId',
            );
            break;
          }
        } catch (e) {
          debugPrint(
            '[YoutubeAudioService] Fallback getManifest (${entry.name}) failed for $videoId: $e',
          );
        }
      }
    }

    // 3. If still null and we haven't reset the client yet, recreate a fresh YoutubeExplode()
    // and retry [ios, androidVr] with requireWatchPage: false
    if (bestStream == null && !forceFreshClient) {
      if (!_isRequestActive(videoId, requestToken)) return null;
      debugPrint(
        '[YoutubeAudioService] Recreating fresh YoutubeExplode instance and retrying [ios, androidVr] (requireWatchPage: false) for $videoId...',
      );
      resetYoutubeClient();
      try {
        final freshManifest = await _yt.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [
                YoutubeApiClient.ios,
                YoutubeApiClient.androidVr,
              ],
              requireWatchPage: false,
            )
            .timeout(const Duration(seconds: 6));
        bestStream = selectBestAudioStream(freshManifest);
      } catch (e) {
        debugPrint(
          '[YoutubeAudioService] Fresh YoutubeExplode getManifest failed for $videoId: $e',
        );
      }
    }

    if (bestStream != null) {
      final rawUrl = ensureHttps(bestStream.url.toString());
      if (rawUrl.isNotEmpty) {
        final matchedUa = resolveUserAgentForUrl(bestStream.url);
        final clientParam = bestStream.url.queryParameters['c'] ?? 'unknown';
        debugPrint(
          '[YoutubeAudioService] Manifest resolved stream for $videoId (itag: ${bestStream.tag}, c: $clientParam, container: ${bestStream.container.name}, mime: ${bestStream.codec.mimeType})',
        );
        return ResolvedAudioStream(
          url: rawUrl,
          userAgent: matchedUa,
          mimeType: bestStream.codec.mimeType,
          contentLength: bestStream.size.totalBytes,
          streamInfo: bestStream,
        );
      }
    }

    return null;
  }

  /// Resolver 2: Fast direct InnerTube player API using ANDROID_VR / IOS
  /// directly parsing adaptiveFormats for audio/mp4 (itag 140 / 139).
  Future<ResolvedAudioStream?> _resolveFastInnerTube(
    String videoId, {
    int? requestToken,
  }) async {
    if (!_isRequestActive(videoId, requestToken)) return null;

    final clientConfigs = [
      (
        clientName: 'IOS',
        userAgent: kYouTubeIosUserAgent,
        context: {
          'client': {
            'clientName': 'IOS',
            'clientVersion': '19.29.1',
            'deviceMake': 'Apple',
            'deviceModel': 'iPhone16,2',
            'osVersion': '17.5.1.21F90',
            'hl': 'en',
            'gl': 'US',
          },
        },
      ),
      (
        clientName: 'ANDROID_VR',
        userAgent: kYouTubeVrUserAgent,
        context: {
          'client': {
            'clientName': 'ANDROID_VR',
            'clientVersion': '1.56.21',
            'deviceMake': 'Oculus',
            'deviceModel': 'Quest 2',
            'androidSdkVersion': 32,
            'osVersion': '12',
            'hl': 'en',
            'gl': 'US',
          },
        },
      ),
    ];

    for (final cfg in clientConfigs) {
      if (!_isRequestActive(videoId, requestToken)) return null;
      try {
        final response = await _httpClient
            .post(
              Uri.parse(
                'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
              ),
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
                  },
                },
              }),
            )
            .timeout(const Duration(milliseconds: 3500));

        if (!_isRequestActive(videoId, requestToken)) return null;
        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final playability = data['playabilityStatus'] as Map<String, dynamic>?;
        if (playability != null && playability['status'] != 'OK') {
          continue;
        }

        final streamingData = data['streamingData'] as Map<String, dynamic>?;
        if (streamingData == null) continue;

        final rawFormats = <Map<String, dynamic>>[];
        if (streamingData['adaptiveFormats'] is List) {
          rawFormats.addAll(
            (streamingData['adaptiveFormats'] as List)
                .cast<Map<String, dynamic>>(),
          );
        }
        if (streamingData['formats'] is List) {
          rawFormats.addAll(
            (streamingData['formats'] as List).cast<Map<String, dynamic>>(),
          );
        }

        final candidateFormats = rawFormats.where((f) {
          final mime = (f['mimeType'] as String? ?? '').toLowerCase();
          final isAudio =
              mime.startsWith('audio/') || f['audioQuality'] != null;
          final hasDirectUrl =
              f['url'] != null && (f['url'] as String).isNotEmpty;
          final isEncrypted =
              f['signatureCipher'] != null || f['cipher'] != null;
          return isAudio && hasDirectUrl && !isEncrypted;
        }).toList();

        if (candidateFormats.isEmpty) continue;

        candidateFormats.sort((a, b) {
          final aIs140 = a['itag'] == 140 || a['itag'] == 139;
          final bIs140 = b['itag'] == 140 || b['itag'] == 139;
          if (aIs140 && !bIs140) return -1;
          if (!aIs140 && bIs140) return 1;

          final mimeA = (a['mimeType'] as String? ?? '').toLowerCase();
          final mimeB = (b['mimeType'] as String? ?? '').toLowerCase();
          final aIsMp4 = mimeA.contains('mp4');
          final bIsMp4 = mimeB.contains('mp4');
          if (aIsMp4 && !bIsMp4) return -1;
          if (!aIsMp4 && bIsMp4) return 1;

          final bitrateA = (a['bitrate'] as num?)?.toInt() ?? 0;
          final bitrateB = (b['bitrate'] as num?)?.toInt() ?? 0;
          return bitrateB.compareTo(bitrateA);
        });

        for (final format in candidateFormats) {
          if (!_isRequestActive(videoId, requestToken)) return null;
          final rawUrl = format['url'] as String;
          final mime = (format['mimeType'] as String? ?? 'audio/mp4')
              .split(';')
              .first
              .trim();
          final clen = int.tryParse(format['contentLength']?.toString() ?? '');
          final parsedUri = Uri.parse(rawUrl);
          final matchedUa =
              resolveUserAgentForUrl(
                parsedUri,
                fallbackUserAgent: cfg.userAgent,
              ) ??
              cfg.userAgent;

          try {
            final testReq = await _httpClient
                .get(
                  parsedUri,
                  headers: {
                    'User-Agent': matchedUa,
                    'Range': 'bytes=0-1024',
                  },
                )
                .timeout(const Duration(milliseconds: 2500));

            if (testReq.statusCode == 200 || testReq.statusCode == 206) {
              debugPrint(
                '[YoutubeAudioService] Fast InnerTube (Resolver 2: ${cfg.clientName}) resolved stream for $videoId (itag: ${format['itag']})',
              );
              return ResolvedAudioStream(
                url: rawUrl,
                userAgent: matchedUa,
                mimeType: mime,
                contentLength: clen,
              );
            }
          } catch (_) {}
        }
      } catch (_) {}
    }
    return null;
  }

  /// Resolves the best MP4 (`itag 140`) stream for [videoId], caching resolved stream info
  /// (including [AudioOnlyStreamInfo]) per `videoId` in memory for 30 minutes so re-tapping
  /// a song starts immediately. Cancels any stale background resolution loops for older songs.
  Future<ResolvedAudioStream> resolveStream(
    String videoId, {
    String? title,
    String? artist,
    bool forceRefresh = false,
  }) async {
    final requestToken = beginResolveRequest(videoId);

    if (forceRefresh) {
      invalidateStreamCache(videoId);
      resetYoutubeClient();
    } else {
      final cached = _getCachedStream(videoId);
      if (cached != null) {
        debugPrint(
          '[YoutubeAudioService] Returning 30-min cached stream for $videoId',
        );
        return cached;
      }
    }

    final resolved = await _resolveAudioStream(
      videoId,
      fallback: forceRefresh,
      requestToken: requestToken,
    );
    if (resolved == null) {
      throw Exception(
        'Failed to resolve playable audio stream for YouTube video $videoId',
      );
    }

    _cacheStream(videoId, resolved);
    return resolved;
  }

  /// Returns a localhost proxy URL (`http://127.0.0.1:<port>/stream?id=<videoId>`)
  /// backed by an already-resolved [resolved] stream in memory (zero re-fetch!).
  Future<String> getProxyUrlForResolvedStream(
    String videoId,
    ResolvedAudioStream resolved,
  ) async {
    await _ensureProxyServer();
    _cacheStream(videoId, resolved);
    return 'http://127.0.0.1:${_proxyServer!.port}/stream?id=$videoId';
  }

  /// Exact videoId audio resolver. NEVER queries third-party catalogs by text/title.
  Future<ResolvedAudioStream?> _resolveAudioStream(
    String videoId, {
    bool fallback = false,
    int? requestToken,
  }) async {
    if (!_isRequestActive(videoId, requestToken)) return null;

    // 1. In-memory URL cache check (30-min TTL for re-tapped or recently played songs)
    if (!fallback) {
      final cached = _getCachedStream(videoId);
      if (cached != null) {
        debugPrint(
          '[YoutubeAudioService] Returning 0ms in-memory cached stream for $videoId',
        );
        return cached;
      }
    }

    // If a custom HTTP client is injected for tests without a custom YoutubeExplode client,
    // race InnerTube and Manifest in parallel so HTTP mocks resolve immediately.
    if (_hasCustomHttpClient && !_hasCustomYtClient) {
      if (!fallback) {
        final fastResult = await _raceFirstNonNull([
          () => _resolveFastInnerTube(videoId, requestToken: requestToken),
          () => _resolveFastManifest(videoId, requestToken: requestToken),
        ]);
        if (fastResult != null) {
          _cacheStream(videoId, fastResult);
          return fastResult;
        }
      }
    } else {
      // Primary: Fast Manifest Resolution ([ios, androidVr] with requireWatchPage: false)
      // + safari/tv fallback with requireWatchPage: false.
      final manifestStream = await _resolveFastManifest(
        videoId,
        forceFreshClient: fallback,
        requestToken: requestToken,
      );
      if (manifestStream != null) {
        _cacheStream(videoId, manifestStream);
        return manifestStream;
      }

      if (!_isRequestActive(videoId, requestToken)) return null;

      // Secondary fast InnerTube probe if manifest resolution returned null
      final fastInnerTube = await _resolveFastInnerTube(
        videoId,
        requestToken: requestToken,
      );
      if (fastInnerTube != null) {
        _cacheStream(videoId, fastInnerTube);
        return fastInnerTube;
      }
    }

    if (!_isRequestActive(videoId, requestToken)) return null;

    // Fallback stages with full client sets if primary resolution did not resolve
    debugPrint(
      '[YoutubeAudioService] Primary resolution missed, executing secondary layers for $videoId...',
    );
    final layer2Stream = await _resolveLayer2InnerTube(
      videoId,
      requestToken: requestToken,
    );
    if (layer2Stream != null) {
      _cacheStream(videoId, layer2Stream);
      return layer2Stream;
    }

    if (!_isRequestActive(videoId, requestToken)) return null;

    final layer1Stream = await _resolveLayer1YoutubeExplode(
      videoId,
      requestToken: requestToken,
    );
    if (layer1Stream != null) {
      _cacheStream(videoId, layer1Stream);
      return layer1Stream;
    }

    if (!_isRequestActive(videoId, requestToken)) return null;

    final layer3Stream = await _resolveLayer3PipedAndInvidious(
      videoId,
      requestToken: requestToken,
    );
    if (layer3Stream != null) {
      _cacheStream(videoId, layer3Stream);
      return layer3Stream;
    }

    return null;
  }

  /// Resolves the audio stream for the exact [videoId] and returns the local loopback proxy URL for ExoPlayer.
  /// ExoPlayer streams from our local proxy which pipes `_yt.videos.streamsClient.get(streamInfo)`
  /// (or Range requests with matched client User-Agents) without HTTP 403 errors.
  Future<String> getAudioStreamUrl(
    String videoId, {
    String? title,
    String? artist,
    bool fallback = false,
  }) async {
    final requestToken = beginResolveRequest(videoId);
    await _ensureProxyServer();

    final cacheFile = File('${_cacheDir.path}/yt_$videoId.m4a');
    if (cacheFile.existsSync() && cacheFile.lengthSync() > 10000) {
      debugPrint(
        '[YoutubeAudioService] Serving exact video $videoId from local disk cache: ${cacheFile.path}',
      );
      return 'http://127.0.0.1:${_proxyServer!.port}/stream?id=$videoId';
    }

    if (fallback) {
      invalidateStreamCache(videoId);
    }

    var resolved = _getCachedStream(videoId);
    if (resolved == null || fallback) {
      resolved = await _resolveAudioStream(
        videoId,
        fallback: fallback,
        requestToken: requestToken,
      );
      if (resolved == null) {
        throw Exception(
          'Failed to resolve playable audio stream for YouTube video $videoId',
        );
      }
      _cacheStream(videoId, resolved);
    }

    return 'http://127.0.0.1:${_proxyServer!.port}/stream?id=$videoId';
  }

  void dispose() {
    cancelActiveResolutions();
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

final onlineSearchResultsProvider = FutureProvider.family<List<Song>, String>((
  ref,
  query,
) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];
  final service = ref.watch(youtubeAudioServiceProvider);
  return service.searchSongs(trimmed);
});
