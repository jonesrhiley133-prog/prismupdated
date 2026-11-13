import 'dart:async';

import 'package:prism_plurality/features/alter_status/status_models.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

final statusTypesProvider = Provider.family<List<StatusType>, String>((ref, lang) {
  final custom = ref.watch(trackerKindProvider(TrackerKind.statusCustom)).value ?? const [];
  return [
    for (final b in builtInStatuses)
      StatusType(key: 'builtin:${b.id}', title: lang == 'es' ? b.es : b.en, iconKey: b.icon, color: b.color),
    for (final c in custom.reversed)
      StatusType(
        key: 'custom:${c.id}',
        title: c.title,
        iconKey: c.str('icon') ?? 'star',
        color: c.integer('color') ?? 0xFF8E7CC3,
        description: c.body,
        record: c,
      ),
  ];
});

/// Type keys hidden from shared surfaces (Home, Headmates list).
final hiddenStatusTypesProvider = Provider<Set<String>>((ref) {
  final s = ref.watch(trackerKindProvider(TrackerKind.statusSettings)).value ?? const [];
  return s.isEmpty ? const {} : s.first.strings('hidden').toSet();
});

/// Current, unexpired statuses by member id.
final alterStatusesProvider = Provider.family<Map<String, AlterStatus>, String>((ref, lang) {
  final now = DateTime.now();
  final types = {for (final t in ref.watch(statusTypesProvider(lang))) t.key: t};
  final out = <String, AlterStatus>{};
  for (final r in ref.watch(trackerKindProvider(TrackerKind.statusCurrent)).value ?? const <TrackerRecord>[]) {
    final mid = r.memberId;
    if (mid == null || out.containsKey(mid)) continue;
    final s = statusFromRecord(r, types);
    if (s == null || s.isExpired(now)) continue;
    out[mid] = s;
  }
  // Rebuild when the next status expires (no timer when nothing expires).
  final next = [for (final s in out.values) ?s.expiresAt]..sort();
  if (next.isNotEmpty) {
    final t = Timer(next.first.difference(now) + const Duration(seconds: 1), ref.invalidateSelf);
    ref.onDispose(t.cancel);
  }
  return out;
});

AlterStatus? statusFromRecord(TrackerRecord r, Map<String, StatusType> types) {
  final key = r.str('type');
  if (key == null || r.memberId == null) return null;
  final t = types[key];
  final exp = r.str('expiresAt');
  return AlterStatus(
    memberId: r.memberId!,
    typeKey: key,
    title: r.title.isNotEmpty ? r.title : (t?.title ?? '?'),
    iconKey: r.str('icon') ?? t?.iconKey ?? 'circle',
    color: r.integer('color') ?? t?.color ?? 0xFF747F8D,
    message: r.body,
    activity: r.str('activity'),
    expiresAt: exp == null ? null : DateTime.tryParse(exp),
    setAt: r.occurredAt,
    isPrivate: r.isPrivate,
    record: r,
  );
}

/// Statuses that may be shown on shared surfaces.
final publicStatusesProvider = Provider.family<Map<String, AlterStatus>, String>((ref, lang) {
  final hidden = ref.watch(hiddenStatusTypesProvider);
  final all = ref.watch(alterStatusesProvider(lang));
  return {
    for (final e in all.entries)
      if (!e.value.isPrivate && !hidden.contains(e.value.typeKey)) e.key: e.value,
  };
});

class StatusActions {
  StatusActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  List<TrackerRecord> get _current => ref.read(trackerKindProvider(TrackerKind.statusCurrent)).value ?? const [];

  /// Sets [memberId]'s status; the previous one moves to history.
  Future<TrackerRecord> set({
    required String memberId,
    required StatusType type,
    String? title,
    String? message,
    String? activity,
    int? color,
    String? iconKey,
    DateTime? expiresAt,
    bool isPrivate = false,
    String? source,
  }) async {
    await _archive(memberId);
    return _t.create(
      kind: TrackerKind.statusCurrent,
      memberId: memberId,
      title: title == null || title.trim() == type.title ? '' : title.trim(),
      body: message,
      occurredAt: DateTime.now(),
      isPrivate: isPrivate,
      fields: {
        'type': type.key,
        'activity': ?(activity == null || activity.trim().isEmpty ? null : activity.trim()),
        'color': ?(color == type.color ? null : color),
        'icon': ?(iconKey == type.iconKey ? null : iconKey),
        'expiresAt': ?expiresAt?.toIso8601String(),
        'source': ?source,
      },
    );
  }

  Future<void> clear(String memberId) => _archive(memberId);

  Future<void> _archive(String memberId) async {
    for (final r in _current.where((r) => r.memberId == memberId).toList()) {
      final exp = DateTime.tryParse(r.str('expiresAt') ?? '');
      final now = DateTime.now();
      final ended = exp != null && exp.isBefore(now) ? exp : now;
      await _t.create(
        kind: TrackerKind.statusLog,
        memberId: memberId,
        title: r.title,
        body: r.body,
        occurredAt: r.occurredAt ?? r.createdAt,
        endedAt: ended,
        isPrivate: r.isPrivate,
        fields: r.fields,
      );
      await _t.delete(r.id, children: false);
    }
  }

  /// Puts back an earlier status (undo for automations).
  Future<void> restore(String memberId, TrackerRecord? previous) async {
    await _archive(memberId);
    if (previous == null) return;
    await _t.create(
      kind: TrackerKind.statusCurrent,
      memberId: memberId,
      title: previous.title,
      body: previous.body,
      occurredAt: DateTime.now(),
      isPrivate: previous.isPrivate,
      fields: previous.fields,
    );
  }

  Future<void> saveCustom({TrackerRecord? editing, required String name, required String icon, required int color, String? description}) async {
    if (editing != null) {
      await _t.save(editing.copyWith(title: name, body: description).withFields({'icon': icon, 'color': color}));
    } else {
      await _t.create(kind: TrackerKind.statusCustom, title: name, body: description, fields: {'icon': icon, 'color': color});
    }
  }

  Future<void> setHidden(Set<String> hidden) async {
    final s = ref.read(trackerKindProvider(TrackerKind.statusSettings)).value ?? const [];
    if (s.isEmpty) {
      await _t.create(kind: TrackerKind.statusSettings, fields: {'hidden': hidden.toList()});
    } else {
      await _t.save(s.first.withFields({'hidden': hidden.toList()}));
    }
  }
}

final statusActionsProvider = Provider<StatusActions>(StatusActions.new);
