import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/tables/tracker_records_table.dart';

part 'tracker_records_dao.g.dart';

@DriftAccessor(tables: [TrackerRecords])
class TrackerRecordsDao extends DatabaseAccessor<AppDatabase>
    with _$TrackerRecordsDaoMixin {
  TrackerRecordsDao(super.db);

  Stream<List<TrackerRecordRow>> watchAll() =>
      (select(trackerRecords)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<TrackerRecordRow>> getAll() =>
      (select(trackerRecords)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<TrackerRecordRow?> getById(String id) =>
      (select(trackerRecords)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> create(TrackerRecordsCompanion companion) =>
      into(trackerRecords).insert(companion);

  Future<void> updateById(String id, TrackerRecordsCompanion companion) =>
      (update(trackerRecords)..where((t) => t.id.equals(id))).write(companion);

  Future<void> softDelete(String id) =>
      (update(trackerRecords)..where((t) => t.id.equals(id))).write(
        const TrackerRecordsCompanion(isDeleted: Value(true)),
      );
}
