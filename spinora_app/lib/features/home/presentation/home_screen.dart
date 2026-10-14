import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_flavor.dart';
import '../../../app/theme.dart';
import '../../../shared/glass_card.dart';

/// Home screen showing the Spinora glassmorphism design system.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(appFlavorProvider);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Spinora'),
        actions: [
          _FlavorBadge(flavor: flavor),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // Background ambient shapes to verify blur effect clearly
          Positioned(
            top: 100,
            left: 30,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.purpleGradient,
              ),
            ),
          ),
          Positioned(
            bottom: 160,
            right: 30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyanAccent.withValues(alpha: 0.7),
              ),
            ),
          ),

          // Main UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Good evening, Masum.',
                    style: tt.displayLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Spinora Design System (Task 0.7)',
                    style: tt.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  // Center GlassCard to verify the blur effect
                  Center(
                    child: GlassCard(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.purpleGradient,
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Glassmorphism Active',
                            style: tt.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '18-sigma blur with frosted fill and border.',
                            style: tt.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlavorBadge extends StatelessWidget {
  const _FlavorBadge({required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
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
