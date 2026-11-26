import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_wizard.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

final _t = DateTime(2026);
Member _m(String id) => Member(id: id, name: id, createdAt: _t);
TrackerRecord _sub(
  String id, {
  bool isolate = true,
  List<Map<String, Object?>> legacy = const [],
}) => TrackerRecord(
  id: id,
  kind: TrackerKind.subsystem,
  title: id,
  createdAt: _t,
  modifiedAt: _t,
).withFields({'isolate': isolate, if (legacy.isNotEmpty) 'members': legacy});
TrackerRecord _mem(String sub, String member) =>
    TrackerRecord(
      id: '$sub-$member',
      kind: TrackerKind.subMember,
      parentId: sub,
      memberId: member,
      createdAt: _t,
      modifiedAt: _t,
    ).withFields({
      'roles': ['Guard'],
    });

ProviderContainer _container(List<TrackerRecord> records) {
  final members = [_m('a'), _m('b'), _m('c'), _m('d')];
  return ProviderContainer(
    overrides: [
      trackerRecordsProvider.overrideWith((ref) => Stream.value(records)),
      activeMemberListProvider.overrideWith((ref) => Stream.value(members)),
      allMemberListProvider.overrideWith((ref) => Stream.value(members)),
    ],
  );
}

Future<List<String>> _visible(ProviderContainer c) async {
  c.listen(userVisibleMemberListProvider, (_, _) {});
  c.listen(pickableMemberListProvider, (_, _) {});
  c.listen(subMembershipsProvider, (_, _) {});
  c.listen(isolationSyncProvider, (_, _) {});
  await c.read(trackerRecordsProvider.future);
  await c.read(activeMemberListProvider.future);
  await Future<void>.delayed(const Duration(milliseconds: 450));
  await Future<void>.delayed(Duration.zero);
  return [
    for (final m
        in c.read(userVisibleMemberListProvider).value ?? const <Member>[])
      m.id,
  ];
}

void main() {
  test('members of an isolated subsystem leave system-wide lists', () async {
    final c = _container([_sub('s1'), _mem('s1', 'b'), _mem('s1', 'c')]);
    addTearDown(c.dispose);
    expect(await _visible(c), ['a', 'd']);
    expect(c.read(pickableMemberListProvider).value!.map((m) => m.id), [
      'a',
      'd',
    ]);
    // Still known to subsystem screens.
    expect(
      c.read(subMembershipsProvider).map((m) => m.memberId),
      containsAll(['b', 'c']),
    );
  });

  test('non-isolated subsystems keep members visible', () async {
    final c = _container([_sub('s1', isolate: false), _mem('s1', 'b')]);
    addTearDown(c.dispose);
    expect(await _visible(c), ['a', 'b', 'c', 'd']);
  });

  test('an alter can belong to several subsystems without copies', () async {
    final c = _container([
      _sub('s1'),
      _sub('s2', isolate: false),
      _mem('s1', 'b'),
      _mem('s2', 'b'),
    ]);
    addTearDown(c.dispose);
    await _visible(c);
    final ms = c
        .read(subMembershipsProvider)
        .where((m) => m.memberId == 'b')
        .toList();
    expect(ms.map((m) => m.subsystemId), unorderedEquals(['s1', 's2']));
    expect(c.read(computedIsolationProvider).ids, {'b'});
  });

  test('legacy member lists are read as memberships', () async {
    final c = _container([
      _sub(
        's1',
        legacy: [
          {'id': 'd', 'role': 'Host'},
        ],
      ),
    ]);
    addTearDown(c.dispose);
    expect(await _visible(c), ['a', 'b', 'c']);
    final m = c.read(subMembershipsProvider).single;
    expect(m.roles, ['Host']);
    expect(m.record.flag('legacy'), isTrue);
  });

  test('parseRoles splits on spaces and keeps quoted roles', () {
    expect(parseRoles('Host Protector "Inner Self Helper", Little'), [
      'Host',
      'Protector',
      'Inner Self Helper',
      'Little',
    ]);
    expect(parseRoles('  '), isEmpty);
  });
}
