import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/library/data/permission_service.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/library/presentation/permission_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/application/user_profile_provider.dart';
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
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/permission',
        builder: (context, state) => const PermissionScreen(),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

