import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:prism_plurality/core/graphics/graphics_engine.dart';

/// Live backdrop blur for glass surfaces, scaled to the graphics budget.
///
/// Backdrop blur is one of the most expensive GPU operations (it reads back
/// and filters everything behind the surface every frame). At lower quality
/// the blur radius shrinks; when live blur is off, the surface gets a
/// slightly more opaque underlay instead, so text stays just as readable.
class PrismBackdropBlur extends StatelessWidget {
  const PrismBackdropBlur({
    super.key,
    required this.sigma,
    required this.child,
  });
  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final q = GraphicsScope.of(context);
    if (q.liveBlur) {
      final s = q.sigma(sigma);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: s, sigmaY: s),
        child: child,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.55)),
      child: child,
    );
  }
}
