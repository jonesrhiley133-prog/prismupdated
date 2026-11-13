import 'package:prism_plurality/domain/models/fronting_session.dart';

/// How trustworthy a co-fronting period's records are.
enum CoCertainty { confirmed, uncertain, incomplete }

/// A stretch of time when the same set of 2+ alters were recorded fronting.
class CoFrontPeriod {
  CoFrontPeriod(this.members, this.start, this.end, this.certainty, {this.ongoing = false});
  final Set<String> members;
  final DateTime start;
  DateTime end;
  final CoCertainty certainty;
  final bool ongoing;
  Duration get duration => end.difference(start);
  String get key => (members.toList()..sort()).join('+');
}

class CoFrontStats {
  CoFrontStats({
    required this.periods,
    required this.total,
    required this.byCombination,
    required this.byMember,
    required this.pairs,
    required this.byMonth,
    required this.byDay,
    required this.certaintyTotals,
  });

  final List<CoFrontPeriod> periods;
  final Duration total;

  /// combination key → (count, total)
  final Map<String, (int, Duration)> byCombination;
  final Map<String, (int, Duration)> byMember;

  /// "a|b" (sorted) → total time together
  final Map<String, Duration> pairs;
  final Map<DateTime, Duration> byMonth;
  final Map<DateTime, Duration> byDay;
  final Map<CoCertainty, Duration> certaintyTotals;

  Duration get average => periods.isEmpty ? Duration.zero : Duration(seconds: total.inSeconds ~/ periods.length);
}

/// Finds co-fronting periods with a sweep over session start/end points.
///
/// Only regular fronting sessions count (sleep is excluded). A period is
/// "uncertain" when any contributing session is marked unsure, and
/// "incomplete" when one has no end and started more than a day ago (likely
/// a forgotten switch). Periods shorter than [minDuration] are ignored.
List<CoFrontPeriod> findCoFronting(
  List<FrontingSession> sessions, {
  required DateTime from,
  required DateTime to,
  DateTime? now,
  Duration minDuration = const Duration(minutes: 1),
}) {
  final n = now ?? DateTime.now();
  final events = <(DateTime, int, FrontingSession)>[];
  for (final s in sessions) {
    if (s.isDeleted || s.sessionType != SessionType.normal || s.memberId == null) continue;
    var start = s.startTime;
    var end = s.endTime ?? n;
    if (end.isAfter(to)) end = to;
    if (start.isBefore(from)) start = from;
    if (!end.isAfter(start)) continue;
    events
      ..add((start, 1, s))
      ..add((end, -1, s));
  }
  events.sort((a, b) {
    final c = a.$1.compareTo(b.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2); // ends before starts at the same instant
  });
  final active = <String, FrontingSession>{};
  final out = <CoFrontPeriod>[];
  DateTime? segStart;
  for (final (t, kind, s) in events) {
    if (segStart != null && active.length >= 2 && t.isAfter(segStart)) {
      final members = {for (final x in active.values) x.memberId!};
      final unsure = active.values.any((x) => x.confidence == FrontConfidence.unsure);
      final stale = active.values.any((x) => x.endTime == null && n.difference(x.startTime) > const Duration(hours: 24));
      final ongoing = active.values.any((x) => x.endTime == null) && !stale && !t.isBefore(to.subtract(const Duration(minutes: 1)));
      final certainty = stale ? CoCertainty.incomplete : (unsure ? CoCertainty.uncertain : CoCertainty.confirmed);
      final last = out.isEmpty ? null : out.last;
      if (last != null && last.end == segStart && last.key == ((members.toList()..sort()).join('+')) && last.certainty == certainty) {
        last.end = t;
      } else {
        out.add(CoFrontPeriod(members, segStart, t, certainty, ongoing: ongoing));
      }
    }
    if (kind == 1) {
      active[s.id] = s;
    } else {
      active.remove(s.id);
    }
    segStart = t;
  }
  return [for (final p in out) if (p.duration >= minDuration) p];
}

CoFrontStats summarize(List<CoFrontPeriod> periods) {
  var total = Duration.zero;
  final byCombo = <String, (int, Duration)>{};
  final byMember = <String, (int, Duration)>{};
  final pairs = <String, Duration>{};
  final byMonth = <DateTime, Duration>{};
  final byDay = <DateTime, Duration>{};
  final cert = <CoCertainty, Duration>{};
  for (final p in periods) {
    final d = p.duration;
    total += d;
    final c = byCombo[p.key];
    byCombo[p.key] = ((c?.$1 ?? 0) + 1, (c?.$2 ?? Duration.zero) + d);
    for (final m in p.members) {
      final x = byMember[m];
      byMember[m] = ((x?.$1 ?? 0) + 1, (x?.$2 ?? Duration.zero) + d);
    }
    final ms = p.members.toList()..sort();
    for (var i = 0; i < ms.length; i++) {
      for (var j = i + 1; j < ms.length; j++) {
        final k = '${ms[i]}|${ms[j]}';
        pairs[k] = (pairs[k] ?? Duration.zero) + d;
      }
    }
    final month = DateTime(p.start.year, p.start.month);
    byMonth[month] = (byMonth[month] ?? Duration.zero) + d;
    // Split across days for the calendar.
    var cur = p.start;
    while (cur.isBefore(p.end)) {
      final dayStart = DateTime(cur.year, cur.month, cur.day);
      final next = DateTime(cur.year, cur.month, cur.day + 1);
      final segEnd = p.end.isBefore(next) ? p.end : next;
      byDay[dayStart] = (byDay[dayStart] ?? Duration.zero) + segEnd.difference(cur);
      cur = segEnd;
    }
    cert[p.certainty] = (cert[p.certainty] ?? Duration.zero) + d;
  }
  return CoFrontStats(
    periods: periods,
    total: total,
    byCombination: byCombo,
    byMember: byMember,
    pairs: pairs,
    byMonth: byMonth,
    byDay: byDay,
    certaintyTotals: cert,
  );
}

String fmtDuration(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 48) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inDays}d ${d.inHours % 24}h';
}
