import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';

void main() {
  final light = ThemeData(brightness: Brightness.light, colorSchemeSeed: Colors.purple);
  final dark = ThemeData(brightness: Brightness.dark, colorSchemeSeed: Colors.purple);

  const midnight = PrismLook(
    id: 'm',
    name: 'Midnight',
    dark: true,
    colors: {'accent': 0xFF00E5FF, 'background': 0xFF000000, 'surface': 0xFF0B0B10, 'text': 0xFFEFFFFF},
  );

  test('palette roles recolour the colour scheme and components', () {
    final t = applyLook(dark, midnight, opposite: light);
    expect(t.colorScheme.primary, const Color(0xFF00E5FF));
    expect(t.colorScheme.surface, const Color(0xFF0B0B10));
    expect(t.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(t.colorScheme.onSurface, const Color(0xFFEFFFFF));
    expect(t.extension<LookTheme>()?.look, same(midnight));
  });

  test('a dark preset used in light mode builds on the dark base', () {
    final t = applyLook(light, midnight, opposite: dark);
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, const Color(0xFF000000));
  });

  test('unreadable text colours are replaced automatically', () {
    const bad = PrismLook(id: 'b', name: 'Bad', colors: {'surface': 0xFF000000, 'text': 0xFF050505});
    final t = applyLook(dark, bad, opposite: light);
    final contrast = (t.colorScheme.onSurface.computeLuminance() + 0.05) / (0xFF000000 == 0 ? 1 : 0.05);
    expect(contrast, greaterThan(4.5));
  });

  test('page presets are built from the clean base, not stacked on the app preset', () {
    const appLook = PrismLook(id: 'a', name: 'App', colors: {'text': 0xFFFF0000});
    const pageLook = PrismLook(id: 'p', name: 'Page', colors: {'accent': 0xFF00FF00});
    final app = applyLook(light, appLook, opposite: dark);
    final page = app.extension<LookTheme>()!.themeFor(pageLook, Brightness.light);
    expect(page.colorScheme.primary, const Color(0xFF00FF00));
    expect(page.colorScheme.onSurface, isNot(const Color(0xFFFF0000)));
  });

  test('alter accents keep the active preset (surfaces, background, extension)', () {
    final app = applyLook(dark, midnight, opposite: light);
    final profile = withAccent(app, const Color(0xFFFF4081));
    expect(profile.colorScheme.primary, const Color(0xFFFF4081));
    expect(profile.colorScheme.surface, const Color(0xFF0B0B10));
    expect(profile.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(profile.extension<LookTheme>(), isNotNull);
  });

  test('alter palette themes also keep the preset', () {
    final app = applyLook(dark, midnight, opposite: light);
    final palette = ThemeData(brightness: Brightness.dark, colorSchemeSeed: Colors.pink);
    final profile = withAccent(app, const Color(0xFFFF4081), palette: palette);
    expect(profile.colorScheme.primary, palette.colorScheme.primary);
    expect(profile.colorScheme.surface, const Color(0xFF0B0B10));
    expect(profile.extension<LookTheme>(), isNotNull);
  });

  test('looks round-trip their colours through JSON', () {
    final back = PrismLook.fromJson(midnight.toJson())!;
    expect(back.colors, midnight.colors);
    expect(back.dark, isTrue);
  });

  test('theme switches are marked so animations can skip', () {
    ThemeSwitch.observe('a');
    ThemeSwitch.observe('b');
    expect(themeAware(const Duration(milliseconds: 200)), Duration.zero);
  });
}
