import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/navigation/lucid_page_transition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(int index) => MaterialApp(
        home: Scaffold(
          body: LucidTabTransitionSwitcher(
            currentIndex: index,
            tabBuilder: (context, i) => Text('Tab $i Content'),
          ),
        ),
      );

  group('LucidTabTransitionSwitcher', () {
    testWidgets('renders initial tab with no BackdropFilter', (tester) async {
      await tester.pumpWidget(host(0));
      expect(find.text('Tab 0 Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('keeps tabs alive, never uses BackdropFilter, hides wave at rest',
        (tester) async {
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(1));
      await tester.pump(const Duration(milliseconds: 150));

      // Both tabs visible mid-whip; no blur anywhere.
      expect(find.text('Tab 0 Content'), findsOneWidget);
      expect(find.text('Tab 1 Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(FractionalTranslation), findsWidgets);

      await tester.pumpAndSettle();

      // Tab 0 is preserved offstage (state kept), not rebuilt/disposed.
      expect(find.text('Tab 0 Content', skipOffstage: false), findsOneWidget);
      expect(find.text('Tab 0 Content'), findsNothing);
      expect(find.text('Tab 1 Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('supports reverse direction', (tester) async {
      await tester.pumpWidget(host(3));
      await tester.pumpWidget(host(1));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Tab 1 Content'), findsOneWidget);
    });
  });

  group('LucidGlassPageRoute & transition', () {
    testWidgets('pushes and pops with LucidGlassPageRoute', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    LucidGlassPageRoute<void>(
                      builder: (_) =>
                          const Scaffold(body: Text('Destination Screen')),
                    ),
                  );
                },
                child: const Text('Push Route'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Push Route'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Destination Screen'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('Destination Screen'), findsNothing);
      expect(find.text('Push Route'), findsOneWidget);
    });

    testWidgets('buildLucidGlassPageTransition uses 380ms', (tester) async {
      final page = buildLucidGlassPageTransition<void>(
        key: const ValueKey('test_key'),
        child: const Text('Route Page'),
      );

      expect(page.transitionDuration, const Duration(milliseconds: 380));
      expect(page.reverseTransitionDuration, const Duration(milliseconds: 380));
    });
  });
}
