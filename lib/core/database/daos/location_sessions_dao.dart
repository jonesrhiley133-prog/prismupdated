import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/tables/locations_tables.dart';

part 'location_sessions_dao.g.dart';

@DriftAccessor(tables: [LocationSessions])
class LocationSessionsDao extends DatabaseAccessor<AppDatabase>
    with _$LocationSessionsDaoMixin {
  LocationSessionsDao(super.db);

  Stream<List<LocationSessionRow>> watchAll() =>
      (select(locationSessions)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();

  Future<List<LocationSessionRow>> getAll() =>
      (select(locationSessions)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  Future<LocationSessionRow?> getById(String id) => (select(
    locationSessions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> create(LocationSessionsCompanion companion) =>
      into(locationSessions).insert(companion);

  Future<void> updateById(String id, LocationSessionsCompanion companion) =>
      (update(
        locationSessions,
      )..where((t) => t.id.equals(id))).write(companion);

  Future<void> softDelete(String id) =>
      (update(locationSessions)..where((t) => t.id.equals(id))).write(
        const LocationSessionsCompanion(isDeleted: Value(true)),
      );
}
