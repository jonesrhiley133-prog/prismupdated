import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/tables/calendar_events_table.dart';

part 'calendar_events_dao.g.dart';

@DriftAccessor(tables: [CalendarEvents])
class CalendarEventsDao extends DatabaseAccessor<AppDatabase>
    with _$CalendarEventsDaoMixin {
  CalendarEventsDao(super.db);

  /// All live events. Recurring series are expanded in Dart, so the whole
  /// table is streamed rather than a date window.
  Stream<List<CalendarEventRow>> watchAll() =>
      (select(calendarEvents)
            ..where((e) => e.isDeleted.equals(false))
            ..orderBy([(e) => OrderingTerm.asc(e.startAt)]))
          .watch();

  Future<List<CalendarEventRow>> getAll() =>
      (select(calendarEvents)
            ..where((e) => e.isDeleted.equals(false))
            ..orderBy([(e) => OrderingTerm.asc(e.startAt)]))
          .get();

  Future<CalendarEventRow?> getById(String id) =>
      (select(calendarEvents)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> create(CalendarEventsCompanion companion) =>
      into(calendarEvents).insert(companion);

  Future<void> updateEvent(String id, CalendarEventsCompanion companion) =>
      (update(calendarEvents)..where((e) => e.id.equals(id))).write(companion);

  Future<void> softDelete(String id) =>
      (update(calendarEvents)..where((e) => e.id.equals(id))).write(
        const CalendarEventsCompanion(isDeleted: Value(true)),
      );
}
