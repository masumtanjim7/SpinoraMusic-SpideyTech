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
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

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
  });
}

class _FakePlayerController extends PlayerController {
  _FakePlayerController(this._initialState);

  final PlayerState _initialState;

  @override
  PlayerState build() => _initialState;
}
