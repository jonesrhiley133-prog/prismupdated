import 'package:prism_sync/generated/api.dart' as ffi;
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/daos/jobs_dao.dart';
import 'package:prism_plurality/data/mappers/job_mapper.dart';
import 'package:prism_plurality/data/repositories/sync_record_mixin.dart';
import 'package:prism_plurality/data/sync/field_diff.dart';
import 'package:prism_plurality/domain/models/work.dart' as domain;
import 'package:prism_plurality/domain/repositories/entity_repository.dart';

class DriftJobRepository
    with SyncRecordMixin
    implements EntityRepository<domain.Job> {
  DriftJobRepository(this._dao, this._syncHandle);

  final JobsDao _dao;
  final ffi.PrismSyncHandle? _syncHandle;

  static const _table = 'jobs';

  @override
  ffi.PrismSyncHandle? get syncHandle => _syncHandle;

  @override
  AppDatabase get syncOutboxDatabase => _dao.attachedDatabase;

  @override
  Stream<List<domain.Job>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(JobMapper.toDomain).toList());

  @override
  Future<List<domain.Job>> getAll() async =>
      (await _dao.getAll()).map(JobMapper.toDomain).toList();

  @override
  Future<domain.Job?> getById(String id) async {
    final row = await _dao.getById(id);
    if (row == null || row.isDeleted) return null;
    return JobMapper.toDomain(row);
  }

  @override
  Future<void> create(domain.Job item) async {
    await runSyncedWrite(() async {
      await _dao.create(JobMapper.toCompanion(item));
      await syncRecordCreate(_table, item.id, JobMapper.syncFields(item));
    });
  }

  @override
  Future<void> update(domain.Job item) async {
    await runSyncedWrite(() async {
      final existing = await _dao.getById(item.id);
      if (existing == null || existing.isDeleted) return;
      final changed = diffSyncFields(
        JobMapper.syncFieldsFromRow(existing),
        JobMapper.syncFields(item),
      );
      if (changed.isEmpty) return;
      await _dao.updateById(item.id, JobMapper.partialCompanion(changed));
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
