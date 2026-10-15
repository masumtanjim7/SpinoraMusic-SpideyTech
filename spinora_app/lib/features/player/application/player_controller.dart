import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:drift/drift.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:just_audio_background/just_audio_background.dart';

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
    this.originalQueue,
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isShuffled = false,
    this.loopMode = LoopMode.off,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  final Track? currentTrack;
  final List<Track> queue;
  final List<Track>? originalQueue;
  final int currentIndex;
  final bool isPlaying;
  final bool isBuffering;
  final bool isShuffled;
  final LoopMode loopMode;
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
    List<Track>? originalQueue,
    int? currentIndex,
    bool? isPlaying,
    bool? isBuffering,
    bool? isShuffled,
    LoopMode? loopMode,
    Duration? position,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      queue: queue ?? this.queue,
      originalQueue: originalQueue ?? this.originalQueue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isShuffled: isShuffled ?? this.isShuffled,
      loopMode: loopMode ?? this.loopMode,
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
          if (state.loopMode == LoopMode.one) {
            seek(Duration.zero);
            play();
          } else if (state.hasNext) {
            next();
          } else if (state.loopMode == LoopMode.all && state.queue.isNotEmpty) {
            playTrack(state.queue.first);
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

    _subscriptions.add(
      player.currentIndexStream.listen((index) {
        if (index != null &&
            index >= 0 &&
            index < state.queue.length &&
            index != state.currentIndex) {
          state = state.copyWith(
            currentIndex: index,
            currentTrack: state.queue[index],
          );
        }
      }),
    );
  }

  AudioSource _buildAudioSource(Track track) {
    final sourceUri = Uri.parse(track.uri);
    return AudioSource.uri(
      sourceUri,
      tag: MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: Duration(milliseconds: track.durationMs),
        artUri: _parseArtUri(track.artworkUri),
      ),
    );
  }

  static Uri? _parseArtUri(String? uriString) {
    if (uriString == null || uriString.isEmpty) return null;
    final parsed = Uri.tryParse(uriString);
    if (parsed != null && (parsed.hasScheme || uriString.startsWith('content://'))) {
      return parsed;
    }
    return Uri.file(uriString);
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
      if (activeQueue.length > 1) {
        final sources = activeQueue.map(_buildAudioSource).toList();
        await player.setAudioSources(sources, initialIndex: index);
      } else {
        final audioSource = _buildAudioSource(track);
        await player.setAudioSource(audioSource);
      }

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

  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    await player.seek(position);
  }

  /// Toggles queue shuffle.
  Future<void> toggleShuffle() async {
    final newShuffled = !state.isShuffled;
    if (newShuffled) {
      final original = List<Track>.from(state.queue);
      final shuffled = List<Track>.from(state.queue)..shuffle();
      final current = state.currentTrack;
      final newIndex = current != null ? shuffled.indexOf(current) : 0;

      state = state.copyWith(
        isShuffled: true,
        originalQueue: original,
        queue: List.unmodifiable(shuffled),
        currentIndex: newIndex,
      );

      if (shuffled.length > 1) {
        try {
          final sources = shuffled.map(_buildAudioSource).toList();
          await player.setAudioSources(
            sources,
            initialIndex: newIndex,
            initialPosition: state.position,
          );
        } catch (_) {}
      }
    } else {
      final original = state.originalQueue ?? state.queue;
      final current = state.currentTrack;
      final newIndex = current != null ? original.indexOf(current) : 0;

      state = state.copyWith(
        isShuffled: false,
        queue: List.unmodifiable(original),
        currentIndex: newIndex,
      );

      if (original.length > 1) {
        try {
          final sources = original.map(_buildAudioSource).toList();
          await player.setAudioSources(
            sources,
            initialIndex: newIndex,
            initialPosition: state.position,
          );
        } catch (_) {}
      }
    }
  }

  /// Cycles repeat mode: off -> all -> one -> off.
  Future<void> cycleLoopMode() async {
    final LoopMode nextMode;
    switch (state.loopMode) {
      case LoopMode.off:
        nextMode = LoopMode.all;
      case LoopMode.all:
        nextMode = LoopMode.one;
      case LoopMode.one:
        nextMode = LoopMode.off;
    }

    try {
      await player.setLoopMode(nextMode);
    } catch (_) {
      // Handled gracefully in completed stream
    }

    state = state.copyWith(loopMode: nextMode);
  }

  /// Toggles the favorite status of the currently loaded track and updates Drift.
  Future<void> toggleFavorite() async {
    final track = state.currentTrack;
    if (track == null) return;

    final newFavorite = !track.isFavorite;
    final updatedTrack = track.copyWith(isFavorite: newFavorite);

    // Persist to Drift database if local song
    if (track.source == TrackSource.local && track.id.startsWith('local_')) {
      final songId = int.tryParse(track.id.replaceFirst('local_', ''));
      if (songId != null) {
        try {
          final db = ref.read(appDatabaseProvider);
          await (db.update(db.songs)..where((s) => s.id.equals(songId))).write(
            SongsCompanion(isFavorite: Value(newFavorite)),
          );
        } catch (e, st) {
          debugPrint('[PlayerController] Error persisting favorite: $e');
          FirebaseCrashlytics.instance.recordError(
            e,
            st,
            reason: 'Failed to update song favorite in Drift',
            fatal: false,
          );
        }
      }
    }

    final updatedQueue = state.queue.map((t) {
      return t.id == track.id ? updatedTrack : t;
    }).toList();

    state = state.copyWith(
      currentTrack: updatedTrack,
      queue: List.unmodifiable(updatedQueue),
    );
  }

  /// Skips to the next song in the active queue.
  Future<void> next() async {
    if (!state.hasNext) {
      if (state.loopMode == LoopMode.all && state.queue.isNotEmpty) {
        await playTrack(state.queue.first);
      }
      return;
    }

    if (player.hasNext) {
      await player.seekToNext();
    } else {
      final nextIndex = state.currentIndex + 1;
      final nextTrack = state.queue[nextIndex];
      await playTrack(nextTrack);
    }
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

    if (player.hasPrevious) {
      await player.seekToPrevious();
    } else {
      final prevIndex = state.currentIndex - 1;
      final prevTrack = state.queue[prevIndex];
      await playTrack(prevTrack);
    }
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
