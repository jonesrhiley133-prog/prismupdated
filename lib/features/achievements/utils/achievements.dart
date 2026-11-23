import 'package:flutter/foundation.dart';

/// Numbers achievements are measured against. Collected by
/// `achievementMetricsProvider` straight from the database.
enum AchievementMetric {
  members,
  frontSessions,
  frontHours,
  sleepNights,
  moodCheckIns,
  moodStreak,
  journalEntries,
  journalStreak,
  dictionaryTerms,
  habitCompletions,
  notes,
  pollVotes,
  contacts,
  cycleDays,
  placesVisited,
  activeDays,
  gamesPlayed,
  cozyMoments,
}

enum AchievementCategory {
  system,
  fronting,
  wellbeing,
  journal,
  knowledge,
  habits,
  social,
  consistency,
}

enum AchievementTier { bronze, silver, gold, platinum, diamond }

@immutable
class AchievementDef {
  const AchievementDef({
    required this.metric,
    required this.target,
    required this.tier,
    required this.category,
  });

  final AchievementMetric metric;
  final int target;
  final AchievementTier tier;
  final AchievementCategory category;

  /// Stable id stored in unlock records: `<metric>.<target>`.
  String get id => '${metric.name}.$target';
}

const _tiers = AchievementTier.values;

List<AchievementDef> _ladder(
  AchievementMetric m,
  AchievementCategory c,
  List<int> targets,
) => [
  for (var i = 0; i < targets.length; i++)
    AchievementDef(metric: m, target: targets[i], tier: _tiers[i], category: c),
];

/// Every achievement, grouped in ladders of up to five tiers.
final List<AchievementDef> allAchievements = [
  ..._ladder(AchievementMetric.members, AchievementCategory.system, [
    1,
    5,
    15,
    40,
    100,
  ]),
  ..._ladder(AchievementMetric.frontSessions, AchievementCategory.fronting, [
    1,
    25,
    100,
    500,
    2000,
  ]),
  ..._ladder(AchievementMetric.frontHours, AchievementCategory.fronting, [
    10,
    100,
    500,
    2000,
    10000,
  ]),
  ..._ladder(AchievementMetric.sleepNights, AchievementCategory.wellbeing, [
    1,
    7,
    30,
    100,
    365,
  ]),
  ..._ladder(AchievementMetric.moodCheckIns, AchievementCategory.wellbeing, [
    1,
    10,
    50,
    200,
    1000,
  ]),
  ..._ladder(AchievementMetric.moodStreak, AchievementCategory.consistency, [
    3,
    7,
    14,
    30,
    100,
  ]),
  ..._ladder(AchievementMetric.journalEntries, AchievementCategory.journal, [
    1,
    10,
    50,
    150,
    500,
  ]),
  ..._ladder(AchievementMetric.journalStreak, AchievementCategory.consistency, [
    3,
    7,
    14,
    30,
    100,
  ]),
  ..._ladder(AchievementMetric.dictionaryTerms, AchievementCategory.knowledge, [
    1,
    10,
    50,
    150,
    500,
  ]),
  ..._ladder(AchievementMetric.habitCompletions, AchievementCategory.habits, [
    1,
    25,
    100,
    500,
    2000,
  ]),
  ..._ladder(AchievementMetric.notes, AchievementCategory.journal, [
    1,
    10,
    50,
    200,
  ]),
  ..._ladder(AchievementMetric.pollVotes, AchievementCategory.social, [
    1,
    10,
    50,
    200,
  ]),
  ..._ladder(AchievementMetric.contacts, AchievementCategory.social, [
    1,
    10,
    50,
  ]),
  ..._ladder(AchievementMetric.cycleDays, AchievementCategory.wellbeing, [
    1,
    30,
    180,
  ]),
  ..._ladder(AchievementMetric.placesVisited, AchievementCategory.wellbeing, [
    1,
    25,
    100,
  ]),
  ..._ladder(AchievementMetric.gamesPlayed, AchievementCategory.social, [
    1,
    10,
    50,
    200,
    1000,
  ]),
  ..._ladder(AchievementMetric.cozyMoments, AchievementCategory.social, [
    1,
    10,
    50,
    200,
  ]),
  ..._ladder(AchievementMetric.activeDays, AchievementCategory.consistency, [
    1,
    7,
    30,
    100,
    365,
  ]),
];

@immutable
class AchievementProgress {
  const AchievementProgress({
    required this.def,
    required this.current,
    this.unlockedAt,
  });

  final AchievementDef def;
  final int current;
  final DateTime? unlockedAt;

  bool get reached => current >= def.target;
  bool get unlocked => unlockedAt != null || reached;
  double get fraction =>
      def.target == 0 ? 1 : (current / def.target).clamp(0, 1).toDouble();
}

/// Progress for every achievement given [metrics] and the stored unlock
/// times keyed by achievement id. An unlock stays even if the metric later
/// drops (for example after deleting data).
List<AchievementProgress> computeProgress(
  Map<AchievementMetric, int> metrics,
  Map<String, DateTime> unlocked,
) => [
  for (final d in allAchievements)
    AchievementProgress(
      def: d,
      current: metrics[d.metric] ?? 0,
      unlockedAt: unlocked[d.id],
    ),
];

/// Achievements reached but not yet recorded.
List<AchievementDef> newlyReached(List<AchievementProgress> progress) => [
  for (final p in progress)
    if (p.reached && p.unlockedAt == null) p.def,
];

/// Longest run of consecutive calendar days in [days] (`yyyy-MM-dd`).
int longestDayStreak(Iterable<String> days) {
  final dates = <DateTime>[for (final d in days) ?DateTime.tryParse(d)]..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in dates) {
    if (prev != null && d == prev) continue;
    run = prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d
        ? run + 1
        : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}
