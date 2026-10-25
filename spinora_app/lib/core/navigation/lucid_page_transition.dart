import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Lucid Glass Transition System — macOS Spring-Whip + Prism Wave
//
// Pure GPU compositor transforms only: translate / scale / opacity plus a
// gradient sweep overlay. NO BackdropFilter, NO ImageFilter.blur, NO 3D rotate.
// ─────────────────────────────────────────────────────────────────────────────

/// Snappy macOS spring curve with a crisp overshoot.
const Curve kMacOSSpringTwitchCurve = Cubic(0.16, 1.14, 0.3, 1.0);

/// Default transition duration for tabs and routes.
const Duration kLucidTransitionDuration = Duration(milliseconds: 380);

const double _kSlideDistance = 0.22;
const double _kStartScale = 0.92;
const Curve _kFadeCurve = Interval(0.0, 0.55);

/// Incoming whip: slide + zoom pop + fade, evaluated at animation value [t].
({Offset offset, double scale, double opacity}) _incomingValues(
  double t,
  bool isForward,
) {
  final double spring = kMacOSSpringTwitchCurve.transform(t);
  final double dir = isForward ? _kSlideDistance : -_kSlideDistance;
  return (
    offset: Offset(dir * (1.0 - spring), 0.0),
    scale: _kStartScale + ((1.0 - _kStartScale) * Curves.easeOutBack.transform(t)),
    opacity: _kFadeCurve.transform(t).clamp(0.0, 1.0),
  );
}

/// Hardware-accelerated "Lucid Glass Prism Wave": an angled gradient sheet that
/// sweeps across the screen as [animation] moves 0 → 1. Zero blur cost.
///
/// Fully hidden when `animation.value == 0.0 || animation.value == 1.0`.
class LucidPrismWave extends StatelessWidget {
  const LucidPrismWave({
    super.key,
    required this.animation,
    required this.isForward,
    required this.isDark,
  });

  final Animation<double> animation;
  final bool isForward;
  final bool isDark;

  static const double _widthFactor = 0.7;

  LinearGradient _gradient() {
    final List<Color> colors;
    final List<double> stops;
    if (isDark) {
      final violet = const Color(0xFF9D50BB);
      final pink = const Color(0xFFFF5E99);
      colors = [
        violet.withValues(alpha: 0.0),
        violet.withValues(alpha: 0.32),
        Colors.white.withValues(alpha: 0.28),
        pink.withValues(alpha: 0.25),
        pink.withValues(alpha: 0.0),
      ];
      stops = const [0.0, 0.3, 0.55, 0.8, 1.0];
    } else {
      final lavender = const Color(0xFFA78BFA);
      colors = [
        Colors.white.withValues(alpha: 0.0),
        Colors.white.withValues(alpha: 0.65),
        lavender.withValues(alpha: 0.28),
        lavender.withValues(alpha: 0.28),
        Colors.white.withValues(alpha: 0.95), // crisp specular leading edge
        Colors.white.withValues(alpha: 0.0),
      ];
      stops = const [0.0, 0.3, 0.65, 0.975, 0.988, 1.0];
    }

    if (isForward) {
      return LinearGradient(
        begin: const Alignment(-1.0, -0.4),
        end: const Alignment(1.0, 0.4),
        colors: colors,
        stops: stops,
      );
    }
    // Mirror so the specular edge leads when sweeping right → left.
    return LinearGradient(
      begin: const Alignment(-1.0, -0.4),
      end: const Alignment(1.0, 0.4),
      colors: colors.reversed.toList(),
      stops: stops.reversed.map((s) => 1.0 - s).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget sheet = DecoratedBox(
      decoration: BoxDecoration(gradient: _gradient()),
      child: const SizedBox.expand(),
    );

    return AnimatedBuilder(
      animation: animation,
      child: sheet,
      builder: (context, child) {
        final double v = animation.value;
        if (v <= 0.0 || v >= 1.0) return const SizedBox.shrink();

        final double dx = isForward
            ? -1.0 + (1.0 + 1.0 / _widthFactor) * v
            : 1.0 - (1.0 + 1.0 / _widthFactor) * v;

        return IgnorePointer(
          child: RepaintBoundary(
            child: FractionallySizedBox(
              widthFactor: _widthFactor,
              heightFactor: 1.0,
              alignment:
                  isForward ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionalTranslation(
                translation: Offset(dx, 0.0),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Route transition: spring slide + zoom pop + fade, with the prism wave.
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
    final sec = widget.secondaryAnimation;

    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, ?sec]),
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        final inV = _incomingValues(
          widget.animation.value.clamp(0.0, 1.0),
          widget.isForward,
        );
        // Receding page when another route is pushed on top.
        final double secT = sec == null
            ? 0.0
            : Curves.easeOutCubic.transform(sec.value.clamp(0.0, 1.0));

        return Stack(
          fit: StackFit.passthrough,
          children: [
            FractionalTranslation(
              translation: Offset(inV.offset.dx - (0.06 * secT), 0.0),
              child: Transform.scale(
                scale: inV.scale * (1.0 - (0.03 * secT)),
                child: Opacity(opacity: inV.opacity, child: child),
              ),
            ),
            Positioned.fill(
              child: LucidPrismWave(
                animation: widget.animation,
                isForward: widget.isForward,
                isDark: isDark,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A [CustomTransitionPage] implementing the Lucid Glass spring-whip transition.
class LucidGlassTransitionPage<T> extends CustomTransitionPage<T> {
  LucidGlassTransitionPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    Duration duration = kLucidTransitionDuration,
    Duration reverseDuration = kLucidTransitionDuration,
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
  Duration duration = kLucidTransitionDuration,
  Duration reverseDuration = kLucidTransitionDuration,
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
    Duration duration = kLucidTransitionDuration,
    Duration reverseDuration = kLucidTransitionDuration,
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

// ─────────────────────────────────────────────────────────────────────────────
// Zero-Buffer Tab Switcher
// ─────────────────────────────────────────────────────────────────────────────

enum _TabRole { idle, current, outgoing }

/// Zero-buffer tab host.
///
/// - Each tab is built lazily ONCE, wrapped in a [RepaintBoundary], and kept
///   alive (state + scroll position + Drift streams) for the app's lifetime.
/// - Switching only animates cached layers via transforms/opacity; tab bodies
///   are never rebuilt during the 380ms whip.
/// - Hidden tabs are [Offstage] with tickers muted.
class LucidTabTransitionSwitcher extends StatefulWidget {
  const LucidTabTransitionSwitcher({
    super.key,
    required this.currentIndex,
    required this.tabBuilder,
    this.duration = kLucidTransitionDuration,
  });

  final int currentIndex;
  final Widget Function(BuildContext context, int index) tabBuilder;
  final Duration duration;

  @override
  State<LucidTabTransitionSwitcher> createState() =>
      _LucidTabTransitionSwitcherState();
}

class _LucidTabTransitionSwitcherState extends State<LucidTabTransitionSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Map<int, Widget> _tabs = <int, Widget>{};
  int? _from;
  bool _isForward = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _from = null);
        }
      });
  }

  @override
  void didUpdateWidget(covariant LucidTabTransitionSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _from = oldWidget.currentIndex;
      _isForward = widget.currentIndex > oldWidget.currentIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _tab(int index) {
    return _tabs.putIfAbsent(
      index,
      () => RepaintBoundary(
        key: ValueKey<String>('lucid_tab_boundary_$index'),
        child: widget.tabBuilder(context, index),
      ),
    );
  }

  Widget _slot(int index, _TabRole role) {
    final Widget tab = _tab(index);
    final bool visible = role != _TabRole.idle;

    return KeyedSubtree(
      key: ValueKey<int>(index),
      child: Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: IgnorePointer(
            ignoring: role == _TabRole.outgoing,
            child: AnimatedBuilder(
              animation: _controller,
              child: tab,
              builder: (context, child) {
                Offset offset = Offset.zero;
                double scale = 1.0;
                double opacity = 1.0;

                if (_from != null && role == _TabRole.current) {
                  final v = _incomingValues(_controller.value, _isForward);
                  offset = v.offset;
                  scale = v.scale;
                  opacity = v.opacity;
                } else if (_from != null && role == _TabRole.outgoing) {
                  final double t = _controller.value;
                  offset = Offset(
                    (_isForward ? -0.08 : 0.08) * Curves.easeOutCubic.transform(t),
                    0.0,
                  );
                  scale = 1.0 - (0.03 * t);
                  opacity = 1.0 -
                      const Interval(0.0, 0.5, curve: Curves.easeIn)
                          .transform(t);
                }

                return FractionalTranslation(
                  translation: offset,
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int current = widget.currentIndex;
    _tab(current); // ensure built

    final List<int> built = _tabs.keys.toList()..sort();
    final int? from = _from;

    // Paint order: idle tabs, outgoing tab, then the incoming/current tab on top.
    final List<Widget> children = [
      for (final i in built)
        if (i != current && i != from) _slot(i, _TabRole.idle),
      if (from != null && from != current) _slot(from, _TabRole.outgoing),
      _slot(current, _TabRole.current),
      Positioned.fill(
        key: const ValueKey<String>('lucid_prism_wave'),
        child: LucidPrismWave(
          animation: _controller,
          isForward: _isForward,
          isDark: isDark,
        ),
      ),
    ];

    return Stack(fit: StackFit.expand, children: children);
  }
}

/// Shared helper exposing the sine pulse used for synchronized nav-bar effects.
double lucidPulse(double t) => math.sin(t.clamp(0.0, 1.0) * math.pi);
