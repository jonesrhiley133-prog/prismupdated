import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/analytics/correlation_engine.dart';

void main() {
  final days = [for (var i = 0; i < 40; i++) DateTime(2026, 1, 1 + i)];

  test('perfectly related series correlate at 1 with high confidence', () {
    final mood = DailySeries(
      id: 'm',
      group: 'mood',
      en: 'Mood',
      es: 'Ánimo',
      values: {for (final (i, d) in days.indexed) d: 1 + (i % 5).toDouble()},
    );
    final sleep = DailySeries(
      id: 's',
      group: 'sleep',
      en: 'Sleep',
      es: 'Sueño',
      values: {
        for (final (i, d) in days.indexed) d: 5 + 2 * (i % 5).toDouble(),
      },
    );
    final c = correlate(mood, sleep, days)!;
    expect(c.r, closeTo(1, 1e-9));
    expect(c.n, 40);
    expect(c.confidence, Confidence.high);
    expect(c.strength, 'strong');
  });

  test('too few overlapping days is reported as insufficient', () {
    final mood = DailySeries(
      id: 'm',
      group: 'mood',
      en: 'Mood',
      es: 'Ánimo',
      values: {days[0]: 3, days[1]: 4, days[2]: 2, days[3]: 5},
    );
    final x = DailySeries(
      id: 'x',
      group: 'g',
      en: 'X',
      es: 'X',
      values: {days[0]: 1, days[1]: 2, days[2]: 0, days[3]: 3},
    );
    expect(correlate(mood, x, days)!.confidence, Confidence.insufficient);
  });

  test('zero-filled counts include days with no records', () {
    final mood = DailySeries(
      id: 'm',
      group: 'mood',
      en: 'Mood',
      es: 'Ánimo',
      values: {for (final d in days) d: 3},
    );
    final x = DailySeries(
      id: 'x',
      group: 'g',
      en: 'X',
      es: 'X',
      values: {days[0]: 2},
      zeroFill: true,
    );
    expect(correlate(mood, x, days)!.n, 40);
  });

  test('lag compares the variable with the next day’s mood', () {
    final mood = DailySeries(
      id: 'm',
      group: 'mood',
      en: 'Mood',
      es: 'Ánimo',
      values: {for (final (i, d) in days.indexed) d: (i % 3).toDouble()},
    );
    final x = DailySeries(
      id: 'x',
      group: 'g',
      en: 'X',
      es: 'X',
      values: {for (final (i, d) in days.indexed) d: ((i + 1) % 3).toDouble()},
    );
    expect(correlate(mood, x, days, lag: 1)!.r, closeTo(1, 1e-9));
  });

  test('p-value shrinks as evidence grows', () {
    expect(pValue(0.5, 10), greaterThan(pValue(0.5, 100)));
    expect(pValue(0, 50), closeTo(1, 1e-6));
  });
}
