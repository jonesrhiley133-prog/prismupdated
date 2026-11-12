import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/data/mappers/json_list_parsing.dart';
import 'package:prism_plurality/data/utils/sync_datetime.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart' as domain;

/// Maps calendar events between Drift rows, domain models and sync fields.
///
/// All-day events are stored as UTC midnight of their calendar date so a
/// paired device in another time zone shows the same days. Timed events are
/// ordinary instants.
class CalendarEventMapper {
  CalendarEventMapper._();

  static domain.CalendarEvent toDomain(CalendarEventRow row) {
    final recurrence = domain.CalendarRecurrence.values.firstWhere(
      (r) => r.name == row.recurrence,
      orElse: () => domain.CalendarRecurrence.none,
    );
    final start = row.isAllDay ? _fromStoredDate(row.startAt) : row.startAt;
    var end = row.isAllDay ? _fromStoredDate(row.endAt) : row.endAt;
    if (end.isBefore(start)) end = start;
    return domain.CalendarEvent(
      id: row.id,
      title: row.title,
      description: row.description,
      location: row.location,
      startAt: start,
      endAt: end,
      isAllDay: row.isAllDay,
      colorHex: row.colorHex,
      category: row.category,
      recurrence: recurrence,
      recurrenceInterval: row.recurrenceInterval < 1
          ? 1
          : row.recurrenceInterval,
      recurrenceWeekdays: parseJsonIntList(
        row.recurrenceWeekdays,
        min: 0,
        max: 6,
      ),
      recurrenceUntil: row.recurrenceUntil == null
          ? null
          : _fromStoredDate(row.recurrenceUntil!),
      recurrenceCount: (row.recurrenceCount ?? 0) > 0
          ? row.recurrenceCount
          : null,
      recurrenceExceptions: parseJsonStringList(row.recurrenceExceptions),
      alertMinutes: parseJsonIntList(row.alertMinutes, min: 0),
      memberIds: parseJsonStringList(row.memberIds),
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
    );
  }

  static CalendarEventsCompanion toCompanion(domain.CalendarEvent e) {
    return CalendarEventsCompanion(
      id: Value(e.id),
      title: Value(e.title),
      description: Value(_blankToNull(e.description)),
      location: Value(_blankToNull(e.location)),
      startAt: Value(_storedStart(e)),
      endAt: Value(_storedEnd(e)),
      isAllDay: Value(e.isAllDay),
      colorHex: Value(e.colorHex),
      category: Value(_blankToNull(e.category)),
      recurrence: Value(e.recurrence.name),
      recurrenceInterval: Value(
        e.recurrenceInterval < 1 ? 1 : e.recurrenceInterval,
      ),
      recurrenceWeekdays: Value(encodeJsonSetOrNull(e.recurrenceWeekdays)),
      recurrenceUntil: Value(
        e.recurrenceUntil == null ? null : _toStoredDate(e.recurrenceUntil!),
      ),
      recurrenceCount: Value(e.recurrenceCount),
      recurrenceExceptions: Value(encodeJsonSetOrNull(e.recurrenceExceptions)),
      alertMinutes: Value(encodeJsonSetOrNull(e.alertMinutes)),
      memberIds: Value(encodeJsonSetOrNull(e.memberIds)),
      createdAt: Value(e.createdAt),
      modifiedAt: Value(e.modifiedAt),
    );
  }

  static Map<String, dynamic> syncFields(domain.CalendarEvent e) {
    return {
      'title': e.title,
      'description': _blankToNull(e.description),
      'location': _blankToNull(e.location),
      'start_at': toSyncUtc(_storedStart(e)),
      'end_at': toSyncUtc(_storedEnd(e)),
      'is_all_day': e.isAllDay,
      'color_hex': e.colorHex,
      'category': _blankToNull(e.category),
      'recurrence': e.recurrence.name,
      'recurrence_interval': e.recurrenceInterval < 1
          ? 1
          : e.recurrenceInterval,
      'recurrence_weekdays': encodeJsonSetOrNull(e.recurrenceWeekdays),
      'recurrence_until': toSyncUtcOrNull(
        e.recurrenceUntil == null ? null : _toStoredDate(e.recurrenceUntil!),
      ),
      'recurrence_count': e.recurrenceCount,
      'recurrence_exceptions': encodeJsonSetOrNull(e.recurrenceExceptions),
      'alert_minutes': encodeJsonSetOrNull(e.alertMinutes),
      'member_ids': encodeJsonSetOrNull(e.memberIds),
      'created_at': toSyncUtc(e.createdAt),
      'modified_at': toSyncUtc(e.modifiedAt),
      'is_deleted': false,
    };
  }

  static Map<String, dynamic> syncFieldsFromRow(CalendarEventRow r) => {
    'title': r.title,
    'description': r.description,
    'location': r.location,
    'start_at': toSyncUtc(r.startAt),
    'end_at': toSyncUtc(r.endAt),
    'is_all_day': r.isAllDay,
    'color_hex': r.colorHex,
    'category': r.category,
    'recurrence': r.recurrence,
    'recurrence_interval': r.recurrenceInterval,
    'recurrence_weekdays': r.recurrenceWeekdays,
    'recurrence_until': toSyncUtcOrNull(r.recurrenceUntil),
    'recurrence_count': r.recurrenceCount,
    'recurrence_exceptions': r.recurrenceExceptions,
    'alert_minutes': r.alertMinutes,
    'member_ids': r.memberIds,
    'created_at': toSyncUtc(r.createdAt),
    'modified_at': toSyncUtc(r.modifiedAt),
    'is_deleted': r.isDeleted,
  };

  static CalendarEventsCompanion partialCompanion(Map<String, dynamic> fields) {
    Value<T> v<T>(String key, T Function(Object? raw) read) =>
        fields.containsKey(key) ? Value(read(fields[key])) : Value<T>.absent();
    return CalendarEventsCompanion(
      title: v('title', (r) => r as String),
      description: v('description', (r) => r as String?),
      location: v('location', (r) => r as String?),
      startAt: v('start_at', parseSyncDateTime),
      endAt: v('end_at', parseSyncDateTime),
      isAllDay: v('is_all_day', (r) => r as bool),
      colorHex: v('color_hex', (r) => r as String?),
      category: v('category', (r) => r as String?),
      recurrence: v('recurrence', (r) => r as String),
      recurrenceInterval: v('recurrence_interval', (r) => r as int),
      recurrenceWeekdays: v('recurrence_weekdays', (r) => r as String?),
      recurrenceUntil: v(
        'recurrence_until',
        (r) => r == null ? null : parseSyncDateTime(r),
      ),
      recurrenceCount: v('recurrence_count', (r) => r as int?),
      recurrenceExceptions: v('recurrence_exceptions', (r) => r as String?),
      alertMinutes: v('alert_minutes', (r) => r as String?),
      memberIds: v('member_ids', (r) => r as String?),
      createdAt: v('created_at', parseSyncDateTime),
      modifiedAt: v('modified_at', parseSyncDateTime),
    );
  }

  static DateTime _storedStart(domain.CalendarEvent e) =>
      e.isAllDay ? _toStoredDate(e.startAt) : e.startAt;

  static DateTime _storedEnd(domain.CalendarEvent e) =>
      e.isAllDay ? _toStoredDate(e.endAt) : e.endAt;
}

/// A local calendar date → UTC midnight of that date.
DateTime _toStoredDate(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day);

/// UTC midnight stored date → local midnight of the same calendar date.
DateTime _fromStoredDate(DateTime stored) {
  final utc = stored.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

String? _blankToNull(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}
