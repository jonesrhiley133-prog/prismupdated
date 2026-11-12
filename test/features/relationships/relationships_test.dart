import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/relationships/utils/relationships.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

final _t = DateTime(2026, 3, 1);
TrackerRecord _r(
  String id,
  String member,
  String otherType, {
  String? other,
  String type = 'friend',
  String status = 'active',
  int? close,
  int? trust,
}) =>
    TrackerRecord(
      id: id,
      kind: TrackerKind.relationship,
      memberId: member,
      createdAt: _t,
      modifiedAt: _t,
    ).withFields({
      RelField.otherType: otherType,
      RelField.otherId: other,
      RelField.type: type,
      RelField.status: status,
      RelField.closeness: close,
      RelField.trust: trust,
    });
TrackerRecord _ev(String parent, int sentiment, DateTime at) => TrackerRecord(
  id: '$parent$at',
  kind: TrackerKind.relationshipEvent,
  parentId: parent,
  occurredAt: at,
  createdAt: at,
  modifiedAt: at,
).withFields({RelField.sentiment: sentiment});

void main() {
  test('stats split internal/external and count connections per member', () {
    final rels = [
      _r(
        '1',
        'a',
        RelOther.member,
        other: 'b',
        type: 'sibling',
        close: 5,
        trust: 4,
      ),
      _r('2', 'a', RelOther.contact, other: 'c1', close: 3),
      _r(
        '3',
        'b',
        RelOther.member,
        other: 'c',
        type: 'protector',
        status: 'ended',
        trust: 2,
      ),
      _r('4', 'c', RelOther.person),
    ];
    final s = RelationshipStats.of(rels, [
      _ev('1', 1, DateTime(2026, 2, 20)),
      _ev('1', -1, DateTime(2026, 1, 1)),
      _ev('2', 0, DateTime(2026, 2, 25)),
    ], _t);
    expect((s.total, s.internal, s.external), (4, 2, 2));
    expect(s.connectionsByMember, {'a': 2, 'b': 2, 'c': 2});
    expect(s.averageCloseness, 4);
    expect(s.averageTrust, 3);
    expect(s.byStatus['ended'], 1);
    expect(s.byType['friend'], 2);
    expect(s.eventsLast30, 2);
    expect(s.positiveShare, closeTo(1 / 3, 0.001));
    expect(memberEnds(rels[1]), {'a'});
  });
}
