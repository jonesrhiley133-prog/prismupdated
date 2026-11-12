import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/cycle_entry.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';

CycleEntry _e(DateTime d, int flow) => CycleEntry(
  id: '$d',
  date: CycleStats.dateKey(d),
  flow: flow,
  createdAt: d,
  modifiedAt: d,
);

void main() {
  test('detects period starts, lengths, current day and estimate', () {
    final entries = <CycleEntry>[
      for (final start in [
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 26),
      ])
        for (var i = 0; i < 5; i++)
          _e(DateTime(start.year, start.month, start.day + i), i == 4 ? 1 : 3),
      _e(DateTime(2026, 1, 15), 1), // spotting doesn't start a period
    ];
    final s = CycleStats.of(entries, today: DateTime(2026, 3, 5));
    expect(s.periodStarts, [
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 29),
      DateTime(2026, 2, 26),
    ]);
    expect(s.cycleLengths, [28, 28]);
    expect(s.averageCycleLength, 28);
    expect(s.averagePeriodLength, 4);
    expect(s.currentCycleDay, 8);
    expect(s.nextPeriodEstimate, DateTime(2026, 3, 26));
  });

  test('needs two cycles before estimating; ignores implausible gaps', () {
    final one = CycleStats.of([
      _e(DateTime(2026, 1, 1), 3),
    ], today: DateTime(2026, 1, 10));
    expect(one.nextPeriodEstimate, isNull);
    expect(one.currentCycleDay, 10);
    final gap = CycleStats.of([
      _e(DateTime(2026, 1, 1), 3),
      _e(DateTime(2026, 1, 8), 3),
      _e(DateTime(2026, 6, 1), 3),
    ], today: DateTime(2026, 6, 2));
    expect(gap.cycleLengths, isEmpty);
  });
}
