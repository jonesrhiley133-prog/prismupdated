import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/subsystems/utils/subsystems.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

final _t = DateTime(2026);
TrackerRecord _s(
  String id, {
  String? parent,
  List<String> members = const [],
  int order = 0,
}) =>
    TrackerRecord(
      id: id,
      kind: TrackerKind.subsystem,
      title: id,
      parentId: parent,
      sortOrder: order,
      createdAt: _t,
      modifiedAt: _t,
    ).withFields({
      SubField.members: [
        for (final m in members)
          SubsystemMember(memberId: m, role: 'r$m').toJson(),
      ],
    });

void main() {
  final all = [
    _s('root', members: ['a']),
    _s('child', parent: 'root', members: ['b']),
    _s('grand', parent: 'child', members: ['c', 'a']),
    _s('other', members: ['d'], order: 1),
  ];

  test('tree order, descendants, members and cycle guard', () {
    expect(subsystemTree(all).map((e) => (e.$1.id, e.$2)), [
      ('root', 0),
      ('child', 1),
      ('grand', 2),
      ('other', 0),
    ]);
    expect(descendantsOf('child', all), {'child', 'grand'});
    expect(allMemberIds(all.first, all), {'a', 'b', 'c'});
    expect(subsystemMembers(all[1]).single.role, 'rb');
    expect(wouldCycle('root', 'grand', all), isTrue);
    expect(wouldCycle('grand', 'other', all), isFalse);
    // An orphan whose parent was deleted is shown at the top level.
    expect(subsystemTree([_s('x', parent: 'gone')]).single.$2, 0);
  });

  test('fronting share clips to the window and skips sleep', () {
    final from = DateTime(2026, 3, 1), to = DateTime(2026, 3, 2);
    final sessions = [
      FrontingSession(
        id: '1',
        memberId: 'a',
        startTime: DateTime(2026, 2, 28, 18),
        endTime: DateTime(2026, 3, 1, 6),
      ),
      FrontingSession(
        id: '2',
        memberId: 'z',
        startTime: DateTime(2026, 3, 1, 6),
        endTime: DateTime(2026, 3, 1, 12),
      ),
      FrontingSession(
        id: '3',
        startTime: DateTime(2026, 3, 1, 0),
        endTime: DateTime(2026, 3, 1, 8),
        sessionType: SessionType.sleep,
      ),
    ];
    expect(frontingShare({'a'}, sessions, from, to), 0.5);
    expect(frontingShare({'q'}, const [], from, to), 0);
  });
}
