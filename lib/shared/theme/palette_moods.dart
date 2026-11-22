import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import 'package:prism_plurality/domain/models/system_settings.dart';

/// User-chosen accents for [PaletteMood.custom] (ARGB ints).
@immutable
class CustomPaletteAccents {
  const CustomPaletteAccents({this.secondary, this.tertiary});

  final int? secondary;
  final int? tertiary;

  static const none = CustomPaletteAccents();

  @override
  bool operator ==(Object other) =>
      other is CustomPaletteAccents &&
      other.secondary == secondary &&
      other.tertiary == tertiary;

  @override
  int get hashCode => Object.hash(secondary, tertiary);
}

/// One accent role (primary, secondary or tertiary) as a hue and chroma in
/// HCT space, so its tones can be picked for light, medium or dark.
typedef _Accent = ({double hue, double chroma});

/// How bright the accent roles sit for a mood.
enum _ToneStyle { standard, pastel, jewel }

class _MoodRecipe {
  const _MoodRecipe({
    required this.base,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    this.tones = _ToneStyle.standard,
  });

  /// Material variant for surfaces and neutrals.
  final DynamicSchemeVariant base;
  final _Accent primary;
  final _Accent secondary;
  final _Accent tertiary;
  final _ToneStyle tones;
}

/// Builds palette colour schemes for every [PaletteMood].
///
/// The first moods map straight onto Material's dynamic scheme variants.
/// Prism moods start from a Material scheme for surfaces and then place the
/// three accents around the seed colour (harmonies, pastel, jewel tones…),
/// each with properly matched on-colours and containers.
abstract final class PaletteMoods {
  /// Material variant behind a mood (for the Prism moods: their surfaces).
  static DynamicSchemeVariant variantFor(PaletteMood mood) => switch (mood) {
    PaletteMood.tonal => DynamicSchemeVariant.tonalSpot,
    PaletteMood.vibrant => DynamicSchemeVariant.vibrant,
    PaletteMood.expressive => DynamicSchemeVariant.expressive,
    PaletteMood.fidelity => DynamicSchemeVariant.fidelity,
    PaletteMood.monochrome => DynamicSchemeVariant.monochrome,
    PaletteMood.neutral => DynamicSchemeVariant.neutral,
    PaletteMood.content => DynamicSchemeVariant.content,
    PaletteMood.rainbow => DynamicSchemeVariant.rainbow,
    PaletteMood.fruitSalad => DynamicSchemeVariant.fruitSalad,
    PaletteMood.neon || PaletteMood.sunset || PaletteMood.candy =>
      DynamicSchemeVariant.vibrant,
    PaletteMood.jewel => DynamicSchemeVariant.fidelity,
    PaletteMood.earthy => DynamicSchemeVariant.neutral,
    _ => DynamicSchemeVariant.tonalSpot,
  };

  /// True for moods that place their own accents (beyond a Material variant).
  static bool isPrismMood(PaletteMood mood) => mood.index >= PaletteMood.pastel.index;

  /// Moods whose surfaces carry more of the accent colour.
  static bool isColourful(PaletteMood mood) => switch (mood) {
    PaletteMood.tonal ||
    PaletteMood.monochrome ||
    PaletteMood.neutral ||
    PaletteMood.earthy ||
    PaletteMood.pastel => false,
    _ => true,
  };

  static double contrastLevel(PaletteContrast contrast) => switch (contrast) {
    PaletteContrast.soft => -0.25,
    PaletteContrast.standard => 0.0,
    PaletteContrast.high => 0.5,
  };

  /// The colour scheme for [seed] in [mood].
  static ColorScheme scheme({
    required Color seed,
    required PaletteMood mood,
    required Brightness brightness,
    required PaletteContrast contrast,
    CustomPaletteAccents custom = CustomPaletteAccents.none,
  }) {
    final level = contrastLevel(contrast);
    final recipe = _recipe(mood, seed, custom);
    if (recipe == null) {
      return ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        dynamicSchemeVariant: variantFor(mood),
        contrastLevel: level,
      );
    }
    final base = ColorScheme.fromSeed(
      seedColor: _color(recipe.primary, 50),
      brightness: brightness,
      dynamicSchemeVariant: recipe.base,
      contrastLevel: level,
    );
    final dark = brightness == Brightness.dark;
    final p = _roles(recipe.primary, recipe.tones, dark, contrast);
    final s = _roles(recipe.secondary, recipe.tones, dark, contrast);
    final t = _roles(recipe.tertiary, recipe.tones, dark, contrast);
    return base.copyWith(
      primary: p.color,
      onPrimary: p.on,
      primaryContainer: p.container,
      onPrimaryContainer: p.onContainer,
      inversePrimary: _tone(recipe.primary, dark ? 40 : 80),
      surfaceTint: p.color,
      secondary: s.color,
      onSecondary: s.on,
      secondaryContainer: s.container,
      onSecondaryContainer: s.onContainer,
      tertiary: t.color,
      onTertiary: t.on,
      tertiaryContainer: t.container,
      onTertiaryContainer: t.onContainer,
    );
  }

  static _MoodRecipe? _recipe(
    PaletteMood mood,
    Color seed,
    CustomPaletteAccents custom,
  ) {
    if (!isPrismMood(mood)) return null;
    final hct = Hct.fromInt(seed.toARGB32());
    final h = hct.hue;
    // Grey seeds still get a colour to build harmonies from.
    final c = hct.chroma < 8 ? 36.0 : hct.chroma;
    _Accent a(double hue, double chroma) =>
        (hue: _wrap(hue), chroma: chroma);
    double toward(double from, double to, double amount) {
      final d = ((to - from + 540) % 360) - 180;
      return from + d * amount;
    }

    final p = a(h, c.clamp(36, 120).toDouble());
    return switch (mood) {
      PaletteMood.pastel => _MoodRecipe(
        base: variantFor(mood),
        primary: a(h, c.clamp(24, 48).toDouble()),
        secondary: a(h + 40, 30),
        tertiary: a(h - 40, 30),
        tones: _ToneStyle.pastel,
      ),
      PaletteMood.neon => _MoodRecipe(
        base: variantFor(mood),
        primary: a(h, 120),
        secondary: a(h + 50, 110),
        tertiary: a(h - 50, 110),
      ),
      PaletteMood.earthy => _MoodRecipe(
        base: variantFor(mood),
        primary: a(toward(h, 55, 0.6), 34),
        secondary: a(toward(h, 85, 0.6), 26),
        tertiary: a(toward(h, 25, 0.6), 30),
      ),
      PaletteMood.jewel => _MoodRecipe(
        base: variantFor(mood),
        primary: a(h, c.clamp(60, 90).toDouble()),
        secondary: a(h + 60, 64),
        tertiary: a(h - 60, 64),
        tones: _ToneStyle.jewel,
      ),
      PaletteMood.sunset => _MoodRecipe(
        base: variantFor(mood),
        primary: a(toward(h, 30, 0.4), c.clamp(56, 100).toDouble()),
        secondary: a(60, 64),
        tertiary: a(350, 60),
      ),
      PaletteMood.ocean => _MoodRecipe(
        base: variantFor(mood),
        primary: a(toward(h, 240, 0.4), c.clamp(44, 80).toDouble()),
        secondary: a(195, 44),
        tertiary: a(265, 40),
      ),
      PaletteMood.forest => _MoodRecipe(
        base: variantFor(mood),
        primary: a(toward(h, 145, 0.45), c.clamp(36, 64).toDouble()),
        secondary: a(105, 34),
        tertiary: a(70, 30),
      ),
      PaletteMood.candy => _MoodRecipe(
        base: variantFor(mood),
        primary: a(h, c.clamp(56, 96).toDouble()),
        secondary: a(350, 60),
        tertiary: a(185, 48),
        tones: _ToneStyle.pastel,
      ),
      PaletteMood.complementary => _MoodRecipe(
        base: variantFor(mood),
        primary: p,
        secondary: a(h + 180, 44),
        tertiary: a(h + 180, 26),
      ),
      PaletteMood.analogous => _MoodRecipe(
        base: variantFor(mood),
        primary: p,
        secondary: a(h + 30, 42),
        tertiary: a(h - 30, 42),
      ),
      PaletteMood.triadic => _MoodRecipe(
        base: variantFor(mood),
        primary: p,
        secondary: a(h + 120, 44),
        tertiary: a(h + 240, 44),
      ),
      PaletteMood.splitComplementary => _MoodRecipe(
        base: variantFor(mood),
        primary: p,
        secondary: a(h + 150, 44),
        tertiary: a(h + 210, 44),
      ),
      PaletteMood.custom => _MoodRecipe(
        base: DynamicSchemeVariant.tonalSpot,
        primary: p,
        secondary: custom.secondary == null
            ? a(h + 30, 42)
            : _accentOf(custom.secondary!),
        tertiary: custom.tertiary == null
            ? a(h - 30, 42)
            : _accentOf(custom.tertiary!),
      ),
      _ => null,
    };
  }

  static _Accent _accentOf(int argb) {
    final hct = Hct.fromInt(argb);
    return (hue: hct.hue, chroma: hct.chroma);
  }

  static ({Color color, Color on, Color container, Color onContainer}) _roles(
    _Accent a,
    _ToneStyle style,
    bool dark,
    PaletteContrast contrast,
  ) {
    // Material's tones (light 40/100/90/10, dark 80/20/30/90), shifted per
    // mood: pastel sits lighter, jewel deeper.
    var (color, on, container, onContainer) = switch ((style, dark)) {
      (_ToneStyle.standard, false) => (40.0, 100.0, 90.0, 10.0),
      (_ToneStyle.standard, true) => (80.0, 20.0, 30.0, 90.0),
      (_ToneStyle.pastel, false) => (50.0, 100.0, 94.0, 20.0),
      (_ToneStyle.pastel, true) => (86.0, 24.0, 38.0, 94.0),
      (_ToneStyle.jewel, false) => (34.0, 100.0, 86.0, 10.0),
      (_ToneStyle.jewel, true) => (72.0, 14.0, 26.0, 92.0),
    };
    final shift = switch (contrast) {
      PaletteContrast.soft => dark ? -4.0 : 6.0,
      PaletteContrast.standard => 0.0,
      PaletteContrast.high => dark ? 8.0 : -12.0,
    };
    color = (color + shift).clamp(5, 95).toDouble();
    if (contrast == PaletteContrast.high) {
      container = (container + (dark ? -6 : 4)).clamp(5, 98).toDouble();
      onContainer = dark ? 98 : 4;
    }
    return (
      color: _tone(a, color),
      on: _tone(a, on),
      container: _tone(a, container),
      onContainer: _tone(a, onContainer),
    );
  }

  static Color _tone(_Accent a, double tone) =>
      Color(TonalPalette.of(a.hue, a.chroma).get(tone.round()));

  static Color _color(_Accent a, double tone) => _tone(a, tone);

  static double _wrap(double hue) => ((hue % 360) + 360) % 360;
}
