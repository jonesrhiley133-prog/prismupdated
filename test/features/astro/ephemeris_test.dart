import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';

/// Reference values from PyEphem (apparent geocentric ecliptic longitude of
/// date; Ascendant/MC found by scanning the ecliptic against the horizon and
/// meridian). See ephemeris_reference.json.
void main() {
  final ref =
      jsonDecode(
            File('test/features/astro/ephemeris_reference.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  const tolerance = {
    Body.sun: 0.05,
    Body.moon: 0.3,
    Body.mercury: 0.15,
    Body.venus: 0.15,
    Body.mars: 0.15,
    Body.jupiter: 0.15,
    Body.saturn: 0.15,
    Body.uranus: 0.15,
    Body.neptune: 0.15,
    Body.pluto: 0.25,
  };

  test('planet longitudes match PyEphem across 1950–2041', () {
    for (final row in (ref['positions'] as List).cast<Map<String, dynamic>>()) {
      final utc = DateTime.parse(row['utc'] as String);
      for (final e in tolerance.entries) {
        final expected = (row[e.key.name] as num).toDouble();
        final got = longitudeOf(e.key, utc);
        expect(
          angleDiff(got, expected).abs(),
          lessThan(e.value),
          reason: '${e.key.name} at ${row['utc']}: $got vs $expected',
        );
      }
    }
  });

  test('ascendant and midheaven match the horizon and meridian', () {
    for (final row in (ref['angles'] as List).cast<Map<String, dynamic>>()) {
      final utc = DateTime.parse(row['utc'] as String);
      final a = anglesAt(
        utc,
        (row['lat'] as num).toDouble(),
        (row['lon'] as num).toDouble(),
      );
      final why = '${row['place']} ${row['utc']}';
      expect(
        angleDiff(a.ascendant, (row['asc'] as num).toDouble()).abs(),
        lessThan(0.3),
        reason: 'ASC $why: ${a.ascendant} vs ${row['asc']}',
      );
      expect(
        angleDiff(a.midheaven, (row['mc'] as num).toDouble()).abs(),
        lessThan(0.3),
        reason: 'MC $why: ${a.midheaven} vs ${row['mc']}',
      );
    }
  });

  test('placidus cusps are ordered and fall back near the poles', () {
    final utc = DateTime.utc(1988, 11, 2, 3, 5);
    final a = anglesAt(utc, 51.5, -0.13);
    expect(a.system, HouseSystem.placidus);
    for (var h = 0; h < 12; h++) {
      final span = norm360(a.cusps[(h + 1) % 12] - a.cusps[h]);
      expect(span, inExclusiveRange(0, 90), reason: 'house ${h + 1}');
    }
    expect(a.houseOf(a.ascendant + 1), 1);
    expect(a.houseOf(a.midheaven + 1), 10);
    final polar = anglesAt(utc, 78.2, 15.6);
    expect(polar.system, HouseSystem.equal);
  });

  test('retrograde detection: Mercury retrograde on 2019-07-20', () {
    expect(positionOf(Body.mercury, DateTime.utc(2019, 7, 20)).retrograde, isTrue);
    expect(positionOf(Body.mercury, DateTime.utc(2019, 9, 1)).retrograde, isFalse);
  });

  test('Chiron is roughly right (Aries in 2020, Pisces in 2012)', () {
    expect(signOf(longitudeOf(Body.chiron, DateTime.utc(2020, 6, 1))), 0);
    expect(signOf(longitudeOf(Body.chiron, DateTime.utc(2013, 6, 1))), 11);
    expect(signOf(longitudeOf(Body.chiron, DateTime.utc(1996, 2, 14))), 6);
  });
}
