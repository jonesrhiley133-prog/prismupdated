import 'package:prism_plurality/domain/models/calendar_event.dart';

abstract class CalendarRepository {
  Stream<List<CalendarEvent>> watchAll();
  Future<List<CalendarEvent>> getAll();
  Future<CalendarEvent?> getById(String id);
  Future<void> create(CalendarEvent event);
  Future<void> update(CalendarEvent event);
  Future<void> delete(String id);
}
