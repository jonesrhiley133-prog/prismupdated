import 'package:prism_plurality/domain/models/work.dart';

/// Worked seconds and estimated earnings (minor units) for one bucket.
class WorkTotals {
  const WorkTotals({this.seconds = 0, this.earningsCents = 0});

  final int seconds;
  final int earningsCents;

  WorkTotals operator +(WorkTotals o) => WorkTotals(
    seconds: seconds + o.seconds,
    earningsCents: earningsCents + o.earningsCents,
  );

  double get hours => seconds / 3600;
}

/// One session's slice of worked time on a single local calendar day.
class WorkSlice {
  const WorkSlice({
    required this.session,
    required this.day,
    required this.seconds,
  });

  final WorkSession session;
  final DateTime day;

  /// Paid seconds on [day] (breaks spread proportionally over the session).
  final int seconds;
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Splits [session] into per-day slices of paid seconds. Unpaid break time
/// is spread over the session in proportion to the time on each day, and
/// rounding leftovers go to the last slice so the slices always sum to
/// exactly [WorkSession.workedAt].
List<WorkSlice> sliceWorkSessionByDay(WorkSession session, DateTime now) {
  final start = session.startedAt;
  final end = session.endedAt ?? now;
  if (!end.isAfter(start)) return const [];
  final totalElapsed = end.difference(start).inSeconds;
  final totalWorked = session.workedAt(now).inSeconds;
  if (totalElapsed <= 0 || totalWorked <= 0) return const [];

  final raw = <(DateTime, int)>[];
  var cursor = start;
  while (cursor.isBefore(end)) {
    final d = _day(cursor);
    final next = DateTime(d.year, d.month, d.day + 1);
    final sliceEnd = next.isBefore(end) ? next : end;
    raw.add((d, sliceEnd.difference(cursor).inSeconds));
    cursor = sliceEnd;
  }

  final out = <WorkSlice>[];
  var assigned = 0;
  for (var i = 0; i < raw.length; i++) {
    final (day, elapsed) = raw[i];
    final seconds = i == raw.length - 1
        ? totalWorked - assigned
        : (elapsed * totalWorked) ~/ totalElapsed;
    assigned += seconds;
    out.add(WorkSlice(session: session, day: day, seconds: seconds));
  }
  return out;
}

/// Aggregated work statistics, all from exact seconds.
class WorkStats {
  WorkStats._(this.byDay, this.byJob, this.total);

  /// Local day → totals.
  final Map<DateTime, WorkTotals> byDay;

  /// Job id → totals.
  final Map<String, WorkTotals> byJob;
  final WorkTotals total;

  static WorkStats of(
    Iterable<WorkSession> sessions, {
    required DateTime now,
    DateTime? from,
    DateTime? to,
  }) {
    final byDay = <DateTime, WorkTotals>{};
    final byJob = <String, WorkTotals>{};
    var total = const WorkTotals();
    for (final s in sessions) {
      for (final slice in sliceWorkSessionByDay(s, now)) {
        if (from != null && slice.day.isBefore(_day(from))) continue;
        if (to != null && !slice.day.isBefore(_day(to))) continue;
        final t = WorkTotals(
          seconds: slice.seconds,
          earningsCents: estimateEarningsCents(
            slice.seconds,
            s.hourlyRateCents,
          ),
        );
        byDay[slice.day] = (byDay[slice.day] ?? const WorkTotals()) + t;
        byJob[s.jobId] = (byJob[s.jobId] ?? const WorkTotals()) + t;
        total = total + t;
      }
    }
    return WorkStats._(byDay, byJob, total);
  }

  /// Totals for the week containing [day]. [firstWeekday] uses
  /// DateTime.monday..sunday.
  WorkTotals weekOf(DateTime day, {int firstWeekday = DateTime.monday}) {
    final d = _day(day);
    final offset = (d.weekday - firstWeekday + 7) % 7;
    final start = DateTime(d.year, d.month, d.day - offset);
    var sum = const WorkTotals();
    for (var i = 0; i < 7; i++) {
      sum =
          sum +
          (byDay[DateTime(start.year, start.month, start.day + i)] ??
              const WorkTotals());
    }
    return sum;
  }

  WorkTotals monthOf(DateTime day) {
    var sum = const WorkTotals();
    for (final e in byDay.entries) {
      if (e.key.year == day.year && e.key.month == day.month) {
        sum = sum + e.value;
      }
    }
    return sum;
  }

  WorkTotals dayOf(DateTime day) => byDay[_day(day)] ?? const WorkTotals();
}
