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
