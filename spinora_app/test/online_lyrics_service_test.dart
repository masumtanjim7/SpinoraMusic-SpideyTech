import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spinora/core/database/app_database.dart';
import 'package:spinora/features/player/application/lyrics_controller.dart';
import 'package:spinora/features/player/data/online_lyrics_service.dart';

void main() {
  group('Smart Metadata Cleaner & cleanQueryText', () {
    test('strips parenthesized and bracketed tags', () {
      expect(
        OnlineLyricsService.cleanQueryText('Blinding Lights (Official Video)'),
        'Blinding Lights',
      );
      expect(
        OnlineLyricsService.cleanQueryText('Starboy [Official Audio]'),
        'Starboy',
      );
      expect(
        OnlineLyricsService.cleanQueryText('Shape of You (Lyrics) [320kbps]'),
        'Shape of You',
      );
      expect(
        OnlineLyricsService.cleanQueryText('Levitating (Visualizer)'),
        'Levitating',
      );
      expect(
        OnlineLyricsService.cleanQueryText('Despacito [Official 4K]'),
        'Despacito',
      );
    });

    test('strips file extensions, bitrates, and website watermarks', () {
      expect(
        OnlineLyricsService.cleanQueryText('song_name_320kbps.mp3'),
        'song name',
      );
      expect(
        OnlineLyricsService.cleanQueryText('track1.m4a 128kbps'),
        'track1',
      );
      expect(
        OnlineLyricsService.cleanQueryText('www.PagalWorld.com - Dilbar.flac'),
        'Dilbar',
      );
      expect(
        OnlineLyricsService.cleanQueryText('DJPunjab.com Brown Munde.wav'),
        'Brown Munde',
      );
    });

    test('strips ft. and feat. collaborators in song titles', () {
      expect(
        OnlineLyricsService.cleanQueryText('Industry Baby feat. Jack Harlow'),
        'Industry Baby',
      );
      expect(
        OnlineLyricsService.cleanQueryText('Save Your Tears ft. Ariana Grande'),
        'Save Your Tears',
      );
    });

    test('cleanSongMetadata automatically splits "Artist - Title" if artist is unknown', () {
      final cleaned1 = OnlineLyricsService.cleanSongMetadata(
        rawTitle: 'The Weeknd - Blinding Lights (Official Audio).mp3',
        rawArtist: '<unknown>',
      );
      expect(cleaned1.artist, 'The Weeknd');
      expect(cleaned1.title, 'Blinding Lights');

      final cleaned2 = OnlineLyricsService.cleanSongMetadata(
        rawTitle: 'Arijit Singh - Kesariya [PagalWorld.com]',
        rawArtist: 'Unknown Artist',
      );
      expect(cleaned2.artist, 'Arijit Singh');
      expect(cleaned2.title, 'Kesariya');
    });

    test('cleanSongMetadata preserves known artists while cleaning noise', () {
      final cleaned = OnlineLyricsService.cleanSongMetadata(
        rawTitle: 'Believer (Lyrics Video) [320kbps]',
        rawArtist: 'Imagine Dragons ft. Lil Wayne',
      );
      expect(cleaned.title, 'Believer');
      expect(cleaned.artist, 'Imagine Dragons');
    });
  });

  group('OnlineLyricsService API Fetching & Candidate Ranking', () {
    test('fetches synced lyrics successfully from LRCLIB primary search', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'lrclib.net');
        expect(request.headers['User-Agent'], contains('SpinoraMusic/1.0.0'));

        final responseJson = [
          {
            'id': 101,
            'trackName': 'Blinding Lights',
            'artistName': 'The Weeknd',
            'duration': 200.0,
            'plainLyrics': 'I said ooh, I am blinded by the lights',
            'syncedLyrics': '[00:15.20]I said ooh, I am blinded by the lights\n[00:20.10]No I cannot sleep',
          },
        ];

        return http.Response(jsonEncode(responseJson), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final service = OnlineLyricsService(client: mockClient);
      const song = Song(
        id: 1,
        title: 'Blinding Lights (Official Video)',
        artist: 'The Weeknd',
        duration: 200000,
        filePath: '/music/blinding_lights.mp3',
        isFavorite: false,
        album: null,
        playCount: 0,
        lastPlayedAt: null,
        lyrics: null,
        isCustomEdited: false,
        isHidden: false,
      );

      final result = await service.fetchLyricsForSong(song);

      expect(result, isNotNull);
      expect(result, contains('[00:15.20]I said ooh, I am blinded by the lights'));
    });

    test('prioritizes synced lyrics candidate and closest duration over plain lyrics', () async {
      final mockClient = MockClient((request) async {
        final responseJson = [
          {
            'id': 1,
            'trackName': 'Blinding Lights',
            'artistName': 'The Weeknd',
            'duration': 200.0,
            'plainLyrics': 'Plain unsynced lyrics version',
            'syncedLyrics': null,
          },
          {
            'id': 2,
            'trackName': 'Blinding Lights',
            'artistName': 'The Weeknd',
            'duration': 200.0,
            'plainLyrics': 'Plain version',
            'syncedLyrics': '[00:10.00]Synced high quality line',
          },
        ];

        return http.Response(jsonEncode(responseJson), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final service = OnlineLyricsService(client: mockClient);
      const song = Song(
        id: 2,
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: 200000,
        filePath: '/music/blinding_lights.mp3',
        isFavorite: false,
        album: null,
        playCount: 0,
        lastPlayedAt: null,
        lyrics: null,
        isCustomEdited: false,
        isHidden: false,
      );

      final result = await service.fetchLyricsForSong(song);

      expect(result, '[00:10.00]Synced high quality line');
    });

    test('falls back to secondary query when initial track_name & artist_name returns empty', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          // First query returns empty list
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        } else {
          // Second fallback query returns result
          final responseJson = [
            {
              'id': 99,
              'trackName': 'Stay',
              'artistName': 'The Kid LAROI',
              'duration': 140.0,
              'syncedLyrics': '[00:05.00]I do the same thing I told you that I never would',
            },
          ];
          return http.Response(jsonEncode(responseJson), 200, headers: {'content-type': 'application/json'});
        }
      });

      final service = OnlineLyricsService(client: mockClient);
      const song = Song(
        id: 3,
        title: 'Stay',
        artist: 'The Kid LAROI',
        duration: 140000,
        filePath: '/music/stay.mp3',
        isFavorite: false,
        album: null,
        playCount: 0,
        lastPlayedAt: null,
        lyrics: null,
        isCustomEdited: false,
        isHidden: false,
      );

      final result = await service.fetchLyricsForSong(song);

      expect(callCount, 2);
      expect(result, '[00:05.00]I do the same thing I told you that I never would');
    });

    test('gracefully returns null on network exception without throwing', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Socket error: no internet connection');
      });

      final service = OnlineLyricsService(client: mockClient);
      const song = Song(
        id: 4,
        title: 'Offline Song',
        artist: 'Offline Artist',
        duration: 180000,
        filePath: '/music/offline.mp3',
        isFavorite: false,
        album: null,
        playCount: 0,
        lastPlayedAt: null,
        lyrics: null,
        isCustomEdited: false,
        isHidden: false,
      );

      final result = await service.fetchLyricsForSong(song);
      expect(result, isNull);
    });
  });

  group('LyricsController & Drift Caching Integration', () {
    test('fetches online lyrics and writes them directly into Drift database', () async {
      final memoryDb = AppDatabase(NativeDatabase.memory());
      addTearDown(() => memoryDb.close());

      final songId = await memoryDb.into(memoryDb.songs).insert(
            SongsCompanion.insert(
              title: 'Mock Track (Lyrics)',
              artist: 'Mock Artist',
              duration: 150000,
              filePath: '/music/mock.mp3',
            ),
          );

      final mockClient = MockClient((request) async {
        final responseJson = [
          {
            'id': 500,
            'trackName': 'Mock Track',
            'artistName': 'Mock Artist',
            'duration': 150.0,
            'syncedLyrics': '[00:12.34]Fetched from online and cached to Drift!',
          },
        ];
        return http.Response(jsonEncode(responseJson), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final mockService = OnlineLyricsService(client: mockClient);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(memoryDb),
          onlineLyricsServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(() => container.dispose());

      final songBefore = await memoryDb.getSongById(songId);
      expect(songBefore!.lyrics, isNull);

      final controller = container.read(lyricsControllerProvider.notifier);
      final success = await controller.refetchLyrics(songBefore);

      expect(success, isTrue);

      // Verify song lyrics are now permanently stored in Drift
      final songAfter = await memoryDb.getSongById(songId);
      expect(songAfter!.lyrics, '[00:12.34]Fetched from online and cached to Drift!');
    });

    test('refetchLyrics with customQuery passes search query to service', () async {
      final memoryDb = AppDatabase(NativeDatabase.memory());
      addTearDown(() => memoryDb.close());

      final songId = await memoryDb.into(memoryDb.songs).insert(
            SongsCompanion.insert(
              title: 'Unknown Title',
              artist: '<unknown>',
              duration: 200000,
              filePath: '/music/unknown.mp3',
            ),
          );

      String? requestedUrl;
      final mockClient = MockClient((request) async {
        requestedUrl = request.url.toString();
        final responseJson = [
          {
            'id': 777,
            'trackName': 'Numb',
            'artistName': 'Linkin Park',
            'duration': 187.0,
            'syncedLyrics': "[00:20.00]I've become so numb, I can't feel you there",
          },
        ];
        return http.Response(jsonEncode(responseJson), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final mockService = OnlineLyricsService(client: mockClient);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(memoryDb),
          onlineLyricsServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(() => container.dispose());

      final song = await memoryDb.getSongById(songId);
      final controller = container.read(lyricsControllerProvider.notifier);

      final success = await controller.refetchLyrics(
        song!,
        customQuery: 'Linkin Park - Numb',
      );

      expect(success, isTrue);
      expect(requestedUrl, contains('Linkin'));
      final cachedSong = await memoryDb.getSongById(songId);
      expect(cachedSong!.lyrics, "[00:20.00]I've become so numb, I can't feel you there");
    });
  });
}
