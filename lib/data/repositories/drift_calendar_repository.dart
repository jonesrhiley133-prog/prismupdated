import 'package:prism_sync/generated/api.dart' as ffi;
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/daos/calendar_events_dao.dart';
import 'package:prism_plurality/data/mappers/calendar_event_mapper.dart';
import 'package:prism_plurality/data/repositories/sync_record_mixin.dart';
import 'package:prism_plurality/data/sync/field_diff.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart' as domain;
import 'package:prism_plurality/domain/repositories/calendar_repository.dart';

class DriftCalendarRepository with SyncRecordMixin implements CalendarRepository {
  DriftCalendarRepository(this._dao, this._syncHandle);

  final CalendarEventsDao _dao;
  final ffi.PrismSyncHandle? _syncHandle;

  static const _table = 'calendar_events';

  @override
  ffi.PrismSyncHandle? get syncHandle => _syncHandle;

  @override
  AppDatabase get syncOutboxDatabase => _dao.attachedDatabase;

  @override
  Stream<List<domain.CalendarEvent>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(CalendarEventMapper.toDomain).toList());

  @override
  Future<List<domain.CalendarEvent>> getAll() async =>
      (await _dao.getAll()).map(CalendarEventMapper.toDomain).toList();

  @override
  Future<domain.CalendarEvent?> getById(String id) async {
    final row = await _dao.getById(id);
    if (row == null || row.isDeleted) return null;
    return CalendarEventMapper.toDomain(row);
  }

  @override
  Future<void> create(domain.CalendarEvent event) async {
    await runSyncedWrite(() async {
      await _dao.create(CalendarEventMapper.toCompanion(event));
      await syncRecordCreate(_table, event.id, CalendarEventMapper.syncFields(event));
    });
  }

  @override
  Future<void> update(domain.CalendarEvent event) async {
    await runSyncedWrite(() async {
      final existing = await _dao.getById(event.id);
      if (existing == null || existing.isDeleted) return;
      final changed = diffSyncFields(
        CalendarEventMapper.syncFieldsFromRow(existing),
        CalendarEventMapper.syncFields(event),
      );
      if (changed.isEmpty) return;
      await _dao.updateEvent(event.id, CalendarEventMapper.partialCompanion(changed));
      await syncRecordUpdate(_table, event.id, changed);
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
