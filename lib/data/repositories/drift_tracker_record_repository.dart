import 'package:prism_sync/generated/api.dart' as ffi;
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/daos/tracker_records_dao.dart';
import 'package:prism_plurality/data/mappers/tracker_record_mapper.dart';
import 'package:prism_plurality/data/repositories/sync_record_mixin.dart';
import 'package:prism_plurality/data/sync/field_diff.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart' as domain;
import 'package:prism_plurality/domain/repositories/entity_repository.dart';

class DriftTrackerRecordRepository
    with SyncRecordMixin
    implements EntityRepository<domain.TrackerRecord> {
  DriftTrackerRecordRepository(this._dao, this._syncHandle);

  final TrackerRecordsDao _dao;
  final ffi.PrismSyncHandle? _syncHandle;

  static const _table = 'tracker_records';

  @override
  ffi.PrismSyncHandle? get syncHandle => _syncHandle;

  @override
  AppDatabase get syncOutboxDatabase => _dao.attachedDatabase;

  @override
  Stream<List<domain.TrackerRecord>> watchAll() => _dao.watchAll().map(
    (rows) => rows.map(TrackerRecordMapper.toDomain).toList(),
  );

  @override
  Future<List<domain.TrackerRecord>> getAll() async =>
      (await _dao.getAll()).map(TrackerRecordMapper.toDomain).toList();

  @override
  Future<domain.TrackerRecord?> getById(String id) async {
    final row = await _dao.getById(id);
    if (row == null || row.isDeleted) return null;
    return TrackerRecordMapper.toDomain(row);
  }

  @override
  Future<void> create(domain.TrackerRecord item) async {
    await runSyncedWrite(() async {
      await _dao.create(TrackerRecordMapper.toCompanion(item));
      await syncRecordCreate(
        _table,
        item.id,
        TrackerRecordMapper.syncFields(item),
      );
    });
  }

  @override
  Future<void> update(domain.TrackerRecord item) async {
    await runSyncedWrite(() async {
      final existing = await _dao.getById(item.id);
      if (existing == null || existing.isDeleted) return;
      final changed = diffSyncFields(
        TrackerRecordMapper.syncFieldsFromRow(existing),
        TrackerRecordMapper.syncFields(item),
      );
      if (changed.isEmpty) return;
      await _dao.updateById(
        item.id,
        TrackerRecordMapper.partialCompanion(changed),
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
