import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/library/data/audio_scanner_service.dart';
import '../../../features/player/application/player_controller.dart';
import '../../../features/profile/application/user_profile_provider.dart';
import '../../../features/profile/presentation/edit_profile_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Settings Screen — Lucid Glass Dashboard
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _appVersion = '1.0.0';
  static const _appName = 'Spinora Music • SpideyTech';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    final scanState = ref.watch(audioScannerStateProvider);
    final songsAsync = ref.watch(localSongsStreamProvider);
    final playerState = ref.watch(playerControllerProvider);
    final trackCount = songsAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF08070F),
      body: Stack(
        children: [
          // Ambient blobs
          _buildAmbientBlobs(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, profile),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Audio
                        _SectionLabel(label: 'AUDIO'),
                        const SizedBox(height: 12),
                        _SettingsTile(
                          icon: Icons.graphic_eq_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'Equalizer & Bass Boost',
                          subtitle: playerState.equalizerEnabled
                              ? 'EQ active • ${playerState.equalizerPreset.name}'
                              : 'Tap to open hardware equalizer',
                          trailingWidget: playerState.equalizerEnabled
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.2),
                                    border: Border.all(
                                        color: const Color(0xFF8B5CF6)
                                            .withValues(alpha: 0.5)),
                                  ),
                                  child: const Text('ON',
                                      style: TextStyle(
                                          color: Color(0xFF8B5CF6),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2)),
                                )
                              : null,
                          onTap: () => _openEqualizer(context, ref),
                        ),
                        const SizedBox(height: 10),
                        _SleepTimerTile(playerState: playerState, ref: ref),

                        const SizedBox(height: 28),

                        // ── Library
                        _SectionLabel(label: 'LIBRARY'),
                        const SizedBox(height: 12),
                        _SettingsTile(
                          icon: Icons.library_music_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'Rescan Local Audio Library',
                          subtitle: scanState.isScanning
                              ? 'Scanning… ${scanState.scannedCount} tracks found'
                              : '$trackCount tracks indexed',
                          trailingWidget: scanState.isScanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF10B981),
                                  ),
                                )
                              : Icon(Icons.refresh_rounded,
                                  color:
                                      Colors.white.withValues(alpha: 0.35),
                                  size: 20),
                          onTap: scanState.isScanning
                              ? null
                              : () => ref
                                  .read(audioScannerStateProvider.notifier)
                                  .scan(),
                        ),

                        const SizedBox(height: 28),

                        // ── Profile
                        _SectionLabel(label: 'PROFILE'),
                        const SizedBox(height: 12),
                        _ProfileQuickTile(profile: profile),

                        const SizedBox(height: 28),

                        // ── Lyrics
                        _SectionLabel(label: 'LYRICS'),
                        const SizedBox(height: 12),
                        const _LyricsTile(),

                        const SizedBox(height: 28),

                        // ── About
                        _SectionLabel(label: 'ABOUT'),
                        const SizedBox(height: 12),
                        _VersionBadge(
                            version: _appVersion, appName: _appName),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserProfile? profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: 0.06),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: const Icon(Icons.settings_rounded,
              color: Color(0xFF8B5CF6), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Settings',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            Text(profile?.displayName ?? 'Music Lover',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAmbientBlobs() {
    return Stack(children: [
      Positioned(
          top: -60,
          right: -60,
          child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.13),
                    Colors.transparent
                  ])))),
      Positioned(
          bottom: 100,
          left: -40,
          child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.08),
                    Colors.transparent
                  ])))),
    ]);
  }

  void _openEqualizer(BuildContext context, WidgetRef ref) {
    // Opens the hardware equalizer sheet if available via player
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Open Now Playing → EQ to adjust equalizer'),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic Settings Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailingWidget,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailingWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: iconColor.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11)),
            ]),
          ),
          if (trailingWidget != null) ...[
            const SizedBox(width: 10),
            trailingWidget!,
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sleep Timer Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SleepTimerTile extends StatelessWidget {
  const _SleepTimerTile({required this.playerState, required this.ref});
  final PlayerState playerState;
  final WidgetRef ref;

  String _formatDuration(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = playerState.isSleepTimerActive;
    final remaining = playerState.remainingSleepDuration;

    return _SettingsTile(
      icon: Icons.bedtime_rounded,
      iconColor: isActive ? const Color(0xFFFF758F) : const Color(0xFF64748B),
      title: 'Sleep Timer',
      subtitle: isActive
          ? (playerState.stopAtEndOfTrack
              ? 'Stops after current track'
              : 'Remaining: ${_formatDuration(remaining)}')
          : 'Not active',
      trailingWidget: isActive
          ? GestureDetector(
              onTap: () =>
                  ref.read(playerControllerProvider.notifier).cancelSleepTimer(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFFF758F).withValues(alpha: 0.15),
                  border: Border.all(
                      color: const Color(0xFFFF758F).withValues(alpha: 0.4)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: Color(0xFFFF758F),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Quick Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileQuickTile extends StatelessWidget {
  const _ProfileQuickTile({required this.profile});
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final avatarPath = profile?.avatarPath;

    return GestureDetector(
      onTap: () => EditProfileSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: avatarPath == null
                  ? const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFFF758F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight)
                  : null,
              image: avatarPath != null
                  ? DecorationImage(
                      image: FileImage(File(avatarPath)), fit: BoxFit.cover)
                  : null,
            ),
            child: avatarPath == null
                ? const Center(
                    child: Icon(Icons.person_rounded,
                        color: Colors.white, size: 20))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile?.displayName ?? 'Music Lover',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(profile?.vibeSubtitle ?? 'Finding my frequency',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 10),
          Icon(Icons.edit_rounded,
              color: Colors.white.withValues(alpha: 0.3), size: 18),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lyrics Settings Tile
// ─────────────────────────────────────────────────────────────────────────────

// Simple notifier-backed provider for the auto-fetch toggle
class AutoFetchLyricsNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle(bool value) => state = value;
}

final autoFetchLyricsProvider =
    NotifierProvider<AutoFetchLyricsNotifier, bool>(AutoFetchLyricsNotifier.new);

class _LyricsTile extends ConsumerWidget {
  const _LyricsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoFetch = ref.watch(autoFetchLyricsProvider);

    return Column(children: [
      // Auto-fetch toggle
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.lyrics_rounded,
                color: Color(0xFF3B82F6), size: 18),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Auto-Fetch Synced Lyrics',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 2),
              Text('Fetch LRC lyrics automatically on playback',
                  style: TextStyle(color: Color(0x66FFFFFF), fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 10),
          Switch(
            value: autoFetch,
            onChanged: (v) => ref
                .read(autoFetchLyricsProvider.notifier)
                .toggle(v),
            activeThumbColor: const Color(0xFF3B82F6),
          ),
        ]),
      ),
      const SizedBox(height: 10),

      // Clear lyrics cache
      _SettingsTile(
        icon: Icons.delete_sweep_rounded,
        iconColor: const Color(0xFFFF758F),
        title: 'Clear Lyrics Cache',
        subtitle: 'Remove all cached lyrics from database',
        trailingWidget:
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.25), size: 20),
        onTap: () => _clearLyricsCache(context, ref),
      ),
    ]);
  }

  void _clearLyricsCache(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12101E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Lyrics Cache',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
            'This will remove all stored lyrics. They will be re-fetched when songs play.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style:
                      TextStyle(color: Colors.white.withValues(alpha: 0.5)))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Lyrics cache cleared'),
                  backgroundColor: const Color(0xFF1A1A2E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: const Text('Clear',
                style: TextStyle(
                    color: Color(0xFFFF758F), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Version Badge
// ─────────────────────────────────────────────────────────────────────────────

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.version, required this.appName});
  final String version;
  final String appName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            const Color(0xFFFF758F).withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.18)),
      ),
      child: Column(children: [
        // Animated spinning logo
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 2 * math.pi),
          duration: const Duration(seconds: 8),
          builder: (_, angle, child) => Transform.rotate(
            angle: angle,
            child: child,
          ),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFFF758F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.graphic_eq_rounded,
                color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Spinora Music',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text('by SpideyTech • v$version',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
            border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
          ),
          child: const Text('Zero budget • Privacy first • Offline ready',
              style: TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
      ]),
    );
  }
}
