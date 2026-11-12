import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/sleep_log/utils/sleep_log.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

const sleepScheduleKind = 'sleep.schedule';

/// The last 120 sleep sessions (newest first).
final sleepLogSessionsProvider = StreamProvider<List<FrontingSession>>(
  (ref) => ref
      .watch(frontingSessionRepositoryProvider)
      .watchRecentSleepSessions(limit: 120),
);

final sleepLogsProvider = Provider<List<TrackerRecord>>(
  (ref) =>
      ref.watch(trackerKindProvider(TrackerKind.sleepLog)).value ?? const [],
);

/// The sleep schedule record, if one was saved.
final sleepScheduleProvider = Provider<TrackerRecord?>(
  (ref) =>
      (ref.watch(trackerKindProvider(sleepScheduleKind)).value ??
              const <TrackerRecord>[])
          .firstOrNull,
);

final sleepNightsProvider = Provider<AsyncValue<List<SleepNight>>>((ref) {
  final sessions = ref.watch(sleepLogSessionsProvider);
  return sessions.whenData((s) => joinNights(s, ref.watch(sleepLogsProvider)));
});
