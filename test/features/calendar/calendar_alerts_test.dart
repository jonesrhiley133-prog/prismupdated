import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/features/calendar/services/calendar_notification_service.dart';

void main() {
  final now = DateTime(2026, 5, 1, 12);

  CalendarEvent event(
    String id,
    DateTime start,
    List<int> alerts, {
    CalendarRecurrence recurrence = CalendarRecurrence.none,
  }) => CalendarEvent(
    id: id,
    title: id,
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    alertMinutes: alerts,
    recurrence: recurrence,
    createdAt: now,
    modifiedAt: now,
  );

  test('alerts are future-only, sorted, and include every offset', () {
    final alerts = upcomingCalendarAlerts([
      event('a', DateTime(2026, 5, 1, 18), [0, 60]),
      event('past', DateTime(2026, 5, 1, 12, 10), [30]),
      event('none', DateTime(2026, 5, 2, 9), []),
    ], now: now);
    expect(alerts.map((a) => a.fireAt), [
      DateTime(2026, 5, 1, 17),
      DateTime(2026, 5, 1, 18),
    ]);
  });

  test('recurring events produce alerts within the horizon, capped', () {
    final alerts = upcomingCalendarAlerts(
      [
        event('daily', DateTime(2026, 4, 1, 9), [
          15,
        ], recurrence: CalendarRecurrence.daily),
      ],
      now: now,
      horizon: const Duration(days: 3),
    );
    expect(alerts, hasLength(3));
    expect(alerts.first.fireAt, DateTime(2026, 5, 2, 8, 45));
    final capped = upcomingCalendarAlerts(
      [
        event('daily', DateTime(2026, 4, 1, 9), [
          15,
        ], recurrence: CalendarRecurrence.daily),
      ],
      now: now,
      horizon: const Duration(days: 60),
    );
    expect(capped, hasLength(CalendarNotificationService.maxScheduled));
  });
}
