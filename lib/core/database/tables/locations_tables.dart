import 'package:drift/drift.dart';

/// A saved place (home, work, therapist's office, …).
@DataClassName('SavedLocationRow')
class SavedLocations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Emoji shown as the location's icon.
  TextColumn get emoji => text().nullable()();
  TextColumn get colorHex => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Time spent at a saved location. Open while [endedAt] is null.
/// Timestamps are exact to the second; durations are never rounded.
@DataClassName('LocationSessionRow')
class LocationSessions extends Table {
  TextColumn get id => text()();
  TextColumn get locationId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
