import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/core/sync/prism_sync_providers.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/work/providers/work_providers.dart';

ProviderContainer _container(AppDatabase db) => ProviderContainer(
  overrides: [
    databaseProvider.overrideWithValue(db),
    prismSyncHandleProvider.overrideWithBuild((ref, notifier) => null),
  ],
);

void main() {
  test(
    'locations and sessions persist, one active session at a time',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = _container(db);
      addTearDown(c.dispose);
      final n = c.read(locationsNotifierProvider.notifier);

      final home = await n.createLocation(name: '  Home ', emoji: '🏠');
      final work = await n.createLocation(name: 'Office', isFavorite: true);
      expect(await n.createLocation(name: '   '), isNull);
      expect(home!.name, 'Home');

      final t0 = DateTime(2026, 5, 1, 9, 0, 0);
      await n.startSession(home.id, at: t0);
      await n.startSession(work!.id, at: t0.add(const Duration(seconds: 3725)));

      final sessions = await c.read(locationSessionRepositoryProvider).getAll();
      expect(sessions, hasLength(2));
      final finished = sessions.singleWhere((s) => s.locationId == home.id);
      expect(finished.endedAt, t0.add(const Duration(seconds: 3725)));
      expect(finished.durationAt(DateTime.now()).inSeconds, 3725);
      expect(sessions.where((s) => s.isActive).single.locationId, work.id);

      await n.stopSession(at: t0.add(const Duration(hours: 2)));
      expect(
        (await c.read(locationSessionRepositoryProvider).getAll()).where(
          (s) => s.isActive,
        ),
        isEmpty,
      );

      // Reopen with a fresh container on the same DB: data persists.
      final c2 = _container(db);
      addTearDown(c2.dispose);
      expect(
        await c2.read(savedLocationRepositoryProvider).getAll(),
        hasLength(2),
      );
    },
  );

  test(
    'clock in snapshots the wage; later wage changes keep history',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = _container(db);
      addTearDown(c.dispose);
      final n = c.read(workNotifierProvider.notifier);

      final job = await n.createJob(
        name: 'Cafe',
        hourlyRateCents: 1800,
        currencyCode: 'USD',
      );
      final t0 = DateTime(2026, 5, 1, 9);
      await n.clockIn(job!, at: t0);
      await n.clockIn(job, at: t0.add(const Duration(minutes: 1))); // no-op
      await n.saveJob(job.copyWith(hourlyRateCents: 2500));
      await n.clockOut(
        jobId: job.id,
        at: t0.add(const Duration(hours: 2, seconds: 1)),
      );

      final sessions = await c.read(workSessionRepositoryProvider).getAll();
      final s = sessions.single;
      expect(s.hourlyRateCents, 1800);
      expect(s.workedAt(DateTime.now()).inSeconds, 7201);
      expect(s.estimatedEarningsCentsAt(DateTime.now()), 3601);
      expect(
        (await c.read(jobRepositoryProvider).getById(job.id))!.hourlyRateCents,
        2500,
      );
    },
  );
}
