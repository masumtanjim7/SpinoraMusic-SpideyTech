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
  _MockHttpClient(this.responseBody);
  final String responseBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
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

      final mockClient = _MockHttpClient(mockInnerTubeJson);
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
}
