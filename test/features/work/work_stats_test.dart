import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/work.dart';
import 'package:prism_plurality/features/work/utils/money.dart';
import 'package:prism_plurality/features/work/utils/work_stats.dart';

WorkSession _s(
  DateTime start,
  DateTime? end, {
  int rate = 1800,
  int breakSeconds = 0,
  String job = 'j',
}) => WorkSession(
  id: '$start',
  jobId: job,
  startedAt: start,
  endedAt: end,
  hourlyRateCents: rate,
  breakSeconds: breakSeconds,
  createdAt: start,
  modifiedAt: start,
);

void main() {
  group('estimateEarningsCents', () {
    test('uses exact seconds, rounding only at the end', () {
      // 1 second at $18.00/h = 0.5 cents → rounds half-up to 1 cent.
      expect(estimateEarningsCents(1, 1800), 1);
      // 59 seconds: 29.5 cents → 30.
      expect(estimateEarningsCents(59, 1800), 30);
      // 1h 0m 1s at $18/h = 1800.5 → 1801.
      expect(estimateEarningsCents(3601, 1800), 1801);
      expect(estimateEarningsCents(0, 1800), 0);
      expect(estimateEarningsCents(100, 0), 0);
    });

    test('live session earnings follow the exact elapsed seconds', () {
      final start = DateTime(2026, 1, 1, 9);
      final s = _s(start, null, rate: 2500);
      expect(s.workedAt(start.add(const Duration(seconds: 7))).inSeconds, 7);
      expect(
        s.estimatedEarningsCentsAt(
          start.add(const Duration(minutes: 90, seconds: 30)),
        ),
        estimateEarningsCents(5430, 2500),
      );
    });
  });

  test('breaks are subtracted and never go negative', () {
    final start = DateTime(2026, 1, 1, 9);
    final s = _s(
      start,
      start.add(const Duration(hours: 8)),
      breakSeconds: 1800,
    );
    expect(s.workedAt(start).inSeconds, 8 * 3600 - 1800);
    final tooLong = _s(
      start,
      start.add(const Duration(minutes: 10)),
      breakSeconds: 3600,
    );
    expect(tooLong.workedAt(start), Duration.zero);
  });

  test('overnight shifts split across days and sum exactly', () {
    final s = _s(
      DateTime(2026, 1, 1, 22, 0, 0),
      DateTime(2026, 1, 2, 6, 30, 7),
      breakSeconds: 1801,
    );
    final slices = sliceWorkSessionByDay(s, DateTime(2026, 1, 3));
    expect(slices.map((x) => x.day), [
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 2),
    ]);
    expect(
      slices.fold<int>(0, (a, b) => a + b.seconds),
      s.workedAt(DateTime(2026, 1, 3)).inSeconds,
    );
  });

  test('stats aggregate by day, week, month and job', () {
    final now = DateTime(2026, 3, 20, 12);
    final sessions = [
      _s(DateTime(2026, 3, 16, 9), DateTime(2026, 3, 16, 17), job: 'a'), // Mon
      _s(
        DateTime(2026, 3, 18, 9),
        DateTime(2026, 3, 18, 13),
        job: 'b',
        rate: 3000,
      ),
      _s(DateTime(2026, 2, 28, 9), DateTime(2026, 2, 28, 10), job: 'a'),
    ];
    final stats = WorkStats.of(sessions, now: now);
    expect(stats.dayOf(DateTime(2026, 3, 16)).seconds, 8 * 3600);
    expect(stats.weekOf(DateTime(2026, 3, 19)).seconds, 12 * 3600);
    expect(
      stats.monthOf(DateTime(2026, 3, 1)).earningsCents,
      8 * 1800 + 4 * 3000,
    );
    expect(stats.byJob['a']!.seconds, 9 * 3600);
    final march = WorkStats.of(
      sessions,
      now: now,
      from: DateTime(2026, 3, 1),
      to: DateTime(2026, 4, 1),
    );
    expect(march.total.seconds, 12 * 3600);
  });

  group('money', () {
    test('parses common inputs to hundredths', () {
      expect(parseMoneyToCents('18.25'), 1825);
      expect(parseMoneyToCents('18,25'), 1825);
      expect(parseMoneyToCents('18'), 1800);
      expect(parseMoneyToCents('18.5'), 1850);
      expect(parseMoneyToCents('1,250.75'), 125075);
      expect(parseMoneyToCents(r'$20'), 2000);
      expect(parseMoneyToCents('abc'), isNull);
      expect(parseMoneyToCents(''), isNull);
    });

    test('formats hundredths in the right currency', () {
      expect(formatMoneyCents(1825, 'USD', locale: 'en_US'), r'$18.25');
      expect(formatMoneyCents(150000, 'JPY', locale: 'en_US'), '¥1,500');
    });
  });
}
