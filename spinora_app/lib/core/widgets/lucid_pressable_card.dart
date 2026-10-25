import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 3D tactile press wrapper for Lucid Glass cards.
///
/// - Scales to 0.965 on finger down (110ms, easeOutCubic) and springs back to
///   1.0 on release (280ms, elasticOut) with a light haptic tick.
/// - Sweeps a 1.5px specular rim highlight around the rounded border using a
///   lightweight canvas painter (no BackdropFilter, no per-frame blur).
class LucidPressableCard extends StatefulWidget {
  const LucidPressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 20,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  State<LucidPressableCard> createState() => _LucidPressableCardState();
}

class _LucidPressableCardState extends State<LucidPressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _rim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _rim.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    setState(() => _pressed = true);
    _rim.forward(from: 0.0);
  }

  void _up(TapUpDetails _) {
    setState(() => _pressed = false);
    HapticFeedback.lightImpact();
  }

  void _cancel() {
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: Duration(milliseconds: _pressed ? 110 : 280),
        curve: _pressed ? Curves.easeOutCubic : Curves.elasticOut,
        child: RepaintBoundary(
          child: CustomPaint(
            foregroundPainter: ForegroundPainter(
              progress: _rim,
              borderRadius: widget.borderRadius,
              isDark: isDark,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Paints a travelling specular highlight along a rounded-rect border.
class ForegroundPainter extends CustomPainter {
  ForegroundPainter({
    required this.progress,
    required this.borderRadius,
    required this.isDark,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final double borderRadius;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value;
    if (t <= 0.0 || t >= 1.0 || size.isEmpty) return;

    final double fade = math.sin(t * math.pi);
    const Color a = Colors.white;
    final Color b = isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6);

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      Radius.circular(borderRadius),
    );

    final shader = SweepGradient(
      transform: GradientRotation(t * 2 * math.pi),
      colors: [
        a.withValues(alpha: 0.0),
        b.withValues(alpha: (isDark ? 0.55 : 0.70) * fade),
        a.withValues(alpha: (isDark ? 0.95 : 1.0) * fade),
        b.withValues(alpha: (isDark ? 0.55 : 0.70) * fade),
        a.withValues(alpha: 0.0),
        a.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.08, 0.14, 0.2, 0.28, 1.0],
    ).createShader(rect);

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant ForegroundPainter old) =>
      old.borderRadius != borderRadius || old.isDark != isDark;
}
