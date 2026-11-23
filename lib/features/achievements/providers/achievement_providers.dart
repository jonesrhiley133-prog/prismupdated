import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/achievements/utils/achievements.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

const _countsSql = '''
SELECT
  (SELECT COUNT(*) FROM members WHERE is_deleted = 0) AS members,
  (SELECT COUNT(*) FROM fronting_sessions
     WHERE is_deleted = 0 AND session_type = 0) AS front_sessions,
  (SELECT COALESCE(SUM(MAX(0, COALESCE(end_time, CAST(strftime('%s','now') AS INTEGER)) - start_time)), 0) / 3600
     FROM fronting_sessions WHERE is_deleted = 0 AND session_type = 0) AS front_hours,
  (SELECT COUNT(*) FROM fronting_sessions
     WHERE is_deleted = 0 AND session_type = 1) +
  (SELECT COUNT(*) FROM sleep_sessions WHERE is_deleted = 0) AS sleep_nights,
  (SELECT COUNT(*) FROM mood_entries WHERE is_deleted = 0) AS mood,
  (SELECT COUNT(*) FROM tracker_records
     WHERE is_deleted = 0 AND kind = 'journal.entry') AS journal,
  (SELECT COUNT(*) FROM tracker_records
     WHERE is_deleted = 0 AND kind = 'dict.term') AS terms,
  (SELECT COUNT(*) FROM habit_completions WHERE is_deleted = 0) AS habits,
  (SELECT COUNT(*) FROM notes WHERE is_deleted = 0) AS notes,
  (SELECT COUNT(*) FROM poll_votes WHERE is_deleted = 0) AS votes,
  (SELECT COUNT(*) FROM contacts WHERE is_deleted = 0) AS contacts,
  (SELECT COUNT(*) FROM cycle_entries WHERE is_deleted = 0) AS cycle,
  (SELECT COUNT(*) FROM location_sessions WHERE is_deleted = 0) AS places,
  (SELECT COUNT(*) FROM tracker_records
     WHERE is_deleted = 0 AND kind = 'games.result') AS games,
  (SELECT COUNT(*) FROM tracker_records
     WHERE is_deleted = 0 AND kind IN ('cozy.post', 'cozy.letter', 'cozy.listItem', 'cozy.gift', 'cozy.doodle', 'cozy.plant')) AS cozy
''';

const _daysSql = '''
SELECT 'mood' AS src, date(recorded_at, 'unixepoch', 'localtime') AS d
  FROM mood_entries WHERE is_deleted = 0
UNION
SELECT 'journal', date(COALESCE(occurred_at, created_at), 'unixepoch', 'localtime')
  FROM tracker_records WHERE is_deleted = 0 AND kind = 'journal.entry'
UNION
SELECT 'front', date(start_time, 'unixepoch', 'localtime')
  FROM fronting_sessions WHERE is_deleted = 0
UNION
SELECT 'habit', date(completed_at, 'unixepoch', 'localtime')
  FROM habit_completions WHERE is_deleted = 0
''';

/// Reads every metric with two queries; re-runs when any source table
/// changes.
Stream<Map<AchievementMetric, int>> watchAchievementMetrics(AppDatabase db) {
  final tables = <ResultSetImplementation<dynamic, dynamic>>{
    db.members,
    db.frontingSessions,
    db.sleepSessions,
    db.moodEntries,
    db.trackerRecords,
    db.habitCompletions,
    db.notes,
    db.pollVotes,
    db.contacts,
    db.cycleEntries,
    db.locationSessions,
  };
  return db.customSelect(_countsSql, readsFrom: tables).watchSingle().asyncMap((
    row,
  ) async {
    final days = await db.customSelect(_daysSql, readsFrom: tables).get();
    final bySrc = <String, List<String>>{};
    final all = <String>{};
    for (final r in days) {
      final d = r.read<String?>('d');
      if (d == null) continue;
      (bySrc[r.read<String>('src')] ??= []).add(d);
      all.add(d);
    }
    int n(String c) => row.read<int?>(c) ?? 0;
    return {
      AchievementMetric.members: n('members'),
      AchievementMetric.frontSessions: n('front_sessions'),
      AchievementMetric.frontHours: n('front_hours'),
      AchievementMetric.sleepNights: n('sleep_nights'),
      AchievementMetric.moodCheckIns: n('mood'),
      AchievementMetric.moodStreak: longestDayStreak(bySrc['mood'] ?? const []),
      AchievementMetric.journalEntries: n('journal'),
      AchievementMetric.journalStreak: longestDayStreak(
        bySrc['journal'] ?? const [],
      ),
      AchievementMetric.dictionaryTerms: n('terms'),
      AchievementMetric.habitCompletions: n('habits'),
      AchievementMetric.notes: n('notes'),
      AchievementMetric.pollVotes: n('votes'),
      AchievementMetric.contacts: n('contacts'),
      AchievementMetric.cycleDays: n('cycle'),
      AchievementMetric.placesVisited: n('places'),
      AchievementMetric.gamesPlayed: n('games'),
      AchievementMetric.cozyMoments: n('cozy'),
      AchievementMetric.activeDays: all.length,
    };
  });
}

final achievementMetricsProvider = StreamProvider<Map<AchievementMetric, int>>(
  (ref) => watchAchievementMetrics(ref.watch(databaseProvider)),
);

/// Unlock time per achievement id, from synced unlock records.
final achievementUnlocksProvider = Provider<AsyncValue<Map<String, DateTime>>>(
  (ref) => ref
      .watch(trackerKindProvider(TrackerKind.achievementUnlock))
      .whenData((list) {
        final out = <String, DateTime>{};
        // Oldest first so the earliest unlock wins when two devices
        // recorded the same achievement.
        for (final r in list.reversed) {
          out.putIfAbsent(r.title, () => r.occurredAt ?? r.createdAt);
        }
        return out;
      }),
);

final achievementProgressProvider =
    Provider<AsyncValue<List<AchievementProgress>>>((ref) {
      final metrics = ref.watch(achievementMetricsProvider);
      final unlocks = ref.watch(achievementUnlocksProvider);
      if (metrics.hasError) {
        return AsyncValue.error(metrics.error!, metrics.stackTrace!);
      }
      if (!metrics.hasValue || !unlocks.hasValue) return const AsyncLoading();
      return AsyncData(computeProgress(metrics.value!, unlocks.value!));
    });

/// Records newly reached achievements. Watch it where achievements should
/// be checked (Achievements screen, Home); returns the ids it unlocked in
/// this session so callers can celebrate them.
class AchievementRecorder extends Notifier<List<String>> {
  final _pending = <String>{};

  @override
  List<String> build() {
    ref.listen(achievementProgressProvider, (_, next) {
      final progress = next.value;
      if (progress != null) _record(newlyReached(progress));
    }, fireImmediately: true);
    return const [];
  }

  Future<void> _record(List<AchievementDef> defs) async {
    final fresh = [
      for (final d in defs)
        if (_pending.add(d.id)) d,
    ];
    if (fresh.isEmpty) return;
    final n = ref.read(trackerNotifierProvider.notifier);
    final now = DateTime.now();
    for (final d in fresh) {
      await n.create(
        kind: TrackerKind.achievementUnlock,
        title: d.id,
        occurredAt: now,
        fields: {'metric': d.metric.name, 'target': d.target},
      );
    }
    state = [...state, for (final d in fresh) d.id];
  }

  void clearCelebrations() => state = const [];
}

final achievementRecorderProvider =
    NotifierProvider<AchievementRecorder, List<String>>(
      AchievementRecorder.new,
    );

/// Convenience for tests and summaries.
List<TrackerRecord> unlockRecordsOf(List<TrackerRecord> all) => [
  for (final r in all)
    if (r.kind == TrackerKind.achievementUnlock) r,
];
