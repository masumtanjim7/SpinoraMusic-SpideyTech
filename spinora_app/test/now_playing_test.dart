import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/audio/track.dart';
import 'package:spinora/core/database/app_database.dart';
import 'package:spinora/features/player/application/player_controller.dart';
import 'package:spinora/features/player/domain/lrc_parser.dart';
import 'package:spinora/features/player/presentation/now_playing_screen.dart';

void main() {
  const testTrack = Track(
    id: 'local_1',
    title: 'Neon Cyberpunk',
    artist: 'Spidey Composer',
    album: 'Spider Beats',
    durationMs: 240000,
    source: TrackSource.local,
    uri: 'file:///storage/song.mp3',
    isFavorite: true,
  );

  testWidgets('NowPlayingScreen displays track metadata and transport controls',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerControllerProvider.overrideWith(
            () => _FakePlayerController(
              const PlayerState(
                currentTrack: testTrack,
                isPlaying: true,
                position: Duration(seconds: 60),
                duration: Duration(seconds: 240),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: NowPlayingScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify header and track metadata
    expect(find.text('NOW PLAYING'), findsOneWidget);
    expect(find.text('Neon Cyberpunk'), findsOneWidget);
    expect(find.text('Spidey Composer • Spider Beats'), findsOneWidget);

    // Verify favorite status icon (active favorite)
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);

    // Verify duration labels: 1:00 current, 4:00 total
    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('4:00'), findsOneWidget);

    // Verify interactive Slider
    expect(find.byType(Slider), findsOneWidget);

    // Verify transport controls
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

    // Verify Queue button is present
    final queueButton = find.byIcon(Icons.queue_music_rounded);
    expect(queueButton, findsOneWidget);

    // Scroll to and tap Queue button to open UpNextQueueSheet
    await tester.ensureVisible(queueButton);
    await tester.tap(queueButton);
    await tester.pumpAndSettle();

    expect(find.text('Up Next Queue'), findsOneWidget);
  });

  testWidgets('Audio tools row opens Sleep Timer, Speed, and Track Info sheets',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerControllerProvider.overrideWith(
            () => _FakePlayerController(
              const PlayerState(
                currentTrack: testTrack,
                isPlaying: true,
                position: Duration(seconds: 30),
                duration: Duration(seconds: 180),
                playbackSpeed: 1.25,
                remainingSleepDuration: Duration(minutes: 14, seconds: 45),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: NowPlayingScreen(),
        ),
      ),
    );

    await tester.pump();

    // 1. Verify glowing sleep timer countdown badge is displayed
    expect(find.text('14:45'), findsOneWidget);
    final timerButton = find.byIcon(Icons.bedtime_rounded);
    expect(timerButton, findsOneWidget);

    await tester.ensureVisible(timerButton);
    await tester.tap(timerButton);
    await tester.pumpAndSettle();

    // Verify Sleep Timer modal sheet is displayed
    expect(find.text('SLEEP TIMER'), findsOneWidget);
    expect(find.text('15 Minutes'), findsOneWidget);
    expect(find.text('30 Minutes'), findsOneWidget);
    expect(find.text('End of Current Track'), findsOneWidget);

    // Dismiss sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 2. Verify playback speed badge
    expect(find.text('1.25x'), findsOneWidget);
    final speedButton = find.byIcon(Icons.speed_rounded);
    expect(speedButton, findsOneWidget);

    await tester.ensureVisible(speedButton);
    await tester.tap(speedButton);
    await tester.pumpAndSettle();

    // Verify Playback Speed modal sheet is displayed
    expect(find.text('PLAYBACK SPEED'), findsOneWidget);
    expect(find.text('Normal speed'), findsOneWidget);
    expect(find.text('Double speed'), findsOneWidget);

    // Dismiss sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 3. Verify Track Info button
    final infoButton = find.byIcon(Icons.info_outline_rounded);
    expect(infoButton, findsOneWidget);

    await tester.ensureVisible(infoButton);
    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    // Verify Track Info modal sheet is displayed
    expect(find.text('TRACK INFORMATION'), findsOneWidget);
    expect(find.text('Neon Cyberpunk'), findsWidgets);
    expect(find.text('Spidey Composer'), findsWidgets);
    expect(find.text('Spider Beats'), findsWidgets);
  });

  testWidgets(
      'Lyrics toggle flips centerpiece to LiveLyricsCard and highlights synced lines',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeController = _FakePlayerController(
      const PlayerState(
        currentTrack: testTrack,
        isPlaying: true,
        position: Duration(seconds: 15),
        duration: Duration(seconds: 180),
      ),
    );

    const testParsedLyrics = ParsedLyrics(
      isSynced: true,
      lines: [
        LyricLine(
            timestamp: Duration(seconds: 5), text: 'First line of lyrics'),
        LyricLine(
            timestamp: Duration(seconds: 15),
            text: 'Active synced second line'),
        LyricLine(
            timestamp: Duration(seconds: 30), text: 'Third line coming up'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerControllerProvider.overrideWith(() => fakeController),
          trackLyricsProvider(testTrack)
              .overrideWith((ref) => Stream.value(testParsedLyrics)),
        ],
        child: const MaterialApp(
          home: NowPlayingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial state shows artwork, lyrics not shown yet
    expect(find.text('LYRICS'), findsNothing);

    // Tap Lyrics button in audio tools row
    final lyricsButton = find.byIcon(Icons.lyrics_rounded);
    expect(lyricsButton, findsOneWidget);
    await tester.ensureVisible(lyricsButton);
    await tester.tap(lyricsButton);
    await tester.pumpAndSettle();

    // Verify LiveLyricsCard is displayed
    expect(find.text('LYRICS'), findsOneWidget);
    expect(find.text('SYNCED'), findsOneWidget);
    expect(find.text('First line of lyrics'), findsOneWidget);
    expect(find.text('Active synced second line'), findsOneWidget);
    expect(find.text('Third line coming up'), findsOneWidget);

    // Tap on the third line to seek
    await tester.tap(find.text('Third line coming up'));
    await tester.pumpAndSettle();

    // Verify seek was triggered with line timestamp
    expect(fakeController.lastSeekPosition, const Duration(seconds: 30));

    // Tap artwork button to flip back to artwork
    await tester.tap(find.byTooltip('Show Artwork'));
    await tester.pumpAndSettle();

    expect(find.text('LYRICS'), findsNothing);
  });

  testWidgets(
      'EditLyricsDialog allows pasting lyrics and saves safely without crash',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final memoryDb = AppDatabase(NativeDatabase.memory());
    addTearDown(() => memoryDb.close());

    final songId = await memoryDb.into(memoryDb.songs).insert(
          SongsCompanion.insert(
            title: 'Neon Cyberpunk',
            artist: 'Spidey Composer',
            duration: 240000,
            filePath: '/music/neon.mp3',
          ),
        );

    final track = Track(
      id: 'local_$songId',
      title: 'Neon Cyberpunk',
      artist: 'Spidey Composer',
      durationMs: 240000,
      source: TrackSource.local,
      uri: 'file:///music/neon.mp3',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(memoryDb),
          playerControllerProvider.overrideWith(
            () => _FakePlayerController(
              PlayerState(
                currentTrack: track,
                isPlaying: true,
                position: const Duration(seconds: 10),
                duration: const Duration(seconds: 240),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: NowPlayingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Lyrics button in audio tools
    final lyricsButton = find.byIcon(Icons.lyrics_rounded);
    await tester.ensureVisible(lyricsButton);
    await tester.tap(lyricsButton);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();

    // Verify empty placeholder
    expect(find.text('No Lyrics Available'), findsOneWidget);
    expect(find.text('Paste Lyrics'), findsOneWidget);

    // Tap Paste Lyrics button
    await tester.tap(find.text('Paste Lyrics'));
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Edit Lyrics'), findsOneWidget);

    // Enter lyrics
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(
      textField,
      '[00:05.00]Pasted intro line\n[00:15.00]Pasted chorus line',
    );
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();

    // Verify dialog dismissed cleanly with NO exception
    expect(tester.takeException(), isNull);
    expect(find.text('Edit Lyrics'), findsNothing);

    // Verify DB received lyrics
    final song = await memoryDb.getSongById(songId);
    expect(song?.lyrics, contains('Pasted intro line'));

    // Verify LiveLyricsCard automatically updated to display the new synced lines!
    expect(find.text('Pasted intro line'), findsOneWidget);
    expect(find.text('Pasted chorus line'), findsOneWidget);

    // Clean up snackbar timer & unmount to flush Drift stream cancellation timer
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}

class _FakePlayerController extends PlayerController {
  _FakePlayerController(this._initialState);

  final PlayerState _initialState;
  Duration? lastSeekPosition;

  @override
  PlayerState build() => _initialState;

  @override
  Future<void> seek(Duration position) async {
    lastSeekPosition = position;
  }
}
