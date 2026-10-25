import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../profile/application/user_profile_provider.dart';
import 'audio_settings_provider.dart';
import 'theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result Models
// ─────────────────────────────────────────────────────────────────────────────

/// Holds the output metadata of a backup export.
@immutable
class BackupExportResult {
  const BackupExportResult({
    required this.filePath,
    required this.fileName,
    required this.jsonString,
    required this.favoritesCount,
    required this.playlistsCount,
    required this.customMetadataCount,
    required this.exportedAt,
  });

  final String filePath;
  final String fileName;
  final String jsonString;
  final int favoritesCount;
  final int playlistsCount;
  final int customMetadataCount;
  final DateTime exportedAt;

  int get fileSizeBytes => utf8.encode(jsonString).length;
  String get formattedSize {
    final kb = fileSizeBytes / 1024.0;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${(kb / 1024.0).toStringAsFixed(1)} MB';
  }
}

/// Holds the output summary of a restored backup.
@immutable
class BackupImportResult {
  const BackupImportResult({
    required this.restoredFavorites,
    required this.restoredPlaylists,
    required this.restoredSongsInPlaylists,
    required this.restoredMetadata,
    required this.restoredProfile,
    required this.restoredSettings,
    this.warningMessages = const [],
  });

  final int restoredFavorites;
  final int restoredPlaylists;
  final int restoredSongsInPlaylists;
  final int restoredMetadata;
  final bool restoredProfile;
  final bool restoredSettings;
  final List<String> warningMessages;

  bool get isSuccessful =>
      restoredFavorites > 0 ||
      restoredPlaylists > 0 ||
      restoredMetadata > 0 ||
      restoredProfile ||
      restoredSettings;
}

/// Metadata representation of a detected `.spinora` backup file on disk.
@immutable
class BackupFileInfo {
  const BackupFileInfo({
    required this.file,
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.modified,
  });

  final File file;
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final DateTime modified;

  String get formattedSize {
    final kb = fileSizeBytes / 1024.0;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${(kb / 1024.0).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return '${modified.year}-${_twoDigits(modified.month)}-${_twoDigits(modified.day)} ${_twoDigits(modified.hour)}:${_twoDigits(modified.minute)}';
  }
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

// ─────────────────────────────────────────────────────────────────────────────
// Backup & Restore Service
// ─────────────────────────────────────────────────────────────────────────────

class BackupService {
  BackupService({required this.db, this.ref});

  final AppDatabase db;
  final Ref? ref;

  static const _channel = MethodChannel('com.spideytech.spinora/media_store');

  // Keys used in SharedPreferences
  static const _kDisplayName = 'profile_display_name';
  static const _kVibeSubtitle = 'profile_vibe_subtitle';
  static const _kAvatarPath = 'profile_avatar_path';
  static const _kOnboardingDone = 'profile_onboarding_done';
  static const _kThemePrefKey = 'spinora_theme_mode';
  static const _kCrossfadeEnabledKey = 'spinora_crossfade_enabled';
  static const _kCrossfadeDurationKey = 'spinora_crossfade_duration';

  /// Serializes user profile, theme/audio settings, favorites, and custom playlists
  /// into a structured `.spinora` JSON backup file and saves it to local disk.
  Future<BackupExportResult> exportData({Directory? targetDirectory}) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    // 1. User Profile Data
    final profileData = {
      'displayName': prefs.getString(_kDisplayName) ?? 'Music Lover',
      'vibeSubtitle': prefs.getString(_kVibeSubtitle) ?? 'Finding my frequency',
      'avatarPath': prefs.getString(_kAvatarPath),
      'hasCompletedOnboarding': prefs.getBool(_kOnboardingDone) ?? false,
    };

    // 2. Settings (Theme, Crossfade)
    final settingsData = {
      'themeMode': prefs.getString(_kThemePrefKey) ?? 'dark',
      'crossfadeEnabled': prefs.getBool(_kCrossfadeEnabledKey) ?? false,
      'crossfadeDurationSeconds':
          prefs.getDouble(_kCrossfadeDurationKey) ?? 3.0,
    };

    // 3. All Songs & Favorites
    final allSongs = await db.getAllSongs();
    final favoritesList = <Map<String, dynamic>>[];
    final customMetadataList = <Map<String, dynamic>>[];

    for (final song in allSongs) {
      if (song.isFavorite) {
        favoritesList.add({
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'duration': song.duration,
          'filePath': song.filePath,
        });
      }

      if (song.isCustomEdited ||
          (song.lyrics != null && song.lyrics!.isNotEmpty) ||
          song.isHidden) {
        customMetadataList.add({
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'duration': song.duration,
          'filePath': song.filePath,
          'lyrics': song.lyrics,
          'isCustomEdited': song.isCustomEdited,
          'isHidden': song.isHidden,
        });
      }
    }

    // 4. Custom Playlists
    final allPlaylists = await db.getAllPlaylists();
    final playlistsList = <Map<String, dynamic>>[];

    for (final playlist in allPlaylists) {
      final songs = await db.getSongsInPlaylist(playlist.id);
      playlistsList.add({
        'name': playlist.name,
        'createdAt': playlist.createdAt.toIso8601String(),
        'songs': songs
            .map(
              (s) => {
                'title': s.title,
                'artist': s.artist,
                'album': s.album,
                'duration': s.duration,
                'filePath': s.filePath,
              },
            )
            .toList(),
      });
    }

    // 5. Build structured payload
    final payload = {
      'version': 1,
      'appName': 'Spinora Music',
      'exportedAt': now.toIso8601String(),
      'profile': profileData,
      'settings': settingsData,
      'favorites': favoritesList,
      'playlists': playlistsList,
      'customMetadata': customMetadataList,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

    // 6. Write to app documents backup directory
    final Directory backupDir;
    if (targetDirectory != null) {
      backupDir = targetDirectory;
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      backupDir = Directory('${appDocDir.path}/backups');
    }
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final dateStr =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}_${_twoDigits(now.hour)}-${_twoDigits(now.minute)}-${_twoDigits(now.second)}';
    final fileName = 'spinora_backup_$dateStr.spinora';
    final targetFile = File('${backupDir.path}/$fileName');
    await targetFile.writeAsString(jsonString, flush: true);

    // Also write a copy to Download folder if accessible on Android
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        final downloadFile = File('${downloadDir.path}/$fileName');
        await downloadFile.writeAsString(jsonString, flush: true);
      }
    } catch (_) {
      // Ignore storage write permission errors for public folder
    }

    return BackupExportResult(
      filePath: targetFile.path,
      fileName: fileName,
      jsonString: jsonString,
      favoritesCount: favoritesList.length,
      playlistsCount: playlistsList.length,
      customMetadataCount: customMetadataList.length,
      exportedAt: now,
    );
  }

  /// Triggers Android's native share sheet for the exported `.spinora` backup file.
  Future<bool> shareBackupFile(String filePath, {String? title}) async {
    try {
      final result = await _channel.invokeMethod<bool>('shareFile', {
        'filePath': filePath,
        'title': title ?? 'Spinora Music Backup',
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Parses and restores favorites, playlists, profile, and settings from a `.spinora` JSON string.
  Future<BackupImportResult> importData(String jsonString) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid Spinora backup file format: $e');
    }

    final version = data['version'];
    if (version == null || version is! num) {
      throw const FormatException(
        'Incompatible backup file: missing version tag',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final warnings = <String>[];
    var restoredProfile = false;
    var restoredSettings = false;
    var restoredFavorites = 0;
    var restoredPlaylists = 0;
    var restoredSongsInPlaylists = 0;
    var restoredMetadata = 0;

    // 1. Restore Profile
    if (data['profile'] is Map<String, dynamic>) {
      final profile = data['profile'] as Map<String, dynamic>;
      final displayName = profile['displayName'] as String?;
      final vibeSubtitle = profile['vibeSubtitle'] as String?;
      final avatarPath = profile['avatarPath'] as String?;
      final onboardingDone = profile['hasCompletedOnboarding'] as bool?;

      if (displayName != null) {
        await prefs.setString(_kDisplayName, displayName);
      }
      if (vibeSubtitle != null) {
        await prefs.setString(_kVibeSubtitle, vibeSubtitle);
      }
      if (avatarPath != null) {
        await prefs.setString(_kAvatarPath, avatarPath);
      }
      if (onboardingDone != null) {
        await prefs.setBool(_kOnboardingDone, onboardingDone);
      }

      if (ref != null) {
        try {
          await ref!
              .read(userProfileProvider.notifier)
              .updateProfile(
                displayName: displayName,
                vibeSubtitle: vibeSubtitle,
                avatarPath: avatarPath,
              );
        } catch (_) {}
      }
      restoredProfile = true;
    }

    // 2. Restore Settings
    if (data['settings'] is Map<String, dynamic>) {
      final settings = data['settings'] as Map<String, dynamic>;
      final themeModeStr = settings['themeMode'] as String?;
      final crossfadeEnabled = settings['crossfadeEnabled'] as bool?;
      final crossfadeDuration = settings['crossfadeDurationSeconds'] as num?;

      if (themeModeStr != null) {
        await prefs.setString(_kThemePrefKey, themeModeStr);
        if (ref != null) {
          try {
            await ref!
                .read(themeModeProvider.notifier)
                .setTheme(
                  themeModeStr == 'light' ? ThemeMode.light : ThemeMode.dark,
                );
          } catch (_) {}
        }
      }

      if (crossfadeEnabled != null) {
        await prefs.setBool(_kCrossfadeEnabledKey, crossfadeEnabled);
        if (ref != null) {
          try {
            await ref!
                .read(audioSettingsProvider.notifier)
                .setCrossfadeEnabled(crossfadeEnabled);
          } catch (_) {}
        }
      }

      if (crossfadeDuration != null) {
        await prefs.setDouble(
          _kCrossfadeDurationKey,
          crossfadeDuration.toDouble(),
        );
        if (ref != null) {
          try {
            await ref!
                .read(audioSettingsProvider.notifier)
                .setCrossfadeDuration(crossfadeDuration.toDouble());
          } catch (_) {}
        }
      }
      restoredSettings = true;
    }

    // 3. Build index of local library songs for matching
    final allSongs = await db.getAllSongs();
    final byPath = <String, Song>{for (final s in allSongs) s.filePath: s};
    final byTitleArtist = <String, Song>{
      for (final s in allSongs) _normalizeKey(s.title, s.artist): s,
    };

    Song? findMatchingSong(Map<String, dynamic> map) {
      final path = map['filePath'] as String?;
      if (path != null && byPath.containsKey(path)) {
        return byPath[path];
      }
      final title = map['title'] as String?;
      final artist = map['artist'] as String?;
      if (title != null && artist != null) {
        final key = _normalizeKey(title, artist);
        if (byTitleArtist.containsKey(key)) {
          return byTitleArtist[key];
        }
      }
      return null;
    }

    // 4. Restore Favorites
    if (data['favorites'] is List) {
      final favorites = (data['favorites'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();

      for (final fav in favorites) {
        final matched = findMatchingSong(fav);
        if (matched != null) {
          if (!matched.isFavorite) {
            await db.setSongFavorite(matched.id, true);
          }
          restoredFavorites++;
        }
      }
    }

    // 5. Restore Custom Playlists
    if (data['playlists'] is List) {
      final playlists = (data['playlists'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      final existingPlaylists = await db.getAllPlaylists();
      final existingByName = <String, Playlist>{
        for (final p in existingPlaylists) p.name.trim().toLowerCase(): p,
      };

      for (final p in playlists) {
        final name = (p['name'] as String?)?.trim() ?? 'Restored Playlist';
        final normalizedName = name.toLowerCase();

        int playlistId;
        if (existingByName.containsKey(normalizedName)) {
          playlistId = existingByName[normalizedName]!.id;
        } else {
          playlistId = await db.createPlaylist(name);
          // Update local map to avoid creating duplicates in the same import
          final created = Playlist(
            id: playlistId,
            name: name,
            createdAt: DateTime.now(),
          );
          existingByName[normalizedName] = created;
        }
        restoredPlaylists++;

        final songsInPlaylist = p['songs'] as List?;
        if (songsInPlaylist != null) {
          for (final songItem
              in songsInPlaylist.whereType<Map<String, dynamic>>()) {
            final matched = findMatchingSong(songItem);
            if (matched != null) {
              await db.addSongToPlaylist(
                playlistId: playlistId,
                songId: matched.id,
              );
              restoredSongsInPlaylists++;
            }
          }
        }
      }
    }

    // 6. Restore Custom Tags, Lyrics & Hidden State
    if (data['customMetadata'] is List) {
      final metadataList = (data['customMetadata'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();

      for (final item in metadataList) {
        final matched = findMatchingSong(item);
        if (matched != null) {
          final lyrics = item['lyrics'] as String?;
          final isHidden = item['isHidden'] as bool?;
          final isEdited = item['isCustomEdited'] as bool? ?? false;
          final title = item['title'] as String?;
          final artist = item['artist'] as String?;
          final album = item['album'] as String?;

          if (lyrics != null && lyrics.isNotEmpty) {
            await db.updateSongLyrics(matched.id, lyrics);
          }
          if (isHidden != null && isHidden != matched.isHidden) {
            await db.setSongHidden(songId: matched.id, isHidden: isHidden);
          }
          if (isEdited && title != null && artist != null) {
            await db.updateSongMetadata(
              songId: matched.id,
              title: title,
              artist: artist,
              album: album,
            );
          }
          restoredMetadata++;
        }
      }
    }

    return BackupImportResult(
      restoredFavorites: restoredFavorites,
      restoredPlaylists: restoredPlaylists,
      restoredSongsInPlaylists: restoredSongsInPlaylists,
      restoredMetadata: restoredMetadata,
      restoredProfile: restoredProfile,
      restoredSettings: restoredSettings,
      warningMessages: warnings,
    );
  }

  /// Scans known locations (app documents & Download folder) for `.spinora` backup files.
  Future<List<BackupFileInfo>> getAvailableLocalBackups() async {
    final results = <String, BackupFileInfo>{};

    Future<void> scanFolder(Directory dir) async {
      try {
        if (!await dir.exists()) return;
        final entities = await dir.list().toList();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.spinora')) {
            final stat = await entity.stat();
            final name = entity.uri.pathSegments.last;
            results[entity.path] = BackupFileInfo(
              file: entity,
              fileName: name,
              filePath: entity.path,
              fileSizeBytes: stat.size,
              modified: stat.modified,
            );
          }
        }
      } catch (_) {}
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    await scanFolder(Directory('${appDocDir.path}/backups'));
    await scanFolder(Directory('/storage/emulated/0/Download'));

    final list = results.values.toList();
    list.sort((a, b) => b.modified.compareTo(a.modified));
    return list;
  }

  String _normalizeKey(String title, String artist) {
    return '${title.trim().toLowerCase()}:::${artist.trim().toLowerCase()}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Riverpod provider for the singleton [BackupService].
final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BackupService(db: db, ref: ref);
});
