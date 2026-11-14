import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/habits/center/habit_center_data.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/fronting/providers/sleep_providers.dart';
import 'package:prism_plurality/shared/notify.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Keeps habit reminders scheduled for the next week: each reminder time
/// on scheduled days, never on skipped, paused or rest days, and not for
/// the rest of today once the target is reached. The optional evening
/// nudge fires at 20:00 only while the target is still open.
class HabitReminderScheduler {
  HabitReminderScheduler(this.ref);
  final Ref ref;
  String _sig = '';
  Timer? _debounce;

  void start() {
    ref.listen<Map<String, HabitView>>(habitViewsProvider, (_, next) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), () => _reschedule(next));
    }, fireImmediately: true);
  }

  void dispose() => _debounce?.cancel();

  Future<void> _reschedule(Map<String, HabitView> views) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final today = dayKey(now);
    final plan = <(DateTime, String, String)>[];
    for (final v in views.values) {
      if (!v.habit.isActive) continue;
      final times = [
        for (final r in v.meta.reminders)
          if (r.split(':') case [final h, final m]) (int.tryParse(h) ?? 9) * 60 + (int.tryParse(m) ?? 0),
      ];
      if (times.isEmpty && !v.meta.remindMissed) continue;
      for (var i = 0; i < 7; i++) {
        final d = today.add(Duration(days: i));
        final s = v.stateOn(d);
        if (s == DayState.rest || s == DayState.paused || s == DayState.skipped || s == DayState.met) continue;
        if (!scheduledOn(v.habit, v.meta, d, v.completions)) continue;
        final left = v.meta.target - v.progressOn(d);
        for (final t in times) {
          final at = d.add(Duration(minutes: t));
          if (at.isAfter(now)) plan.add((at, v.habit.name, i == 0 && left < v.meta.target ? '${left.ceil()} to go today' : 'Time for ${v.habit.name}'));
        }
        if (v.meta.remindMissed) {
          final at = d.add(const Duration(hours: 20));
          if (at.isAfter(now)) plan.add((at, v.habit.name, 'Your target isn’t reached yet — there’s still time'));
        }
      }
    }
    plan.sort((a, b) => a.$1.compareTo(b.$1));
    final sig = plan.map((p) => '${p.$1.millisecondsSinceEpoch}${p.$2}').join('|');
    if (sig == _sig) return;
    _sig = sig;
    try {
      final svc = ref.read(localNotificationServiceProvider);
      await svc.cancelRange(PrismNotify.habitBase, PrismNotify.range);
      for (final (i, p) in plan.take(PrismNotify.range).indexed) {
        await svc.scheduleOneShot(
          id: PrismNotify.habitBase + i,
          title: p.$2,
          body: p.$3,
          scheduledFor: p.$1,
          details: PrismNotify.details('prism_habit_routines', 'Habit reminders'),
          payload: 'prism:habits',
        );
      }
    } catch (e) {
      debugPrint('[Habits] reminder scheduling failed: $e');
    }
  }
}

/// Counts connected activity toward habits set to log automatically
/// (drinks, meals, workouts, journal entries, dreams, mood check-ins,
/// finished sleep). Each auto completion links back to its source record.
class HabitAutoLogger {
  HabitAutoLogger(this.ref);
  final Ref ref;
  final DateTime _started = DateTime.now();
  Set<String>? _tracker;
  Set<String>? _moods;
  String? _sleepId;

  void start() {
    ref.listen<AsyncValue<List<TrackerRecord>>>(trackerRecordsProvider, (_, next) => _onTracker(next.value), fireImmediately: true);
    ref.listen<AsyncValue<List<MoodEntry>>>(moodEntriesProvider, (_, next) => _onMood(next.value), fireImmediately: true);
    ref.listen<AsyncValue<FrontingSession?>>(activeSleepSessionProvider, (prev, next) {
      final was = prev?.value?.id ?? _sleepId;
      _sleepId = next.value?.id;
      if (was != null && next.hasValue && next.value == null) {
        _fire('sleep', RecordRef(RecordRef.front, was), null);
      }
    }, fireImmediately: true);
  }

  bool _fresh(DateTime created) => created.isAfter(_started.subtract(const Duration(seconds: 10)));

  void _onTracker(List<TrackerRecord>? list) {
    if (list == null) return;
    final ids = {for (final r in list) r.id};
    final prev = _tracker;
    _tracker = ids;
    if (prev == null) return;
    for (final r in list) {
      if (prev.contains(r.id) || !_fresh(r.createdAt)) continue;
      if (const {'nutri.drink', 'nutri.meal', 'fitness.workout', 'journal.entry', 'dream.entry'}.contains(r.kind)) {
        _fire(r.kind, RecordRef(RecordRef.rec, r.id), r.memberId, minutes: r.integer('minutes'));
      }
    }
  }

  void _onMood(List<MoodEntry>? list) {
    if (list == null) return;
    final ids = {for (final m in list) m.id};
    final prev = _moods;
    _moods = ids;
    if (prev == null) return;
    for (final m in list) {
      if (!prev.contains(m.id) && _fresh(m.createdAt)) _fire('mood', RecordRef(RecordRef.mood, m.id), m.memberId);
    }
  }

  Future<void> _fire(String source, RecordRef origin, String? memberId, {int? minutes}) async {
    final views = ref.read(habitViewsProvider).values.where((v) => v.habit.isActive && v.meta.autoLog == source && !v.meta.isPausedOn(DateTime.now()));
    final logs = ref.read(trackerKindProvider(TrackerKind.habitLog)).value ?? const <TrackerRecord>[];
    for (final v in views) {
      if (logs.any((l) => l.str('habitId') == v.habit.id && l.str('source') == origin.key)) continue;
      try {
        await ref.read(habitCenterActionsProvider).log(
          habit: v.habit,
          memberId: memberId ?? ref.read(currentFronterProvider).value?.id,
          minutes: v.meta.unit == HabitUnit.minutes ? (minutes ?? v.meta.defaultMinutes) : minutes,
          source: origin.key,
          linkTo: [origin],
        );
      } catch (e) {
        debugPrint('[Habits] auto log failed: $e');
      }
    }
  }
}

final habitReminderSchedulerProvider = Provider<HabitReminderScheduler>((ref) {
  final s = HabitReminderScheduler(ref)..start();
  ref.onDispose(s.dispose);
  return s;
});

final habitAutoLoggerProvider = Provider<HabitAutoLogger>((ref) => HabitAutoLogger(ref)..start());

/// Starts the habit services a few seconds after launch.
final habitCenterBootProvider = Provider<void>((ref) {
  final t = Timer(const Duration(seconds: 6), () {
    if (!ref.mounted) return;
    ref.read(habitReminderSchedulerProvider);
    ref.read(habitAutoLoggerProvider);
  });
  ref.onDispose(t.cancel);
});
