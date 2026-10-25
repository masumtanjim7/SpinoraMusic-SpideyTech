import 'dart:async';
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
import '../../../core/navigation/lucid_page_transition.dart';
import '../../../core/widgets/lucid_cascade_item.dart';
import 'playlist_detail_screen.dart';
import 'widgets/library_group_views.dart';
import 'widgets/online_search_view.dart';
import 'widgets/song_artwork.dart';
import 'widgets/song_options_sheet.dart';

// ---------------------------------------------------------------------------
// Library Filter & Sort State & Providers
// ---------------------------------------------------------------------------

enum SongSortOption {
  titleAsc('Title', Icons.sort_by_alpha_rounded),
  artistAsc('Artist', Icons.person_rounded),
  mostPlayed('Most Played', Icons.local_fire_department_rounded),
  recentlyPlayed('Recently Played', Icons.history_rounded),
  durationDesc('Duration', Icons.timer_outlined);

  const SongSortOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum LibraryFilter {
  all,
  onlineSearch,
  favorites,
  mostPlayed,
  playlists,
  artists,
  albums,
}

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

class SongSortNotifier extends Notifier<SongSortOption> {
  @override
  SongSortOption build() => SongSortOption.titleAsc;

  void setSort(SongSortOption option) => state = option;
}

final librarySortOptionProvider =
    NotifierProvider<SongSortNotifier, SongSortOption>(SongSortNotifier.new);

class SortAscendingNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void setAscending(bool asc) => state = asc;
}

final librarySortAscendingProvider =
    NotifierProvider<SortAscendingNotifier, bool>(SortAscendingNotifier.new);

/// Filters and sorts the loaded songs according to the active search text,
/// category filter, and sort preference.
final filteredSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final songsAsync = ref.watch(localSongsStreamProvider);
  final query = ref.watch(librarySearchQueryProvider).trim().toLowerCase();
  final filter = ref.watch(libraryFilterProvider);
  final sortOption = ref.watch(librarySortOptionProvider);
  final isAsc = ref.watch(librarySortAscendingProvider);

  return songsAsync.whenData((songs) {
    final filtered = songs.where((song) {
      if (filter == LibraryFilter.favorites && !song.isFavorite) {
        return false;
      }
      if (filter == LibraryFilter.mostPlayed && song.playCount <= 0) {
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

    filtered.sort((a, b) {
      if (filter == LibraryFilter.mostPlayed) {
        final countCmp = b.playCount.compareTo(a.playCount);
        if (countCmp != 0) return countCmp;
      }

      int cmp;
      switch (sortOption) {
        case SongSortOption.titleAsc:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case SongSortOption.artistAsc:
          cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          if (cmp == 0) {
            cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
        case SongSortOption.mostPlayed:
          cmp = b.playCount.compareTo(a.playCount);
          if (cmp == 0) {
            cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
        case SongSortOption.recentlyPlayed:
          final aTime =
              a.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              b.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          cmp = bTime.compareTo(aTime);
        case SongSortOption.durationDesc:
          cmp = b.duration.compareTo(a.duration);
      }

      if (!isAsc) {
        cmp = -cmp;
      }
      return cmp;
    });

    return filtered;
  });
});

// ---------------------------------------------------------------------------
// Library Screen Widget
// ---------------------------------------------------------------------------

/// Screen displaying local audio tracks with instant search, favorites filter,
/// and embedded cover artwork.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.showMiniPlayer = true});

  final bool showMiniPlayer;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final TextEditingController _searchController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(librarySearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
    final tick = ref.watch(tabEntryTicksProvider.select((t) => t[1] + t[2]));

    final allSongs = allSongsAsync.asData?.value ?? [];
    final filteredSongs = filteredSongsAsync.asData?.value ?? [];
    final recentSongs = recentSongsAsync.asData?.value ?? [];
    final isSearchingOrFiltering =
        searchQuery.isNotEmpty || selectedFilter != LibraryFilter.all;

    return Scaffold(
      backgroundColor: widget.showMiniPlayer
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.transparent,
      body: Stack(
        children: [
          // Ambient background lighting orbs for glass refraction (soft glow, no solid clipping circles)
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (context.isDarkMode
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF7C3AED))
                        .withValues(alpha: context.isDarkMode ? 0.22 : 0.08),
                    Colors.transparent,
                  ],
                ),
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
                gradient: RadialGradient(
                  colors: [
                    (context.isDarkMode
                            ? const Color(0xFF00E5FF)
                            : const Color(0xFFFF758F))
                        .withValues(alpha: context.isDarkMode ? 0.15 : 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Bar / Header
                LucidCascadeItem(
                  index: 0,
                  triggerKey: tick,
                  child: Padding(
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
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: context.primaryText,
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
                                  color: context.primaryText,
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
                                  color: context.isDarkMode
                                      ? AppColors.cyanAccent
                                      : context.secondaryText,
                                  fontWeight: FontWeight.w500,
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
                            backgroundColor: context.isDarkMode
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.90),
                            foregroundColor: context.isDarkMode
                                ? AppColors.cyanAccent
                                : context.primaryAccent,
                          ),
                          icon: scanState.isScanning
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.isDarkMode
                                        ? AppColors.cyanAccent
                                        : context.primaryAccent,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded),
                          tooltip: 'Scan Device Storage',
                        ),
                      ],
                    ),
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
                      color: context.isDarkMode
                          ? AppColors.deepPurple.withValues(alpha: 0.4)
                          : context.primaryAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.isDarkMode
                            ? AppColors.purpleAccent.withValues(alpha: 0.3)
                            : context.primaryAccent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.primaryText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Scanning storage and indexing metadata...',
                            style: tt.bodySmall?.copyWith(
                              color: context.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Search Bar (shown when library has songs, searching, on playlists tab, or online search tab)
                if (allSongs.isNotEmpty ||
                    isSearchingOrFiltering ||
                    selectedFilter == LibraryFilter.playlists ||
                    selectedFilter == LibraryFilter.onlineSearch) ...[
                  LucidCascadeItem(
                    index: 1,
                    triggerKey: tick,
                    child: _GlassSearchBar(
                      controller: _searchController,
                      hintText: selectedFilter == LibraryFilter.onlineSearch
                          ? 'Search YouTube music & streams...'
                          : 'Search songs, artists, albums...',
                      onChanged: (val) {
                        if (selectedFilter == LibraryFilter.onlineSearch) {
                          _debounceTimer?.cancel();
                          _debounceTimer = Timer(
                            const Duration(milliseconds: 500),
                            () {
                              ref
                                  .read(librarySearchQueryProvider.notifier)
                                  .setQuery(val);
                            },
                          );
                        } else {
                          ref
                              .read(librarySearchQueryProvider.notifier)
                              .setQuery(val);
                        }
                      },
                      onSubmitted: (val) {
                        _debounceTimer?.cancel();
                        ref
                            .read(librarySearchQueryProvider.notifier)
                            .setQuery(val);
                      },
                      onClear: () {
                        _debounceTimer?.cancel();
                        _searchController.clear();
                        ref.read(librarySearchQueryProvider.notifier).clear();
                      },
                    ),
                  ),
                ],

                // Filter Bar (always visible so user can freely switch tabs)
                LucidCascadeItem(
                  index: 2,
                  triggerKey: tick,
                  child: _LibraryFilterBar(
                    selectedFilter: selectedFilter,
                    onFilterSelected: (f) {
                      setState(() {
                        ref.read(libraryFilterProvider.notifier).setFilter(f);
                      });
                    },
                    allSongs: allSongs,
                    totalCount: allSongs.length,
                    filteredCount: filteredSongs.length,
                    isSearchingOrFiltering: isSearchingOrFiltering,
                  ),
                ),

                // Songs List, Playlists, Artists, Albums, or State Placeholders
                Expanded(
                  child: switch (selectedFilter) {
                    LibraryFilter.onlineSearch => OnlineSearchView(
                      searchQuery: searchQuery,
                      onSuggestionTap: (tag) {
                        _searchController.text = tag;
                        _debounceTimer?.cancel();
                        ref
                            .read(librarySearchQueryProvider.notifier)
                            .setQuery(tag);
                      },
                    ),
                    LibraryFilter.playlists => const _PlaylistsView(),
                    LibraryFilter.artists => ArtistsGroupedView(
                      songs: allSongs,
                      searchQuery: searchQuery,
                    ),
                    LibraryFilter.albums => AlbumsGroupedView(
                      songs: allSongs,
                      searchQuery: searchQuery,
                    ),
                    _ => allSongsAsync.when(
                      data: (songs) {
                        if (songs.isEmpty &&
                            selectedFilter == LibraryFilter.all) {
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
                            isMostPlayedOnly:
                                selectedFilter == LibraryFilter.mostPlayed,
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
                                MediaQuery.of(context).padding.bottom +
                                    (playerState.hasTrack ? 150.0 : 100.0),
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
                  },
                ),
              ],
            ),
          ),

          // Floating Glass Mini-Player (bottom anchored)
          if (widget.showMiniPlayer)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: MiniPlayer(bottomPadding: 16)),
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
    this.hintText = 'Search songs, artists, albums...',
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: context.searchBarBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.searchBarBorder),
        boxShadow: context.isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: context.primaryText, fontSize: 14),
        cursorColor: context.primaryAccent,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: context.searchBarHint, fontSize: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.primaryAccent,
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: context.secondaryText,
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
    required this.allSongs,
    required this.totalCount,
    required this.filteredCount,
    required this.isSearchingOrFiltering,
  });

  final LibraryFilter selectedFilter;
  final ValueChanged<LibraryFilter> onFilterSelected;
  final List<Song> allSongs;
  final int totalCount;
  final int filteredCount;
  final bool isSearchingOrFiltering;

  @override
  Widget build(BuildContext context) {
    final uniqueArtists = allSongs.map((s) => s.artist.trim()).toSet();
    final uniqueAlbums = allSongs
        .map((s) => s.album?.trim() ?? 'Unknown Album')
        .toSet();

    final showSortButton =
        selectedFilter == LibraryFilter.all ||
        selectedFilter == LibraryFilter.favorites ||
        selectedFilter == LibraryFilter.mostPlayed;

    final isLight = context.isLight;

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
              activeColor: context.primaryAccent,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Favorites',
              icon: Icons.favorite_rounded,
              isSelected: selectedFilter == LibraryFilter.favorites,
              onTap: () => onFilterSelected(LibraryFilter.favorites),
              activeColor: Colors.pinkAccent,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Most Played',
              icon: Icons.local_fire_department_rounded,
              isSelected: selectedFilter == LibraryFilter.mostPlayed,
              onTap: () => onFilterSelected(LibraryFilter.mostPlayed),
              activeColor: Colors.orangeAccent,
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
              label: 'Artists',
              icon: Icons.person_rounded,
              isSelected: selectedFilter == LibraryFilter.artists,
              onTap: () => onFilterSelected(LibraryFilter.artists),
              activeColor: isLight
                  ? AppColors.lightAccent
                  : AppColors.cyanAccent,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Albums',
              icon: Icons.album_rounded,
              isSelected: selectedFilter == LibraryFilter.albums,
              onTap: () => onFilterSelected(LibraryFilter.albums),
              activeColor: isLight ? Colors.teal : Colors.tealAccent,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'YouTube Stream',
              icon: Icons.travel_explore_rounded,
              isSelected: selectedFilter == LibraryFilter.onlineSearch,
              onTap: () => onFilterSelected(LibraryFilter.onlineSearch),
              activeColor: Colors.redAccent,
            ),
            const SizedBox(width: 12),

            // Counter badge according to active tab
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
                      color: AppColors.purpleAccent.withValues(
                        alpha: isLight ? 0.10 : 0.15,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.purpleAccent.withValues(
                          alpha: isLight ? 0.25 : 0.3,
                        ),
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
            else if (selectedFilter == LibraryFilter.artists)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      (isLight ? AppColors.lightAccent : AppColors.cyanAccent)
                          .withValues(alpha: isLight ? 0.10 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        (isLight ? AppColors.lightAccent : AppColors.cyanAccent)
                            .withValues(alpha: isLight ? 0.25 : 0.3),
                  ),
                ),
                child: Text(
                  '${uniqueArtists.length} artists',
                  style: TextStyle(
                    color: isLight
                        ? AppColors.lightAccent
                        : AppColors.cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              )
            else if (selectedFilter == LibraryFilter.albums)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isLight ? Colors.teal : Colors.tealAccent).withValues(
                    alpha: isLight ? 0.10 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isLight ? Colors.teal : Colors.tealAccent)
                        .withValues(alpha: isLight ? 0.25 : 0.3),
                  ),
                ),
                child: Text(
                  '${uniqueAlbums.length} albums',
                  style: TextStyle(
                    color: isLight ? Colors.teal : Colors.tealAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              )
            else if (selectedFilter != LibraryFilter.onlineSearch)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.primaryAccent.withValues(
                    alpha: isLight ? 0.10 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.primaryAccent.withValues(
                      alpha: isLight ? 0.25 : 0.3,
                    ),
                  ),
                ),
                child: Text(
                  isSearchingOrFiltering
                      ? '$filteredCount / $totalCount'
                      : '$totalCount tracks',
                  style: TextStyle(
                    color: context.primaryAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

            // Sleek glassmorphic Sort Chip button
            if (showSortButton) ...[
              const SizedBox(width: 8),
              Consumer(
                builder: (context, ref, _) {
                  final sortOption = ref.watch(librarySortOptionProvider);
                  final isAsc = ref.watch(librarySortAscendingProvider);

                  return Tooltip(
                    message: 'Change sorting order',
                    child: InkWell(
                      onTap: () => showSortBottomSheet(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.glassTileBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.glassTileBorder),
                          boxShadow: context.glassTileShadow,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              sortOption.icon,
                              size: 13,
                              color: context.primaryAccent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              sortOption.label,
                              style: TextStyle(
                                color: context.primaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isAsc
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 12,
                              color: context.primaryAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
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
    final isLight = context.isLight;
    final effectiveColor =
        activeColor ?? (isLight ? AppColors.lightAccent : AppColors.cyanAccent);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isLight
                    ? effectiveColor.withValues(alpha: 0.12)
                    : effectiveColor.withValues(alpha: 0.18))
              : (isLight
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isLight
                      ? effectiveColor.withValues(alpha: 0.8)
                      : effectiveColor.withValues(alpha: 0.7))
                : (isLight
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.08)),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: effectiveColor.withValues(
                      alpha: isLight ? 0.20 : 0.25,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : (isLight
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? effectiveColor
                  : (isLight
                        ? context.secondaryText
                        : Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isLight ? effectiveColor : Colors.white)
                    : (isLight
                          ? context.secondaryText
                          : Colors.white.withValues(alpha: 0.7)),
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
                        color: context.primaryAccent.withValues(
                          alpha: context.isLight ? 0.12 : 0.15,
                        ),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        size: 15,
                        color: context.primaryAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RECENTLY PLAYED',
                      style: tt.labelMedium?.copyWith(
                        color: context.primaryText.withValues(
                          alpha: context.isLight ? 0.8 : 0.9,
                        ),
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
                    color: context.isLight
                        ? Colors.black.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${recentSongs.length}',
                    style: tt.labelSmall?.copyWith(
                      color: context.primaryAccent,
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
      onLongPress: () => showSongOptionsSheet(context: context, song: song),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 110,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isCurrent
              ? AppColors.purpleAccent.withValues(
                  alpha: context.isLight ? 0.12 : 0.18,
                )
              : context.glassTileBg,
          border: Border.all(
            color: isCurrent
                ? context.primaryAccent.withValues(alpha: 0.6)
                : context.glassTileBorder,
            width: isCurrent ? 1.5 : 1,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: context.primaryAccent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : context.glassTileShadow,
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
                          : LinearGradient(
                              colors: [
                                context.primaryAccent,
                                AppColors.purpleAccent,
                              ],
                            ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isCurrent
                                      ? AppColors.purpleAccent
                                      : context.primaryAccent)
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
                color: isCurrent ? context.primaryAccent : context.primaryText,
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
                color: context.secondaryText,
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
  const _SongListTile({required this.song, required this.songs});

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
            ? AppColors.purpleAccent.withValues(
                alpha: context.isLight ? 0.12 : 0.16,
              )
            : context.glassTileBg,
        border: Border.all(
          color: isCurrent
              ? context.primaryAccent.withValues(alpha: 0.65)
              : context.glassTileBorder,
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: context.primaryAccent.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 0.5,
                ),
                BoxShadow(
                  color: AppColors.purpleAccent.withValues(alpha: 0.16),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : context.glassTileShadow,
      ),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          onLongPress: () => showSongOptionsSheet(context: context, song: song),
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
                          color: isCurrent
                              ? context.primaryAccent
                              : context.primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${song.artist}${song.album != null ? ' • ${song.album}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: context.secondaryText,
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
                            : (context.isLight
                                  ? Colors.black.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.35)),
                        size: 18,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: song.isFavorite
                          ? 'Remove from Favorites'
                          : 'Add to Favorites',
                      onPressed: () async {
                        final db = ref.read(appDatabaseProvider);
                        await (db.update(
                          db.songs,
                        )..where((s) => s.id.equals(song.id))).write(
                          SongsCompanion(isFavorite: Value(!song.isFavorite)),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatDuration(song.duration),
                      style: tt.labelSmall?.copyWith(
                        color: isCurrent
                            ? context.primaryAccent
                            : context.secondaryText,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                      color: context.secondaryText,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 28,
                      ),
                      tooltip: 'Song Options',
                      onPressed: () =>
                          showSongOptionsSheet(context: context, song: song),
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
            ? (4.0 + 11.0 * (math.sin((t + 0.3) * math.pi)).abs()).clamp(
                4.0,
                15.0,
              )
            : 11.0;
        final h3 = widget.isPlaying
            ? (4.0 + 10.0 * (math.sin((t + 0.6) * math.pi)).abs()).clamp(
                4.0,
                15.0,
              )
            : 7.0;
        final h4 = widget.isPlaying
            ? (4.0 + 8.0 * (math.sin((t + 0.85) * math.pi)).abs()).clamp(
                4.0,
                15.0,
              )
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
    final searchQuery = ref
        .watch(librarySearchQueryProvider)
        .trim()
        .toLowerCase();
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
            Container(
              decoration: BoxDecoration(
                color: context.glassTileBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.purpleAccent.withValues(
                    alpha: context.isLight ? 0.25 : 0.35,
                  ),
                ),
                boxShadow: context.glassTileShadow,
              ),
              child: Material(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      showCreatePlaylistDialog(context: context, ref: ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
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
                                color: AppColors.purpleAccent.withValues(
                                  alpha: 0.3,
                                ),
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
                              Text(
                                'Create New Playlist',
                                style: TextStyle(
                                  color: context.primaryText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Curate custom mix collections',
                                style: TextStyle(
                                  color: context.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.add_circle_outline_rounded,
                          color: context.primaryAccent,
                          size: 22,
                        ),
                      ],
                    ),
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
                    style: TextStyle(color: context.secondaryText),
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
                        color: context.secondaryText,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Playlists Created Yet',
                        style: tt.titleSmall?.copyWith(
                          color: context.primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap "+ New Playlist" above to start building your playlists.',
                        style: tt.bodySmall?.copyWith(
                          color: context.secondaryText,
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
    final songCountAsync = ref.watch(
      playlistSongCountStreamProvider(playlist.id),
    );
    final count = songCountAsync.asData?.value ?? 0;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: context.glassTileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.glassTileBorder),
        boxShadow: context.glassTileShadow,
      ),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              LucidGlassPageRoute(
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
                          color: context.primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$count ${count == 1 ? 'track' : 'tracks'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: context.primaryAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: context.secondaryText,
                  size: 14,
                ),
              ],
            ),
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
    this.isFavoritesOnly = false,
    this.isMostPlayedOnly = false,
    required this.onReset,
  });

  final String query;
  final bool isFavoritesOnly;
  final bool isMostPlayedOnly;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final IconData icon;
    final String title;
    final String message;

    if (isMostPlayedOnly && query.isEmpty) {
      icon = Icons.local_fire_department_outlined;
      title = 'No Most Played Tracks Yet';
      message =
          'Play songs from your library to see them ranked here by play count.';
    } else if (isFavoritesOnly && query.isEmpty) {
      icon = Icons.favorite_border_rounded;
      title = 'No Favorites Yet';
      message =
          'Tap the heart icon on any track to add it to your favorites list.';
    } else {
      icon = Icons.search_off_rounded;
      title = 'No Tracks Found';
      message =
          'No songs matched your search criteria. Try a different keyword.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: context.secondaryText),
              const SizedBox(height: 14),
              Text(
                title,
                style: tt.titleMedium?.copyWith(
                  color: context.primaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: tt.bodySmall?.copyWith(color: context.secondaryText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.primaryAccent,
                  side: BorderSide(
                    color: context.primaryAccent.withValues(alpha: 0.5),
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
                  color: context.primaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan your local storage to index MP3s and audio files into your Spinora library.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: context.secondaryText),
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
