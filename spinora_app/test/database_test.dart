import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('can insert and query a song in Songs table', () async {
    final id = await db.into(db.songs).insert(
          SongsCompanion.insert(
            title: 'Test Song',
            artist: 'Spidey Artist',
            duration: 180000,
            filePath: '/storage/emulated/0/Music/test.mp3',
          ),
        );

    final allSongs = await db.select(db.songs).get();
    expect(allSongs.length, 1);
    expect(allSongs.first.id, id);
    expect(allSongs.first.title, 'Test Song');
    expect(allSongs.first.artist, 'Spidey Artist');
    expect(allSongs.first.duration, 180000);
    expect(allSongs.first.isFavorite, false);
  });

  test('can create, watch, add songs, and delete custom playlists', () async {
    // 1. Insert two songs
    final song1Id = await db.into(db.songs).insert(
          SongsCompanion.insert(
            title: 'Song Alpha',
            artist: 'Artist 1',
            duration: 120000,
            filePath: '/music/alpha.mp3',
          ),
        );
    final song2Id = await db.into(db.songs).insert(
          SongsCompanion.insert(
            title: 'Song Beta',
            artist: 'Artist 2',
            duration: 150000,
            filePath: '/music/beta.mp3',
          ),
        );

    // 2. Create playlist
    final playlistId = await db.createPlaylist('Gym Workout');
    expect(playlistId, isPositive);

    final playlists = await db.watchAllPlaylists().first;
    expect(playlists.length, 1);
    expect(playlists.first.name, 'Gym Workout');

    // 3. Add songs to playlist
    await db.addSongToPlaylist(playlistId: playlistId, songId: song1Id);
    await db.addSongToPlaylist(playlistId: playlistId, songId: song2Id);

    // Verify songs in playlist
    final playlistSongs = await db.watchSongsInPlaylist(playlistId).first;
    expect(playlistSongs.length, 2);
    expect(playlistSongs.map((s) => s.title), containsAll(['Song Alpha', 'Song Beta']));

    // Verify song count
    final count = await db.watchPlaylistSongCount(playlistId).first;
    expect(count, 2);

    // 4. Remove one song from playlist
    await db.removeSongFromPlaylist(playlistId: playlistId, songId: song1Id);
    final remainingSongs = await db.watchSongsInPlaylist(playlistId).first;
    expect(remainingSongs.length, 1);
    expect(remainingSongs.first.id, song2Id);

    // Verify song still exists in library
    final allSongs = await db.select(db.songs).get();
    expect(allSongs.length, 2);

    // 5. Delete playlist
    await db.deletePlaylist(playlistId);
    final remainingPlaylists = await db.watchAllPlaylists().first;
    expect(remainingPlaylists, isEmpty);

    // Songs in library are intact
    final songsAfterDelete = await db.select(db.songs).get();
    expect(songsAfterDelete.length, 2);
  });

  test('can update and watch song lyrics in database', () async {
    final songId = await db.into(db.songs).insert(
          SongsCompanion.insert(
            title: 'Lyrics Test Song',
            artist: 'Spidey',
            duration: 120000,
            filePath: '/music/lyrics.mp3',
          ),
        );

    // Initial lyrics is null
    final initialSong = await db.getSongById(songId);
    expect(initialSong?.lyrics, isNull);

    // Update lyrics
    await db.updateSongLyrics(songId, '[00:10.00]First line of lyrics\n[00:20.00]Second line');

    final updatedSong = await db.getSongById(songId);
    expect(updatedSong?.lyrics, '[00:10.00]First line of lyrics\n[00:20.00]Second line');

    // Watch stream emits updated song
    final streamedSong = await db.watchSongById(songId).first;
    expect(streamedSong?.lyrics, contains('First line of lyrics'));

    // Clear lyrics
    await db.updateSongLyrics(songId, null);
    final clearedSong = await db.getSongById(songId);
    expect(clearedSong?.lyrics, isNull);
  });

  test('updateSongMetadata sets isCustomEdited and updates fields', () async {
    final songId = await db.into(db.songs).insert(
          SongsCompanion.insert(
            title: 'Original Title',
            artist: 'Original Artist',
            duration: 180000,
            filePath: '/music/track.mp3',
          ),
        );

    final before = await db.getSongById(songId);
    expect(before?.isCustomEdited, false);

    await db.updateSongMetadata(
      songId: songId,
      title: 'Edited Title',
      artist: 'Edited Artist',
      album: 'Edited Album',
    );

    final after = await db.getSongById(songId);
    expect(after?.title, 'Edited Title');
    expect(after?.artist, 'Edited Artist');
    expect(after?.album, 'Edited Album');
    expect(after?.isCustomEdited, true);
  });

  test('setSongHidden filters out songs from watchAllSongs and playlist views', () async {
    final song1Id = await db.into(db.songs).insert(
          SongsCompanion.insert(
            title: 'Visible Song',
            artist: 'Artist 1',
            duration: 120000,
            filePath: '/music/visible.mp3',
          ),
        );
    final song2Id = await db.into(db.songs).insert(
          SongsCompanion.insert(
            title: 'Ringtone Clip',
            artist: 'Unknown',
            duration: 15000,
            filePath: '/music/clip.mp3',
          ),
        );

    // Both are visible initially
    var all = await db.watchAllSongs().first;
    expect(all.length, 2);

    // Hide song2
    await db.setSongHidden(songId: song2Id, isHidden: true);

    all = await db.watchAllSongs().first;
    expect(all.length, 1);
    expect(all.first.id, song1Id);
    expect(all.first.title, 'Visible Song');

    // Add both to playlist
    final pId = await db.createPlaylist('Favorites');
    await db.addSongToPlaylist(playlistId: pId, songId: song1Id);
    await db.addSongToPlaylist(playlistId: pId, songId: song2Id);

    // Hidden song should be filtered out from watchSongsInPlaylist
    final pSongs = await db.watchSongsInPlaylist(pId).first;
    expect(pSongs.length, 1);
    expect(pSongs.first.id, song1Id);

    // Playlist count should reflect non-hidden songs
    final count = await db.watchPlaylistSongCount(pId).first;
    expect(count, 1);

    // Unhide song2
    await db.setSongHidden(songId: song2Id, isHidden: false);
    all = await db.watchAllSongs().first;
    expect(all.length, 2);
  });
}
