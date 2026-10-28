import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/lucid_cascade_item.dart';
import '../../library/presentation/library_screen.dart';
import '../../library/presentation/widgets/online_search_view.dart';
import '../../player/presentation/mini_player.dart';

/// Dedicated Search & YouTube Streaming screen dynamically adapting to
/// Dark Mode (obsidian-cosmos `#090712` / `#0D0B18`, translucent dark Lucid Glass)
/// and Light Mode (pearl-lilac `#F4F5FA` / `#EAEEF8`, frosted white cards).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.showMiniPlayer = true});

  final bool showMiniPlayer;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F111A);
    final secondaryText = isDark
        ? const Color(0xFFB4B0C8)
        : const Color(0xFF5C6275);
    final accentColor = isDark ? AppColors.cyanAccent : AppColors.lightAccent;
    final searchQuery = ref.watch(librarySearchQueryProvider);
    final tick = ref.watch(tabEntryTicksProvider.select((t) => t[2]));
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF090712)
          : const Color(0xFFF4F5FA),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF090712), Color(0xFF0D0B18)]
                : const [Color(0xFFF4F5FA), Color(0xFFEAEEF8)],
          ),
        ),
        child: Stack(
          children: [
            // Ambient glow orbs
            Positioned(
              top: -50,
              right: -30,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF7C3AED))
                          .withValues(alpha: isDark ? 0.20 : 0.08),
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
                      (isDark
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFFFF758F))
                          .withValues(alpha: isDark ? 0.14 : 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
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
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Icon(
                              Icons.travel_explore_rounded,
                              color: accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Search & Stream',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.titleLarge?.copyWith(
                                    color: primaryText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'YouTube audio streams & live discovery',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                    color: secondaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search input bar
                  LucidCascadeItem(
                    index: 1,
                    triggerKey: tick,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.95),
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {});
                          _debounceTimer?.cancel();
                          _debounceTimer = Timer(
                            const Duration(milliseconds: 500),
                            () {
                              ref
                                  .read(librarySearchQueryProvider.notifier)
                                  .setQuery(val);
                            },
                          );
                        },
                        onSubmitted: (val) {
                          _debounceTimer?.cancel();
                          ref
                              .read(librarySearchQueryProvider.notifier)
                              .setQuery(val);
                        },
                        textInputAction: TextInputAction.search,
                        style: TextStyle(color: primaryText, fontSize: 14),
                        cursorColor: accentColor,
                        decoration: InputDecoration(
                          hintText: 'Search YouTube music & streams...',
                          hintStyle: TextStyle(
                            color: secondaryText,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: accentColor,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  color: secondaryText,
                                  onPressed: () {
                                    _debounceTimer?.cancel();
                                    _searchController.clear();
                                    setState(() {});
                                    ref
                                        .read(
                                          librarySearchQueryProvider.notifier,
                                        )
                                        .clear();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Online Search Results View
                  Expanded(
                    child: OnlineSearchView(
                      searchQuery: searchQuery,
                      onSuggestionTap: (tag) {
                        _searchController.text = tag;
                        setState(() {});
                        _debounceTimer?.cancel();
                        ref
                            .read(librarySearchQueryProvider.notifier)
                            .setQuery(tag);
                      },
                    ),
                  ),
                ],
              ),
            ),

            if (widget.showMiniPlayer)
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
      ),
    );
  }
}

