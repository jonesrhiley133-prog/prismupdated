import 'package:prism_sync/generated/api.dart' as ffi;
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/daos/contacts_dao.dart';
import 'package:prism_plurality/data/mappers/contact_mapper.dart';
import 'package:prism_plurality/data/repositories/sync_record_mixin.dart';
import 'package:prism_plurality/data/sync/field_diff.dart';
import 'package:prism_plurality/domain/models/contact.dart' as domain;
import 'package:prism_plurality/domain/repositories/entity_repository.dart';

class DriftContactRepository
    with SyncRecordMixin
    implements EntityRepository<domain.Contact> {
  DriftContactRepository(this._dao, this._syncHandle);

  final ContactsDao _dao;
  final ffi.PrismSyncHandle? _syncHandle;

  static const _table = 'contacts';

  @override
  ffi.PrismSyncHandle? get syncHandle => _syncHandle;

  @override
  AppDatabase get syncOutboxDatabase => _dao.attachedDatabase;

  @override
  Stream<List<domain.Contact>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(ContactMapper.toDomain).toList());

  @override
  Future<List<domain.Contact>> getAll() async =>
      (await _dao.getAll()).map(ContactMapper.toDomain).toList();

  @override
  Future<domain.Contact?> getById(String id) async {
    final row = await _dao.getById(id);
    if (row == null || row.isDeleted) return null;
    return ContactMapper.toDomain(row);
  }

  @override
  Future<void> create(domain.Contact item) async {
    await runSyncedWrite(() async {
      await _dao.create(ContactMapper.toCompanion(item));
      await syncRecordCreate(_table, item.id, ContactMapper.syncFields(item));
    });
  }

  @override
  Future<void> update(domain.Contact item) async {
    await runSyncedWrite(() async {
      final existing = await _dao.getById(item.id);
      if (existing == null || existing.isDeleted) return;
      final changed = diffSyncFields(
        ContactMapper.syncFieldsFromRow(existing),
        ContactMapper.syncFields(item),
      );
      if (changed.isEmpty) return;
      await _dao.updateById(item.id, ContactMapper.partialCompanion(changed));
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
