import 'package:flutter/foundation.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';

abstract final class SubField {
  static const emoji = 'emoji';
  static const color = 'color';
  static const members = 'members';
  static const linkedGroupId = 'linkedGroupId';
  static const purpose = 'purpose';
  static const origin = 'origin';
  static const rules = 'rules';
  static const connections = 'connections';
}

@immutable
class SubsystemMember {
  const SubsystemMember({required this.memberId, this.role});

  final String memberId;
  final String? role;

  Map<String, Object?> toJson() => {
    'id': memberId,
    if (role != null && role!.isNotEmpty) 'role': role,
  };

  static SubsystemMember? fromJson(Object? v) {
    if (v is! Map || v['id'] is! String) return null;
    return SubsystemMember(
      memberId: v['id'] as String,
      role: v['role'] is String ? v['role'] as String : null,
    );
  }
}

List<SubsystemMember> subsystemMembers(TrackerRecord s) {
  final raw = s.fields[SubField.members];
  if (raw is! List) return const [];
  return [for (final v in raw) ?SubsystemMember.fromJson(v)];
}

/// Ids of [s] and every subsystem nested under it.
Set<String> descendantsOf(String id, List<TrackerRecord> all) {
  final out = <String>{id};
  var grew = true;
  while (grew) {
    grew = false;
    for (final s in all) {
      if (s.parentId != null && out.contains(s.parentId) && out.add(s.id))
        grew = true;
    }
  }
  return out;
}

/// Members of [s] including nested subsystems.
Set<String> allMemberIds(TrackerRecord s, List<TrackerRecord> all) {
  final ids = descendantsOf(s.id, all);
  return {
    for (final x in all)
      if (ids.contains(x.id))
        for (final m in subsystemMembers(x)) m.memberId,
  };
}

/// Subsystems in display order with their depth (parents before children).
List<(TrackerRecord, int)> subsystemTree(List<TrackerRecord> all) {
  final ids = {for (final s in all) s.id};
  final children = <String?, List<TrackerRecord>>{};
  for (final s in all) {
    final p = s.parentId != null && ids.contains(s.parentId)
        ? s.parentId
        : null;
    (children[p] ??= []).add(s);
  }
  for (final l in children.values) {
    l.sort(
      (a, b) => a.sortOrder != b.sortOrder
          ? a.sortOrder.compareTo(b.sortOrder)
          : a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
  }
  final out = <(TrackerRecord, int)>[];
  final seen = <String>{};
  void walk(String? parent, int depth) {
    for (final s in children[parent] ?? const <TrackerRecord>[]) {
      if (!seen.add(s.id)) continue;
      out.add((s, depth));
      walk(s.id, depth + 1);
    }
  }

  walk(null, 0);
  return out;
}

/// Whether making [parentId] the parent of [id] would create a loop.
bool wouldCycle(String id, String? parentId, List<TrackerRecord> all) =>
    parentId != null && descendantsOf(id, all).contains(parentId);

/// Share of tracked fronting time (0–1) spent by [memberIds] in [sessions]
/// between [from] and [to]. Co-fronting counts for each fronter.
double frontingShare(
  Set<String> memberIds,
  List<FrontingSession> sessions,
  DateTime from,
  DateTime to,
) {
  var total = 0, mine = 0;
  for (final s in sessions) {
    if (s.sessionType == SessionType.sleep || s.memberId == null) continue;
    final start = s.startTime.isBefore(from) ? from : s.startTime;
    final end = (s.endTime ?? to).isAfter(to) ? to : (s.endTime ?? to);
    final secs = end.difference(start).inSeconds;
    if (secs <= 0) continue;
    total += secs;
    if (memberIds.contains(s.memberId)) mine += secs;
  }
  return total == 0 ? 0 : mine / total;
}
