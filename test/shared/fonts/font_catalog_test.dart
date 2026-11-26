import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prism_plurality/shared/fonts/font_catalog.dart';

void main() {
  test('at least 150 distinct families, none duplicated', () {
    final names = fontCatalog.map((f) => f.family).toList();
    expect(names.length, greaterThanOrEqualTo(150));
    expect(names.toSet().length, names.length, reason: 'duplicate family');
  });

  test('every family exists in Google Fonts (so it can load on demand)', () {
    final known = GoogleFonts.asMap();
    final missing = [
      for (final f in fontCatalog)
        if (!known.containsKey(f.family)) f.family,
    ];
    expect(missing, isEmpty);
  });

  test('every category and every required script is covered', () {
    for (final c in fontCategories.keys) {
      expect(
        fontCatalog.where((f) => f.categories.contains(c)),
        isNotEmpty,
        reason: c,
      );
    }
    for (final s in [
      'latin',
      'korean',
      'japanese',
      'chinese',
      'arabic',
      'cyrillic',
      'greek',
    ]) {
      expect(
        fontCatalog.where((f) => f.scripts.contains(s)).length,
        greaterThanOrEqualTo(3),
        reason: s,
      );
    }
  });

  test('all category and script ids are known', () {
    for (final f in fontCatalog) {
      for (final c in f.categories) {
        expect(
          fontCategories.containsKey(c),
          isTrue,
          reason: '${f.family}: $c',
        );
      }
      for (final s in f.scripts) {
        expect(fontScripts.containsKey(s), isTrue, reason: '${f.family}: $s');
      }
    }
  });
}
