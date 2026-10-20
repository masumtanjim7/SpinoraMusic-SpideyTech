import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/presentation/library_screen.dart';
import '../../player/presentation/mini_player.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main Scaffold — macOS-Style Glass Tab Shifting Navigation Shell
// ─────────────────────────────────────────────────────────────────────────────

/// Global riverpod notifier for tab selection.
class MainNavTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

/// Global riverpod provider to allow any child view to switch navigation tabs.
final mainNavTabProvider =
    NotifierProvider<MainNavTabNotifier, int>(MainNavTabNotifier.new);

/// Main application scaffold hosting the 5 primary tabs with a tactile,
/// macOS-style fluid glass tab shifting animation and persistent mini-player.
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _selectedIndex = 0;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = ref.read(mainNavTabProvider);
    _previousIndex = _selectedIndex;
  }

  void _onTabTapped(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();

    // Specific filter actions on tab activation
    if (index == 1) {
      ref.read(libraryFilterProvider.notifier).setFilter(LibraryFilter.all);
    } else if (index == 2) {
      ref
          .read(libraryFilterProvider.notifier)
          .setFilter(LibraryFilter.onlineSearch);
    }

    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });

    ref.read(mainNavTabProvider.notifier).setTab(index);
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const HomeDashboardView();
      case 1:
        return const LibraryScreen(showMiniPlayer: false);
      case 2:
        return const LibraryScreen(showMiniPlayer: false);
      case 3:
        return const ProfileScreen(showMiniPlayer: false);
      case 4:
        return const SettingsScreen(showMiniPlayer: false);
      default:
        return const HomeDashboardView();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Synchronize if external provider state changes
    ref.listen<int>(mainNavTabProvider, (prev, next) {
      if (next != _selectedIndex) {
        _onTabTapped(next);
      }
    });

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fluid macOS-style glass tab shifting animated switcher
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              reverseDuration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.topLeft,
                  children: <Widget>[
                    ...previousChildren,
                    ?currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                final isEntering =
                    (child.key as ValueKey<int>?)?.value == _selectedIndex;
                final isForward = _selectedIndex >= _previousIndex;

                // Horizontal parallax offset based on tab index direction
                final double slideOffset = isForward ? 0.08 : -0.08;
                final Offset beginOffset = isEntering
                    ? Offset(slideOffset, 0.0)
                    : Offset(-slideOffset, 0.0);

                final curvedAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );

                final slideAnimation = Tween<Offset>(
                  begin: beginOffset,
                  end: Offset.zero,
                ).animate(curvedAnimation);

                // Tactile scale factor (0.97 -> 1.0)
                final scaleAnimation = Tween<double>(
                  begin: isEntering ? 0.97 : 1.0,
                  end: isEntering ? 1.0 : 0.97,
                ).animate(curvedAnimation);

                // Frosted glass opacity fade
                final fadeAnimation = Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
                  reverseCurve:
                      const Interval(0.15, 1.0, curve: Curves.easeIn),
                ));

                return FadeTransition(
                  opacity: fadeAnimation,
                  child: SlideTransition(
                    position: slideAnimation,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      child: child,
                    ),
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedIndex),
                child: _buildTab(_selectedIndex),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent Floating Glass Mini-Player (sits floating right above the bottom bar)
          const MiniPlayer(bottomPadding: 8),
          GlassBottomNavBar(
            selectedIndex: _selectedIndex,
            onTap: _onTabTapped,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// macOS/Apple Lucid Glass Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────

class GlassBottomNavBar extends StatefulWidget {
  const GlassBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  State<GlassBottomNavBar> createState() => _GlassBottomNavBarState();
}

class _GlassBottomNavBarState extends State<GlassBottomNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    // Initial entrance light sweep shimmer
    _shimmerController.forward();
  }

  @override
  void didUpdateWidget(covariant GlassBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _shimmerController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final BoxDecoration glassDecoration = isDark
        ? BoxDecoration(
            color: const Color(0xFF0D0B18).withValues(alpha: 0.35),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1.0,
              ),
            ),
          )
        : BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.55),
                Colors.white.withValues(alpha: 0.25),
              ],
            ),
            color: Colors.white.withValues(alpha: 0.38),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: glassDecoration,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double totalWidth = constraints.maxWidth;
                  final double tabWidth = totalWidth / 5.0;
                  final double pillWidth = math.min(tabWidth - 4.0, 56.0);
                  const double pillHeight = 32.0;
                  final double pillLeft = (widget.selectedIndex * tabWidth) +
                      ((tabWidth - pillWidth) / 2.0);
                  const double pillTop = 4.0;

                  return Stack(
                    children: [
                      // Sliding & Morphing Lucid Glass Active Tab Pill
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        left: pillLeft,
                        top: pillTop,
                        width: pillWidth,
                        height: pillHeight,
                        child: _ActiveGlassPill(
                          isDark: isDark,
                          shimmerAnimation: _shimmerController,
                        ),
                      ),

                      // Interactive 5 Tabs
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _NavBarItem(
                            icon: Icons.home_rounded,
                            label: 'Home',
                            isActive: widget.selectedIndex == 0,
                            onTap: () => widget.onTap(0),
                          ),
                          _NavBarItem(
                            icon: Icons.library_music_rounded,
                            label: 'Library',
                            isActive: widget.selectedIndex == 1,
                            onTap: () => widget.onTap(1),
                          ),
                          _NavBarItem(
                            icon: Icons.search_rounded,
                            label: 'Search',
                            isActive: widget.selectedIndex == 2,
                            onTap: () => widget.onTap(2),
                          ),
                          _NavBarItem(
                            icon: Icons.person_rounded,
                            label: 'Profile',
                            isActive: widget.selectedIndex == 3,
                            onTap: () => widget.onTap(3),
                          ),
                          _NavBarItem(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            isActive: widget.selectedIndex == 4,
                            onTap: () => widget.onTap(4),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tactile Lucid Glass selection capsule with BackdropFilter, specular borders,
/// neon/lavender glow drop shadows, and a diagonal specular light sweep animation.
class _ActiveGlassPill extends StatelessWidget {
  const _ActiveGlassPill({
    required this.isDark,
    required this.shimmerAnimation,
  });

  final bool isDark;
  final Animation<double> shimmerAnimation;

  @override
  Widget build(BuildContext context) {
    final gradient = isDark
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF9D50BB).withValues(alpha: 0.28),
              const Color(0xFFFF5E99).withValues(alpha: 0.16),
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.72),
              const Color(0xFF8B5CF6).withValues(alpha: 0.18),
            ],
          );

    final border = Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.28)
          : Colors.white.withValues(alpha: 0.95),
      width: isDark ? 1.0 : 1.2,
    );

    final boxShadow = [
      if (isDark)
        BoxShadow(
          color: const Color(0xFF9D50BB).withValues(alpha: 0.35),
          blurRadius: 16,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        )
      else
        BoxShadow(
          color: const Color(0xFF7A5CFF).withValues(alpha: 0.20),
          blurRadius: 14,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Glass body capsule with gradient & specular border
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: gradient,
                  border: border,
                ),
              ),

              // Diagonal specular light sweep / glass shimmer on selection
              AnimatedBuilder(
                animation: shimmerAnimation,
                builder: (context, child) {
                  final progress = shimmerAnimation.value;
                  if (progress <= 0.0 || progress >= 1.0) {
                    return const SizedBox.shrink();
                  }

                  // Sweeps diagonally across from top-left to bottom-right
                  final double sweepX = -1.8 + (3.6 * progress);

                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment(sweepX - 0.7, -1.0),
                        end: Alignment(sweepX + 0.7, 1.0),
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(
                            alpha: isDark ? 0.38 : 0.50,
                          ),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor =
        isDark ? const Color(0xFFE9D5FF) : const Color(0xFF6D28D9);
    final inactiveColor =
        isDark ? Colors.white.withValues(alpha: 0.50) : const Color(0xFF64748B);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 32,
                child: Center(
                  child: AnimatedScale(
                    scale: isActive ? 1.15 : 1.0,
                    curve: Curves.easeOutBack,
                    duration: const Duration(milliseconds: 320),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? activeColor : inactiveColor,
                    letterSpacing: -0.1,
                    shadows: isActive
                        ? [
                            Shadow(
                              color: activeColor.withValues(
                                alpha: isDark ? 0.55 : 0.35,
                              ),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
