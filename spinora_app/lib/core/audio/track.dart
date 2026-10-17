import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

/// Origin of a playable track in Spinora.
enum TrackSource {
  local,
  audius,
  online,
}

/// The common, immutable track model used by the player and queues.
///
/// Strictly adheres to Rule 2 in `PROJECT_CONTEXT.md`:
/// "Every track, local or online, uses the common Track model
/// (id, title, artist, album, durationMs, artworkUri, source, uri).
/// The player only knows Track."
@immutable
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.durationMs,
    this.artworkUri,
    required this.source,
    required this.uri,
    this.isFavorite = false,
  });

  /// Unique identifier (e.g. `local_123` or online track ID).
  final String id;

  /// Track display title.
  final String title;

  /// Artist name.
  final String artist;

  /// Optional album name.
  final String? album;

  /// Duration in milliseconds.
  final int durationMs;

  /// URI string for artwork (local file path or remote HTTP URL).
  final String? artworkUri;

  /// Source of the track (local or online provider).
  final TrackSource source;

  /// Playable URI string (file path URI or remote audio stream URL).
  final String uri;

  /// Whether this track is marked as favorite by the user.
  final bool isFavorite;

  /// Creates a [Track] from a Drift [Song] record.
  factory Track.fromSong(Song song) {
    final isOnline = song.filePath.startsWith('yt://') ||
        song.filePath.startsWith('http://') ||
        song.filePath.startsWith('https://');

    return Track(
      id: isOnline ? 'online_${song.id}' : 'local_${song.id}',
      title: song.title,
      artist: song.artist,
      album: song.album,
      durationMs: song.duration,
      artworkUri: song.albumArtPath,
      source: isOnline ? TrackSource.online : TrackSource.local,
      uri: isOnline ? song.filePath : Uri.file(song.filePath).toString(),
      isFavorite: song.isFavorite,
    );
  }

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? artworkUri,
    TrackSource? source,
    String? uri,
    bool? isFavorite,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      artworkUri: artworkUri ?? this.artworkUri,
      source: source ?? this.source,
      uri: uri ?? this.uri,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Track &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          uri == other.uri;

  @override
  int get hashCode => id.hashCode ^ uri.hashCode;
}
