import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/cycle_entry.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_advanced.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

final _t = DateTime(2026);
CycleEntry _e(DateTime d, int flow, [List<String> s = const []]) => CycleEntry(
  id: '$d',
  date: CycleStats.dateKey(d),
  flow: flow,
  symptoms: s,
  createdAt: _t,
  modifiedAt: _t,
);

void main() {
  final entries = <CycleEntry>[
    for (final start in [
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 29),
      DateTime(2026, 2, 26),
    ])
      for (var i = 0; i < 4; i++)
        _e(start.add(Duration(days: i)), 3, ['cramps']),
    _e(DateTime(2026, 1, 20), 0, ['bloating']),
  ];
  final stats = CycleStats.of(entries, today: DateTime(2026, 3, 5));
  const names = {
    'menstrual': 'M',
    'follicular': 'F',
    'ovulation': 'O',
    'luteal': 'L',
  };

  test('default phases fit the averages and cover the cycle', () {
    final p = defaultPhases(averageCycle: 28, averagePeriod: 4, names: names);
    expect(p.map((x) => (x.startDay, x.endDay)), [
      (1, 4),
      (5, 12),
      (13, 15),
      (16, 28),
    ]);
    expect(phaseFor(14, p)!.key, 'ovulation');
    expect(cycleDayOn(DateTime(2026, 3, 5), stats.periodStarts), 8);
    expect(cycleDayOn(DateTime(2025, 12, 1), stats.periodStarts), isNull);
  });

  test('custom phases override defaults when valid', () {
    TrackerRecord r(String t, int s, int e) => TrackerRecord(
      id: t,
      kind: TrackerKind.cyclePhase,
      title: t,
      createdAt: _t,
      modifiedAt: _t,
    ).withFields({CycleField.startDay: s, CycleField.endDay: e});
    expect(customPhases(const []), isNull);
    final c = customPhases([
      r('Rest', 1, 5),
      r('Bad', 9, 3),
      r('Rise', 6, 14),
    ])!;
    expect(c.map((x) => x.name), ['Rest', 'Rise']);
  });

  test('history, variability and predictions', () {
    final h = cycleHistory(entries, stats);
    expect(h.first.length, isNull);
    expect(h[1].length, 28);
    expect(h[1].periodLength, 4);
    expect(h.last.symptomDays, 5);
    expect(cycleVariability([28, 28]), isNull);
    expect(cycleVariability([26, 28, 30]), closeTo(1.633, 0.01));
    final p = predictCycles(stats, count: 2);
    expect(p.first.periodStart, DateTime(2026, 3, 26));
    expect(p.first.ovulation, DateTime(2026, 3, 12));
    expect(p.first.fertileStart, DateTime(2026, 3, 7));
    expect(p[1].periodStart, DateTime(2026, 4, 23));
  });

  test('phase patterns combine symptoms, wellness and mood', () {
    final phases = defaultPhases(
      averageCycle: 28,
      averagePeriod: 4,
      names: names,
    );
    final wellness = [
      TrackerRecord(
        id: 'w',
        kind: TrackerKind.cycleWellness,
        title: '2026-01-02',
        createdAt: _t,
        modifiedAt: _t,
      ).withFields({CycleField.energy: 2, CycleField.pain: 6}),
    ];
    final moods = [
      MoodEntry(
        id: 'm',
        mood: 2,
        recordedAt: DateTime(2026, 1, 3, 12),
        createdAt: _t,
        modifiedAt: _t,
      ),
    ];
    final pat = {
      for (final p in phasePatterns(
        phases: phases,
        starts: stats.periodStarts,
        entries: entries,
        wellness: wellness,
        moods: moods,
      ))
        p.phase.key: p,
    };
    expect(pat['menstrual']!.daysLogged, 12);
    expect(pat['menstrual']!.symptomShare['cramps'], 1.0);
    expect(pat['menstrual']!.averageEnergy, 2);
    expect(pat['menstrual']!.averageMood, 2);
    expect(pat['luteal']!.symptomShare['bloating'], 1.0);
  });
}
