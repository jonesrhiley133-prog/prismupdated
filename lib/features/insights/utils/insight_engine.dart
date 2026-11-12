import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/location.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/domain/models/work.dart';
import 'package:prism_plurality/features/mood/data/emotion_library.dart';
import 'package:prism_plurality/features/work/utils/work_stats.dart';

/// Everything the insight engine looks at. All lists may be empty.
class InsightInputs {
  const InsightInputs({
    required this.moodEntries,
    required this.frontingSessions,
    required this.locationSessions,
    required this.workSessions,
  });

  final List<MoodEntry> moodEntries;

  /// Normal and sleep sessions overlapping the analysis window.
  final List<FrontingSession> frontingSessions;
  final List<LocationSession> locationSessions;
  final List<WorkSession> workSessions;
}

/// What happened on one day, from exact timestamps.
class DaySummary {
  const DaySummary({
    required this.day,
    required this.checkIns,
    required this.averageMood,
    required this.averageIntensity,
    required this.averageEnergy,
    required this.averageStress,
    required this.topEmotions,
    required this.bodySensations,
    required this.sleep,
    required this.sleepQuality,
    required this.frontSeconds,
    required this.coFrontSeconds,
    required this.switches,
    required this.locationSeconds,
    required this.workSeconds,
    required this.workEarnings,
  });

  final DateTime day;
  final int checkIns;
  final double? averageMood;
  final double? averageIntensity;
  final double? averageEnergy;
  final double? averageStress;

  /// Emotion keys, most frequent first.
  final List<String> topEmotions;

  /// Body-sensation values, most frequent first.
  final List<String> bodySensations;

  /// Sleep that ended on this day (last night), if logged.
  final Duration? sleep;
  final SleepQuality? sleepQuality;

  /// Member id → seconds fronting on this day.
  final Map<String, int> frontSeconds;

  /// Seconds where two or more members fronted at once.
  final int coFrontSeconds;

  /// Number of fronting sessions that started on this day.
  final int switches;

  /// Location id → seconds at that location on this day.
  final Map<String, int> locationSeconds;
  final int workSeconds;

  /// Currency code → estimated earnings (hundredths).
  final Map<String, int> workEarnings;

  bool get isEmpty =>
      checkIns == 0 &&
      sleep == null &&
      frontSeconds.isEmpty &&
      locationSeconds.isEmpty &&
      workSeconds == 0;
}

/// A possible pattern across recent days. Never a diagnosis.
sealed class InsightPattern {
  const InsightPattern();

  /// How many data points back this up (shown so people can judge it).
  int get support;
}

class SleepMoodPattern extends InsightPattern {
  const SleepMoodPattern({
    required this.longSleepMood,
    required this.shortSleepMood,
    required this.longDays,
    required this.shortDays,
  });
  final double longSleepMood;
  final double shortSleepMood;
  final int longDays;
  final int shortDays;
  @override
  int get support => longDays + shortDays;
}

class LocationMoodPattern extends InsightPattern {
  const LocationMoodPattern({
    required this.locationId,
    required this.moodThere,
    required this.moodElsewhere,
    required this.checkInsThere,
  });
  final String locationId;
  final double moodThere;
  final double moodElsewhere;
  final int checkInsThere;
  @override
  int get support => checkInsThere;
}

class MemberMoodPattern extends InsightPattern {
  const MemberMoodPattern({
    required this.memberId,
    required this.moodWhileFronting,
    required this.moodOtherwise,
    required this.checkIns,
  });
  final String memberId;
  final double moodWhileFronting;
  final double moodOtherwise;
  final int checkIns;
  @override
  int get support => checkIns;
}

class WorkMoodPattern extends InsightPattern {
  const WorkMoodPattern({
    required this.workDayMood,
    required this.offDayMood,
    required this.workDays,
    required this.offDays,
  });
  final double workDayMood;
  final double offDayMood;
  final int workDays;
  final int offDays;
  @override
  int get support => workDays + offDays;
}

class BodyEmotionPattern extends InsightPattern {
  const BodyEmotionPattern({
    required this.bodySensation,
    required this.emotionKey,
    required this.together,
  });
  final String bodySensation;
  final String emotionKey;
  final int together;
  @override
  int get support => together;
}

class StressTrendPattern extends InsightPattern {
  const StressTrendPattern({
    required this.recentStress,
    required this.earlierStress,
    required this.recentCheckIns,
    required this.earlierCheckIns,
  });
  final double recentStress;
  final double earlierStress;
  final int recentCheckIns;
  final int earlierCheckIns;
  bool get rising => recentStress > earlierStress;
  @override
  int get support => recentCheckIns + earlierCheckIns;
}

/// Gentle, optional suggestions. Rendered as friendly text in the UI.
enum InsightSuggestion {
  restBreak,
  groundingPause,
  gentleEvening,
  celebrateGoodMoment,
  checkInWithSystem,
  revisitComfortPlace,
  lightCheckIn,
  balanceWork,
}

class DailyInsight {
  const DailyInsight({
    required this.today,
    required this.patterns,
    required this.suggestions,
    required this.daysWithData,
  });

  final DaySummary today;
  final List<InsightPattern> patterns;
  final List<InsightSuggestion> suggestions;

  /// Days in the look-back window that had any check-in.
  final int daysWithData;
}

/// Minimum data points per group before a pattern is shown.
const minPatternSupport = 3;

/// Minimum mood difference (1–5 scale) worth mentioning.
const minMoodDifference = 0.5;

DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);

double? _avg(Iterable<num?> values) {
  var sum = 0.0;
  var n = 0;
  for (final v in values) {
    if (v == null) continue;
    sum += v;
    n++;
  }
  return n == 0 ? null : sum / n;
}

List<String> _ranked(Iterable<String> values) {
  final counts = <String, int>{};
  for (final v in values) {
    counts[v] = (counts[v] ?? 0) + 1;
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  return keys;
}

/// Seconds of [start, end) that fall inside [from, to).
int _overlapSeconds(DateTime start, DateTime end, DateTime from, DateTime to) {
  final s = start.isAfter(from) ? start : from;
  final e = end.isBefore(to) ? end : to;
  return e.isAfter(s) ? e.difference(s).inSeconds : 0;
}

/// Builds the insight for [day], looking back [lookBackDays] for patterns.
DailyInsight buildDailyInsight(
  InsightInputs input, {
  required DateTime day,
  required DateTime now,
  int lookBackDays = 30,
}) {
  final today = _summarizeDay(input, _d(day), now);
  final windowStart = DateTime(day.year, day.month, day.day - lookBackDays + 1);
  final windowEnd = DateTime(day.year, day.month, day.day + 1);
  final windowEntries = input.moodEntries
      .where(
        (e) =>
            !e.recordedAt.isBefore(windowStart) &&
            e.recordedAt.isBefore(windowEnd),
      )
      .toList();

  final patterns = <InsightPattern>[
    ?_sleepMood(input, windowEntries, windowStart, windowEnd),
    ?_workMood(input, windowEntries, windowStart, windowEnd, now),
    ..._locationMood(input, windowEntries, now),
    ..._memberMood(windowEntries),
    ?_bodyEmotion(windowEntries),
    ?_stressTrend(windowEntries, day),
  ]..sort((a, b) => b.support.compareTo(a.support));

  final daysWithData = windowEntries
      .map((e) => _d(e.recordedAt))
      .toSet()
      .length;

  return DailyInsight(
    today: today,
    patterns: patterns.take(5).toList(),
    suggestions: _suggest(today, patterns),
    daysWithData: daysWithData,
  );
}

DaySummary _summarizeDay(InsightInputs input, DateTime day, DateTime now) {
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  final entries = input.moodEntries
      .where((e) => _d(e.recordedAt) == day)
      .toList();

  // Last night's sleep: the longest sleep session that ended today.
  FrontingSession? sleep;
  for (final s in input.frontingSessions.where((s) => s.isSleep)) {
    final end = s.endTime;
    if (end == null || _d(end) != day) continue;
    if (sleep == null || s.duration > sleep.duration) sleep = s;
  }

  // Fronting: exact seconds per member, co-fronting where ≥2 overlap.
  final normal = input.frontingSessions.where(
    (s) => !s.isSleep && s.memberId != null,
  );
  final front = <String, int>{};
  final events = <(DateTime, int)>[];
  var switches = 0;
  for (final s in normal) {
    final end = s.endTime ?? now;
    final secs = _overlapSeconds(s.startTime, end, day, dayEnd);
    if (secs <= 0) continue;
    front[s.memberId!] = (front[s.memberId!] ?? 0) + secs;
    final a = s.startTime.isAfter(day) ? s.startTime : day;
    final b = end.isBefore(dayEnd) ? end : dayEnd;
    events.add((a, 1));
    events.add((b, -1));
    if (_d(s.startTime) == day) switches++;
  }
  events.sort((x, y) {
    final c = x.$1.compareTo(y.$1);
    return c != 0 ? c : x.$2.compareTo(y.$2); // ends before starts
  });
  var depth = 0;
  var coFront = 0;
  DateTime? last;
  for (final (t, delta) in events) {
    if (last != null && depth >= 2) coFront += t.difference(last).inSeconds;
    depth += delta;
    last = t;
  }

  final locations = <String, int>{};
  for (final s in input.locationSessions) {
    final secs = _overlapSeconds(s.startedAt, s.endedAt ?? now, day, dayEnd);
    if (secs > 0) {
      locations[s.locationId] = (locations[s.locationId] ?? 0) + secs;
    }
  }

  var workSeconds = 0;
  final earnings = <String, int>{};
  for (final s in input.workSessions) {
    for (final slice in sliceWorkSessionByDay(s, now)) {
      if (slice.day != day) continue;
      workSeconds += slice.seconds;
      earnings[s.currencyCode] =
          (earnings[s.currencyCode] ?? 0) +
          estimateEarningsCents(slice.seconds, s.hourlyRateCents);
    }
  }

  return DaySummary(
    day: day,
    checkIns: entries.length,
    averageMood: _avg(entries.map((e) => e.mood)),
    averageIntensity: _avg(entries.map((e) => e.intensity)),
    averageEnergy: _avg(entries.map((e) => e.energy)),
    averageStress: _avg(entries.map((e) => e.stress)),
    topEmotions: _ranked(
      entries.expand((e) => e.emotions).map((r) => parseEmotionEntry(r).$1),
    ),
    bodySensations: _ranked(entries.expand((e) => e.bodySensations)),
    sleep: sleep?.duration,
    sleepQuality: sleep?.quality,
    frontSeconds: front,
    coFrontSeconds: coFront,
    switches: switches,
    locationSeconds: locations,
    workSeconds: workSeconds,
    workEarnings: earnings,
  );
}

Map<DateTime, double> _dailyMood(List<MoodEntry> entries) {
  final byDay = <DateTime, List<int>>{};
  for (final e in entries) {
    byDay.putIfAbsent(_d(e.recordedAt), () => []).add(e.mood);
  }
  return {
    for (final e in byDay.entries)
      e.key: e.value.reduce((a, b) => a + b) / e.value.length,
  };
}

SleepMoodPattern? _sleepMood(
  InsightInputs input,
  List<MoodEntry> entries,
  DateTime from,
  DateTime to,
) {
  final mood = _dailyMood(entries);
  final sleepByDay = <DateTime, Duration>{};
  for (final s in input.frontingSessions.where((s) => s.isSleep)) {
    final end = s.endTime;
    if (end == null || end.isBefore(from) || !end.isBefore(to)) continue;
    final d = _d(end);
    sleepByDay[d] = (sleepByDay[d] ?? Duration.zero) + s.duration;
  }
  final long = <double>[];
  final short = <double>[];
  for (final e in sleepByDay.entries) {
    final m = mood[e.key];
    if (m == null) continue;
    if (e.value >= const Duration(hours: 7)) long.add(m);
    if (e.value < const Duration(hours: 6)) short.add(m);
  }
  if (long.length < minPatternSupport || short.length < minPatternSupport) {
    return null;
  }
  final l = _avg(long)!;
  final s = _avg(short)!;
  if ((l - s).abs() < minMoodDifference) return null;
  return SleepMoodPattern(
    longSleepMood: l,
    shortSleepMood: s,
    longDays: long.length,
    shortDays: short.length,
  );
}

WorkMoodPattern? _workMood(
  InsightInputs input,
  List<MoodEntry> entries,
  DateTime from,
  DateTime to,
  DateTime now,
) {
  if (input.workSessions.isEmpty) return null;
  final mood = _dailyMood(entries);
  final workDays = <DateTime>{
    for (final s in input.workSessions)
      for (final slice in sliceWorkSessionByDay(s, now))
        if (slice.seconds > 0) slice.day,
  };
  final on = <double>[];
  final off = <double>[];
  for (final e in mood.entries) {
    (workDays.contains(e.key) ? on : off).add(e.value);
  }
  if (on.length < minPatternSupport || off.length < minPatternSupport) {
    return null;
  }
  final a = _avg(on)!;
  final b = _avg(off)!;
  if ((a - b).abs() < minMoodDifference) return null;
  return WorkMoodPattern(
    workDayMood: a,
    offDayMood: b,
    workDays: on.length,
    offDays: off.length,
  );
}

List<LocationMoodPattern> _locationMood(
  InsightInputs input,
  List<MoodEntry> entries,
  DateTime now,
) {
  if (entries.length < minPatternSupport * 2) return const [];
  final at = <String, List<int>>{};
  final elsewhere = <String, List<int>>{};
  final locationIds = input.locationSessions.map((s) => s.locationId).toSet();
  for (final e in entries) {
    final here = <String>{
      for (final s in input.locationSessions)
        if (!e.recordedAt.isBefore(s.startedAt) &&
            e.recordedAt.isBefore(s.endedAt ?? now))
          s.locationId,
    };
    for (final id in locationIds) {
      (here.contains(id) ? at : elsewhere)
          .putIfAbsent(id, () => [])
          .add(e.mood);
    }
  }
  final out = <LocationMoodPattern>[];
  for (final id in locationIds) {
    final a = at[id] ?? const [];
    final b = elsewhere[id] ?? const [];
    if (a.length < minPatternSupport || b.length < minPatternSupport) continue;
    final ma = _avg(a)!;
    final mb = _avg(b)!;
    if ((ma - mb).abs() < minMoodDifference) continue;
    out.add(
      LocationMoodPattern(
        locationId: id,
        moodThere: ma,
        moodElsewhere: mb,
        checkInsThere: a.length,
      ),
    );
  }
  return out;
}

List<MemberMoodPattern> _memberMood(List<MoodEntry> entries) {
  final byMember = <String, List<int>>{};
  for (final e in entries) {
    if (e.memberId != null) {
      byMember.putIfAbsent(e.memberId!, () => []).add(e.mood);
    }
  }
  final out = <MemberMoodPattern>[];
  for (final m in byMember.entries) {
    final others = [
      for (final e in entries)
        if (e.memberId != m.key) e.mood,
    ];
    if (m.value.length < minPatternSupport ||
        others.length < minPatternSupport) {
      continue;
    }
    final a = _avg(m.value)!;
    final b = _avg(others)!;
    if ((a - b).abs() < minMoodDifference) continue;
    out.add(
      MemberMoodPattern(
        memberId: m.key,
        moodWhileFronting: a,
        moodOtherwise: b,
        checkIns: m.value.length,
      ),
    );
  }
  return out;
}

BodyEmotionPattern? _bodyEmotion(List<MoodEntry> entries) {
  final pairs = <(String, String), int>{};
  for (final e in entries) {
    for (final b in e.bodySensations.toSet()) {
      for (final raw in e.emotions) {
        final key = (b, parseEmotionEntry(raw).$1);
        pairs[key] = (pairs[key] ?? 0) + 1;
      }
    }
  }
  if (pairs.isEmpty) return null;
  final best = pairs.entries.reduce((a, b) => b.value > a.value ? b : a);
  if (best.value < minPatternSupport) return null;
  return BodyEmotionPattern(
    bodySensation: best.key.$1,
    emotionKey: best.key.$2,
    together: best.value,
  );
}

StressTrendPattern? _stressTrend(List<MoodEntry> entries, DateTime day) {
  final recentStart = DateTime(day.year, day.month, day.day - 2);
  final recent = <int>[];
  final earlier = <int>[];
  for (final e in entries) {
    final s = e.stress;
    if (s == null) continue;
    (e.recordedAt.isBefore(recentStart) ? earlier : recent).add(s);
  }
  if (recent.length < minPatternSupport || earlier.length < minPatternSupport) {
    return null;
  }
  final r = _avg(recent)!;
  final ea = _avg(earlier)!;
  if ((r - ea).abs() < 0.75) return null;
  return StressTrendPattern(
    recentStress: r,
    earlierStress: ea,
    recentCheckIns: recent.length,
    earlierCheckIns: earlier.length,
  );
}

List<InsightSuggestion> _suggest(DaySummary t, List<InsightPattern> patterns) {
  final out = <InsightSuggestion>[];
  if ((t.averageStress ?? 0) >= 4 ||
      patterns.any((p) => p is StressTrendPattern && p.rising)) {
    out.add(InsightSuggestion.restBreak);
  }
  final tense = t.bodySensations.any(
    (b) => const ['tense', 'tight', 'shaky', 'pain', 'aching'].any(b.endsWith),
  );
  if (tense ||
      t.topEmotions.any(
        (k) => const [
          'anxious',
          'overwhelmed',
          'panicked',
          'dissociated',
          'flooded',
        ].contains(k),
      )) {
    out.add(InsightSuggestion.groundingPause);
  }
  if (t.sleep != null && t.sleep! < const Duration(hours: 6)) {
    out.add(InsightSuggestion.gentleEvening);
  }
  if ((t.averageMood ?? 0) >= 4) out.add(InsightSuggestion.celebrateGoodMoment);
  if (t.switches >= 4 || t.coFrontSeconds >= 3600) {
    out.add(InsightSuggestion.checkInWithSystem);
  }
  if (patterns.any(
    (p) => p is LocationMoodPattern && p.moodThere > p.moodElsewhere,
  )) {
    out.add(InsightSuggestion.revisitComfortPlace);
  }
  if (t.workSeconds >= 9 * 3600) out.add(InsightSuggestion.balanceWork);
  if (t.checkIns == 0) out.add(InsightSuggestion.lightCheckIn);
  return out.take(4).toList();
}
