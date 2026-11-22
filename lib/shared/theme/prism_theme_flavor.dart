import 'package:flutter/material.dart';

/// Carries whether the active theme is the user-driven Palette flavor (which
/// paints surfaces and decorative elements with the seeded accent) or one of
/// the standard flavors (light, dark, OLED — where accent should stay scarce
/// and reserved for functional signals like the FAB, switches, progress
/// indicators, and focus rings).
///
/// Widgets that want to scale back accent decoration in standard mode read
/// this via [PrismThemeFlavor.of] and branch on [isPalette].
@immutable
class PrismThemeFlavor extends ThemeExtension<PrismThemeFlavor> {
  const PrismThemeFlavor({required this.isPalette, this.isMedium = false});

  final bool isPalette;

  /// Built for the medium tone (mid-tone surfaces, light text).
  final bool isMedium;

  static const PrismThemeFlavor standard = PrismThemeFlavor(isPalette: false);
  static const PrismThemeFlavor palette = PrismThemeFlavor(isPalette: true);

  /// Reads the flavor from a [BuildContext]. Falls back to standard when the
  /// extension is missing (e.g. previews, tests).
  static PrismThemeFlavor of(BuildContext context) =>
      Theme.of(context).extension<PrismThemeFlavor>() ?? standard;

  @override
  PrismThemeFlavor copyWith({bool? isPalette, bool? isMedium}) =>
      PrismThemeFlavor(
        isPalette: isPalette ?? this.isPalette,
        isMedium: isMedium ?? this.isMedium,
      );

  /// Flavor is discrete — snap at the halfway point rather than blending.
  @override
  PrismThemeFlavor lerp(ThemeExtension<PrismThemeFlavor>? other, double t) {
    if (other is! PrismThemeFlavor) return this;
    return t < 0.5 ? this : other;
  }
}
