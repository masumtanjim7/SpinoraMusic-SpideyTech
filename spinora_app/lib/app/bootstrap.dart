import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_flavor.dart';
import 'spidey_app.dart';

/// Shared startup function called by both entry points.
///
/// Overrides [appFlavorProvider] with the flavor chosen at compile time so
/// every provider and widget in the tree can read it without any platform
/// channel or BuildConfig access.
void bootstrap(AppFlavor flavor) {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: [
        appFlavorProvider.overrideWithValue(flavor),
      ],
      child: const SpideyApp(),
    ),
  );
}
