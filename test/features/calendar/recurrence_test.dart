import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/features/calendar/utils/recurrence.dart';

CalendarEvent _event({
  required DateTime start,
  DateTime? end,
  CalendarRecurrence recurrence = CalendarRecurrence.none,
  int interval = 1,
  List<int> weekdays = const [],
  DateTime? until,
  int? count,
  List<String> exceptions = const [],
  bool allDay = false,
}) {
  final now = DateTime(2026, 1, 1);
  return CalendarEvent(
    id: 'e',
    title: 'Event',
    startAt: start,
    endAt: end ?? start.add(const Duration(hours: 1)),
    isAllDay: allDay,
    recurrence: recurrence,
    recurrenceInterval: interval,
    recurrenceWeekdays: weekdays,
    recurrenceUntil: until,
    recurrenceCount: count,
    recurrenceExceptions: exceptions,
    createdAt: now,
    modifiedAt: now,
  );
}

List<String> _keys(List<CalendarOccurrence> o) =>
    o.map((e) => e.occurrenceKey).toList();

void main() {
  final jan = DateTime(2026, 1, 1);
  final feb = DateTime(2026, 2, 1);

  test('one-off event appears only when it overlaps the range', () {
    final e = _event(start: DateTime(2026, 1, 10, 9));
    expect(expandCalendarEvent(e, jan, feb), hasLength(1));
    expect(expandCalendarEvent(e, feb, DateTime(2026, 3, 1)), isEmpty);
  });

  test('daily every 2 days with a count', () {
    final e = _event(
      start: DateTime(2026, 1, 1, 9),
      recurrence: CalendarRecurrence.daily,
      interval: 2,
      count: 4,
    );
    expect(_keys(expandCalendarEvent(e, jan, feb)), [
      '2026-01-01',
      '2026-01-03',
      '2026-01-05',
      '2026-01-07',
    ]);
  });

  test('daily skip-ahead still finds occurrences far in the future', () {
    final e = _event(
      start: DateTime(2000, 1, 1, 9),
      recurrence: CalendarRecurrence.daily,
    );
    final occ = expandCalendarEvent(e, jan, DateTime(2026, 1, 4));
    expect(_keys(occ), ['2026-01-01', '2026-01-02', '2026-01-03']);
    expect(occ.first.start.hour, 9);
  });

  test('weekly on Mon/Wed/Fri until a date', () {
    final e = _event(
      start: DateTime(2026, 1, 5, 18), // Monday
      recurrence: CalendarRecurrence.weekly,
      weekdays: const [1, 3, 5],
      until: DateTime(2026, 1, 14),
    );
    expect(_keys(expandCalendarEvent(e, jan, feb)), [
      '2026-01-05',
      '2026-01-07',
      '2026-01-09',
      '2026-01-12',
      '2026-01-14',
    ]);
  });

  test('weekly without weekdays uses the start weekday, every 2 weeks', () {
    final e = _event(
      start: DateTime(2026, 1, 6, 10), // Tuesday
      recurrence: CalendarRecurrence.weekly,
      interval: 2,
    );
    expect(_keys(expandCalendarEvent(e, jan, feb)), [
      '2026-01-06',
      '2026-01-20',
    ]);
  });

  test('monthly on the 31st skips short months', () {
    final e = _event(
      start: DateTime(2026, 1, 31, 12),
      recurrence: CalendarRecurrence.monthly,
    );
    expect(_keys(expandCalendarEvent(e, jan, DateTime(2026, 6, 1))), [
      '2026-01-31',
      '2026-03-31',
      '2026-05-31',
    ]);
  });

  test('yearly on Feb 29 only occurs in leap years', () {
    final e = _event(
      start: DateTime(2024, 2, 29, 8),
      recurrence: CalendarRecurrence.yearly,
    );
    expect(_keys(expandCalendarEvent(e, DateTime(2024), DateTime(2033))), [
      '2024-02-29',
      '2028-02-29',
      '2032-02-29',
    ]);
  });

  test('exceptions remove occurrences but still count toward the count', () {
    final e = _event(
      start: DateTime(2026, 1, 1, 9),
      recurrence: CalendarRecurrence.daily,
      count: 3,
      exceptions: const ['2026-01-02'],
    );
    expect(_keys(expandCalendarEvent(e, jan, feb)), [
      '2026-01-01',
      '2026-01-03',
    ]);
  });

  test('multi-day all-day event covers each of its days', () {
    final e = _event(
      start: DateTime(2026, 1, 10),
      end: DateTime(2026, 1, 12),
      allDay: true,
    );
    final occ = expandCalendarEvent(
      e,
      DateTime(2026, 1, 11),
      DateTime(2026, 1, 12),
    ).single;
    expect(occ.coversDay(DateTime(2026, 1, 10)), isTrue);
    expect(occ.coversDay(DateTime(2026, 1, 12)), isTrue);
    expect(occ.coversDay(DateTime(2026, 1, 13)), isFalse);
    expect(occ.isMultiDay, isTrue);
  });

  test(
    'an occurrence that started before the range but overlaps it is kept',
    () {
      final e = _event(
        start: DateTime(2026, 1, 31, 23),
        end: DateTime(2026, 2, 1, 2),
      );
      expect(expandCalendarEvent(e, feb, DateTime(2026, 2, 2)), hasLength(1));
    },
  );

  test('layoutDayColumns puts overlapping events side by side', () {
    final a = expandCalendarEvent(
      _event(start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 11)),
      jan,
      feb,
    ).single;
    final b = expandCalendarEvent(
      _event(
        start: DateTime(2026, 1, 1, 10),
        end: DateTime(2026, 1, 1, 12),
      ).copyWith(id: 'b'),
      jan,
      feb,
    ).single;
    final c = expandCalendarEvent(
      _event(start: DateTime(2026, 1, 1, 13)).copyWith(id: 'c'),
      jan,
      feb,
    ).single;
    final layout = layoutDayColumns([a, b, c]);
    expect(layout[a], (0, 2));
    expect(layout[b], (1, 2));
    expect(layout[c], (0, 1));
  });
}
