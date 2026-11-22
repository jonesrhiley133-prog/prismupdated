import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/core/sync/prism_sync_providers.dart';
import 'package:prism_plurality/features/achievements/providers/achievement_providers.dart';
import 'package:prism_plurality/features/achievements/utils/achievements.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/whats_new/changelog.dart';

void main() {
  test('ids are unique and ladders ascend', () {
    final ids = allAchievements.map((a) => a.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final m in AchievementMetric.values) {
      final t = [
        for (final a in allAchievements)
          if (a.metric == m) a.target,
      ];
      expect(t, isNotEmpty, reason: '$m has no achievements');
      expect([...t]..sort(), t);
    }
  });

  test('longest streak handles gaps and duplicates', () {
    expect(
      longestDayStreak([
        '2026-01-01',
        '2026-01-02',
        '2026-01-02',
        '2026-01-04',
        '2026-01-05',
        '2026-01-06',
      ]),
      3,
    );
    expect(longestDayStreak(const []), 0);
    expect(longestDayStreak(['2025-12-31', '2026-01-01']), 2);
  });

  test('progress keeps earlier unlocks and reports new ones', () {
    final p = computeProgress(
      {AchievementMetric.members: 6},
      {'members.15': DateTime(2026)},
    );
    final members = p
        .where((x) => x.def.metric == AchievementMetric.members)
        .toList();
    expect(members.map((x) => x.unlocked), [true, true, true, false, false]);
    expect(newlyReached(p).map((d) => d.id), ['members.1', 'members.5']);
  });

  test(
    'metrics come from the database and unlocks are recorded once',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          prismSyncHandleProvider.overrideWithBuild((ref, notifier) => null),
        ],
      );
      addTearDown(c.dispose);
      final now = DateTime(2026, 3, 1, 12);
      await db
          .into(db.members)
          .insert(
            MembersCompanion.insert(id: 'm1', name: 'Ada', createdAt: now),
          );
      await db
          .into(db.frontingSessions)
          .insert(
            FrontingSessionsCompanion.insert(
              id: 'f1',
              startTime: now,
              endTime: Value(now.add(const Duration(hours: 12))),
              memberId: const Value('m1'),
            ),
          );
      for (var d = 0; d < 3; d++) {
        await db
            .into(db.moodEntries)
            .insert(
              MoodEntriesCompanion.insert(
                id: 'mo$d',
                mood: const Value(3),
                recordedAt: now.add(Duration(days: d)),
                createdAt: now,
                modifiedAt: now,
              ),
            );
      }
      await c
          .read(trackerNotifierProvider.notifier)
          .create(kind: TrackerKind.journalEntry, title: 'x', occurredAt: now);
      final sub = c.listen(achievementMetricsProvider, (_, _) {});
      addTearDown(sub.close);
      final m = await c.read(achievementMetricsProvider.future);
      expect(m[AchievementMetric.members], 1);
      expect(m[AchievementMetric.frontSessions], 1);
      expect(m[AchievementMetric.frontHours], 12);
      expect(m[AchievementMetric.moodCheckIns], 3);
      expect(m[AchievementMetric.moodStreak], 3);
      expect(m[AchievementMetric.journalEntries], 1);
      expect(m[AchievementMetric.activeDays], 3);

      final rec = c.listen(achievementRecorderProvider, (_, _) {});
      addTearDown(rec.close);
      final unlocksSub = c.listen(
        trackerKindProvider(TrackerKind.achievementUnlock),
        (_, _) {},
      );
      addTearDown(unlocksSub.close);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final unlocks = (await c.read(trackerRecordsProvider.future))
          .where((r) => r.kind == TrackerKind.achievementUnlock)
          .map((r) => r.title)
          .toList();
      expect(
        unlocks,
        containsAll([
          'members.1',
          'frontSessions.1',
          'frontHours.10',
          'moodCheckIns.1',
          'moodStreak.3',
          'journalEntries.1',
          'activeDays.1',
        ]),
      );
      expect(unlocks.toSet(), hasLength(unlocks.length));
    },
  );

  test('changelog is newest first and covers the app version', () {
    final dates = prismChangelog.map((r) => r.date).toList();
    expect([...dates]..sort((a, b) => b.compareTo(a)), dates);
    expect(releaseFor('0.16.0'), isNotNull);
    expect(releaseFor('0.17.0'), isNotNull);
    expect(releaseFor('0.18.0'), isNotNull);
    expect(releaseFor('0.19.0'), isNotNull);
    expect(releaseFor('0.20.0'), isNotNull);
    expect(releaseFor('0.21.0'), isNotNull);
    expect(releaseFor('0.22.0'), isNotNull);
    expect(releaseFor('0.23.0'), isNotNull);
    expect(releaseFor('0.23.1'), isNotNull);
    expect(releaseFor('0.24.0'), isNotNull);
    expect(releaseFor('0.25.0'), isNotNull);
    expect(releaseFor('0.25.1'), isNotNull);
    expect(releaseFor('0.26.0'), isNotNull);
    expect(releaseFor('0.27.0'), isNotNull);
    expect(releaseFor('0.27.1'), isNotNull);
    expect(releaseFor('0.28.0'), isNotNull);
    expect(releaseFor('0.29.0'), isNotNull);
    expect(releaseFor('0.30.0'), isNotNull);
    expect(releaseFor('0.31.0'), isNotNull);
    expect(releaseFor('0.32.0'), isNotNull);
    expect(releaseFor('0.33.0'), isNotNull);
    expect(releaseFor('0.34.0'), isNotNull);
    expect(releaseFor('0.35.0'), isNotNull);
    expect(releaseFor('0.36.0'), isNotNull);
    expect(releaseFor('0.37.0'), isNotNull);
    expect(releaseFor('0.38.0'), isNotNull);
    expect(releaseFor('0.38.1'), isNotNull);
    expect(releaseFor('0.39.0'), isNotNull);
    expect(releaseFor('0.39.2'), isNotNull);
    expect(releaseFor('0.39.3'), isNotNull);
    expect(releaseFor('9.9.9'), isNull);
  });
}
