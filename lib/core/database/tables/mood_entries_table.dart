import 'package:drift/drift.dart';

/// One mood / wellbeing check-in.
///
/// [mood] is the 1–5 valence scale (1 = very low, 5 = great). [intensity] is
/// how strongly the feeling is held (1–10). [energy], [stress] and
/// [sleepQuality] are optional 1–5 scales recorded alongside the check-in.
/// [emotions] and [bodySensations] are JSON-encoded string lists.
@DataClassName('MoodEntryRow')
class MoodEntries extends Table {
  TextColumn get id => text()();

  /// Member who logged the check-in. Null = whole system / unspecified.
  TextColumn get memberId => text().nullable()();
  IntColumn get mood => integer().withDefault(const Constant(3))();
  IntColumn get intensity => integer().withDefault(const Constant(5))();
  TextColumn get emotions => text().nullable()();
  IntColumn get energy => integer().nullable()();
  IntColumn get stress => integer().nullable()();
  IntColumn get sleepQuality => integer().nullable()();
  TextColumn get bodySensations => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
