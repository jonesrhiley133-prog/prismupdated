import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:prism_plurality/domain/models/system_settings.dart';
import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';
import 'package:prism_plurality/shared/theme/palette_moods.dart';
import 'package:prism_plurality/shared/theme/prism_theme_flavor.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double _hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  const seed = Color(0xFF7E57C2);

  test('stored indexes of existing values never move', () {
    // Moods and brightness are stored and synced by index.
    expect(PaletteMood.tonal.index, 0);
    expect(PaletteMood.vibrant.index, 1);
    expect(PaletteMood.expressive.index, 2);
    expect(PaletteMood.fidelity.index, 3);
    expect(PaletteMood.monochrome.index, 4);
    expect(ThemeBrightness.system.index, 0);
    expect(ThemeBrightness.light.index, 1);
    expect(ThemeBrightness.dark.index, 2);
    expect(ThemeBrightness.medium.index, 3);
  });

  test('every mood builds a readable scheme in light and dark', () {
    for (final mood in PaletteMood.values) {
      for (final b in Brightness.values) {
        final s = AppTheme.paletteScheme(
          seed: seed,
          mood: mood,
          brightness: b,
          contrast: PaletteContrast.standard,
        );
        expect(s.brightness, b, reason: '$mood $b');
        expect(
          _contrast(s.onPrimary, s.primary),
          greaterThan(3),
          reason: '$mood $b onPrimary',
        );
        expect(
          _contrast(s.onSecondaryContainer, s.secondaryContainer),
          greaterThan(3),
          reason: '$mood $b onSecondaryContainer',
        );
      }
    }
  });

  test('moods differ from each other', () {
    final seen = <int>{};
    for (final mood in PaletteMood.values) {
      final s = AppTheme.paletteScheme(
        seed: seed,
        mood: mood,
        brightness: Brightness.dark,
        contrast: PaletteContrast.standard,
      );
      seen.add(Object.hash(s.primary, s.secondary, s.tertiary));
    }
    // Custom falls back to analogous accents until colours are picked.
    expect(seen.length, greaterThanOrEqualTo(PaletteMood.values.length - 1));
  });

  test('harmonies place accents around the wheel', () {
    final seedHue = Hct.fromInt(seed.toARGB32()).hue;
    double hueOf(Color c) => Hct.fromInt(c.toARGB32()).hue;
    final comp = AppTheme.paletteScheme(
      seed: seed,
      mood: PaletteMood.complementary,
      brightness: Brightness.dark,
      contrast: PaletteContrast.standard,
    );
    expect(_hueDistance(hueOf(comp.secondary), seedHue), greaterThan(150));
    final tri = AppTheme.paletteScheme(
      seed: seed,
      mood: PaletteMood.triadic,
      brightness: Brightness.dark,
      contrast: PaletteContrast.standard,
    );
    expect(_hueDistance(hueOf(tri.secondary), seedHue), closeTo(120, 20));
  });

  test('custom mood uses the accents the user picked', () {
    const orange = 0xFFFF8A00, teal = 0xFF00A39A;
    final s = AppTheme.paletteScheme(
      seed: seed,
      mood: PaletteMood.custom,
      brightness: Brightness.light,
      contrast: PaletteContrast.standard,
      custom: const CustomPaletteAccents(secondary: orange, tertiary: teal),
    );
    double hue(int argb) => Hct.fromInt(argb).hue;
    expect(
      _hueDistance(hue(s.secondary.toARGB32()), hue(orange)),
      lessThan(12),
    );
    expect(_hueDistance(hue(s.tertiary.toARGB32()), hue(teal)), lessThan(12));
  });

  test('medium sits between dark and light and keeps text readable', () {
    final dark = AppTheme.dark(accentColor: seed);
    final light = AppTheme.light(accentColor: seed);
    final medium = AppTheme.medium(accentColor: seed);
    final l = medium.colorScheme.surface.computeLuminance();
    expect(l, greaterThan(dark.colorScheme.surface.computeLuminance()));
    expect(l, lessThan(light.colorScheme.surface.computeLuminance()));
    expect(medium.brightness, Brightness.dark);
    expect(medium.extension<PrismThemeFlavor>()?.isMedium, isTrue);
    expect(
      _contrast(medium.colorScheme.onSurface, medium.colorScheme.surface),
      greaterThan(4.5),
    );
    expect(
      _contrast(medium.colorScheme.primary, medium.colorScheme.surface),
      greaterThan(3),
    );

    final paletteMedium = AppTheme.materialYouMedium(
      null,
      null,
      paletteSource: PaletteSource.custom,
      paletteSeedColorHex: '#7E57C2',
      paletteMood: PaletteMood.ocean,
    );
    expect(paletteMedium.extension<PrismThemeFlavor>()?.isMedium, isTrue);
    expect(
      _contrast(
        paletteMedium.colorScheme.onSurface,
        paletteMedium.colorScheme.surface,
      ),
      greaterThan(4.5),
    );
    // A member palette built on a medium page stays medium.
    final local = AppTheme.localPaletteTheme(
      paletteMedium,
      seedColor: const Color(0xFF2E7D32),
      paletteMood: PaletteMood.forest,
    );
    expect(local.extension<PrismThemeFlavor>()?.isMedium, isTrue);
  });

  test('custom accents survive an appearance round trip', () {
    const state = AppearanceState(
      customSecondary: 0xFFFF8A00,
      customTertiary: 0xFF00A39A,
    );
    final back = AppearanceState.fromJson(state.toJson());
    expect(back.customSecondary, 0xFFFF8A00);
    expect(back.customTertiary, 0xFF00A39A);
    final cleared = back.copyWith(customSecondary: null);
    expect(cleared.customSecondary, isNull);
    expect(cleared.customTertiary, 0xFF00A39A);
    expect(AppearanceState.fromJson(const {}).customSecondary, isNull);
  });
}
