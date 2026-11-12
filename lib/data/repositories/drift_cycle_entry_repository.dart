import 'package:prism_sync/generated/api.dart' as ffi;
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/daos/cycle_entries_dao.dart';
import 'package:prism_plurality/data/mappers/cycle_entry_mapper.dart';
import 'package:prism_plurality/data/repositories/sync_record_mixin.dart';
import 'package:prism_plurality/data/sync/field_diff.dart';
import 'package:prism_plurality/domain/models/cycle_entry.dart' as domain;
import 'package:prism_plurality/domain/repositories/entity_repository.dart';

class DriftCycleEntryRepository
    with SyncRecordMixin
    implements EntityRepository<domain.CycleEntry> {
  DriftCycleEntryRepository(this._dao, this._syncHandle);

  final CycleEntriesDao _dao;
  final ffi.PrismSyncHandle? _syncHandle;

  static const _table = 'cycle_entries';

  @override
  ffi.PrismSyncHandle? get syncHandle => _syncHandle;

  @override
  AppDatabase get syncOutboxDatabase => _dao.attachedDatabase;

  @override
  Stream<List<domain.CycleEntry>> watchAll() => _dao.watchAll().map(
    (rows) => rows.map(CycleEntryMapper.toDomain).toList(),
  );

  @override
  Future<List<domain.CycleEntry>> getAll() async =>
      (await _dao.getAll()).map(CycleEntryMapper.toDomain).toList();

  @override
  Future<domain.CycleEntry?> getById(String id) async {
    final row = await _dao.getById(id);
    if (row == null || row.isDeleted) return null;
    return CycleEntryMapper.toDomain(row);
  }

  @override
  Future<void> create(domain.CycleEntry item) async {
    await runSyncedWrite(() async {
      await _dao.create(CycleEntryMapper.toCompanion(item));
      await syncRecordCreate(
        _table,
        item.id,
        CycleEntryMapper.syncFields(item),
      );
    });
  }

  @override
  Future<void> update(domain.CycleEntry item) async {
    await runSyncedWrite(() async {
      final existing = await _dao.getById(item.id);
      if (existing == null || existing.isDeleted) return;
      final changed = diffSyncFields(
        CycleEntryMapper.syncFieldsFromRow(existing),
        CycleEntryMapper.syncFields(item),
      );
      if (changed.isEmpty) return;
      await _dao.updateById(
        item.id,
        CycleEntryMapper.partialCompanion(changed),
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
