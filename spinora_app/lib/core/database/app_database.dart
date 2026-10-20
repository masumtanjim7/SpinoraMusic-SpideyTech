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
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  TextColumn get lyrics => text().nullable()();
  BoolColumn get isCustomEdited =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
}

/// Drift table storing active playback state to support app reload / resume.
@DataClassName('SavedPlaybackSession')
class PlaybackSessions extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get lastTrackId => text().nullable()();
  IntColumn get lastSongId => integer().nullable()();
  IntColumn get lastPositionMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
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

@DriftDatabase(tables: [Songs, Playlists, PlaylistSongs, PlaybackSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

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
          if (from < 3) {
            await m.addColumn(songs, songs.lastPlayedAt);
            await m.addColumn(songs, songs.playCount);
            await m.createTable(playbackSessions);
          }
          if (from < 4) {
            await m.addColumn(songs, songs.lyrics);
          }
          if (from < 5) {
            await m.addColumn(songs, songs.isCustomEdited);
            await m.addColumn(songs, songs.isHidden);
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
      ..where(playlistSongs.playlistId.equals(playlistId) &
          songs.isHidden.equals(false))
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
    final query = selectOnly(playlistSongs).join([
      innerJoin(
        songs,
        songs.id.equalsExp(playlistSongs.songId),
      ),
    ])
      ..addColumns([countExp])
      ..where(playlistSongs.playlistId.equals(playlistId) &
          songs.isHidden.equals(false));

    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  /// Watches all non-hidden songs ordered by title ascending.
  Stream<List<Song>> watchAllSongs() {
    return (select(songs)
          ..where((s) => s.isHidden.equals(false))
          ..orderBy([
            (s) => OrderingTerm(expression: s.title, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // History & Playback Queries
  // ---------------------------------------------------------------------------

  /// Records a track play by updating [lastPlayedAt] and incrementing [playCount].
  Future<void> recordSongPlay(int songId) async {
    final existing = await (select(songs)..where((s) => s.id.equals(songId)))
        .getSingleOrNull();
    if (existing != null) {
      await (update(songs)..where((s) => s.id.equals(songId))).write(
        SongsCompanion(
          lastPlayedAt: Value(DateTime.now()),
          playCount: Value(existing.playCount + 1),
        ),
      );
    }
  }

  /// Watches recently played songs ordered by [lastPlayedAt] descending (filtering hidden).
  Stream<List<Song>> watchRecentlyPlayedSongs({int limit = 15}) {
    return (select(songs)
          ..where((s) => s.lastPlayedAt.isNotNull() & s.isHidden.equals(false))
          ..orderBy([
            (s) => OrderingTerm(
                  expression: s.lastPlayedAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(limit))
        .watch();
  }

  /// Fetches a single [Song] by its [id].
  Future<Song?> getSongById(int songId) {
    return (select(songs)..where((s) => s.id.equals(songId))).getSingleOrNull();
  }

  /// Watches a single [Song] by its [id] reactively.
  Stream<Song?> watchSongById(int songId) {
    return (select(songs)..where((s) => s.id.equals(songId)))
        .watchSingleOrNull();
  }

  /// Updates stored lyrics for a specific song.
  Future<void> updateSongLyrics(int songId, String? lyrics) async {
    await (update(songs)..where((s) => s.id.equals(songId))).write(
      SongsCompanion(
        lyrics: Value(lyrics),
      ),
    );
  }

  /// Updates song metadata (title, artist, album) and marks it as custom edited.
  Future<void> updateSongMetadata({
    required int songId,
    required String title,
    required String artist,
    required String? album,
  }) async {
    await (update(songs)..where((s) => s.id.equals(songId))).write(
      SongsCompanion(
        title: Value(title),
        artist: Value(artist),
        album: Value(album?.trim().isEmpty == true ? null : album?.trim()),
        isCustomEdited: const Value(true),
      ),
    );
  }

  /// Sets whether a song is hidden from library views (e.g. ringtones/audio clips).
  Future<void> setSongHidden({
    required int songId,
    required bool isHidden,
  }) async {
    await (update(songs)..where((s) => s.id.equals(songId))).write(
      SongsCompanion(
        isHidden: Value(isHidden),
      ),
    );
  }

  /// Fetches the last saved playback session state.
  Future<SavedPlaybackSession?> getPlaybackSession() {
    return (select(playbackSessions)..where((p) => p.id.equals(1)))
        .getSingleOrNull();
  }

  /// Persists active playback session state for resume on next launch.
  Future<void> savePlaybackSession({
    required int? songId,
    required String? trackId,
    required int positionMs,
  }) {
    return into(playbackSessions).insertOnConflictUpdate(
      PlaybackSessionsCompanion(
        id: const Value(1),
        lastSongId: Value(songId),
        lastTrackId: Value(trackId),
        lastPositionMs: Value(positionMs),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Backup & Bulk Retrieval Helpers
  // ---------------------------------------------------------------------------

  /// Fetches all playlists currently stored in the database.
  Future<List<Playlist>> getAllPlaylists() {
    return select(playlists).get();
  }

  /// Fetches all songs currently stored in the database.
  Future<List<Song>> getAllSongs() {
    return select(songs).get();
  }

  /// Fetches all songs in a given playlist by its ID.
  Future<List<Song>> getSongsInPlaylist(int playlistId) {
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

    return query.map((row) => row.readTable(songs)).get();
  }

  /// Sets the favorite status of a song by ID.
  Future<void> setSongFavorite(int songId, bool isFavorite) {
    return (update(songs)..where((s) => s.id.equals(songId))).write(
      SongsCompanion(isFavorite: Value(isFavorite)),
    );
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

/// Reactive stream of recently played songs ordered by last played timestamp descending.
final recentlyPlayedSongsStreamProvider =
    StreamProvider<List<Song>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchRecentlyPlayedSongs();
});

/// Fetches a specific [Song] by its ID.
final songByIdProvider = FutureProvider.family<Song?, int>((ref, songId) {
  final db = ref.watch(appDatabaseProvider);
  return db.getSongById(songId);
});

/// Reactive stream of a single [Song] by its ID.
final songStreamByIdProvider =
    StreamProvider.family<Song?, int>((ref, songId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchSongById(songId);
});
