import 'package:drift/drift.dart';

/// A generic, synced record used by the life-tracking sections (journal,
/// dictionary, fitness, finance, school, relationships, headspace,
/// subsystems, sleep details, achievements …).
///
/// [kind] says which section and record type a row belongs to (for example
/// `journal.entry`, `finance.txn`, `school.class`). Section-specific values
/// live in [data], a JSON object; the common columns are promoted so they
/// can be indexed and queried. [parentId] links child records (an
/// assignment to its class, a headspace link to its map …). [amount] holds
/// a numeric value in hundredths (money in cents, distance in 1/100 km …).
@DataClassName('TrackerRecordRow')
class TrackerRecords extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().nullable()();

  /// JSON object with section-specific fields.
  TextColumn get data => text().nullable()();

  /// JSON list of tags.
  TextColumn get tags => text().nullable()();
  DateTimeColumn get occurredAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get amount => integer().nullable()();
  TextColumn get memberId => text().nullable()();

  /// Hidden behind a tap-to-reveal and left out of Home, insights and
  /// shared summaries.
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
