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
}
