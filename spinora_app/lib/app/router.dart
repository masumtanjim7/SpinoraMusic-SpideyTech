import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/navigation/lucid_page_transition.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/data/permission_service.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/library/presentation/permission_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/application/user_profile_provider.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

/// Application-wide [GoRouter] with a permission redirect guard and an
/// onboarding redirect for first-time users.
///
/// Redirect priority:
///   1. /permission — if audio permission not granted
///   2. /onboarding — if user hasn't completed onboarding
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final loc = state.matchedLocation;

      // Never loop on permission or onboarding screens
      if (loc == '/permission' || loc == '/onboarding') return null;

      // 1. Check audio permission
      final status = await ref
          .read(audioPermissionStatusProvider.future)
          .catchError((_) => PermissionStatus.denied);
      if (!status.isGranted) return '/permission';

      // 2. Check onboarding completion
      final profile = await ref
          .read(userProfileProvider.future)
          .catchError((_) => const UserProfile());
      if (!profile.hasCompletedOnboarding) return '/onboarding';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => LucidGlassTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => LucidGlassTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/permission',
        pageBuilder: (context, state) => LucidGlassTransitionPage(
          key: state.pageKey,
          child: const PermissionScreen(),
        ),
      ),
      GoRoute(
        path: '/library',
        pageBuilder: (context, state) => LucidGlassTransitionPage(
          key: state.pageKey,
          child: const LibraryScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => LucidGlassTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => LucidGlassTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
    ],
  );
});

