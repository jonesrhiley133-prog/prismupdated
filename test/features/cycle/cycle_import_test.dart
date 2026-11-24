import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/cycle_entry.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_import.dart';
import 'package:prism_plurality/features/fitness/health/health_sync.dart';

void main() {
  test('CSV with date, flow and symptoms', () {
    final r = parseCycleFile(
      'x.csv',
      'Date,Flow,Symptoms,Notes\n2026-01-03,heavy,"cramps; headache",ouch\n2026-01-04,light,,\n2026-01-05,,,\nbad,1,,',
    );
    expect(r.days.map((d) => d.key), ['2026-01-03', '2026-01-04']);
    expect(r.days.first.flow, 4);
    expect(r.days.first.symptoms, ['cramps', 'headache']);
    expect(r.skippedRows, 2);
  });

  test('CSV period ranges', () {
    final r = parseCycleFile('flo.csv', 'Start,End\n2026-02-01,2026-02-04\n');
    expect(r.days.length, 4);
    expect(r.days.every((d) => d.flow == 3), isTrue);
  });

  test('Clue measurement JSON', () {
    final r = parseCycleFile(
      'clue.json',
      '{"measurements":[{"date":"2026-03-01","type":"period","value":{"option":"medium"}},{"date":"2026-03-02","type":"period","value":{"option":"spotting"}},{"date":"2026-03-02","type":"pain","value":{"option":"cramps"}},{"date":"2026-03-09","type":"sleep","value":"7"}]}',
    );
    expect(r.format, 'Clue');
    expect(r.days.map((d) => (d.key, d.flow)), [
      ('2026-03-01', 3),
      ('2026-03-02', 1),
    ]);
    expect(r.days.last.symptoms, ['cramps']);
  });

  test('plan keeps what was logged by hand', () {
    final now = DateTime(2026);
    final existing = {
      '2026-01-03': CycleEntry(
        id: 'a',
        date: '2026-01-03',
        flow: 2,
        symptoms: const ['cramps'],
        createdAt: now,
        modifiedAt: now,
      ),
      '2026-01-04': CycleEntry(
        id: 'b',
        date: '2026-01-04',
        flow: 0,
        createdAt: now,
        modifiedAt: now,
      ),
    };
    final incoming = [
      ImportedCycleDay(DateTime(2026, 1, 3), 4),
      ImportedCycleDay(DateTime(2026, 1, 4), 2),
      ImportedCycleDay(DateTime(2026, 1, 5), 3),
    ];
    final plan = planCycleImport(existing, incoming);
    expect(plan.create.map((d) => d.key), ['2026-01-05']);
    expect(plan.update.map((u) => u.$1.id), ['b']);
    expect(plan.unchanged, 1);
    expect(
      planCycleImport(existing, incoming, fillBlanksOnly: false).update.length,
      2,
    );
  });

  test('sleep segments merge into nights', () {
    final d = DateTime(2026, 1, 1, 23);
    final nights = mergeSleepSegments([
      (d, d.add(const Duration(hours: 2))),
      (
        d.add(const Duration(hours: 2, minutes: 20)),
        d.add(const Duration(hours: 7)),
      ),
      (
        d.add(const Duration(hours: 14)),
        d.add(const Duration(hours: 14, minutes: 10)),
      ),
    ]);
    expect(nights, [(d, d.add(const Duration(hours: 7)))]);
  });
}
