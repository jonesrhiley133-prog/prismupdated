import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/astro/engine/chart.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';
import 'package:prism_plurality/features/astro/engine/events.dart';

void main() {
  final ref =
      jsonDecode(
            File(
              'test/features/astro/events_reference.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final from = DateTime.utc(2024, 1, 1);
  final to = DateTime.utc(2027, 12, 31);
  final all = lunations(from, to);

  void checkPhase(String key, MoonPhase phase) {
    final expected = [
      for (final s in (ref[key] as List).cast<String>()) DateTime.parse(s),
    ].where((d) => d.isBefore(to)).toList();
    final got = [
      for (final l in all)
        if (l.phase == phase) l.utc,
    ];
    expect(got.length, expected.length, reason: key);
    for (var i = 0; i < got.length; i++) {
      expect(
        got[i].difference(expected[i]).inMinutes.abs(),
        lessThan(20),
        reason: '$key ${expected[i]} vs ${got[i]}',
      );
    }
  }

  test('new, quarter and full moons match PyEphem within 20 minutes', () {
    checkPhase('new', MoonPhase.newMoon);
    checkPhase('first', MoonPhase.firstQuarter);
    checkPhase('full', MoonPhase.fullMoon);
    checkPhase('last', MoonPhase.lastQuarter);
  });

  test('Sun sign changes match within 15 minutes', () {
    final got = ingresses(Body.sun, from, to);
    final expected = (ref['sunIngress'] as List).cast<List>();
    expect(got.length, expected.length);
    for (var i = 0; i < got.length; i++) {
      expect(got[i].sign, expected[i][1]);
      expect(
        got[i].utc
            .difference(DateTime.parse(expected[i][0] as String))
            .inMinutes
            .abs(),
        lessThan(15),
      );
    }
  });

  test('known eclipses are flagged', () {
    Lunation near(DateTime d) => all.reduce(
      (a, b) => a.utc.difference(d).abs() < b.utc.difference(d).abs() ? a : b,
    );
    expect(near(DateTime.utc(2024, 4, 8, 18)).eclipse, Eclipse.solar);
    expect(near(DateTime.utc(2026, 8, 12, 17)).eclipse, Eclipse.solar);
    expect(near(DateTime.utc(2026, 2, 17, 12)).eclipse, Eclipse.solar);
    expect(near(DateTime.utc(2025, 9, 7, 18)).eclipse, Eclipse.lunar);
    expect(near(DateTime.utc(2026, 3, 3, 11)).eclipse, Eclipse.lunar);
    // An ordinary full moon is not.
    expect(near(DateTime.utc(2026, 6, 29, 23)).eclipse, Eclipse.none);
  });

  test('Mercury stations in 2024', () {
    final s = stations(Body.mercury, from, DateTime.utc(2024, 12, 31));
    final retro = [
      for (final x in s)
        if (x.toRetrograde) x.utc,
    ];
    expect(retro.length, 3);
    expect(retro.first.month, 4); // 1 April 2024
    expect(retro.first.day, 1);
  });

  test('sun sign from month and day, with cusps', () {
    expect(sunSignForDate(7, 4), (3, null)); // Cancer
    expect(sunSignForDate(1, 1), (9, null)); // Capricorn
    expect(sunSignForDate(3, 21).$1, 0); // Aries, cusp with Pisces
    expect(sunSignForDate(3, 21).$2, 11);
    expect(sunSignForDate(4, 19), (0, 1)); // Aries, next day Taurus
  });
}
