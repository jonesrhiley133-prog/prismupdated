import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/tables/cycle_contacts_tables.dart';

part 'cycle_entries_dao.g.dart';

@DriftAccessor(tables: [CycleEntries])
class CycleEntriesDao extends DatabaseAccessor<AppDatabase>
    with _$CycleEntriesDaoMixin {
  CycleEntriesDao(super.db);

  Stream<List<CycleEntryRow>> watchAll() =>
      (select(cycleEntries)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  Future<List<CycleEntryRow>> getAll() =>
      (select(cycleEntries)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<CycleEntryRow?> getById(String id) =>
      (select(cycleEntries)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> create(CycleEntriesCompanion companion) =>
      into(cycleEntries).insert(companion);

  Future<void> updateById(String id, CycleEntriesCompanion companion) =>
      (update(cycleEntries)..where((t) => t.id.equals(id))).write(companion);

  Future<void> softDelete(String id) =>
      (update(cycleEntries)..where((t) => t.id.equals(id))).write(
        const CycleEntriesCompanion(isDeleted: Value(true)),
      );
}
