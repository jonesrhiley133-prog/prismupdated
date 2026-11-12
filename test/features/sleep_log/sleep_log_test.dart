import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/sleep_log/utils/sleep_log.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

FrontingSession _s(String id, DateTime start, Duration len, SleepQuality q) =>
    FrontingSession(
      id: id,
      startTime: start,
      endTime: start.add(len),
      sessionType: SessionType.sleep,
      quality: q,
    );

TrackerRecord _log(String parent, Map<String, Object?> f) => TrackerRecord(
  id: 'l$parent',
  kind: TrackerKind.sleepLog,
  parentId: parent,
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
).withFields(f);

void main() {
  final sessions = [
    _s(
      'a',
      DateTime(2026, 3, 1, 23),
      const Duration(hours: 8),
      SleepQuality.good,
    ),
    _s(
      'b',
      DateTime(2026, 3, 2, 23, 30),
      const Duration(hours: 6),
      SleepQuality.poor,
    ),
    _s(
      'c',
      DateTime(2026, 3, 4, 0, 30),
      const Duration(hours: 7, minutes: 30),
      SleepQuality.excellent,
    ),
    _s(
      'd',
      DateTime(2026, 3, 4, 23),
      const Duration(hours: 5),
      SleepQuality.veryPoor,
    ),
  ];
  final logs = [
    _log('a', {
      SleepField.latencyMin: 20,
      SleepField.lighting: 'dark',
      SleepField.temperatureC: 18.0,
      SleepField.factors: ['reading'],
    }),
    _log('b', {
      SleepField.factors: ['caffeine', 'screens'],
      SleepField.interruptions: 3,
      SleepField.lighting: 'screen',
    }),
    _log('c', {
      SleepField.lighting: 'dark',
      SleepField.temperatureC: 17.5,
      SleepField.factors: ['reading'],
    }),
    _log('d', {
      SleepField.factors: ['caffeine'],
      SleepField.interruptions: 1,
    }),
  ];

  test('nights join logs and subtract time to fall asleep', () {
    final nights = joinNights(sessions, logs);
    expect(nights.first.session.id, 'd');
    final a = nights.firstWhere((n) => n.session.id == 'a');
    expect(a.asleep, const Duration(hours: 7, minutes: 40));
    expect(a.quality, 4);
  });

  test('summary averages bedtimes across midnight and computes debt', () {
    final s = SleepSummary.of(joinNights(sessions, logs), targetHours: 8);
    expect(s.nights, 4);
    expect(s.averageInterruptions, 1);
    expect(s.averageQuality, closeTo(3, 0.001));
    // Bedtimes 23:00, 23:30, 00:30, 23:00 → about 23:30.
    final bed = fromNoonMinutes(s.averageBedtimeFromNoon!);
    expect((bed.hour, bed.minute), (23, 30));
    expect(s.debtHours, closeTo(0.333 + 2 + 0.5 + 3, 0.01));
    expect(s.bedtimeSpreadMin, greaterThan(0));
  });

  test('factor impacts compare logged nights', () {
    final impacts = {
      for (final i in factorImpacts(joinNights(sessions, logs))) i.key: i,
    };
    expect(impacts['factor:reading']!.averageQuality, 4.5);
    expect(impacts['factor:caffeine']!.averageQuality, 1.5);
    expect(impacts['lighting:dark']!.nights, 2);
    expect(impacts['temp:16_19']!.nights, 2);
    expect(impacts.containsKey('lighting:screen'), isFalse); // only 1 night
    expect(bedtimeDeviation(DateTime(2026, 3, 1, 0, 30), 23 * 60), 90);
    expect(bedtimeDeviation(DateTime(2026, 3, 1, 22, 30), 23 * 60), -30);
  });
}
