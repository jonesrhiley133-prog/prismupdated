import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/calendar/utils/recurrence.dart';

/// A single alert to deliver for an event occurrence.
@immutable
class CalendarAlert {
  const CalendarAlert({
    required this.fireAt,
    required this.occurrence,
    required this.minutesBefore,
  });

  final DateTime fireAt;
  final CalendarOccurrence occurrence;
  final int minutesBefore;
}

/// Computes the upcoming alerts for [events] within [horizon] of [now],
/// soonest first, capped at [limit].
List<CalendarAlert> upcomingCalendarAlerts(
  Iterable<CalendarEvent> events, {
  required DateTime now,
  Duration horizon = const Duration(days: 14),
  int limit = CalendarNotificationService.maxScheduled,
}) {
  final withAlerts = events.where((e) => e.alertMinutes.isNotEmpty).toList();
  if (withAlerts.isEmpty) return const [];
  final maxLead = withAlerts
      .expand((e) => e.alertMinutes)
      .fold<int>(0, (a, b) => b > a ? b : a);
  final occurrences = expandCalendarEvents(
    withAlerts,
    now,
    now.add(horizon).add(Duration(minutes: maxLead)),
  );
  final alerts = <CalendarAlert>[];
  for (final o in occurrences) {
    for (final minutes in o.event.alertMinutes) {
      final fireAt = o.start.subtract(Duration(minutes: minutes));
      if (fireAt.isAfter(now) && fireAt.isBefore(now.add(horizon))) {
        alerts.add(
          CalendarAlert(fireAt: fireAt, occurrence: o, minutesBefore: minutes),
        );
      }
    }
  }
  alerts.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return alerts.take(limit).toList();
}

/// Schedules local notifications for calendar event alerts.
///
/// Uses a fixed block of notification IDs (non-overlapping with fronting
/// 1000–2000, habits 3,000,000+ and reminders 20,000,000–21,200,360). Every
/// reschedule cancels the whole block and re-issues the soonest alerts, so
/// edits, deletes and synced changes never leave stale alerts behind. The
/// cap keeps Prism well under iOS's 64-pending-notification limit together
/// with reminders and habits.
class CalendarNotificationService {
  CalendarNotificationService(this._local);

  final LocalNotificationService _local;

  static const idRangeStart = 22000000;
  static const maxScheduled = 24;
  static const _channelId = 'calendar';
  static const _channelName = 'Calendar';
  static const _channelDesc = 'Calendar event alerts';

  Future<void> _queue = Future.value();

  Future<void> reschedule(List<CalendarEvent> events, {DateTime? now}) {
    final result = _queue.then(
      (_) => _reschedule(events, now ?? DateTime.now()),
    );
    _queue = result.catchError((Object _) {});
    return result;
  }

  Future<void> _reschedule(List<CalendarEvent> events, DateTime now) async {
    await _local.cancelRange(idRangeStart, maxScheduled);
    final alerts = upcomingCalendarAlerts(events, now: now);
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwin = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    for (var i = 0; i < alerts.length; i++) {
      final a = alerts[i];
      await _local.scheduleOneShot(
        id: idRangeStart + i,
        title: a.occurrence.event.title,
        body: _body(a),
        scheduledFor: a.fireAt,
        details: details,
        payload: 'prism:calendar:${a.occurrence.event.id}',
      );
    }
  }

  String _body(CalendarAlert a) {
    final o = a.occurrence;
    final where = o.event.location;
    final when = o.isAllDay
        ? calendarDateKey(o.start)
        : '${o.start.hour.toString().padLeft(2, '0')}:'
              '${o.start.minute.toString().padLeft(2, '0')}';
    return [
      when,
      if (where != null && where.isNotEmpty) where,
      if (where == null && o.event.category != null) o.event.category!,
    ].join(' · ');
  }
}

final calendarNotificationServiceProvider =
    Provider<CalendarNotificationService>((ref) {
      return CalendarNotificationService(
        ref.watch(localNotificationServiceProvider),
      );
    });

/// Keeps calendar alerts in sync with the event list. Listen to this at the
/// app level (see `PrismApp`).
final calendarNotificationListenerProvider = Provider<void>((ref) {
  final service = ref.watch(calendarNotificationServiceProvider);
  Timer? debounce;
  ref.onDispose(() => debounce?.cancel());

  void schedule() {
    final events = ref.read(calendarEventsProvider).value;
    if (events == null) return;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), () {
      service.reschedule(events).catchError((Object e) {
        debugPrint('Calendar alert reschedule failed (non-fatal): $e');
      });
    });
  }

  // Fires on startup and on every local or synced change. Alerts cover a
  // rolling 14-day window, so opening the app at least once every two weeks
  // keeps later occurrences armed.
  ref.listen(
    calendarEventsProvider,
    (_, _) => schedule(),
    fireImmediately: true,
  );
});
