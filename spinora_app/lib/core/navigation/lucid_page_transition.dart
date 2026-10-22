import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Lucid Glass Transition System — macOS Stage Manager / Desktop Space 3D Morph
// ─────────────────────────────────────────────────────────────────────────────

/// Snappy macOS Stage Manager spring curve with subtle elastic overshoot ("twitch").
const Curve kMacOSSpringTwitchCurve = Cubic(0.18, 1.18, 0.32, 1.0);

/// Floating Lucid Glass Window frame and refraction wrapper.
///
/// While in motion (`0.005 < progress < 0.995`):
/// - Morphs into a floating rounded glass window with animated corner radius:
///   `sin(progress * pi) * 32.0`
/// - Draws a glowing 1.5px specular glass border (Light Mode: luminous white; Dark Mode: neon lavender)
/// - Emits a deep floating window box shadow with subtle ambient neon bloom
/// - Applies an optical blur pulse (`sin(progress * pi) * 10.0`)
/// - Sweeps a diagonal specular glass light sheen across the surface
///
/// When stationary (`progress <= 0.005 || progress >= 0.995`), returns [child] directly
/// with ZERO `BackdropFilter`, `ClipRRect`, or `Transform` overhead.
class _LucidGlassWindow extends StatelessWidget {
  const _LucidGlassWindow({
    super.key,
    required this.child,
    required this.progress,
    required this.scale,
    required this.translation,
    required this.rotationY,
    required this.opacity,
    required this.isDark,
    this.showGlassOverlay = true,
  });

  final Widget child;
  final double progress;
  final double scale;
  final Offset translation;
  final double rotationY;
  final double opacity;
  final bool isDark;
  final bool showGlassOverlay;

  @override
  Widget build(BuildContext context) {
    // Zero-overhead stationary bypass
    if (progress <= 0.005 || progress >= 0.995) {
      return child;
    }

    final double sinVal = math.sin(progress.clamp(0.0, 1.0) * math.pi);
    final double radius = sinVal * 32.0;
    final double blurSigma = sinVal * 10.0;

    final border = Border.all(
      color: isDark
          ? const Color(0xFFD8B4FE).withValues(alpha: 0.55 * sinVal)
          : Colors.white.withValues(alpha: 0.75 * sinVal),
      width: 1.5,
    );

    final boxShadow = [
      BoxShadow(
        color: (isDark ? const Color(0xFF0A0714) : Colors.black)
            .withValues(alpha: 0.40 * sinVal),
        blurRadius: 28 * sinVal,
        spreadRadius: 2 * sinVal,
        offset: Offset(0, 12 * sinVal),
      ),
      if (isDark)
        BoxShadow(
          color: const Color(0xFF9D50BB).withValues(alpha: 0.22 * sinVal),
          blurRadius: 36 * sinVal,
          offset: const Offset(0, 4),
        ),
    ];

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(rotationY);

    return FractionalTranslation(
      translation: translation,
      child: Transform(
        transform: transform,
        alignment: Alignment.center,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: boxShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Underlying view content
                    child,

                    // Specular Glass Border Frame
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius),
                            border: border,
                          ),
                        ),
                      ),
                    ),

                    // Live Frosted Glass Overlay (BackdropFilter)
                    if (showGlassOverlay && blurSigma > 0.1)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(radius),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: blurSigma,
                                sigmaY: blurSigma,
                              ),
                              child: Container(
                                color: (isDark ? Colors.black : Colors.white)
                                    .withValues(
                                  alpha: sinVal * (isDark ? 0.10 : 0.06),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Transient Diagonal Specular Glass Light Sheen
                    if (showGlassOverlay)
                      Positioned.fill(
                        child: _SpecularGlassSheenProgress(
                          progress: progress,
                          isDark: isDark,
                          radius: radius,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Transient diagonal specular glass sheen overlay.
class _SpecularGlassSheenProgress extends StatelessWidget {
  const _SpecularGlassSheenProgress({
    required this.progress,
    required this.isDark,
    required this.radius,
  });

  final double progress;
  final bool isDark;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.01 || progress >= 0.99) {
      return const SizedBox.shrink();
    }

    final double alphaFactor = math.sin(progress.clamp(0.0, 1.0) * math.pi);
    if (alphaFactor <= 0.01) {
      return const SizedBox.shrink();
    }

    final double sweepX = -1.8 + (3.6 * progress);

    final gradient = isDark
        ? LinearGradient(
            begin: Alignment(sweepX - 0.7, -1.0),
            end: Alignment(sweepX + 0.7, 1.0),
            colors: [
              Colors.transparent,
              const Color(0xFF9D50BB).withValues(alpha: 0.24 * alphaFactor),
              const Color(0xFF00E5FF).withValues(alpha: 0.32 * alphaFactor),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 0.55, 1.0],
          )
        : LinearGradient(
            begin: Alignment(sweepX - 0.7, -1.0),
            end: Alignment(sweepX + 0.7, 1.0),
            colors: [
              Colors.white.withValues(alpha: 0.0),
              const Color(0xFFE9D5FF).withValues(alpha: 0.28 * alphaFactor),
              Colors.white.withValues(alpha: 0.50 * alphaFactor),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.45, 0.55, 1.0],
          );

    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(gradient: gradient),
        ),
      ),
    );
  }
}

/// Transition widget providing the macOS Stage Manager 3D Lucid Glass transition
/// for route pages.
class LucidGlassPageTransition extends StatefulWidget {
  const LucidGlassPageTransition({
    super.key,
    required this.animation,
    this.secondaryAnimation,
    required this.child,
    this.isForward = true,
  });

  final Animation<double> animation;
  final Animation<double>? secondaryAnimation;
  final Widget child;
  final bool isForward;

  @override
  State<LucidGlassPageTransition> createState() =>
      _LucidGlassPageTransitionState();
}

class _LucidGlassPageTransitionState extends State<LucidGlassPageTransition> {
  @override
  void initState() {
    super.initState();
    if (widget.animation.status == AnimationStatus.forward) {
      HapticFeedback.selectionClick();
    }
    widget.animation.addStatusListener(_onAnimationStatusChanged);
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.reverse) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onAnimationStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.animation,
        if (widget.secondaryAnimation != null) widget.secondaryAnimation!,
      ]),
      builder: (context, _) {
        final double t = widget.animation.value;
        final bool isStationary =
            (t <= 0.005 || t >= 0.995) &&
            (widget.secondaryAnimation == null ||
                widget.secondaryAnimation!.value <= 0.005);

        if (isStationary) {
          return widget.child;
        }

        // Secondary animation: receding macOS space window when another route is pushed on top
        if (widget.secondaryAnimation != null &&
            widget.secondaryAnimation!.value > 0.005) {
          final double secT = widget.secondaryAnimation!.value;
          final double outProgress = Curves.easeInOutCubic.transform(secT);
          final double outScale = 1.0 - (0.14 * outProgress);
          final double outSlideX = -0.35 * outProgress;
          final double outRotationY = 0.14 * outProgress;
          final double outOpacity = (1.0 - outProgress).clamp(0.0, 1.0);

          return _LucidGlassWindow(
            progress: secT,
            scale: outScale,
            translation: Offset(outSlideX, 0.0),
            rotationY: outRotationY,
            opacity: outOpacity,
            isDark: isDark,
            showGlassOverlay: false,
            child: widget.child,
          );
        }

        // Primary animation: incoming snapping macOS window with spring twitch overshoot
        final double inSpringValue = kMacOSSpringTwitchCurve.transform(t);
        final double inSlideX =
            (widget.isForward ? 0.45 : -0.45) * (1.0 - inSpringValue);
        final double inScale = 0.88 + (0.12 * inSpringValue);
        final double inRotationY =
            (widget.isForward ? -0.16 : 0.16) * (1.0 - inSpringValue);
        final double inOpacity = (t * 2.5).clamp(0.0, 1.0);

        return _LucidGlassWindow(
          progress: t,
          scale: inScale,
          translation: Offset(inSlideX, 0.0),
          rotationY: inRotationY,
          opacity: inOpacity,
          isDark: isDark,
          showGlassOverlay: true,
          child: widget.child,
        );
      },
    );
  }
}

/// A [CustomTransitionPage] implementing the macOS Stage Manager Lucid Glass transition.
///
/// Default transition duration is 480ms with 420ms reverse.
class LucidGlassTransitionPage<T> extends CustomTransitionPage<T> {
  LucidGlassTransitionPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    Duration duration = const Duration(milliseconds: 480),
    Duration reverseDuration = const Duration(milliseconds: 420),
    bool isForward = true,
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return LucidGlassPageTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              isForward: isForward,
              child: child,
            );
          },
        );
}

/// Helper method to create a [LucidGlassTransitionPage] for GoRouter routes.
CustomTransitionPage<T> buildLucidGlassPageTransition<T>({
  required Widget child,
  LocalKey? key,
  String? name,
  Object? arguments,
  String? restorationId,
  Duration duration = const Duration(milliseconds: 480),
  Duration reverseDuration = const Duration(milliseconds: 420),
  bool isForward = true,
}) {
  return LucidGlassTransitionPage<T>(
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
    duration: duration,
    reverseDuration: reverseDuration,
    isForward: isForward,
    child: child,
  );
}

/// A [PageRouteBuilder] implementing the Lucid Glass transition for [Navigator.push].
class LucidGlassPageRoute<T> extends PageRouteBuilder<T> {
  LucidGlassPageRoute({
    required WidgetBuilder builder,
    super.settings,
    Duration duration = const Duration(milliseconds: 480),
    Duration reverseDuration = const Duration(milliseconds: 420),
    bool isForward = true,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.barrierColor,
    super.barrierDismissible,
    super.barrierLabel,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return LucidGlassPageTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              isForward: isForward,
              child: child,
            );
          },
        );
}

/// Directional dual-window 3D tab switcher for bottom navigation bars.
///
/// Features:
/// - Dual-window simultaneous 3D rendering (outgoing receding glass window + incoming snapping glass window)
/// - Receding window: scales down `1.0` -> `0.86`, slides away `0.0` -> `±0.35`, tilts `±0.14` Y-rotation, fades `1.0` -> `0.0`
/// - Incoming window: spring curve [kMacOSSpringTwitchCurve] (`Cubic(0.18, 1.18, 0.32, 1.0)`) with elastic overshoot "twitch"
///   gliding from `±0.45` -> `0.0`, scales up `0.88` -> `1.0`, and un-tilts `∓0.16` -> `0.0`
/// - Lucid Glass Window Frame: dynamic corner radius (`sin(t * pi) * 32.0`), 1.5px glowing specular border, floating shadow
/// - Mid-shift optical blur pulse (`sin(t * pi) * 10.0`) and moving specular diagonal light sheen
/// - Tactile haptic feedback on tab change
/// - Zero GPU overhead when stationary (`animation.value == 0.0 || 1.0` bypasses BackdropFilter and ClipRRect)
class LucidTabTransitionSwitcher extends StatefulWidget {
  const LucidTabTransitionSwitcher({
    super.key,
    required this.currentIndex,
    required this.previousIndex,
    required this.child,
    this.duration = const Duration(milliseconds: 480),
    this.reverseDuration = const Duration(milliseconds: 420),
  });

  final int currentIndex;
  final int previousIndex;
  final Widget child;
  final Duration duration;
  final Duration reverseDuration;

  @override
  State<LucidTabTransitionSwitcher> createState() =>
      _LucidTabTransitionSwitcherState();
}

class _LucidTabTransitionSwitcherState extends State<LucidTabTransitionSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _outgoingChild;
  late Widget _incomingChild;
  late int _currentTab;
  late int _previousTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.currentIndex;
    _previousTab = widget.previousIndex;
    _incomingChild = widget.child;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _outgoingChild = null;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant LucidTabTransitionSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _previousTab = oldWidget.currentIndex;
      _currentTab = widget.currentIndex;
      _outgoingChild = oldWidget.child;
      _incomingChild = widget.child;
      _controller.forward(from: 0.0);
      HapticFeedback.selectionClick();
    } else if (widget.child != oldWidget.child) {
      _incomingChild = widget.child;
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
      builder: (context, _) {
        final double t = _controller.value;
        final bool isStationary =
            _controller.isDismissed ||
            _controller.isCompleted ||
            _outgoingChild == null;

        if (isStationary) {
          return widget.child;
        }

        final bool isForward = _currentTab >= _previousTab;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Outgoing receding macOS window calculations
        final double outProgress = Curves.easeInOutCubic.transform(t);
        final double outScale = 1.0 - (0.14 * outProgress);
        final double outSlideX = (isForward ? -0.35 : 0.35) * outProgress;
        final double outRotationY = (isForward ? 0.14 : -0.14) * outProgress;
        final double outOpacity = (1.0 - outProgress).clamp(0.0, 1.0);

        // Incoming snapping macOS window with spring twitch overshoot
        final double inSpringValue = kMacOSSpringTwitchCurve.transform(t);
        final double inSlideX =
            (isForward ? 0.45 : -0.45) * (1.0 - inSpringValue);
        final double inScale = 0.88 + (0.12 * inSpringValue);
        final double inRotationY =
            (isForward ? -0.16 : 0.16) * (1.0 - inSpringValue);
        final double inOpacity = (t * 2.5).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Outgoing receding macOS glass window
            _LucidGlassWindow(
              key: ValueKey('outgoing_$_previousTab'),
              progress: t,
              scale: outScale,
              translation: Offset(outSlideX, 0.0),
              rotationY: outRotationY,
              opacity: outOpacity,
              isDark: isDark,
              showGlassOverlay: false,
              child: _outgoingChild!,
            ),

            // Incoming snapping macOS glass window with spring twitch
            _LucidGlassWindow(
              key: ValueKey('incoming_$_currentTab'),
              progress: t,
              scale: inScale,
              translation: Offset(inSlideX, 0.0),
              rotationY: inRotationY,
              opacity: inOpacity,
              isDark: isDark,
              showGlassOverlay: true,
              child: _incomingChild,
            ),
          ],
        );
      },
    );
  }
}
