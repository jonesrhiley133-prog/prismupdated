import 'package:flutter/foundation.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';

/// Field keys inside fitness records' `data`.
abstract final class FitField {
  static const activity = 'activity';
  static const minutes = 'minutes';
  static const distanceKm = 'distanceKm';
  static const calories = 'calories';
  static const effort = 'effort';
  static const heartRate = 'heartRate';
  static const sets = 'sets';
  static const moodAfter = 'moodAfter';
  static const metric = 'metric';
  static const period = 'period';
  static const target = 'target';
}

const fitnessActivities = [
  'walk',
  'run',
  'cycle',
  'swim',
  'strength',
  'yoga',
  'hiit',
  'hike',
  'dance',
  'sports',
  'stretch',
  'climb',
  'row',
  'other',
];

/// Activities where distance matters.
const distanceActivities = {'walk', 'run', 'cycle', 'swim', 'hike', 'row'};

/// One exercise line in a strength workout.
@immutable
class ExerciseSet {
  const ExerciseSet({
    required this.exercise,
    this.sets = 1,
    this.reps = 0,
    this.weightKg = 0,
  });

  final String exercise;
  final int sets;
  final int reps;
  final double weightKg;

  /// sets × reps × weight.
  double get volume => sets * reps * weightKg;

  Map<String, Object?> toJson() => {
    'exercise': exercise,
    'sets': sets,
    'reps': reps,
    'weightKg': weightKg,
  };

  static ExerciseSet? fromJson(Object? v) {
    if (v is! Map || v['exercise'] is! String) return null;
    num n(String k) => v[k] is num ? v[k] as num : 0;
    return ExerciseSet(
      exercise: v['exercise'] as String,
      sets: n('sets').toInt(),
      reps: n('reps').toInt(),
      weightKg: n('weightKg').toDouble(),
    );
  }
}

List<ExerciseSet> workoutSets(TrackerRecord w) {
  final raw = w.fields[FitField.sets];
  if (raw is! List) return const [];
  return [for (final v in raw) ?ExerciseSet.fromJson(v)];
}

int workoutMinutes(TrackerRecord w) => w.integer(FitField.minutes) ?? 0;
double workoutKm(TrackerRecord w) => w.number(FitField.distanceKm) ?? 0;
int workoutCalories(TrackerRecord w) => w.integer(FitField.calories) ?? 0;
String workoutActivity(TrackerRecord w) => w.str(FitField.activity) ?? 'other';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday-start week containing [d].
DateTime weekStart(DateTime d) =>
    _day(d).subtract(Duration(days: d.weekday - DateTime.monday));

@immutable
class FitnessTotals {
  const FitnessTotals({
    this.workouts = 0,
    this.minutes = 0,
    this.km = 0,
    this.calories = 0,
  });

  final int workouts;
  final int minutes;
  final double km;
  final int calories;

  FitnessTotals add(TrackerRecord w) => FitnessTotals(
    workouts: workouts + 1,
    minutes: minutes + workoutMinutes(w),
    km: km + workoutKm(w),
    calories: calories + workoutCalories(w),
  );

  num valueOf(String metric) => switch (metric) {
    'minutes' => minutes,
    'distance' => km,
    'calories' => calories,
    _ => workouts,
  };
}

FitnessTotals totalsBetween(
  Iterable<TrackerRecord> workouts,
  DateTime from,
  DateTime to,
) {
  var t = const FitnessTotals();
  for (final w in workouts) {
    final d = w.occurredAt ?? w.createdAt;
    if (!d.isBefore(from) && d.isBefore(to)) t = t.add(w);
  }
  return t;
}

/// Totals for the last [count] weeks ending with [now]'s week, oldest
/// first.
List<(DateTime, FitnessTotals)> weeklyTotals(
  Iterable<TrackerRecord> workouts,
  DateTime now, {
  int count = 8,
}) {
  final thisWeek = weekStart(now);
  return [
    for (var i = count - 1; i >= 0; i--)
      (
        thisWeek.subtract(Duration(days: 7 * i)),
        totalsBetween(
          workouts,
          thisWeek.subtract(Duration(days: 7 * i)),
          thisWeek.subtract(Duration(days: 7 * (i - 1))),
        ),
      ),
  ];
}

/// Consecutive weeks (ending this week or last) with at least one workout.
int weekStreak(Iterable<TrackerRecord> workouts, DateTime now) {
  final weeks = {
    for (final w in workouts) weekStart(w.occurredAt ?? w.createdAt),
  };
  var cursor = weekStart(now);
  if (!weeks.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 7));
  }
  var n = 0;
  while (weeks.contains(cursor)) {
    n++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return n;
}

/// Per-exercise history across all workouts.
@immutable
class ExerciseStats {
  const ExerciseStats({
    required this.exercise,
    required this.sessions,
    required this.bestWeightKg,
    required this.bestReps,
    required this.totalVolume,
    required this.lastDone,
  });

  final String exercise;
  final int sessions;
  final double bestWeightKg;
  final int bestReps;
  final double totalVolume;
  final DateTime lastDone;
}

List<ExerciseStats> exerciseHistory(Iterable<TrackerRecord> workouts) {
  final by = <String, List<(DateTime, ExerciseSet)>>{};
  final names = <String, String>{};
  for (final w in workouts) {
    final d = w.occurredAt ?? w.createdAt;
    for (final s in workoutSets(w)) {
      final key = s.exercise.trim().toLowerCase();
      if (key.isEmpty) continue;
      names.putIfAbsent(key, s.exercise.trim);
      (by[key] ??= []).add((d, s));
    }
  }
  final out = [
    for (final e in by.entries)
      ExerciseStats(
        exercise: names[e.key]!,
        sessions: e.value.map((x) => _day(x.$1)).toSet().length,
        bestWeightKg: e.value.fold(
          0.0,
          (m, x) => x.$2.weightKg > m ? x.$2.weightKg : m,
        ),
        bestReps: e.value.fold(0, (m, x) => x.$2.reps > m ? x.$2.reps : m),
        totalVolume: e.value.fold(0.0, (s, x) => s + x.$2.volume),
        lastDone: e.value
            .map((x) => x.$1)
            .reduce((a, b) => a.isAfter(b) ? a : b),
      ),
  ]..sort((a, b) => b.lastDone.compareTo(a.lastDone));
  return out;
}

/// Progress toward a goal record in its current period.
(num current, num target) goalProgress(
  TrackerRecord goal,
  Iterable<TrackerRecord> workouts,
  DateTime now,
) {
  final period = goal.str(FitField.period) ?? 'week';
  final from = period == 'month'
      ? DateTime(now.year, now.month)
      : weekStart(now);
  final to = period == 'month'
      ? DateTime(now.year, now.month + 1)
      : from.add(const Duration(days: 7));
  final totals = totalsBetween(workouts, from, to);
  return (
    totals.valueOf(goal.str(FitField.metric) ?? 'workouts'),
    goal.number(FitField.target) ?? 0,
  );
}

/// Personal bests per activity: longest, farthest.
Map<String, (int minutes, double km)> personalBests(
  Iterable<TrackerRecord> workouts,
) {
  final out = <String, (int, double)>{};
  for (final w in workouts) {
    final a = workoutActivity(w);
    final cur = out[a] ?? (0, 0.0);
    out[a] = (
      workoutMinutes(w) > cur.$1 ? workoutMinutes(w) : cur.$1,
      workoutKm(w) > cur.$2 ? workoutKm(w) : cur.$2,
    );
  }
  return out;
}
