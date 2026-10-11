import 'package:go_router/go_router.dart';

import '../features/home/presentation/home_screen.dart';

/// Application-wide router.
/// Add new routes here as features are built.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
