import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The build flavors available in Spinora.
enum AppFlavor {
  dev,
  prod;

  /// Human-readable label shown in the UI.
  String get label => switch (this) {
        AppFlavor.dev => 'Dev',
        AppFlavor.prod => 'Prod',
      };

  /// The Drift database file name for this flavor.
  /// Keeps dev and prod data completely separate on-device.
  String get dbName => switch (this) {
        AppFlavor.dev => 'spinora_dev.db',
        AppFlavor.prod => 'spinora.db',
      };
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Holds the [AppFlavor] that was set at startup via [bootstrap].
/// Override this provider in tests or with a [ProviderScope] override to
/// inject a specific flavor without running the full app.
///
/// Throws a [StateError] if read before [bootstrap] has run –
/// this is intentional: the flavor must always be explicit.
final appFlavorProvider = Provider<AppFlavor>(
  (ref) => throw StateError(
    'appFlavorProvider must be overridden in the root ProviderScope. '
    'Did you forget to call bootstrap(flavor)?',
  ),
  name: 'appFlavorProvider',
);
