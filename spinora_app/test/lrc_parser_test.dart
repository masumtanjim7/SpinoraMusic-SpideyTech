import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/database/app_database.dart';
import 'package:spinora/features/player/domain/lrc_parser.dart';

void main() {
  group('LrcParser Tests', () {
    test('parses standard timestamped LRC lines and metadata correctly', () {
      const rawLrc = '''
[ti:Harder, Better, Faster, Stronger]
[ar:Daft Punk]
[al:Discovery]
[by:Spidey]
[offset:200]
[00:14.50]Work it make it do it makes us
[00:18.25]Harder better faster stronger
[00:22.00]More than ever hour after
[00:26]Our work is never over
''';

      final parsed = LrcParser.parse(rawLrc);

      expect(parsed.isSynced, isTrue);
      expect(parsed.title, 'Harder, Better, Faster, Stronger');
      expect(parsed.artist, 'Daft Punk');
      expect(parsed.album, 'Discovery');
      expect(parsed.by, 'Spidey');
      expect(parsed.offsetMs, 200);
      expect(parsed.lines.length, 4);

      // Line 1: [00:14.50] = 14s 500ms
      expect(parsed.lines[0].timestamp, const Duration(seconds: 14, milliseconds: 500));
      expect(parsed.lines[0].text, 'Work it make it do it makes us');
      expect(parsed.lines[0].isSynced, isTrue);

      // Line 2: [00:18.25] = 18s 250ms
      expect(parsed.lines[1].timestamp, const Duration(seconds: 18, milliseconds: 250));
      expect(parsed.lines[1].text, 'Harder better faster stronger');

      // Line 3: [00:22.00] = 22s
      expect(parsed.lines[2].timestamp, const Duration(seconds: 22));

      // Line 4: [00:26] = 26s (no milliseconds)
      expect(parsed.lines[3].timestamp, const Duration(seconds: 26));
      expect(parsed.lines[3].text, 'Our work is never over');
    });

    test('parses multiple timestamps on a single line and sorts chronologically', () {
      const rawLrc = '''
[00:10.00][00:30.00]Around the world, around the world
[00:20.00]Around the world, around the world
''';

      final parsed = LrcParser.parse(rawLrc);

      expect(parsed.isSynced, isTrue);
      expect(parsed.lines.length, 3);
      expect(parsed.lines[0].timestamp, const Duration(seconds: 10));
      expect(parsed.lines[1].timestamp, const Duration(seconds: 20));
      expect(parsed.lines[2].timestamp, const Duration(seconds: 30));
      expect(parsed.lines[0].text, 'Around the world, around the world');
      expect(parsed.lines[2].text, 'Around the world, around the world');
    });

    test('falls back cleanly to plain unsynced lines when no timestamps exist', () {
      const rawLyrics = '''
Just a small town girl
Livin' in a lonely world
She took the midnight train goin' anywhere
''';

      final parsed = LrcParser.parse(rawLyrics);

      expect(parsed.isSynced, isFalse);
      expect(parsed.lines.length, 3);
      expect(parsed.lines[0].text, 'Just a small town girl');
      expect(parsed.lines[0].isSynced, isFalse);
      expect(parsed.lines[1].text, "Livin' in a lonely world");
      expect(parsed.lines[2].text, "She took the midnight train goin' anywhere");
    });

    test('activeIndexForPosition returns correct index as playback advances', () {
      const rawLrc = '''
[00:05.00]Intro line
[00:15.00]First verse
[00:25.00]Chorus line
''';

      final parsed = LrcParser.parse(rawLrc);

      // Before first line: returns -1
      expect(parsed.activeIndexForPosition(const Duration(seconds: 2)), -1);

      // At or right after line 0
      expect(parsed.activeIndexForPosition(const Duration(seconds: 5)), 0);
      expect(parsed.activeIndexForPosition(const Duration(seconds: 10)), 0);

      // At line 1
      expect(parsed.activeIndexForPosition(const Duration(seconds: 15)), 1);
      expect(parsed.activeIndexForPosition(const Duration(seconds: 20)), 1);

      // At line 2 (last line)
      expect(parsed.activeIndexForPosition(const Duration(seconds: 25)), 2);
      expect(parsed.activeIndexForPosition(const Duration(seconds: 40)), 2);
    });

    test('resolveSongLyrics prioritizes database lyrics over file lookup', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db.close());

      // Insert song with pre-existing lyrics in DB
      final songId = await db.into(db.songs).insert(
            SongsCompanion.insert(
              title: 'Synth Track',
              artist: 'Neon Wave',
              duration: 150000,
              filePath: '/music/synth.mp3',
            ),
          );

      await db.updateSongLyrics(songId, '[00:05.00]Database cached lyrics');

      final song = (await db.getSongById(songId))!;
      final lyrics = await resolveSongLyrics(song: song, db: db);

      expect(lyrics, '[00:05.00]Database cached lyrics');
    });

    test('resolveSongLyrics automatically loads and caches .lrc file when DB lyrics is empty', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db.close());

      // Create a temporary .lrc file
      final tempDir = await Directory.systemTemp.createTemp('lrc_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final audioPath = '${tempDir.path}/test_track.mp3';
      final lrcPath = '${tempDir.path}/test_track.lrc';

      final lrcFile = File(lrcPath);
      await lrcFile.writeAsString('[00:10.00]File loaded lyrics line');

      final songId = await db.into(db.songs).insert(
            SongsCompanion.insert(
              title: 'File Track',
              artist: 'Local Artist',
              duration: 180000,
              filePath: audioPath,
            ),
          );

      final song = (await db.getSongById(songId))!;
      expect(song.lyrics, isNull);

      // Resolve lyrics from file
      final lyrics = await resolveSongLyrics(song: song, db: db);
      expect(lyrics, '[00:10.00]File loaded lyrics line');

      // Verify lyrics was automatically cached into database
      final updatedSong = (await db.getSongById(songId))!;
      expect(updatedSong.lyrics, '[00:10.00]File loaded lyrics line');
    });
  });
}
