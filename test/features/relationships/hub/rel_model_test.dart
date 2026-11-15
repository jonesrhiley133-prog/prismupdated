import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/relationships/hub/rel_layout.dart';
import 'package:prism_plurality/features/relationships/hub/rel_map.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

final _t = DateTime(2026);
TrackerRecord _r(String id, String a, String b, Map<String, Object?> f) => TrackerRecord(id: id, kind: TrackerKind.relationship, memberId: a, createdAt: _t, modifiedAt: _t).withFields({'otherType': 'member', 'otherId': b, ...f});

class _Repo implements EntityRepository<TrackerRecord> {
  final rows = <TrackerRecord>[];
  @override
  Stream<List<TrackerRecord>> watchAll() async* {
    yield [...rows];
  }

  @override
  Future<List<TrackerRecord>> getAll() async => [...rows];
  @override
  Future<TrackerRecord?> getById(String id) async => rows.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> create(TrackerRecord item) async => rows.add(item);
  @override
  Future<void> update(TrackerRecord item) async => rows[rows.indexWhere((r) => r.id == item.id)] = item;
  @override
  Future<void> delete(String id) async => rows.removeWhere((r) => r.id == id);
}

void main() {
  test('older single-type records read as labels', () {
    final r = Rel(_r('1', 'a', 'b', {'type': 'best_friend', 'closeness': 4}));
    expect(r.labels, ['best_friends']);
    expect(r.dyn('closeness'), 4);
    expect(r.confidence, 'confirmed');
  });

  test('directional labels invert for the other alter', () {
    final r = Rel(_r('1', 'p', 'c', {'labels': ['parent', 'best_friends']}));
    expect(r.labelsFor('p'), ['parent', 'best_friends']);
    expect(r.labelsFor('c'), ['child', 'best_friends']);
  });

  test('statistics count categories, complicated and exploring', () {
    final rels = [
      Rel(_r('1', 'a', 'b', {'labels': ['sibling', 'best_friends']})),
      Rel(_r('2', 'a', 'c', {'labels': ['dating'], 'status': 'exploring'})),
      Rel(_r('3', 'b', 'c', {'labels': ['friends'], 'confidence': 'uncertain'})),
    ];
    final s = RelStats(rels, const RelSettings());
    expect((s.total, s.alters, s.familial, s.platonic, s.romantic, s.complicated, s.exploring), (3, 3, 1, 2, 1, 1, 1));
  });

  test('saving a second relationship for a pair adds labels instead of duplicating', () async {
    final repo = _Repo();
    final c = ProviderContainer(overrides: [trackerRecordRepositoryProvider.overrideWithValue(repo), isolatedMembersProvider.overrideWith(IsolatedMembersNotifier.new)]);
    addTearDown(c.dispose);
    c.listen(trackerRecordsProvider, (_, _) {});
    c.listen(relsProvider, (_, _) {});
    await c.read(trackerRecordsProvider.future);
    final actions = c.read(relActionsProvider);
    final id = await actions.save(memberId: 'p', otherType: 'member', otherId: 'k', labels: ['parent']);
    c.invalidate(trackerRecordsProvider);
    await c.read(trackerRecordsProvider.future);
    // Saved from the child's side: "k is p's best friend" + "k is p's child".
    final id2 = await actions.save(memberId: 'k', otherType: 'member', otherId: 'p', labels: ['best_friends', 'child']);
    expect(id2, id);
    final rows = repo.rows.where((r) => r.kind == TrackerKind.relationship).toList();
    expect(rows, hasLength(1));
    expect(Rel(rows.single).labels, ['parent', 'best_friends']);
    await expectLater(actions.save(memberId: 'p', otherType: 'member', otherId: 'p', labels: ['friends']), throwsArgumentError);
  });

  test('deleting removes children and can be restored', () async {
    final repo = _Repo()
      ..rows.addAll([
        _r('1', 'a', 'b', {'labels': ['friends']}),
        TrackerRecord(id: 'n1', kind: TrackerKind.relationshipNote, parentId: '1', createdAt: _t, modifiedAt: _t),
        TrackerRecord(id: 'e1', kind: TrackerKind.relationshipEvent, parentId: '1', createdAt: _t, modifiedAt: _t),
      ]);
    final c = ProviderContainer(overrides: [trackerRecordRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    c.listen(relsProvider, (_, _) {});
    await c.read(trackerRecordsProvider.future);
    final removed = await c.read(relActionsProvider).delete(c.read(relsProvider).single);
    expect(repo.rows, isEmpty);
    await c.read(relActionsProvider).restore(removed);
    expect(repo.rows.map((r) => r.id), unorderedEquals(['1', 'n1', 'e1']));
  });

  test('layouts are deterministic and finite', () {
    final nodes = [for (var i = 0; i < 25; i++) 'n$i'];
    final edges = [for (var i = 1; i < 25; i++) ('n${i ~/ 2}', 'n$i')];
    final a = networkLayout(nodes, edges), b = networkLayout(nodes, edges);
    expect(a.positions, b.positions);
    expect(a.positions.values.every((p) => p.dx.isFinite && p.dy.isFinite && p.dx >= 0 && p.dy >= 0), isTrue);
    final fam = familyLayout(['g', 'p', 'c', 's'], [('g', 'p', 1), ('p', 'c', 1), ('c', 's', 0)]);
    final y = {for (final e in fam.positions.entries) e.key: e.value.dy};
    expect(y['g']! < y['p']! && y['p']! < y['c']!, isTrue);
    expect(y['c'], y['s']);
    final rad = radialLayout('x', ['a', 'b', 'c']);
    expect(rad.size, isA<Size>());
  });

  test('map views filter connections', () {
    final rels = [
      Rel(_r('1', 'a', 'b', {'labels': ['sibling', 'best_friends']})),
      Rel(_r('2', 'a', 'c', {'labels': ['dating']})),
      Rel(_r('3', 'c', 'd', {'labels': ['mentee']})),
    ];
    final ids = {'a', 'b', 'c', 'd'};
    const s = RelSettings();
    expect(mapEdges(rels: rels, alterIds: ids, settings: s, view: RelMapView.network), hasLength(3));
    expect(mapEdges(rels: rels, alterIds: ids, settings: s, view: RelMapView.family).single.rel.id, '1');
    expect(mapEdges(rels: rels, alterIds: ids, settings: s, view: RelMapView.romantic).single.rel.id, '2');
    expect(mapEdges(rels: rels, alterIds: ids, settings: s, view: RelMapView.individual, focus: 'c'), hasLength(2));
    expect(mapEdges(rels: rels, alterIds: ids, settings: s, view: RelMapView.network, hiddenCategories: {'familial', 'platonic'}), hasLength(2));
    // "c is d's mentee" draws as an arrow from mentor d to c.
    final m = mapEdges(rels: rels, alterIds: ids, settings: s, view: RelMapView.network).firstWhere((e) => e.rel.id == '3');
    expect((m.a, m.b, m.directional), ('d', 'c', true));
    // Multiple labels draw as separate styles.
    expect(mapEdges(rels: rels, alterIds: ids, settings: s, view: RelMapView.network).first.styles, ['sibling', 'platonic']);
  });
}
