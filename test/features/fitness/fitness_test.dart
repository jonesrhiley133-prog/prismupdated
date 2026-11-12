import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/fitness/utils/fitness.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

TrackerRecord _w(
  DateTime at,
  String activity, {
  int min = 30,
  double km = 0,
  List<ExerciseSet> sets = const [],
}) =>
    TrackerRecord(
      id: '$at$activity',
      kind: TrackerKind.fitnessWorkout,
      occurredAt: at,
      createdAt: at,
      modifiedAt: at,
    ).withFields({
      FitField.activity: activity,
      FitField.minutes: min,
      FitField.distanceKm: km,
      if (sets.isNotEmpty) FitField.sets: [for (final s in sets) s.toJson()],
    });

void main() {
  final now = DateTime(2026, 11, 12, 18); // Thursday
  final ws = [
    _w(DateTime(2026, 11, 10), 'run', min: 30, km: 5),
    _w(
      DateTime(2026, 11, 12),
      'strength',
      min: 45,
      sets: const [
        ExerciseSet(exercise: 'Squat', sets: 3, reps: 8, weightKg: 60),
      ],
    ),
    _w(
      DateTime(2026, 11, 4),
      'strength',
      sets: const [
        ExerciseSet(exercise: 'squat ', sets: 3, reps: 10, weightKg: 55),
        ExerciseSet(exercise: 'Row', sets: 2, reps: 12, weightKg: 30),
      ],
    ),
    _w(DateTime(2026, 10, 28), 'walk', min: 60, km: 4.2),
    _w(DateTime(2026, 10, 7), 'run', min: 20, km: 3),
  ];

  test('weekly totals, streak and goal progress', () {
    expect(weekStart(now), DateTime(2026, 11, 9));
    final t = totalsBetween(ws, DateTime(2026, 11, 9), DateTime(2026, 11, 16));
    expect((t.workouts, t.minutes, t.km), (2, 75, 5.0));
    expect(weekStreak(ws, now), 3);
    expect(weeklyTotals(ws, now, count: 3).map((w) => w.$2.workouts), [
      1,
      1,
      2,
    ]);
    final goal =
        TrackerRecord(
          id: 'g',
          kind: TrackerKind.fitnessGoal,
          createdAt: now,
          modifiedAt: now,
        ).withFields({
          FitField.metric: 'minutes',
          FitField.period: 'week',
          FitField.target: 150,
        });
    expect(goalProgress(goal, ws, now), (75, 150));
    final month = goal.withFields({
      FitField.metric: 'distance',
      FitField.period: 'month',
    });
    expect(goalProgress(month, ws, now).$1, 5.0);
  });

  test('exercise history merges names and keeps bests', () {
    final h = exerciseHistory(ws);
    final squat = h.firstWhere((e) => e.exercise.toLowerCase() == 'squat');
    expect(squat.sessions, 2);
    expect(squat.bestWeightKg, 60);
    expect(squat.bestReps, 10);
    expect(squat.totalVolume, 3 * 8 * 60 + 3 * 10 * 55);
    expect(squat.lastDone, DateTime(2026, 11, 12));
    expect(personalBests(ws)['run'], (30, 5.0));
  });
}
