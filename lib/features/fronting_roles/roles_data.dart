import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

/// A fronting status. Primary, Co-front and Co-conscious are built in;
/// systems can add their own (Nearby, Observing, Blended…).
@immutable
class FrontStatusType {
  const FrontStatusType({
    required this.id,
    required this.name,
    this.description = '',
    this.emoji = '',
    this.color,
    this.order = 0,
    this.visible = true,
    this.maxAlters,
    this.activeFronting = true,
    this.inAnalytics = true,
    this.onDashboard = true,
    this.inNotification = true,
    this.builtIn = false,
    this.record,
  });

  final String id;
  final String name;
  final String description;
  final String emoji;
  final int? color;
  final int order;
  final bool visible;

  /// At most this many alters can hold the status at once (null: no limit).
  final int? maxAlters;

  /// Counts as fronting (needs an active fronting session). Off for
  /// statuses like Co-conscious or Nearby, which describe awareness.
  final bool activeFronting;
  final bool inAnalytics;
  final bool onDashboard;
  final bool inNotification;
  final bool builtIn;
  final TrackerRecord? record;

  Color? get colorValue => color == null ? null : Color(color!);

  Map<String, Object?> toFields() => {
    'description': description,
    'emoji': emoji,
    'color': color,
    'order': order,
    'visible': visible,
    'maxAlters': maxAlters,
    'activeFronting': activeFronting,
    'inAnalytics': inAnalytics,
    'onDashboard': onDashboard,
    'inNotification': inNotification,
  };

  static FrontStatusType fromRecord(TrackerRecord r) {
    final f = r.fields;
    return FrontStatusType(
      id: r.id,
      name: r.title,
      description: '${f['description'] ?? ''}',
      emoji: '${f['emoji'] ?? ''}',
      color: (f['color'] as num?)?.toInt(),
      order: (f['order'] as num?)?.toInt() ?? 100,
      visible: f['visible'] != false,
      maxAlters: (f['maxAlters'] as num?)?.toInt(),
      activeFronting: f['activeFronting'] == true,
      inAnalytics: f['inAnalytics'] != false,
      onDashboard: f['onDashboard'] != false,
      inNotification: f['inNotification'] != false,
      record: r,
    );
  }
}

const kPrimary = 'primary';
const kCoFront = 'cofront';
const kCoConscious = 'coconscious';
const kNoStatus = 'none';

const builtInStatuses = [
  FrontStatusType(
    id: kPrimary,
    name: 'Primary',
    emoji: '⭐',
    order: 0,
    maxAlters: 1,
    builtIn: true,
    description: 'The main fronter right now.',
  ),
  FrontStatusType(
    id: kCoFront,
    name: 'Co-front',
    emoji: '👥',
    order: 1,
    builtIn: true,
    description: 'Also fronting, sharing control.',
  ),
  FrontStatusType(
    id: kCoConscious,
    name: 'Co-Conscious',
    emoji: '👁️',
    order: 2,
    activeFronting: false,
    builtIn: true,
    description: 'Aware and present, but not fronting.',
  ),
];

/// Suggestions offered when adding a custom status (optional, never forced).
const statusSuggestions = <(String, String, bool)>[
  ('Background', '🌫️', false),
  ('Nearby', '📍', false),
  ('Observing', '🔭', false),
  ('Passive', '🍃', true),
  ('Blended', '🌀', true),
  ('Uncertain', '❔', true),
  ('Resting', '😴', false),
  ('Available', '✋', false),
  ('Internal activity', '🏠', false),
];

/// Every status, ordered.
final frontStatusTypesProvider = Provider<List<FrontStatusType>>((ref) {
  final custom = [
    for (final r
        in ref.watch(trackerKindProvider(TrackerKind.frontStatusType)).value ??
            const <TrackerRecord>[])
      FrontStatusType.fromRecord(r),
  ];
  return [...builtInStatuses, ...custom]
    ..sort((a, b) => a.order.compareTo(b.order));
});

FrontStatusType? statusById(List<FrontStatusType> all, String? id) =>
    all.where((s) => s.id == id).firstOrNull;

/// Who's There and role preferences (synced, so devices agree).
@immutable
class RoleSettings {
  const RoleSettings({
    this.record,
    this.whosThereEnabled = true,
    this.intervalMinutes = 300,
    this.lastConfirmed,
    this.snoozedUntil,
    this.allowMultipleStatuses = false,
  });
  final TrackerRecord? record;
  final bool whosThereEnabled;

  /// Minutes since the last confirmed fronting change before asking.
  final int intervalMinutes;
  final DateTime? lastConfirmed;
  final DateTime? snoozedUntil;

  /// Whether an alter can hold more than one status at once.
  final bool allowMultipleStatuses;

  Map<String, Object?> toFields() => {
    'whosThere': whosThereEnabled,
    'interval': intervalMinutes,
    'lastConfirmed': lastConfirmed?.toIso8601String(),
    'snoozedUntil': snoozedUntil?.toIso8601String(),
    'multiple': allowMultipleStatuses,
  };

  RoleSettings copyWith({
    bool? whosThereEnabled,
    int? intervalMinutes,
    DateTime? lastConfirmed,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
    bool? allowMultipleStatuses,
  }) => RoleSettings(
    record: record,
    whosThereEnabled: whosThereEnabled ?? this.whosThereEnabled,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    lastConfirmed: lastConfirmed ?? this.lastConfirmed,
    snoozedUntil: clearSnooze ? null : (snoozedUntil ?? this.snoozedUntil),
    allowMultipleStatuses: allowMultipleStatuses ?? this.allowMultipleStatuses,
  );

  static RoleSettings of(TrackerRecord? r) => RoleSettings(
    record: r,
    whosThereEnabled: r?.fields['whosThere'] != false,
    intervalMinutes: (r?.fields['interval'] as num?)?.toInt() ?? 300,
    lastConfirmed: DateTime.tryParse('${r?.fields['lastConfirmed'] ?? ''}'),
    snoozedUntil: DateTime.tryParse('${r?.fields['snoozedUntil'] ?? ''}'),
    allowMultipleStatuses: r?.fields['multiple'] == true,
  );
}

final roleSettingsProvider = Provider<RoleSettings>((ref) {
  final list =
      ref.watch(trackerKindProvider(TrackerKind.frontRoleSettings)).value ??
      const <TrackerRecord>[];
  return RoleSettings.of(
    list.isEmpty
        ? null
        : (list.toList()..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt)))
              .first,
  );
});

/// One alter's role right now.
@immutable
class MemberRole {
  const MemberRole(this.memberId, this.statusId, {this.session, this.since});
  final String memberId;
  final String statusId;
  final FrontingSession? session;
  final DateTime? since;
}

/// Works out every alter's current role(s).
///
/// - Alters with an open fronting session: an explicit role recorded during
///   that session wins; otherwise the earliest session is Primary and the
///   rest are Co-front (matching how Prism showed fronting before roles).
/// - Statuses that aren't active fronting (Co-conscious, Nearby…) last until
///   changed or cleared, and don't need a session.
@visibleForTesting
List<MemberRole> computeRoles({
  required List<FrontingSession> active,
  required List<TrackerRecord> roleRecords,
  required List<FrontStatusType> types,
  bool allowMultiple = false,
}) {
  final byMember = <String, List<TrackerRecord>>{};
  for (final r in roleRecords) {
    if (r.memberId == null) continue;
    byMember.putIfAbsent(r.memberId!, () => []).add(r);
  }
  for (final l in byMember.values) {
    l.sort(
      (a, b) =>
          (b.occurredAt ?? b.createdAt).compareTo(a.occurredAt ?? a.createdAt),
    );
  }
  final sessions =
      active
          .where(
            (s) => s.memberId != null && s.sessionType == SessionType.normal,
          )
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
  final out = <MemberRole>[];
  var primaryTaken = false;

  // Explicit roles first, so an explicit Primary beats the default.
  final explicitActive = <String, String>{};
  for (final s in sessions) {
    final recs = byMember[s.memberId!] ?? const [];
    final during = recs
        .where(
          (r) => !(r.occurredAt ?? r.createdAt).isBefore(
            s.startTime.subtract(const Duration(seconds: 5)),
          ),
        )
        .toList();
    final latest = during.isEmpty ? null : during.first;
    final id = latest?.fields['status'] as String?;
    final type = statusById(types, id);
    if (type != null && type.activeFronting)
      explicitActive[s.memberId!] = type.id;
  }
  if (explicitActive.values.contains(kPrimary)) primaryTaken = true;
  final explicitlyNoPrimary = roleRecords.any(
    (r) =>
        r.fields['noPrimary'] == true &&
        sessions.any(
          (s) => !(r.occurredAt ?? r.createdAt).isBefore(
            s.startTime.subtract(const Duration(seconds: 5)),
          ),
        ),
  );

  for (final s in sessions) {
    final m = s.memberId!;
    if (out.any(
      (r) =>
          r.memberId == m &&
          statusById(types, r.statusId)?.activeFronting == true,
    ))
      continue;
    var id = explicitActive[m];
    if (id == null) {
      if (!primaryTaken && !explicitlyNoPrimary) {
        id = kPrimary;
        primaryTaken = true;
      } else {
        id = kCoFront;
      }
    } else if (id == kPrimary && out.any((r) => r.statusId == kPrimary)) {
      id = kCoFront; // only one Primary
    }
    out.add(MemberRole(m, id, session: s, since: s.startTime));
  }

  // Awareness statuses (not tied to a session).
  for (final e in byMember.entries) {
    final latest = e.value.first;
    final type = statusById(types, latest.fields['status'] as String?);
    if (type == null || type.activeFronting) continue;
    if (!allowMultiple && out.any((r) => r.memberId == e.key)) continue;
    out.add(
      MemberRole(e.key, type.id, since: latest.occurredAt ?? latest.createdAt),
    );
  }
  return out;
}

final currentRolesProvider = Provider<List<MemberRole>>((ref) {
  final active =
      ref.watch(activeSessionsProvider).value ?? const <FrontingSession>[];
  final recs =
      ref.watch(trackerKindProvider(TrackerKind.frontRole)).value ??
      const <TrackerRecord>[];
  final types = ref.watch(frontStatusTypesProvider);
  return computeRoles(
    active: active,
    roleRecords: recs,
    types: types,
    allowMultiple: ref.watch(roleSettingsProvider).allowMultipleStatuses,
  );
});

/// The Primary fronter's id, if there is one.
final primaryFronterIdProvider = Provider<String?>(
  (ref) => ref
      .watch(currentRolesProvider)
      .where((r) => r.statusId == kPrimary)
      .firstOrNull
      ?.memberId,
);

/// When fronting last changed (newest open session start), or null.
final lastFrontingChangeProvider = Provider<DateTime?>((ref) {
  final active =
      ref.watch(activeSessionsProvider).value ?? const <FrontingSession>[];
  final starts = [
    for (final s in active)
      if (s.sessionType == SessionType.normal) s.startTime,
  ];
  if (starts.isEmpty) return null;
  return starts.reduce((a, b) => a.isAfter(b) ? a : b);
});

/// Whether Who's There is due now.
bool whosThereDue({
  required RoleSettings settings,
  required DateTime? lastChange,
  required DateTime now,
}) {
  if (!settings.whosThereEnabled || settings.intervalMinutes <= 0) return false;
  if (settings.snoozedUntil != null && now.isBefore(settings.snoozedUntil!))
    return false;
  final anchors = [?lastChange, ?settings.lastConfirmed];
  if (anchors.isEmpty) return true;
  final latest = anchors.reduce((a, b) => a.isAfter(b) ? a : b);
  return now.difference(latest) >= Duration(minutes: settings.intervalMinutes);
}

class RolesActions {
  RolesActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<void> setStatus(String memberId, String statusId) => _t.create(
    kind: TrackerKind.frontRole,
    memberId: memberId,
    occurredAt: DateTime.now(),
    fields: {'status': statusId},
  );

  Future<void> clearStatus(String memberId) => setStatus(memberId, kNoStatus);

  Future<void> markNoPrimary() async {
    final roles = ref.read(currentRolesProvider);
    for (final r in roles.where((r) => r.statusId == kPrimary)) {
      await _t.create(
        kind: TrackerKind.frontRole,
        memberId: r.memberId,
        occurredAt: DateTime.now(),
        fields: {'status': kCoFront, 'noPrimary': true},
      );
    }
  }

  Future<void> saveSettings(RoleSettings s) async {
    if (s.record == null) {
      await _t.create(
        kind: TrackerKind.frontRoleSettings,
        fields: s.toFields(),
      );
    } else {
      await _t.save(s.record!.withFields(s.toFields()));
    }
  }

  /// "Still the same": resets the timer without touching fronting history.
  Future<void> confirmSame() => saveSettings(
    ref
        .read(roleSettingsProvider)
        .copyWith(lastConfirmed: DateTime.now(), clearSnooze: true),
  );

  /// "Skip for now": quiet until half the interval has passed (at least
  /// 30 minutes), so it doesn't reappear on every screen.
  Future<void> snooze() {
    final s = ref.read(roleSettingsProvider);
    final mins = (s.intervalMinutes / 2).clamp(30, 240).round();
    return saveSettings(
      s.copyWith(snoozedUntil: DateTime.now().add(Duration(minutes: mins))),
    );
  }

  /// Sets who's fronting from a Who's There choice. [primary] first, then
  /// co-fronters. Alters already fronting keep their sessions (no false
  /// switch); others start; those not chosen stop.
  Future<void> applyFronting({
    required String? primary,
    List<String> others = const [],
  }) async {
    final chosen = [?primary, ...others.where((o) => o != primary)];
    final active =
        ref.read(activeSessionsProvider).value ?? const <FrontingSession>[];
    final activeIds = {
      for (final s in active)
        if (s.sessionType == SessionType.normal && s.memberId != null)
          s.memberId!,
    };
    final notifier = ref.read(frontingNotifierProvider.notifier);
    final sameSet =
        activeIds.length == chosen.length && activeIds.containsAll(chosen);
    if (!sameSet) {
      final toStart = chosen.where((c) => !activeIds.contains(c)).toList();
      final toEnd = activeIds.where((a) => !chosen.contains(a)).toList();
      if (toEnd.isNotEmpty &&
          toEnd.length == activeIds.length &&
          toStart.isNotEmpty) {
        await notifier.replaceFronting(toStart);
      } else {
        if (toEnd.isNotEmpty) await notifier.endFronting(toEnd);
        for (final m in toStart) {
          await notifier.addCoFronter(m);
        }
      }
    }
    if (primary != null) await setStatus(primary, kPrimary);
    for (final o in others.where((o) => o != primary)) {
      await setStatus(o, kCoFront);
    }
    await confirmSame();
  }

  Future<void> saveStatusType(FrontStatusType t) async {
    if (t.record == null) {
      await _t.create(
        kind: TrackerKind.frontStatusType,
        title: t.name,
        fields: t.toFields(),
      );
    } else {
      await _t.save(t.record!.copyWith(title: t.name).withFields(t.toFields()));
    }
  }

  Future<void> deleteStatusType(FrontStatusType t) async {
    if (t.record != null) await _t.delete(t.record!.id);
  }
}

final rolesActionsProvider = Provider<RolesActions>(RolesActions.new);
