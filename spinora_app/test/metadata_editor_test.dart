import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/audio/track.dart';
import 'package:spinora/core/database/app_database.dart';
import 'package:spinora/features/library/presentation/widgets/edit_song_dialog.dart';
import 'package:spinora/features/library/presentation/widgets/song_options_sheet.dart';
import 'package:spinora/features/player/presentation/widgets/audio_tools_sheets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  const testSong = Song(
    id: 1,
    title: 'Sunflower_(Official_Music_Video)_[320kbps]',
    artist: 'Post Malone & Swae Lee',
    album: 'Spider-Man: Into the Spider-Verse',
    duration: 158000,
    filePath: '/storage/emulated/0/Music/sunflower.mp3',
    isFavorite: false,
    playCount: 0,
    isCustomEdited: false,
    isHidden: false,
  );

  testWidgets('EditSongDialog displays initial values and allows editing',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: EditSongDialog(song: testSong),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dialog header
    expect(find.text('EDIT TRACK TAGS'), findsOneWidget);
    expect(find.text('Auto-Clean Tags from Filename'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    // Initial fields have values
    expect(find.text('Sunflower_(Official_Music_Video)_[320kbps]'),
        findsOneWidget);
    expect(find.text('Post Malone & Swae Lee'), findsOneWidget);
    expect(find.text('Spider-Man: Into the Spider-Verse'), findsOneWidget);

    // Tap Auto-Clean Tags button
    await tester.tap(find.text('Auto-Clean Tags from Filename'));
    await tester.pumpAndSettle();

    // Verify auto-cleaned title
    expect(find.text('Sunflower'), findsOneWidget);
    expect(find.text('Tags cleaned from filename clutter'), findsOneWidget);
  });

  testWidgets('EditSongDialog validates empty title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: EditSongDialog(song: testSong),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Clear the title field
    final titleFinder =
        find.widgetWithText(TextField, 'Sunflower_(Official_Music_Video)_[320kbps]');
    await tester.enterText(titleFinder, '');
    await tester.pumpAndSettle();

    // Try to save
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // Should show validation snackbar
    expect(find.text('Title cannot be empty'), findsOneWidget);
  });

  testWidgets('EditSongDialog saves metadata to Drift and updates PlayerController',
      (tester) async {
    // Insert song into memory DB first
    await db.into(db.songs).insert(
          SongsCompanion.insert(
            title: testSong.title,
            artist: testSong.artist,
            duration: testSong.duration,
            filePath: testSong.filePath,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showEditSongDialog(context: context, song: testSong),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Auto clean tags
    await tester.tap(find.text('Auto-Clean Tags from Filename'));
    await tester.pumpAndSettle();

    // Save changes
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed
    expect(find.text('EDIT TRACK TAGS'), findsNothing);

    // Verify database was updated
    final updated = await db.getSongById(testSong.id);
    expect(updated?.title, 'Sunflower');
    expect(updated?.isCustomEdited, true);
  });

  testWidgets('SongOptionsSheet shows Edit Tags and Hide from Library with Undo',
      (tester) async {
    final songId = await db.into(db.songs).insert(
          SongsCompanion.insert(
            title: 'Sample Track',
            artist: 'Sample Artist',
            duration: 120000,
            filePath: '/music/sample.mp3',
          ),
        );

    final insertedSong = (await db.getSongById(songId))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showSongOptionsSheet(
                    context: context,
                    song: insertedSong,
                  ),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open Sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify options are present
    expect(find.text('Edit Tags'), findsOneWidget);
    expect(find.text('Hide from Library'), findsOneWidget);

    // Tap Hide from Library
    await tester.tap(find.text('Hide from Library'));
    await tester.pumpAndSettle();

    // Verify song was hidden in DB
    var song = await db.getSongById(songId);
    expect(song?.isHidden, true);

    // Verify Undo snackbar is visible
    expect(find.text('Hidden "Sample Track" from library'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();

    // Verify song is unhidden in DB
    song = await db.getSongById(songId);
    expect(song?.isHidden, false);
  });

  testWidgets('TrackInfoSheet displays Edit Tags button for local tracks',
      (tester) async {
    await db.into(db.songs).insert(
          SongsCompanion.insert(
            title: 'Local Test Track',
            artist: 'Local Artist',
            duration: 180000,
            filePath: '/music/test.mp3',
          ),
        );

    const localTrack = Track(
      id: 'local_1',
      title: 'Local Test Track',
      artist: 'Local Artist',
      durationMs: 180000,
      source: TrackSource.local,
      uri: '/music/test.mp3',
      isFavorite: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TrackInfoSheet(track: localTrack),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Header & metadata
    expect(find.text('TRACK INFORMATION'), findsOneWidget);
    expect(find.text('Local Test Track'), findsOneWidget);

    // Edit Tags action button is present for local track
    expect(find.text('Edit Tags'), findsOneWidget);
  });
}
