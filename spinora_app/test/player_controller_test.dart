import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/audio/track.dart';
import 'package:spinora/features/player/application/player_controller.dart';

void main() {
  group('PlayerState logic tests', () {
    const track1 = Track(
      id: 'local_1',
      title: 'Song One',
      artist: 'Artist One',
      durationMs: 180000,
      source: TrackSource.local,
      uri: 'file:///path/song1.mp3',
    );

    const track2 = Track(
      id: 'local_2',
      title: 'Song Two',
      artist: 'Artist Two',
      durationMs: 240000,
      source: TrackSource.local,
      uri: 'file:///path/song2.mp3',
    );

    test('initial state has no track and zero progress', () {
      const state = PlayerState();
      expect(state.hasTrack, false);
      expect(state.isPlaying, false);
      expect(state.progressRatio, 0.0);
    });

    test('progressRatio computes correctly', () {
      const state = PlayerState(
        position: Duration(seconds: 90),
        duration: Duration(seconds: 180),
      );
      expect(state.progressRatio, 0.5);
    });

    test('queue navigation boundaries (hasNext/hasPrevious)', () {
      final stateAtStart = PlayerState(
        currentTrack: track1,
        queue: const [track1, track2],
        currentIndex: 0,
      );
      expect(stateAtStart.hasNext, true);
      expect(stateAtStart.hasPrevious, false);

      final stateAtEnd = PlayerState(
        currentTrack: track2,
        queue: const [track1, track2],
        currentIndex: 1,
      );
      expect(stateAtEnd.hasNext, false);
      expect(stateAtEnd.hasPrevious, true);
    });
  });
}
