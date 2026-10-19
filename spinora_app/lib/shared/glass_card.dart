import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A reusable glassmorphic container widget.
///
/// Dynamically adapts between Dark Cosmos frosted glass and Apple-grade
/// Light Lucid Glass (ultra-clean frosted white glass with soft shadow depth
/// and iridescent highlights).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.customShadow,
    this.customFillColor,
    this.customBorderColor,
  });

  final Widget? child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? customShadow;
  final Color? customFillColor;
  final Color? customBorderColor;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(24);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fillColor = customFillColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.78));

    final borderColor = customBorderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.90));

    final shadows = customShadow ??
        (isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : AppTheme.lightCardShadow);

    Widget card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: effectiveRadius,
              border: Border.all(
                color: borderColor,
                width: isDark ? 1.0 : 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (margin != null) {
      card = Padding(
        padding: margin!,
        child: card,
      );
    }

    return card;
  }
}
