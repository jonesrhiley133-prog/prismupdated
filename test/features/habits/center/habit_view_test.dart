import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/habit.dart';
import 'package:prism_plurality/domain/models/habit_completion.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/habits/center/habit_center_data.dart';

void main() {
  final today = dayKey(DateTime.now());
  DateTime ago(int d, [int h = 10]) => today.subtract(Duration(days: d)).add(Duration(hours: h));
  final habit = Habit(id: 'h', name: 'Water', createdAt: today.subtract(const Duration(days: 30)), modifiedAt: today);
  HabitCompletion c(String id, DateTime at) => HabitCompletion(id: id, habitId: 'h', completedAt: at, createdAt: at, modifiedAt: at);
  HabitMeta meta(Map<String, Object?> f) =>
      HabitMeta(TrackerRecord(id: 'm', kind: 'habit.meta', parentId: 'h', createdAt: today, modifiedAt: today).withFields(f));

  HabitView view(List<HabitCompletion> cs, {Map<String, Object?> m = const {'target': 3}, Set<DateTime> skips = const {}, Map<String, HabitLog> logs = const {}}) =>
      HabitView(habit: habit, meta: meta(m), completions: cs..sort((a, b) => b.completedAt.compareTo(a.completedAt)), logs: logs, skips: skips);

  test('several completions a day add up toward the target', () {
    final v = view([c('1', ago(0, 8)), c('2', ago(0, 12))]);
    expect(v.todayProgress, 2);
    expect(v.stateOn(today), DayState.partial);
    expect(v.todayFraction, closeTo(2 / 3, 1e-9));
  });

  test('a completion can carry a count, minutes or an amount', () {
    final log = HabitLog(TrackerRecord(id: 'l', kind: 'habit.log', parentId: '1', createdAt: today, modifiedAt: today).withFields({'count': 3}));
    expect(view([c('1', ago(0))], logs: {'1': log}).stateOn(today), DayState.met);
    final mins = HabitLog(TrackerRecord(id: 'l', kind: 'habit.log', parentId: '1', createdAt: today, modifiedAt: today).withFields({'minutes': 40}));
    expect(view([c('1', ago(0))], m: {'target': 30, 'unit': 'minutes'}, logs: {'1': mins}).stateOn(today), DayState.met);
  });

  test('skipped and rest days keep the streak; an unfinished today does not break it', () {
    final cs = <HabitCompletion>[
      for (final d in [1, 3, 4]) ...[c('a$d', ago(d, 8)), c('b$d', ago(d, 12)), c('c$d', ago(d, 18))],
    ];
    final v = view(cs, skips: {today.subtract(const Duration(days: 2))});
    expect(v.currentStreak, 3);
    // Without the skip, day 2 is missed and the streak is just 1.
    expect(view(cs).currentStreak, 1);
    final rest = today.subtract(const Duration(days: 2)).weekday;
    expect(view(cs, m: {'target': 3, 'recovery': ['$rest']}).currentStreak, 3);
  });

  test('paused days count as neither missed nor met', () {
    final v = view([], m: {'target': 1, 'paused': true});
    expect(v.stateOn(today), DayState.paused);
    expect(v.isDueToday, isFalse);
  });

  test('consistency counts met scheduled days only', () {
    final cs = [for (final d in [1, 2]) for (var i = 0; i < 3; i++) c('$d$i', ago(d, 8 + i))];
    final v = view(cs);
    expect(v.consistency(today.subtract(const Duration(days: 4)), today.subtract(const Duration(days: 1))), closeTo(0.5, 1e-9));
  });

  test('monthly habits are only scheduled on their day', () {
    final m = meta({'monthDay': today.day});
    expect(scheduledOn(habit, m, today, const []), isTrue);
    expect(scheduledOn(habit, m, today.add(const Duration(days: 1)), const []), today.add(const Duration(days: 1)).day == today.day);
  });
}
