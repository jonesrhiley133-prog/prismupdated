import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/features/availability/availability_models.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/notify.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

final availCategoriesProvider = Provider.family<List<AvailCategory>, String>((ref, lang) {
  final custom = ref.watch(trackerKindProvider(TrackerKind.availCategory)).value ?? const [];
  final overrides = {for (final c in custom) if (c.str('builtin') != null) c.str('builtin')!: c};
  return [
    for (final (id, en, es, color, icon) in builtInAvailability)
      AvailCategory(
        id: id,
        title: lang == 'es' ? es : en,
        color: overrides[id]?.integer('color') ?? color,
        icon: overrides[id]?.str('icon') ?? icon,
        record: overrides[id],
      ),
    for (final c in custom.reversed)
      if (c.str('builtin') == null)
        AvailCategory(id: c.id, title: c.title, color: c.integer('color') ?? 0xFF8C8C8C, icon: c.str('icon') ?? 'circle', record: c),
  ];
});

final availRulesProvider = Provider<List<AvailRule>>((ref) => [
  for (final r in ref.watch(trackerKindProvider(TrackerKind.availRule)).value ?? const <TrackerRecord>[]) AvailRule(r),
]);

final availOverridesProvider = Provider<List<AvailOverride>>((ref) => [
  for (final r in ref.watch(trackerKindProvider(TrackerKind.availOverride)).value ?? const <TrackerRecord>[]) AvailOverride(r),
]);

/// Blocks for [memberId] between [from] and [to], overrides cutting into
/// the weekly schedule.
List<AvailBlock> availabilityBlocks({
  required String memberId,
  required DateTime from,
  required DateTime to,
  required List<AvailRule> rules,
  required List<AvailOverride> overrides,
}) {
  final out = <AvailBlock>[];
  final mine = [for (final r in rules) if (r.memberId == memberId) r];
  final ovs = [for (final o in overrides) if (o.memberId == memberId && o.end.isAfter(from) && o.start.isBefore(to)) o];
  for (var d = DateTime(from.year, from.month, from.day - 1); d.isBefore(to); d = DateTime(d.year, d.month, d.day + 1)) {
    for (final r in mine) {
      if (!r.weekdays.contains(d.weekday)) continue;
      final s = d.add(Duration(minutes: r.startMin));
      var e = d.add(Duration(minutes: r.endMin));
      if (r.endMin <= r.startMin) e = e.add(const Duration(days: 1));
      if (!e.isAfter(from) || !s.isBefore(to)) continue;
      if (r.validFrom != null && e.isBefore(r.validFrom!)) continue;
      if (r.validUntil != null && s.isAfter(DateTime(r.validUntil!.year, r.validUntil!.month, r.validUntil!.day + 1))) continue;
      // Cut out override windows.
      var pieces = [(s, e)];
      for (final o in ovs) {
        pieces = [
          for (final (ps, pe) in pieces)
            ...[
              if (o.start.isAfter(ps)) (ps, o.start.isBefore(pe) ? o.start : pe),
              if (o.end.isBefore(pe)) (o.end.isAfter(ps) ? o.end : ps, pe),
            ].where((p) => p.$2.isAfter(p.$1)),
        ];
      }
      for (final (ps, pe) in pieces) {
        out.add(AvailBlock(memberId, ps, pe, r.category, note: r.note, record: r.record));
      }
    }
  }
  for (final o in ovs) {
    out.add(AvailBlock(memberId, o.start, o.end, o.category, note: o.note, isOverride: true, record: o.record));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return [for (final b in out) if (b.end.isAfter(from) && b.start.isBefore(to)) b];
}

/// Category for [memberId] at [t], or null when nothing is planned.
String? availabilityAt(String memberId, DateTime t, List<AvailRule> rules, List<AvailOverride> overrides) {
  AvailOverride? best;
  for (final o in overrides) {
    if (o.memberId == memberId && o.covers(t) && (best == null || o.record.createdAt.isAfter(best.record.createdAt))) best = o;
  }
  if (best != null) return best.category;
  for (final r in rules) {
    if (r.memberId == memberId && r.covers(t)) return r.category;
  }
  return null;
}

class AvailabilityActions {
  AvailabilityActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<void> saveRule({
    TrackerRecord? editing,
    required String memberId,
    required List<int> days,
    required int start,
    required int end,
    required String category,
    String? note,
    bool notify = false,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    final fields = {'days': [for (final d in days) '$d'], 'start': start, 'end': end, 'cat': category, 'notify': notify};
    if (editing != null) {
      await _t.save(editing.copyWith(memberId: memberId, body: note, occurredAt: validFrom, endedAt: validUntil).withFields(fields));
    } else {
      await _t.create(kind: TrackerKind.availRule, memberId: memberId, body: note, occurredAt: validFrom, endedAt: validUntil, fields: fields);
    }
    await rescheduleNotifications();
  }

  Future<void> saveOverride({
    TrackerRecord? editing,
    required String memberId,
    required DateTime start,
    required DateTime end,
    required String category,
    String? note,
    bool notify = false,
  }) async {
    final fields = {'cat': category, 'notify': notify};
    if (editing != null) {
      await _t.save(editing.copyWith(memberId: memberId, body: note, occurredAt: start, endedAt: end).withFields(fields));
    } else {
      await _t.create(kind: TrackerKind.availOverride, memberId: memberId, body: note, occurredAt: start, endedAt: end, fields: fields);
    }
    await rescheduleNotifications();
  }

  Future<void> delete(String id) async {
    await _t.delete(id, children: false);
    await rescheduleNotifications();
  }

  Future<void> saveCategory({TrackerRecord? editing, String? builtin, required String title, required int color, required String icon}) async {
    final fields = {'color': color, 'icon': icon, 'builtin': builtin};
    if (editing != null) {
      await _t.save(editing.copyWith(title: title).withFields(fields));
    } else {
      await _t.create(kind: TrackerKind.availCategory, title: title, fields: fields);
    }
  }

  /// Schedules one notification per upcoming change (next 7 days) for rules
  /// and overrides with notifications on, 10 minutes before.
  Future<void> rescheduleNotifications({String Function(String memberId)? nameOf, Map<String, String>? catNames}) async {
    if (kIsWeb) return;
    final svc = ref.read(localNotificationServiceProvider);
    try {
      await svc.cancelRange(PrismNotify.availabilityBase, PrismNotify.range);
    } catch (_) {
      return;
    }
    final rules = ref.read(availRulesProvider);
    final ovs = ref.read(availOverridesProvider);
    final now = DateTime.now();
    final until = now.add(const Duration(days: 7));
    final members = {for (final r in rules) if (r.notify) r.memberId, for (final o in ovs) if (o.record.flag('notify')) o.memberId};
    final names = {for (final m in ref.read(allMembersProvider).value ?? const []) m.id: m.name};
    final cats = {for (final c in ref.read(availCategoriesProvider('en'))) c.id: c.title};
    nameOf ??= (id) => names[id] ?? '';
    catNames ??= cats;
    var i = 0;
    for (final m in members) {
      for (final b in availabilityBlocks(memberId: m, from: now, to: until, rules: rules, overrides: ovs)) {
        final notify = b.record?.flag('notify') ?? false;
        if (!notify || i >= 200) continue;
        final at = b.start.subtract(const Duration(minutes: 10));
        if (!at.isAfter(now)) continue;
        await svc.scheduleOneShot(
          id: PrismNotify.availabilityBase + i++,
          title: 'Availability',
          body: '${nameOf(m)} ${catNames[b.category] ?? b.category} · ${fmtMinutes(b.start.hour * 60 + b.start.minute)}'.trim(),
          scheduledFor: at,
          details: PrismNotify.details('prism_availability', 'Availability'),
          payload: 'prism:availability',
        );
      }
    }
  }
}

final availabilityActionsProvider = Provider<AvailabilityActions>(AvailabilityActions.new);
