import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/features/data_reset.dart';
import 'package:prism_plurality/core/features/feature_registry.dart';
import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

class _Repo implements EntityRepository<TrackerRecord> {
  _Repo([List<TrackerRecord> seed = const []]) : rows = [...seed];
  final List<TrackerRecord> rows;
  final deleted = <String>{};
  final _c = StreamController<List<TrackerRecord>>.broadcast();
  List<TrackerRecord> get live => [for (final r in rows) if (!deleted.contains(r.id)) r];
  @override
  Stream<List<TrackerRecord>> watchAll() async* {
    yield live;
    yield* _c.stream;
  }

  @override
  Future<List<TrackerRecord>> getAll() async => live;
  @override
  Future<TrackerRecord?> getById(String id) async => live.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> create(TrackerRecord item) async {
    if (rows.any((r) => r.id == item.id)) throw StateError('duplicate id ${item.id}');
    rows.add(item);
    _c.add(live);
  }

  @override
  Future<void> update(TrackerRecord item) async {
    rows[rows.indexWhere((r) => r.id == item.id)] = item;
    _c.add(live);
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id); // soft delete, like the real repository
    _c.add(live);
  }
}

TrackerRecord _r(String id, String kind, DateTime at, {String? parent}) => TrackerRecord(id: id, kind: kind, parentId: parent, occurredAt: at, createdAt: at, modifiedAt: at);

const _flags = (chat: true, polls: true, habits: true, sleep: true, notes: true, reminders: true, boards: false);

void main() {
  test('every navigation tab belongs to a registered feature', () {
    for (final id in AppShellTabId.values) {
      if (id == AppShellTabId.home || id == AppShellTabId.settings) continue;
      expect(featureByTab[id], isNotNull, reason: '$id must be registered in prismFeatures');
    }
  });

  test('feature ids are unique, dependencies exist, data kinds are real', () {
    final ids = prismFeatures.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final f in prismFeatures) {
      for (final d in f.dependsOn) {
        expect(prismFeatureIndex[d], isNotNull, reason: '${f.id} depends on missing $d');
      }
      for (final s in f.data.sources) {
        expect(resetSources[s], isNotNull, reason: '${f.id} uses unknown reset source $s');
      }
      expect(f.data.activityKinds.toSet().intersection(f.data.permanentKinds.toSet()), isEmpty);
    }
    // Each tracker kind belongs to at most one feature.
    final seen = <String, String>{};
    for (final f in prismFeatures) {
      for (final k in [...f.data.activityKinds, ...f.data.permanentKinds]) {
        expect(seen[k], isNull, reason: '$k is in ${seen[k]} and ${f.id}');
        seen[k] = f.id;
      }
    }
  });

  test('feature switches persist in a synced record; core and legacy behave', () async {
    final repo = _Repo();
    final c = ProviderContainer(overrides: [trackerRecordRepositoryProvider.overrideWithValue(repo), featureFlagsProvider.overrideWithValue(_flags)]);
    addTearDown(c.dispose);
    c.listen(featureStatesProvider, (_, _) {});
    await c.read(trackerRecordsProvider.future);
    expect(c.read(featureStatesProvider)['relationships'], isTrue);
    expect(c.read(featureStatesProvider)['boards'], isFalse, reason: 'legacy flag');
    await c.read(featureActionsProvider).setEnabled('relationships', false);
    c.invalidate(trackerRecordsProvider);
    await c.read(trackerRecordsProvider.future);
    expect(c.read(featureStatesProvider)['relationships'], isFalse);
    expect(repo.live.where((r) => r.kind == TrackerKind.appFeatures), hasLength(1));
    await c.read(featureActionsProvider).setEnabled('members', false);
    expect(c.read(featureStatesProvider)['members'], isTrue, reason: 'core features stay on');
    expect(disabledFeatureFor('/relationships/r/abc', c.read(featureStatesProvider))?.id, 'relationships');
    expect(disabledFeatureFor('/journal', c.read(featureStatesProvider)), isNull);
  });

  test('date ranges use local boundaries; weeks cross month and year ends', () {
    final wed = DateTime(2026, 12, 30, 15);
    final w = rangeFor(ResetPeriod.week, wed);
    expect(w.start, DateTime(2026, 12, 28));
    expect(w.end, DateTime(2027, 1, 4));
    final sunStart = rangeFor(ResetPeriod.week, DateTime(2027, 1, 2), firstWeekday: DateTime.sunday);
    expect(sunStart.start, DateTime(2026, 12, 27));
    expect(rangeFor(ResetPeriod.month, wed).end, DateTime(2027, 1, 1));
    expect(rangeFor(ResetPeriod.year, wed).start, DateTime(2026));
    final today = rangeFor(ResetPeriod.today, wed);
    expect(today.contains(DateTime(2026, 12, 30, 23, 59)), isTrue);
    expect(today.contains(DateTime(2026, 12, 31)), isFalse);
    final custom = rangeFor(ResetPeriod.custom, wed, customStart: DateTime(2026, 3, 1), customEnd: DateTime(2026, 3, 3));
    expect(custom.contains(DateTime(2026, 3, 3, 22)), isTrue);
  });

  test('reset removes only the feature’s dated records in range, and undo restores them', () async {
    final dir = await Directory.systemTemp.createTemp('reset');
    DataResetService.testDir = dir;
    addTearDown(() => dir.delete(recursive: true));
    final now = DateTime.now();
    final lastYear = DateTime(now.year - 1, 6, 1);
    final repo = _Repo([
      _r('w1', TrackerKind.fitnessWorkout, now),
      _r('w2', TrackerKind.fitnessWorkout, lastYear),
      _r('g1', TrackerKind.fitnessGoal, now),
      _r('rel', TrackerKind.relationship, now),
      _r('ev', TrackerKind.relationshipEvent, now, parent: 'rel'),
      _r('j1', TrackerKind.journalEntry, now),
    ]);
    final c = ProviderContainer(overrides: [trackerRecordRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    c.listen(trackerRecordsProvider, (_, _) {});
    final svc = c.read(dataResetServiceProvider);
    final fitness = prismFeatureIndex['fitness']!;
    final plan = await svc.plan(fitness, ResetPeriod.year, rangeFor(ResetPeriod.year, now));
    expect(plan.items.map((i) => i.id), ['w1'], reason: 'goals are long-term; last year untouched');
    expect(plan.recoverable, isTrue);
    final batch = await svc.execute(plan);
    expect(repo.live.map((r) => r.id), containsAll(['w2', 'g1', 'rel', 'ev', 'j1']));
    expect(repo.live.any((r) => r.id == 'w1'), isFalse);
    expect(repo.live.where((r) => r.kind == TrackerKind.appResetLog), hasLength(1));
    expect(await svc.canUndo(batch), isTrue);
    final n = await svc.undo(batch);
    expect(n, 1);
    expect(repo.live.where((r) => r.kind == TrackerKind.fitnessWorkout && r.occurredAt == plan.items.single.date), hasLength(1));
    expect(await svc.canUndo(batch), isFalse);

    // Clearing all relationship data keeps parent links when restored.
    final relPlan = await svc.plan(prismFeatureIndex['relationships']!, ResetPeriod.all, rangeFor(ResetPeriod.all, now));
    expect(relPlan.items.map((i) => i.id).toSet(), {'rel', 'ev'});
    final b2 = await svc.execute(relPlan);
    expect(repo.live.any((r) => r.kind == TrackerKind.relationship), isFalse);
    await svc.undo(b2);
    final newRel = repo.live.firstWhere((r) => r.kind == TrackerKind.relationship);
    final newEv = repo.live.firstWhere((r) => r.kind == TrackerKind.relationshipEvent);
    expect(newEv.parentId, newRel.id);
    expect(repo.live.any((r) => r.id == 'j1'), isTrue, reason: 'journal untouched');
  });
}
