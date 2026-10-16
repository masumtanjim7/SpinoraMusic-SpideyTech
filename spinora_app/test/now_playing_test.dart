import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/audio/track.dart';
import 'package:spinora/features/player/application/player_controller.dart';
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
}

class _FakePlayerController extends PlayerController {
  _FakePlayerController(this._initialState);

  final PlayerState _initialState;

  @override
  PlayerState build() => _initialState;
}
