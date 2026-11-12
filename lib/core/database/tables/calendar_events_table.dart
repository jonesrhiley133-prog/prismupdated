import 'package:drift/drift.dart';

/// A calendar event, optionally recurring.
///
/// Recurrence is stored as a small rule: [recurrence] is the frequency name
/// (`none`, `daily`, `weekly`, `monthly`, `yearly`), [recurrenceInterval] is
/// "every N", [recurrenceWeekdays] is a JSON list of weekday ints (0 = Sunday)
/// for weekly rules, [recurrenceUntil] bounds the series, [recurrenceCount]
/// caps the number of occurrences, and [recurrenceExceptions] is a JSON list
/// of `yyyy-MM-dd` dates whose occurrence was removed.
///
/// [alertMinutes] is a JSON list of "minutes before start" notification
/// offsets; [memberIds] is a JSON list of attending member ids.
@DataClassName('CalendarEventRow')
class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();
  TextColumn get colorHex => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get recurrence => text().withDefault(const Constant('none'))();
  IntColumn get recurrenceInterval =>
      integer().withDefault(const Constant(1))();
  TextColumn get recurrenceWeekdays => text().nullable()();
  DateTimeColumn get recurrenceUntil => dateTime().nullable()();
  IntColumn get recurrenceCount => integer().nullable()();
  TextColumn get recurrenceExceptions => text().nullable()();
  TextColumn get alertMinutes => text().nullable()();
  TextColumn get memberIds => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
