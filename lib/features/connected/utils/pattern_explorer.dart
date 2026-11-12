import 'package:prism_plurality/domain/models/cycle_entry.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/location.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/domain/models/work.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';
import 'package:prism_plurality/features/mood/data/body_map.dart';
import 'package:prism_plurality/features/mood/data/emotion_library.dart';
import 'package:prism_plurality/features/work/utils/work_stats.dart';

/// What the Pattern Explorer compares.
enum PatternComparison {
  emotionSleep,
  emotionFronting,
  emotionLocation,
  emotionCycle,
  bodyEmotion,
  workMood,
}

/// Groups that only need a label key from the UI (members, locations and
/// jobs are ids; the rest are fixed keys like `sleep_lt6`).
class PatternGroup {
  const PatternGroup({
    required this.key,
    required this.checkIns,
    required this.averageMood,
    required this.topEmotions,
  });

  final String key;
  final int checkIns;
  final double? averageMood;

  /// (emotion key, count), most frequent first, up to 5.
  final List<(String, int)> topEmotions;
}

class PatternExplorerInputs {
  const PatternExplorerInputs({
    required this.moods,
    required this.fronting,
    required this.locations,
    required this.work,
    required this.cycle,
  });

  final List<MoodEntry> moods;
  final List<FrontingSession> fronting;
  final List<LocationSession> locations;
  final List<WorkSession> work;
  final List<CycleEntry> cycle;
}

DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);

PatternGroup _group(String key, List<MoodEntry> entries) {
  final counts = <String, int>{};
  for (final e in entries) {
    for (final raw in e.emotions) {
      final k = parseEmotionEntry(raw).$1;
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  final top = counts.entries.toList()
    ..sort(
      (a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key),
    );
  return PatternGroup(
    key: key,
    checkIns: entries.length,
    averageMood: entries.isEmpty
        ? null
        : entries.map((e) => e.mood).reduce((a, b) => a + b) / entries.length,
    topEmotions: [for (final e in top.take(5)) (e.key, e.value)],
  );
}

/// Runs [comparison] over check-ins recorded in [from, to). Groups with no
/// check-ins are dropped. These are descriptive groupings only.
List<PatternGroup> explorePattern(
  PatternComparison comparison,
  PatternExplorerInputs input, {
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final moods = input.moods
      .where((m) => !m.recordedAt.isBefore(from) && m.recordedAt.isBefore(to))
      .toList();
  final groups = <String, List<MoodEntry>>{};
  void add(String key, MoodEntry e) => groups.putIfAbsent(key, () => []).add(e);

  switch (comparison) {
    case PatternComparison.emotionSleep:
      final sleepByDay = <DateTime, Duration>{};
      for (final s in input.fronting.where(
        (s) => s.isSleep && s.endTime != null,
      )) {
        final d = _d(s.endTime!);
        sleepByDay[d] = (sleepByDay[d] ?? Duration.zero) + s.duration;
      }
      for (final m in moods) {
        final sleep = sleepByDay[_d(m.recordedAt)];
        if (sleep == null) {
          add('sleep_unknown', m);
        } else if (sleep.inMinutes < 360) {
          add('sleep_lt6', m);
        } else if (sleep.inMinutes < 420) {
          add('sleep_6_7', m);
        } else if (sleep.inMinutes < 480) {
          add('sleep_7_8', m);
        } else {
          add('sleep_8plus', m);
        }
      }
    case PatternComparison.emotionFronting:
      final normal = input.fronting
          .where((s) => !s.isSleep && s.memberId != null)
          .toList();
      for (final m in moods) {
        final fronters = {
          for (final s in normal)
            if (!m.recordedAt.isBefore(s.startTime) &&
                m.recordedAt.isBefore(s.endTime ?? now))
              s.memberId!,
        };
        if (fronters.isEmpty) add('front_none', m);
        if (fronters.length > 1) add('front_cofront', m);
        for (final id in fronters) {
          add('member:$id', m);
        }
      }
    case PatternComparison.emotionLocation:
      for (final m in moods) {
        final here = {
          for (final s in input.locations)
            if (!m.recordedAt.isBefore(s.startedAt) &&
                m.recordedAt.isBefore(s.endedAt ?? now))
              s.locationId,
        };
        if (here.isEmpty) add('location_none', m);
        for (final id in here) {
          add('location:$id', m);
        }
      }
    case PatternComparison.emotionCycle:
      final stats = CycleStats.of(input.cycle, today: now);
      final periodDays = {
        for (final c in input.cycle.where((c) => c.isPeriodDay)) c.date,
      };
      for (final m in moods) {
        final d = _d(m.recordedAt);
        if (periodDays.contains(CycleStats.dateKey(d))) {
          add('cycle_period', m);
          continue;
        }
        final start = stats.periodStarts.where((s) => !s.isAfter(d)).lastOrNull;
        if (start == null) {
          add('cycle_unknown', m);
          continue;
        }
        final day =
            DateTime.utc(d.year, d.month, d.day)
                .difference(DateTime.utc(start.year, start.month, start.day))
                .inDays +
            1;
        if (day > 60) {
          add('cycle_unknown', m);
        } else if (day <= 13) {
          add('cycle_6_13', m);
        } else if (day <= 20) {
          add('cycle_14_20', m);
        } else {
          add('cycle_21plus', m);
        }
      }
    case PatternComparison.bodyEmotion:
      for (final m in moods) {
        final regions = m.bodySensations
            .map((b) => parseBodySensation(b).$1)
            .toSet();
        if (regions.isEmpty) add('body_none', m);
        for (final r in regions) {
          add('body:$r', m);
        }
      }
    case PatternComparison.workMood:
      final workDays = <DateTime, Set<String>>{};
      for (final s in input.work) {
        for (final slice in sliceWorkSessionByDay(s, now)) {
          if (slice.seconds > 0) {
            workDays.putIfAbsent(slice.day, () => {}).add(s.jobId);
          }
        }
      }
      for (final m in moods) {
        final jobs = workDays[_d(m.recordedAt)];
        if (jobs == null) {
          add('work_off', m);
        } else {
          add('work_on', m);
          for (final j in jobs) {
            add('job:$j', m);
          }
        }
      }
  }
  final out = [for (final e in groups.entries) _group(e.key, e.value)];
  out.sort((a, b) => b.checkIns.compareTo(a.checkIns));
  return out;
}
