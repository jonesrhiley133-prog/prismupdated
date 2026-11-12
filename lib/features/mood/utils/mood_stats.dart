import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/mood/data/emotion_library.dart';

/// Calendar-day key for grouping (local time).
DateTime moodDayKey(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Groups entries by local calendar day, newest day first. Entries within a
/// day keep their incoming order.
Map<DateTime, List<MoodEntry>> groupMoodEntriesByDay(
  Iterable<MoodEntry> entries,
) {
  final out = <DateTime, List<MoodEntry>>{};
  for (final e in entries) {
    out.putIfAbsent(moodDayKey(e.recordedAt), () => []).add(e);
  }
  final keys = out.keys.toList()..sort((a, b) => b.compareTo(a));
  return {for (final k in keys) k: out[k]!};
}

/// Average mood per local day.
Map<DateTime, double> dailyAverageMood(Iterable<MoodEntry> entries) {
  final sums = <DateTime, (int, int)>{};
  for (final e in entries) {
    final k = moodDayKey(e.recordedAt);
    final (s, n) = sums[k] ?? (0, 0);
    sums[k] = (s + e.mood, n + 1);
  }
  return {for (final e in sums.entries) e.key: e.value.$1 / e.value.$2};
}

/// Summary statistics over a set of entries.
class MoodSummary {
  const MoodSummary({
    required this.count,
    required this.averageMood,
    required this.averageIntensity,
    required this.averageEnergy,
    required this.averageStress,
    required this.averageSleepQuality,
    required this.topEmotions,
    required this.topBodySensations,
    required this.moodDistribution,
    required this.averageMoodByMember,
    required this.averageMoodByTimeOfDay,
    required this.daysLogged,
    required this.currentStreak,
  });

  final int count;
  final double? averageMood;
  final double? averageIntensity;
  final double? averageEnergy;
  final double? averageStress;
  final double? averageSleepQuality;

  /// Emotion key → count, most frequent first.
  final List<MapEntry<String, int>> topEmotions;

  /// Body sensation value → count, most frequent first.
  final List<MapEntry<String, int>> topBodySensations;

  /// Mood level (1–5) → count.
  final Map<int, int> moodDistribution;

  /// Member id (null key = unassigned) → average mood.
  final Map<String?, double> averageMoodByMember;

  /// Time bucket (`morning`, `afternoon`, `evening`, `night`) → avg mood.
  final Map<String, double> averageMoodByTimeOfDay;

  /// Distinct days with at least one check-in.
  final int daysLogged;

  /// Consecutive days up to and including [now]'s day (or yesterday, if
  /// today has no check-in yet) with at least one check-in.
  final int currentStreak;

  static MoodSummary of(Iterable<MoodEntry> input, {DateTime? now}) {
    final entries = input.toList();
    double? avg(Iterable<int?> values) {
      var sum = 0;
      var n = 0;
      for (final v in values) {
        if (v == null) continue;
        sum += v;
        n++;
      }
      return n == 0 ? null : sum / n;
    }

    List<MapEntry<String, int>> ranked(Iterable<String> values) {
      final counts = <String, int>{};
      for (final v in values) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
      final list = counts.entries.toList()
        ..sort((a, b) {
          final c = b.value.compareTo(a.value);
          return c != 0 ? c : a.key.compareTo(b.key);
        });
      return list;
    }

    final distribution = {for (var i = 1; i <= 5; i++) i: 0};
    for (final e in entries) {
      distribution[e.mood] = (distribution[e.mood] ?? 0) + 1;
    }

    final byMember = <String?, List<int>>{};
    final byBucket = <String, List<int>>{};
    for (final e in entries) {
      byMember.putIfAbsent(e.memberId, () => []).add(e.mood);
      byBucket.putIfAbsent(timeBucketOf(e.recordedAt), () => []).add(e.mood);
    }
    double mean(List<int> l) => l.reduce((a, b) => a + b) / l.length;

    final days = entries.map((e) => moodDayKey(e.recordedAt)).toSet();

    return MoodSummary(
      count: entries.length,
      averageMood: avg(entries.map((e) => e.mood)),
      averageIntensity: avg(entries.map((e) => e.intensity)),
      averageEnergy: avg(entries.map((e) => e.energy)),
      averageStress: avg(entries.map((e) => e.stress)),
      averageSleepQuality: avg(entries.map((e) => e.sleepQuality)),
      topEmotions: ranked(
        entries.expand((e) => e.emotions).map((r) => parseEmotionEntry(r).$1),
      ),
      topBodySensations: ranked(entries.expand((e) => e.bodySensations)),
      moodDistribution: distribution,
      averageMoodByMember: {
        for (final e in byMember.entries) e.key: mean(e.value),
      },
      averageMoodByTimeOfDay: {
        for (final e in byBucket.entries) e.key: mean(e.value),
      },
      daysLogged: days.length,
      currentStreak: _streak(days, now ?? DateTime.now()),
    );
  }

  static int _streak(Set<DateTime> days, DateTime now) {
    var day = moodDayKey(now);
    if (!days.contains(day)) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }
}

/// `morning` 05–12, `afternoon` 12–17, `evening` 17–22, `night` otherwise.
String timeBucketOf(DateTime t) {
  final h = t.toLocal().hour;
  if (h >= 5 && h < 12) return 'morning';
  if (h >= 12 && h < 17) return 'afternoon';
  if (h >= 17 && h < 22) return 'evening';
  return 'night';
}

/// Entries recorded on or after the start of the day [days] - 1 days ago.
List<MoodEntry> moodEntriesInLastDays(
  Iterable<MoodEntry> entries,
  int days, {
  DateTime? now,
}) {
  final today = moodDayKey(now ?? DateTime.now());
  final start = DateTime(today.year, today.month, today.day - (days - 1));
  return entries.where((e) => !e.recordedAt.isBefore(start)).toList();
}
