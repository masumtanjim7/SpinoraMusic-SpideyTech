import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme.dart';
import '../../../../core/audio/track.dart';
import '../../../../core/database/app_database.dart';

/// Reusable artwork widget for Spinora Music tracks.
///
/// Loads real embedded ID3 cover art or system MediaStore thumbnails
/// via platform channels, cached local image files, or network URLs.
/// Displays a sleek dark glassmorphic fallback with a glowing neon music note
/// when no cover art is available.
class SongArtwork extends StatefulWidget {
  const SongArtwork({
    super.key,
    this.songId,
    this.artworkUri,
    this.filePath,
    this.width,
    this.height,
    this.size,
    this.borderRadius,
    this.isCurrent = false,
    this.iconSize,
    this.heroTag,
    this.fit = BoxFit.cover,
  });

  /// Creates a [SongArtwork] from a common [Track] model.
  factory SongArtwork.fromTrack(
    Track track, {
    Key? key,
    double? size,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    bool isCurrent = false,
    double? iconSize,
    String? heroTag,
    BoxFit fit = BoxFit.cover,
  }) {
    int? parsedId;
    if (track.source == TrackSource.local && track.id.startsWith('local_')) {
      parsedId = int.tryParse(track.id.replaceFirst('local_', ''));
    }

    String? localFilePath;
    if (track.uri.startsWith('file://')) {
      try {
        localFilePath = Uri.parse(track.uri).toFilePath();
      } catch (_) {
        localFilePath = track.uri.replaceFirst('file://', '');
      }
    } else if (track.uri.startsWith('/') || track.uri.contains(':\\')) {
      localFilePath = track.uri;
    }

    return SongArtwork(
      key: key,
      songId: parsedId,
      artworkUri: track.artworkUri,
      filePath: localFilePath,
      size: size,
      width: width,
      height: height,
      borderRadius: borderRadius,
      isCurrent: isCurrent,
      iconSize: iconSize,
      heroTag: heroTag,
      fit: fit,
    );
  }

  /// Creates a [SongArtwork] from a Drift [Song] record.
  factory SongArtwork.fromSong(
    Song song, {
    Key? key,
    double? size,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    bool isCurrent = false,
    double? iconSize,
    String? heroTag,
    BoxFit fit = BoxFit.cover,
  }) {
    return SongArtwork(
      key: key,
      songId: song.id,
      artworkUri: song.albumArtPath,
      filePath: song.filePath,
      size: size,
      width: width,
      height: height,
      borderRadius: borderRadius,
      isCurrent: isCurrent,
      iconSize: iconSize,
      heroTag: heroTag,
      fit: fit,
    );
  }

  /// Media ID of the audio track in device MediaStore.
  final int? songId;

  /// Artwork URI string (content://, file://, http://, https://, or raw path).
  final String? artworkUri;

  /// Underlying audio file path (for extracting embedded ID3 artwork).
  final String? filePath;

  /// Explicit width. Defaults to [size] or 48.
  final double? width;

  /// Explicit height. Defaults to [size] or 48.
  final double? height;

  /// Square dimensions if [width] and [height] are omitted.
  final double? size;

  /// Border radius for clipping and decoration. Defaults to 12.
  final BorderRadius? borderRadius;

  /// Whether this track is the currently playing track.
  final bool isCurrent;

  /// Size of the fallback music note icon.
  final double? iconSize;

  /// Optional Hero tag for transition animations.
  final String? heroTag;

  /// Image fit. Defaults to [BoxFit.cover].
  final BoxFit fit;

  // ── Global In-Memory Artwork Cache ──────────────────────────────────────────
  static final Map<String, Uint8List?> _artworkBytesCache = {};
  static final Map<String, Future<Uint8List?>> _activeRequests = {};
  static const MethodChannel _channel = MethodChannel(
    'com.spideytech.spinora/media_store',
  );

  @override
  State<SongArtwork> createState() => _SongArtworkState();
}

class _SongArtworkState extends State<SongArtwork> {
  Uint8List? _bytes;

  String? get _cacheKey {
    if (widget.songId != null) return 'id_${widget.songId}';
    if (widget.filePath != null && widget.filePath!.isNotEmpty) {
      return 'path_${widget.filePath}';
    }
    if (widget.artworkUri != null && widget.artworkUri!.isNotEmpty) {
      return 'uri_${widget.artworkUri}';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _checkAndLoadArtwork();
  }

  @override
  void didUpdateWidget(covariant SongArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId ||
        oldWidget.filePath != widget.filePath ||
        oldWidget.artworkUri != widget.artworkUri) {
      _checkAndLoadArtwork();
    }
  }

  void _checkAndLoadArtwork() {
    final key = _cacheKey;
    if (key == null) return;

    if (SongArtwork._artworkBytesCache.containsKey(key)) {
      _bytes = SongArtwork._artworkBytesCache[key];
      return;
    }

    // Network images and existing local image files don't need MethodChannel
    final artUri = widget.artworkUri;
    if (artUri != null &&
        (artUri.startsWith('http://') || artUri.startsWith('https://'))) {
      return;
    }
    if (artUri != null &&
        !artUri.startsWith('content://') &&
        (artUri.startsWith('/') ||
            artUri.contains(':\\') ||
            artUri.startsWith('file://'))) {
      final path = artUri.startsWith('file://')
          ? Uri.parse(artUri).toFilePath()
          : artUri;
      if (File(path).existsSync()) {
        return;
      }
    }

    _loadArtworkBytes(key);
  }

  Future<void> _loadArtworkBytes(String key) async {
    if (SongArtwork._activeRequests.containsKey(key)) {
      final bytes = await SongArtwork._activeRequests[key];
      if (mounted) {
        setState(() {
          _bytes = bytes;
        });
      }
      return;
    }

    final future = _fetchFromPlatform();
    SongArtwork._activeRequests[key] = future;

    try {
      final bytes = await future;
      SongArtwork._artworkBytesCache[key] = bytes;
      if (mounted) {
        setState(() {
          _bytes = bytes;
        });
      }
    } catch (_) {
      SongArtwork._artworkBytesCache[key] = null;
    } finally {
      SongArtwork._activeRequests.remove(key);
    }
  }

  Future<Uint8List?> _fetchFromPlatform() async {
    if (!kIsWeb && !Platform.isAndroid) return null;
    try {
      final result = await SongArtwork._channel.invokeMethod<Uint8List>(
        'getArtwork',
        {
          'songId': widget.songId,
          'filePath': widget.filePath,
          'uri': widget.artworkUri,
        },
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width ?? widget.size ?? 48.0;
    final h = widget.height ?? widget.size ?? 48.0;
    final radius = widget.borderRadius ?? BorderRadius.circular(12);

    Widget content;

    // 1. Memory bytes loaded from ID3 tag or MediaStore thumbnail
    if (_bytes != null && _bytes!.isNotEmpty) {
      content = Image.memory(
        _bytes!,
        width: w,
        height: h,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) =>
            _buildFallback(w, h, radius),
      );
    }
    // 2. Remote HTTP/HTTPS Artwork (YouTube / Online Stream)
    else if (widget.artworkUri != null &&
        (widget.artworkUri!.startsWith('http://') ||
            widget.artworkUri!.startsWith('https://'))) {
      content = Image.network(
        widget.artworkUri!,
        width: w,
        height: h,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildFallback(w, h, radius);
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildFallback(w, h, radius),
      );
    }
    // 3. Local image file
    else if (widget.artworkUri != null &&
        !widget.artworkUri!.startsWith('content://') &&
        (widget.artworkUri!.startsWith('/') ||
            widget.artworkUri!.contains(':\\') ||
            widget.artworkUri!.startsWith('file://'))) {
      final path = widget.artworkUri!.startsWith('file://')
          ? Uri.parse(widget.artworkUri!).toFilePath()
          : widget.artworkUri!;
      final file = File(path);
      if (file.existsSync()) {
        content = Image.file(
          file,
          width: w,
          height: h,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallback(w, h, radius),
        );
      } else {
        content = _buildFallback(w, h, radius);
      }
    }
    // 4. Fallback dark glassmorphic note icon
    else {
      content = _buildFallback(w, h, radius);
    }

    final clipped = ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: w, height: h, child: content),
    );

    if (widget.heroTag != null && widget.heroTag!.isNotEmpty) {
      return Hero(tag: widget.heroTag!, child: clipped);
    }

    return clipped;
  }

  /// Sleek dark glassmorphic container with glowing neon music note icon.
  Widget _buildFallback(double w, double h, BorderRadius radius) {
    final iconSize = widget.iconSize ?? (w * 0.45).clamp(18.0, 72.0);

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: const Color(0xFF140F2D).withValues(alpha: 0.85),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.deepPurple.withValues(alpha: 0.6),
            const Color(0xFF0C091A).withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(
          color: widget.isCurrent
              ? AppColors.cyanAccent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.1),
          width: widget.isCurrent ? 1.5 : 1.0,
        ),
        boxShadow: widget.isCurrent
            ? [
                BoxShadow(
                  color: AppColors.cyanAccent.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: AppColors.purpleAccent.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Center(
        child: Icon(
          widget.isCurrent
              ? Icons.music_note_rounded
              : Icons.music_note_outlined,
          color: widget.isCurrent
              ? AppColors.cyanAccent
              : AppColors.purpleAccent.withValues(alpha: 0.85),
          size: iconSize,
        ),
      ),
    );
  }
}
