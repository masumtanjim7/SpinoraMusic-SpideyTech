import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/audio/track.dart';
import 'package:spinora/features/player/application/player_controller.dart';
import 'package:spinora/features/player/presentation/mini_player.dart';

void main() {
  testWidgets('MiniPlayer is hidden when no track is loaded', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MiniPlayer(),
          ),
        ),
      ),
    );

    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('MiniPlayer renders title, artist, and controls when track is loaded',
      (tester) async {
    const activeTrack = Track(
      id: 'local_1',
      title: 'Neon Beat',
      artist: 'Spidey Artist',
      durationMs: 200000,
      source: TrackSource.local,
      uri: 'file:///test/song.mp3',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerControllerProvider.overrideWith(
            () => _FakePlayerController(
              const PlayerState(
                currentTrack: activeTrack,
                isPlaying: true,
                position: Duration(seconds: 50),
                duration: Duration(seconds: 200),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: MiniPlayer(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Neon Beat'), findsOneWidget);
    expect(find.text('Spidey Artist'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });
}

class _FakePlayerController extends PlayerController {
  _FakePlayerController(this._initialState);

  final PlayerState _initialState;

  @override
  PlayerState build() => _initialState;
}
