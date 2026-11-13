import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/router/app_router.dart' show appRootNavigatorKey;
import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/alter_status/status_providers.dart';
import 'package:prism_plurality/features/automations/automation_models.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/calendar/utils/recurrence.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/nutrition/nutrition_data.dart';
import 'package:prism_plurality/shared/notify.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const _uuid = Uuid();

final automationRulesProvider = Provider<List<AutoRule>>((ref) {
  final rules = [for (final r in ref.watch(trackerKindProvider(TrackerKind.autoRule)).value ?? const <TrackerRecord>[]) AutoRule(r)];
  rules.sort((a, b) => b.priority != a.priority ? b.priority - a.priority : a.record.createdAt.compareTo(b.record.createdAt));
  return rules;
});

final automationLogProvider = Provider<List<TrackerRecord>>((ref) => ref.watch(trackerKindProvider(TrackerKind.autoLog)).value ?? const []);

final automationCountersProvider = Provider<List<TrackerRecord>>((ref) => ref.watch(trackerKindProvider(TrackerKind.autoCounter)).value ?? const []);

/// Recent in-app messages from automations (for the Home card).
final automationMessagesProvider = Provider<List<TrackerRecord>>((ref) {
  final cutoff = DateTime.now().subtract(const Duration(hours: 24));
  return [
    for (final l in ref.watch(automationLogProvider))
      if (l.str('message') != null && !l.flag('undone') && !l.flag('dismissed') && (l.occurredAt ?? l.createdAt).isAfter(cutoff)) l,
  ];
});

/// Runs automation rules while Prism is open.
class AutomationEngine {
  AutomationEngine(this.ref);
  final Ref ref;
  final DateTime _started = DateTime.now();
  Set<String>? _sessions;
  Map<String, String?> _sessionMembers = {};
  Set<String>? _tracker;
  Set<String>? _moods;
  Timer? _tick;
  final _recentRuns = <DateTime>[];
  final _fired = <String>{};
  bool _running = false;
  final _queue = <(String, AutoContext, Map<String, Object?>)>[];

  void start() {
    ref.listen<AsyncValue<List<FrontingSession>>>(activeSessionsProvider, (_, next) => _onSessions(next.value), fireImmediately: true);
    ref.listen<AsyncValue<List<TrackerRecord>>>(trackerRecordsProvider, (_, next) => _onTracker(next.value), fireImmediately: true);
    ref.listen<AsyncValue<List<MoodEntry>>>(moodEntriesProvider, (_, next) => _onMood(next.value), fireImmediately: true);
    ref.listen(frontingHistoryProvider(60), (_, _) {}); // keeps today's switches available
    ref.listen<List<AutoRule>>(automationRulesProvider, (_, next) {
      _scheduleTimed(next);
      _updateTicker(next);
    }, fireImmediately: true);
  }

  static const _tickTriggers = {AutoTrigger.time, AutoTrigger.eventSoon, AutoTrigger.hydrationMissing, AutoTrigger.condition};

  /// The minute clock only runs while a clock-based rule is enabled.
  void _updateTicker(List<AutoRule> rules) {
    final need = rules.any((r) => r.enabled && _tickTriggers.contains(r.triggerType));
    if (need && _tick == null) {
      _tick = Timer.periodic(const Duration(minutes: 1), (_) => _onTick());
    } else if (!need && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  String _timedSignature = '';

  /// Notifications of time-based rules are scheduled with the system so
  /// they arrive even when Prism is closed (the engine skips them).
  Future<void> _scheduleTimed(List<AutoRule> rules) async {
    if (kIsWeb) return;
    final timed = [
      for (final r in rules)
        if (r.enabled && r.triggerType == AutoTrigger.time && r.conditions.isEmpty)
          for (final a in r.actions)
            if (a['type'] == AutoAction.notify) (r, a),
    ];
    final sig = [for (final (r, a) in timed) '${r.id}${r.trigger}$a'].join('|');
    if (sig == _timedSignature) return;
    _timedSignature = sig;
    final svc = ref.read(localNotificationServiceProvider);
    const base = PrismNotify.automationBase + 500;
    try {
      await svc.cancelRange(base, 500);
      var i = 0;
      for (final (r, a) in timed) {
        final minute = (r.trigger['time'] as num?)?.toInt() ?? 9 * 60;
        final days = r.trigger['days'] is List ? [for (final d in r.trigger['days'] as List) (d as num).toInt()] : const [1, 2, 3, 4, 5, 6, 7];
        for (final d in days) {
          if (i >= 500) break;
          final ctx = AutoContext(trigger: AutoTrigger.time);
          await svc.scheduleExactWeekly(
            id: base + i++,
            title: _fill(a['title'] as String? ?? r.name, ctx),
            body: _fill(a['text'] as String?, ctx),
            time: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
            weekday: d,
            details: PrismNotify.details('prism_automations', 'Automations'),
          );
        }
      }
    } catch (e) {
      debugPrint('[Automations] scheduling failed: $e');
    }
  }

  void dispose() => _tick?.cancel();

  List<AutoRule> get _rules => [for (final r in ref.read(automationRulesProvider)) if (r.enabled) r];

  void _onSessions(List<FrontingSession>? list) {
    if (list == null) return;
    final normal = [for (final s in list) if (s.sessionType == SessionType.normal) s];
    final ids = {for (final s in normal) s.id};
    final members = {for (final s in normal) s.id: s.memberId};
    final prev = _sessions;
    _sessions = ids;
    final prevMembers = _sessionMembers;
    _sessionMembers = members;
    if (prev == null) return;
    for (final s in normal.where((s) => !prev.contains(s.id))) {
      final ctx = AutoContext(trigger: AutoTrigger.frontStart, memberId: s.memberId, record: '${RecordRef.front}:${s.id}');
      _fire(AutoTrigger.frontStart, ctx);
      _fire(AutoTrigger.alterActive, AutoContext(trigger: AutoTrigger.alterActive, memberId: s.memberId, record: ctx.record));
    }
    for (final id in prev.difference(ids)) {
      _fire(AutoTrigger.frontEnd, AutoContext(trigger: AutoTrigger.frontEnd, memberId: prevMembers[id], record: '${RecordRef.front}:$id'));
    }
  }

  void _onTracker(List<TrackerRecord>? list) {
    if (list == null) return;
    final ids = {for (final r in list) r.id};
    final prev = _tracker;
    _tracker = ids;
    if (prev == null) return;
    for (final r in list) {
      if (prev.contains(r.id) || r.fields['auto'] != null) continue;
      if (r.createdAt.isBefore(_started.subtract(const Duration(seconds: 10)))) continue; // synced history
      final type = switch (r.kind) {
        TrackerKind.journalEntry => AutoTrigger.journal,
        TrackerKind.dreamEntry => AutoTrigger.dream,
        _ => null,
      };
      if (type != null) _fire(type, AutoContext(trigger: type, memberId: r.memberId, record: '${RecordRef.rec}:${r.id}', title: r.title));
    }
  }

  void _onMood(List<MoodEntry>? list) {
    if (list == null) return;
    final ids = {for (final m in list) m.id};
    final prev = _moods;
    _moods = ids;
    if (prev == null) return;
    for (final m in list) {
      if (prev.contains(m.id) || m.createdAt.isBefore(_started.subtract(const Duration(seconds: 10)))) continue;
      _fire(AutoTrigger.mood, AutoContext(trigger: AutoTrigger.mood, memberId: m.memberId, record: '${RecordRef.mood}:${m.id}', moodValue: m.mood));
    }
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Future<void> _onTick() async {
    final now = DateTime.now();
    for (final r in _rules) {
      final t = r.trigger;
      switch (r.triggerType) {
        case AutoTrigger.time:
          final minute = (t['time'] as num?)?.toInt() ?? 9 * 60;
          final days = t['days'] is List ? [for (final d in t['days'] as List) (d as num).toInt()] : const [1, 2, 3, 4, 5, 6, 7];
          final nowMin = now.hour * 60 + now.minute;
          final key = 'time:${r.id}:${_dayKey(now)}';
          if (days.contains(now.weekday) && nowMin >= minute && nowMin - minute < 5 && !_fired.contains(key) && (r.lastRun == null || _dayKey(r.lastRun!) != _dayKey(now))) {
            _fired.add(key);
            await _run(r, AutoContext(trigger: AutoTrigger.time));
          }
        case AutoTrigger.eventSoon:
          final minutes = (t['minutes'] as num?)?.toInt() ?? 30;
          final events = ref.read(calendarEventsProvider).value ?? const <CalendarEvent>[];
          for (final o in expandCalendarEvents(events, now, now.add(Duration(minutes: minutes + 1)))) {
            if (o.event.isAllDay) continue;
            final until = o.start.difference(now).inMinutes;
            final key = 'event:${r.id}:${o.event.id}:${o.start.toIso8601String()}';
            if (until >= 0 && until <= minutes && !_fired.contains(key)) {
              _fired.add(key);
              await _run(r, AutoContext(trigger: AutoTrigger.eventSoon, record: '${RecordRef.event}:${o.event.id}', title: o.event.title));
            }
          }
        case AutoTrigger.hydrationMissing:
          final hours = (t['hours'] as num?)?.toDouble() ?? 3;
          final drinks = ref.read(drinksProvider);
          final today = DateTime(now.year, now.month, now.day);
          DateTime last = today.add(const Duration(hours: 7));
          for (final d in drinks) {
            final at = d.occurredAt ?? d.createdAt;
            if (at.isAfter(last)) last = at;
          }
          if (now.difference(last).inMinutes >= hours * 60 && now.isAfter(today.add(const Duration(hours: 7)))) {
            await _run(r, AutoContext(trigger: AutoTrigger.hydrationMissing));
          }
        case AutoTrigger.condition:
          final key = 'cond:${r.id}:${_dayKey(now)}';
          if (!_fired.contains(key) && _compare(_metric(t['metric'] as String? ?? 'hydrationToday'), t['op'] as String? ?? '<', (t['value'] as num?)?.toDouble() ?? 0)) {
            if (r.lastRun != null && _dayKey(r.lastRun!) == _dayKey(now)) continue;
            _fired.add(key);
            await _run(r, AutoContext(trigger: AutoTrigger.condition));
          }
      }
    }
  }

  void _fire(String type, AutoContext ctx) {
    for (final r in _rules) {
      if (r.triggerType != type) continue;
      final only = r.trigger['alters'];
      if (only is List && only.isNotEmpty && !only.contains(ctx.memberId)) continue;
      unawaited(_run(r, ctx));
    }
  }

  bool _compare(double v, String op, double target) => switch (op) {
    '<' => v < target,
    '<=' => v <= target,
    '>' => v > target,
    '>=' => v >= target,
    '=' => v == target,
    _ => false,
  };

  double _metric(String key) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isToday(DateTime d) => !d.isBefore(today);
    switch (key) {
      case 'hydrationToday':
        return ref.read(drinksProvider).where((d) => isToday(d.occurredAt ?? d.createdAt)).fold(0, (a, d) => a + drinkMl(d)).toDouble();
      case 'mealsToday':
        return ref.read(mealsProvider).where((m) => isToday(m.occurredAt ?? m.createdAt)).length.toDouble();
      case 'moodToday':
        final ms = [for (final m in ref.read(moodEntriesProvider).value ?? const <MoodEntry>[]) if (isToday(m.recordedAt)) m.mood];
        return ms.isEmpty ? 0 : ms.reduce((a, b) => a + b) / ms.length;
      case 'journalToday':
        return (ref.read(trackerKindProvider(TrackerKind.journalEntry)).value ?? const []).where((r) => isToday(r.occurredAt ?? r.createdAt)).length.toDouble();
      case 'dreamsWeek':
        final start = today.subtract(Duration(days: now.weekday - 1));
        return (ref.read(trackerKindProvider(TrackerKind.dreamEntry)).value ?? const []).where((r) => !(r.occurredAt ?? r.createdAt).isBefore(start)).length.toDouble();
      case 'switchesToday':
        return (_switchesToday).toDouble();
    }
    return 0;
  }

  int get _switchesToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return (ref.read(frontingHistoryProvider(60)).value ?? const <FrontingSession>[])
        .where((s) => s.sessionType == SessionType.normal && !s.startTime.isBefore(today))
        .length;
  }

  bool _conditionsMet(AutoRule r, AutoContext ctx) {
    final now = ctx.at;
    final fronters = {for (final s in ref.read(activeSessionsProvider).value ?? const <FrontingSession>[]) if (s.sessionType == SessionType.normal) ?s.memberId};
    for (final c in r.conditions) {
      final ok = switch (c['type']) {
        AutoCondition.alter => () {
          final ids = c['ids'] is List ? (c['ids'] as List).cast<String>() : const <String>[];
          final who = c['who'] == 'fronting' ? fronters : {?ctx.memberId};
          return ids.isEmpty || who.any(ids.contains);
        }(),
        AutoCondition.timeOfDay => () {
          final from = (c['from'] as num?)?.toInt() ?? 0, to = (c['to'] as num?)?.toInt() ?? 1440;
          final m = now.hour * 60 + now.minute;
          return from <= to ? m >= from && m < to : (m >= from || m < to);
        }(),
        AutoCondition.weekday => (c['days'] is List ? (c['days'] as List).contains(now.weekday) : true),
        AutoCondition.fronting => () {
          final ids = c['ids'] is List ? (c['ids'] as List).cast<String>() : const <String>[];
          return switch (c['mode']) {
            'all' => ids.every(fronters.contains),
            'none' => !ids.any(fronters.contains),
            'cofronting' => fronters.length >= 2,
            _ => ids.isEmpty ? fronters.isNotEmpty : ids.any(fronters.contains),
          };
        }(),
        AutoCondition.mood => _compare((ctx.moodValue ?? _metric('moodToday')).toDouble(), c['op'] as String? ?? '<=', (c['value'] as num?)?.toDouble() ?? 2),
        AutoCondition.location => () {
          final active = ref.read(activeLocationSessionProvider);
          final ids = c['ids'] is List ? (c['ids'] as List).cast<String>() : const <String>[];
          return active != null && (ids.isEmpty || ids.contains(active.locationId));
        }(),
        AutoCondition.metric => _compare(_metric(c['metric'] as String? ?? 'hydrationToday'), c['op'] as String? ?? '<', (c['value'] as num?)?.toDouble() ?? 0),
        _ => true,
      };
      if (!ok) return false;
    }
    return true;
  }

  String _fill(String? text, AutoContext ctx) {
    if (text == null) return '';
    final members = ref.read(allMembersProvider).value ?? const <Member>[];
    final prefer = ref.read(memberNamePreferDisplayProvider);
    final alter = members.where((m) => m.id == ctx.memberId).firstOrNull?.effectiveName(preferDisplayName: prefer) ?? '';
    final t = ctx.at;
    return text
        .replaceAll('{alter}', alter)
        .replaceAll('{time}', '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .replaceAll('{date}', '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}')
        .replaceAll('{mood}', ctx.moodValue?.toString() ?? '')
        .replaceAll('{title}', ctx.title ?? '');
  }

  /// Runs [r] for [ctx] unless rate limits, cooldown or conditions say no.
  /// With [force] (the "Test" button) cooldown and conditions are skipped.
  Future<TrackerRecord?> _run(AutoRule r, AutoContext ctx, {bool force = false}) async {
    if (_running) {
      _queue.add((r.id, ctx, const {}));
      return null;
    }
    final now = DateTime.now();
    _recentRuns.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (!force && _recentRuns.length >= 20) return null; // runaway protection
    if (!force && r.lastRun != null && now.difference(r.lastRun!).inMinutes < r.cooldownMin) return null;
    if (!force && !_conditionsMet(r, ctx)) return null;
    _running = true;
    _recentRuns.add(now);
    final created = <Map<String, Object?>>[];
    final errors = <String>[];
    String? message;
    final t = ref.read(trackerNotifierProvider.notifier);
    try {
      for (final a in r.actions) {
        try {
          switch (a['type']) {
            case AutoAction.notify:
              // Time rules without conditions are delivered by the system schedule.
              if (ctx.trigger == AutoTrigger.time && r.conditions.isEmpty) break;
              if (!kIsWeb) {
                final id = PrismNotify.automationBase + (_uuid.v4().hashCode.abs() % PrismNotify.range);
                await ref.read(localNotificationServiceProvider).showImmediate(
                  id: id,
                  title: _fill(a['title'] as String? ?? r.name, ctx),
                  body: _fill(a['text'] as String?, ctx),
                  details: PrismNotify.details('prism_automations', 'Automations'),
                  payload: 'prism:automation',
                );
              }
            case AutoAction.message:
              message = _fill(a['text'] as String?, ctx);
              final c = appRootNavigatorKey.currentContext;
              if (c != null && c.mounted && message.isNotEmpty) PrismToast.show(c, message: message, icon: PhosphorIcons.lightning());
            case AutoAction.createEntry:
              final kind = a['kind'] as String? ?? TrackerKind.journalEntry;
              final title = _fill(a['title'] as String?, ctx);
              final fields = <String, Object?>{'auto': r.id};
              int? amount;
              if (kind == TrackerKind.nutriDrink) {
                fields['bev'] = a['bev'] ?? 'water';
                fields['ml'] = (a['ml'] as num?)?.toInt() ?? 250;
              }
              final rec = await t.create(
                kind: kind,
                title: title.isEmpty ? r.name : title,
                body: _fill(a['text'] as String?, ctx).isEmpty ? null : _fill(a['text'] as String?, ctx),
                memberId: a['owner'] == 'trigger' ? ctx.memberId : null,
                occurredAt: now,
                amount: amount,
                tags: [if (a['tag'] is String) a['tag'] as String],
                fields: fields,
              );
              created.add({'type': 'rec', 'id': rec.id});
            case AutoAction.setStatus:
              final target = a['target'] == 'trigger' ? ctx.memberId : a['memberId'] as String?;
              if (target == null) break;
              final lang = 'en';
              final current = ref.read(alterStatusesProvider(lang))[target];
              if (a['onlyIfNone'] != false && current != null) break; // never silently overwrite
              final type = ref.read(statusTypesProvider(lang)).where((x) => x.key == a['status']).firstOrNull;
              if (type == null) throw StateError('status type missing');
              final minutes = (a['minutes'] as num?)?.toInt();
              final rec = await ref.read(statusActionsProvider).set(
                memberId: target,
                type: type,
                message: _fill(a['text'] as String?, ctx).isEmpty ? null : _fill(a['text'] as String?, ctx),
                expiresAt: minutes == null ? null : now.add(Duration(minutes: minutes)),
                source: 'auto:${r.id}',
              );
              created.add({
                'type': 'status',
                'id': rec.id,
                'member': target,
                'prev': current?.record == null ? null : {'title': current!.record!.title, 'body': current.record!.body, 'private': current.record!.isPrivate, 'fields': current.record!.fields},
              });
            case AutoAction.addEvent:
              final start = now.add(Duration(minutes: (a['inMinutes'] as num?)?.toInt() ?? 60));
              final ev = CalendarEvent(
                id: _uuid.v4(),
                title: _fill(a['title'] as String? ?? r.name, ctx),
                description: _fill(a['text'] as String?, ctx).isEmpty ? null : _fill(a['text'] as String?, ctx),
                startAt: start,
                endAt: start.add(Duration(minutes: (a['duration'] as num?)?.toInt() ?? 30)),
                memberIds: [?ctx.memberId],
                createdAt: now,
                modifiedAt: now,
              );
              await ref.read(calendarRepositoryProvider).create(ev);
              created.add({'type': 'event', 'id': ev.id});
            case AutoAction.reminder:
              if (!kIsWeb) {
                final id = PrismNotify.automationBase + (_uuid.v4().hashCode.abs() % PrismNotify.range);
                await ref.read(localNotificationServiceProvider).scheduleOneShot(
                  id: id,
                  title: _fill(a['title'] as String? ?? r.name, ctx),
                  body: _fill(a['text'] as String?, ctx),
                  scheduledFor: now.add(Duration(minutes: (a['inMinutes'] as num?)?.toInt() ?? 30)),
                  details: PrismNotify.details('prism_automations', 'Automations'),
                  payload: 'prism:automation',
                );
                created.add({'type': 'notif', 'id': id});
              }
            case AutoAction.counter:
              final name = (a['name'] as String?)?.trim().isNotEmpty == true ? a['name'] as String : r.name;
              final by = (a['by'] as num?)?.toInt() ?? 1;
              final existing = ref.read(automationCountersProvider).where((c) => c.title == name).firstOrNull;
              if (existing == null) {
                final c = await t.create(kind: TrackerKind.autoCounter, title: name, amount: by, fields: {'lastAt': now.toIso8601String()});
                created.add({'type': 'counter', 'id': c.id, 'by': by});
              } else {
                await t.save(existing.copyWith(amount: (existing.amount ?? 0) + by).withFields({'lastAt': now.toIso8601String()}));
                created.add({'type': 'counter', 'id': existing.id, 'by': by});
              }
            case AutoAction.link:
              final self = RecordRef.parse(ctx.record);
              if (self == null) break;
              RecordRef? target;
              switch (a['target']) {
                case 'fronter':
                  final f = ref.read(currentFronterProvider).value;
                  if (f != null) target = RecordRef(RecordRef.member, f.id);
                case 'trigger':
                  if (ctx.memberId != null) target = RecordRef(RecordRef.member, ctx.memberId!);
                case 'location':
                  final l = ref.read(activeLocationSessionProvider);
                  if (l != null) target = RecordRef(RecordRef.location, l.locationId);
                case 'session':
                  final s = (ref.read(activeSessionsProvider).value ?? const <FrontingSession>[]).where((s) => s.sessionType == SessionType.normal).firstOrNull;
                  if (s != null) target = RecordRef(RecordRef.front, s.id);
              }
              if (target == null || target == self) break;
              final ok = await ref.read(linkActionsProvider).link(self, target, category: a['cat'] as String? ?? 'related');
              if (ok) {
                final l = ref.read(recordLinksProvider).where((x) => (x.a == self && x.b == target) || (x.b == self && x.a == target)).lastOrNull;
                if (l != null) created.add({'type': 'rec', 'id': l.id});
              }
          }
        } catch (e) {
          errors.add('${a['type']}: $e');
        }
      }
      final log = await t.create(
        kind: TrackerKind.autoLog,
        title: r.name,
        occurredAt: now,
        body: errors.isEmpty ? null : errors.join('\n'),
        fields: {'rule': r.id, 'trigger': ctx.trigger, 'ok': errors.isEmpty, 'created': created, 'message': message, 'member': ctx.memberId, 'test': force ? true : null},
      );
      final streak = errors.isEmpty ? 0 : r.errorStreak + 1;
      await t.save(r.record.withFields({'lastRun': now.toIso8601String(), 'errors': streak, if (streak >= 5) 'enabled': false, if (streak >= 5) 'disabledReason': 'errors'}));
      _trimLog();
      return log;
    } catch (e, st) {
      debugPrint('[Automations] ${r.name} failed: $e\n$st');
      return null;
    } finally {
      _running = false;
      if (_queue.isNotEmpty) {
        final (id, c, _) = _queue.removeAt(0);
        final rule = ref.read(automationRulesProvider).where((x) => x.id == id).firstOrNull;
        if (rule != null) unawaited(_run(rule, c));
      }
    }
  }

  /// Keeps the history to the newest 300 runs.
  void _trimLog() {
    final logs = ref.read(automationLogProvider);
    if (logs.length <= 300) return;
    final t = ref.read(trackerNotifierProvider.notifier);
    for (final l in logs.skip(300)) {
      unawaited(t.delete(l.id, children: false));
    }
  }

  /// Runs [r] now regardless of trigger, cooldown and conditions.
  Future<TrackerRecord?> test(AutoRule r) {
    final f = ref.read(currentFronterProvider).value;
    return _run(r, AutoContext(trigger: 'test', memberId: f?.id, title: r.name), force: true);
  }

  /// Reverses what a run created, where possible.
  Future<int> undo(TrackerRecord log) async {
    if (log.flag('undone')) return 0;
    final t = ref.read(trackerNotifierProvider.notifier);
    var n = 0;
    final created = log.fields['created'] is List ? (log.fields['created'] as List).whereType<Map>() : const <Map>[];
    for (final c in created) {
      try {
        switch (c['type']) {
          case 'rec':
            await t.delete(c['id'] as String);
          case 'event':
            await ref.read(calendarRepositoryProvider).delete(c['id'] as String);
          case 'notif':
            await ref.read(localNotificationServiceProvider).cancel(c['id'] as int);
          case 'counter':
            final ctr = ref.read(automationCountersProvider).where((x) => x.id == c['id']).firstOrNull;
            if (ctr != null) await t.save(ctr.copyWith(amount: (ctr.amount ?? 0) - ((c['by'] as num?)?.toInt() ?? 1)));
          case 'status':
            final member = c['member'] as String;
            final current = ref.read(alterStatusesProvider('en'))[member];
            // Only undo if the automation's status is still the current one.
            if (current?.record?.id != c['id']) break;
            final prev = c['prev'] is Map ? (c['prev'] as Map) : null;
            await ref.read(statusActionsProvider).restore(
              member,
              prev == null
                  ? null
                  : TrackerRecord(
                      id: 'prev',
                      kind: TrackerKind.statusCurrent,
                      title: prev['title'] as String? ?? '',
                      body: prev['body'] as String?,
                      isPrivate: prev['private'] == true,
                      createdAt: DateTime.now(),
                      modifiedAt: DateTime.now(),
                    ).withFields((prev['fields'] as Map?)?.cast<String, Object?>() ?? const {}),
            );
        }
        n++;
      } catch (_) {}
    }
    await t.save(log.withFields({'undone': true}));
    return n;
  }
}

final automationEngineProvider = Provider<AutomationEngine>((ref) {
  final e = AutomationEngine(ref)..start();
  ref.onDispose(e.dispose);
  return e;
});
