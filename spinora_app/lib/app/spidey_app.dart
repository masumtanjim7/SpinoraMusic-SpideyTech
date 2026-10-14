import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

/// Root application widget.
///
/// Watches [appRouterProvider] so that the [GoRouter] instance (and its
/// redirect guard) is available to [MaterialApp.router] without any extra
/// wiring.  The router itself is stable across rebuilds because it is backed
/// by a Riverpod [Provider].
class SpideyApp extends ConsumerWidget {
  const SpideyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Spinora',
      theme: spideyDarkTheme,
      darkTheme: spideyDarkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
