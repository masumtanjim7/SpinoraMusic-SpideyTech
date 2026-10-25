import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme.dart';
import '../../../shared/glass_card.dart';
import '../data/permission_service.dart';

/// Shown once on first launch (or after a cold-start when permission is not
/// yet granted) so the user can allow local audio access.
///
/// Navigates to '/' automatically after permission is granted.
/// Does NOT pop itself — the router redirect handles the transition.
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  bool _requesting = false;
  bool _permanentlyDenied = false;

  Future<void> _request() async {
    setState(() {
      _requesting = true;
      _permanentlyDenied = false;
    });

    final status = await requestAudioPermission();

    if (!mounted) return;

    if (status.isGranted) {
      // Invalidate the provider so the router redirect re-evaluates.
      ref.invalidate(audioPermissionStatusProvider);
      // Router redirect will push '/' once the provider resolves to granted.
      context.go('/');
    } else {
      setState(() {
        _requesting = false;
        _permanentlyDenied = status.isPermanentlyDenied;
      });
    }
  }

  Future<void> _openSettings() async {
    await openPermissionSettings();
    // Re-check after the user returns from system settings.
    if (!mounted) return;
    ref.invalidate(audioPermissionStatusProvider);
    final status = await checkAudioPermission();
    if (!mounted) return;
    if (status.isGranted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient background blobs — consistent with HomeScreen
          Positioned(
            top: 80,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.purpleGradient,
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyanAccent.withValues(alpha: 0.55),
              ),
            ),
          ),

          // Centered card
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.purpleGradient,
                          ),
                          child: const Icon(
                            Icons.library_music_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Allow Music Access',
                          style: tt.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        Text(
                          _permanentlyDenied
                              ? 'Access was denied. Open Settings to enable '
                                    '"Music & Audio" permission for Spinora.'
                              : 'Spinora needs access to your local audio files '
                                    'to scan and play your music library.',
                          style: tt.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // Primary action
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _requesting
                                ? null
                                : (_permanentlyDenied
                                      ? _openSettings
                                      : _request),
                            icon: _requesting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _permanentlyDenied
                                        ? Icons.settings_outlined
                                        : Icons.check_circle_outline_rounded,
                                  ),
                            label: Text(
                              _requesting
                                  ? 'Requesting…'
                                  : (_permanentlyDenied
                                        ? 'Open Settings'
                                        : 'Allow Access'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
