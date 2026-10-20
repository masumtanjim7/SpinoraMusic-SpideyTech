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

class GlassBottomNavBar extends StatelessWidget {
  const GlassBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavBarItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isActive: selectedIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavBarItem(
                    icon: Icons.library_music_rounded,
                    label: 'Library',
                    isActive: selectedIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavBarItem(
                    icon: Icons.search_rounded,
                    label: 'Search',
                    isActive: selectedIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  _NavBarItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    isActive: selectedIndex == 3,
                    onTap: () => onTap(3),
                  ),
                  _NavBarItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    isActive: selectedIndex == 4,
                    onTap: () => onTap(4),
                  ),
                ],
              ),
            ),
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
        isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED);
    final inactiveColor =
        isDark ? Colors.white.withValues(alpha: 0.50) : const Color(0xFF64748B);

    final pillDecoration = isActive
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.32),
                      const Color(0xFFFF758F).withValues(alpha: 0.18),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.75),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.22),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.90),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF7C3AED))
                    .withValues(alpha: isDark ? 0.30 : 0.16),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.transparent,
          );

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: pillDecoration,
                child: Icon(
                  icon,
                  size: 20,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? activeColor : inactiveColor,
                    letterSpacing: -0.1,
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
