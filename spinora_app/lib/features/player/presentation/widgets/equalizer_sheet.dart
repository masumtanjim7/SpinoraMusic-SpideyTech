import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/player_controller.dart';
import '../../domain/equalizer_state.dart';

// ---------------------------------------------------------------------------
// Equalizer Modal Launcher Helper
// ---------------------------------------------------------------------------

/// Opens the dark glassmorphic Built-In Hardware Audio Equalizer & Bass Enhancer sheet.
void showEqualizerSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const EqualizerSheet(),
  );
}

// ---------------------------------------------------------------------------
// Futuristic Dark Glassmorphic Equalizer Bottom Sheet
// ---------------------------------------------------------------------------

class EqualizerSheet extends ConsumerWidget {
  const EqualizerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final tt = Theme.of(context).textTheme;
    final isEqEnabled = playerState.equalizerEnabled;
    final isLight = context.isLight;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.96)
            : const Color(0xFF0A0A12).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.75),
            blurRadius: 36,
            spreadRadius: 4,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top Header: Title, Subtitle, Neon Switch, Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cyanAccent.withValues(
                            alpha: isEqEnabled ? 0.2 : (isLight ? 0.08 : 0.08),
                          ),
                          border: Border.all(
                            color: isEqEnabled
                                ? AppColors.cyanAccent.withValues(alpha: 0.6)
                                : (isLight
                                      ? Colors.black.withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.1)),
                          ),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: isEqEnabled
                              ? AppColors.cyanAccent
                              : context.secondaryText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AUDIO EQUALIZER',
                              style: tt.titleMedium?.copyWith(
                                color: context.primaryText,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEqEnabled
                                  ? 'Active • ${playerState.equalizerPreset.displayName}'
                                  : 'Disabled • Hardware Bypass',
                              style: tt.bodySmall?.copyWith(
                                color: isEqEnabled
                                    ? (isLight
                                          ? const Color(0xFF0D9488)
                                          : AppColors.cyanAccent)
                                    : context.secondaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Active Neon Switch
                Switch(
                  value: isEqEnabled,
                  onChanged: (val) => controller.setEqualizerEnabled(val),
                  activeThumbColor: AppColors.cyanAccent,
                  activeTrackColor: AppColors.cyanAccent.withValues(
                    alpha: 0.35,
                  ),
                  inactiveThumbColor: isLight ? Colors.black38 : Colors.white38,
                  inactiveTrackColor: isLight
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.08),
                ),

                // Dismiss Button
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: context.secondaryText),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 1: Horizontal Scrollable Preset Chips
            Text(
              'PRESETS',
              style: tt.bodySmall?.copyWith(
                color: context.secondaryText,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: EqualizerPreset.values.map((preset) {
                  final isSelected = playerState.equalizerPreset == preset;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        controller.applyPreset(preset);
                        if (!isEqEnabled) {
                          controller.setEqualizerEnabled(true);
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.cyanAccent.withValues(
                                  alpha: isLight ? 0.16 : 0.18,
                                )
                              : (isLight
                                    ? Colors.black.withValues(alpha: 0.03)
                                    : Colors.white.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.cyanAccent.withValues(alpha: 0.7)
                                : (isLight
                                      ? Colors.black.withValues(alpha: 0.06)
                                      : Colors.white.withValues(alpha: 0.1)),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.cyanAccent.withValues(
                                      alpha: isLight ? 0.2 : 0.25,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.cyanAccent,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              preset.displayName,
                              style: TextStyle(
                                color: isSelected
                                    ? (isLight
                                          ? const Color(0xFF0D9488)
                                          : AppColors.cyanAccent)
                                    : context.primaryText,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Hardware Frequency Band Vertical Sliders Card
            Container(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isEqEnabled
                      ? AppColors.cyanAccent.withValues(alpha: 0.2)
                      : (isLight
                            ? Colors.black.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.equalizer_rounded,
                              size: 16,
                              color: isEqEnabled
                                  ? AppColors.cyanAccent
                                  : context.secondaryText,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '5-BAND GRAPHIC EQUALIZER',
                                style: tt.bodySmall?.copyWith(
                                  color: context.primaryText,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '±15 dB',
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Vertical Band Sliders in a balanced Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: playerState.equalizerBands.map((band) {
                      final gainValue = band.gain.clamp(
                        band.minDecibels,
                        band.maxDecibels,
                      );
                      final isNonZero = gainValue.abs() > 0.05;

                      return Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Live dB Readout
                            Text(
                              band.formattedGain,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isEqEnabled
                                    ? (isNonZero
                                          ? (isLight
                                                ? const Color(0xFF0D9488)
                                                : AppColors.cyanAccent)
                                          : context.primaryText)
                                    : context.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Vertical Rotated Slider
                            SizedBox(
                              height: 140,
                              child: RotatedBox(
                                quarterTurns:
                                    3, // Rotate 270 deg: down=min, up=max
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3.5,
                                    activeTrackColor: isEqEnabled
                                        ? AppColors.cyanAccent
                                        : (isLight
                                              ? Colors.black26
                                              : Colors.white24),
                                    inactiveTrackColor: isLight
                                        ? Colors.black.withValues(alpha: 0.08)
                                        : Colors.white.withValues(alpha: 0.08),
                                    thumbColor: isEqEnabled
                                        ? (isNonZero
                                              ? AppColors.cyanAccent
                                              : (isLight
                                                    ? context.primaryText
                                                    : Colors.white))
                                        : (isLight
                                              ? Colors.black26
                                              : Colors.white38),
                                    overlayColor: AppColors.cyanAccent
                                        .withValues(alpha: 0.15),
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                      elevation: 3,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14,
                                    ),
                                  ),
                                  child: Slider(
                                    min: band.minDecibels,
                                    max: band.maxDecibels,
                                    value: gainValue,
                                    onChanged: isEqEnabled
                                        ? (newGain) {
                                            controller.setBandGain(
                                              band.index,
                                              newGain,
                                            );
                                          }
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Hardware Frequency Label
                            Text(
                              band.formattedFrequency,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: isEqEnabled
                                    ? context.primaryText
                                    : context.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Hardware Bass & Loudness Boost (AndroidLoudnessEnhancer)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: playerState.loudnessGain > 0
                      ? AppColors.purpleAccent.withValues(alpha: 0.35)
                      : (isLight
                            ? Colors.black.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.purpleAccent.withValues(
                                  alpha: playerState.loudnessGain > 0
                                      ? (isLight ? 0.16 : 0.2)
                                      : (isLight ? 0.06 : 0.08),
                                ),
                              ),
                              child: Icon(
                                Icons.surround_sound_rounded,
                                size: 18,
                                color: playerState.loudnessGain > 0
                                    ? AppColors.purpleAccent
                                    : context.secondaryText,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'BASS & LOUDNESS BOOST',
                                    style: tt.bodySmall?.copyWith(
                                      color: context.primaryText,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Native Hardware LoudnessEnhancer',
                                    style: TextStyle(
                                      color: context.secondaryText,
                                      fontSize: 9.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Live Gain Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: playerState.loudnessGain > 0
                              ? AppColors.purpleAccent.withValues(
                                  alpha: isLight ? 0.14 : 0.2,
                                )
                              : (isLight
                                    ? Colors.black.withValues(alpha: 0.04)
                                    : Colors.white.withValues(alpha: 0.06)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: playerState.loudnessGain > 0
                                ? AppColors.purpleAccent.withValues(alpha: 0.6)
                                : (isLight
                                      ? Colors.black.withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.1)),
                          ),
                        ),
                        child: Text(
                          playerState.loudnessGain > 0
                              ? '+${playerState.loudnessGain.toStringAsFixed(1)} dB'
                              : '0 dB',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: playerState.loudnessGain > 0
                                ? AppColors.purpleAccent
                                : context.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Horizontal Loudness Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: AppColors.purpleAccent,
                      inactiveTrackColor: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.08),
                      thumbColor: AppColors.purpleAccent,
                      overlayColor: AppColors.purpleAccent.withValues(
                        alpha: 0.15,
                      ),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                        elevation: 3,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: 10.0,
                      divisions: 20,
                      value: playerState.loudnessGain.clamp(0.0, 10.0),
                      onChanged: (val) => controller.setLoudnessGain(val),
                    ),
                  ),

                  // Range boundary labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0 dB (Bypass)',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: context.secondaryText,
                        ),
                      ),
                      Text(
                        '+5.0 dB',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: context.secondaryText,
                        ),
                      ),
                      Text(
                        '+10.0 dB (Max Boost)',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.purpleAccent.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bottom Reset to Flat Quick Action
            Center(
              child: TextButton.icon(
                onPressed: () {
                  controller.applyPreset(EqualizerPreset.flat);
                  controller.setLoudnessGain(0.0);
                },
                icon: Icon(
                  Icons.restart_alt_rounded,
                  size: 16,
                  color: context.secondaryText,
                ),
                label: Text(
                  'Reset Equalizer to Flat',
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
