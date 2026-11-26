import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/fitness/health/health_sync.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

class _Repo implements EntityRepository<TrackerRecord> {
  final rows = <TrackerRecord>[];
  @override
  Stream<List<TrackerRecord>> watchAll() async* {
    yield [...rows];
  }

  @override
  Future<List<TrackerRecord>> getAll() async => [...rows];
  @override
  Future<TrackerRecord?> getById(String id) async =>
      rows.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> create(TrackerRecord item) async => rows.add(item);
  @override
  Future<void> update(TrackerRecord item) async =>
      rows[rows.indexWhere((r) => r.id == item.id)] = item;
  @override
  Future<void> delete(String id) async => rows.removeWhere((r) => r.id == id);
}

HealthDataPoint _workout(
  String id,
  String source,
  DateTime start,
  int minutes,
  HealthWorkoutActivityType type,
) => HealthDataPoint(
  uuid: id,
  value: WorkoutHealthValue(
    workoutActivityType: type,
    totalDistance: 5000,
    totalDistanceUnit: HealthDataUnit.METER,
    totalEnergyBurned: 300,
  ),
  type: HealthDataType.WORKOUT,
  unit: HealthDataUnit.NO_UNIT,
  dateFrom: start,
  dateTo: start.add(Duration(minutes: minutes)),
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'd',
  sourceId: source,
  sourceName: source,
);

class _FakeGateway implements HealthGateway {
  _FakeGateway(this.points);
  List<HealthDataPoint> points;
  bool granted = true;

  /// Types the user refused in the system dialog.
  Set<HealthDataType> deniedTypes = {};

  /// Types whose reads throw (simulated platform failure).
  Set<HealthDataType> failing = {};
  @override
  bool get supported => true;
  @override
  bool get ios => false;
  @override
  Future<String> availability() async => 'available';
  @override
  Future<void> install() async {}
  @override
  Future<bool> request(List<HealthDataType> types) async => granted;
  @override
  Future<bool?> has(List<HealthDataType> types) async =>
      granted && !types.any(deniedTypes.contains);
  @override
  Future<bool> requestHistory() async => true;
  @override
  Future<void> revoke() async {}
  @override
  Future<List<HealthDataPoint>> read(
    List<HealthDataType> types,
    DateTime from,
    DateTime to,
  ) async {
    if (types.any(failing.contains)) throw StateError('read failed');
    return [
      for (final p in points)
        if (types.contains(p.type) && !p.dateFrom.isBefore(from)) p,
    ];
  }

  @override
  Future<int?> steps(DateTime from, DateTime to) async =>
      from.day == DateTime.now().day ? 4200 : null;
}

void main() {
  mainExtra();
  test('workout types map to Prism activities', () {
    expect(mapWorkoutActivity('RUNNING_TREADMILL'), 'run');
    expect(mapWorkoutActivity('BIKING'), 'cycle');
    expect(mapWorkoutActivity('TRADITIONAL_STRENGTH_TRAINING'), 'strength');
    expect(mapWorkoutActivity('SOCCER'), 'sports');
    expect(mapWorkoutActivity('MEDITATION'), 'other');
  });

  test('duplicates: same source id, or the same session from two apps', () {
    final t = DateTime(2026, 3, 1, 9);
    final existing = [
      TrackerRecord(
        id: 'x',
        kind: TrackerKind.fitnessWorkout,
        occurredAt: t,
        createdAt: t,
        modifiedAt: t,
      ).withFields({'activity': 'run', 'minutes': 35, 'sourceId': 'a'}),
    ];
    final incoming = [
      ImportedWorkout(
        sourceId: 'a',
        source: 'Strava',
        activity: 'run',
        start: t,
        end: t.add(const Duration(minutes: 35)),
      ),
      ImportedWorkout(
        sourceId: 'b',
        source: 'Fit',
        activity: 'run',
        start: t.add(const Duration(minutes: 1)),
        end: t.add(const Duration(minutes: 36)),
      ),
      ImportedWorkout(
        sourceId: 'c',
        source: 'Fit',
        activity: 'yoga',
        start: t.add(const Duration(hours: 3)),
        end: t.add(const Duration(hours: 4)),
      ),
      ImportedWorkout(
        sourceId: 'd',
        source: 'Other',
        activity: 'yoga',
        start: t.add(const Duration(hours: 3)),
        end: t.add(const Duration(hours: 4)),
      ),
    ];
    final (fresh, dups) = dedupeWorkouts(existing, incoming);
    expect(fresh.map((w) => w.sourceId), ['c']);
    expect(dups, 3);
  });

  test(
    'sync imports workouts with attribution and default alter, skips them next time',
    () async {
      final repo = _Repo();
      final now = DateTime.now();
      final gw = _FakeGateway([
        _workout(
          'w1',
          'Strava',
          now.subtract(const Duration(hours: 2)),
          35,
          HealthWorkoutActivityType.RUNNING,
        ),
      ]);
      final c = ProviderContainer(
        overrides: [
          trackerRecordRepositoryProvider.overrideWithValue(repo),
          healthGatewayProvider.overrideWithValue(gw),
          featureStatesProvider.overrideWithValue({
            'fitness': true,
            'healthIntegration': true,
          }),
        ],
      );
      addTearDown(c.dispose);
      c.listen(trackerRecordsProvider, (_, _) {});
      c.listen(healthSettingsProvider, (_, _) {});
      Future<void> refresh() async {
        c.invalidate(trackerRecordsProvider);
        await c.read(trackerRecordsProvider.future);
      }

      await refresh();
      final svc = c.read(healthSyncProvider);
      // Not connected: nothing happens.
      expect((await svc.sync()).workouts, 0);
      expect(
        await svc.connect({
          HealthCategory.workouts,
          HealthCategory.steps,
          HealthCategory.activeMinutes,
        }),
        isTrue,
      );
      await refresh();
      await svc.saveSettings({'defaultAlter': 'alter-1'});
      await refresh();
      final r1 = await svc.sync();
      expect(r1.error, isNull);
      expect(r1.workouts, 1);
      await refresh();
      final w = repo.rows.firstWhere(
        (r) => r.kind == TrackerKind.fitnessWorkout,
      );
      expect(
        (
          w.str('activity'),
          w.integer('minutes'),
          w.str('source'),
          w.flag('imported'),
          w.memberId,
        ),
        ('run', 35, 'Strava', true, 'alter-1'),
      );
      expect(w.fields['distanceKm'], 5.0);
      final daily = repo.rows
          .where((r) => r.kind == TrackerKind.fitnessDaily)
          .toList();
      expect(
        daily.any(
          (d) => d.integer('steps') == 4200 && d.integer('activeMinutes') == 35,
        ),
        isTrue,
      );
      expect(c.read(healthSettingsProvider).sourcesSeen, contains('Strava'));
      // Second sync: the same workout is a duplicate.
      final r2 = await svc.sync();
      expect(r2.workouts, 0);
      expect(r2.duplicates, 1);
      // Remove imported keeps manual workouts.
      await c
          .read(trackerNotifierProvider.notifier)
          .create(
            kind: TrackerKind.fitnessWorkout,
            fields: {'activity': 'walk', 'minutes': 10},
          );
      await refresh();
      await svc.removeImported();
      expect(
        repo.rows
            .where((r) => r.kind == TrackerKind.fitnessWorkout)
            .map((r) => r.str('activity')),
        ['walk'],
      );
    },
  );

  test('declined permission leaves the integration disconnected', () async {
    final repo = _Repo();
    final gw = _FakeGateway([])..granted = false;
    final c = ProviderContainer(
      overrides: [
        trackerRecordRepositoryProvider.overrideWithValue(repo),
        healthGatewayProvider.overrideWithValue(gw),
      ],
    );
    addTearDown(c.dispose);
    c.listen(healthSettingsProvider, (_, _) {});
    await c.read(trackerRecordsProvider.future);
    expect(
      await c.read(healthSyncProvider).connect({HealthCategory.workouts}),
      isFalse,
    );
    c.invalidate(trackerRecordsProvider);
    await c.read(trackerRecordsProvider.future);
    expect(c.read(healthSettingsProvider).connected, isFalse);
    expect(c.read(healthSettingsProvider).lastError, 'denied');
  });
}

HealthDataPoint _numeric(
  String id,
  HealthDataType type,
  String source,
  DateTime at,
  num value,
  HealthDataUnit unit,
) => HealthDataPoint(
  uuid: id,
  value: NumericHealthValue(numericValue: value),
  type: type,
  unit: unit,
  dateFrom: at,
  dateTo: at.add(const Duration(minutes: 5)),
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'd',
  sourceId: source,
  sourceName: source,
);

void mainExtra() {
  ProviderContainer container(_Repo repo, _FakeGateway gw) {
    final c = ProviderContainer(
      overrides: [
        trackerRecordRepositoryProvider.overrideWithValue(repo),
        healthGatewayProvider.overrideWithValue(gw),
        featureStatesProvider.overrideWithValue({
          'fitness': true,
          'healthIntegration': true,
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'partial permission: allowed types sync, refused ones are reported, not fatal',
    () async {
      final repo = _Repo();
      final now = DateTime.now();
      final gw = _FakeGateway([
        _numeric(
          'h1',
          HealthDataType.HEART_RATE,
          'Watch',
          now.subtract(const Duration(hours: 1)),
          70,
          HealthDataUnit.BEATS_PER_MINUTE,
        ),
      ])..deniedTypes = {HealthDataType.HEART_RATE};
      final c = container(repo, gw);
      final svc = c.read(healthSyncProvider);
      expect(
        await svc.connect({HealthCategory.steps, HealthCategory.heartRate}),
        isTrue,
      );
      final r = await svc.sync();
      expect(r.error, isNull);
      expect(r.byCategory[HealthCategory.steps]!.status, 'ok');
      expect(r.byCategory[HealthCategory.heartRate]!.status, 'denied');
      final days = repo.rows
          .where((x) => x.kind == TrackerKind.fitnessDaily)
          .toList();
      expect(days.single.integer('steps'), 4200);
      expect(days.single.integer('heartRateAvg'), isNull);
    },
  );

  test(
    'a failing type does not block the others, and is retried next sync',
    () async {
      final repo = _Repo();
      final now = DateTime.now();
      final gw = _FakeGateway([
        _workout(
          'w1',
          'Strava',
          now.subtract(const Duration(hours: 3)),
          30,
          HealthWorkoutActivityType.WALKING,
        ),
        _numeric(
          'd1',
          HealthDataType.DISTANCE_DELTA,
          'Phone',
          now.subtract(const Duration(hours: 2)),
          1500,
          HealthDataUnit.METER,
        ),
      ])..failing = {HealthDataType.DISTANCE_DELTA};
      final c = container(repo, gw);
      final svc = c.read(healthSyncProvider);
      await svc.connect({HealthCategory.workouts, HealthCategory.distance});
      final r1 = await svc.sync();
      expect(r1.byCategory[HealthCategory.workouts]!.status, 'ok');
      expect(r1.byCategory[HealthCategory.distance]!.status, 'failed');
      expect(r1.workouts, 1);
      final s1 = HealthSettings(
        repo.rows.firstWhere((x) => x.kind == TrackerKind.fitnessSource),
      );
      expect(s1.cursor(HealthCategory.workouts), isNotNull);
      expect(
        s1.cursor(HealthCategory.distance),
        isNull,
        reason: 'cursor only moves after data is saved',
      );
      gw.failing = {};
      final r2 = await svc.sync();
      expect(r2.byCategory[HealthCategory.distance]!.status, 'ok');
      expect(r2.workouts, 0);
      expect(
        repo.rows.where((x) => x.kind == TrackerKind.fitnessWorkout).length,
        1,
      );
      final day = repo.rows
          .where((x) => x.kind == TrackerKind.fitnessDaily)
          .single;
      expect(day.fields['distanceKm'], 1.5);
    },
  );

  test(
    're-sync updates edited source records, keeps manual edits, never duplicates days',
    () async {
      final repo = _Repo();
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 4));
      final gw = _FakeGateway([
        _workout('w1', 'Strava', start, 30, HealthWorkoutActivityType.RUNNING),
      ]);
      final c = container(repo, gw);
      final svc = c.read(healthSyncProvider);
      await svc.connect({HealthCategory.workouts, HealthCategory.steps});
      await svc.sync();
      // The provider extends the session.
      gw.points = [
        _workout('w1', 'Strava', start, 45, HealthWorkoutActivityType.RUNNING),
      ];
      final r = await svc.sync();
      expect(r.updated, 1);
      var w = repo.rows.firstWhere((x) => x.kind == TrackerKind.fitnessWorkout);
      expect(w.integer('minutes'), 45);
      // A hand edit in Prism wins over later provider changes.
      await c
          .read(trackerNotifierProvider.notifier)
          .save(w.withFields({'minutes': 50, 'manualEdit': true}));
      gw.points = [
        _workout('w1', 'Strava', start, 60, HealthWorkoutActivityType.RUNNING),
      ];
      await svc.sync();
      w = repo.rows.firstWhere((x) => x.kind == TrackerKind.fitnessWorkout);
      expect(w.integer('minutes'), 50);
      expect(
        repo.rows.where((x) => x.kind == TrackerKind.fitnessWorkout).length,
        1,
      );
      expect(
        repo.rows.where((x) => x.kind == TrackerKind.fitnessDaily).length,
        1,
        reason: 'one record per day however often it syncs',
      );
    },
  );

  test(
    'daily source policy picks one source instead of adding overlapping apps',
    () {
      expect(pickDailySource({'Phone': 5000, 'Watch': 5400}), (
        5400.0,
        'Watch',
      ));
      expect(pickDailySource({}), isNull);
    },
  );
}
