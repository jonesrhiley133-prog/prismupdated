import 'package:flutter/foundation.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';

/// Field keys inside relationship records. A relationship links a system
/// member ([TrackerRecord.memberId]) to another member, a contact or a
/// named person.
abstract final class RelField {
  static const otherType = 'otherType';
  static const otherId = 'otherId';
  static const otherName = 'otherName';
  static const type = 'type';
  static const status = 'status';
  static const closeness = 'closeness';
  static const trust = 'trust';
  static const boundaries = 'boundaries';
  static const dynamics = 'dynamics';
  static const sentiment = 'sentiment';
  static const mutual = 'mutual';
}

abstract final class RelOther {
  static const member = 'member';
  static const contact = 'contact';
  static const person = 'person';
}

const relationshipTypes = [
  'friend',
  'best_friend',
  'partner',
  'crush',
  'family',
  'sibling',
  'parent_figure',
  'child_figure',
  'caretaker',
  'protector',
  'mentor',
  'classmate',
  'coworker',
  'rival',
  'acquaintance',
  'other',
];

const relationshipStatuses = [
  'active',
  'close',
  'distant',
  'complicated',
  'ended',
];

/// Whether this relationship is between two system members.
bool isInternal(TrackerRecord r) =>
    r.str(RelField.otherType) == RelOther.member;

/// Both member ends of an internal relationship.
Set<String> memberEnds(TrackerRecord r) => {
  ?r.memberId,
  if (isInternal(r)) ?r.str(RelField.otherId),
};

@immutable
class RelationshipStats {
  const RelationshipStats({
    required this.total,
    required this.internal,
    required this.external,
    required this.byType,
    required this.byStatus,
    required this.averageCloseness,
    required this.averageTrust,
    required this.connectionsByMember,
    required this.eventsLast30,
    required this.positiveShare,
  });

  final int total;
  final int internal;
  final int external;
  final Map<String, int> byType;
  final Map<String, int> byStatus;
  final double? averageCloseness;
  final double? averageTrust;

  /// Member id → number of relationships they are part of.
  final Map<String, int> connectionsByMember;
  final int eventsLast30;

  /// Share of events marked positive, 0–1, or null without rated events.
  final double? positiveShare;

  static RelationshipStats of(
    List<TrackerRecord> rels,
    List<TrackerRecord> events,
    DateTime now,
  ) {
    final byType = <String, int>{}, byStatus = <String, int>{};
    final conn = <String, int>{};
    final close = <int>[], trust = <int>[];
    var internal = 0;
    for (final r in rels) {
      final t = r.str(RelField.type) ?? 'other';
      byType[t] = (byType[t] ?? 0) + 1;
      final s = r.str(RelField.status) ?? 'active';
      byStatus[s] = (byStatus[s] ?? 0) + 1;
      if (isInternal(r)) internal++;
      for (final m in memberEnds(r)) {
        conn[m] = (conn[m] ?? 0) + 1;
      }
      final c = r.integer(RelField.closeness);
      if (c != null) close.add(c);
      final tr = r.integer(RelField.trust);
      if (tr != null) trust.add(tr);
    }
    final since = now.subtract(const Duration(days: 30));
    final rated = [for (final e in events) ?e.integer(RelField.sentiment)];
    double? avg(List<int> l) =>
        l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;
    return RelationshipStats(
      total: rels.length,
      internal: internal,
      external: rels.length - internal,
      byType: byType,
      byStatus: byStatus,
      averageCloseness: avg(close),
      averageTrust: avg(trust),
      connectionsByMember: conn,
      eventsLast30: events
          .where((e) => (e.occurredAt ?? e.createdAt).isAfter(since))
          .length,
      positiveShare: rated.isEmpty
          ? null
          : rated.where((s) => s > 0).length / rated.length,
    );
  }
}
