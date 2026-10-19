import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spinora/core/theme/app_theme.dart';
import 'package:spinora/features/library/data/audio_scanner_service.dart';
import 'package:spinora/features/settings/application/theme_provider.dart';
import 'package:spinora/features/settings/presentation/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme & Design Tokens', () {
    test('appDarkTheme has correct properties', () {
      expect(appDarkTheme.brightness, Brightness.dark);
      expect(appDarkTheme.scaffoldBackgroundColor, const Color(0xFF08070F));
      expect(AppColors.background, const Color(0xFF08070F));
    });

    test('appLightTheme has Apple Lucid Glass properties', () {
      expect(appLightTheme.brightness, Brightness.light);
      expect(appLightTheme.scaffoldBackgroundColor, const Color(0xFFF4F5FA));
      expect(AppColors.lightBackground, const Color(0xFFF4F5FA));
      expect(AppColors.lightTextPrimary, const Color(0xFF0F111A));
      expect(AppColors.lightTextSecondary, const Color(0xFF5C6275));
    });

    test('AppTheme shadows are defined', () {
      expect(AppTheme.lightCardShadow, isNotEmpty);
      expect(AppTheme.darkCardShadow, isNotEmpty);
    });
  });

  group('themeModeProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to ThemeMode.dark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = container.read(themeModeProvider);
      expect(mode, ThemeMode.dark);
    });

    test('toggleTheme alternates between dark and light and persists', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);

      await container.read(themeModeProvider.notifier).toggleTheme();
      expect(container.read(themeModeProvider), ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('spinora_theme_mode'), 'light');

      await container.read(themeModeProvider.notifier).toggleTheme();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(prefs.getString('spinora_theme_mode'), 'dark');
    });

    test('setTheme explicitly sets mode and persists', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(themeModeProvider.notifier)
          .setTheme(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('spinora_theme_mode'), 'light');
    });
  });

  group('SettingsScreen Appearance UI', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders Appearance section with Dark and Light chips',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localSongsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: appLightTheme,
            darkTheme: appDarkTheme,
            themeMode: ThemeMode.dark,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Dark Cosmos'), findsOneWidget);
      expect(find.text('Lucid Light'), findsOneWidget);

      // Tap on Lucid Light chip
      await tester.tap(find.text('Lucid Light'));
      await tester.pumpAndSettle();

      // Verify the tile title updates to Light Mode (Apple Lucid Glass)
      expect(find.text('Light Mode (Apple Lucid Glass)'), findsOneWidget);
      expect(find.text('Pearl-white acrylic, frosted glass & slate'),
          findsOneWidget);
    });
  });
}
