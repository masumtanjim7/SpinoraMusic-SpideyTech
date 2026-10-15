import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Drift table storing cached song metadata.
class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text().nullable()();
  IntColumn get duration => integer()();
  TextColumn get filePath => text()();
  TextColumn get albumArtPath => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}

/// Drift table storing custom user playlists.
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Join table mapping songs into custom playlists.
class PlaylistSongs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get songId =>
      integer().references(Songs, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Songs, Playlists, PlaylistSongs])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(playlists);
            await m.createTable(playlistSongs);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ---------------------------------------------------------------------------
  // Playlist Queries & Helpers
  // ---------------------------------------------------------------------------

  /// Watches all playlists ordered by creation date descending.
  Stream<List<Playlist>> watchAllPlaylists() {
    return (select(playlists)
          ..orderBy([
            (p) =>
                OrderingTerm(expression: p.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Creates a new custom playlist.
  Future<int> createPlaylist(String name) {
    return into(playlists).insert(PlaylistsCompanion.insert(name: name));
  }

  /// Deletes a playlist and removes all its song associations.
  Future<int> deletePlaylist(int playlistId) async {
    await (delete(playlistSongs)
          ..where((ps) => ps.playlistId.equals(playlistId)))
        .go();
    return (delete(playlists)..where((p) => p.id.equals(playlistId))).go();
  }

  /// Adds a song to a playlist if not already present.
  Future<int> addSongToPlaylist({
    required int playlistId,
    required int songId,
  }) async {
    final existing = await (select(playlistSongs)
          ..where((ps) =>
              ps.playlistId.equals(playlistId) & ps.songId.equals(songId)))
        .getSingleOrNull();
    if (existing != null) {
      return existing.id;
    }
    return into(playlistSongs).insert(
      PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
      ),
    );
  }

  /// Removes a song from a playlist.
  Future<int> removeSongFromPlaylist({
    required int playlistId,
    required int songId,
  }) {
    return (delete(playlistSongs)
          ..where((ps) =>
              ps.playlistId.equals(playlistId) & ps.songId.equals(songId)))
        .go();
  }

  /// Watches all songs in a given playlist, ordered by the time they were added.
  Stream<List<Song>> watchSongsInPlaylist(int playlistId) {
    final query = select(songs).join([
      innerJoin(
        playlistSongs,
        playlistSongs.songId.equalsExp(songs.id),
      ),
    ])
      ..where(playlistSongs.playlistId.equals(playlistId))
      ..orderBy([
        OrderingTerm(expression: playlistSongs.addedAt, mode: OrderingMode.asc),
      ]);

    return query.watch().map(
          (rows) => rows.map((row) => row.readTable(songs)).toList(),
        );
  }

  /// Watches the number of songs in a given playlist.
  Stream<int> watchPlaylistSongCount(int playlistId) {
    final countExp = playlistSongs.id.count();
    final query = selectOnly(playlistSongs)
      ..addColumns([countExp])
      ..where(playlistSongs.playlistId.equals(playlistId));

    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File('${dbFolder.path}/app_database.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

/// Riverpod provider for the singleton [AppDatabase] instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Reactive stream of all user playlists.
final allPlaylistsStreamProvider = StreamProvider<List<Playlist>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllPlaylists();
});

/// Reactive stream of songs in a specific playlist.
final playlistSongsStreamProvider =
    StreamProvider.family<List<Song>, int>((ref, playlistId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchSongsInPlaylist(playlistId);
});

/// Reactive stream of song count in a specific playlist.
final playlistSongCountStreamProvider =
    StreamProvider.family<int, int>((ref, playlistId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchPlaylistSongCount(playlistId);
});
