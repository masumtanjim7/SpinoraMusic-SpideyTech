import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/database/app_database.dart';
import 'permission_service.dart';

// ---------------------------------------------------------------------------
// Audio Scan State
// ---------------------------------------------------------------------------

enum AudioScanStatus { idle, scanning, success, failure }

@immutable
class AudioScanState {
  const AudioScanState({
    this.status = AudioScanStatus.idle,
    this.scannedCount = 0,
    this.errorMessage,
  });

  final AudioScanStatus status;
  final int scannedCount;
  final String? errorMessage;

  bool get isScanning => status == AudioScanStatus.scanning;

  AudioScanState copyWith({
    AudioScanStatus? status,
    int? scannedCount,
    String? errorMessage,
  }) {
    return AudioScanState(
      status: status ?? this.status,
      scannedCount: scannedCount ?? this.scannedCount,
      errorMessage: errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Audio Scanner Service
// ---------------------------------------------------------------------------

/// Service responsible for querying local audio files from device storage
/// (via Android MediaStore or platform channels) and syncing them to [AppDatabase].
class AudioScannerService {
  AudioScannerService({required this.db, MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.spideytech.spinora/media_store');

  final AppDatabase db;
  final MethodChannel _channel;

  /// Queries the Android MediaStore via [MethodChannel].
  ///
  /// Returns a raw list of maps containing song metadata.
  Future<List<Map<String, dynamic>>> queryDeviceAudio() async {
    if (!Platform.isAndroid) {
      debugPrint('[AudioScanner] Not on Android; skipping MediaStore query.');
      return const [];
    }

    try {
      final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'querySongs',
      );
      if (result == null) return const [];

      return result.map((item) {
        return item.map((key, value) => MapEntry(key.toString(), value));
      }).toList();
    } on MissingPluginException catch (_) {
      debugPrint(
        '[AudioScanner] MediaStore method channel not implemented on host.',
      );
      return const [];
    } catch (e, st) {
      debugPrint('[AudioScanner] Error querying MediaStore: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'MediaStore query failed',
        fatal: false,
      );
      rethrow;
    }
  }

  /// Queries audio from device storage, deduplicates against existing records,
  /// and updates/inserts/removes in the Drift database ONLY if songs changed.
  Future<int> scanAndIndexSongs() async {
    final permission = await checkAudioPermission();
    if (!permission.isGranted) {
      throw StateError(
        'Audio/Storage permission is not granted. Cannot scan media.',
      );
    }

    final rawSongs = await queryDeviceAudio();
    if (rawSongs.isEmpty) return 0;

    // Load existing records to prevent duplicate entries for the same file.
    final existingSongs = await db.select(db.songs).get();
    final existingPaths = {for (final s in existingSongs) s.filePath: s};
    final scannedPaths = <String>{};

    final toInsert = <SongsCompanion>[];
    final toUpdate = <SongsCompanion>[];

    for (final raw in rawSongs) {
      final filePath = raw['filePath'] as String? ?? '';
      if (filePath.isEmpty) continue;
      scannedPaths.add(filePath);

      final title = (raw['title'] as String?)?.trim().isNotEmpty == true
          ? (raw['title'] as String).trim()
          : 'Unknown';
      final artist = (raw['artist'] as String?)?.trim().isNotEmpty == true
          ? (raw['artist'] as String).trim()
          : 'Unknown Artist';
      final album = raw['album'] as String?;
      final duration = (raw['duration'] as num?)?.toInt() ?? 0;
      final albumArtPath = raw['albumArtPath'] as String?;

      final existing = existingPaths[filePath];

      if (existing == null) {
        toInsert.add(
          SongsCompanion.insert(
            title: title,
            artist: artist,
            album: Value(album),
            duration: duration,
            filePath: filePath,
            albumArtPath: Value(albumArtPath),
            isCustomEdited: const Value(false),
            isHidden: const Value(false),
          ),
        );
      } else {
        // If song was custom edited by user, preserve user-edited title, artist, album.
        final effectiveTitle = existing.isCustomEdited ? existing.title : title;
        final effectiveArtist = existing.isCustomEdited
            ? existing.artist
            : artist;
        final effectiveAlbum = existing.isCustomEdited ? existing.album : album;

        // Update metadata if it has changed.
        if (existing.title != effectiveTitle ||
            existing.artist != effectiveArtist ||
            existing.album != effectiveAlbum ||
            existing.duration != duration ||
            existing.albumArtPath != albumArtPath) {
          toUpdate.add(
            SongsCompanion(
              id: Value(existing.id),
              title: Value(effectiveTitle),
              artist: Value(effectiveArtist),
              album: Value(effectiveAlbum),
              duration: Value(duration),
              filePath: Value(filePath),
              albumArtPath: Value(albumArtPath),
              isFavorite: Value(existing.isFavorite),
              lyrics: Value(existing.lyrics),
              isCustomEdited: Value(existing.isCustomEdited),
              isHidden: Value(existing.isHidden),
            ),
          );
        }
      }
    }

    // Identify local files that were deleted from device storage
    final removedIds = <int>[];
    for (final existing in existingSongs) {
      final path = existing.filePath;
      final isOnline =
          path.startsWith('yt://') ||
          path.startsWith('http://') ||
          path.startsWith('https://');
      if (!isOnline && !scannedPaths.contains(path)) {
        try {
          if (!File(path).existsSync()) {
            removedIds.add(existing.id);
          }
        } catch (_) {}
      }
    }

    final hasChanges =
        toInsert.isNotEmpty || toUpdate.isNotEmpty || removedIds.isNotEmpty;

    if (!hasChanges) {
      debugPrint(
        '[AudioScanner] Background scan complete: 0 changes (${existingSongs.length} songs).',
      );
      return existingSongs.length;
    }

    await db.batch((batch) {
      for (final insertItem in toInsert) {
        batch.insert(db.songs, insertItem);
      }
      for (final updateItem in toUpdate) {
        batch.replace(db.songs, updateItem);
      }
      if (removedIds.isNotEmpty) {
        batch.deleteWhere(db.songs, (s) => s.id.isIn(removedIds));
      }
    });

    final updatedSongs =
        await (db.select(db.songs)
              ..where((s) => s.isHidden.equals(false))
              ..orderBy([
                (s) =>
                    OrderingTerm(expression: s.title, mode: OrderingMode.asc),
              ]))
            .get();
    LibraryCache.saveSongs(updatedSongs);

    debugPrint(
      '[AudioScanner] Indexed ${toInsert.length} new, ${toUpdate.length} updated, ${removedIds.length} removed. Total visible: ${updatedSongs.length}',
    );
    return updatedSongs.length;
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final audioScannerServiceProvider = Provider<AudioScannerService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AudioScannerService(db: db);
});

class AudioScannerNotifier extends Notifier<AudioScanState> {
  bool _backgroundScanTriggered = false;

  @override
  AudioScanState build() => const AudioScanState();

  /// Runs a silent background microtask scan once per app session so newly added
  /// or deleted songs are synced without blocking startup or showing a spinner.
  void ensureBackgroundScanTriggered() {
    if (_backgroundScanTriggered) return;
    _backgroundScanTriggered = true;

    unawaited(
      Future.microtask(() async {
        try {
          if (!Platform.isAndroid) return;
          final permission = await checkAudioPermission();
          if (!permission.isGranted) return;
          final service = ref.read(audioScannerServiceProvider);
          final count = await service.scanAndIndexSongs();
          if (count > 0 && state.status == AudioScanStatus.idle) {
            state = state.copyWith(scannedCount: count);
          }
        } catch (e) {
          debugPrint('[AudioScanner] Silent background scan skipped: $e');
        }
      }),
    );
  }

  /// Triggers an explicit user-initiated scan of device audio files.
  Future<int> scan() async {
    state = state.copyWith(
      status: AudioScanStatus.scanning,
      errorMessage: null,
    );

    try {
      final service = ref.read(audioScannerServiceProvider);
      final count = await service.scanAndIndexSongs();
      state = state.copyWith(
        status: AudioScanStatus.success,
        scannedCount: count,
      );
      return count;
    } catch (e, st) {
      final errorMsg = e.toString();
      debugPrint('[AudioScanner] Scan failed: $errorMsg');
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Audio scanner scan failure',
        fatal: false,
      );
      state = state.copyWith(
        status: AudioScanStatus.failure,
        errorMessage: errorMsg,
      );
      return 0;
    }
  }
}

final audioScannerStateProvider =
    NotifierProvider<AudioScannerNotifier, AudioScanState>(
      AudioScannerNotifier.new,
    );

/// Reactive stream of all non-hidden songs currently indexed in the local Drift database.
/// Immediately yields cached songs from [LibraryCache] on frame 1 so the UI renders
/// with zero reload delay, then streams live updates from Drift and triggers a silent
/// background device scan microtask.
final localSongsStreamProvider = StreamProvider<List<Song>>((ref) async* {
  final cached = LibraryCache.cachedSongs;
  if (cached.isNotEmpty) {
    yield cached;
  }

  // Kick off silent background MediaStore diff scan in a microtask
  Future.microtask(() {
    try {
      ref
          .read(audioScannerStateProvider.notifier)
          .ensureBackgroundScanTriggered();
    } catch (_) {}
  });

  final db = ref.watch(appDatabaseProvider);
  final stream =
      (db.select(db.songs)
            ..where((s) => s.isHidden.equals(false))
            ..orderBy([
              (s) => OrderingTerm(expression: s.title, mode: OrderingMode.asc),
            ]))
          .watch();

  await for (final songs in stream) {
    LibraryCache.saveSongs(songs);
    yield songs;
  }
});
