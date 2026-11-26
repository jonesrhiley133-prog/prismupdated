import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/astro/engine/chart.dart';
import 'package:prism_plurality/features/astro/engine/places.dart';

void main() {
  final index = CityIndex.parse(
    File('assets/astro/cities.tsv').readAsStringSync(),
  );

  test('finds cities by prefix, accents and region', () {
    expect(index.cities.length, greaterThan(30000));
    expect(index.search('london').first.country, 'United Kingdom');
    expect(index.search('sao paulo').first.name, 'São Paulo');
    final ca = index.search('london, canada');
    expect(ca.first.region, 'Ontario');
    expect(index.search('springfield').length, greaterThan(3));
    expect(index.search('x'), isEmpty);
  });

  test('historical offsets: daylight saving and pre-1970 rules', () {
    // New York in July 1975: EDT.
    expect(
      utcOffsetAt('America/New_York', 1975, 7, 4, 21, 15),
      const Duration(hours: -4),
    );
    // London in 1968–71 was on British Standard Time (UTC+1) all year.
    expect(
      utcOffsetAt('Europe/London', 1969, 1, 15, 12, 0),
      const Duration(hours: 1),
    );
    // India: +5:30.
    expect(
      formatOffset(utcOffsetAt('Asia/Kolkata', 2001, 3, 1, 9, 0)!),
      'UTC+5:30',
    );
  });

  test('birth data converts local birth time to UTC with the zone', () {
    final b = BirthData(
      year: 1975,
      month: 7,
      day: 4,
      hour: 21,
      minute: 15,
      place: index.search('new york').first.toPlace(),
    );
    expect(b.utc, DateTime.utc(1975, 7, 5, 1, 15));
    expect(b.isComplete, isTrue);
    final chart = NatalChart.of(b);
    expect(chart.angles, isNotNull);
    expect(chart.moonCertain, isTrue);
    // Without a time, the rising sign is unknown and nothing is guessed.
    final noTime = NatalChart.of(BirthData(year: 1975, month: 7, day: 4));
    expect(noTime.angles, isNull);
    expect(noTime.risingSign, isNull);
    expect(noTime.sunSign, 3); // Cancer
  });
}
