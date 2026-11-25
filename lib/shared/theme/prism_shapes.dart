import 'package:flutter/material.dart';

enum CornerStyle { rounded, angular }

@immutable
class PrismShapes extends ThemeExtension<PrismShapes> {
  final CornerStyle cornerStyle;

  /// How round corners are when [cornerStyle] is rounded: 1 = Prism's
  /// normal corners, smaller = flatter (from the Look editor's corner
  /// setting), 0 = square. Angular mode is always 0.
  final double roundnessScale;
  const PrismShapes({required this.cornerStyle, this.roundnessScale = 1});

  /// 0 (square) … 1 (fully round) for everything in the app.
  double get roundness =>
      cornerStyle == CornerStyle.angular ? 0 : roundnessScale.clamp(0.0, 1.0);

  static const PrismShapes rounded = PrismShapes(
    cornerStyle: CornerStyle.rounded,
  );
  static const PrismShapes angular = PrismShapes(
    cornerStyle: CornerStyle.angular,
  );

  /// Access from a BuildContext. Falls back to `rounded` if extension is missing.
  static PrismShapes of(BuildContext context) =>
      Theme.of(context).extension<PrismShapes>() ?? PrismShapes.rounded;

  /// Context-free default for const/static contexts. Always rounded.
  static const PrismShapes defaults = PrismShapes.rounded;

  /// Returns [value] when rounded, 0 when angular. Use for body radii.
  double radius(double value) => value * roundness;

  /// Returns [height] / 2 when rounded (pill), 0 when angular.
  double pill(double height) => height / 2 * roundness;

  /// Shape for avatar-like surfaces.
  BoxShape avatarShape() =>
      roundness >= 0.999 ? BoxShape.circle : BoxShape.rectangle;

  /// BorderRadius for avatars in angular mode (null in rounded — circle doesn't use it).
  BorderRadius? avatarBorderRadius([double size = 48]) =>
      roundness >= 0.999 ? null : BorderRadius.circular(size / 2 * roundness);

  /// Radius for something that is a circle in fully-round mode: a circle
  /// at full roundness, squarer as roundness goes down. [size] (the
  /// shortest side) keeps the curve proportional when known.
  BorderRadius roundFor([double? size]) {
    final r = roundness;
    if (r >= 0.999) return BorderRadius.circular(9999);
    if (r <= 0) return BorderRadius.zero;
    return BorderRadius.circular(size == null ? 22 * r : size / 2 * r);
  }

  /// CircleBorder in rounded, zero-radius RoundedRectangleBorder in angular.
  /// For FAB, circle icon buttons.
  ShapeBorder circleOrSquareBorder() => roundness >= 0.999
      ? const CircleBorder()
      : RoundedRectangleBorder(borderRadius: roundFor());

  @override
  PrismShapes copyWith({CornerStyle? cornerStyle, double? roundnessScale}) =>
      PrismShapes(
        cornerStyle: cornerStyle ?? this.cornerStyle,
        roundnessScale: roundnessScale ?? this.roundnessScale,
      );

  /// No meaningful interpolation — shape is discrete. Snap at t >= 0.5.
  /// rounded↔angular is a deliberate aesthetic switch, not a continuous value.
  @override
  PrismShapes lerp(ThemeExtension<PrismShapes>? other, double t) {
    if (other is! PrismShapes) return this;
    return t < 0.5 ? this : other;
  }
}

/// A corner radius scaled by the app's roundness (Squared = 0).
BorderRadius prismCorners(BuildContext context, double radius) =>
    BorderRadius.circular(radius * PrismShapes.of(context).roundness);

/// A single corner [Radius] scaled by the app's roundness.
Radius prismRadius(BuildContext context, double radius) =>
    Radius.circular(radius * PrismShapes.of(context).roundness);

/// Round-aware stand-ins for always-circular widgets. They follow the
/// app's Squared/Rounded setting and the Look editor's corner roundness.
BorderRadius prismRound(BuildContext context, [double? size]) =>
    PrismShapes.of(context).roundFor(size);

ShapeBorder prismCircleBorder(
  BuildContext context, {
  BorderSide side = BorderSide.none,
}) {
  final s = PrismShapes.of(context);
  return s.roundness >= 0.999
      ? CircleBorder(side: side)
      : RoundedRectangleBorder(borderRadius: s.roundFor(), side: side);
}

/// Replaces [ClipOval].
class PrismClipRound extends StatelessWidget {
  const PrismClipRound({
    super.key,
    this.child,
    this.clipBehavior = Clip.antiAlias,
  });
  final Widget? child;
  final Clip clipBehavior;
  @override
  Widget build(BuildContext context) {
    final s = PrismShapes.of(context);
    if (s.roundness >= 0.999)
      return ClipOval(clipBehavior: clipBehavior, child: child);
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.biggest.shortestSide.isFinite
            ? box.biggest.shortestSide
            : null;
        return ClipRRect(
          borderRadius: s.roundFor(side),
          clipBehavior: clipBehavior,
          child: child,
        );
      },
    );
  }
}

/// Replaces [CircleAvatar] with the same common parameters.
class PrismCircleAvatar extends StatelessWidget {
  const PrismCircleAvatar({
    super.key,
    this.radius,
    this.backgroundColor,
    this.foregroundColor,
    this.backgroundImage,
    this.foregroundImage,
    this.child,
    this.minRadius,
    this.maxRadius,
    this.onBackgroundImageError,
  });
  final double? radius;
  final double? minRadius, maxRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final ImageProvider? backgroundImage;
  final ImageProvider? foregroundImage;
  final Widget? child;
  final ImageErrorListener? onBackgroundImageError;

  @override
  Widget build(BuildContext context) {
    final s = PrismShapes.of(context);
    if (s.roundness >= 0.999) {
      return CircleAvatar(
        radius: radius,
        minRadius: minRadius,
        maxRadius: maxRadius,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        backgroundImage: backgroundImage,
        foregroundImage: foregroundImage,
        onBackgroundImageError: onBackgroundImageError,
        child: child,
      );
    }
    final theme = Theme.of(context);
    final r = radius ?? minRadius ?? maxRadius ?? 20;
    final bg = backgroundColor ?? theme.colorScheme.primaryContainer;
    final fg = foregroundColor ?? theme.colorScheme.onPrimaryContainer;
    final img = foregroundImage ?? backgroundImage;
    return Container(
      width: r * 2,
      height: r * 2,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: s.roundFor(r * 2),
        image: img == null
            ? null
            : DecorationImage(
                image: img,
                fit: BoxFit.cover,
                onError: onBackgroundImageError,
              ),
      ),
      alignment: Alignment.center,
      child: child == null
          ? null
          : DefaultTextStyle.merge(
              style: TextStyle(color: fg),
              child: IconTheme.merge(
                data: IconThemeData(color: fg),
                child: child!,
              ),
            ),
    );
  }
}
