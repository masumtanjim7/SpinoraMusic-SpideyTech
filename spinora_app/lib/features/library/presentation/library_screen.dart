import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/glass_card.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/mini_player.dart';
import '../data/audio_scanner_service.dart';
import 'playlist_detail_screen.dart';
import 'widgets/song_artwork.dart';
import 'widgets/song_options_sheet.dart';

// ---------------------------------------------------------------------------
// Library Filter State & Providers
// ---------------------------------------------------------------------------

enum LibraryFilter { all, playlists, favorites }

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final librarySearchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => LibraryFilter.all;

  void setFilter(LibraryFilter filter) => state = filter;
}

final libraryFilterProvider =
    NotifierProvider<LibraryFilterNotifier, LibraryFilter>(
  LibraryFilterNotifier.new,
);

/// Filters the loaded songs according to the active search text and favorites filter.
final filteredSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final songsAsync = ref.watch(localSongsStreamProvider);
  final query = ref.watch(librarySearchQueryProvider).trim().toLowerCase();
  final filter = ref.watch(libraryFilterProvider);

  return songsAsync.whenData((songs) {
    return songs.where((song) {
      if (filter == LibraryFilter.favorites && !song.isFavorite) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesTitle = song.title.toLowerCase().contains(query);
        final matchesArtist = song.artist.toLowerCase().contains(query);
        final matchesAlbum = song.album?.toLowerCase().contains(query) ?? false;
        if (!matchesTitle && !matchesArtist && !matchesAlbum) {
          return false;
        }
      }
      return true;
    }).toList();
  });
});

// ---------------------------------------------------------------------------
// Library Screen Widget
// ---------------------------------------------------------------------------

/// Screen displaying local audio tracks with instant search, favorites filter,
/// and embedded cover artwork.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(librarySearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSongsAsync = ref.watch(localSongsStreamProvider);
    final filteredSongsAsync = ref.watch(filteredSongsProvider);
    final recentSongsAsync = ref.watch(recentlyPlayedSongsStreamProvider);
    final scanState = ref.watch(audioScannerStateProvider);
    final playerState = ref.watch(playerControllerProvider);
    final selectedFilter = ref.watch(libraryFilterProvider);
    final searchQuery = ref.watch(librarySearchQueryProvider);
    final tt = Theme.of(context).textTheme;

    final allSongs = allSongsAsync.asData?.value ?? [];
    final filteredSongs = filteredSongsAsync.asData?.value ?? [];
    final recentSongs = recentSongsAsync.asData?.value ?? [];
    final isSearchingOrFiltering =
        searchQuery.isNotEmpty || selectedFilter != LibraryFilter.all;

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
                              allSongsAsync.when(
                                data: (songs) =>
                                    '${songs.length} tracks available',
                                loading: () => 'Loading library...',
                                error: (error, _) => 'Error loading library',
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

                // Search Bar (shown when library has songs, searching, or on playlists tab)
                if (allSongs.isNotEmpty ||
                    isSearchingOrFiltering ||
                    selectedFilter == LibraryFilter.playlists) ...[
                  _GlassSearchBar(
                    controller: _searchController,
                    onChanged: (val) {
                      ref
                          .read(librarySearchQueryProvider.notifier)
                          .setQuery(val);
                    },
                    onClear: () {
                      _searchController.clear();
                      ref.read(librarySearchQueryProvider.notifier).clear();
                    },
                  ),
                ],

                // Filter Bar (always visible so user can freely switch tabs)
                _LibraryFilterBar(
                  selectedFilter: selectedFilter,
                  onFilterSelected: (f) {
                    setState(() {
                      ref.read(libraryFilterProvider.notifier).setFilter(f);
                    });
                  },
                  totalCount: allSongs.length,
                  filteredCount: filteredSongs.length,
                  isSearchingOrFiltering: isSearchingOrFiltering,
                ),

                // Songs List, Playlists, or State Placeholders
                Expanded(
                  child: selectedFilter == LibraryFilter.playlists
                      ? const _PlaylistsView()
                      : allSongsAsync.when(
                    data: (songs) {
                      if (songs.isEmpty && selectedFilter == LibraryFilter.all) {
                        return _EmptyLibraryView(
                          isScanning: scanState.isScanning,
                          onScanPressed: () => ref
                              .read(audioScannerStateProvider.notifier)
                              .scan(),
                        );
                      }

                      if (filteredSongs.isEmpty) {
                        return _NoSearchResultsView(
                          query: searchQuery,
                          isFavoritesOnly:
                              selectedFilter == LibraryFilter.favorites,
                          onReset: () {
                            _searchController.clear();
                            ref
                                .read(librarySearchQueryProvider.notifier)
                                .clear();
                            setState(() {
                              ref
                                  .read(libraryFilterProvider.notifier)
                                  .setFilter(LibraryFilter.all);
                            });
                          },
                        );
                      }

                      final showRecentlyPlayed =
                          selectedFilter == LibraryFilter.all &&
                              searchQuery.isEmpty &&
                              recentSongs.isNotEmpty;

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          if (showRecentlyPlayed) ...[
                            SliverToBoxAdapter(
                              child: _RecentlyPlayedSection(
                                recentSongs: recentSongs,
                              ),
                            ),
                          ],
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              showRecentlyPlayed ? 4 : 8,
                              20,
                              playerState.hasTrack ? 110 : 80,
                            ),
                            sliver: SliverList.separated(
                              itemCount: filteredSongs.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final song = filteredSongs[index];
                                return _SongListTile(
                                  song: song,
                                  songs: filteredSongs,
                                );
                              },
                            ),
                          ),
                        ],
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

// ---------------------------------------------------------------------------
// Search Bar Widget
// ---------------------------------------------------------------------------

class _GlassSearchBar extends StatelessWidget {
  const _GlassSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: AppColors.cyanAccent,
        decoration: InputDecoration(
          hintText: 'Search songs, artists, albums...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.cyanAccent,
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: Colors.white.withValues(alpha: 0.6),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter Chips & Counter Bar
// ---------------------------------------------------------------------------

class _LibraryFilterBar extends StatelessWidget {
  const _LibraryFilterBar({
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.totalCount,
    required this.filteredCount,
    required this.isSearchingOrFiltering,
  });

  final LibraryFilter selectedFilter;
  final ValueChanged<LibraryFilter> onFilterSelected;
  final int totalCount;
  final int filteredCount;
  final bool isSearchingOrFiltering;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterChip(
              label: 'All Songs',
              icon: Icons.music_note_rounded,
              isSelected: selectedFilter == LibraryFilter.all,
              onTap: () => onFilterSelected(LibraryFilter.all),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Playlists',
              icon: Icons.queue_music_rounded,
              isSelected: selectedFilter == LibraryFilter.playlists,
              onTap: () => onFilterSelected(LibraryFilter.playlists),
              activeColor: AppColors.purpleAccent,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Favorites',
              icon: Icons.favorite_rounded,
              isSelected: selectedFilter == LibraryFilter.favorites,
              onTap: () => onFilterSelected(LibraryFilter.favorites),
              activeColor: Colors.pinkAccent,
            ),
            const SizedBox(width: 12),
            // Counter badge
            if (selectedFilter == LibraryFilter.playlists)
              Consumer(
                builder: (context, ref, _) {
                  final playlists =
                      ref.watch(allPlaylistsStreamProvider).asData?.value ?? [];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.purpleAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.purpleAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${playlists.length} playlists',
                      style: const TextStyle(
                        color: AppColors.purpleAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.cyanAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isSearchingOrFiltering
                      ? '$filteredCount / $totalCount'
                      : '$totalCount tracks',
                  style: const TextStyle(
                    color: AppColors.cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = activeColor ?? AppColors.cyanAccent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? effectiveColor.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: effectiveColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? effectiveColor
                  : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recently Played Horizontal Strip Widgets
// ---------------------------------------------------------------------------

/// Sleek horizontal "Recently Played" glassmorphic carousel displayed at the top of All Songs.
class _RecentlyPlayedSection extends ConsumerWidget {
  const _RecentlyPlayedSection({required this.recentSongs});

  final List<Song> recentSongs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cyanAccent.withValues(alpha: 0.15),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 15,
                        color: AppColors.cyanAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RECENTLY PLAYED',
                      style: tt.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${recentSongs.length}',
                    style: tt.labelSmall?.copyWith(
                      color: AppColors.cyanAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: recentSongs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final song = recentSongs[index];
                final isCurrent =
                    playerState.currentTrack?.id == 'local_${song.id}';
                final isPlaying = isCurrent && playerState.isPlaying;

                return _RecentlyPlayedCard(
                  song: song,
                  recentSongs: recentSongs,
                  isCurrent: isCurrent,
                  isPlaying: isPlaying,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Glassmorphic card in the Recently Played strip featuring artwork, glowing play badge, and metadata.
class _RecentlyPlayedCard extends ConsumerWidget {
  const _RecentlyPlayedCard({
    required this.song,
    required this.recentSongs,
    required this.isCurrent,
    required this.isPlaying,
  });

  final Song song;
  final List<Song> recentSongs;
  final bool isCurrent;
  final bool isPlaying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (isCurrent) {
          ref.read(playerControllerProvider.notifier).togglePlayPause();
        } else {
          ref
              .read(playerControllerProvider.notifier)
              .playSong(song, songsQueue: recentSongs);
        }
      },
      onLongPress: () => showSongOptionsSheet(
        context: context,
        song: song,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 110,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isCurrent
              ? AppColors.purpleAccent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isCurrent
                ? AppColors.cyanAccent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: isCurrent ? 1.5 : 1,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: AppColors.cyanAccent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SongArtwork.fromSong(
                  song,
                  size: 94,
                  borderRadius: BorderRadius.circular(14),
                  isCurrent: isCurrent,
                  iconSize: 32,
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isCurrent
                          ? AppColors.purpleGradient
                          : const LinearGradient(
                              colors: [
                                AppColors.cyanAccent,
                                AppColors.purpleAccent,
                              ],
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: (isCurrent
                                  ? AppColors.purpleAccent
                                  : AppColors.cyanAccent)
                              .withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(
                color: isCurrent ? AppColors.cyanAccent : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Song List Tile Widget
// ---------------------------------------------------------------------------

/// Song item tile formatted with frosted glass styling, neon border glow, and animated equalizer.
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isCurrent
            ? AppColors.purpleAccent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: isCurrent
              ? AppColors.cyanAccent.withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.08),
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.cyanAccent.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 0.5,
                ),
                BoxShadow(
                  color: AppColors.purpleAccent.withValues(alpha: 0.16),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isCurrent) {
              ref.read(playerControllerProvider.notifier).togglePlayPause();
            } else {
              ref
                  .read(playerControllerProvider.notifier)
                  .playSong(song, songsQueue: songs);
            }
          },
          onLongPress: () => showSongOptionsSheet(
            context: context,
            song: song,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? AppColors.cyanAccent : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${song.artist}${song.album != null ? ' • ${song.album}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrent) ...[
                      _EqualizerIndicator(isPlaying: isPlaying),
                      const SizedBox(width: 8),
                    ],
                  IconButton(
                    icon: Icon(
                      song.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: song.isFavorite
                          ? Colors.pinkAccent
                          : Colors.white.withValues(alpha: 0.35),
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: song.isFavorite
                        ? 'Remove from Favorites'
                        : 'Add to Favorites',
                    onPressed: () async {
                      final db = ref.read(appDatabaseProvider);
                      await (db.update(db.songs)
                            ..where((s) => s.id.equals(song.id)))
                          .write(
                        SongsCompanion(isFavorite: Value(!song.isFavorite)),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatDuration(song.duration),
                    style: tt.labelSmall?.copyWith(
                      color: isCurrent
                          ? AppColors.cyanAccent
                          : AppColors.cyanAccent.withValues(alpha: 0.8),
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                    ),
                    color: Colors.white.withValues(alpha: 0.5),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 26, minHeight: 28),
                    tooltip: 'Song Options',
                    onPressed: () => showSongOptionsSheet(
                      context: context,
                      song: song,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
 }
}

/// Animated 4-bar equalizer icon that bounces rhythmically while playing.
class _EqualizerIndicator extends StatefulWidget {
  const _EqualizerIndicator({required this.isPlaying});

  final bool isPlaying;

  @override
  State<_EqualizerIndicator> createState() => _EqualizerIndicatorState();
}

class _EqualizerIndicatorState extends State<_EqualizerIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _EqualizerIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final h1 = widget.isPlaying
            ? (5.0 + 8.0 * math.sin(t * math.pi)).clamp(4.0, 15.0)
            : 5.0;
        final h2 = widget.isPlaying
            ? (4.0 + 11.0 * (math.sin((t + 0.3) * math.pi)).abs())
                .clamp(4.0, 15.0)
            : 11.0;
        final h3 = widget.isPlaying
            ? (4.0 + 10.0 * (math.sin((t + 0.6) * math.pi)).abs())
                .clamp(4.0, 15.0)
            : 7.0;
        final h4 = widget.isPlaying
            ? (4.0 + 8.0 * (math.sin((t + 0.85) * math.pi)).abs())
                .clamp(4.0, 15.0)
            : 4.0;

        return SizedBox(
          width: 18,
          height: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(h1),
              const SizedBox(width: 2),
              _buildBar(h2),
              const SizedBox(width: 2),
              _buildBar(h3),
              const SizedBox(width: 2),
              _buildBar(h4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cyanAccent,
        borderRadius: BorderRadius.circular(1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanAccent.withValues(alpha: 0.55),
            blurRadius: 3,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Playlists View & Tile Widgets
// ---------------------------------------------------------------------------

class _PlaylistsView extends ConsumerWidget {
  const _PlaylistsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(allPlaylistsStreamProvider);
    final searchQuery =
        ref.watch(librarySearchQueryProvider).trim().toLowerCase();
    final playerState = ref.watch(playerControllerProvider);
    final tt = Theme.of(context).textTheme;

    return playlistsAsync.when(
      data: (playlists) {
        final filteredPlaylists = searchQuery.isEmpty
            ? playlists
            : playlists
                .where((p) => p.name.toLowerCase().contains(searchQuery))
                .toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            playerState.hasTrack ? 110 : 80,
          ),
          children: [
            // Glassmorphic "+ New Playlist" action card
            Material(
              color: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.purpleAccent.withValues(alpha: 0.35),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () =>
                    showCreatePlaylistDialog(context: context, ref: ref),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.purpleGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.purpleAccent.withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Create New Playlist',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Curate custom mix collections',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.cyanAccent.withValues(alpha: 0.8),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (filteredPlaylists.isEmpty && searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No playlists matching "$searchQuery"',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ),
              )
            else if (filteredPlaylists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Playlists Created Yet',
                        style: tt.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap "+ New Playlist" above to start building your playlists.',
                        style: tt.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredPlaylists.map((playlist) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PlaylistTile(playlist: playlist),
                );
              }),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.purpleAccent),
      ),
      error: (error, stackTrace) => Center(
        child: Text(
          'Failed to load playlists: $error',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  const _PlaylistTile({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songCountAsync =
        ref.watch(playlistSongCountStreamProvider(playlist.id));
    final count = songCountAsync.asData?.value ?? 0;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlaylistDetailScreen(playlist: playlist),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.queue_music_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$count ${count == 1 ? 'track' : 'tracks'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.cyanAccent.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white38,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholders & Empty Views
// ---------------------------------------------------------------------------

/// Displayed when a search or filter produces 0 results.
class _NoSearchResultsView extends StatelessWidget {
  const _NoSearchResultsView({
    required this.query,
    required this.isFavoritesOnly,
    required this.onReset,
  });

  final String query;
  final bool isFavoritesOnly;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFavoritesOnly
                    ? Icons.favorite_border_rounded
                    : Icons.search_off_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 14),
              Text(
                isFavoritesOnly && query.isEmpty
                    ? 'No Favorites Yet'
                    : 'No Tracks Found',
                style: tt.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFavoritesOnly && query.isEmpty
                    ? 'Tap the heart icon on any track to add it to your favorites list.'
                    : 'No songs matched your search criteria. Try a different keyword.',
                style: tt.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.cyanAccent,
                  side: BorderSide(
                    color: AppColors.cyanAccent.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displayed when no tracks have been indexed yet in the database.
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
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.purpleAccent.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.library_music_rounded,
                  size: 36,
                  color: AppColors.purpleAccent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Songs Found',
                style: tt.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan your local storage to index MP3s and audio files into your Spinora library.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: isScanning ? null : onScanPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: isScanning
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
                  isScanning ? 'Scanning Storage...' : 'Scan Storage Now',
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
