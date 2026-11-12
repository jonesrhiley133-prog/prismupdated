import 'package:prism_sync/generated/api.dart' as ffi;
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/daos/location_sessions_dao.dart';
import 'package:prism_plurality/data/mappers/location_session_mapper.dart';
import 'package:prism_plurality/data/repositories/sync_record_mixin.dart';
import 'package:prism_plurality/data/sync/field_diff.dart';
import 'package:prism_plurality/domain/models/location.dart' as domain;
import 'package:prism_plurality/domain/repositories/entity_repository.dart';

class DriftLocationSessionRepository
    with SyncRecordMixin
    implements EntityRepository<domain.LocationSession> {
  DriftLocationSessionRepository(this._dao, this._syncHandle);

  final LocationSessionsDao _dao;
  final ffi.PrismSyncHandle? _syncHandle;

  static const _table = 'location_sessions';

  @override
  ffi.PrismSyncHandle? get syncHandle => _syncHandle;

  @override
  AppDatabase get syncOutboxDatabase => _dao.attachedDatabase;

  @override
  Stream<List<domain.LocationSession>> watchAll() => _dao.watchAll().map(
    (rows) => rows.map(LocationSessionMapper.toDomain).toList(),
  );

  @override
  Future<List<domain.LocationSession>> getAll() async =>
      (await _dao.getAll()).map(LocationSessionMapper.toDomain).toList();

  @override
  Future<domain.LocationSession?> getById(String id) async {
    final row = await _dao.getById(id);
    if (row == null || row.isDeleted) return null;
    return LocationSessionMapper.toDomain(row);
  }

  @override
  Future<void> create(domain.LocationSession item) async {
    await runSyncedWrite(() async {
      await _dao.create(LocationSessionMapper.toCompanion(item));
      await syncRecordCreate(
        _table,
        item.id,
        LocationSessionMapper.syncFields(item),
      );
    });
  }

  @override
  Future<void> update(domain.LocationSession item) async {
    await runSyncedWrite(() async {
      final existing = await _dao.getById(item.id);
      if (existing == null || existing.isDeleted) return;
      final changed = diffSyncFields(
        LocationSessionMapper.syncFieldsFromRow(existing),
        LocationSessionMapper.syncFields(item),
      );
      if (changed.isEmpty) return;
      await _dao.updateById(
        item.id,
        LocationSessionMapper.partialCompanion(changed),
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
