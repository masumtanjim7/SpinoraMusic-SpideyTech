import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable glassmorphic container widget.
///
/// Uses [BackdropFilter] with an 18-sigma blur, semi-transparent white fill,
/// subtle white outline, and rounded corners according to Spinora design tokens.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  final Widget? child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(24);

    Widget card = ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: effectiveRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: child,
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
