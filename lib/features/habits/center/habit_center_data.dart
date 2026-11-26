import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/habit.dart';
import 'package:prism_plurality/domain/models/habit_completion.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/habits/providers/habit_providers.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const _uuid = Uuid();

DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// How a habit's progress is measured.
enum HabitUnit { times, minutes, amount }

/// Habit settings beyond the synced habit row, kept in one shared record
/// (`habit.meta`, parent = habit id).
class HabitMeta {
  const HabitMeta(this.record);
  final TrackerRecord? record;

  int get target => record?.integer('target') ?? 1;
  HabitUnit get unit => HabitUnit.values.firstWhere(
    (u) => u.name == record?.str('unit'),
    orElse: () => HabitUnit.times,
  );

  /// Label for one unit ("glass", "session", "page").
  String? get unitLabel => record?.str('unitLabel');
  String? get groupId => record?.str('group');
  bool get paused => record?.flag('paused') ?? false;
  DateTime? get pausedUntil =>
      DateTime.tryParse(record?.str('pausedUntil') ?? '');

  /// Weekdays (1–7) that are rest days.
  List<int> get recoveryDays => [
    for (final s in record?.strings('recovery') ?? const <String>[])
      ?int.tryParse(s),
  ];

  /// Day of month for monthly habits (null = not monthly).
  int? get monthDay => record?.integer('monthDay');
  List<String> get nextHabits => record?.strings('next') ?? const [];
  List<String> get reminders => record?.strings('reminders') ?? const [];
  bool get remindMissed => record?.flag('remindMissed') ?? false;

  /// Record kind that counts automatically (e.g. `nutri.drink`).
  String? get autoLog => record?.str('autoLog');
  int? get challengeTarget => record?.integer('challenge');
  DateTime? get challengeEnd =>
      DateTime.tryParse(record?.str('challengeEnd') ?? '');
  int get defaultMinutes => record?.integer('defaultMinutes') ?? 25;
  bool get shared => record?.flag('shared') ?? false;

  bool isPausedOn(DateTime day) =>
      paused &&
      (pausedUntil == null || !dayKey(day).isAfter(dayKey(pausedUntil!)));
}

/// Per-completion details (`habit.log`, parent = completion id).
class HabitLog {
  const HabitLog(this.record);
  final TrackerRecord? record;
  int get count => record?.integer('count') ?? 1;
  int? get minutes => record?.integer('minutes');
  double? get amount => record?.number('amount');
  List<String> get media => record?.strings('media') ?? const [];
  String? get locationId => record?.str('location');
  List<String> get coMembers => record?.strings('co') ?? const [];
  String? get source => record?.str('source');
}

/// Progress a completion adds toward the daily target.
num progressOf(HabitMeta meta, HabitLog log) => switch (meta.unit) {
  HabitUnit.times => log.count,
  HabitUnit.minutes => log.minutes ?? meta.defaultMinutes,
  HabitUnit.amount => log.amount ?? 1,
};

final habitMetasProvider = Provider<Map<String, HabitMeta>>((ref) {
  final rows =
      ref.watch(trackerKindProvider(TrackerKind.habitMeta)).value ??
      const <TrackerRecord>[];
  return {
    for (final r in rows.reversed)
      if (r.parentId != null) r.parentId!: HabitMeta(r),
  };
});

final habitLogsProvider = Provider<Map<String, HabitLog>>((ref) {
  final rows =
      ref.watch(trackerKindProvider(TrackerKind.habitLog)).value ??
      const <TrackerRecord>[];
  return {
    for (final r in rows)
      if (r.parentId != null) r.parentId!: HabitLog(r),
  };
});

/// habitId → skipped days.
final habitSkipsProvider = Provider<Map<String, Set<DateTime>>>((ref) {
  final rows =
      ref.watch(trackerKindProvider(TrackerKind.habitSkip)).value ??
      const <TrackerRecord>[];
  final out = <String, Set<DateTime>>{};
  for (final r in rows) {
    if (r.parentId == null || r.occurredAt == null) continue;
    out.putIfAbsent(r.parentId!, () => {}).add(dayKey(r.occurredAt!));
  }
  return out;
});

final habitGroupsProvider = Provider<List<TrackerRecord>>((ref) {
  final rows = [
    ...?ref.watch(trackerKindProvider(TrackerKind.habitGroup)).value,
  ];
  rows.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return rows;
});

/// Running timers: habitId → timer record.
final habitTimersProvider = Provider<Map<String, TrackerRecord>>((ref) {
  final rows =
      ref.watch(trackerKindProvider(TrackerKind.habitTimer)).value ??
      const <TrackerRecord>[];
  return {
    for (final r in rows)
      if (r.parentId != null) r.parentId!: r,
  };
});

/// Whether [habit] is scheduled on [day] (before skips/pauses).
bool scheduledOn(
  Habit habit,
  HabitMeta meta,
  DateTime day,
  List<HabitCompletion> history,
) {
  final d = dayKey(day);
  if (dayKey(habit.createdAt).isAfter(d)) return false;
  if (meta.recoveryDays.contains(d.weekday)) return false;
  if (meta.monthDay != null)
    return d.day ==
        meta.monthDay!.clamp(1, DateUtils.getDaysInMonth(d.year, d.month));
  switch (habit.frequency) {
    case HabitFrequency.daily:
    case HabitFrequency.custom:
      return true;
    case HabitFrequency.weekly:
      return habit.weeklyDays?.contains(d.weekday % 7) ?? true;
    case HabitFrequency.interval:
      final n = habit.intervalDays ?? 1;
      if (n <= 1) return true;
      final before = [
        for (final c in history)
          if (dayKey(c.completedAt).isBefore(d)) dayKey(c.completedAt),
      ]..sort();
      if (before.isEmpty) return true;
      return d.difference(before.last).inDays >= n;
  }
}

enum DayState { met, partial, missed, skipped, rest, paused, future }

/// Everything the Center and dashboards show for one habit.
class HabitView {
  HabitView({
    required this.habit,
    required this.meta,
    required this.completions,
    required this.logs,
    required this.skips,
  });
  final Habit habit;
  final HabitMeta meta;

  /// All completions, newest first.
  final List<HabitCompletion> completions;
  final Map<String, HabitLog> logs;
  final Set<DateTime> skips;

  late final Map<DateTime, List<HabitCompletion>> byDay = () {
    final m = <DateTime, List<HabitCompletion>>{};
    for (final c in completions) {
      m.putIfAbsent(dayKey(c.completedAt), () => []).add(c);
    }
    return m;
  }();

  HabitLog logOf(HabitCompletion c) => logs[c.id] ?? const HabitLog(null);

  num progressOn(DateTime day) => (byDay[dayKey(day)] ?? const []).fold<num>(
    0,
    (a, c) => a + progressOf(meta, logOf(c)),
  );

  DayState stateOn(DateTime day, {DateTime? now}) {
    final d = dayKey(day);
    final today = dayKey(now ?? DateTime.now());
    final p = progressOn(d);
    if (p >= meta.target) return DayState.met;
    if (d.isAfter(today)) return DayState.future;
    if (skips.contains(d)) return DayState.skipped;
    if (meta.isPausedOn(d)) return DayState.paused;
    if (!scheduledOn(habit, meta, d, completions))
      return p > 0 ? DayState.partial : DayState.rest;
    return p > 0 ? DayState.partial : DayState.missed;
  }

  bool get isDueToday {
    final s = stateOn(DateTime.now());
    return s == DayState.partial || s == DayState.missed;
  }

  num get todayProgress => progressOn(DateTime.now());
  double get todayFraction => meta.target <= 0
      ? 1
      : (todayProgress / meta.target).clamp(0, 1).toDouble();

  /// Consecutive met days; skipped, rest and paused days never break it,
  /// and an unfinished today doesn't either.
  int get currentStreak {
    var n = 0;
    var d = dayKey(DateTime.now());
    if (stateOn(d) != DayState.met) d = d.subtract(const Duration(days: 1));
    final start = dayKey(habit.createdAt);
    while (!d.isBefore(start)) {
      final s = stateOn(d);
      if (s == DayState.met) {
        n++;
      } else if (s == DayState.missed || s == DayState.partial) {
        break;
      }
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  int get longestStreak {
    var best = 0, run = 0;
    final today = dayKey(DateTime.now());
    for (
      var d = dayKey(habit.createdAt);
      !d.isAfter(today);
      d = d.add(const Duration(days: 1))
    ) {
      final s = stateOn(d);
      if (s == DayState.met) {
        run++;
        if (run > best) best = run;
      } else if ((s == DayState.missed || s == DayState.partial) &&
          d != today) {
        run = 0;
      }
    }
    return best;
  }

  /// Met days ÷ scheduled days in the range (skips excluded).
  double consistency(DateTime from, DateTime to) {
    var due = 0, met = 0;
    for (
      var d = dayKey(from);
      !d.isAfter(dayKey(to));
      d = d.add(const Duration(days: 1))
    ) {
      final s = stateOn(d);
      if (s == DayState.met) {
        met++;
        due++;
      } else if (s == DayState.missed || s == DayState.partial) {
        if (d != dayKey(DateTime.now())) due++;
      }
    }
    return due == 0 ? 0 : met / due;
  }

  List<HabitCompletion> completionsBetween(DateTime from, DateTime to) => [
    for (final c in completions)
      if (!c.completedAt.isBefore(from) && c.completedAt.isBefore(to)) c,
  ];

  double? averageMinutes(Iterable<HabitCompletion> cs) {
    final m = [for (final c in cs) ?logOf(c).minutes];
    return m.isEmpty ? null : m.reduce((a, b) => a + b) / m.length;
  }

  double? averageRating(Iterable<HabitCompletion> cs) {
    final r = [for (final c in cs) ?c.rating];
    return r.isEmpty ? null : r.reduce((a, b) => a + b) / r.length;
  }
}

final habitViewsProvider = Provider<Map<String, HabitView>>((ref) {
  final habits = ref.watch(habitsProvider).value ?? const <Habit>[];
  final all =
      ref.watch(allCompletionsProvider).value ?? const <HabitCompletion>[];
  final metas = ref.watch(habitMetasProvider);
  final logs = ref.watch(habitLogsProvider);
  final skips = ref.watch(habitSkipsProvider);
  final byHabit = <String, List<HabitCompletion>>{};
  for (final c in all) {
    byHabit.putIfAbsent(c.habitId, () => []).add(c);
  }
  return {
    for (final h in habits)
      h.id: HabitView(
        habit: h,
        meta: metas[h.id] ?? const HabitMeta(null),
        completions: (byHabit[h.id] ?? [])
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt)),
        logs: logs,
        skips: skips[h.id] ?? const {},
      ),
  };
});

class HabitCenterActions {
  HabitCenterActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  /// Logs one completion with its own details and links. Returns its id.
  Future<String> log({
    required Habit habit,
    String? memberId,
    DateTime? at,
    int count = 1,
    int? minutes,
    double? amount,
    int? rating,
    String? notes,
    List<String> media = const [],
    String? locationId,
    List<String> coMembers = const [],
    List<RecordRef> linkTo = const [],
    String? source,
  }) async {
    final id = _uuid.v4();
    await ref
        .read(habitNotifierProvider.notifier)
        .completeHabit(
          habitId: habit.id,
          completedByMemberId: memberId,
          notes: notes,
          rating: rating,
          wasFronting:
              memberId != null &&
              memberId == ref.read(currentFronterProvider).value?.id,
          completedAt: at,
          completionId: id,
        );
    final fields = <String, Object?>{
      'habitId': habit.id,
      if (count != 1) 'count': count,
      'minutes': ?minutes,
      'amount': ?amount,
      if (media.isNotEmpty) 'media': media,
      'location': ?locationId,
      if (coMembers.isNotEmpty) 'co': coMembers,
      'source': ?source,
    };
    if (fields.length > 1) {
      await _t.create(
        kind: TrackerKind.habitLog,
        parentId: id,
        occurredAt: at ?? DateTime.now(),
        memberId: memberId,
        fields: fields,
      );
    }
    final links = ref.read(linkActionsProvider);
    final self = RecordRef(RecordRef.habitLog, id);
    if (locationId != null)
      await links.link(
        self,
        RecordRef(RecordRef.location, locationId),
        category: 'during',
      );
    for (final r in linkTo) {
      await links.link(self, r, category: 'related');
    }
    return id;
  }

  /// Updates the details record of a completion.
  Future<void> saveLog(
    HabitCompletion c,
    HabitLog existing,
    Map<String, Object?> changes,
  ) async {
    if (existing.record != null) {
      await _t.save(existing.record!.withFields(changes));
    } else {
      await _t.create(
        kind: TrackerKind.habitLog,
        parentId: c.id,
        occurredAt: c.completedAt,
        memberId: c.completedByMemberId,
        fields: {'habitId': c.habitId, ...changes},
      );
    }
  }

  /// Removes a completion together with its details and links.
  Future<void> deleteCompletion(HabitCompletion c) async {
    await ref
        .read(habitNotifierProvider.notifier)
        .uncompleteHabit(habitId: c.habitId, completionId: c.id);
    await _cleanup({c.id}, {'${RecordRef.habitLog}:${c.id}'});
  }

  /// Deletes a habit with its completions, extensions and links.
  Future<void> deleteHabit(Habit h) async {
    final completions =
        ref.read(habitViewsProvider)[h.id]?.completions ??
        const <HabitCompletion>[];
    await ref.read(habitNotifierProvider.notifier).deleteHabit(h.id);
    await _cleanup(
      {h.id, for (final c in completions) c.id},
      {
        '${RecordRef.habit}:${h.id}',
        for (final c in completions) '${RecordRef.habitLog}:${c.id}',
      },
    );
  }

  Future<void> _cleanup(Set<String> parents, Set<String> refs) async {
    final all = await ref.read(trackerRecordRepositoryProvider).getAll();
    final repo = ref.read(trackerRecordRepositoryProvider);
    for (final r in all) {
      final owned =
          r.parentId != null &&
          parents.contains(r.parentId) &&
          r.kind.startsWith('habit.');
      final linked =
          r.kind == TrackerKind.linkEdge &&
          (refs.contains(r.str('a')) || refs.contains(r.str('b')));
      if (owned || linked) await repo.delete(r.id);
    }
  }

  Future<void> saveMeta(String habitId, Map<String, Object?> changes) async {
    final existing = ref.read(habitMetasProvider)[habitId]?.record;
    if (existing != null) {
      await _t.save(existing.withFields(changes));
    } else {
      await _t.create(
        kind: TrackerKind.habitMeta,
        parentId: habitId,
        fields: changes,
      );
    }
  }

  Future<void> toggleSkip(String habitId, DateTime day) async {
    final d = dayKey(day);
    final rows =
        ref.read(trackerKindProvider(TrackerKind.habitSkip)).value ??
        const <TrackerRecord>[];
    final existing = rows
        .where(
          (r) =>
              r.parentId == habitId &&
              r.occurredAt != null &&
              dayKey(r.occurredAt!) == d,
        )
        .toList();
    if (existing.isNotEmpty) {
      for (final r in existing) {
        await _t.delete(r.id, children: false);
      }
    } else {
      await _t.create(
        kind: TrackerKind.habitSkip,
        parentId: habitId,
        occurredAt: d,
      );
    }
  }

  Future<void> startTimer(String habitId) async {
    if (ref.read(habitTimersProvider).containsKey(habitId)) return;
    await _t.create(
      kind: TrackerKind.habitTimer,
      parentId: habitId,
      occurredAt: DateTime.now(),
      fields: {'pausedMs': 0},
    );
  }

  Future<void> pauseTimer(TrackerRecord t) async {
    final pausedAt = DateTime.tryParse(t.str('pausedAt') ?? '');
    if (pausedAt == null) {
      await _t.save(
        t.withFields({'pausedAt': DateTime.now().toIso8601String()}),
      );
    } else {
      final extra = DateTime.now().difference(pausedAt).inMilliseconds;
      await _t.save(
        t.withFields({
          'pausedAt': null,
          'pausedMs': (t.integer('pausedMs') ?? 0) + extra,
        }),
      );
    }
  }

  /// Elapsed active time of a timer.
  static Duration elapsed(TrackerRecord t, [DateTime? now]) {
    final start = t.occurredAt ?? t.createdAt;
    final pausedAt = DateTime.tryParse(t.str('pausedAt') ?? '');
    final end = pausedAt ?? now ?? DateTime.now();
    return end.difference(start) -
        Duration(milliseconds: t.integer('pausedMs') ?? 0);
  }

  Future<void> discardTimer(TrackerRecord t) =>
      _t.delete(t.id, children: false);

  Future<TrackerRecord> saveGroup({
    TrackerRecord? editing,
    required String name,
    required List<String> habitIds,
    int? color,
    String? icon,
  }) async {
    final fields = {'habits': habitIds, 'color': color, 'icon': icon};
    if (editing != null) {
      final next = editing.copyWith(title: name).withFields(fields);
      await _t.save(next);
      return next;
    }
    return _t.create(
      kind: TrackerKind.habitGroup,
      title: name,
      fields: fields,
      sortOrder: ref.read(habitGroupsProvider).length,
    );
  }
}

final habitCenterActionsProvider = Provider<HabitCenterActions>(
  HabitCenterActions.new,
);
