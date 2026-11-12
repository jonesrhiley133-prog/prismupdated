import 'package:drift/drift.dart';

/// A job with an hourly wage. Money is stored in minor units (cents) to
/// avoid floating-point drift.
@DataClassName('JobRow')
class Jobs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get hourlyRateCents => integer().withDefault(const Constant(0))();

  /// ISO 4217 code, e.g. `USD`.
  TextColumn get currencyCode => text().withDefault(const Constant('USD'))();
  TextColumn get colorHex => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One clock-in. Open while [endedAt] is null. [hourlyRateCents] is a
/// snapshot of the job's rate at clock-in, so later wage changes don't
/// rewrite history. Unpaid break time is in [breakSeconds].
@DataClassName('WorkSessionRow')
class WorkSessions extends Table {
  TextColumn get id => text()();
  TextColumn get jobId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get hourlyRateCents => integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('USD'))();
  IntColumn get breakSeconds => integer().withDefault(const Constant(0))();
  TextColumn get memberId => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
