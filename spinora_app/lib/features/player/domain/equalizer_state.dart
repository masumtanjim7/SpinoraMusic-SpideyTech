import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Equalizer Band State Model
// ---------------------------------------------------------------------------

/// Immutable state representing a single frequency band of the hardware equalizer.
@immutable
class EqualizerBandState {
  const EqualizerBandState({
    required this.index,
    required this.centerFrequency,
    required this.gain,
    this.minDecibels = -15.0,
    this.maxDecibels = 15.0,
  });

  /// 0-indexed band position.
  final int index;

  /// Center frequency in Hertz (Hz), e.g., 60.0, 230.0, 910.0, 3600.0, 14000.0.
  final double centerFrequency;

  /// Gain in decibels (dB), e.g., -15.0 to +15.0 dB.
  final double gain;

  /// Minimum gain supported by the hardware band (typically -15.0 to -10.0 dB).
  final double minDecibels;

  /// Maximum gain supported by the hardware band (typically +10.0 to +15.0 dB).
  final double maxDecibels;

  /// Clean human-readable frequency label, e.g., "60Hz", "230Hz", "910Hz", "3.6kHz", "14kHz".
  String get formattedFrequency {
    if (centerFrequency >= 1000) {
      final khz = centerFrequency / 1000;
      if (khz == khz.roundToDouble()) {
        return '${khz.toInt()}kHz';
      }
      return '${khz.toStringAsFixed(1)}kHz';
    }
    return '${centerFrequency.round()}Hz';
  }

  /// Clean formatted gain string with sign, e.g., "+4.5 dB", "0.0 dB", "-2.0 dB".
  String get formattedGain {
    final prefix = gain > 0 ? '+' : '';
    return '$prefix${gain.toStringAsFixed(1)} dB';
  }

  EqualizerBandState copyWith({
    int? index,
    double? centerFrequency,
    double? gain,
    double? minDecibels,
    double? maxDecibels,
  }) {
    return EqualizerBandState(
      index: index ?? this.index,
      centerFrequency: centerFrequency ?? this.centerFrequency,
      gain: gain ?? this.gain,
      minDecibels: minDecibels ?? this.minDecibels,
      maxDecibels: maxDecibels ?? this.maxDecibels,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EqualizerBandState &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          centerFrequency == other.centerFrequency &&
          gain == other.gain &&
          minDecibels == other.minDecibels &&
          maxDecibels == other.maxDecibels;

  @override
  int get hashCode =>
      Object.hash(index, centerFrequency, gain, minDecibels, maxDecibels);

  @override
  String toString() =>
      'EqualizerBandState(index: $index, freq: $formattedFrequency, gain: $formattedGain)';
}

// ---------------------------------------------------------------------------
// Equalizer Presets
// ---------------------------------------------------------------------------

/// Standard built-in equalizer curve presets.
enum EqualizerPreset {
  flat(displayName: 'Flat', gains: [0.0, 0.0, 0.0, 0.0, 0.0]),
  bassBoost(displayName: 'Bass Boost', gains: [6.0, 4.5, 1.5, 0.0, 0.0]),
  pop(displayName: 'Pop', gains: [-1.5, 2.0, 4.5, 3.0, -1.0]),
  rock(displayName: 'Rock', gains: [5.0, 3.0, -1.0, 3.5, 5.5]),
  vocal(displayName: 'Vocal', gains: [-3.0, 1.0, 5.0, 4.0, 0.5]),
  custom(displayName: 'Custom', gains: []);

  const EqualizerPreset({required this.displayName, required this.gains});

  final String displayName;
  final List<double> gains;
}

// ---------------------------------------------------------------------------
// Default 5-Band Hardware Preset Fallback
// ---------------------------------------------------------------------------

/// Default 5-band frequency layout for tests, previews, and baseline hardware.
const List<EqualizerBandState> defaultEqualizerBands = [
  EqualizerBandState(
    index: 0,
    centerFrequency: 60.0,
    gain: 0.0,
    minDecibels: -15.0,
    maxDecibels: 15.0,
  ),
  EqualizerBandState(
    index: 1,
    centerFrequency: 230.0,
    gain: 0.0,
    minDecibels: -15.0,
    maxDecibels: 15.0,
  ),
  EqualizerBandState(
    index: 2,
    centerFrequency: 910.0,
    gain: 0.0,
    minDecibels: -15.0,
    maxDecibels: 15.0,
  ),
  EqualizerBandState(
    index: 3,
    centerFrequency: 3600.0,
    gain: 0.0,
    minDecibels: -15.0,
    maxDecibels: 15.0,
  ),
  EqualizerBandState(
    index: 4,
    centerFrequency: 14000.0,
    gain: 0.0,
    minDecibels: -15.0,
    maxDecibels: 15.0,
  ),
];

/// Computes or interpolates target gains for any band count from a preset curve.
List<double> calculatePresetGainsForBands(
  EqualizerPreset preset,
  List<EqualizerBandState> bands,
) {
  if (preset == EqualizerPreset.custom || preset.gains.isEmpty) {
    return bands.map((b) => b.gain).toList();
  }

  // Exact 5-band match
  if (bands.length == preset.gains.length) {
    return List<double>.from(preset.gains);
  }

  // Linear interpolation across arbitrary hardware band counts
  final result = <double>[];
  for (int i = 0; i < bands.length; i++) {
    final t = i / (bands.length - 1);
    final mappedIndex = t * (preset.gains.length - 1);
    final lower = mappedIndex.floor();
    final upper = mappedIndex.ceil();
    if (lower == upper) {
      result.add(preset.gains[lower]);
    } else {
      final fraction = mappedIndex - lower;
      result.add(
        preset.gains[lower] +
            (preset.gains[upper] - preset.gains[lower]) * fraction,
      );
    }
  }
  return result;
}
