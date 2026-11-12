import 'package:freezed_annotation/freezed_annotation.dart';

part 'calendar_event.freezed.dart';
part 'calendar_event.g.dart';

enum CalendarRecurrence { none, daily, weekly, monthly, yearly }

/// A calendar event. Recurring events are stored once and expanded into
/// occurrences by `expandCalendarEvent`.
@freezed
abstract class CalendarEvent with _$CalendarEvent {
  const CalendarEvent._();

  const factory CalendarEvent({
    required String id,
    required String title,
    String? description,
    String? location,

    /// Start of the first occurrence. For all-day events only the date part
    /// is meaningful.
    required DateTime startAt,

    /// End of the first occurrence. For all-day events this is the last day
    /// the event covers (inclusive).
    required DateTime endAt,
    @Default(false) bool isAllDay,

    /// `#RRGGBB` colour, or null for the theme accent.
    String? colorHex,
    String? category,
    @Default(CalendarRecurrence.none) CalendarRecurrence recurrence,

    /// Repeat every N units of [recurrence].
    @Default(1) int recurrenceInterval,

    /// Weekdays (0 = Sunday … 6 = Saturday) for weekly rules. Empty means
    /// "the weekday of [startAt]".
    @Default(<int>[]) List<int> recurrenceWeekdays,

    /// Last day the series may produce an occurrence on (inclusive).
    DateTime? recurrenceUntil,

    /// Maximum number of occurrences in the series.
    int? recurrenceCount,

    /// `yyyy-MM-dd` keys of occurrences removed from the series.
    @Default(<String>[]) List<String> recurrenceExceptions,

    /// Notification offsets in minutes before each occurrence starts.
    @Default(<int>[]) List<int> alertMinutes,

    /// Attending member ids.
    @Default(<String>[]) List<String> memberIds,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) = _CalendarEvent;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) =>
      _$CalendarEventFromJson(json);

  bool get isRecurring => recurrence != CalendarRecurrence.none;

  Duration get duration {
    final d = endAt.difference(startAt);
    return d.isNegative ? Duration.zero : d;
  }
}
