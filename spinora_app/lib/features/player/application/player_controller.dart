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
import '../domain/equalizer_state.dart';
import 'lyrics_controller.dart';

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
    this.playbackSpeed = 1.0,
    this.remainingSleepDuration,
    this.stopAtEndOfTrack = false,
    this.equalizerEnabled = false,
    this.loudnessEnhancerEnabled = false,
    this.loudnessGain = 0.0,
    this.equalizerPreset = EqualizerPreset.flat,
    this.equalizerBands = defaultEqualizerBands,
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
  final double playbackSpeed;
  final Duration? remainingSleepDuration;
  final bool stopAtEndOfTrack;
  final bool equalizerEnabled;
  final bool loudnessEnhancerEnabled;
  final double loudnessGain;
  final EqualizerPreset equalizerPreset;
  final List<EqualizerBandState> equalizerBands;

  bool get hasTrack => currentTrack != null;
  bool get hasNext => queue.isNotEmpty && currentIndex < queue.length - 1;
  bool get hasPrevious => queue.isNotEmpty && currentIndex > 0;
  bool get isSleepTimerActive =>
      remainingSleepDuration != null || stopAtEndOfTrack;

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
    double? playbackSpeed,
    Duration? remainingSleepDuration,
    bool clearSleepTimer = false,
    bool? stopAtEndOfTrack,
    bool? equalizerEnabled,
    bool? loudnessEnhancerEnabled,
    double? loudnessGain,
    EqualizerPreset? equalizerPreset,
    List<EqualizerBandState>? equalizerBands,
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
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      remainingSleepDuration: clearSleepTimer
          ? null
          : (remainingSleepDuration ?? this.remainingSleepDuration),
      stopAtEndOfTrack: clearSleepTimer
          ? false
          : (stopAtEndOfTrack ?? this.stopAtEndOfTrack),
      equalizerEnabled: equalizerEnabled ?? this.equalizerEnabled,
      loudnessEnhancerEnabled:
          loudnessEnhancerEnabled ?? this.loudnessEnhancerEnabled,
      loudnessGain: loudnessGain ?? this.loudnessGain,
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      equalizerBands: equalizerBands ?? this.equalizerBands,
    );
  }
}

// ---------------------------------------------------------------------------
// Player Controller Notifier
// ---------------------------------------------------------------------------

/// Global controller managing audio playback, audio session focus, and queues.
class PlayerController extends Notifier<PlayerState> {
  PlayerController({
    this.playerInstance,
    AndroidEqualizer? equalizerInstance,
    AndroidLoudnessEnhancer? loudnessEnhancerInstance,
  })  : _equalizer = equalizerInstance,
        _loudnessEnhancer = loudnessEnhancerInstance;

  final AudioPlayer? playerInstance;
  AudioPlayer? _player;
  AndroidEqualizer? _equalizer;
  AndroidLoudnessEnhancer? _loudnessEnhancer;
  AndroidEqualizerParameters? _equalizerParameters;

  AudioPlayer get player {
    if (_player != null) return _player!;
    if (playerInstance != null) {
      _player = playerInstance;
      return _player!;
    }
    _equalizer ??= AndroidEqualizer();
    _loudnessEnhancer ??= AndroidLoudnessEnhancer();
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [
          _equalizer!,
          _loudnessEnhancer!,
        ],
      ),
    );
    return _player!;
  }

  AndroidEqualizer get equalizer {
    if (_equalizer == null) {
      final _ = player;
    }
    return _equalizer ??= AndroidEqualizer();
  }

  AndroidLoudnessEnhancer get loudnessEnhancer {
    if (_loudnessEnhancer == null) {
      final _ = player;
    }
    return _loudnessEnhancer ??= AndroidLoudnessEnhancer();
  }

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _sleepTimer;
  String? _lastRecordedTrackId;
  DateTime? _lastRecordedTime;
  DateTime? _lastPersistedTime;

  @override
  PlayerState build() {
    _initAudioSession();
    _listenToPlayerStreams();
    _restoreSavedSession();
    _initAudioEffects();

    ref.onDispose(() {
      _sleepTimer?.cancel();
      _sleepTimer = null;
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
      // Auto-fetch lyrics online in background if not already cached
      try {
        ref.read(lyricsControllerProvider.notifier).triggerAutoFetchForTrack(track);
      } catch (e) {
        debugPrint('[PlayerController] Error triggering auto lyrics fetch: $e');
      }
    }
    _persistCurrentSession(immediate: true);
  }

  /// Manually triggers an online lyrics search/refetch for the active track.
  Future<bool> refetchLyrics({String? customQuery}) async {
    final track = state.currentTrack;
    if (track == null) return false;
    if (track.source != TrackSource.local || !track.id.startsWith('local_')) {
      return false;
    }
    final songId = int.tryParse(track.id.replaceFirst('local_', ''));
    if (songId == null) return false;

    final db = ref.read(appDatabaseProvider);
    final song = await db.getSongById(songId);
    if (song == null) return false;

    return ref
        .read(lyricsControllerProvider.notifier)
        .refetchLyrics(song, customQuery: customQuery);
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
          if (state.stopAtEndOfTrack) {
            cancelSleepTimer();
            pause();
            seek(Duration.zero);
            return;
          }

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

  /// Updates metadata for a local track in the active queue and current track state in real-time.
  void updateTrackMetadata({
    required int songId,
    required String title,
    required String artist,
    required String? album,
  }) {
    final trackId = 'local_$songId';
    final updatedQueue = state.queue.map((t) {
      if (t.id == trackId) {
        return t.copyWith(
          title: title,
          artist: artist,
          album: album,
        );
      }
      return t;
    }).toList();

    Track? updatedCurrentTrack = state.currentTrack;
    if (state.currentTrack?.id == trackId) {
      updatedCurrentTrack = state.currentTrack!.copyWith(
        title: title,
        artist: artist,
        album: album,
      );
    }

    state = state.copyWith(
      currentTrack: updatedCurrentTrack,
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
    cancelSleepTimer();
    await player.stop();
    state = const PlayerState();
  }

  // ---------------------------------------------------------------------------
  // Sleep Timer Management
  // ---------------------------------------------------------------------------

  /// Sets a countdown sleep timer. When expired, playback pauses cleanly.
  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;

    if (duration <= Duration.zero) {
      cancelSleepTimer();
      return;
    }

    state = state.copyWith(
      remainingSleepDuration: duration,
      stopAtEndOfTrack: false,
    );

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.remainingSleepDuration;
      if (current == null) {
        timer.cancel();
        _sleepTimer = null;
        return;
      }

      final nextRemaining = current - const Duration(seconds: 1);
      if (nextRemaining <= Duration.zero) {
        timer.cancel();
        _sleepTimer = null;
        state = state.copyWith(clearSleepTimer: true);
        pause();
      } else {
        state = state.copyWith(remainingSleepDuration: nextRemaining);
      }
    });
  }

  /// Sets the sleep timer to pause playback at the conclusion of the current track.
  void setSleepTimerEndOfTrack() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    state = state.copyWith(
      clearSleepTimer: true,
      stopAtEndOfTrack: true,
    );
  }

  /// Cancels any active sleep timer or end-of-track pause rule.
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    state = state.copyWith(
      clearSleepTimer: true,
      stopAtEndOfTrack: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Playback Speed Management
  // ---------------------------------------------------------------------------

  static const List<double> availablePlaybackSpeeds = [
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
  ];

  /// Updates audio playback speed on [player] and updates state.
  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await player.setSpeed(speed);
      state = state.copyWith(playbackSpeed: speed);
    } catch (e, st) {
      debugPrint('[PlayerController] Error setting playback speed: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Failed to set playback speed on player',
        fatal: false,
      );
    }
  }

  /// Cycles through available playback speed presets (0.75x -> 1.0x -> 1.25x -> 1.5x -> 2.0x).
  Future<void> cyclePlaybackSpeed() async {
    final currentSpeed = state.playbackSpeed;
    final currentIndex = availablePlaybackSpeeds.indexWhere(
      (s) => (s - currentSpeed).abs() < 0.01,
    );
    final nextIndex = currentIndex == -1
        ? 1 // default to 1.0
        : (currentIndex + 1) % availablePlaybackSpeeds.length;
    await setPlaybackSpeed(availablePlaybackSpeeds[nextIndex]);
  }

  // ---------------------------------------------------------------------------
  // Hardware Audio Equalizer & Loudness/Bass Enhancer Management
  // ---------------------------------------------------------------------------

  /// Initializes hardware audio equalizer & loudness enhancer streams and parameters.
  Future<void> _initAudioEffects() async {
    try {
      final eq = equalizer;
      final le = loudnessEnhancer;

      _subscriptions.add(eq.enabledStream.listen((enabled) {
        if (state.equalizerEnabled != enabled) {
          state = state.copyWith(equalizerEnabled: enabled);
        }
      }));

      _subscriptions.add(le.enabledStream.listen((enabled) {
        if (state.loudnessEnhancerEnabled != enabled) {
          state = state.copyWith(loudnessEnhancerEnabled: enabled);
        }
      }));

      _subscriptions.add(le.targetGainStream.listen((gain) {
        if ((state.loudnessGain - gain).abs() > 0.01) {
          state = state.copyWith(loudnessGain: gain);
        }
      }));

      final params = await eq.parameters;
      _equalizerParameters = params;

      final eqEnabled = eq.enabled;
      final leEnabled = le.enabled;
      final targetGain = le.targetGain;

      final List<EqualizerBandState> initialBands = [];
      for (final band in params.bands) {
        final gain = band.gain;
        initialBands.add(EqualizerBandState(
          index: band.index,
          centerFrequency: band.centerFrequency,
          gain: gain,
          minDecibels: params.minDecibels,
          maxDecibels: params.maxDecibels,
        ));
      }

      state = state.copyWith(
        equalizerEnabled: eqEnabled,
        loudnessEnhancerEnabled: leEnabled,
        loudnessGain: targetGain,
        equalizerBands:
            initialBands.isNotEmpty ? initialBands : defaultEqualizerBands,
      );
    } catch (e) {
      debugPrint('[PlayerController] Audio effects init fallback: $e');
    }
  }

  /// Toggles or updates hardware equalizer enabled state.
  Future<void> setEqualizerEnabled(bool enabled) async {
    state = state.copyWith(equalizerEnabled: enabled);
    try {
      await equalizer.setEnabled(enabled);
    } catch (e, st) {
      debugPrint('[PlayerController] Error setting equalizer enabled: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Failed to set equalizer enabled',
        fatal: false,
      );
    }
  }

  /// Toggles hardware equalizer on or off.
  Future<void> toggleEqualizer() async {
    await setEqualizerEnabled(!state.equalizerEnabled);
  }

  /// Toggles or updates hardware loudness enhancer enabled state.
  Future<void> setLoudnessEnhancerEnabled(bool enabled) async {
    state = state.copyWith(loudnessEnhancerEnabled: enabled);
    try {
      await loudnessEnhancer.setEnabled(enabled);
    } catch (e, st) {
      debugPrint('[PlayerController] Error setting loudness enhancer enabled: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Failed to set loudness enhancer enabled',
        fatal: false,
      );
    }
  }

  /// Toggles hardware loudness enhancer on or off.
  Future<void> toggleLoudnessEnhancer() async {
    await setLoudnessEnhancerEnabled(!state.loudnessEnhancerEnabled);
  }

  /// Sets target gain (0.0 to 10.0 dB) on AndroidLoudnessEnhancer for Bass / Loudness Boost.
  Future<void> setLoudnessGain(double gain) async {
    final clampedGain = gain.clamp(0.0, 10.0);
    final shouldEnable = clampedGain > 0.0;
    state = state.copyWith(
      loudnessGain: clampedGain,
      loudnessEnhancerEnabled: shouldEnable,
    );
    try {
      await loudnessEnhancer.setEnabled(shouldEnable);
      await loudnessEnhancer.setTargetGain(clampedGain);
    } catch (e, st) {
      debugPrint('[PlayerController] Error setting loudness gain: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Failed to set loudness gain',
        fatal: false,
      );
    }
  }

  /// Updates gain for an individual equalizer band in real-time and switches preset to Custom.
  Future<void> setBandGain(int bandIndex, double gain) async {
    final currentBands = List<EqualizerBandState>.from(state.equalizerBands);
    if (bandIndex < 0 || bandIndex >= currentBands.length) return;

    final targetBand = currentBands[bandIndex];
    final clampedGain =
        gain.clamp(targetBand.minDecibels, targetBand.maxDecibels);
    currentBands[bandIndex] = targetBand.copyWith(gain: clampedGain);

    state = state.copyWith(
      equalizerBands: currentBands,
      equalizerPreset: EqualizerPreset.custom,
    );

    try {
      final params = _equalizerParameters ?? await equalizer.parameters;
      _equalizerParameters = params;
      if (bandIndex < params.bands.length) {
        await params.bands[bandIndex].setGain(clampedGain);
      }
    } catch (e, st) {
      debugPrint('[PlayerController] Error setting band gain: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Failed to set equalizer band gain',
        fatal: false,
      );
    }
  }

  /// Applies a built-in equalizer preset curve (Flat, Bass Boost, Pop, Rock, Vocal, Custom).
  Future<void> applyPreset(EqualizerPreset preset) async {
    final currentBands = state.equalizerBands;
    final presetGains = calculatePresetGainsForBands(preset, currentBands);

    final updatedBands = <EqualizerBandState>[];
    for (int i = 0; i < currentBands.length; i++) {
      final band = currentBands[i];
      final newGain =
          presetGains[i].clamp(band.minDecibels, band.maxDecibels);
      updatedBands.add(band.copyWith(gain: newGain));
    }

    state = state.copyWith(
      equalizerPreset: preset,
      equalizerBands: updatedBands,
    );

    try {
      final params = _equalizerParameters ?? await equalizer.parameters;
      _equalizerParameters = params;
      for (int i = 0; i < params.bands.length && i < updatedBands.length; i++) {
        await params.bands[i].setGain(updatedBands[i].gain);
      }
    } catch (e, st) {
      debugPrint('[PlayerController] Error applying equalizer preset: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Failed to apply equalizer preset',
        fatal: false,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(
  PlayerController.new,
);
