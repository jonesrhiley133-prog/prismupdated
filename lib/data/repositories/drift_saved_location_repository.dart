import 'package:prism_sync/generated/api.dart' as ffi;
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/daos/saved_locations_dao.dart';
import 'package:prism_plurality/data/mappers/saved_location_mapper.dart';
import 'package:prism_plurality/data/repositories/sync_record_mixin.dart';
import 'package:prism_plurality/data/sync/field_diff.dart';
import 'package:prism_plurality/domain/models/location.dart' as domain;
import 'package:prism_plurality/domain/repositories/entity_repository.dart';

class DriftSavedLocationRepository
    with SyncRecordMixin
    implements EntityRepository<domain.SavedLocation> {
  DriftSavedLocationRepository(this._dao, this._syncHandle);

  final SavedLocationsDao _dao;
  final ffi.PrismSyncHandle? _syncHandle;

  static const _table = 'saved_locations';

  @override
  ffi.PrismSyncHandle? get syncHandle => _syncHandle;

  @override
  AppDatabase get syncOutboxDatabase => _dao.attachedDatabase;

  @override
  Stream<List<domain.SavedLocation>> watchAll() => _dao.watchAll().map(
    (rows) => rows.map(SavedLocationMapper.toDomain).toList(),
  );

  @override
  Future<List<domain.SavedLocation>> getAll() async =>
      (await _dao.getAll()).map(SavedLocationMapper.toDomain).toList();

  @override
  Future<domain.SavedLocation?> getById(String id) async {
    final row = await _dao.getById(id);
    if (row == null || row.isDeleted) return null;
    return SavedLocationMapper.toDomain(row);
  }

  @override
  Future<void> create(domain.SavedLocation item) async {
    await runSyncedWrite(() async {
      await _dao.create(SavedLocationMapper.toCompanion(item));
      await syncRecordCreate(
        _table,
        item.id,
        SavedLocationMapper.syncFields(item),
      );
    });
  }

  @override
  Future<void> update(domain.SavedLocation item) async {
    await runSyncedWrite(() async {
      final existing = await _dao.getById(item.id);
      if (existing == null || existing.isDeleted) return;
      final changed = diffSyncFields(
        SavedLocationMapper.syncFieldsFromRow(existing),
        SavedLocationMapper.syncFields(item),
      );
      if (changed.isEmpty) return;
      await _dao.updateById(
        item.id,
        SavedLocationMapper.partialCompanion(changed),
      );
      await syncRecordUpdate(_table, item.id, changed);
    });
  }

  @override
  Future<void> delete(String id) async {
    await runSyncedWrite(() async {
      await _dao.softDelete(id);
      await syncRecordDelete(_table, id);
    });
  }
}
