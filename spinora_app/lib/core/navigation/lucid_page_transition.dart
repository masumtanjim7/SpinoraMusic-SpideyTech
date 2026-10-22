import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Lucid Glass Transition System — Apple / macOS Optical Glass Page & Tab Morph
// ─────────────────────────────────────────────────────────────────────────────

/// Mid-transition optical blur pulse.
///
/// Follows a bell curve: `sin(animation.value * pi) * 12.0` so the screen visibly
/// frosts/refracts mid-shift and sharpens cleanly to 0.0 once the page settles.
///
/// Strictly returns [SizedBox.shrink] when stationary (`animation.value == 0.0 || 1.0`)
/// to ensure zero GPU overhead.
class _OpticalBlurPulse extends StatelessWidget {
  const _OpticalBlurPulse({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final double progress = animation.value;
        if (progress <= 0.0 || progress >= 1.0) {
          return const SizedBox.shrink();
        }

        final double blurSigma = math.sin(progress * math.pi) * 12.0;
        if (blurSigma <= 0.05) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final double tintAlpha =
            math.sin(progress * math.pi) * (isDark ? 0.12 : 0.08);

        return IgnorePointer(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                color: (isDark ? Colors.black : Colors.white)
                    .withValues(alpha: tintAlpha),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Moving specular glass sheen overlay.
///
/// Renders a transient diagonal glass light reflection that sweeps across the
/// incoming screen as it locks into place. Adapts to theme brightness:
/// - Light Mode: Luminous white/lilac sheen
/// - Dark Mode: Neon violet/cyan sheen
///
/// Strictly bypassed when stationary (`animation.value == 0.0 || 1.0`).
class _SpecularGlassSheen extends StatelessWidget {
  const _SpecularGlassSheen({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final double progress = animation.value;
        if (progress <= 0.0 || progress >= 1.0) {
          return const SizedBox.shrink();
        }

        final double alphaFactor = math.sin(progress * math.pi);
        if (alphaFactor <= 0.01) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final double sweepX = -1.8 + (3.6 * progress);

        final gradient = isDark
            ? LinearGradient(
                begin: Alignment(sweepX - 0.7, -1.0),
                end: Alignment(sweepX + 0.7, 1.0),
                colors: [
                  Colors.transparent,
                  const Color(0xFF9D50BB).withValues(
                    alpha: 0.22 * alphaFactor,
                  ),
                  const Color(0xFF00E5FF).withValues(
                    alpha: 0.30 * alphaFactor,
                  ),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 0.55, 1.0],
              )
            : LinearGradient(
                begin: Alignment(sweepX - 0.7, -1.0),
                end: Alignment(sweepX + 0.7, 1.0),
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  const Color(0xFFE9D5FF).withValues(
                    alpha: 0.26 * alphaFactor,
                  ),
                  Colors.white.withValues(
                    alpha: 0.45 * alphaFactor,
                  ),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45, 0.55, 1.0],
              );

        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(gradient: gradient),
          ),
        );
      },
    );
  }
}

/// Transition widget providing the Lucid Glass animation for route pages.
///
/// Features:
/// - Directional parallax slide (`Offset(0.08, 0.0)` -> `Offset.zero`)
/// - 3D depth scale (`0.95` -> `1.0`) with `Curves.easeOutCubic`
/// - Smooth opacity crossfade
/// - Mid-transition optical blur pulse (`sin(t * pi) * 12.0`)
/// - Moving specular glass sheen (diagonal light sweep)
/// - Secondary animation support (scaling down & sliding slightly back when another route is pushed)
/// - Haptic selection click trigger on transition start
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
    final curvedAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final slideAnimation = Tween<Offset>(
      begin: Offset(widget.isForward ? 0.08 : -0.08, 0.0),
      end: Offset.zero,
    ).animate(curvedAnimation);

    final scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(curvedAnimation);

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
      reverseCurve: const Interval(0.15, 1.0, curve: Curves.easeIn),
    ));

    Widget content = FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: widget.child,
        ),
      ),
    );

    if (widget.secondaryAnimation != null) {
      final secondaryCurved = CurvedAnimation(
        parent: widget.secondaryAnimation!,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final secondaryScale = Tween<double>(
        begin: 1.0,
        end: 0.95,
      ).animate(secondaryCurved);
      final secondarySlide = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.04, 0.0),
      ).animate(secondaryCurved);

      content = SlideTransition(
        position: secondarySlide,
        child: ScaleTransition(
          scale: secondaryScale,
          child: content,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        _OpticalBlurPulse(animation: widget.animation),
        _SpecularGlassSheen(animation: widget.animation),
      ],
    );
  }
}

/// A [CustomTransitionPage] implementing the Apple / macOS Lucid Glass transition.
///
/// Default transition duration is 450ms with 400ms reverse.
class LucidGlassTransitionPage<T> extends CustomTransitionPage<T> {
  LucidGlassTransitionPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    Duration duration = const Duration(milliseconds: 450),
    Duration reverseDuration = const Duration(milliseconds: 400),
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
  Duration duration = const Duration(milliseconds: 450),
  Duration reverseDuration = const Duration(milliseconds: 400),
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
    Duration duration = const Duration(milliseconds: 450),
    Duration reverseDuration = const Duration(milliseconds: 400),
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

/// Directional tab transition switcher for bottom navigation bars.
///
/// Features:
/// - Directional horizontal parallax (`Offset(isForward ? 0.08 : -0.08, 0.0)` -> `Offset.zero`)
/// - 3D tactile depth scale (`0.95` -> `1.0`)
/// - Smooth opacity crossfade
/// - Mid-transition optical blur pulse (`sin(t * pi) * 12.0`)
/// - Adaptive diagonal specular light sweep reflection
/// - Haptic feedback on tab change
class LucidTabTransitionSwitcher extends StatefulWidget {
  const LucidTabTransitionSwitcher({
    super.key,
    required this.currentIndex,
    required this.previousIndex,
    required this.child,
    this.duration = const Duration(milliseconds: 450),
    this.reverseDuration = const Duration(milliseconds: 400),
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

class _LucidTabTransitionSwitcherState
    extends State<LucidTabTransitionSwitcher> {
  @override
  void didUpdateWidget(covariant LucidTabTransitionSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isForward = widget.currentIndex >= widget.previousIndex;

    return AnimatedSwitcher(
      duration: widget.duration,
      reverseDuration: widget.reverseDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.topLeft,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final isEntering =
            (child.key as ValueKey<int>?)?.value == widget.currentIndex;

        // Horizontal parallax offset based on tab index direction
        final double slideOffset = isForward ? 0.08 : -0.08;

        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final slideAnimation = Tween<Offset>(
          begin: isEntering
              ? Offset(slideOffset, 0.0)
              : Offset(-slideOffset, 0.0),
          end: Offset.zero,
        ).animate(curvedAnimation);

        // Tactile 3D depth scale factor (0.95 -> 1.0)
        final scaleAnimation = Tween<double>(
          begin: isEntering ? 0.95 : 1.0,
          end: isEntering ? 1.0 : 0.95,
        ).animate(curvedAnimation);

        // Frosted glass opacity crossfade
        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
          reverseCurve: const Interval(0.15, 1.0, curve: Curves.easeIn),
        ));

        final transitionChild = FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          ),
        );

        if (!isEntering) {
          return transitionChild;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            transitionChild,
            _OpticalBlurPulse(animation: animation),
            _SpecularGlassSheen(animation: animation),
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(widget.currentIndex),
        child: widget.child,
      ),
    );
  }
}
