import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spinora/core/audio/track.dart';
import 'package:spinora/core/database/app_database.dart';
import 'package:spinora/features/online/data/youtube_audio_service.dart';
import 'package:spinora/features/player/application/lyrics_controller.dart';
import 'package:spinora/features/player/application/player_controller.dart';
import 'package:spinora/features/library/presentation/widgets/online_search_view.dart';

class _MockHttpClient extends http.BaseClient {
  _MockHttpClient([this._handler, this._responseBody]);
  final Future<http.StreamedResponse> Function(http.BaseRequest request)? _handler;
  final String? _responseBody;

  factory _MockHttpClient.withBody(String responseBody) {
    return _MockHttpClient(null, responseBody);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final handler = _handler;
    if (handler != null) {
      return handler(request);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(_responseBody ?? '{}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('YoutubeAudioService virtual ID & mapping tests', () {
    test('generateVirtualId produces deterministic negative integers', () {
      final id1 = YoutubeAudioService.generateVirtualId('dQw4w9WgXcQ');
      final id2 = YoutubeAudioService.generateVirtualId('dQw4w9WgXcQ');
      final id3 = YoutubeAudioService.generateVirtualId('9bZkp7q19f0');

      expect(id1, id2, reason: 'Identical videoId must produce identical ID');
      expect(id1 < 0, true, reason: 'Virtual ID must be negative to avoid Drift collision');
      expect(id3 < 0, true, reason: 'Virtual ID must be negative to avoid Drift collision');
      expect(id1 != id3, true);
    });

    test('cleanSongQuery removes YouTube fluff and formats clean query', () {
      expect(
        YoutubeAudioService.cleanSongQuery(
          'Lionel Richie - Hello (Official Music Video)',
          'LionelRichieVEVO',
        ),
        'Lionel Richie Hello',
      );
      expect(
        YoutubeAudioService.cleanSongQuery(
          'Aaj Ki Raat (From Stree 2) [Official Video] | 4K',
          'Saregama Music',
        ),
        'Saregama Music Aaj Ki Raat From Stree 2',
      );
      expect(
        YoutubeAudioService.cleanSongQuery('Lofi Chill Beats [24/7 Live Stream]'),
        'Lofi Chill Beats',
      );
    });

    test('ensureHttps upgrades http:// URLs to https:// and leaves https:// intact', () {
      expect(
        YoutubeAudioService.ensureHttps('http://rr1---sn-abc.googlevideo.com/videoplayback?id=123'),
        'https://rr1---sn-abc.googlevideo.com/videoplayback?id=123',
      );
      expect(
        YoutubeAudioService.ensureHttps('https://rr1---sn-abc.googlevideo.com/videoplayback?id=123'),
        'https://rr1---sn-abc.googlevideo.com/videoplayback?id=123',
      );
      expect(
        YoutubeAudioService.ensureHttps('file:///path/to/audio.mp3'),
        'file:///path/to/audio.mp3',
      );
    });

    test('parseDurationText correctly parses mm:ss and hh:mm:ss to milliseconds', () {
      expect(YoutubeAudioService.parseDurationText('3:45'), 225000);
      expect(YoutubeAudioService.parseDurationText('1:02:05'), 3725000);
      expect(YoutubeAudioService.parseDurationText('0:45'), 45000);
      expect(YoutubeAudioService.parseDurationText(''), 0);
      expect(YoutubeAudioService.parseDurationText(null), 0);
    });

    test('searchSongs falls back cleanly to InnerTube on queries like aaj without crashing', () async {
      final mockInnerTubeJson = jsonEncode({
        'contents': {
          'twoColumnSearchResultsRenderer': {
            'primaryContents': {
              'sectionListRenderer': {
                'contents': [
                  {
                    'itemSectionRenderer': {
                      'contents': [
                        {
                          'videoRenderer': {
                            'videoId': 'mockAaj123',
                            'title': {
                              'runs': [
                                {'text': 'Aaj Ki Raat (From Stree 2)'}
                              ]
                            },
                            'ownerText': {
                              'runs': [
                                {'text': 'Saregama Music'}
                              ]
                            },
                            'lengthText': {'simpleText': '3:48'},
                            'thumbnail': {
                              'thumbnails': [
                                {
                                  'url':
                                      'https://i.ytimg.com/vi/mockAaj123/hqdefault.jpg'
                                }
                              ]
                            }
                          }
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      });

      final mockClient = _MockHttpClient.withBody(mockInnerTubeJson);
      final service = YoutubeAudioService(httpClient: mockClient);
      final results = await service.searchSongs('aaj');
      expect(results, isNotEmpty);
      expect(results.first.filePath, 'yt://mockAaj123');
      expect(results.first.title, 'Aaj Ki Raat (From Stree 2)');
      expect(results.first.artist, 'Saregama Music');
      expect(results.first.duration, 228000);
      expect(results.first.album, 'YouTube Stream');
      service.dispose();
    });

    test('getAudioStreamUrl parses direct InnerTube audio without probing streams 133 or 137', () async {
      final mockInnerTubePlayerJson = jsonEncode({
        'playabilityStatus': {'status': 'OK'},
        'streamingData': {
          'adaptiveFormats': [
            {
              'itag': 137, // 1080p video stream (the one that 403s on YouTube)
              'mimeType': 'video/mp4; codecs="avc1.640028"',
              'bitrate': 2500000,
            },
            {
              'itag': 133, // 240p video stream (the other one that 403s)
              'mimeType': 'video/mp4; codecs="avc1.4d400d"',
              'bitrate': 250000,
            },
            {
              'itag': 140, // Audio stream!
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'bitrate': 129000,
              'contentLength': '3456789',
              'url': 'https://rr1---sn-mock.googlevideo.com/videoplayback?id=mockVideo123&itag=140',
            },
          ],
        },
      });

      final mockClient = _MockHttpClient((req) async {
        // Range probe check
        if (req.url.host.contains('googlevideo.com')) {
          return http.StreamedResponse(
            Stream.value([1, 2, 3, 4]),
            206,
            headers: {
              'content-type': 'audio/mp4',
              'content-range': 'bytes 0-3/3456789',
              'content-length': '4',
            },
          );
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(mockInnerTubePlayerJson)),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = YoutubeAudioService(httpClient: mockClient);
      final streamUrl = await service.getAudioStreamUrl('mockVideo123');
      expect(streamUrl.startsWith('http://127.0.0.1:'), true);
      expect(streamUrl.contains('mockVideo123'), true);
      expect(streamUrl.contains('/stream'), true);
      service.dispose();
    });

    test('getAudioStreamUrl resolves exact videoId via Layer 2 InnerTube with visitorData', () async {
      final mockVisitorJson = jsonEncode({
        'responseContext': {
          'visitorData': 'mockVisitorData123',
        },
      });

      final mockInnerTubePlayerJson = jsonEncode({
        'playabilityStatus': {'status': 'OK'},
        'streamingData': {
          'adaptiveFormats': [
            {
              'itag': 140,
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'bitrate': 129000,
              'contentLength': '3456789',
              'url': 'https://rr1---sn-mock.googlevideo.com/videoplayback?id=mockExactVideoId&itag=140',
            },
          ],
        },
      });

      final mockClient = _MockHttpClient((req) async {
        final urlStr = req.url.toString();
        if (urlStr.contains('visitor_id')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(mockVisitorJson)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (urlStr.contains('youtubei/v1/player')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(mockInnerTubePlayerJson)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (urlStr.contains('googlevideo.com')) {
          return http.StreamedResponse(
            Stream.value([1, 2, 3, 4]),
            206,
            headers: {
              'content-type': 'audio/mp4',
              'content-range': 'bytes 0-3/3456789',
              'content-length': '4',
            },
          );
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode('{}')),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = YoutubeAudioService(httpClient: mockClient);
      final streamUrl = await service.getAudioStreamUrl('mockExactVideoId');
      expect(streamUrl.startsWith('http://127.0.0.1:'), true);
      expect(streamUrl.contains('mockExactVideoId'), true);
      expect(streamUrl.contains('/stream'), true);
      service.dispose();
    });

    test('getAudioStreamUrl resolves exact videoId via Layer 3 Invidious / Piped when Layers 1 & 2 fail', () async {
      final mockUnplayableJson = jsonEncode({
        'playabilityStatus': {
          'status': 'LOGIN_REQUIRED',
          'reason': 'Sign in to confirm you’re not a bot',
        },
      });

      final mockPipedStreamJson = jsonEncode({
        'audioStreams': [
          {
            'url': 'https://mock.piped.video/stream/mockExactVideo3?itag=140',
            'format': 'M4A',
            'bitrate': 128000,
            'contentLength': 4567890,
            'mimeType': 'audio/mp4',
          },
        ],
      });

      bool saavnSearchCalled = false;

      final mockClient = _MockHttpClient((req) async {
        final urlStr = req.url.toString();
        if (urlStr.contains('jiosaavn.com')) {
          saavnSearchCalled = true;
        }
        if (urlStr.contains('youtubei/v1/player') || urlStr.contains('visitor_id')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(mockUnplayableJson)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (urlStr.contains('pipedapi') || urlStr.contains('/streams/')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(mockPipedStreamJson)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (urlStr.contains('mock.piped.video')) {
          return http.StreamedResponse(
            Stream.value([1, 2, 3, 4]),
            206,
            headers: {
              'content-type': 'audio/mp4',
              'content-range': 'bytes 0-3/4567890',
              'content-length': '4',
            },
          );
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode('{}')),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = YoutubeAudioService(httpClient: mockClient);
      final streamUrl = await service.getAudioStreamUrl(
        'mockExactVideo3',
        title: 'Adele - Hello',
        artist: 'Adele',
      );
      expect(streamUrl.startsWith('http://127.0.0.1:'), true);
      expect(streamUrl.contains('mockExactVideo3'), true);
      expect(streamUrl.contains('/stream'), true);
      expect(saavnSearchCalled, false, reason: 'Third-party text search must NEVER be called to swap songs');
      service.dispose();
    });

    test('getAudioStreamUrl caches resolved stream in memory for instant subsequent playback', () async {
      int networkCalls = 0;
      final mockInnerTubePlayerJson = jsonEncode({
        'playabilityStatus': {'status': 'OK'},
        'streamingData': {
          'adaptiveFormats': [
            {
              'itag': 140,
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'bitrate': 129000,
              'contentLength': '3456789',
              'url': 'https://rr1---sn-mock.googlevideo.com/videoplayback?id=mockCachedVid&itag=140',
            },
          ],
        },
      });

      final mockClient = _MockHttpClient((req) async {
        networkCalls++;
        if (req.url.host.contains('googlevideo.com')) {
          return http.StreamedResponse(
            Stream.value([1, 2, 3, 4]),
            206,
            headers: {
              'content-type': 'audio/mp4',
              'content-range': 'bytes 0-3/3456789',
              'content-length': '4',
            },
          );
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(mockInnerTubePlayerJson)),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = YoutubeAudioService(httpClient: mockClient);
      final firstUrl = await service.getAudioStreamUrl('mockCachedVid');
      final callsAfterFirst = networkCalls;

      final secondUrl = await service.getAudioStreamUrl('mockCachedVid');
      expect(firstUrl, secondUrl);
      expect(networkCalls, callsAfterFirst, reason: 'Second call must return from in-memory cache in 0ms');
      service.dispose();
    });

    test('Track.fromSong correctly flags yt:// as TrackSource.online without file:// prefix', () {
      final onlineSong = Song(
        id: YoutubeAudioService.generateVirtualId('abc123xyz'),
        title: 'Online Stream Track',
        artist: 'Online Artist',
        album: 'YouTube Stream',
        duration: 215000,
        filePath: 'yt://abc123xyz',
        albumArtPath: 'https://i.ytimg.com/vi/abc123xyz/hqdefault.jpg',
        isFavorite: false,
        playCount: 0,
        isCustomEdited: false,
        isHidden: false,
      );

      final track = Track.fromSong(onlineSong);

      expect(track.source, TrackSource.online);
      expect(track.uri, 'yt://abc123xyz');
      expect(track.uri.startsWith('file://'), false);
      expect(track.artworkUri, 'https://i.ytimg.com/vi/abc123xyz/hqdefault.jpg');
      expect(track.durationMs, 215000);
      expect(track.title, 'Online Stream Track');
      expect(track.artist, 'Online Artist');
    });

    test('Track.fromSong correctly handles local file paths with file:// scheme', () {
      final localSong = Song(
        id: 42,
        title: 'Local Track',
        artist: 'Local Artist',
        album: 'Local Album',
        duration: 180000,
        filePath: '/storage/emulated/0/Music/song.mp3',
        albumArtPath: '/storage/emulated/0/Music/song.jpg',
        isFavorite: true,
        playCount: 5,
        isCustomEdited: false,
        isHidden: false,
      );

      final track = Track.fromSong(localSong);

      expect(track.source, TrackSource.local);
      expect(track.uri, 'file:///storage/emulated/0/Music/song.mp3');
      expect(track.artworkUri, '/storage/emulated/0/Music/song.jpg');
    });
  });

  group('OnlineLyricsCacheNotifier tests', () {
    test('allows caching and retrieving lyrics by track id and uri', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const lrcContent = '[00:01.00]Line 1\n[00:05.00]Line 2';
      final notifier = container.read(onlineLyricsCacheProvider.notifier);

      notifier.cacheLyrics('yt://abc123xyz', lrcContent);
      notifier.cacheLyrics('-98765', lrcContent);

      final cache = container.read(onlineLyricsCacheProvider);
      expect(cache['yt://abc123xyz'], lrcContent);
      expect(cache['-98765'], lrcContent);
      expect(cache['unknown'], isNull);
    });
  });

  group('PlayerState buffering property tests', () {
    test('isBuffering defaults to false and copyWith toggles it', () {
      const state = PlayerState();
      expect(state.isBuffering, false);

      final bufferingState = state.copyWith(isBuffering: true);
      expect(bufferingState.isBuffering, true);

      final resumedState = bufferingState.copyWith(isBuffering: false);
      expect(resumedState.isBuffering, false);
    });
  });

  group('OnlineSearchView widget tests', () {
    testWidgets('renders prompt card and suggestion chips when query is empty', (tester) async {
      String? tappedSuggestion;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: OnlineSearchView(
                searchQuery: '',
                onSuggestionTap: (tag) => tappedSuggestion = tag,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Online Audio Search & Stream'), findsOneWidget);
      expect(find.text('Lofi Beats'), findsOneWidget);
      expect(find.text('Synthwave Chill'), findsOneWidget);

      await tester.tap(find.text('Lofi Beats'));
      await tester.pump();

      expect(tappedSuggestion, 'Lofi Beats');
    });

    testWidgets('renders online results when query has matches', (tester) async {
      final mockSongs = [
        Song(
          id: -1001,
          title: 'Cyberpunk 2077 Theme',
          artist: 'Marcin Przybyłowicz',
          album: 'YouTube Stream',
          duration: 180000,
          filePath: 'yt://cyberpunk123',
          albumArtPath: 'https://i.ytimg.com/vi/cyberpunk123/hqdefault.jpg',
          isFavorite: false,
          playCount: 0,
          isCustomEdited: false,
          isHidden: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineSearchResultsProvider('cyberpunk')
                .overrideWith((ref) => mockSongs),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OnlineSearchView(
                searchQuery: 'cyberpunk',
                onSuggestionTap: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Cyberpunk 2077 Theme'), findsOneWidget);
      expect(find.text('Marcin Przybyłowicz'), findsOneWidget);
      expect(find.text('STREAM'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
    });
  });

  group('Resilient MP4 stream selection, caching, and YouTubeByteStreamSource fallback tests', () {
    test('resolveStream prioritizes MP4 (itag 140) over higher-bitrate WebM (itag 251) and caches for 30 minutes', () async {
      int playerCalls = 0;
      final mockInnerTubePlayerJson = jsonEncode({
        'playabilityStatus': {'status': 'OK'},
        'streamingData': {
          'adaptiveFormats': [
            {
              'itag': 251,
              'mimeType': 'audio/webm; codecs="opus"',
              'bitrate': 160000,
              'contentLength': '4000000',
              'url': 'https://rr1---sn-mock.googlevideo.com/videoplayback?id=mp4TestVid&itag=251',
            },
            {
              'itag': 140,
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'bitrate': 128000,
              'contentLength': '3200000',
              'url': 'https://rr1---sn-mock.googlevideo.com/videoplayback?id=mp4TestVid&itag=140',
            },
          ],
        },
      });

      final mockClient = _MockHttpClient((req) async {
        if (req.url.toString().contains('youtubei/v1/player')) {
          playerCalls++;
          return http.StreamedResponse(
            Stream.value(utf8.encode(mockInnerTubePlayerJson)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.host.contains('googlevideo.com')) {
          return http.StreamedResponse(
            Stream.value([1, 2, 3, 4]),
            206,
            headers: {
              'content-type': 'audio/mp4',
              'content-range': 'bytes 0-3/3200000',
              'content-length': '4',
            },
          );
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode('{}')),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = YoutubeAudioService(httpClient: mockClient);
      final resolved = await service.resolveStream('mp4TestVid');
      expect(resolved.url.contains('itag=140'), true, reason: 'Must select MP4 itag 140 over WebM itag 251');
      expect(resolved.mimeType, 'audio/mp4');

      final callsAfterFirst = playerCalls;
      final cachedResolved = await service.resolveStream('mp4TestVid');
      expect(cachedResolved.url, resolved.url);
      expect(playerCalls, callsAfterFirst, reason: 'Must serve from 30-min cache without re-fetching');

      // Invalidate on error and verify re-fetch
      service.invalidateStreamCache('mp4TestVid');
      await service.resolveStream('mp4TestVid');
      expect(playerCalls > callsAfterFirst, true, reason: 'Must re-fetch after cache invalidation');
      service.dispose();
    });

    test('YouTubeByteStreamSource streams chunked range bytes cleanly', () async {
      final mockBytes = List<int>.generate(1024, (i) => i % 256);
      final mockClient = _MockHttpClient((req) async {
        return http.StreamedResponse(
          Stream.value(mockBytes),
          200,
          headers: {
            'content-type': 'audio/mp4',
            'content-length': '${mockBytes.length}',
          },
        );
      });

      final service = YoutubeAudioService(httpClient: mockClient);
      const resolved = ResolvedAudioStream(
        url: 'https://rr1---sn-mock.googlevideo.com/videoplayback?id=byteTest&itag=140',
        userAgent: kYouTubeVrUserAgent,
        mimeType: 'audio/mp4',
        contentLength: 1024,
      );

      final byteSource = YouTubeByteStreamSource(
        videoId: 'byteTest',
        resolvedStream: resolved,
        youtubeService: service,
      );

      final response = await byteSource.request(0, 1024);
      expect(response.contentType, 'audio/mp4');
      expect(response.sourceLength, 1024);

      final collected = <int>[];
      await for (final chunk in response.stream) {
        collected.addAll(chunk);
      }
      expect(collected.length, 1024);
      service.dispose();
    });
  });
}
