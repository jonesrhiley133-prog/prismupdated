import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';

void main() {
  test('a dark background never forces dark mode', () {
    const look = PrismLook(
      id: 'mine',
      name: 'Mine',
      background: BgSpec(kind: BgKind.builtin, builtin: 'milkyWay'),
    );
    expect(lookBrightness(look), isNull);
    const night = PrismLook(
      id: 'n',
      name: 'Night',
      background: BgSpec(kind: BgKind.builtin, builtin: 'night'),
    );
    expect(lookBrightness(night), isNull);
    // Light and dark themes both keep their own brightness.
    final light = applyLook(
      ThemeData.light(),
      look,
      opposite: ThemeData.dark(),
    );
    final dark = applyLook(ThemeData.dark(), look, opposite: ThemeData.light());
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
  });

  test('a theme marked for one mode still says so', () {
    const darkOnly = PrismLook(id: 'd', name: 'D', dark: true);
    expect(lookBrightness(darkOnly), Brightness.dark);
    expect(lookBrightness(darkOnly.copyWith(dark: null)), isNull);
  });

  testWidgets('a background made for the other mode gets a readable wash', (
    t,
  ) async {
    Future<int> washes(ThemeData theme) async {
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const LookBackground(
            spec: BgSpec(kind: BgKind.color, color: 0xFF050505),
          ),
        ),
      );
      return t
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where(
            (b) =>
                b.color ==
                theme.scaffoldBackgroundColor.withValues(alpha: 0.62),
          )
          .length;
    }

    expect(await washes(ThemeData.light()), 1);
    expect(await washes(ThemeData.dark()), 0);
  });
}
