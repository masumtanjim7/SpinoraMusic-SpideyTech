import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_flavor.dart';

/// Placeholder home screen shown while features are being built.
///
/// Displays the active [AppFlavor] so it is immediately obvious which
/// build is running on-device. Replace the body with the real player
/// UI once Task 1 (Core & UI) is underway.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(appFlavorProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spinora'),
        actions: [
          _FlavorBadge(flavor: flavor),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder icon – swap for album art later.
            Icon(
              Icons.music_note_rounded,
              size: 80,
              color: cs.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Spinora Music',
              style: tt.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Flavor: ${flavor.name}',
              style: tt.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 48),
            Text(
              'Player UI coming in Task 1.',
              style: tt.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helper widget
// ---------------------------------------------------------------------------

class _FlavorBadge extends StatelessWidget {
  const _FlavorBadge({required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    // Only show the badge in dev so prod has a clean UI.
    if (flavor == AppFlavor.prod) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        flavor.label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
