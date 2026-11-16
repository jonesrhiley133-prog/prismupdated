import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/features/cycle/providers/cycle_providers.dart';
import 'package:prism_plurality/features/insights/utils/insight_engine.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/work/providers/work_providers.dart';

/// Look-back window for patterns, in days.
const insightLookBackDays = 30;

/// Fronting + sleep sessions overlapping the look-back window ending on
/// [day] (inclusive).
final insightFrontingSessionsProvider = StreamProvider.autoDispose
    .family<List<FrontingSession>, DateTime>((ref, day) {
      final start = DateTime(
        day.year,
        day.month,
        day.day - insightLookBackDays,
      );
      final end = DateTime(day.year, day.month, day.day + 1);
      return ref
          .watch(frontingSessionRepositoryProvider)
          .watchSessionsOverlappingRange(start, end);
    });

/// The insight for [day], or null while data is loading.
final dailyInsightProvider = Provider.autoDispose.family<DailyInsight?, DateTime>(
  (ref, day) {
    final mood = ref.watch(moodEntriesProvider);
    final fronting = ref.watch(insightFrontingSessionsProvider(day));
    final locations = ref.watch(locationSessionsProvider);
    final work = ref.watch(workSessionsProvider);
    final cycle = ref.watch(cycleEntriesProvider);
    if (!mood.hasValue ||
        !fronting.hasValue ||
        !locations.hasValue ||
        !work.hasValue ||
        !cycle.hasValue) {
      return null;
    }
    return buildDailyInsight(
      InsightInputs(
        // Body sensations are private Health content, not system-wide insights.
        moodEntries: [
          for (final m in mood.value!) m.copyWith(bodySensations: const []),
        ],
        frontingSessions: fronting.value!,
        locationSessions: locations.value!,
        workSessions: work.value!,
      ),
      day: day,
      now: DateTime.now(),
      lookBackDays: insightLookBackDays,
    );
  },
);
