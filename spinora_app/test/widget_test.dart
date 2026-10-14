// Smoke tests for Spinora widgets.
//
// These tests run without a native Firebase environment – they exercise pure
// Flutter/Dart code only (GlassCard, theme tokens, etc.).  Firebase init is
// intentionally NOT called here; CI runs `flutter test` without an Android
// device or google-services.json.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spinora/shared/glass_card.dart';

void main() {
  testWidgets('GlassCard renders its child without error', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GlassCard(
              child: Text('smoke'),
            ),
          ),
        ),
      ),
    );

    // The child text is present in the widget tree.
    expect(find.text('smoke'), findsOneWidget);

    // GlassCard itself is present.
    expect(find.byType(GlassCard), findsOneWidget);
  });
}
