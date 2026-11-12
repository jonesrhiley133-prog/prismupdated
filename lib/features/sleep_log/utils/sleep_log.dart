import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';

/// Field keys inside a sleep log's `data`. A log is attached to a sleep
/// session through [TrackerRecord.parentId].
abstract final class SleepField {
  static const temperatureC = 'temperatureC';
  static const lighting = 'lighting';
  static const location = 'location';
  static const noise = 'noise';
  static const comfort = 'comfort';
  static const latencyMin = 'latencyMin';
  static const interruptions = 'interruptions';
  static const interruptionReasons = 'interruptionReasons';
  static const factors = 'factors';
  static const wakeFeeling = 'wakeFeeling';
  static const dreams = 'dreams';
  static const sharedWith = 'sharedWith';
  static const bedtimeMin = 'bedtimeMin';
  static const wakeMin = 'wakeMin';
  static const weekendBedtimeMin = 'weekendBedtimeMin';
  static const weekendWakeMin = 'weekendWakeMin';
  static const targetHours = 'targetHours';
}

const sleepLightingOptions = ['dark', 'dim', 'nightlight', 'bright', 'screen'];
const sleepLocationOptions = [
  'bed',
  'couch',
  'guest',
  'travel',
  'floor',
  'other',
];
const sleepNoiseOptions = ['silent', 'quiet', 'white_noise', 'music', 'noisy'];
const sleepSharedOptions = ['alone', 'partner', 'pet', 'child', 'others'];
const sleepDreamOptions = ['none', 'neutral', 'pleasant', 'vivid', 'nightmare'];
const sleepFactorOptions = [
  'caffeine',
  'alcohol',
  'screens',
  'exercise',
  'late_meal',
  'nap',
  'medication',
  'stress',
  'pain',
  'reading',
  'meditation',
  'shower',
];
const sleepInterruptionOptions = [
  'bathroom',
  'noise',
  'nightmare',
  'pain',
  'temperature',
  'pet',
  'child',
  'switch',
  'anxiety',
  'other',
];

/// Quality enum as a 1–5 score (null when unknown).
int? qualityScore(SleepQuality? q) => switch (q) {
  SleepQuality.veryPoor => 1,
  SleepQuality.poor => 2,
  SleepQuality.fair => 3,
  SleepQuality.good => 4,
  SleepQuality.excellent => 5,
  _ => null,
};

/// A sleep session joined with its optional log.
@immutable
class SleepNight {
  const SleepNight({required this.session, this.log});

  final FrontingSession session;
  final TrackerRecord? log;

  DateTime get start => session.startTime;
  DateTime? get end => session.endTime;

  /// Time asleep: in bed minus how long it took to fall asleep.
  Duration get asleep {
    final e = end;
    if (e == null) return Duration.zero;
    final inBed = e.difference(start);
    final latency = Duration(minutes: log?.integer(SleepField.latencyMin) ?? 0);
    final d = inBed - latency;
    return d.isNegative ? Duration.zero : d;
  }

  int? get quality => qualityScore(session.quality);
  int get interruptions => log?.integer(SleepField.interruptions) ?? 0;
}

List<SleepNight> joinNights(
  Iterable<FrontingSession> sessions,
  Iterable<TrackerRecord> logs,
) {
  final byParent = {
    for (final l in logs)
      if (l.parentId != null) l.parentId!: l,
  };
  return [
    for (final s in sessions)
      if (s.endTime != null) SleepNight(session: s, log: byParent[s.id]),
  ]..sort((a, b) => b.start.compareTo(a.start));
}

/// Minutes from noon, so bedtimes around midnight average correctly
/// (23:00 → 660, 01:00 → 780).
int minutesFromNoon(DateTime t) {
  final m = t.hour * 60 + t.minute;
  return (m - 12 * 60) % (24 * 60);
}

DateTime fromNoonMinutes(int m) {
  final total = (m + 12 * 60) % (24 * 60);
  return DateTime(2000, 1, 1, total ~/ 60, total % 60);
}

@immutable
class SleepSummary {
  const SleepSummary({
    required this.nights,
    required this.averageAsleep,
    required this.averageQuality,
    required this.averageLatency,
    required this.averageInterruptions,
    required this.averageBedtimeFromNoon,
    required this.averageWakeFromNoon,
    required this.bedtimeSpreadMin,
    required this.debtHours,
  });

  final int nights;
  final Duration averageAsleep;
  final double? averageQuality;
  final double? averageLatency;
  final double averageInterruptions;
  final int? averageBedtimeFromNoon;
  final int? averageWakeFromNoon;

  /// Standard deviation of bedtimes in minutes (lower = more regular).
  final double? bedtimeSpreadMin;

  /// Hours below the target across these nights (never negative).
  final double debtHours;

  static SleepSummary of(List<SleepNight> nights, {double targetHours = 8}) {
    if (nights.isEmpty) {
      return const SleepSummary(
        nights: 0,
        averageAsleep: Duration.zero,
        averageQuality: null,
        averageLatency: null,
        averageInterruptions: 0,
        averageBedtimeFromNoon: null,
        averageWakeFromNoon: null,
        bedtimeSpreadMin: null,
        debtHours: 0,
      );
    }
    final asleep = nights.fold(0, (s, n) => s + n.asleep.inMinutes);
    final q = [for (final n in nights) ?n.quality];
    final lat = [
      for (final n in nights) ?n.log?.integer(SleepField.latencyMin),
    ];
    final beds = [for (final n in nights) minutesFromNoon(n.start)];
    final wakes = [for (final n in nights) minutesFromNoon(n.end!)];
    final meanBed = beds.reduce((a, b) => a + b) / beds.length;
    final spread = beds.length < 2
        ? null
        : math.sqrt(
            beds.fold(0.0, (s, b) => s + (b - meanBed) * (b - meanBed)) /
                beds.length,
          );
    var debt = 0.0;
    for (final n in nights) {
      final short = targetHours - n.asleep.inMinutes / 60;
      if (short > 0) debt += short;
    }
    return SleepSummary(
      nights: nights.length,
      averageAsleep: Duration(minutes: asleep ~/ nights.length),
      averageQuality: q.isEmpty ? null : q.reduce((a, b) => a + b) / q.length,
      averageLatency: lat.isEmpty
          ? null
          : lat.reduce((a, b) => a + b) / lat.length,
      averageInterruptions:
          nights.fold(0, (s, n) => s + n.interruptions) / nights.length,
      averageBedtimeFromNoon: meanBed.round(),
      averageWakeFromNoon: (wakes.reduce((a, b) => a + b) / wakes.length)
          .round(),
      bedtimeSpreadMin: spread,
      debtHours: debt,
    );
  }
}

/// How nights with a given factor value compare.
@immutable
class FactorImpact {
  const FactorImpact({
    required this.key,
    required this.nights,
    required this.averageHours,
    this.averageQuality,
  });

  /// e.g. `factor:caffeine`, `lighting:dark`, `temp:16-19`.
  final String key;
  final int nights;
  final double averageHours;
  final double? averageQuality;
}

String temperatureBucket(double c) {
  if (c < 16) return 'lt16';
  if (c < 19) return '16_19';
  if (c < 22) return '19_22';
  return '22plus';
}

/// Groups logged nights by every recorded factor value. Only groups with
/// at least [minNights] are returned, best average quality first.
List<FactorImpact> factorImpacts(List<SleepNight> nights, {int minNights = 2}) {
  final groups = <String, List<SleepNight>>{};
  void add(String k, SleepNight n) => (groups[k] ??= []).add(n);
  for (final n in nights) {
    final l = n.log;
    if (l == null) continue;
    for (final f in l.strings(SleepField.factors)) {
      add('factor:$f', n);
    }
    for (final key in [
      SleepField.lighting,
      SleepField.location,
      SleepField.noise,
    ]) {
      final v = l.str(key);
      if (v != null) add('$key:$v', n);
    }
    final c = l.integer(SleepField.comfort);
    if (c != null) add('comfort:$c', n);
    final t = l.number(SleepField.temperatureC);
    if (t != null) add('temp:${temperatureBucket(t)}', n);
  }
  final out = [
    for (final e in groups.entries)
      if (e.value.length >= minNights)
        FactorImpact(
          key: e.key,
          nights: e.value.length,
          averageHours:
              e.value.fold(0, (s, n) => s + n.asleep.inMinutes) /
              e.value.length /
              60,
          averageQuality: () {
            final q = [for (final n in e.value) ?n.quality];
            return q.isEmpty ? null : q.reduce((a, b) => a + b) / q.length;
          }(),
        ),
  ];
  out.sort((a, b) {
    final aq = a.averageQuality ?? -1, bq = b.averageQuality ?? -1;
    return aq != bq
        ? bq.compareTo(aq)
        : b.averageHours.compareTo(a.averageHours);
  });
  return out;
}

/// Minutes between actual and target bedtime (positive = later).
int bedtimeDeviation(DateTime start, int targetMinuteOfDay) {
  final actual = minutesFromNoon(start);
  final target = (targetMinuteOfDay - 12 * 60) % (24 * 60);
  return actual - target;
}
