import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/theme_provider.dart';
import 'router.dart';
import 'theme.dart';

/// Root application widget.
///
/// Watches [appRouterProvider] and [themeModeProvider] so that the app reacts
/// dynamically to route changes and instant theme switches (Dark Cosmos / Light Lucid Glass).
class SpideyApp extends ConsumerWidget {
  const SpideyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Spinora',
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
