import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/glass_card.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/mini_player.dart';
import 'widgets/song_artwork.dart';
import 'widgets/song_options_sheet.dart';

/// Screen displaying the songs belonging to a specific custom playlist.
class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(playlistSongsStreamProvider(playlist.id));
    final playerState = ref.watch(playerControllerProvider);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Ambient neon glow orbs behind header
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.purpleGradient,
              ),
            ),
          ),
          Positioned(
            top: 100,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyanAccent.withValues(alpha: 0.15),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showDeleteConfirmation(context, ref),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                        tooltip: 'Delete Playlist',
                      ),
                    ],
                  ),
                ),

                // Playlist Hero Glass Card
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: AppColors.purpleGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.purpleAccent.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.queue_music_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playlist.name,
                                style: tt.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              songsAsync.when(
                                data: (songs) => Text(
                                  '${songs.length} tracks',
                                  style: tt.bodySmall?.copyWith(
                                    color: AppColors.cyanAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                loading: () => Text(
                                  'Loading...',
                                  style: tt.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                                error: (error, stackTrace) => Text(
                                  '0 tracks',
                                  style: tt.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Created ${playlist.createdAt.month}/${playlist.createdAt.day}/${playlist.createdAt.year}',
                                style: tt.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Play All and Shuffle Action Controls
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Prominent "Play All" Button
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: AppColors.purpleGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.purpleAccent.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                final songs = songsAsync.asData?.value ?? [];
                                if (songs.isEmpty) return;
                                ref
                                    .read(playerControllerProvider.notifier)
                                    .playPlaylist(songs);
                              },
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Play All',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Shuffle Button
                      Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final songs = songsAsync.asData?.value ?? [];
                              if (songs.isEmpty) return;
                              await ref
                                  .read(playerControllerProvider.notifier)
                                  .playPlaylist(songs, shuffle: true);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shuffle_rounded,
                                    color: AppColors.cyanAccent,
                                    size: 20,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Shuffle',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Songs List in this Playlist
                Expanded(
                  child: songsAsync.when(
                    data: (songs) {
                      if (songs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: GlassCard(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.music_off_rounded,
                                    size: 48,
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Empty Playlist',
                                    style: tt.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'No tracks added to this playlist yet. Return to the Music Library and tap the 3-dot menu on any song to add it here.',
                                    style: tt.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          playerState.hasTrack ? 110 : 40,
                        ),
                        itemCount: songs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          final isCurrent =
                              playerState.currentTrack?.id ==
                              'local_${song.id}';

                          return Material(
                            color: isCurrent
                                ? AppColors.purpleAccent.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isCurrent
                                    ? AppColors.cyanAccent.withValues(
                                        alpha: 0.4,
                                      )
                                    : Colors.white.withValues(alpha: 0.08),
                                width: isCurrent ? 1.5 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                ref
                                    .read(playerControllerProvider.notifier)
                                    .playPlaylist(songs, initialIndex: index);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    SongArtwork.fromSong(
                                      song,
                                      size: 48,
                                      borderRadius: BorderRadius.circular(12),
                                      isCurrent: isCurrent,
                                      iconSize: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: tt.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: isCurrent
                                                  ? AppColors.cyanAccent
                                                  : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${song.artist}${song.album != null ? ' • ${song.album}' : ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: tt.bodySmall?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.6,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          formatDuration(song.duration),
                                          style: tt.labelSmall?.copyWith(
                                            color: isCurrent
                                                ? AppColors.cyanAccent
                                                : AppColors.cyanAccent
                                                      .withValues(alpha: 0.8),
                                            fontWeight: isCurrent
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline_rounded,
                                            color: Colors.white38,
                                            size: 18,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          tooltip: 'Remove from Playlist',
                                          onPressed: () async {
                                            final db = ref.read(
                                              appDatabaseProvider,
                                            );
                                            await db.removeSongFromPlaylist(
                                              playlistId: playlist.id,
                                              songId: song.id,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.more_vert_rounded,
                                            color: Colors.white54,
                                            size: 18,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 26,
                                            minHeight: 28,
                                          ),
                                          tooltip: 'Track Options',
                                          onPressed: () {
                                            showSongOptionsSheet(
                                              context: context,
                                              song: song,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.purpleAccent,
                      ),
                    ),
                    error: (error, stackTrace) => Center(
                      child: Text(
                        'Error loading songs: $error',
                        style: const TextStyle(color: Colors.redAccent),
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
            child: SafeArea(top: false, child: MiniPlayer(bottomPadding: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF181528),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          title: const Text(
            'Delete Playlist?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${playlist.name}"? The songs will remain in your music library.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final db = ref.read(appDatabaseProvider);
      await db.deletePlaylist(playlist.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
