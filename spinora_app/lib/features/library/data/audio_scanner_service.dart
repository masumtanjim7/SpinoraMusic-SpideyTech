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
  /// and updates/inserts into the Drift database.
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

    int newlyInserted = 0;

    await db.batch((batch) {
      for (final raw in rawSongs) {
        final filePath = raw['filePath'] as String? ?? '';
        if (filePath.isEmpty) continue;

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
          batch.insert(
            db.songs,
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
          newlyInserted++;
        } else {
          // If song was custom edited by user, preserve user-edited title, artist, album.
          final effectiveTitle = existing.isCustomEdited
              ? existing.title
              : title;
          final effectiveArtist = existing.isCustomEdited
              ? existing.artist
              : artist;
          final effectiveAlbum = existing.isCustomEdited
              ? existing.album
              : album;

          // Update metadata if it has changed.
          if (existing.title != effectiveTitle ||
              existing.artist != effectiveArtist ||
              existing.album != effectiveAlbum ||
              existing.duration != duration ||
              existing.albumArtPath != albumArtPath) {
            batch.update(
              db.songs,
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
    });

    final totalCount =
        await (db.selectOnly(db.songs)..addColumns([db.songs.id.count()]))
            .map((row) => row.read(db.songs.id.count()) ?? 0)
            .getSingle();

    debugPrint(
      '[AudioScanner] Indexed $newlyInserted new songs. Total in DB: $totalCount',
    );
    return totalCount;
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
  @override
  AudioScanState build() => const AudioScanState();

  /// Triggers a scan of device audio files and indexes them in Drift.
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
final localSongsStreamProvider = StreamProvider<List<Song>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.songs)
        ..where((s) => s.isHidden.equals(false))
        ..orderBy([
          (s) => OrderingTerm(expression: s.title, mode: OrderingMode.asc),
        ]))
      .watch();
});
