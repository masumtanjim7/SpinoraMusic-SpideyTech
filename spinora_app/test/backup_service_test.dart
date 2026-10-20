import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spinora/core/database/app_database.dart';
import 'package:spinora/features/settings/application/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late BackupService backupService;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'profile_display_name': 'Peter Parker',
      'profile_vibe_subtitle': 'Web-slinging beats',
      'spinora_theme_mode': 'dark',
      'spinora_crossfade_enabled': true,
      'spinora_crossfade_duration': 4.5,
    });

    tempDir = Directory.systemTemp.createTempSync('spinora_backup_test_');
    db = AppDatabase(NativeDatabase.memory());
    backupService = BackupService(db: db);
  });

  tearDown(() async {
    await db.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('BackupService Export Tests', () {
    test('exports empty database with default settings and profile', () async {
      final result = await backupService.exportData(targetDirectory: tempDir);

      expect(result.fileName, endsWith('.spinora'));
      expect(result.favoritesCount, 0);
      expect(result.playlistsCount, 0);
      expect(result.customMetadataCount, 0);

      final decoded = jsonDecode(result.jsonString) as Map<String, dynamic>;
      expect(decoded['version'], 1);
      expect(decoded['appName'], 'Spinora Music');
      expect(decoded['profile']['displayName'], 'Peter Parker');
      expect(decoded['profile']['vibeSubtitle'], 'Web-slinging beats');
      expect(decoded['settings']['themeMode'], 'dark');
      expect(decoded['settings']['crossfadeEnabled'], true);
      expect(decoded['settings']['crossfadeDurationSeconds'], 4.5);
    });

    test('exports favorites, playlists, and custom metadata accurately', () async {
      // 1. Seed songs
      final s1 = await db.into(db.songs).insert(
            SongsCompanion.insert(
              title: 'Sunflower',
              artist: 'Post Malone',
              duration: 158000,
              filePath: '/storage/music/sunflower.mp3',
              isFavorite: const Value(true),
            ),
          );
      final s2 = await db.into(db.songs).insert(
            SongsCompanion.insert(
              title: 'What\'s Up Danger',
              artist: 'Blackway & Black Caviar',
              duration: 222000,
              filePath: '/storage/music/danger.mp3',
              isFavorite: const Value(false),
              lyrics: const Value('[00:10.00]Can\'t stop me now'),
              isCustomEdited: const Value(true),
            ),
          );

      // 2. Seed playlist
      final playlistId = await db.createPlaylist('Spider-Verse OST');
      await db.addSongToPlaylist(playlistId: playlistId, songId: s1);
      await db.addSongToPlaylist(playlistId: playlistId, songId: s2);

      // 3. Export
      final result = await backupService.exportData(targetDirectory: tempDir);

      expect(result.favoritesCount, 1);
      expect(result.playlistsCount, 1);
      expect(result.customMetadataCount, 1);

      final decoded = jsonDecode(result.jsonString) as Map<String, dynamic>;
      final favorites = decoded['favorites'] as List;
      expect(favorites.length, 1);
      expect(favorites.first['title'], 'Sunflower');

      final playlists = decoded['playlists'] as List;
      expect(playlists.length, 1);
      expect(playlists.first['name'], 'Spider-Verse OST');
      expect((playlists.first['songs'] as List).length, 2);

      final custom = decoded['customMetadata'] as List;
      expect(custom.length, 1);
      expect(custom.first['title'], 'What\'s Up Danger');
      expect(custom.first['lyrics'], '[00:10.00]Can\'t stop me now');
    });
  });

  group('BackupService Import & Restore Tests', () {
    test('restores favorites, playlists, and settings into database', () async {
      // 1. Seed existing library songs that match by path or title/artist
      await db.into(db.songs).insert(
            SongsCompanion.insert(
              title: 'Sunflower',
              artist: 'Post Malone',
              duration: 158000,
              filePath: '/storage/music/sunflower.mp3',
              isFavorite: const Value(false),
            ),
          );
      await db.into(db.songs).insert(
            SongsCompanion.insert(
              title: 'Believer',
              artist: 'Imagine Dragons',
              duration: 204000,
              // Different file path on new phone
              filePath: '/new_device/believer.mp3',
              isFavorite: const Value(false),
            ),
          );

      // 2. Prepare backup JSON from previous device
      final backupPayload = {
        'version': 1,
        'appName': 'Spinora Music',
        'exportedAt': '2026-10-20T22:00:00.000Z',
        'profile': {
          'displayName': 'Miles Morales',
          'vibeSubtitle': 'Brooklyn Vibes',
        },
        'settings': {
          'themeMode': 'light',
          'crossfadeEnabled': true,
          'crossfadeDurationSeconds': 5.0,
        },
        'favorites': [
          {
            'title': 'Sunflower',
            'artist': 'Post Malone',
            'filePath': '/storage/music/sunflower.mp3',
          },
          {
            // Matched by Title + Artist even though path differed
            'title': 'Believer',
            'artist': 'Imagine Dragons',
            'filePath': '/old_device/believer.mp3',
          },
        ],
        'playlists': [
          {
            'name': 'Power Workout',
            'songs': [
              {
                'title': 'Believer',
                'artist': 'Imagine Dragons',
                'filePath': '/old_device/believer.mp3',
              },
            ],
          },
        ],
        'customMetadata': [
          {
            'title': 'Sunflower',
            'artist': 'Post Malone',
            'filePath': '/storage/music/sunflower.mp3',
            'lyrics': '[00:15.00]Sunflower chorus',
          },
        ],
      };

      // 3. Execute restore
      final importResult = await backupService.importData(jsonEncode(backupPayload));

      expect(importResult.isSuccessful, isTrue);
      expect(importResult.restoredFavorites, 2);
      expect(importResult.restoredPlaylists, 1);
      expect(importResult.restoredSongsInPlaylists, 1);
      expect(importResult.restoredMetadata, 1);

      // 4. Verify Drift database state
      final allSongs = await db.getAllSongs();
      final sunflower = allSongs.firstWhere((s) => s.title == 'Sunflower');
      final believer = allSongs.firstWhere((s) => s.title == 'Believer');

      expect(sunflower.isFavorite, isTrue);
      expect(sunflower.lyrics, '[00:15.00]Sunflower chorus');
      expect(believer.isFavorite, isTrue);

      final playlists = await db.getAllPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.name, 'Power Workout');

      final songsInPlaylist = await db.getSongsInPlaylist(playlists.first.id);
      expect(songsInPlaylist.length, 1);
      expect(songsInPlaylist.first.title, 'Believer');

      // 5. Verify SharedPreferences state
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_display_name'), 'Miles Morales');
      expect(prefs.getString('profile_vibe_subtitle'), 'Brooklyn Vibes');
      expect(prefs.getString('spinora_theme_mode'), 'light');
      expect(prefs.getDouble('spinora_crossfade_duration'), 5.0);
    });

    test('throws FormatException on invalid json or missing version', () async {
      expect(
        () => backupService.importData('not a valid json'),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => backupService.importData('{"foo": "bar"}'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
