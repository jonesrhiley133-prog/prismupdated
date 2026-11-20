import 'package:flutter/foundation.dart';

import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/diagnostics/perf_probe.dart';
import 'package:prism_plurality/features/settings/services/stress_data_generator.dart';

/// Profiling builds only: seeds [StressPreset.perf] once. Later launches
/// reuse it, so before/after runs measure the same data.
Future<void> seedPerfFixture(AppDatabase db) async {
  if (!kPerfMode) return;
  final generator = StressDataGenerator(db);
  if (await generator.hasStressData()) return;
  final started = DateTime.now();
  await for (final _ in generator.generate(StressPreset.perf)) {}
  await db.systemSettingsDao.updateSystemName('Prism Perf Fixture');
  await db.systemSettingsDao.updateHasCompletedOnboarding(true);
  debugPrint(
    '[PERF] seeded fixture in ${DateTime.now().difference(started).inSeconds}s',
  );
}
