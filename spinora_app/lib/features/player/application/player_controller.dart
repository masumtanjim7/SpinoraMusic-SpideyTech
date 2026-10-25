import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:drift/drift.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:just_audio_background/just_audio_background.dart';

import '../../../core/audio/track.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/home_widget_service.dart';
import '../../online/data/youtube_audio_service.dart';
import '../../settings/application/audio_settings_provider.dart';
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
    this.shuffledIndices,
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
  final List<int>? shuffledIndices;
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
  bool get isShuffleEnabled => isShuffled;
  bool get isSleepTimerActive =>
      remainingSleepDuration != null || stopAtEndOfTrack;
  bool get isLoading => isBuffering;

  double get progressRatio {
    if (duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  PlayerState copyWith({
    Track? currentTrack,
    List<Track>? queue,
    List<Track>? originalQueue,
    bool clearOriginalQueue = false,
    List<int>? shuffledIndices,
    bool clearShuffledIndices = false,
    int? currentIndex,
    bool? isPlaying,
    bool? isLoading,
    bool? isBuffering,
    bool? isShuffled,
    bool? isShuffleEnabled,
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
      originalQueue: clearOriginalQueue
          ? null
          : (originalQueue ?? this.originalQueue),
      shuffledIndices: clearShuffledIndices
          ? null
          : (shuffledIndices ?? this.shuffledIndices),
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isLoading ?? isBuffering ?? this.isBuffering,
      isShuffled: isShuffleEnabled ?? isShuffled ?? this.isShuffled,
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
  }) : _equalizer = equalizerInstance,
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
        androidAudioEffects: [_equalizer!, _loudnessEnhancer!],
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
  Timer? _fadeInTimer;
  bool _isFadingOut = false;
  bool _isFadingIn = false;
  String? _lastRecordedTrackId;
  DateTime? _lastRecordedTime;
  DateTime? _lastPersistedTime;

  @override
  PlayerState build() {
    _initAudioSession();
    _listenToPlayerStreams();
    _restoreSavedSession();
    _initAudioEffects();

    HomeWidgetService.initialize(
      onPlayPause: togglePlayPause,
      onNext: next,
      onPrevious: previous,
    );

    ref.listen<AudioSettingsState>(audioSettingsProvider, (prev, next) {
      if (!next.crossfadeEnabled && (prev?.crossfadeEnabled ?? false)) {
        _cancelFadeTransitions();
        player.setVolume(1.0);
      }
    });

    ref.onDispose(() {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      _cancelFadeTransitions();
      for (final sub in _subscriptions) {
        sub.cancel();
      }
      _player?.dispose();
    });

    return const PlayerState();
  }

  void _cancelFadeTransitions() {
    _fadeInTimer?.cancel();
    _fadeInTimer = null;
    _isFadingIn = false;
    _isFadingOut = false;
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
      await player.setAudioSource(audioSource, initialPosition: safePosition);

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

    if (track.source == TrackSource.local &&
        track.id.startsWith('local_') &&
        !track.uri.startsWith('yt://')) {
      final songId = int.tryParse(track.id.replaceFirst('local_', ''));
      if (songId != null && songId > 0) {
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
        ref
            .read(lyricsControllerProvider.notifier)
            .triggerAutoFetchForTrack(track);
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

    final songId =
        (currentTrack.source == TrackSource.local &&
            currentTrack.id.startsWith('local_') &&
            !currentTrack.uri.startsWith('yt://'))
        ? int.tryParse(currentTrack.id.replaceFirst('local_', ''))
        : null;

    if (songId != null && songId <= 0) return;

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

        state = state.copyWith(isPlaying: isPlaying, isBuffering: isBuffering);
        _syncWidgetState();

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
          } else if (state.hasNext ||
              (state.loopMode == LoopMode.all && state.queue.isNotEmpty)) {
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
        _persistCurrentSession();
        _handleCrossfadeOnPosition(pos);
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
          state = state.copyWith(currentIndex: index, currentTrack: nextTrack);
          _syncWidgetState();
          if (state.isPlaying) {
            _recordPlayback(nextTrack);
          }
          _triggerFadeInIfNeeded();
        }
      }),
    );
  }

  /// Generates an unbiased Fisher-Yates random permutation of [list].
  static List<T> fisherYatesShuffle<T>(List<T> list, [Random? random]) {
    final result = List<T>.from(list);
    if (result.length <= 1) return result;
    final rng = random ?? Random();
    for (var i = result.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }

  /// Returns the next track in the queue, taking loopMode and shuffle into account.
  Track? getNextTrack() {
    if (state.queue.isEmpty) return null;
    if (state.hasNext) {
      return state.queue[state.currentIndex + 1];
    }
    if (state.loopMode == LoopMode.all) {
      if (state.isShuffled && state.queue.length > 1) {
        final original = state.originalQueue ?? state.queue;
        return original.first;
      }
      return state.queue.first;
    }
    return null;
  }

  /// Returns the previous track in the queue, taking loopMode into account.
  Track? getPreviousTrack() {
    if (state.queue.isEmpty) return null;
    if (state.hasPrevious) {
      return state.queue[state.currentIndex - 1];
    }
    if (state.loopMode == LoopMode.all) {
      return state.queue.last;
    }
    return null;
  }

  void _handleCrossfadeOnPosition(Duration pos) {
    final audioSettings = ref.read(audioSettingsProvider);
    if (!audioSettings.crossfadeEnabled || !state.isPlaying) {
      if (_isFadingOut) {
        _isFadingOut = false;
        player.setVolume(1.0);
      }
      return;
    }

    if (_isFadingIn) {
      return;
    }

    // Ensure there is a valid next track to crossfade into before starting fade-out
    final nextTrack = getNextTrack();
    if (nextTrack == null) {
      if (_isFadingOut) {
        _isFadingOut = false;
        player.setVolume(1.0);
      }
      return;
    }

    final duration = state.duration;
    if (duration == Duration.zero) return;

    final fadeSec = audioSettings.crossfadeDurationSeconds;
    final fadeMs = (fadeSec * 1000).round();

    if (duration.inMilliseconds <= fadeMs * 2) return;

    final remainingMs = duration.inMilliseconds - pos.inMilliseconds;
    if (remainingMs <= fadeMs && remainingMs >= 0) {
      _isFadingOut = true;
      final volume = calculateFadeOutVolume(
        position: pos,
        duration: duration,
        crossfadeDurationSeconds: fadeSec,
      );
      player.setVolume(volume);
    } else if (_isFadingOut && remainingMs > fadeMs) {
      _isFadingOut = false;
      player.setVolume(1.0);
    }
  }

  void _triggerFadeInIfNeeded() {
    final audioSettings = ref.read(audioSettingsProvider);
    if (!audioSettings.crossfadeEnabled) {
      _cancelFadeTransitions();
      player.setVolume(1.0);
      return;
    }

    _cancelFadeTransitions();
    _isFadingIn = true;

    final fadeSec = audioSettings.crossfadeDurationSeconds;
    const stepIntervalMs = 50;
    final totalSteps = (fadeSec * 1000 / stepIntervalMs).round().clamp(5, 160);
    var currentStep = 0;

    player.setVolume(0.0);
    final stopwatch = Stopwatch()..start();

    _fadeInTimer = Timer.periodic(
      const Duration(milliseconds: stepIntervalMs),
      (timer) {
        currentStep++;
        final elapsed = stopwatch.elapsed;
        final volume = calculateFadeInVolume(
          elapsedSinceStart: elapsed,
          crossfadeDurationSeconds: fadeSec,
        );

        player.setVolume(volume);

        if (volume >= 1.0 || currentStep >= totalSteps) {
          timer.cancel();
          _fadeInTimer = null;
          _isFadingIn = false;
          player.setVolume(1.0);
        }
      },
    );
  }

  final Map<String, String> _resolvedStreamUrls = {};
  int _playbackRequestId = 0;

  /// Resolves direct HTTPS stream URL for online tracks (e.g. `yt://<videoId>`).
  Future<String> _resolveTrackStreamUrl(
    Track track, {
    bool forceFallback = false,
  }) async {
    if (!track.uri.startsWith('yt://')) {
      return track.uri;
    }
    if (!forceFallback && _resolvedStreamUrls.containsKey(track.uri)) {
      return _resolvedStreamUrls[track.uri]!;
    }
    final videoId = track.uri.replaceFirst('yt://', '');
    final service = ref.read(youtubeAudioServiceProvider);
    final streamUrl = await service.getAudioStreamUrl(
      videoId,
      title: track.title,
      artist: track.artist,
      fallback: forceFallback,
    );
    _resolvedStreamUrls[track.uri] = streamUrl;
    return streamUrl;
  }

  AudioSource _buildAudioSource(Track track) {
    final uriString = _resolvedStreamUrls[track.uri] ?? track.uri;
    final isOnline =
        track.uri.startsWith('yt://') ||
        uriString.startsWith('http://') ||
        uriString.startsWith('https://');

    final mediaItem = _createMediaItem(track);

    if (isOnline) {
      final parsed = (uriString.startsWith('/') && !uriString.startsWith('//'))
          ? Uri.file(uriString)
          : Uri.parse(uriString);
      return AudioSource.uri(parsed, tag: mediaItem);
    }

    final sourceUri = Uri.parse(uriString);
    return AudioSource.uri(sourceUri, tag: mediaItem);
  }

  /// Builds a fully-specified [MediaItem] with guaranteed title, artist, album,
  /// duration, display properties, and high-resolution artwork fallback for
  /// Android Lock Screen, Bluetooth Car Dashboards (AVRCP/Media3), and AudioService.
  static MediaItem _createMediaItem(Track track) {
    final artUri = _resolveArtUri(track.artworkUri);
    final albumTitle = (track.album != null && track.album!.trim().isNotEmpty)
        ? track.album!.trim()
        : 'Spinora Music';
    final artistName = (track.artist.trim().isNotEmpty)
        ? track.artist.trim()
        : 'Unknown Artist';
    final trackTitle = (track.title.trim().isNotEmpty)
        ? track.title.trim()
        : 'Unknown Track';

    return MediaItem(
      id: track.uri,
      title: trackTitle,
      artist: artistName,
      album: albumTitle,
      duration: Duration(milliseconds: track.durationMs),
      artUri: artUri,
      playable: true,
      displayTitle: trackTitle,
      displaySubtitle: artistName,
      displayDescription: albumTitle,
      extras: {
        'id': track.id,
        'source': track.source.name,
        'isFavorite': track.isFavorite,
      },
    );
  }

  /// Resolves an artwork URI string (remote, content://, local file, or asset).
  /// Falls back to the high-res app icon asset if no artwork is available.
  static Uri _resolveArtUri(String? uriString) {
    if (uriString != null && uriString.trim().isNotEmpty) {
      final trimmed = uriString.trim();
      final parsed = Uri.tryParse(trimmed);
      if (parsed != null &&
          (parsed.hasScheme || trimmed.startsWith('content://'))) {
        return parsed;
      }
      return Uri.file(trimmed);
    }
    // High-resolution fallback for Android Lock Screen, Bluetooth Car AVRCP & Media3
    return Uri.parse('asset:///assets/icon/spinora_icon.png');
  }

  /// Plays a given [Track], optionally initializing a new track [queue].
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    final requestId = ++_playbackRequestId;
    final List<Track> activeQueue;
    final List<Track>? originalQueue;
    final int index;

    final bool isNewQueue = queue != null &&
        queue.isNotEmpty &&
        !listEquals(queue, state.queue) &&
        !listEquals(queue, state.originalQueue);

    if (isNewQueue) {
      if (state.isShuffled && queue.length > 1) {
        originalQueue = List<Track>.unmodifiable(queue);
        final others = List<Track>.from(queue)
          ..removeWhere((t) => t.id == track.id);
        final shuffledOthers = fisherYatesShuffle(others);
        activeQueue = [track, ...shuffledOthers];
        index = 0;
      } else {
        originalQueue = List<Track>.unmodifiable(queue);
        activeQueue = List<Track>.from(queue);
        var foundIndex = activeQueue.indexWhere((t) => t.id == track.id);
        if (foundIndex == -1) {
          foundIndex = activeQueue.length;
          activeQueue.add(track);
        }
        index = foundIndex;
      }
    } else {
      originalQueue = state.originalQueue;
      activeQueue =
          state.queue.isEmpty ? [track] : List<Track>.from(state.queue);
      var foundIndex = activeQueue.indexWhere((t) => t.id == track.id);
      if (foundIndex == -1) {
        foundIndex = activeQueue.length;
        activeQueue.add(track);
      }
      index = foundIndex;
    }

    final isOnline = track.uri.startsWith('yt://');

    // 1) Immediately update UI state to show selected currentTrack and set isBuffering = true
    state = state.copyWith(
      currentTrack: track,
      queue: List.unmodifiable(activeQueue),
      originalQueue: originalQueue,
      currentIndex: index,
      isBuffering: isOnline,
      isPlaying: false,
      clearError: true,
    );
    _syncWidgetState();

    try {
      if (isOnline) {
        // Stop any active playback immediately to release previous ExoPlayer connections
        try {
          await player.stop();
        } catch (_) {}

        final mediaItem = _createMediaItem(track);

        try {
          // 2) Extract videoId and await getAudioStreamUrl (first attempt)
          final streamUrl = await _resolveTrackStreamUrl(track);
          if (requestId != _playbackRequestId) {
            debugPrint(
              '[PlayerController] Discarding outdated playback request #$requestId for ${track.title}',
            );
            return;
          }

          final streamUri =
              (streamUrl.startsWith('/') && !streamUrl.startsWith('//'))
              ? Uri.file(streamUrl)
              : Uri.parse(streamUrl);

          // 3) Load resolved URL without custom headers so ExoPlayer connects directly over HTTP/HTTPS/file
          final audioSource = AudioSource.uri(streamUri, tag: mediaItem);

          await player.setAudioSource(audioSource);
          if (requestId != _playbackRequestId) return;

          await player.play();
          if (requestId != _playbackRequestId) return;
        } catch (initialError, initialStackTrace) {
          if (requestId != _playbackRequestId) return;

          debugPrint(
            '[PlayerController] Initial online stream playback failed ($initialError). Retrying with fallback stream...',
          );
          if (kDebugMode) {
            debugPrint(initialStackTrace.toString());
          }
          // Invalidate cached stream URL
          _resolvedStreamUrls.remove(track.uri);

          // Retry once with fallback stream from YoutubeAudioService
          final fallbackStreamUrl = await _resolveTrackStreamUrl(
            track,
            forceFallback: true,
          );
          if (requestId != _playbackRequestId) return;

          final fallbackUri =
              (fallbackStreamUrl.startsWith('/') &&
                  !fallbackStreamUrl.startsWith('//'))
              ? Uri.file(fallbackStreamUrl)
              : Uri.parse(fallbackStreamUrl);
          final fallbackAudioSource = AudioSource.uri(
            fallbackUri,
            tag: mediaItem,
          );

          await player.setAudioSource(fallbackAudioSource);
          if (requestId != _playbackRequestId) return;

          await player.play();
          if (requestId != _playbackRequestId) return;
          _triggerFadeInIfNeeded();
        }

        _recordPlayback(track);

        // Auto-fetch lyrics online in background
        ref
            .read(lyricsControllerProvider.notifier)
            .triggerAutoFetchForTrack(track);
        return;
      }

      // Local playback branch
      final hasOnlineInQueue = activeQueue.any(
        (t) => t.uri.startsWith('yt://'),
      );
      if (activeQueue.length > 1 && !hasOnlineInQueue) {
        final sources = activeQueue.map(_buildAudioSource).toList();
        await player.setAudioSources(sources, initialIndex: index);
      } else {
        final audioSource = _buildAudioSource(track);
        await player.setAudioSource(audioSource);
      }

      if (requestId != _playbackRequestId) return;

      await player.play();
      _triggerFadeInIfNeeded();
      _recordPlayback(track);

      // Trigger automatic lyrics fetching for track
      ref
          .read(lyricsControllerProvider.notifier)
          .triggerAutoFetchForTrack(track);
    } catch (e, st) {
      if (requestId != _playbackRequestId) return;

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
        isBuffering: false,
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
  Future<void> playPlaylist(
    List<Song> songs, {
    int initialIndex = 0,
    bool shuffle = false,
  }) async {
    if (songs.isEmpty) return;
    final tracks = songs.map(Track.fromSong).toList();
    final safeIndex = initialIndex.clamp(0, tracks.length - 1);

    if (shuffle) {
      final initialTrack = tracks[safeIndex];
      final others = List<Track>.from(tracks)..removeAt(safeIndex);
      final shuffledQueue = [
        initialTrack,
        ...fisherYatesShuffle(others),
      ];
      state = state.copyWith(
        isShuffled: true,
        originalQueue: List.unmodifiable(tracks),
      );
      await playTrack(initialTrack, queue: shuffledQueue);
    } else {
      await playTrack(tracks[safeIndex], queue: tracks);
    }
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

    final newOriginal = state.originalQueue != null
        ? (List<Track>.from(state.originalQueue!)
          ..removeWhere((t) => t.id == track.id)
          ..add(track))
        : null;

    state = state.copyWith(
      queue: List.unmodifiable(newQueue),
      originalQueue:
          newOriginal != null ? List.unmodifiable(newOriginal) : null,
      currentIndex: newCurrentIndex,
    );

    final hasOnline = newQueue.any((t) => t.uri.startsWith('yt://'));
    if (!hasOnline) {
      try {
        final sources = newQueue.map(_buildAudioSource).toList();
        await player.setAudioSources(
          sources,
          initialIndex: newCurrentIndex,
          initialPosition: state.position,
        );
      } catch (e, st) {
        debugPrint(
          '[PlayerController] Error updating audio sources on playNext: $e',
        );
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'playNext audio sources error',
          fatal: false,
        );
      }
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
    final hasOnline = state.queue.any((t) => t.uri.startsWith('yt://'));

    if (!hasOnline && (player.hasPrevious || player.hasNext)) {
      state = state.copyWith(currentIndex: index, currentTrack: targetTrack);
      try {
        await player.seek(Duration.zero, index: index);
        if (!state.isPlaying) {
          await player.play();
        }
        ref
            .read(lyricsControllerProvider.notifier)
            .triggerAutoFetchForTrack(targetTrack);
      } catch (e, st) {
        debugPrint('[PlayerController] Error seeking in queue: $e');
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'jumpToIndex seek error',
          fatal: false,
        );
      }
    } else {
      await playTrack(targetTrack, queue: state.queue);
    }
  }

  /// Removes the track at [index] from the active playback queue.
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= state.queue.length) return;

    final removedTrack = state.queue[index];
    final newQueue = List<Track>.from(state.queue);
    newQueue.removeAt(index);

    final newOriginal = state.originalQueue != null
        ? (List<Track>.from(state.originalQueue!)
          ..removeWhere((t) => t.id == removedTrack.id))
        : null;

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
        originalQueue:
            newOriginal != null ? List.unmodifiable(newOriginal) : null,
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
        originalQueue:
            newOriginal != null ? List.unmodifiable(newOriginal) : null,
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
        debugPrint(
          '[PlayerController] Error updating queue sources on remove: $e',
        );
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
    _cancelFadeTransitions();
    player.setVolume(1.0);
    _persistCurrentSession(immediate: true);
    return player.pause();
  }

  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    _cancelFadeTransitions();
    player.setVolume(1.0);
    await player.seek(position);
    _persistCurrentSession(immediate: true);
  }

  /// Toggles queue shuffle.
  Future<void> toggleShuffle() async {
    final newShuffled = !state.isShuffled;
    if (newShuffled) {
      if (state.queue.isEmpty) {
        state = state.copyWith(isShuffled: true);
        return;
      }

      final original = state.originalQueue ?? List<Track>.from(state.queue);
      final current = state.currentTrack;
      final currentIdx =
          state.currentIndex >= 0 && state.currentIndex < state.queue.length
              ? state.currentIndex
              : 0;
      final activeTrack = current ?? state.queue[currentIdx];

      // Keep active track as current item so audio doesn't interrupt,
      // and Fisher-Yates randomize remaining tracks in the queue.
      final remaining = <Track>[];
      for (int i = 0; i < state.queue.length; i++) {
        if (i != currentIdx) {
          remaining.add(state.queue[i]);
        }
      }

      final shuffledRemaining = fisherYatesShuffle(remaining);
      final shuffledQueue = [activeTrack, ...shuffledRemaining];
      const newIndex = 0;

      final shuffledIndices = shuffledQueue.map((t) {
        final idx = original.indexWhere((o) => o.id == t.id);
        return idx != -1 ? idx : 0;
      }).toList();

      state = state.copyWith(
        isShuffled: true,
        originalQueue: List.unmodifiable(original),
        queue: List.unmodifiable(shuffledQueue),
        currentIndex: newIndex,
        shuffledIndices: shuffledIndices,
      );

      if (shuffledQueue.length > 1) {
        final hasOnline = shuffledQueue.any((t) => t.uri.startsWith('yt://'));
        if (!hasOnline) {
          try {
            final sources = shuffledQueue.map(_buildAudioSource).toList();
            await player.setAudioSources(
              sources,
              initialIndex: newIndex,
              initialPosition: state.position,
            );
          } catch (_) {}
        }
      }
    } else {
      final original = state.originalQueue ?? state.queue;
      final current = state.currentTrack;
      final foundIndex =
          current != null ? original.indexWhere((t) => t.id == current.id) : 0;
      final newIndex = foundIndex != -1 ? foundIndex : 0;

      state = state.copyWith(
        isShuffled: false,
        queue: List.unmodifiable(original),
        currentIndex: newIndex,
        clearShuffledIndices: true,
      );

      if (original.length > 1) {
        final hasOnline = original.any((t) => t.uri.startsWith('yt://'));
        if (!hasOnline) {
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
        return t.copyWith(title: title, artist: artist, album: album);
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
        if (state.isShuffled && state.queue.length > 1) {
          final original = state.originalQueue ?? state.queue;
          final reshuffled = fisherYatesShuffle(original);
          final nextTrack = reshuffled.first;
          await playTrack(nextTrack, queue: reshuffled);
          return;
        }
        await playTrack(state.queue.first, queue: state.queue);
      }
      return;
    }

    final hasOnline = state.queue.any((t) => t.uri.startsWith('yt://'));
    if (!hasOnline &&
        player.hasNext &&
        player.currentIndex == state.currentIndex) {
      await player.seekToNext();
    } else {
      final nextIndex = state.currentIndex + 1;
      final nextTrack = state.queue[nextIndex];
      await playTrack(nextTrack, queue: state.queue);
    }
  }

  /// Alias for skipToNext for explicit media / lock screen compatibility.
  Future<void> skipToNext() => next();

  /// Skips to the previous song, or restarts the track if > 3s played.
  Future<void> previous() async {
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (!state.hasPrevious) {
      if (state.loopMode == LoopMode.all && state.queue.isNotEmpty) {
        final lastTrack = state.queue.last;
        await playTrack(lastTrack, queue: state.queue);
        return;
      }
      await seek(Duration.zero);
      return;
    }

    final hasOnline = state.queue.any((t) => t.uri.startsWith('yt://'));
    if (!hasOnline &&
        player.hasPrevious &&
        player.currentIndex == state.currentIndex) {
      await player.seekToPrevious();
    } else {
      final prevIndex = state.currentIndex - 1;
      final prevTrack = state.queue[prevIndex];
      await playTrack(prevTrack, queue: state.queue);
    }
  }

  /// Alias for skipToPrevious for explicit media / lock screen compatibility.
  Future<void> skipToPrevious() => previous();

  Future<void> stop() async {
    cancelSleepTimer();
    _cancelFadeTransitions();
    player.setVolume(1.0);
    await player.stop();
    state = const PlayerState();
    _syncWidgetState();
  }

  /// Synchronizes current playback state to native Android Home Screen App Widget.
  void _syncWidgetState() {
    HomeWidgetService.updateWidget(
      title: state.currentTrack?.title ?? 'Spinora Music',
      artist: state.currentTrack?.artist ?? 'Ready to play',
      isPlaying: state.isPlaying,
    );
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
    state = state.copyWith(clearSleepTimer: true, stopAtEndOfTrack: true);
  }

  /// Cancels any active sleep timer or end-of-track pause rule.
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    state = state.copyWith(clearSleepTimer: true, stopAtEndOfTrack: false);
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

      _subscriptions.add(
        eq.enabledStream.listen((enabled) {
          if (state.equalizerEnabled != enabled) {
            state = state.copyWith(equalizerEnabled: enabled);
          }
        }),
      );

      _subscriptions.add(
        le.enabledStream.listen((enabled) {
          if (state.loudnessEnhancerEnabled != enabled) {
            state = state.copyWith(loudnessEnhancerEnabled: enabled);
          }
        }),
      );

      _subscriptions.add(
        le.targetGainStream.listen((gain) {
          if ((state.loudnessGain - gain).abs() > 0.01) {
            state = state.copyWith(loudnessGain: gain);
          }
        }),
      );

      final params = await eq.parameters;
      _equalizerParameters = params;

      final eqEnabled = eq.enabled;
      final leEnabled = le.enabled;
      final targetGain = le.targetGain;

      final List<EqualizerBandState> initialBands = [];
      for (final band in params.bands) {
        final gain = band.gain;
        initialBands.add(
          EqualizerBandState(
            index: band.index,
            centerFrequency: band.centerFrequency,
            gain: gain,
            minDecibels: params.minDecibels,
            maxDecibels: params.maxDecibels,
          ),
        );
      }

      state = state.copyWith(
        equalizerEnabled: eqEnabled,
        loudnessEnhancerEnabled: leEnabled,
        loudnessGain: targetGain,
        equalizerBands: initialBands.isNotEmpty
            ? initialBands
            : defaultEqualizerBands,
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
      debugPrint(
        '[PlayerController] Error setting loudness enhancer enabled: $e',
      );
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
    final clampedGain = gain.clamp(
      targetBand.minDecibels,
      targetBand.maxDecibels,
    );
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
      final newGain = presetGains[i].clamp(band.minDecibels, band.maxDecibels);
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
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
