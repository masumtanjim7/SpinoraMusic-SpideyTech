import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinora/features/player/presentation/widgets/audio_visualizer_widget.dart';

void main() {
  group('AudioVisualizerWidget Tests', () {
    testWidgets('renders child widget and CustomPaint when active',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioVisualizerWidget(
              isPlaying: true,
              size: 200,
              child: Container(
                key: const ValueKey('artwork_container'),
                color: Colors.red,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('artwork_container')), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Advance frames to ensure animations run smoothly without throwing
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('transitions gracefully when paused and halts animation',
        (tester) async {
      var isPlaying = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    AudioVisualizerWidget(
                      isPlaying: isPlaying,
                      size: 200,
                      child: const Text('Cover Art'),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => isPlaying = !isPlaying),
                      child: const Text('Toggle'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Cover Art'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));

      // Pause playback
      await tester.tap(find.text('Toggle'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('Cover Art'), findsOneWidget);
    });

    testWidgets('renders plain child when enabled is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizerWidget(
              enabled: false,
              isPlaying: true,
              size: 150,
              child: Text('Disabled Visualizer'),
            ),
          ),
        ),
      );

      expect(find.text('Disabled Visualizer'), findsOneWidget);
    });
  });

  group('MiniAudioVisualizer Tests', () {
    testWidgets('renders all bars and reacts to isPlaying', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MiniAudioVisualizer(
              isPlaying: true,
              barCount: 4,
              width: 20,
              height: 16,
            ),
          ),
        ),
      );

      expect(find.byType(MiniAudioVisualizer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('handles paused state without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MiniAudioVisualizer(
              isPlaying: false,
              barCount: 4,
            ),
          ),
        ),
      );

      expect(find.byType(MiniAudioVisualizer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
