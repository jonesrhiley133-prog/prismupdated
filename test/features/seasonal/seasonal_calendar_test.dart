import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/seasonal/seasonal_calendar.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  test('Easter is exact', () {
    expect(easterSunday(2024), d(2024, 3, 31));
    expect(easterSunday(2025), d(2025, 4, 20));
    expect(easterSunday(2026), d(2026, 4, 5));
    expect(easterSunday(2027), d(2027, 3, 28));
    expect(easterSunday(2038), d(2038, 4, 25));
  });

  test('Hanukkah (25 Kislev) matches the published dates', () {
    expect(hanukkahStart(2023), d(2023, 12, 8));
    expect(hanukkahStart(2024), d(2024, 12, 26));
    expect(hanukkahStart(2025), d(2025, 12, 15));
    expect(hanukkahStart(2026), d(2026, 12, 5));
    expect(hanukkahStart(2027), d(2027, 12, 25));
  });

  test('Islamic holidays are within two days of the observed dates', () {
    void near(DateTime? got, DateTime want) {
      expect(got, isNotNull);
      expect(
        got!.difference(want).inDays.abs(),
        lessThanOrEqualTo(2),
        reason: '$got vs $want',
      );
    }

    near(islamicDateIn(2024, 9, 1), d(2024, 3, 11)); // Ramadan
    near(islamicDateIn(2025, 9, 1), d(2025, 3, 1));
    near(islamicDateIn(2026, 9, 1), d(2026, 2, 18));
    near(islamicDateIn(2025, 10, 1), d(2025, 3, 30)); // Eid al-Fitr
    near(islamicDateIn(2026, 10, 1), d(2026, 3, 20));
    near(islamicDateIn(2025, 12, 10), d(2025, 6, 6)); // Eid al-Adha
    near(islamicDateIn(2026, 12, 10), d(2026, 5, 27));
  });

  test('lunar new year and other tabled festivals', () {
    expect(lunarNewYear(2026), d(2026, 2, 17));
    expect(lunarNewYear(2027), d(2027, 2, 6));
    expect(midAutumnFestival(2026), d(2026, 9, 25));
    expect(diwaliDate(2026), d(2026, 11, 8));
    expect(holiDate(2026), d(2026, 3, 4));
    expect(lunarNewYear(1990), isNull);
  });

  test('the 4th Thursday of November is Thanksgiving in North America', () {
    expect(nthWeekday(2026, 11, 4, 4), d(2026, 11, 26));
    final w = SeasonalWindows.windowFor(
      'thanksgiving',
      2026,
      region: SeasonalRegion.northAmerica,
    )!;
    expect(w.contains(d(2026, 11, 26)), isTrue);
  });

  test('seasons flip in the southern hemisphere', () {
    final nWinter = SeasonalWindows.windowFor(
      'winter',
      2026,
      hemisphere: Hemisphere.north,
    )!;
    final sWinter = SeasonalWindows.windowFor(
      'winter',
      2026,
      hemisphere: Hemisphere.south,
    )!;
    expect(nWinter.contains(d(2026, 12, 25)), isTrue);
    expect(sWinter.contains(d(2026, 7, 15)), isTrue);
    expect(sWinter.contains(d(2026, 12, 25)), isFalse);
    expect(
      resolveHemisphere(Hemisphere.auto, SeasonalRegion.oceania),
      Hemisphere.south,
    );
    expect(
      resolveHemisphere(Hemisphere.auto, SeasonalRegion.europe),
      Hemisphere.north,
    );
    expect(
      resolveHemisphere(Hemisphere.north, SeasonalRegion.oceania),
      Hemisphere.north,
    );
  });

  test('regional holidays move with the region', () {
    final jp = SeasonalWindows.windowFor(
      'childrensday',
      2026,
      region: SeasonalRegion.eastAsia,
    )!;
    final intl = SeasonalWindows.windowFor('childrensday', 2026)!;
    expect(jp.contains(d(2026, 5, 5)), isTrue);
    expect(intl.contains(d(2026, 6, 1)), isTrue);
    final tsuyu = SeasonalWindows.windowFor(
      'rainy',
      2026,
      region: SeasonalRegion.eastAsia,
    )!;
    expect(tsuyu.contains(d(2026, 6, 20)), isTrue);
  });

  test('every collection has a window for ordinary years', () {
    for (final c in seasonalCollections) {
      for (final y in [2026, 2027, 2030]) {
        final w = SeasonalWindows.windowFor(c.id, y);
        expect(w, isNotNull, reason: '${c.id} $y');
        expect(w!.days, greaterThan(0));
        expect(w.days, lessThan(200));
      }
    }
  });

  test('winter and Kwanzaa windows cross the new year', () {
    final k = SeasonalWindows.windowFor('kwanzaa', 2026)!;
    expect(k.contains(d(2026, 12, 31)), isTrue);
    expect(k.contains(d(2027, 1, 1)), isTrue);
    final w = SeasonalWindows.windowFor(
      'winter',
      2026,
      hemisphere: Hemisphere.north,
    )!;
    expect(w.contains(d(2027, 1, 15)), isTrue);
  });

  test('lunar holidays outside the tables have no automatic date', () {
    expect(SeasonalWindows.windowFor('lunarnewyear', 1990), isNull);
    expect(SeasonalWindows.windowFor('christmas', 1990), isNotNull);
  });
}
