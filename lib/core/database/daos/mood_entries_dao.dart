import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/tables/mood_entries_table.dart';

part 'mood_entries_dao.g.dart';

@DriftAccessor(tables: [MoodEntries])
class MoodEntriesDao extends DatabaseAccessor<AppDatabase>
    with _$MoodEntriesDaoMixin {
  MoodEntriesDao(super.db);

  Stream<List<MoodEntryRow>> watchAll() =>
      (select(moodEntries)
            ..where((e) => e.isDeleted.equals(false))
            ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)]))
          .watch();

  Stream<List<MoodEntryRow>> watchBetween(DateTime start, DateTime end) =>
      (select(moodEntries)
            ..where(
              (e) =>
                  e.isDeleted.equals(false) &
                  e.recordedAt.isBiggerOrEqualValue(start) &
                  e.recordedAt.isSmallerThanValue(end),
            )
            ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)]))
          .watch();

  Future<List<MoodEntryRow>> getAll() =>
      (select(moodEntries)
            ..where((e) => e.isDeleted.equals(false))
            ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)]))
          .get();

  Future<MoodEntryRow?> getById(String id) =>
      (select(moodEntries)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> create(MoodEntriesCompanion companion) =>
      into(moodEntries).insert(companion);

  Future<void> updateEntry(String id, MoodEntriesCompanion companion) =>
      (update(moodEntries)..where((e) => e.id.equals(id))).write(companion);

  Future<void> softDelete(String id) =>
      (update(moodEntries)..where((e) => e.id.equals(id))).write(
        const MoodEntriesCompanion(isDeleted: Value(true)),
      );
}
