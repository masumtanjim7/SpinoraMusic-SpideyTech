import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/audio/track.dart';
import 'package:spinora/features/player/application/player_controller.dart';
import 'package:spinora/features/player/domain/equalizer_state.dart';
import 'package:spinora/features/player/presentation/widgets/audio_tools_sheets.dart';

void main() {
  group('EqualizerBandState and Presets logic tests', () {
    test('frequency formatting handles Hz and kHz correctly', () {
      const band60 = EqualizerBandState(
        index: 0,
        centerFrequency: 60.0,
        gain: 0.0,
      );
      expect(band60.formattedFrequency, '60Hz');

      const band230 = EqualizerBandState(
        index: 1,
        centerFrequency: 230.0,
        gain: 0.0,
      );
      expect(band230.formattedFrequency, '230Hz');

      const band910 = EqualizerBandState(
        index: 2,
        centerFrequency: 910.0,
        gain: 0.0,
      );
      expect(band910.formattedFrequency, '910Hz');

      const band3600 = EqualizerBandState(
        index: 3,
        centerFrequency: 3600.0,
        gain: 0.0,
      );
      expect(band3600.formattedFrequency, '3.6kHz');

      const band14000 = EqualizerBandState(
        index: 4,
        centerFrequency: 14000.0,
        gain: 0.0,
      );
      expect(band14000.formattedFrequency, '14kHz');
    });

    test('gain formatting displays sign and unit cleanly', () {
      const positiveGain = EqualizerBandState(
        index: 0,
        centerFrequency: 60.0,
        gain: 4.5,
      );
      expect(positiveGain.formattedGain, '+4.5 dB');

      const zeroGain = EqualizerBandState(
        index: 0,
        centerFrequency: 60.0,
        gain: 0.0,
      );
      expect(zeroGain.formattedGain, '0.0 dB');

      const negativeGain = EqualizerBandState(
        index: 0,
        centerFrequency: 60.0,
        gain: -3.0,
      );
      expect(negativeGain.formattedGain, '-3.0 dB');
    });

    test('calculatePresetGainsForBands returns exact gains for 5 bands', () {
      final flatGains = calculatePresetGainsForBands(
        EqualizerPreset.flat,
        defaultEqualizerBands,
      );
      expect(flatGains, [0.0, 0.0, 0.0, 0.0, 0.0]);

      final bassGains = calculatePresetGainsForBands(
        EqualizerPreset.bassBoost,
        defaultEqualizerBands,
      );
      expect(bassGains, EqualizerPreset.bassBoost.gains);

      final rockGains = calculatePresetGainsForBands(
        EqualizerPreset.rock,
        defaultEqualizerBands,
      );
      expect(rockGains, EqualizerPreset.rock.gains);
    });

    test('calculatePresetGainsForBands interpolates for arbitrary band counts', () {
      final arbitraryBands = List.generate(
        3,
        (i) => EqualizerBandState(
          index: i,
          centerFrequency: 100.0 * (i + 1),
          gain: 0.0,
        ),
      );
      final interpolated = calculatePresetGainsForBands(
        EqualizerPreset.rock,
        arbitraryBands,
      );
      expect(interpolated.length, 3);
      expect(interpolated.first, EqualizerPreset.rock.gains.first);
      expect(interpolated.last, EqualizerPreset.rock.gains.last);
    });
  });

  group('PlayerState Equalizer fields tests', () {
    test('default PlayerState has equalizer disabled with default bands', () {
      const state = PlayerState();
      expect(state.equalizerEnabled, false);
      expect(state.loudnessEnhancerEnabled, false);
      expect(state.loudnessGain, 0.0);
      expect(state.equalizerPreset, EqualizerPreset.flat);
      expect(state.equalizerBands.length, 5);
      expect(state.equalizerBands[0].formattedFrequency, '60Hz');
      expect(state.equalizerBands[4].formattedFrequency, '14kHz');
    });

    test('copyWith updates equalizer properties accurately', () {
      const state = PlayerState();
      final updated = state.copyWith(
        equalizerEnabled: true,
        loudnessEnhancerEnabled: true,
        loudnessGain: 4.0,
        equalizerPreset: EqualizerPreset.bassBoost,
      );

      expect(updated.equalizerEnabled, true);
      expect(updated.loudnessEnhancerEnabled, true);
      expect(updated.loudnessGain, 4.0);
      expect(updated.equalizerPreset, EqualizerPreset.bassBoost);
    });
  });

  group('Equalizer Widgets tests', () {
    testWidgets('EqualizerSheet renders header, presets, 5 bands, and loudness slider',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showEqualizerSheet(context),
                  child: const Text('Open EQ'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap to open sheet
      await tester.tap(find.text('Open EQ'));
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('AUDIO EQUALIZER'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Verify Preset chips
      expect(find.text('Flat'), findsOneWidget);
      expect(find.text('Bass Boost'), findsOneWidget);
      expect(find.text('Pop'), findsOneWidget);
      expect(find.text('Rock'), findsOneWidget);
      expect(find.text('Vocal'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      // Verify 5 Frequency Band Labels
      expect(find.text('60Hz'), findsOneWidget);
      expect(find.text('230Hz'), findsOneWidget);
      expect(find.text('910Hz'), findsOneWidget);
      expect(find.text('3.6kHz'), findsOneWidget);
      expect(find.text('14kHz'), findsOneWidget);

      // Verify Loudness Section
      expect(find.text('BASS & LOUDNESS BOOST'), findsOneWidget);
      expect(find.text('0 dB (Bypass)'), findsOneWidget);
      expect(find.text('+10.0 dB (Max Boost)'), findsOneWidget);

      // Verify Reset Action
      expect(find.text('Reset Equalizer to Flat'), findsOneWidget);
    });

    testWidgets('AudioToolsActionRow displays EQ pill button', (tester) async {
      const mockTrack = Track(
        id: 'test_1',
        title: 'Spinora Sound',
        artist: 'SpideyTech',
        durationMs: 180000,
        source: TrackSource.local,
        uri: 'file:///track.mp3',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AudioToolsActionRow(
                playerState: const PlayerState(equalizerEnabled: true),
                track: mockTrack,
                onOpenQueue: () {},
              ),
            ),
          ),
        ),
      );

      // Verify EQ button is present
      expect(find.text('EQ'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });
  });
}
