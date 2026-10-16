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
  String? _lastRecordedTrackId;
  DateTime? _lastRecordedTime;
  DateTime? _lastPersistedTime;

  @override
  PlayerState build() {
    _initAudioSession();
    _listenToPlayerStreams();
    _restoreSavedSession();

    ref.onDispose(() {
      for (final sub in _subscriptions) {
        sub.cancel();
      }
      _player?.dispose();
    });

    return const PlayerState();
  }

  /// Restores the last active track and playback position from local database on startup.
  Future<void> _restoreSavedSession() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final session = await db.getPlaybackSession();
      if (session == null || session.lastSongId == null) return;

      // Ensure user hasn't already started playing a track before restore finishes
      if (state.hasTrack) return;

      final song = await db.getSongById(session.lastSongId!);
      if (song == null) return;

      if (state.hasTrack) return;

      final track = Track.fromSong(song);
      final savedPosition = Duration(milliseconds: session.lastPositionMs);
      final trackDuration = Duration(milliseconds: track.durationMs);
      final safePosition =
          (savedPosition > trackDuration || savedPosition < Duration.zero)
              ? Duration.zero
              : savedPosition;

      final audioSource = _buildAudioSource(track);
      await player.setAudioSource(
        audioSource,
        initialPosition: safePosition,
      );

      state = state.copyWith(
        currentTrack: track,
        queue: [track],
        currentIndex: 0,
        position: safePosition,
        duration: trackDuration,
        isPlaying: false,
      );
    } catch (e, st) {
      debugPrint('[PlayerController] Error restoring saved session: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Error restoring playback session',
        fatal: false,
      );
    }
  }

  /// Records a play count and lastPlayedAt timestamp in Drift for local songs.
  void _recordPlayback(Track track) {
    final now = DateTime.now();
    if (_lastRecordedTrackId == track.id &&
        _lastRecordedTime != null &&
        now.difference(_lastRecordedTime!).inSeconds < 5) {
      return;
    }

    _lastRecordedTrackId = track.id;
    _lastRecordedTime = now;

    if (track.source == TrackSource.local && track.id.startsWith('local_')) {
      final songId = int.tryParse(track.id.replaceFirst('local_', ''));
      if (songId != null) {
        try {
          final db = ref.read(appDatabaseProvider);
          db.recordSongPlay(songId);
        } catch (e, st) {
          debugPrint('[PlayerController] Error recording song play: $e');
          FirebaseCrashlytics.instance.recordError(
            e,
            st,
            reason: 'Failed to record song play in Drift',
            fatal: false,
          );
        }
      }
    }
    _persistCurrentSession(immediate: true);
  }

  /// Persists active playback session state to Drift database.
  void _persistCurrentSession({bool immediate = false}) {
    final currentTrack = state.currentTrack;
    if (currentTrack == null) return;

    final now = DateTime.now();
    if (!immediate &&
        _lastPersistedTime != null &&
        now.difference(_lastPersistedTime!).inSeconds < 3) {
      return;
    }
    _lastPersistedTime = now;

    final songId = (currentTrack.source == TrackSource.local &&
            currentTrack.id.startsWith('local_'))
        ? int.tryParse(currentTrack.id.replaceFirst('local_', ''))
        : null;

    try {
      final db = ref.read(appDatabaseProvider);
      db.savePlaybackSession(
        songId: songId,
        trackId: currentTrack.id,
        positionMs: state.position.inMilliseconds,
      );
    } catch (e) {
      debugPrint('[PlayerController] Failed to persist session: $e');
    }
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

        final wasPlaying = state.isPlaying;

        state = state.copyWith(
          isPlaying: isPlaying,
          isBuffering: isBuffering,
        );

        if (isPlaying && !wasPlaying && state.currentTrack != null) {
          _recordPlayback(state.currentTrack!);
        }

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
        _persistCurrentSession();
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
          final nextTrack = state.queue[index];
          state = state.copyWith(
            currentIndex: index,
            currentTrack: nextTrack,
          );
          if (state.isPlaying) {
            _recordPlayback(nextTrack);
          }
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
      _recordPlayback(track);
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

  /// Plays an entire list of [Song]s as a playlist, starting from [initialIndex].
  Future<void> playPlaylist(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    final tracks = songs.map(Track.fromSong).toList();
    final safeIndex = initialIndex.clamp(0, tracks.length - 1);
    await playTrack(tracks[safeIndex], queue: tracks);
  }

  /// Inserts a [Track] directly after the currently playing song in the queue.
  Future<void> playNext(Track track) async {
    if (state.queue.isEmpty) {
      await playTrack(track);
      return;
    }

    final newQueue = List<Track>.from(state.queue);
    final existingIndex = newQueue.indexWhere((t) => t.id == track.id);
    if (existingIndex == state.currentIndex) {
      return; // Already playing this track
    }

    if (existingIndex != -1) {
      newQueue.removeAt(existingIndex);
    }

    final currentTrack = state.currentTrack;
    final newCurrentIndex = currentTrack != null
        ? newQueue.indexWhere((t) => t.id == currentTrack.id)
        : state.currentIndex;
    final insertIndex = (newCurrentIndex + 1).clamp(0, newQueue.length);
    newQueue.insert(insertIndex, track);

    state = state.copyWith(
      queue: List.unmodifiable(newQueue),
      currentIndex: newCurrentIndex,
    );

    try {
      final sources = newQueue.map(_buildAudioSource).toList();
      await player.setAudioSources(
        sources,
        initialIndex: newCurrentIndex,
        initialPosition: state.position,
      );
    } catch (e, st) {
      debugPrint('[PlayerController] Error updating audio sources on playNext: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'playNext audio sources error',
        fatal: false,
      );
    }
  }

  /// Convenience method to insert a [Song] as the next track in the queue.
  Future<void> playSongNext(Song song) {
    return playNext(Track.fromSong(song));
  }

  /// Directly seeks and jumps to the queued track at [index].
  Future<void> jumpToIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    if (index == state.currentIndex) return;

    final targetTrack = state.queue[index];
    state = state.copyWith(
      currentIndex: index,
      currentTrack: targetTrack,
    );

    try {
      await player.seek(Duration.zero, index: index);
      if (!state.isPlaying) {
        await player.play();
      }
    } catch (e, st) {
      debugPrint('[PlayerController] Error jumping to index $index: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'jumpToIndex error',
        fatal: false,
      );
    }
  }

  /// Removes the track at [index] from the active playback queue.
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= state.queue.length) return;

    final newQueue = List<Track>.from(state.queue);
    newQueue.removeAt(index);

    if (newQueue.isEmpty) {
      await stop();
      return;
    }

    int newCurrentIndex = state.currentIndex;
    Track? newCurrentTrack = state.currentTrack;

    if (index == state.currentIndex) {
      newCurrentIndex = index < newQueue.length ? index : newQueue.length - 1;
      newCurrentTrack = newQueue[newCurrentIndex];
      state = state.copyWith(
        queue: List.unmodifiable(newQueue),
        currentIndex: newCurrentIndex,
        currentTrack: newCurrentTrack,
      );
      try {
        final sources = newQueue.map(_buildAudioSource).toList();
        await player.setAudioSources(sources, initialIndex: newCurrentIndex);
        if (state.isPlaying) {
          await player.play();
        }
      } catch (e, st) {
        debugPrint('[PlayerController] Error removing active track: $e');
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'removeFromQueue active error',
          fatal: false,
        );
      }
    } else {
      if (index < state.currentIndex) {
        newCurrentIndex = state.currentIndex - 1;
      }
      state = state.copyWith(
        queue: List.unmodifiable(newQueue),
        currentIndex: newCurrentIndex,
      );
      try {
        final sources = newQueue.map(_buildAudioSource).toList();
        await player.setAudioSources(
          sources,
          initialIndex: newCurrentIndex,
          initialPosition: state.position,
        );
      } catch (e, st) {
        debugPrint('[PlayerController] Error updating queue sources on remove: $e');
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'removeFromQueue sync error',
          fatal: false,
        );
      }
    }
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

  Future<void> pause() {
    _persistCurrentSession(immediate: true);
    return player.pause();
  }

  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    await player.seek(position);
    _persistCurrentSession(immediate: true);
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
