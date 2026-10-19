import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spinora/core/theme/app_theme.dart';
import 'package:spinora/features/library/data/audio_scanner_service.dart';
import 'package:spinora/features/settings/application/audio_settings_provider.dart';
import 'package:spinora/features/settings/presentation/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Crossfade Math Calculations', () {
    test('calculateFadeOutVolume calculates linear fade out correctly', () {
      const trackDuration = Duration(seconds: 100);
      const crossfadeDuration = 3.0; // 3 seconds

      // Remaining time is greater than fade window -> full volume
      // Position: 90s, Duration: 100s -> Remaining: 10s (> 3s)
      expect(
        calculateFadeOutVolume(
          position: const Duration(seconds: 90),
          duration: trackDuration,
          crossfadeDurationSeconds: crossfadeDuration,
        ),
        1.0,
      );

      // Exactly at the start of the fade window (Remaining: 3.0s)
      expect(
        calculateFadeOutVolume(
          position: const Duration(seconds: 97),
          duration: trackDuration,
          crossfadeDurationSeconds: crossfadeDuration,
        ),
        1.0,
      );

      // Halfway through the fade-out (Remaining: 1.5s out of 3.0s)
      final midVolume = calculateFadeOutVolume(
        position: const Duration(milliseconds: 98500),
        duration: trackDuration,
        crossfadeDurationSeconds: crossfadeDuration,
      );
      expect(midVolume, closeTo(0.5, 0.01));

      // Almost at the end (Remaining: 0.3s out of 3.0s)
      final nearEndVolume = calculateFadeOutVolume(
        position: const Duration(milliseconds: 99700),
        duration: trackDuration,
        crossfadeDurationSeconds: crossfadeDuration,
      );
      expect(nearEndVolume, closeTo(0.1, 0.01));

      // Reached the end -> 0.0
      expect(
        calculateFadeOutVolume(
          position: trackDuration,
          duration: trackDuration,
          crossfadeDurationSeconds: crossfadeDuration,
        ),
        0.0,
      );

      // Past the end -> 0.0
      expect(
        calculateFadeOutVolume(
          position: const Duration(seconds: 105),
          duration: trackDuration,
          crossfadeDurationSeconds: crossfadeDuration,
        ),
        0.0,
      );

      // Short track (duration <= fade * 2): do not duck prematurely
      expect(
        calculateFadeOutVolume(
          position: const Duration(seconds: 4),
          duration: const Duration(seconds: 5),
          crossfadeDurationSeconds: crossfadeDuration,
        ),
        1.0,
      );

      // Edge case: crossfadeDuration <= 0
      expect(
        calculateFadeOutVolume(
          position: const Duration(seconds: 99),
          duration: trackDuration,
          crossfadeDurationSeconds: 0.0,
        ),
        1.0,
      );
    });

    test('calculateFadeInVolume calculates linear fade in correctly', () {
      const crossfadeDuration = 4.0; // 4 seconds

      // Start of track -> 0.0
      expect(
        calculateFadeInVolume(
          elapsedSinceStart: Duration.zero,
          crossfadeDurationSeconds: crossfadeDuration,
        ),
        0.0,
      );
      expect(
        calculateFadeInVolume(
          elapsedSinceStart: const Duration(milliseconds: -200),
          crossfadeDurationSeconds: crossfadeDuration,
        ),
        0.0,
      );

      // Halfway through fade in (2s / 4s)
      final midVolume = calculateFadeInVolume(
        elapsedSinceStart: const Duration(seconds: 2),
        crossfadeDurationSeconds: crossfadeDuration,
      );
      expect(midVolume, closeTo(0.5, 0.01));

      // Reached full fade in (4s / 4s)
      expect(
        calculateFadeInVolume(
          elapsedSinceStart: const Duration(seconds: 4),
          crossfadeDurationSeconds: crossfadeDuration,
        ),
        1.0,
      );

      // Beyond fade in duration -> clamped to 1.0
      expect(
        calculateFadeInVolume(
          elapsedSinceStart: const Duration(seconds: 10),
          crossfadeDurationSeconds: crossfadeDuration,
        ),
        1.0,
      );

      // Edge case: crossfadeDuration <= 0
      expect(
        calculateFadeInVolume(
          elapsedSinceStart: Duration.zero,
          crossfadeDurationSeconds: 0.0,
        ),
        1.0,
      );
    });
  });

  group('audioSettingsProvider & Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to crossfadeEnabled=false and crossfadeDurationSeconds=3.0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(audioSettingsProvider);
      expect(state.crossfadeEnabled, isFalse);
      expect(state.crossfadeDurationSeconds, 3.0);
      expect(state.fadeDuration, const Duration(seconds: 3));
    });

    test('setCrossfadeEnabled toggles state and persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(audioSettingsProvider).crossfadeEnabled, isFalse);

      await container.read(audioSettingsProvider.notifier).setCrossfadeEnabled(true);
      expect(container.read(audioSettingsProvider).crossfadeEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('spinora_crossfade_enabled'), isTrue);

      await container.read(audioSettingsProvider.notifier).setCrossfadeEnabled(false);
      expect(container.read(audioSettingsProvider).crossfadeEnabled, isFalse);
      expect(prefs.getBool('spinora_crossfade_enabled'), isFalse);
    });

    test('setCrossfadeDuration clamps and persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(audioSettingsProvider.notifier).setCrossfadeDuration(5.5);
      expect(container.read(audioSettingsProvider).crossfadeDurationSeconds, 5.5);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('spinora_crossfade_duration'), 5.5);

      // Clamping below 1.0
      await container.read(audioSettingsProvider.notifier).setCrossfadeDuration(0.2);
      expect(container.read(audioSettingsProvider).crossfadeDurationSeconds, 1.0);

      // Clamping above 8.0
      await container.read(audioSettingsProvider.notifier).setCrossfadeDuration(12.0);
      expect(container.read(audioSettingsProvider).crossfadeDurationSeconds, 8.0);
    });

    test('loads saved preferences from SharedPreferences on initialization', () async {
      SharedPreferences.setMockInitialValues({
        'spinora_crossfade_enabled': true,
        'spinora_crossfade_duration': 6.0,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(audioSettingsProvider.notifier).initialized;

      final state = container.read(audioSettingsProvider);
      expect(state.crossfadeEnabled, isTrue);
      expect(state.crossfadeDurationSeconds, 6.0);
      expect(state.fadeDuration, const Duration(seconds: 6));
    });
  });

  group('SettingsScreen Crossfade UI Rendering', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders Audio Playback & Crossfade section and controls', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioScannerStateProvider.overrideWith(
              () => _MockScannerNotifier(),
            ),
            localSongsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            theme: appDarkTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify section header exists
      expect(find.text('AUDIO PLAYBACK & CROSSFADE'), findsOneWidget);

      // Verify switch tile title and initial subtitle
      expect(find.text('Enable Audio Crossfade'), findsOneWidget);
      expect(
        find.text('Seamlessly blend consecutive tracks'),
        findsOneWidget,
      );

      // Verify switch exists and is initially off
      final rowFinder = find.ancestor(
        of: find.text('Enable Audio Crossfade'),
        matching: find.byType(Row),
      );
      final switchFinder = find.descendant(
        of: rowFinder,
        matching: find.byType(Switch),
      );
      expect(switchFinder, findsOneWidget);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);

      // Slider is not rendered while disabled
      expect(find.byType(Slider), findsNothing);

      // Tap the switch to enable crossfade
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final updatedSwitch = tester.widget<Switch>(switchFinder);
      expect(updatedSwitch.value, isTrue);

      // Now duration label, badge, and slider should appear
      expect(find.text('Crossfade Duration (1s - 8s)'), findsOneWidget);
      expect(find.text('3.0s'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });
  });
}

class _MockScannerNotifier extends AudioScannerNotifier {
  @override
  AudioScanState build() => const AudioScanState(scannedCount: 120);
}
