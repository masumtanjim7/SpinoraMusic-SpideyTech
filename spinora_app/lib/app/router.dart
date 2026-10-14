import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/library/data/permission_service.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/library/presentation/permission_screen.dart';

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

/// Application-wide [GoRouter] with a permission redirect guard.
///
/// Declared as a [Provider] so the redirect closure can call
/// `ref.read(audioPermissionStatusProvider.future)` via the captured
/// [Ref] — this is the idiomatic go_router + Riverpod pattern.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      // Avoid an infinite redirect loop on the permission screen itself.
      if (state.matchedLocation == '/permission') return null;

      final status = await ref
          .read(audioPermissionStatusProvider.future)
          .catchError((_) => PermissionStatus.denied);

      return status.isGranted ? null : '/permission';
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/permission',
        builder: (context, state) => const PermissionScreen(),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
    ],
  );
});
