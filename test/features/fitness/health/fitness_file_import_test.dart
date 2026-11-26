import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/fitness/health/fitness_file_import.dart';
import 'package:prism_plurality/features/fitness/health/health_sync.dart';
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

Uint8List _fixture(String name) =>
    File('test/fixtures/fitness/$name').readAsBytesSync();

void main() {
  test(
    'Apple Health export: workouts, per-day totals with one source per day, skipped rows',
    () {
      final p = parseFitnessExport(_fixture('apple_export.xml'), 'export.xml');
      expect(p.kind, ExportKind.appleHealth);
      expect(p.workouts, hasLength(1));
      final w = p.workouts.single;
      expect(
        (w.activity, w.minutes, w.distanceKm, w.calories),
        ('run', 30, 5.1, 320),
      );
      final day = p.daily[dayKey(DateTime.utc(2026, 3, 9, 9))]!;
      // iPhone 2000 vs Watch 2300 for the same walk: the larger, not 4300.
      expect(day['steps'], 2300);
      expect(day['stepsSource'], 'Sam’s Apple Watch');
      expect(day['distanceKm'], 1.25);
      expect(day['calories'], 100, reason: '418.4 kJ = 100 kcal');
      expect(day['heartRateAvg'], 70);
      expect(p.skipped, 1);
    },
  );

  test('Apple Health zip is unpacked', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'apple_health_export/export.xml',
          _fixture('apple_export.xml').length,
          _fixture('apple_export.xml'),
        ),
      );
    final zip = Uint8List.fromList(ZipEncoder().encode(archive));
    final p = parseFitnessExport(zip, 'export.zip');
    expect(p.workouts, hasLength(1));
  });

  test('Google Fit Takeout daily metrics', () {
    final p = parseFitnessExport(
      _fixture('google_fit_daily.csv'),
      'Daily activity metrics.csv',
    );
    expect(p.kind, ExportKind.googleFit);
    expect(p.daily['2026-03-07']!['steps'], 4567);
    expect(p.daily['2026-03-07']!['distanceKm'], 3.21);
    expect(p.daily['2026-03-07']!['activeMinutes'], 42);
    expect(p.daily.containsKey('2026-03-08'), isFalse);
    expect(p.skipped, 1);
  });

  test(
    'Samsung Health CSVs: steps per device resolved, exercises imported, bad rows skipped',
    () {
      final p = parseSamsungCsvs([
        utf8.decode(_fixture('samsung_steps.csv')),
        utf8.decode(_fixture('samsung_exercise.csv')),
      ]);
      expect(p.kind, ExportKind.samsungHealth);
      expect(
        p.daily['2026-03-09']!['steps'],
        6400,
        reason: 'the device with the larger count, not both',
      );
      expect(p.workouts.single.activity, 'run');
      expect(p.workouts.single.minutes, 40);
      expect(p.workouts.single.sourceId, 'samsung:abc-123');
      expect(p.skipped, 2);
    },
  );

  test('unsupported files are rejected before anything is saved', () {
    expect(
      () => parseFitnessExport(
        Uint8List.fromList(utf8.encode('a,b\n1,2')),
        'random.csv',
      ),
      throwsA(isA<ImportFormatException>()),
    );
    expect(
      () => parseFitnessExport(
        Uint8List.fromList(utf8.encode('<?xml version="1.0"?><foo/>')),
        'x.xml',
      ),
      throwsA(isA<ImportFormatException>()),
    );
  });

  test('importing the same file twice creates nothing new', () async {
    final repo = _Repo();
    final c = ProviderContainer(
      overrides: [trackerRecordRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final w = c.read(fitnessWriterProvider);
    final p = parseFitnessExport(_fixture('apple_export.xml'), 'export.xml');
    final first = await w.upsertWorkouts(
      p.workouts,
      platform: exportPlatform(p.kind),
    );
    await w.upsertDaily(p.daily, platform: exportPlatform(p.kind));
    final count = repo.rows.length;
    final second = await w.upsertWorkouts(
      p.workouts,
      platform: exportPlatform(p.kind),
    );
    await w.upsertDaily(p.daily, platform: exportPlatform(p.kind));
    expect(first.$1, 1);
    expect(second, (0, 0, 1));
    expect(repo.rows.length, count);
    expect(
      repo.rows.where((r) => r.kind == TrackerKind.fitnessDaily).length,
      1,
    );
  });

  test('a day covered by sync and a file shows one value per metric', () {
    final t = DateTime(2026, 3, 9);
    final a = TrackerRecord(
      id: 'a',
      kind: TrackerKind.fitnessDaily,
      createdAt: t,
      modifiedAt: t,
    ).withFields({'steps': 5000, 'platform': 'healthconnect'});
    final b =
        TrackerRecord(
          id: 'b',
          kind: TrackerKind.fitnessDaily,
          createdAt: t,
          modifiedAt: t,
        ).withFields({
          'steps': 5200,
          'distanceKm': 3.1,
          'platform': 'file:samsung',
        });
    expect(mergeDailyRows([a, b]), containsPair('steps', 5200));
    expect(mergeDailyRows([a, b]), containsPair('distanceKm', 3.1));
  });
}
