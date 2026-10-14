import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/glass_card.dart';
import '../data/audio_scanner_service.dart';

/// Screen displaying all local audio tracks saved in the Drift database.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(localSongsStreamProvider);
    final scanState = ref.watch(audioScannerStateProvider);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient background lighting orbs for glass refraction
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.purpleGradient,
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyanAccent.withValues(alpha: 0.15),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Bar / Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Music Library',
                              style: tt.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              songsAsync.when(
                                data: (songs) =>
                                    '${songs.length} tracks available',
                                loading: () => 'Loading library...',
                                error: (error, stackTrace) =>
                                    'Error loading library',
                              ),
                              style: tt.bodySmall?.copyWith(
                                color: AppColors.cyanAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Top Action button for scan
                      IconButton.filledTonal(
                        onPressed: scanState.isScanning
                            ? null
                            : () => ref
                                .read(audioScannerStateProvider.notifier)
                                .scan(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: AppColors.cyanAccent,
                        ),
                        icon: scanState.isScanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.cyanAccent,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                        tooltip: 'Scan Device Storage',
                      ),
                    ],
                  ),
                ),

                // Scanning Banner (if active)
                if (scanState.isScanning)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deepPurple.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.purpleAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Scanning storage and indexing metadata...',
                          style: tt.bodySmall?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                // Songs List or State Placeholders
                Expanded(
                  child: songsAsync.when(
                    data: (songs) {
                      if (songs.isEmpty) {
                        return _EmptyLibraryView(
                          isScanning: scanState.isScanning,
                          onScanPressed: () => ref
                              .read(audioScannerStateProvider.notifier)
                              .scan(),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                        itemCount: songs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return _SongListTile(song: song);
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.purpleAccent,
                      ),
                    ),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Failed to load songs: $error',
                          style: tt.bodyMedium?.copyWith(
                            color: Colors.redAccent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: scanState.isScanning
            ? null
            : () => ref.read(audioScannerStateProvider.notifier).scan(),
        backgroundColor: AppColors.purpleAccent,
        foregroundColor: Colors.white,
        icon: scanState.isScanning
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.refresh_rounded),
        label: Text(
          scanState.isScanning ? 'Scanning...' : 'Scan Music',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Song item tile formatted with frosted glass styling and performance optimizations.
class _SongListTile extends StatelessWidget {
  const _SongListTile({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: _AlbumArtThumbnail(albumArtPath: song.albumArtPath),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          '${song.artist}${song.album != null ? ' • ${song.album}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        trailing: Text(
          formatDuration(song.duration),
          style: tt.labelSmall?.copyWith(
            color: AppColors.cyanAccent.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: () {
          // Track selection will connect to the Audio player in Phase 2
        },
      ),
    );
  }
}

/// Thumbnail for album artwork with gradient fallback icon.
class _AlbumArtThumbnail extends StatelessWidget {
  const _AlbumArtThumbnail({this.albumArtPath});

  final String? albumArtPath;

  @override
  Widget build(BuildContext context) {
    const size = 48.0;

    if (albumArtPath != null && albumArtPath!.isNotEmpty) {
      if (albumArtPath!.startsWith('content://') ||
          albumArtPath!.startsWith('file://') ||
          albumArtPath!.startsWith('/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(albumArtPath!),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _fallbackCover(size),
          ),
        );
      }
    }

    return _fallbackCover(size);
  }

  Widget _fallbackCover(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: AppColors.purpleGradient,
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

/// Displayed when no tracks have been indexed yet.
class _EmptyLibraryView extends StatelessWidget {
  const _EmptyLibraryView({
    required this.isScanning,
    required this.onScanPressed,
  });

  final bool isScanning;
  final VoidCallback onScanPressed;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.purpleGradient,
                ),
                child: const Icon(
                  Icons.library_music_outlined,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Songs Found',
                style: tt.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Your local library is empty. Tap below to scan your device storage for music tracks.',
                style: tt.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: isScanning ? null : onScanPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  isScanning ? 'Scanning...' : 'Scan Storage Now',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
