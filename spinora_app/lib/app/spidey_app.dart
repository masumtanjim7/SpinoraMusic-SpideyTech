import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

/// Root application widget.
///
/// Reads nothing from providers itself – all state is consumed by child
/// widgets so that MaterialApp.router stays stable on provider changes.
class SpideyApp extends ConsumerWidget {
  const SpideyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Spinora',
      theme: spideyDarkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
