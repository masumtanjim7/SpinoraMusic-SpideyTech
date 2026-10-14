import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/audio/track.dart';
import '../../../core/database/app_database.dart';

// ---------------------------------------------------------------------------
// Player State Model
// ---------------------------------------------------------------------------

@immutable
class PlayerState {
  const PlayerState({
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  final Track? currentTrack;
  final List<Track> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final String? errorMessage;

  bool get hasTrack => currentTrack != null;
  bool get hasNext => queue.isNotEmpty && currentIndex < queue.length - 1;
  bool get hasPrevious => queue.isNotEmpty && currentIndex > 0;

  double get progressRatio {
    if (duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  PlayerState copyWith({
    Track? currentTrack,
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// Player Controller Notifier
// ---------------------------------------------------------------------------

/// Global controller managing audio playback, audio session focus, and queues.
class PlayerController extends Notifier<PlayerState> {
  PlayerController({this.playerInstance});

  final AudioPlayer? playerInstance;
  AudioPlayer? _player;
  AudioPlayer get player => _player ??= playerInstance ?? AudioPlayer();

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  PlayerState build() {
    _initAudioSession();
    _listenToPlayerStreams();

    ref.onDispose(() {
      for (final sub in _subscriptions) {
        sub.cancel();
      }
      _player?.dispose();
    });

    return const PlayerState();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _subscriptions.add(
        session.becomingNoisyEventStream.listen((_) {
          pause();
        }),
      );
    } catch (e, st) {
      debugPrint('[PlayerController] AudioSession configuration failed: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'AudioSession init failure',
        fatal: false,
      );
    }
  }

  void _listenToPlayerStreams() {
    _subscriptions.add(
      player.playerStateStream.listen((playerState) {
        final isPlaying = playerState.playing;
        final isBuffering =
            playerState.processingState == ProcessingState.buffering ||
                playerState.processingState == ProcessingState.loading;

        state = state.copyWith(
          isPlaying: isPlaying,
          isBuffering: isBuffering,
        );

        if (playerState.processingState == ProcessingState.completed) {
          if (state.hasNext) {
            next();
          } else {
            pause();
            seek(Duration.zero);
          }
        }
      }),
    );

    _subscriptions.add(
      player.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
      }),
    );

    _subscriptions.add(
      player.durationStream.listen((dur) {
        if (dur != null) {
          state = state.copyWith(duration: dur);
        }
      }),
    );
  }

  /// Plays a given [Track], optionally initializing a new track [queue].
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    final activeQueue = queue ?? (state.queue.isEmpty ? [track] : state.queue);
    var index = activeQueue.indexWhere((t) => t.id == track.id);
    if (index == -1) {
      index = activeQueue.length;
      activeQueue.add(track);
    }

    state = state.copyWith(
      currentTrack: track,
      queue: List.unmodifiable(activeQueue),
      currentIndex: index,
      clearError: true,
    );

    try {
      final sourceUri = Uri.parse(track.uri);
      final audioSource = AudioSource.uri(sourceUri);

      await player.setAudioSource(audioSource);
      await player.play();
    } catch (e, st) {
      debugPrint('[PlayerController] Error playing track "${track.title}": $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Error playing track',
        fatal: false,
      );
      state = state.copyWith(
        errorMessage: 'Playback error: ${e.toString()}',
        isPlaying: false,
      );
    }
  }

  /// Convenience method to play a Drift [Song] from the library.
  Future<void> playSong(Song song, {List<Song>? songsQueue}) {
    final track = Track.fromSong(song);
    final queue = songsQueue?.map(Track.fromSong).toList();
    return playTrack(track, queue: queue);
  }

  /// Toggles between play and pause.
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    if (state.currentTrack == null && state.queue.isNotEmpty) {
      await playTrack(state.queue.first);
      return;
    }
    await player.play();
  }

  Future<void> pause() => player.pause();

  Future<void> seek(Duration position) => player.seek(position);

  /// Skips to the next song in the active queue.
  Future<void> next() async {
    if (!state.hasNext) return;
    final nextIndex = state.currentIndex + 1;
    final nextTrack = state.queue[nextIndex];
    await playTrack(nextTrack);
  }

  /// Skips to the previous song, or restarts the track if > 3s played.
  Future<void> previous() async {
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (!state.hasPrevious) {
      await seek(Duration.zero);
      return;
    }

    final prevIndex = state.currentIndex - 1;
    final prevTrack = state.queue[prevIndex];
    await playTrack(prevTrack);
  }

  Future<void> stop() async {
    await player.stop();
    state = const PlayerState();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(
  PlayerController.new,
);
