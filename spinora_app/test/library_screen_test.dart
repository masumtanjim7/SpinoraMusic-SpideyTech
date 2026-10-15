import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/database/app_database.dart';
import 'package:spinora/features/library/data/audio_scanner_service.dart';
import 'package:spinora/features/library/presentation/library_screen.dart';

void main() {
  testWidgets('LibraryScreen renders empty view when no songs are present',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Music Library'), findsOneWidget);
    expect(find.text('No Songs Found'), findsOneWidget);
    expect(find.text('Scan Storage Now'), findsOneWidget);
  });

  testWidgets('LibraryScreen renders song tiles when songs are loaded',
      (tester) async {
    final fakeSongs = [
      const Song(
        id: 1,
        title: 'Mock Track 1',
        artist: 'Artist A',
        album: 'Album X',
        duration: 185000,
        filePath: '/music/track1.mp3',
        isFavorite: false,
      ),
      const Song(
        id: 2,
        title: 'Mock Track 2',
        artist: 'Artist B',
        album: 'Album Y',
        duration: 240000,
        filePath: '/music/track2.mp3',
        isFavorite: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider
              .overrideWith((ref) => Stream.value(fakeSongs)),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mock Track 1'), findsOneWidget);
    expect(find.text('Mock Track 2'), findsOneWidget);
    expect(find.text('Artist A • Album X'), findsOneWidget);
    expect(find.text('3:05'), findsOneWidget); // 185s = 3m 05s
    expect(find.text('4:00'), findsOneWidget); // 240s = 4m 00s
  });

  testWidgets('LibraryScreen filters tracks in real time by search query and favorites',
      (tester) async {
    final fakeSongs = [
      const Song(
        id: 1,
        title: 'Cyberpunk Beat',
        artist: 'Spidey Producer',
        album: 'Neon City',
        duration: 180000,
        filePath: '/music/cyber.mp3',
        isFavorite: true,
      ),
      const Song(
        id: 2,
        title: 'Acoustic Sunrise',
        artist: 'Morning Artist',
        album: 'Calm Day',
        duration: 210000,
        filePath: '/music/acoustic.mp3',
        isFavorite: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider
              .overrideWith((ref) => Stream.value(fakeSongs)),
          allPlaylistsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial state shows both songs and track counter badge
    expect(find.text('Cyberpunk Beat'), findsOneWidget);
    expect(find.text('Acoustic Sunrise'), findsOneWidget);
    expect(find.text('2 tracks'), findsOneWidget);

    // 1. Search for "Cyber"
    await tester.enterText(find.byType(TextField), 'Cyber');
    await tester.pumpAndSettle();

    expect(find.text('Cyberpunk Beat'), findsOneWidget);
    expect(find.text('Acoustic Sunrise'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    // 2. Clear search
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Cyberpunk Beat'), findsOneWidget);
    expect(find.text('Acoustic Sunrise'), findsOneWidget);

    // 3. Filter by Favorites chip
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Cyberpunk Beat'), findsOneWidget);
    expect(find.text('Acoustic Sunrise'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    // 4. Switch to Playlists tab
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    expect(find.text('Create New Playlist'), findsOneWidget);
    expect(find.text('No Playlists Created Yet'), findsOneWidget);
  });

  testWidgets('Tapping 3-dot song options opens song options bottom sheet',
      (tester) async {
    final fakeSongs = [
      const Song(
        id: 1,
        title: 'Action Theme',
        artist: 'Composer X',
        album: 'Soundtrack 1',
        duration: 180000,
        filePath: '/music/theme.mp3',
        isFavorite: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSongsStreamProvider
              .overrideWith((ref) => Stream.value(fakeSongs)),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find and tap the 3-dot menu on the song tile
    final moreButton = find.byIcon(Icons.more_vert_rounded);
    expect(moreButton, findsOneWidget);

    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    // Verify sheet actions
    expect(find.text('Play Next'), findsOneWidget);
    expect(find.text('Add to Playlist'), findsOneWidget);
    expect(find.text('Add to Favorites'), findsOneWidget);
  });
}
