import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/library/data/audio_scanner_service.dart';
import '../../../features/player/application/player_controller.dart';
import '../../../features/profile/application/user_profile_provider.dart';
import '../../../features/profile/presentation/edit_profile_sheet.dart';
import '../application/audio_settings_provider.dart';
import '../application/backup_service.dart';
import '../application/theme_provider.dart';
import '../../../core/widgets/lucid_cascade_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Settings Screen — Lucid Glass Dashboard
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.showMiniPlayer = true});

  final bool showMiniPlayer;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tick = ref.watch(tabEntryTicksProvider.select((t) => t[4]));

    return Scaffold(
      backgroundColor: showMiniPlayer
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.transparent,
      body: Stack(
        children: [
          // Ambient blobs
          _buildAmbientBlobs(isDark),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                LucidCascadeItem(
                  index: 0,
                  triggerKey: tick,
                  child: _buildHeader(context, profile, isDark),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      MediaQuery.of(context).padding.bottom +
                          (playerState.hasTrack ? 150.0 : 100.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Appearance
                        LucidCascadeItem(
                          index: 1,
                          triggerKey: tick,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel(label: 'APPEARANCE'),
                              const SizedBox(height: 12),
                              const _AppearanceTile(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Audio Playback & Crossfade
                        LucidCascadeItem(
                          index: 2,
                          triggerKey: tick,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel(
                                label: 'AUDIO PLAYBACK & CROSSFADE',
                              ),
                              const SizedBox(height: 12),
                              const _CrossfadeCard(),
                              const SizedBox(height: 10),
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
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          color: const Color(0xFF8B5CF6)
                                              .withValues(alpha: 0.2),
                                          border: Border.all(
                                            color: const Color(0xFF8B5CF6)
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: const Text(
                                          'ON',
                                          style: TextStyle(
                                            color: Color(0xFF8B5CF6),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      )
                                    : null,
                                onTap: () => _openEqualizer(context, ref),
                              ),
                              const SizedBox(height: 10),
                              _SleepTimerTile(
                                playerState: playerState,
                                ref: ref,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Library
                        LucidCascadeItem(
                          index: 3,
                          triggerKey: tick,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel(label: 'LIBRARY'),
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
                                    : Icon(
                                        Icons.refresh_rounded,
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.35,
                                              )
                                            : const Color(0xFF5C6275),
                                        size: 20,
                                      ),
                                onTap: scanState.isScanning
                                    ? null
                                    : () => ref
                                          .read(
                                            audioScannerStateProvider.notifier,
                                          )
                                          .scan(),
                              ),

                              const SizedBox(height: 28),

                              // ── Profile
                              const _SectionLabel(label: 'PROFILE'),
                              const SizedBox(height: 12),
                              _ProfileQuickTile(profile: profile),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Lyrics
                        LucidCascadeItem(
                          index: 4,
                          triggerKey: tick,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel(label: 'LYRICS'),
                              const SizedBox(height: 12),
                              const _LyricsTile(),

                              const SizedBox(height: 28),

                              // ── Data & Backup
                              const _SectionLabel(label: 'DATA & BACKUP'),
                              const SizedBox(height: 12),
                              const _BackupSection(),

                              const SizedBox(height: 28),

                              // ── About
                              const _SectionLabel(label: 'ABOUT'),
                              const SizedBox(height: 12),
                              _VersionBadge(
                                version: _appVersion,
                                appName: _appName,
                              ),
                            ],
                          ),
                        ),

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

  Widget _buildHeader(BuildContext context, UserProfile? profile, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.85),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : Colors.white.withValues(alpha: 0.95),
              ),
              boxShadow: isDark ? null : AppTheme.lightCardShadow,
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Color(0xFF8B5CF6),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F111A),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  profile?.displayName ?? 'Music Lover',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.45)
                        : const Color(0xFF5C6275),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBlobs(bool isDark) {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        const Color(0xFF8B5CF6).withValues(alpha: 0.13),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFDDD6FE).withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        const Color(0xFF10B981).withValues(alpha: 0.08),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFFDE8EF).withValues(alpha: 0.40),
                        Colors.transparent,
                      ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openEqualizer(BuildContext context, WidgetRef ref) {
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
// Appearance Tile (Dark Mode vs Light Mode Apple Lucid Glass)
// ─────────────────────────────────────────────────────────────────────────────

class _AppearanceTile extends ConsumerWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.95),
          width: isDark ? 1.0 : 1.2,
        ),
        boxShadow: isDark ? null : AppTheme.lightCardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: isDark
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                      : const Color(0xFFE63946).withValues(alpha: 0.15),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFFE63946),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDark ? 'Dark Mode' : 'Light Mode (Apple Lucid Glass)',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F111A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDark
                          ? 'Deep cosmos base & neon accents'
                          : 'Pearl-white acrylic, frosted glass & slate',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : const Color(0xFF5C6275),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: isDark,
                onChanged: (val) {
                  ref
                      .read(themeModeProvider.notifier)
                      .setTheme(val ? ThemeMode.dark : ThemeMode.light);
                },
                activeThumbColor: const Color(0xFF8B5CF6),
                inactiveThumbColor: const Color(0xFFE63946),
                inactiveTrackColor: const Color(0xFFE63946)
                    .withValues(alpha: 0.25),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Interactive Segmented Option Chips: [🌙 Dark Cosmos] [☀️ Light Lucid Glass]
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setTheme(ThemeMode.dark),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isDark
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: 0.04),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.nightlight_round,
                          size: 14,
                          color: isDark
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF5C6275),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Dark Cosmos',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isDark
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF5C6275),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setTheme(ThemeMode.light),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: !isDark
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: !isDark
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.45)
                            : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wb_sunny_rounded,
                          size: 14,
                          color: !isDark
                              ? const Color(0xFF7C3AED)
                              : Colors.white60,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Lucid Light',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: !isDark
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: !isDark
                                ? const Color(0xFF0F111A)
                                : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio Crossfade Card
// ─────────────────────────────────────────────────────────────────────────────

class _CrossfadeCard extends ConsumerWidget {
  const _CrossfadeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioSettings = ref.watch(audioSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = audioSettings.crossfadeEnabled;
    final duration = audioSettings.crossfadeDurationSeconds;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.95),
          width: isDark ? 1.0 : 1.2,
        ),
        boxShadow: isDark ? null : AppTheme.lightCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF00E5FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable Audio Crossfade',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F111A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled
                          ? 'DJ-style smooth fade transitions (${duration.toStringAsFixed(1)}s)'
                          : 'Seamlessly blend consecutive tracks',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : const Color(0xFF5C6275),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: enabled,
                onChanged: (val) {
                  ref
                      .read(audioSettingsProvider.notifier)
                      .setCrossfadeEnabled(val);
                },
                activeThumbColor: const Color(0xFF00E5FF),
                activeTrackColor: const Color(0xFF00E5FF)
                    .withValues(alpha: 0.35),
                inactiveThumbColor: isDark
                    ? Colors.white38
                    : const Color(0xFF94A3B8),
                inactiveTrackColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE2E8F0),
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Crossfade Duration (1s - 8s)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F111A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    '${duration.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF00E5FF),
                inactiveTrackColor: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE2E8F0),
                thumbColor: const Color(0xFF00E5FF),
                overlayColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                trackHeight: 3.5,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7.0,
                ),
              ),
              child: Slider(
                value: duration.clamp(1.0, 8.0),
                min: 1.0,
                max: 8.0,
                divisions: 14,
                onChanged: (val) {
                  ref
                      .read(audioSettingsProvider.notifier)
                      .setCrossfadeDuration(val);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '1.0s (Subtle)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : const Color(0xFF8E95A8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    '8.0s (Club DJ)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : const Color(0xFF8E95A8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        color: isDark
            ? Colors.white.withValues(alpha: 0.35)
            : const Color(0xFF5C6275).withValues(alpha: 0.8),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.85),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.95),
            width: isDark ? 1.0 : 1.2,
          ),
          boxShadow: isDark ? null : AppTheme.lightCardShadow,
        ),
        child: Row(
          children: [
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F111A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : const Color(0xFF5C6275),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingWidget != null) ...[
              const SizedBox(width: 10),
              trailingWidget!,
            ],
          ],
        ),
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
    if (d == null) return '0:00';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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
              onTap: () => ref
                  .read(playerControllerProvider.notifier)
                  .cancelSleepTimer(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFFF758F).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFFFF758F).withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFFFF758F),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => EditProfileSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.85),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.95),
            width: isDark ? 1.0 : 1.2,
          ),
          boxShadow: isDark ? null : AppTheme.lightCardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: avatarPath == null
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFFF758F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                image: avatarPath != null
                    ? DecorationImage(
                        image: FileImage(File(avatarPath)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarPath == null
                  ? const Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.displayName ?? 'Music Lover',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F111A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile?.vibeSubtitle ?? 'Finding my frequency',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : const Color(0xFF5C6275),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.edit_rounded,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : const Color(0xFF5C6275),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lyrics Settings Tile
// ─────────────────────────────────────────────────────────────────────────────

class AutoFetchLyricsNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle(bool value) => state = value;
}

final autoFetchLyricsProvider = NotifierProvider<AutoFetchLyricsNotifier, bool>(
  AutoFetchLyricsNotifier.new,
);

class _LyricsTile extends ConsumerWidget {
  const _LyricsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoFetch = ref.watch(autoFetchLyricsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Auto-fetch toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.85),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.95),
              width: isDark ? 1.0 : 1.2,
            ),
            boxShadow: isDark ? null : AppTheme.lightCardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.lyrics_rounded,
                  color: Color(0xFF3B82F6),
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-Fetch Synced Lyrics',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F111A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fetch LRC lyrics automatically on playback',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0x66FFFFFF)
                            : const Color(0xFF5C6275),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: autoFetch,
                onChanged: (v) =>
                    ref.read(autoFetchLyricsProvider.notifier).toggle(v),
                activeThumbColor: const Color(0xFF3B82F6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Clear lyrics cache
        _SettingsTile(
          icon: Icons.delete_sweep_rounded,
          iconColor: const Color(0xFFFF758F),
          title: 'Clear Lyrics Cache',
          subtitle: 'Remove all cached lyrics from database',
          trailingWidget: Icon(
            Icons.chevron_right_rounded,
            color: isDark
                ? Colors.white.withValues(alpha: 0.25)
                : const Color(0xFF5C6275),
            size: 20,
          ),
          onTap: () => _clearLyricsCache(context, ref),
        ),
      ],
    );
  }

  void _clearLyricsCache(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF12101E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear Lyrics Cache',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F111A),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will remove all stored lyrics. They will be re-fetched when songs play.',
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.6)
                : const Color(0xFF5C6275),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : const Color(0xFF5C6275),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Lyrics cache cleared'),
                  backgroundColor: const Color(0xFF1A1A2E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: const Text(
              'Clear',
              style: TextStyle(
                color: Color(0xFFFF758F),
                fontWeight: FontWeight.w700,
              ),
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: isDark
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.95),
          width: isDark ? 1.0 : 1.2,
        ),
        boxShadow: isDark ? null : AppTheme.lightCardShadow,
      ),
      child: Column(
        children: [
          // Animated spinning logo
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 2 * math.pi),
            duration: const Duration(seconds: 8),
            builder: (_, angle, child) =>
                Transform.rotate(angle: angle, child: child),
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
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Spinora Music',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F111A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'by SpideyTech • v$version',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : const Color(0xFF5C6275),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'Zero budget • Privacy first • Offline ready',
              style: TextStyle(
                color: Color(0xFF8B5CF6),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data & Backup Section
// ─────────────────────────────────────────────────────────────────────────────

class _BackupSection extends ConsumerStatefulWidget {
  const _BackupSection();

  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  bool _isExporting = false;

  Future<void> _handleExport(BuildContext context) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final backupService = ref.read(backupServiceProvider);
      final result = await backupService.exportData();
      if (!mounted) return;
      setState(() => _isExporting = false);

      if (context.mounted) {
        _BackupSuccessSheet.show(context, ref, result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export backup: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _handleRestore(BuildContext context) {
    _RestoreBackupSheet.show(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _SettingsTile(
          icon: Icons.cloud_upload_rounded,
          iconColor: const Color(0xFF00E5FF),
          title: 'Export Backup',
          subtitle: 'Generate & share spinora_backup_<date>.spinora',
          trailingWidget: _isExporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00E5FF),
                  ),
                )
              : Icon(
                  Icons.ios_share_rounded,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : const Color(0xFF5C6275),
                  size: 20,
                ),
          onTap: _isExporting ? null : () => _handleExport(context),
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.settings_backup_restore_rounded,
          iconColor: const Color(0xFF8B5CF6),
          title: 'Restore Backup',
          subtitle: 'Pick a .spinora file to restore playlists & favorites',
          trailingWidget: Icon(
            Icons.chevron_right_rounded,
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : const Color(0xFF5C6275),
            size: 20,
          ),
          onTap: () => _handleRestore(context),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Backup Export Success Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _BackupSuccessSheet extends StatelessWidget {
  const _BackupSuccessSheet({required this.result, required this.ref});
  final BackupExportResult result;
  final WidgetRef ref;

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    BackupExportResult result,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BackupSuccessSheet(result: result, ref: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Glowing Check Icon
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.cloud_done_rounded,
              color: Color(0xFF00E5FF),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Backup Created Successfully',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F111A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  result.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF5C6275),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                ),
                child: Text(
                  result.formattedSize,
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stats badges row
          Row(
            children: [
              Expanded(
                child: _BackupStatBadge(
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFFF758F),
                  label: '${result.favoritesCount}',
                  subtitle: 'Favorites',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BackupStatBadge(
                  icon: Icons.playlist_play_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  label: '${result.playlistsCount}',
                  subtitle: 'Playlists',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BackupStatBadge(
                  icon: Icons.tune_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: '${result.customMetadataCount}',
                  subtitle: 'Edits',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Informational note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF1F5F9),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_special_rounded,
                  size: 18,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved to App Documents and Downloads folder. You can export or send this file to any device.',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.55)
                          : const Color(0xFF475569),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.filePath));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('File path copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF1A1A2E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Path'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.white
                        : const Color(0xFF0F111A),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref
                        .read(backupServiceProvider)
                        .shareBackupFile(result.filePath);
                  },
                  icon: const Icon(Icons.share_rounded, size: 17),
                  label: const Text('Share Backup File'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF0A0E21),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Restore Backup Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _RestoreBackupSheet extends ConsumerStatefulWidget {
  const _RestoreBackupSheet();

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RestoreBackupSheet(),
    );
  }

  @override
  ConsumerState<_RestoreBackupSheet> createState() =>
      _RestoreBackupSheetState();
}

class _RestoreBackupSheetState extends ConsumerState<_RestoreBackupSheet> {
  final _textController = TextEditingController();
  bool _isLoading = true;
  bool _isRestoring = false;
  bool _isManualInput = false;
  List<BackupFileInfo> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final list = await ref
          .read(backupServiceProvider)
          .getAvailableLocalBackups();
      if (mounted) {
        setState(() {
          _backups = list;
          _isLoading = false;
          if (list.isEmpty) {
            _isManualInput = true;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isManualInput = true;
        });
      }
    }
  }

  Future<void> _confirmAndRestore({
    File? file,
    String? rawJson,
    String? title,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.settings_backup_restore_rounded,
                color: Color(0xFF8B5CF6),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Restore Backup?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'This will restore favorites, playlists, and settings from ${title ?? 'this backup'}.\n\nExisting library songs will not be deleted.',
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirm Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);

    try {
      final jsonStr = file != null
          ? await file.readAsString()
          : (rawJson ?? _textController.text.trim());

      if (jsonStr.isEmpty) {
        throw const FormatException('Empty backup data provided.');
      }

      final summary = await ref.read(backupServiceProvider).importData(jsonStr);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restore complete: ${summary.restoredFavorites} favorites, ${summary.restoredPlaylists} playlists restored.',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore backup: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.settings_backup_restore_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restore Backup',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F111A),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _isManualInput
                          ? 'Paste raw JSON or enter file path'
                          : 'Select a discovered .spinora backup file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : const Color(0xFF5C6275),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _isManualInput = !_isManualInput);
                },
                tooltip: _isManualInput
                    ? 'Show local files'
                    : 'Paste JSON/path',
                icon: Icon(
                  _isManualInput
                      ? Icons.folder_open_rounded
                      : Icons.text_snippet_rounded,
                  color: const Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isRestoring)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF8B5CF6),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Restoring playlists & favorites…',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_isManualInput) ...[
            Text(
              'Paste Backup Payload or File Path',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F111A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 5,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F111A),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: '{\n  "version": 1,\n  "appName": "Spinora Music",\n  ...\n} or /path/to/backup.spinora',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF8B5CF6),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null && mounted) {
                      _textController.text = data!.text!;
                    }
                  },
                  icon: const Icon(Icons.paste_rounded, size: 15),
                  label: const Text('Paste Clipboard'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    final text = _textController.text.trim();
                    if (text.isEmpty) return;
                    if (text.startsWith('/') || text.contains('.spinora')) {
                      final f = File(text);
                      if (f.existsSync()) {
                        _confirmAndRestore(
                          file: f,
                          title: f.uri.pathSegments.last,
                        );
                        return;
                      }
                    }
                    _confirmAndRestore(rawJson: text, title: 'pasted JSON');
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Restore Data'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_isLoading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ),
          ] else if (_backups.isEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_off_rounded,
                      size: 40,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No .spinora backups found in Downloads or Documents',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => setState(() => _isManualInput = true),
                      icon: const Icon(Icons.text_snippet_rounded, size: 16),
                      label: const Text('Paste JSON or File Path'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _backups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _backups[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.white,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.15),
                          ),
                          child: const Icon(
                            Icons.description_rounded,
                            color: Color(0xFF8B5CF6),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F111A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.formattedSize} • ${item.formattedDate}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.45)
                                      : const Color(0xFF5C6275),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _confirmAndRestore(
                            file: item.file,
                            title: item.fileName,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.2),
                            foregroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                color: Color(0xFF8B5CF6),
                                width: 1,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Restore',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Backup Stat Badge
// ─────────────────────────────────────────────────────────────────────────────

class _BackupStatBadge extends StatelessWidget {
  const _BackupStatBadge({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F111A),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.45)
                  : const Color(0xFF64748B),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
