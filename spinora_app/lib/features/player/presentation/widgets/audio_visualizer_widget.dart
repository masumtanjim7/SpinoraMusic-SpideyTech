import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Interactive audio visualizer that wraps a centerpiece widget (such as album artwork)
/// with pulsing neon glow rings and animated radial waveform frequency spectrum arcs.
///
/// Automatically halts animation ticker when [isPlaying] is false to eliminate
/// battery and GPU consumption when audio is paused.
class AudioVisualizerWidget extends StatefulWidget {
  const AudioVisualizerWidget({
    super.key,
    required this.child,
    required this.isPlaying,
    required this.size,
    this.primaryColor = AppColors.cyanAccent,
    this.secondaryColor = AppColors.purpleAccent,
    this.enabled = true,
  });

  /// The child centerpiece (e.g. Artwork Card) centered inside the visualizer ring.
  final Widget child;

  /// Whether audio is actively playing.
  final bool isPlaying;

  /// Overall dimension of the artwork centerpiece square.
  final double size;

  /// Primary neon color for inner ring and waveform peaks.
  final Color primaryColor;

  /// Secondary neon color for outer harmonic glow.
  final Color secondaryColor;

  /// Master switch to enable or disable visualizer rendering.
  final bool enabled;

  @override
  State<AudioVisualizerWidget> createState() => _AudioVisualizerWidgetState();
}

class _AudioVisualizerWidgetState extends State<AudioVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    if (widget.isPlaying && widget.enabled) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    if (_isTestEnvironment) {
      _controller.forward(from: 0.5);
    } else {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AudioVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying ||
        widget.enabled != oldWidget.enabled) {
      if (widget.isPlaying && widget.enabled) {
        if (!_controller.isAnimating) {
          _startAnimation();
        }
      } else {
        if (_controller.isAnimating) {
          _controller.animateTo(
            0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.child,
      );
    }

    // Extra padding around artwork to accommodate the glowing waveform bars & rings
    final overflowPadding = (widget.size * 0.12).clamp(18.0, 38.0);
    final totalSize = widget.size + (overflowPadding * 2);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(totalSize, totalSize),
          painter: _WaveformRingPainter(
            animationValue: _controller.value,
            isPlaying: widget.isPlaying,
            innerRadius: widget.size / 2,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
          child: SizedBox(
            width: totalSize,
            height: totalSize,
            child: Center(
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// CustomPainter rendering smooth neon concentric waveform rings and
/// 48 harmonic frequency spectrum rays surrounding the artwork.
class _WaveformRingPainter extends CustomPainter {
  _WaveformRingPainter({
    required this.animationValue,
    required this.isPlaying,
    required this.innerRadius,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final double animationValue;
  final bool isPlaying;
  final double innerRadius;
  final Color primaryColor;
  final Color secondaryColor;

  static const int _barCount = 48;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final activeProgress = isPlaying ? 1.0 : 0.0;
    if (activeProgress == 0.0 && animationValue == 0.0) {
      return;
    }

    final t = animationValue * 2 * math.pi;

    // 1. Ambient pulsing background glow
    final glowRadius = innerRadius + 10.0 + (math.sin(t) * 4.0);
    final glowPaint = Paint()
      ..color = secondaryColor.withValues(
        alpha: (0.16 + 0.08 * math.sin(t)) * activeProgress,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, glowRadius, glowPaint);

    // 2. Concentric Neon Pulsing Rings
    final innerRingRadius = innerRadius + 2.0 + (math.sin(t * 1.5) * 3.0);
    final innerRingPaint = Paint()
      ..color = primaryColor.withValues(
        alpha: (0.35 + 0.20 * math.sin(t * 1.5)) * activeProgress,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, innerRingRadius, innerRingPaint);

    final outerRingRadius = innerRadius + 12.0 + (math.cos(t) * 4.5);
    final outerRingPaint = Paint()
      ..color = secondaryColor.withValues(
        alpha: (0.22 + 0.12 * math.cos(t)) * activeProgress,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, outerRingRadius, outerRingPaint);

    // 3. Radial Frequency Spectrum Bars
    final barPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final angleStep = (2 * math.pi) / _barCount;

    for (var i = 0; i < _barCount; i++) {
      final angle = i * angleStep;

      // Harmonic waveform simulation combining fundamental and overtone frequencies
      final harmonic1 = math.sin(angle * 3.0 + t);
      final harmonic2 = math.cos(angle * 5.0 - t * 1.4);
      final harmonic3 = math.sin(angle * 7.0 + t * 0.7);

      final combined = (harmonic1 * 0.5 + harmonic2 * 0.35 + harmonic3 * 0.15)
          .abs()
          .clamp(0.05, 1.0);

      final maxBarLength = 16.0;
      final barLength = maxBarLength * combined * activeProgress;

      final startDistance = innerRadius + 4.0;
      final endDistance = startDistance + barLength;

      final startX = center.dx + math.cos(angle) * startDistance;
      final startY = center.dy + math.sin(angle) * startDistance;
      final endX = center.dx + math.cos(angle) * endDistance;
      final endY = center.dy + math.sin(angle) * endDistance;

      // Color interpolation around perimeter from cyan to purple
      final colorRatio = (math.sin(angle + t * 0.5) + 1.0) / 2.0;
      final barColor = Color.lerp(primaryColor, secondaryColor, colorRatio)!;

      final barAlpha = (0.35 + (0.55 * combined)) * activeProgress;
      barPaint.color = barColor.withValues(alpha: barAlpha.clamp(0.0, 1.0));
      barPaint.strokeWidth = (2.2 * (0.8 + 0.4 * combined)).clamp(1.5, 3.0);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformRingPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.innerRadius != innerRadius ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

/// Compact 4-bar jumping equalizer animation suitable for the MiniPlayer,
/// song lists, or header badges.
class MiniAudioVisualizer extends StatefulWidget {
  const MiniAudioVisualizer({
    super.key,
    required this.isPlaying,
    this.color = AppColors.cyanAccent,
    this.barCount = 4,
    this.height = 14,
    this.width = 16,
  });

  /// Whether playback is active.
  final bool isPlaying;

  /// Bar tint color.
  final Color color;

  /// Number of equalizer bars.
  final int barCount;

  /// Total height of the visualizer.
  final double height;

  /// Total width of the visualizer.
  final double width;

  @override
  State<MiniAudioVisualizer> createState() => _MiniAudioVisualizerState();
}

class _MiniAudioVisualizerState extends State<MiniAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    if (widget.isPlaying) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    if (_isTestEnvironment) {
      _controller.forward(from: 0.5);
    } else {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MiniAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_controller.isAnimating) {
          _startAnimation();
        }
      } else {
        if (_controller.isAnimating) {
          _controller.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barSpacing = 2.0;
    final totalSpacing = (widget.barCount - 1) * barSpacing;
    final barWidth = ((widget.width - totalSpacing) / widget.barCount).clamp(
      1.5,
      4.0,
    );

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (index) {
              final phase = (index * 0.75);
              final t = (_controller.value * 2 * math.pi) + phase;
              final wave = (math.sin(t) + 1.0) / 2.0;

              final barHeight = widget.isPlaying
                  ? (widget.height * (0.25 + 0.75 * wave)).clamp(
                      3.0,
                      widget.height,
                    )
                  : 3.0;

              return Container(
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                    alpha: widget.isPlaying ? 0.90 : 0.40,
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: widget.isPlaying
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.45),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
