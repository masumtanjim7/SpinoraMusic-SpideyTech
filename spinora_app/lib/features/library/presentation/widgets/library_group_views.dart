import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../player/application/player_controller.dart';
import '../library_screen.dart';
import 'song_artwork.dart';

// ---------------------------------------------------------------------------
// Sort Bottom Sheet Launcher & Widget
// ---------------------------------------------------------------------------

void showSortBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const SortBottomSheet(),
  );
}

class SortBottomSheet extends ConsumerWidget {
  const SortBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSort = ref.watch(librarySortOptionProvider);
    final isAscending = ref.watch(librarySortAscendingProvider);
    final sortNotifier = ref.read(librarySortOptionProvider.notifier);
    final ascNotifier = ref.read(librarySortAscendingProvider.notifier);
    final tt = Theme.of(context).textTheme;
    final isLight = context.isLight;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.96)
            : AppColors.surface.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.7),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.primaryAccent.withValues(
                        alpha: isLight ? 0.12 : 0.15,
                      ),
                    ),
                    child: Icon(
                      Icons.sort_rounded,
                      size: 18,
                      color: context.primaryAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SORT SONGS',
                    style: tt.titleMedium?.copyWith(
                      color: context.primaryText,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: context.secondaryText),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Direction Toggle (Ascending vs Descending)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => ascNotifier.setAscending(true),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isAscending
                            ? context.primaryAccent.withValues(
                                alpha: isLight ? 0.15 : 0.2,
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAscending
                              ? context.primaryAccent.withValues(
                                  alpha: isLight ? 0.8 : 0.6,
                                )
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 16,
                            color: isAscending
                                ? context.primaryAccent
                                : context.secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ascending',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isAscending
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isAscending
                                  ? context.primaryAccent
                                  : context.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => ascNotifier.setAscending(false),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !isAscending
                            ? AppColors.purpleAccent.withValues(
                                alpha: isLight ? 0.15 : 0.2,
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !isAscending
                              ? AppColors.purpleAccent.withValues(
                                  alpha: isLight ? 0.8 : 0.6,
                                )
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 16,
                            color: !isAscending
                                ? AppColors.purpleAccent
                                : context.secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Descending',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: !isAscending
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: !isAscending
                                  ? AppColors.purpleAccent
                                  : context.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Options List
          for (final option in SongSortOption.values) ...[
            InkWell(
              onTap: () {
                sortNotifier.setSort(option);
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: currentSort == option
                      ? context.primaryAccent.withValues(
                          alpha: isLight ? 0.12 : 0.12,
                        )
                      : context.glassTileBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: currentSort == option
                        ? context.primaryAccent.withValues(
                            alpha: isLight ? 0.8 : 0.6,
                          )
                        : context.glassTileBorder,
                    width: currentSort == option ? 1.4 : 1.0,
                  ),
                  boxShadow: currentSort == option
                      ? null
                      : context.glassTileShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentSort == option
                            ? context.primaryAccent.withValues(
                                alpha: isLight ? 0.15 : 0.2,
                              )
                            : (isLight
                                  ? Colors.black.withValues(alpha: 0.05)
                                  : Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Icon(
                        option.icon,
                        size: 18,
                        color: currentSort == option
                            ? context.primaryAccent
                            : context.secondaryText,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        option.label,
                        style: tt.bodyMedium?.copyWith(
                          color: currentSort == option
                              ? (isLight ? context.primaryAccent : Colors.white)
                              : context.primaryText,
                          fontWeight: currentSort == option
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (currentSort == option)
                      Icon(
                        Icons.check_circle_rounded,
                        color: context.primaryAccent,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Artists Grouped View
// ---------------------------------------------------------------------------

class ArtistsGroupedView extends ConsumerWidget {
  const ArtistsGroupedView({
    super.key,
    required this.songs,
    required this.searchQuery,
  });

  final List<Song> songs;
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final tt = Theme.of(context).textTheme;

    // Group songs by artist name
    final Map<String, List<Song>> artistMap = {};
    for (final song in songs) {
      final artistName = song.artist.trim().isEmpty
          ? 'Unknown Artist'
          : song.artist.trim();
      artistMap.putIfAbsent(artistName, () => []).add(song);
    }

    final sortedArtists = artistMap.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // Filter by search query if non-empty
    final filteredArtists = searchQuery.isEmpty
        ? sortedArtists
        : sortedArtists.where((artist) {
            return artist.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

    if (filteredArtists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_off_rounded,
                size: 56,
                color: context.secondaryText,
              ),
              const SizedBox(height: 16),
              Text(
                'No Artists Found',
                style: tt.titleMedium?.copyWith(
                  color: context.primaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                searchQuery.isNotEmpty
                    ? 'No artists match "$searchQuery"'
                    : 'Scan your storage to populate your artist catalog.',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(color: context.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 8, 20, playerState.hasTrack ? 110 : 80),
      itemCount: filteredArtists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final artist = filteredArtists[index];
        final artistSongs = artistMap[artist] ?? [];
        final firstSong = artistSongs.first;

        return InkWell(
          onTap: () {
            showArtistDetailSheet(context, artist, artistSongs);
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.glassTileBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.glassTileBorder),
              boxShadow: context.glassTileShadow,
            ),
            child: Row(
              children: [
                // Circular artist artwork
                ClipOval(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: SongArtwork.fromSong(
                      firstSong,
                      width: 52,
                      height: 52,
                      borderRadius: BorderRadius.circular(26),
                      iconSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Artist name and track count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          color: context.primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${artistSongs.length} ${artistSongs.length == 1 ? 'track' : 'tracks'}',
                        style: tt.bodySmall?.copyWith(
                          color: context.primaryAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.chevron_right_rounded,
                  color: context.secondaryText,
                  size: 22,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void showArtistDetailSheet(
  BuildContext context,
  String artist,
  List<Song> songs,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _ArtistDetailSheet(artist: artist, songs: songs),
  );
}

class _ArtistDetailSheet extends ConsumerWidget {
  const _ArtistDetailSheet({required this.artist, required this.songs});

  final String artist;
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerController = ref.read(playerControllerProvider.notifier);
    final playerState = ref.watch(playerControllerProvider);
    final tt = Theme.of(context).textTheme;
    final isLight = context.isLight;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.96)
            : AppColors.surface.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: SongArtwork.fromSong(
                    songs.first,
                    width: 50,
                    height: 50,
                    borderRadius: BorderRadius.circular(25),
                    iconSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        color: context.primaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${songs.length} ${songs.length == 1 ? 'song' : 'songs'} in library',
                      style: tt.bodySmall?.copyWith(
                        color: context.primaryAccent,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: context.secondaryText),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Play All & Shuffle
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    playerController.playPlaylist(songs);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Play All',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purpleAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    playerController.playPlaylist(songs, shuffle: true);
                    Navigator.of(context).pop();
                  },
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: context.primaryAccent,
                  ),
                  label: Text(
                    'Shuffle',
                    style: TextStyle(
                      color: context.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: context.primaryAccent.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isLight ? Colors.black12 : Colors.white10),
          const SizedBox(height: 8),

          // Tracks List
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: songs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final song = songs[index];
                final isCurrent =
                    playerState.currentTrack?.id == 'local_${song.id}';

                return InkWell(
                  onTap: () {
                    playerController.playSong(song, songsQueue: songs);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? context.primaryAccent.withValues(
                              alpha: isLight ? 0.12 : 0.12,
                            )
                          : context.glassTileBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent
                            ? context.primaryAccent.withValues(
                                alpha: isLight ? 0.8 : 0.5,
                              )
                            : context.glassTileBorder,
                      ),
                      boxShadow: isCurrent ? null : context.glassTileShadow,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? context.primaryAccent
                                : context.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent
                                      ? context.primaryAccent
                                      : context.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (song.album != null)
                                Text(
                                  song.album!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.secondaryText,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          formatDuration(song.duration),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Albums Grouped View
// ---------------------------------------------------------------------------

class AlbumsGroupedView extends ConsumerWidget {
  const AlbumsGroupedView({
    super.key,
    required this.songs,
    required this.searchQuery,
  });

  final List<Song> songs;
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final tt = Theme.of(context).textTheme;

    // Group songs by album name
    final Map<String, List<Song>> albumMap = {};
    for (final song in songs) {
      final albumName = (song.album == null || song.album!.trim().isEmpty)
          ? 'Unknown Album'
          : song.album!.trim();
      albumMap.putIfAbsent(albumName, () => []).add(song);
    }

    final sortedAlbums = albumMap.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // Filter by search query if present
    final filteredAlbums = searchQuery.isEmpty
        ? sortedAlbums
        : sortedAlbums.where((album) {
            final matchesAlbum = album.toLowerCase().contains(
              searchQuery.toLowerCase(),
            );
            final matchesArtist = (albumMap[album]?.first.artist ?? '')
                .toLowerCase()
                .contains(searchQuery.toLowerCase());
            return matchesAlbum || matchesArtist;
          }).toList();

    if (filteredAlbums.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.album_outlined,
                size: 56,
                color: context.secondaryText,
              ),
              const SizedBox(height: 16),
              Text(
                'No Albums Found',
                style: tt.titleMedium?.copyWith(
                  color: context.primaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                searchQuery.isNotEmpty
                    ? 'No albums match "$searchQuery"'
                    : 'Scan your storage to populate your album library.',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(color: context.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 8, 20, playerState.hasTrack ? 110 : 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.74,
      ),
      itemCount: filteredAlbums.length,
      itemBuilder: (context, index) {
        final album = filteredAlbums[index];
        final albumSongs = albumMap[album] ?? [];
        final firstSong = albumSongs.first;

        return InkWell(
          onTap: () {
            showAlbumDetailSheet(context, album, albumSongs);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.glassTileBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.glassTileBorder),
              boxShadow: context.glassTileShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Artwork
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: SongArtwork.fromSong(
                        firstSong,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(16),
                        iconSize: 42,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Album title
                Text(
                  album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    color: context.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),

                // Artist & count
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        firstSong.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.purpleAccent.withValues(
                          alpha: context.isLight ? 0.10 : 0.15,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${albumSongs.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.purpleAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void showAlbumDetailSheet(
  BuildContext context,
  String album,
  List<Song> songs,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _AlbumDetailSheet(album: album, songs: songs),
  );
}

class _AlbumDetailSheet extends ConsumerWidget {
  const _AlbumDetailSheet({required this.album, required this.songs});

  final String album;
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerController = ref.read(playerControllerProvider.notifier);
    final playerState = ref.watch(playerControllerProvider);
    final tt = Theme.of(context).textTheme;
    final isLight = context.isLight;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.96)
            : AppColors.surface.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: SongArtwork.fromSong(
                    songs.first,
                    width: 50,
                    height: 50,
                    borderRadius: BorderRadius.circular(14),
                    iconSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        color: context.primaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${songs.first.artist} • ${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.purpleAccent,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: context.secondaryText),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Play All & Shuffle
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    playerController.playPlaylist(songs);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Play All',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryAccent,
                    foregroundColor: isLight ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    playerController.playPlaylist(songs, shuffle: true);
                    Navigator.of(context).pop();
                  },
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: context.primaryAccent,
                  ),
                  label: Text(
                    'Shuffle',
                    style: TextStyle(
                      color: context.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: context.primaryAccent.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isLight ? Colors.black12 : Colors.white10),
          const SizedBox(height: 8),

          // Tracks List
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: songs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final song = songs[index];
                final isCurrent =
                    playerState.currentTrack?.id == 'local_${song.id}';

                return InkWell(
                  onTap: () {
                    playerController.playSong(song, songsQueue: songs);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.purpleAccent.withValues(
                              alpha: isLight ? 0.12 : 0.15,
                            )
                          : context.glassTileBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.purpleAccent.withValues(
                                alpha: isLight ? 0.8 : 0.6,
                              )
                            : context.glassTileBorder,
                      ),
                      boxShadow: isCurrent ? null : context.glassTileShadow,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? AppColors.purpleAccent
                                : context.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent
                                  ? AppColors.purpleAccent
                                  : context.primaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          formatDuration(song.duration),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
