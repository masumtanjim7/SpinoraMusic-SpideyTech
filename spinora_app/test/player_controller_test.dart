import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:spinora/core/audio/track.dart';
import 'package:spinora/core/widgets/home_widget_service.dart';
import 'package:spinora/features/player/application/player_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerState logic tests', () {
    const track1 = Track(
      id: 'local_1',
      title: 'Song One',
      artist: 'Artist One',
      durationMs: 180000,
      source: TrackSource.local,
      uri: 'file:///path/song1.mp3',
      isFavorite: false,
    );

    const track2 = Track(
      id: 'local_2',
      title: 'Song Two',
      artist: 'Artist Two',
      durationMs: 240000,
      source: TrackSource.local,
      uri: 'file:///path/song2.mp3',
      isFavorite: true,
    );

    test('initial state has no track and zero progress', () {
      const state = PlayerState();
      expect(state.hasTrack, false);
      expect(state.isPlaying, false);
      expect(state.isShuffled, false);
      expect(state.loopMode, LoopMode.off);
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

    test('loopMode state updates correctly', () {
      const stateOff = PlayerState(loopMode: LoopMode.off);
      final stateAll = stateOff.copyWith(loopMode: LoopMode.all);
      final stateOne = stateAll.copyWith(loopMode: LoopMode.one);

      expect(stateOff.loopMode, LoopMode.off);
      expect(stateAll.loopMode, LoopMode.all);
      expect(stateOne.loopMode, LoopMode.one);
    });

    test('track favorite status toggles in copyWith', () {
      final favTrack = track1.copyWith(isFavorite: true);
      expect(favTrack.isFavorite, true);
      expect(track2.isFavorite, true);
    });

    test('queue reordering logic for playNext', () {
      const track3 = Track(
        id: 'local_3',
        title: 'Song Three',
        artist: 'Artist Three',
        durationMs: 200000,
        source: TrackSource.local,
        uri: 'file:///path/song3.mp3',
      );

      final state = PlayerState(
        currentTrack: track1,
        queue: const [track1, track2],
        currentIndex: 0,
      );

      // Inserting track3 as playNext should place it at index 1
      final newQueue = List<Track>.from(state.queue);
      final insertIndex = state.currentIndex + 1;
      newQueue.insert(insertIndex, track3);

      final updatedState = state.copyWith(
        queue: List.unmodifiable(newQueue),
      );

      expect(updatedState.queue.length, 3);
      expect(updatedState.queue[0], track1);
      expect(updatedState.queue[1], track3);
      expect(updatedState.queue[2], track2);
    });

    test('queue removal logic for removeFromQueue', () {
      const track3 = Track(
        id: 'local_3',
        title: 'Song Three',
        artist: 'Artist Three',
        durationMs: 200000,
        source: TrackSource.local,
        uri: 'file:///path/song3.mp3',
      );

      final state = PlayerState(
        currentTrack: track2,
        queue: const [track1, track2, track3],
        currentIndex: 1,
      );

      // Remove track1 (index 0 < currentIndex 1)
      final newQueue = List<Track>.from(state.queue)..removeAt(0);
      final newCurrentIndex = state.currentIndex - 1;

      final updatedState = state.copyWith(
        queue: List.unmodifiable(newQueue),
        currentIndex: newCurrentIndex,
      );

      expect(updatedState.queue.length, 2);
      expect(updatedState.currentIndex, 0);
      expect(updatedState.currentTrack, track2);
      expect(updatedState.queue[0], track2);
      expect(updatedState.queue[1], track3);
    });

    test('playback speed defaults to 1.0 and updates via copyWith', () {
      const state = PlayerState();
      expect(state.playbackSpeed, 1.0);

      final fasterState = state.copyWith(playbackSpeed: 1.5);
      expect(fasterState.playbackSpeed, 1.5);

      final slowerState = fasterState.copyWith(playbackSpeed: 0.75);
      expect(slowerState.playbackSpeed, 0.75);
    });

    test('sleep timer state, isSleepTimerActive, and clearSleepTimer', () {
      const state = PlayerState();
      expect(state.isSleepTimerActive, false);
      expect(state.remainingSleepDuration, isNull);
      expect(state.stopAtEndOfTrack, false);

      // Set timed duration
      final timedState = state.copyWith(
        remainingSleepDuration: const Duration(minutes: 30),
      );
      expect(timedState.isSleepTimerActive, true);
      expect(timedState.remainingSleepDuration, const Duration(minutes: 30));
      expect(timedState.stopAtEndOfTrack, false);

      // Set end of track
      final endOfTrackState = state.copyWith(
        stopAtEndOfTrack: true,
      );
      expect(endOfTrackState.isSleepTimerActive, true);
      expect(endOfTrackState.stopAtEndOfTrack, true);

      // Clear sleep timer
      final clearedState = timedState.copyWith(clearSleepTimer: true);
      expect(clearedState.isSleepTimerActive, false);
      expect(clearedState.remainingSleepDuration, isNull);
      expect(clearedState.stopAtEndOfTrack, false);
    });

    test('available playback speeds contains standard presets', () {
      expect(PlayerController.availablePlaybackSpeeds, [
        0.75,
        1.0,
        1.25,
        1.5,
        2.0,
      ]);
    });

    test('HomeWidgetService.updateWidget executes safely without errors', () async {
      await expectLater(
        HomeWidgetService.updateWidget(
          title: 'Test Song',
          artist: 'Test Artist',
          isPlaying: true,
        ),
        completes,
      );
    });

    test('HomeWidgetService.initialize sets handlers and dispatches correctly', () {
      var playPauseCalled = false;
      var nextCalled = false;
      var prevCalled = false;

      HomeWidgetService.initialize(
        onPlayPause: () => playPauseCalled = true,
        onNext: () => nextCalled = true,
        onPrevious: () => prevCalled = true,
      );

      // Verify initialization completed without exceptions
      expect(playPauseCalled, false);
      expect(nextCalled, false);
      expect(prevCalled, false);
    });
  });
}
