import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/glass_card.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/mini_player.dart';
import '../data/audio_scanner_service.dart';

/// Screen displaying all local audio tracks saved in the Drift database.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(localSongsStreamProvider);
    final scanState = ref.watch(audioScannerStateProvider);
    final playerState = ref.watch(playerControllerProvider);
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
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          playerState.hasTrack ? 110 : 80,
                        ),
                        itemCount: songs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return _SongListTile(
                            song: song,
                            songs: songs,
                          );
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

          // Floating Glass Mini-Player (bottom anchored)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: MiniPlayer(bottomPadding: 16),
            ),
          ),
        ],
      ),
      floatingActionButton: playerState.hasTrack
          ? null
          : FloatingActionButton.extended(
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

/// Song item tile formatted with frosted glass styling and active track highlights.
class _SongListTile extends ConsumerWidget {
  const _SongListTile({
    required this.song,
    required this.songs,
  });

  final Song song;
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final isCurrent = playerState.currentTrack?.id == 'local_${song.id}';
    final isPlaying = isCurrent && playerState.isPlaying;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: isCurrent
          ? AppColors.purpleAccent.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCurrent
              ? AppColors.cyanAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: _AlbumArtThumbnail(
          albumArtPath: song.albumArtPath,
          isCurrent: isCurrent,
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: isCurrent ? AppColors.cyanAccent : Colors.white,
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrent) ...[
              Icon(
                isPlaying
                    ? Icons.graphic_eq_rounded
                    : Icons.pause_circle_outline_rounded,
                color: AppColors.cyanAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              formatDuration(song.duration),
              style: tt.labelSmall?.copyWith(
                color: isCurrent
                    ? AppColors.cyanAccent
                    : AppColors.cyanAccent.withValues(alpha: 0.8),
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
        onTap: () {
          if (isCurrent) {
            ref.read(playerControllerProvider.notifier).togglePlayPause();
          } else {
            ref
                .read(playerControllerProvider.notifier)
                .playSong(song, songsQueue: songs);
          }
        },
      ),
    );
  }
}

/// Thumbnail for album artwork with gradient fallback icon.
class _AlbumArtThumbnail extends StatelessWidget {
  const _AlbumArtThumbnail({
    this.albumArtPath,
    this.isCurrent = false,
  });

  final String? albumArtPath;
  final bool isCurrent;

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
            errorBuilder: (context, error, stackTrace) => _fallbackCover(size),
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
        gradient: isCurrent ? null : AppColors.purpleGradient,
        color: isCurrent ? AppColors.purpleAccent : null,
      ),
      child: Icon(
        isCurrent ? Icons.music_note_rounded : Icons.music_note_outlined,
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
