import 'package:prism_plurality/domain/models/calendar_event.dart';

/// One concrete occurrence of a (possibly recurring) calendar event.
class CalendarOccurrence {
  const CalendarOccurrence({
    required this.event,
    required this.start,
    required this.end,
  });

  final CalendarEvent event;

  /// Start of this occurrence. Local midnight for all-day events.
  final DateTime start;

  /// End of this occurrence. For all-day events this is the local midnight
  /// of the last covered day (inclusive), mirroring [CalendarEvent.endAt].
  final DateTime end;

  bool get isAllDay => event.isAllDay;

  /// Exclusive end instant used for overlap maths.
  DateTime get endExclusive => isAllDay
      ? DateTime(end.year, end.month, end.day + 1)
      : (end.isAfter(start) ? end : start.add(const Duration(minutes: 1)));

  /// `yyyy-MM-dd` of [start]; the key stored in
  /// [CalendarEvent.recurrenceExceptions] to remove this occurrence.
  String get occurrenceKey => calendarDateKey(start);

  /// Whether this occurrence touches the local calendar day [day].
  bool coversDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    return start.isBefore(dayEnd) && endExclusive.isAfter(dayStart);
  }

  /// Spans more than one calendar day (or is all-day): shown in the all-day
  /// lane of week/day views rather than the hour grid.
  bool get isMultiDay =>
      isAllDay ||
      calendarDateKey(start) !=
          calendarDateKey(endExclusive.subtract(const Duration(minutes: 1)));

  @override
  bool operator ==(Object other) =>
      other is CalendarOccurrence &&
      other.event.id == event.id &&
      other.start == start;

  @override
  int get hashCode => Object.hash(event.id, start);
}

String calendarDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Safety valve so a malformed rule can never spin forever.
const _maxIterations = 50000;

/// Expands [event] into the occurrences overlapping `[rangeStart, rangeEnd)`.
///
/// Rules follow RFC 5545 semantics where they matter:
/// * `recurrenceCount` counts occurrences from the series start, and removed
///   occurrences ([CalendarEvent.recurrenceExceptions]) still count.
/// * Monthly rules on the 29th–31st skip months without that day; yearly
///   rules on Feb 29 only occur in leap years.
/// * Weekly rules with no weekdays use the weekday of the first occurrence.
List<CalendarOccurrence> expandCalendarEvent(
  CalendarEvent event,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final out = <CalendarOccurrence>[];
  final duration = event.isAllDay
      ? Duration(days: _daysBetween(event.startAt, event.endAt))
      : event.duration;
  final exceptions = event.recurrenceExceptions.toSet();
  final until = event.recurrenceUntil == null
      ? null
      : DateTime(
          event.recurrenceUntil!.year,
          event.recurrenceUntil!.month,
          event.recurrenceUntil!.day + 1,
        );
  final count = event.recurrenceCount;

  CalendarOccurrence occurrenceAt(DateTime start) => CalendarOccurrence(
    event: event,
    start: start,
    end: event.isAllDay
        ? DateTime(start.year, start.month, start.day + duration.inDays)
        : start.add(duration),
  );

  var produced = 0;
  // Returns false when expansion should stop.
  bool consider(DateTime start) {
    if (!start.isBefore(rangeEnd)) return false;
    if (until != null && !start.isBefore(until)) return false;
    if (count != null && produced >= count) return false;
    produced++;
    final occ = occurrenceAt(start);
    if (occ.endExclusive.isAfter(rangeStart) &&
        !exceptions.contains(occ.occurrenceKey)) {
      out.add(occ);
    }
    return true;
  }

  final s = event.startAt;
  final interval = event.recurrenceInterval < 1 ? 1 : event.recurrenceInterval;

  switch (event.recurrence) {
    case CalendarRecurrence.none:
      consider(s);

    case CalendarRecurrence.daily:
      // Without a count we can jump straight to the range: earlier
      // occurrences cannot overlap it unless they last longer than a step.
      var k = 0;
      if (count == null) {
        final lookBack = duration.inDays + 1;
        final firstUseful = _daysBetween(s, rangeStart) - lookBack;
        if (firstUseful > 0) k = firstUseful ~/ interval;
      }
      for (var i = 0; i < _maxIterations; i++, k++) {
        final start = DateTime(
          s.year,
          s.month,
          s.day + k * interval,
          s.hour,
          s.minute,
        );
        if (!consider(start)) break;
      }

    case CalendarRecurrence.weekly:
      final days =
          (event.recurrenceWeekdays.isEmpty
                  ? [s.weekday % 7]
                  : event.recurrenceWeekdays.where((d) => d >= 0 && d <= 6))
              .toSet()
              .toList()
            ..sort();
      // Sunday of the week containing the first occurrence.
      final anchor = DateTime(s.year, s.month, s.day - (s.weekday % 7));
      var week = 0;
      if (count == null) {
        final lookBackWeeks = duration.inDays ~/ 7 + 1;
        final firstUseful =
            _daysBetween(anchor, rangeStart) ~/ 7 - lookBackWeeks;
        if (firstUseful > 0) week = (firstUseful ~/ interval) * interval;
      }
      var stop = false;
      for (var i = 0; i < _maxIterations && !stop; i++, week += interval) {
        for (final d in days) {
          final start = DateTime(
            anchor.year,
            anchor.month,
            anchor.day + week * 7 + d,
            s.hour,
            s.minute,
          );
          if (start.isBefore(s)) continue;
          if (!consider(start)) {
            stop = true;
            break;
          }
        }
      }

    case CalendarRecurrence.monthly:
      for (var k = 0; k < _maxIterations; k++) {
        final month = s.month + k * interval;
        final start = DateTime(s.year, month, s.day, s.hour, s.minute);
        // Skip months that don't have this day (e.g. the 31st).
        if (start.day != s.day) {
          final probe = DateTime(s.year, month);
          if (!probe.isBefore(rangeEnd)) break;
          continue;
        }
        if (!consider(start)) break;
      }

    case CalendarRecurrence.yearly:
      for (var k = 0; k < _maxIterations; k++) {
        final year = s.year + k * interval;
        final start = DateTime(year, s.month, s.day, s.hour, s.minute);
        if (start.month != s.month || start.day != s.day) {
          if (!DateTime(year).isBefore(rangeEnd)) break;
          continue;
        }
        if (!consider(start)) break;
      }
  }
  return out;
}

/// Expands every event and returns occurrences sorted by start (all-day
/// first within the same day).
List<CalendarOccurrence> expandCalendarEvents(
  Iterable<CalendarEvent> events,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final out = <CalendarOccurrence>[
    for (final e in events) ...expandCalendarEvent(e, rangeStart, rangeEnd),
  ];
  out.sort(compareOccurrences);
  return out;
}

int compareOccurrences(CalendarOccurrence a, CalendarOccurrence b) {
  final dayA = DateTime(a.start.year, a.start.month, a.start.day);
  final dayB = DateTime(b.start.year, b.start.month, b.start.day);
  final c = dayA.compareTo(dayB);
  if (c != 0) return c;
  if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
  final t = a.start.compareTo(b.start);
  if (t != 0) return t;
  return a.event.title.compareTo(b.event.title);
}

/// Whole calendar days from [a]'s date to [b]'s date (DST-safe).
int _daysBetween(DateTime a, DateTime b) {
  final ua = DateTime.utc(a.year, a.month, a.day);
  final ub = DateTime.utc(b.year, b.month, b.day);
  return ub.difference(ua).inDays;
}

/// Lays out timed occurrences of one day into side-by-side columns so
/// overlapping events don't cover each other. Returns `(column, columns)`
/// for each occurrence, where `columns` is the width of its overlap cluster.
Map<CalendarOccurrence, (int, int)> layoutDayColumns(
  List<CalendarOccurrence> timed,
) {
  final sorted = [...timed]
    ..sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : b.endExclusive.compareTo(a.endExclusive);
    });
  final result = <CalendarOccurrence, (int, int)>{};
  var cluster = <CalendarOccurrence>[];
  var columnEnds = <DateTime>[];
  var clusterEnd = DateTime.fromMillisecondsSinceEpoch(0);
  final assigned = <CalendarOccurrence, int>{};

  void flush() {
    for (final o in cluster) {
      result[o] = (assigned[o]!, columnEnds.length);
    }
    cluster = [];
    columnEnds = [];
    assigned.clear();
  }

  for (final o in sorted) {
    if (cluster.isNotEmpty && !o.start.isBefore(clusterEnd)) flush();
    var col = columnEnds.indexWhere((end) => !end.isAfter(o.start));
    if (col < 0) {
      col = columnEnds.length;
      columnEnds.add(o.endExclusive);
    } else {
      columnEnds[col] = o.endExclusive;
    }
    assigned[o] = col;
    cluster.add(o);
    if (o.endExclusive.isAfter(clusterEnd)) clusterEnd = o.endExclusive;
  }
  flush();
  return result;
}
