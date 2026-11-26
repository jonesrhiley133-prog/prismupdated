import 'package:prism_sync/generated/api.dart' as ffi;
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/daos/mood_entries_dao.dart';
import 'package:prism_plurality/data/mappers/mood_entry_mapper.dart';
import 'package:prism_plurality/data/repositories/sync_record_mixin.dart';
import 'package:prism_plurality/data/sync/field_diff.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart' as domain;
import 'package:prism_plurality/domain/repositories/mood_repository.dart';

class DriftMoodRepository with SyncRecordMixin implements MoodRepository {
  DriftMoodRepository(this._dao, this._syncHandle);

  final MoodEntriesDao _dao;
  final ffi.PrismSyncHandle? _syncHandle;

  static const _table = 'mood_entries';

  @override
  ffi.PrismSyncHandle? get syncHandle => _syncHandle;

  @override
  AppDatabase get syncOutboxDatabase => _dao.attachedDatabase;

  @override
  Stream<List<domain.MoodEntry>> watchAll() => _dao.watchAll().map(
    (rows) => rows.map(MoodEntryMapper.toDomain).toList(),
  );

  @override
  Future<List<domain.MoodEntry>> getAll() async =>
      (await _dao.getAll()).map(MoodEntryMapper.toDomain).toList();

  @override
  Future<domain.MoodEntry?> getById(String id) async {
    final row = await _dao.getById(id);
    if (row == null || row.isDeleted) return null;
    return MoodEntryMapper.toDomain(row);
  }

  @override
  Future<void> create(domain.MoodEntry entry) async {
    await runSyncedWrite(() async {
      await _dao.create(MoodEntryMapper.toCompanion(entry));
      await syncRecordCreate(
        _table,
        entry.id,
        MoodEntryMapper.syncFields(entry),
      );
    });
  }

  @override
  Future<void> update(domain.MoodEntry entry) async {
    await runSyncedWrite(() async {
      final existing = await _dao.getById(entry.id);
      if (existing == null || existing.isDeleted) return;
      final changed = diffSyncFields(
        MoodEntryMapper.syncFieldsFromRow(existing),
        MoodEntryMapper.syncFields(entry),
      );
      if (changed.isEmpty) return;
      await _dao.updateEntry(
        entry.id,
        MoodEntryMapper.partialCompanion(changed),
      );
      await syncRecordUpdate(_table, entry.id, changed);
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
