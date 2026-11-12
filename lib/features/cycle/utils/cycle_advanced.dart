import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:prism_plurality/domain/models/cycle_entry.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';

const cycleSymptomKind = 'cycle.symptom';

abstract final class CycleField {
  static const startDay = 'startDay';
  static const endDay = 'endDay';
  static const color = 'color';
  static const energy = 'energy';
  static const pain = 'pain';
  static const bbt = 'bbt';
  static const mucus = 'mucus';
  static const libido = 'libido';
  static const ovulationTest = 'ovulationTest';
  static const pregnancyTest = 'pregnancyTest';
  static const medication = 'medication';
}

const mucusOptions = ['dry', 'sticky', 'creamy', 'watery', 'eggwhite'];

/// A named range of cycle days (1-based, inclusive).
@immutable
class CyclePhase {
  const CyclePhase({
    required this.key,
    required this.name,
    required this.startDay,
    required this.endDay,
    required this.color,
    this.record,
  });

  /// `menstrual`, `follicular`, `ovulation`, `luteal`, or a record id.
  final String key;
  final String name;
  final int startDay;
  final int endDay;
  final int color;
  final TrackerRecord? record;

  bool contains(int day) => day >= startDay && day <= endDay;
}

/// Default phases sized to the user's own average cycle and period.
List<CyclePhase> defaultPhases({
  required double? averageCycle,
  required double? averagePeriod,
  required Map<String, String> names,
}) {
  final cycle = (averageCycle ?? 28).round().clamp(18, 50);
  final period = (averagePeriod ?? 5).round().clamp(2, 10);
  final ovulation = (cycle - 14).clamp(period + 2, cycle - 2);
  return [
    CyclePhase(
      key: 'menstrual',
      name: names['menstrual']!,
      startDay: 1,
      endDay: period,
      color: 0xFFE57373,
    ),
    CyclePhase(
      key: 'follicular',
      name: names['follicular']!,
      startDay: period + 1,
      endDay: ovulation - 2,
      color: 0xFF81C784,
    ),
    CyclePhase(
      key: 'ovulation',
      name: names['ovulation']!,
      startDay: ovulation - 1,
      endDay: ovulation + 1,
      color: 0xFF64B5F6,
    ),
    CyclePhase(
      key: 'luteal',
      name: names['luteal']!,
      startDay: ovulation + 2,
      endDay: cycle,
      color: 0xFFBA68C8,
    ),
  ];
}

/// Custom phases from records, sorted by start day; null if none saved.
List<CyclePhase>? customPhases(List<TrackerRecord> records) {
  final out = [
    for (final r in records)
      if ((r.integer(CycleField.startDay) ?? 0) >= 1 &&
          (r.integer(CycleField.endDay) ?? 0) >=
              (r.integer(CycleField.startDay) ?? 1))
        CyclePhase(
          key: r.id,
          name: r.title,
          startDay: r.integer(CycleField.startDay)!,
          endDay: r.integer(CycleField.endDay)!,
          color: r.integer(CycleField.color) ?? 0xFF9E9E9E,
          record: r,
        ),
  ]..sort((a, b) => a.startDay.compareTo(b.startDay));
  return out.isEmpty ? null : out;
}

CyclePhase? phaseFor(int? cycleDay, List<CyclePhase> phases) {
  if (cycleDay == null) return null;
  for (final p in phases) {
    if (p.contains(cycleDay)) return p;
  }
  return null;
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);
int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Cycle day (1-based) of [day] given known period starts, or null when
/// it falls before the first start or more than 60 days after the last.
int? cycleDayOn(DateTime day, List<DateTime> starts) {
  DateTime? last;
  for (final s in starts) {
    if (!s.isAfter(day)) last = s;
  }
  if (last == null) return null;
  final n = _daysBetween(last, day) + 1;
  return n > 60 ? null : n;
}

@immutable
class CycleRecord {
  const CycleRecord({
    required this.start,
    required this.length,
    required this.periodLength,
    required this.symptomDays,
  });

  final DateTime start;

  /// Days until the next period started; null for the current cycle.
  final int? length;
  final int periodLength;
  final int symptomDays;
}

/// Past cycles, newest first.
List<CycleRecord> cycleHistory(List<CycleEntry> entries, CycleStats stats) {
  final byKey = {for (final e in entries) e.date: e};
  final starts = stats.periodStarts;
  final out = <CycleRecord>[];
  for (var i = 0; i < starts.length; i++) {
    final s = starts[i];
    final next = i + 1 < starts.length ? starts[i + 1] : null;
    var period = 0;
    var cursor = s;
    while ((byKey[CycleStats.dateKey(cursor)]?.flow ?? 0) >= 2 && period < 15) {
      period++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    final end = next ?? DateTime.now();
    var symptomDays = 0;
    for (final e in entries) {
      final d = DateTime.tryParse(e.date);
      if (d == null) continue;
      if (!d.isBefore(s) && d.isBefore(end) && e.symptoms.isNotEmpty)
        symptomDays++;
    }
    out.add(
      CycleRecord(
        start: s,
        length: next == null ? null : _daysBetween(s, next),
        periodLength: period,
        symptomDays: symptomDays,
      ),
    );
  }
  return out.reversed.toList();
}

/// Standard deviation of cycle lengths (days), or null with < 3 cycles.
double? cycleVariability(List<int> lengths) {
  if (lengths.length < 3) return null;
  final m = lengths.reduce((a, b) => a + b) / lengths.length;
  return math.sqrt(
    lengths.fold(0.0, (s, l) => s + (l - m) * (l - m)) / lengths.length,
  );
}

@immutable
class CyclePrediction {
  const CyclePrediction({
    required this.periodStart,
    required this.ovulation,
    required this.fertileStart,
    required this.fertileEnd,
  });

  final DateTime periodStart;
  final DateTime ovulation;
  final DateTime fertileStart;
  final DateTime fertileEnd;
}

/// The next [count] predicted cycles (needs an average cycle length).
List<CyclePrediction> predictCycles(CycleStats stats, {int count = 3}) {
  final next = stats.nextPeriodEstimate;
  final avg = stats.averageCycleLength;
  if (next == null || avg == null) return const [];
  final len = avg.round();
  return [
    for (var i = 0; i < count; i++)
      () {
        final start = _d(next.add(Duration(days: len * i)));
        final previousStart = start.subtract(Duration(days: len));
        final ov = previousStart.add(Duration(days: len - 14));
        return CyclePrediction(
          periodStart: start,
          ovulation: ov,
          fertileStart: ov.subtract(const Duration(days: 5)),
          fertileEnd: ov.add(const Duration(days: 1)),
        );
      }(),
  ];
}

/// Per-phase aggregates for patterns and insights.
@immutable
class PhasePattern {
  const PhasePattern({
    required this.phase,
    required this.daysLogged,
    required this.symptomShare,
    this.averageMood,
    this.averageEnergy,
    this.averagePain,
  });

  final CyclePhase phase;
  final int daysLogged;

  /// Symptom key → share of logged days in this phase that had it.
  final Map<String, double> symptomShare;
  final double? averageMood;
  final double? averageEnergy;
  final double? averagePain;
}

List<PhasePattern> phasePatterns({
  required List<CyclePhase> phases,
  required List<DateTime> starts,
  required List<CycleEntry> entries,
  required List<TrackerRecord> wellness,
  required List<MoodEntry> moods,
}) {
  return [
    for (final p in phases)
      () {
        var logged = 0;
        final counts = <String, int>{};
        final energy = <int>[], pain = <int>[];
        for (final e in entries) {
          final d = DateTime.tryParse(e.date);
          if (d == null || !p.contains(cycleDayOn(d, starts) ?? -1)) continue;
          logged++;
          for (final s in e.symptoms) {
            counts[s] = (counts[s] ?? 0) + 1;
          }
        }
        for (final w in wellness) {
          final d = DateTime.tryParse(w.title);
          if (d == null || !p.contains(cycleDayOn(d, starts) ?? -1)) continue;
          if (!entries.any((e) => e.date == w.title)) logged++;
          final en = w.integer(CycleField.energy);
          final pa = w.integer(CycleField.pain);
          if (en != null) energy.add(en);
          if (pa != null) pain.add(pa);
        }
        final mood = [
          for (final m in moods)
            if (p.contains(cycleDayOn(_d(m.recordedAt), starts) ?? -1)) m.mood,
        ];
        double? avg(List<int> l) =>
            l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;
        return PhasePattern(
          phase: p,
          daysLogged: logged,
          symptomShare: {
            for (final e in counts.entries)
              if (logged > 0) e.key: e.value / logged,
          },
          averageMood: avg(mood),
          averageEnergy: avg(energy),
          averagePain: avg(pain),
        );
      }(),
  ];
}
