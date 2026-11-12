import 'package:drift/drift.dart';

/// One day of cycle tracking. [date] is a `yyyy-MM-dd` calendar date so it
/// never shifts between time zones.
@DataClassName('CycleEntryRow')
class CycleEntries extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()();

  /// 0 none, 1 spotting, 2 light, 3 medium, 4 heavy.
  IntColumn get flow => integer().withDefault(const Constant(0))();

  /// JSON list of symptom keys.
  TextColumn get symptoms => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get memberId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A person outside the system (friend, family, coworker …).
///
/// [birthday] is `yyyy-MM-dd`, or `0004-MM-dd` when the year is unknown
/// (the same convention member birthdays use). [phones] and [emails] are
/// JSON string lists. [externalId] is the device-contacts id or the source
/// app's id, used to avoid importing the same person twice.
@DataClassName('ContactRow')
class Contacts extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get phones => text().nullable()();
  TextColumn get emails => text().nullable()();
  TextColumn get birthday => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get externalId => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
