import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/tables/work_tables.dart';

part 'jobs_dao.g.dart';

@DriftAccessor(tables: [Jobs])
class JobsDao extends DatabaseAccessor<AppDatabase> with _$JobsDaoMixin {
  JobsDao(super.db);

  Stream<List<JobRow>> watchAll() =>
      (select(jobs)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<List<JobRow>> getAll() =>
      (select(jobs)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<JobRow?> getById(String id) =>
      (select(jobs)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> create(JobsCompanion companion) => into(jobs).insert(companion);

  Future<void> updateById(String id, JobsCompanion companion) =>
      (update(jobs)..where((t) => t.id.equals(id))).write(companion);

  Future<void> softDelete(String id) =>
      (update(jobs)..where((t) => t.id.equals(id))).write(
        const JobsCompanion(isDeleted: Value(true)),
      );
}
