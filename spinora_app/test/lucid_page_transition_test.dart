import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/core/navigation/lucid_page_transition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LucidTabTransitionSwitcher Widget Tests', () {
    testWidgets('renders initial tab child cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LucidTabTransitionSwitcher(
              currentIndex: 0,
              previousIndex: 0,
              child: Text('Tab 0 Content'),
            ),
          ),
        ),
      );

      expect(find.text('Tab 0 Content'), findsOneWidget);
      // Stationary: BackdropFilter must be bypassed (zero GPU overhead)
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('switches tabs smoothly and settles with zero BackdropFilter nodes',
        (tester) async {
      int currentIndex = 0;
      int previousIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          previousIndex = currentIndex;
                          currentIndex = 1;
                        });
                      },
                      child: const Text('Switch to Tab 1'),
                    ),
                    Expanded(
                      child: LucidTabTransitionSwitcher(
                        currentIndex: currentIndex,
                        previousIndex: previousIndex,
                        child: Text(
                          'Tab $currentIndex Content',
                          key: ValueKey<int>(currentIndex),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Tab 0 Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);

      // Trigger tab switch
      await tester.tap(find.text('Switch to Tab 1'));
      await tester.pump();
      // Pump mid-animation (e.g. 200ms into the 480ms transition)
      await tester.pump(const Duration(milliseconds: 200));

      // Both outgoing tab and incoming tab must be rendered simultaneously in the Stack
      expect(find.text('Tab 0 Content'), findsOneWidget);
      expect(find.text('Tab 1 Content'), findsOneWidget);

      // Mid-transition blur pulse should be present on moving window
      expect(find.byType(BackdropFilter), findsOneWidget);

      // Settle animation completely
      await tester.pumpAndSettle();

      expect(find.text('Tab 0 Content'), findsNothing);
      expect(find.text('Tab 1 Content'), findsOneWidget);
      // Once settled, BackdropFilter must be bypassed again
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('supports reverse tab direction correctly', (tester) async {
      int currentIndex = 3;
      int previousIndex = 3;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          previousIndex = currentIndex;
                          currentIndex = 1;
                        });
                      },
                      child: const Text('Switch Backward'),
                    ),
                    Expanded(
                      child: LucidTabTransitionSwitcher(
                        currentIndex: currentIndex,
                        previousIndex: previousIndex,
                        child: Text(
                          'Tab $currentIndex Content',
                          key: ValueKey<int>(currentIndex),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Tab 3 Content'), findsOneWidget);

      // Switch backward
      await tester.tap(find.text('Switch Backward'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(BackdropFilter), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Tab 1 Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('LucidGlassPageRoute & LucidGlassPageTransition Tests', () {
    testWidgets('pushes and pops with LucidGlassPageRoute', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    LucidGlassPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: Text('Destination Screen'),
                      ),
                    ),
                  );
                },
                child: const Text('Push Route'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Push Route'), findsOneWidget);
      expect(find.text('Destination Screen'), findsNothing);

      // Tap push
      await tester.tap(find.text('Push Route'));
      await tester.pump();
      // Mid-transition
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byType(BackdropFilter), findsOneWidget);

      // Settle
      await tester.pumpAndSettle();
      expect(find.text('Destination Screen'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);

      // Pop route
      final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
      navigatorState.pop();

      // Mid-reverse
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(BackdropFilter), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Destination Screen'), findsNothing);
      expect(find.text('Push Route'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('buildLucidGlassPageTransition creates configured CustomTransitionPage',
        (tester) async {
      final page = buildLucidGlassPageTransition<void>(
        key: const ValueKey('test_key'),
        child: const Text('Route Page'),
      );

      expect(page.transitionDuration, const Duration(milliseconds: 480));
      expect(page.reverseTransitionDuration, const Duration(milliseconds: 420));
    });
  });
}
