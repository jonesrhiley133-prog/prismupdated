import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/tables/work_tables.dart';

part 'work_sessions_dao.g.dart';

@DriftAccessor(tables: [WorkSessions])
class WorkSessionsDao extends DatabaseAccessor<AppDatabase>
    with _$WorkSessionsDaoMixin {
  WorkSessionsDao(super.db);

  Stream<List<WorkSessionRow>> watchAll() =>
      (select(workSessions)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();

  Future<List<WorkSessionRow>> getAll() =>
      (select(workSessions)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  Future<WorkSessionRow?> getById(String id) =>
      (select(workSessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> create(WorkSessionsCompanion companion) =>
      into(workSessions).insert(companion);

  Future<void> updateById(String id, WorkSessionsCompanion companion) =>
      (update(workSessions)..where((t) => t.id.equals(id))).write(companion);

  Future<void> softDelete(String id) =>
      (update(workSessions)..where((t) => t.id.equals(id))).write(
        const WorkSessionsCompanion(isDeleted: Value(true)),
      );
}
