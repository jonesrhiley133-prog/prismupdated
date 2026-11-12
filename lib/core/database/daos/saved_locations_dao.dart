import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/tables/locations_tables.dart';

part 'saved_locations_dao.g.dart';

@DriftAccessor(tables: [SavedLocations])
class SavedLocationsDao extends DatabaseAccessor<AppDatabase>
    with _$SavedLocationsDaoMixin {
  SavedLocationsDao(super.db);

  Stream<List<SavedLocationRow>> watchAll() =>
      (select(savedLocations)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<SavedLocationRow>> getAll() =>
      (select(savedLocations)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<SavedLocationRow?> getById(String id) =>
      (select(savedLocations)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> create(SavedLocationsCompanion companion) =>
      into(savedLocations).insert(companion);

  Future<void> updateById(String id, SavedLocationsCompanion companion) =>
      (update(savedLocations)..where((t) => t.id.equals(id))).write(companion);

  Future<void> softDelete(String id) =>
      (update(savedLocations)..where((t) => t.id.equals(id))).write(
        const SavedLocationsCompanion(isDeleted: Value(true)),
      );
}
