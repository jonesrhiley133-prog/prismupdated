import 'dart:math' as math;

/// Aspect-ratio choices offered by Prism's shared image cropper.
///
/// A `null` [ratio] means freeform cropping (the crop box can take any
/// proportion); `1.0` doubles as the circular-preview ratio when the caller
/// requested a circle mask.
class PrismCropRatio {
  const PrismCropRatio(this.id, this.label, this.ratio);

  final String id;
  final String label;
  final double? ratio;

  static const freeform = PrismCropRatio('free', 'Free', null);
  static const square = PrismCropRatio('square', 'Square', 1);
  static const portrait3x4 = PrismCropRatio('3x4', '3:4', 3 / 4);
  static const portrait9x16 = PrismCropRatio('9x16', '9:16', 9 / 16);
  static const landscape4x3 = PrismCropRatio('4x3', '4:3', 4 / 3);
  static const landscape16x9 = PrismCropRatio('16x9', '16:9', 16 / 9);
  static const bannerWide = PrismCropRatio('banner', 'Banner', 3 / 1);

  /// Ratio presets shown in the cropper UI. Custom ratios can be appended by
  /// callers via [showPrismImageCropper]'s `extraRatios` parameter.
  static const defaults = [
    freeform,
    square,
    portrait3x4,
    portrait9x16,
    landscape4x3,
    landscape16x9,
    bannerWide,
  ];
}

/// Extra options for Prism's centralized image cropper so every import point
/// (avatars, banners, scrapbook covers, stickers, ID cards, decorations, …)
/// shares one interface with the same behaviour.
class PrismImageCropOptions {
  const PrismImageCropOptions({
    this.initialRatio = PrismCropRatio.freeform,
    this.extraRatios = const [],
    this.circularPreview = false,
    this.allowFlip = true,
    this.allowReset = true,
    this.showZoomHint = true,
  });

  /// Ratio the crop box starts with.
  final PrismCropRatio initialRatio;

  /// Additional custom aspect ratios appended after the defaults.
  final List<PrismCropRatio> extraRatios;

  /// Draw a circular guide over the crop window (for avatars/stickers).
  final bool circularPreview;

  /// Show horizontal/vertical flip buttons.
  final bool allowFlip;

  /// Show a reset button restoring rotation, flips and the full crop area.
  final bool allowReset;

  /// Brief hint that pinch zooms and dragging inside the box repositions.
  final bool showZoomHint;

  List<PrismCropRatio> get ratios => [...PrismCropRatio.defaults, ...extraRatios];
}

/// Horizontal/vertical mirror state applied before cropping.
enum PrismCropFlip { none, horizontal, vertical, both }

extension PrismCropFlipMatrix on PrismCropFlip {
  /// Scale factors for [Transform] around the image centre.
  Offset2 get scale => switch (this) {
        PrismCropFlip.none => const Offset2(1, 1),
        PrismCropFlip.horizontal => const Offset2(-1, 1),
        PrismCropFlip.vertical => const Offset2(1, -1),
        PrismCropFlip.both => const Offset2(-1, -1),
      };

  PrismCropFlip toggledHorizontal() => switch (this) {
        PrismCropFlip.none => PrismCropFlip.horizontal,
        PrismCropFlip.horizontal => PrismCropFlip.none,
        PrismCropFlip.vertical => PrismCropFlip.both,
        PrismCropFlip.both => PrismCropFlip.vertical,
      };

  PrismCropFlip toggledVertical() => switch (this) {
        PrismCropFlip.none => PrismCropFlip.vertical,
        PrismCropFlip.vertical => PrismCropFlip.none,
        PrismCropFlip.horizontal => PrismCropFlip.both,
        PrismCropFlip.both => PrismCropFlip.horizontal,
      };
}

/// Minimal immutable 2D offset used outside Flutter widget code (tests).
class Offset2 {
  const Offset2(this.x, this.y);
  final double x;
  final double y;
}

/// Rotation snapping helper: snaps arbitrary angles to the nearest quarter
/// turn when within [tolerance] radians (used by the cropper's rotate drag).
double snapRotation(double radians, {double tolerance = 0.12}) {
  final quarter = math.pi / 2;
  final nearest = (radians / quarter).roundToDouble() * quarter;
  return (radians - nearest).abs() <= tolerance ? nearest % (2 * math.pi) : radians;
}
