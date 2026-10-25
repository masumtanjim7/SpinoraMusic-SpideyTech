import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../../online/data/youtube_audio_service.dart';
import '../../../player/application/player_controller.dart';
import 'song_artwork.dart';

/// View displaying online YouTube music search results with live streaming playback.
class OnlineSearchView extends ConsumerWidget {
  const OnlineSearchView({
    super.key,
    required this.searchQuery,
    required this.onSuggestionTap,
  });

  final String searchQuery;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final tt = Theme.of(context).textTheme;

    if (searchQuery.trim().isEmpty) {
      return _OnlineSearchEmptyPrompt(onSuggestionTap: onSuggestionTap);
    }

    final searchResultsAsync = ref.watch(
      onlineSearchResultsProvider(searchQuery.trim()),
    );

    return searchResultsAsync.when(
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  color: AppColors.cyanAccent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Searching YouTube audio streams...',
                style: tt.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Fetching live metadata & stream manifests',
                style: tt.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 32,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Failed to load search results',
                style: tt.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => ref.refresh(
                  onlineSearchResultsProvider(searchQuery.trim()),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.cyanAccent,
                  side: BorderSide(
                    color: AppColors.cyanAccent.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (songs) {
        if (songs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    child: const Icon(
                      Icons.music_off_rounded,
                      size: 32,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No online streams found',
                    style: tt.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try searching with a different track title or artist.',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            playerState.hasTrack ? 110 : 80,
          ),
          itemCount: songs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final song = songs[index];
            final isCurrent =
                playerState.currentTrack?.uri == song.filePath ||
                playerState.currentTrack?.id == 'online_${song.id}';
            return _OnlineSongCard(
              song: song,
              isCurrent: isCurrent,
              isPlaying: isCurrent && playerState.isPlaying,
              onTap: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                await ref
                    .read(playerControllerProvider.notifier)
                    .playSong(song);
                final error = ref.read(playerControllerProvider).errorMessage;
                if (error != null && error.isNotEmpty) {
                  messenger?.showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF2A1520),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      content: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              error,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
              onPlayNext: () {
                ref.read(playerControllerProvider.notifier).playSongNext(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E1A2E),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.cyanAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    content: Text(
                      'Playing next: "${song.title}"',
                      style: const TextStyle(color: Colors.white),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OnlineSearchEmptyPrompt extends StatelessWidget {
  const _OnlineSearchEmptyPrompt({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  static const List<String> _suggestions = [
    'Trending Music',
    'Lofi Beats',
    'Synthwave Chill',
    'Top Hits 2026',
    'Acoustic Pop',
    'Cyberpunk EDM',
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE50914), AppColors.cyanAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Online Audio Search & Stream',
              style: tt.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stream millions of tracks directly with auto-synced lyrics, hardware equalizer, and zero ads.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'TRY SEARCHING FOR',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions.map((suggestion) {
                return InkWell(
                  onTap: () => onSuggestionTap(suggestion),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 13,
                          color: AppColors.cyanAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          suggestion,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineSongCard extends StatelessWidget {
  const _OnlineSongCard({
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayNext,
  });

  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.cyanAccent.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? AppColors.cyanAccent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.09),
          width: isCurrent ? 1.4 : 1.0,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.cyanAccent.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SongArtwork.fromSong(
                    song,
                    size: 52,
                    borderRadius: BorderRadius.circular(12),
                    isCurrent: isCurrent,
                  ),
                ),
                const SizedBox(width: 14),

                // Title, Author & Stream badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent
                                    ? AppColors.cyanAccent
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.5),
                                width: 0.9,
                              ),
                            ),
                            child: const Text(
                              'STREAM',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formatDuration(song.duration),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Equalizer wave indicator if currently playing
                if (isCurrent && isPlaying) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: AppColors.cyanAccent,
                      size: 20,
                    ),
                  ),
                ],

                IconButton(
                  icon: const Icon(Icons.playlist_play_rounded),
                  color: Colors.white.withValues(alpha: 0.7),
                  tooltip: 'Play Next',
                  onPressed: onPlayNext,
                  iconSize: 22,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
