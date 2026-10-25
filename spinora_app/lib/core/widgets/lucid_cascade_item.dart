import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-tab "entered" counters. Bumped by the main shell whenever a tab is
/// selected so each tab's [LucidCascadeItem]s replay their domino entry.
class TabEntryTicksNotifier extends Notifier<List<int>> {
  @override
  List<int> build() => List<int>.filled(5, 0);

  void bump(int tab) {
    final next = [...state];
    next[tab] = next[tab] + 1;
    state = next;
  }
}

final tabEntryTicksProvider =
    NotifierProvider<TabEntryTicksNotifier, List<int>>(
      TabEntryTicksNotifier.new,
    );

const Curve kDominoSpringCurve = Cubic(0.16, 1.12, 0.3, 1.0);

/// Staggered "Domino Glass" entry: glides up (0.06 → 0) and scales 0.96 → 1.0,
/// delayed by `index * 35ms` within a 420ms animation. Replays whenever
/// [triggerKey] changes. Pure transform + opacity (GPU compositor only).
class LucidCascadeItem extends StatefulWidget {
  const LucidCascadeItem({
    super.key,
    required this.index,
    required this.triggerKey,
    required this.child,
  });

  final int index;
  final Object? triggerKey;
  final Widget child;

  @override
  State<LucidCascadeItem> createState() => _LucidCascadeItemState();
}

class _LucidCascadeItemState extends State<LucidCascadeItem>
    with SingleTickerProviderStateMixin {
  static const int _durationMs = 420;
  static const int _staggerMs = 35;

  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    final int delay = widget.index * _staggerMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _durationMs + delay),
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay / (_durationMs + delay),
        1.0,
        curve: kDominoSpringCurve,
      ),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant LucidCascadeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.triggerKey != widget.triggerKey) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        if (_controller.isCompleted) return child!;
        final double v = _curve.value;
        final double fade = (v * 2.0).clamp(0.0, 1.0);
        return FractionalTranslation(
          translation: Offset(0.0, 0.06 * (1.0 - v)),
          child: Transform.scale(
            scale: 0.96 + (0.04 * v),
            child: Opacity(opacity: fade, child: child),
          ),
        );
      },
    );
  }
}
