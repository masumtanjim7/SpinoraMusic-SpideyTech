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
}
