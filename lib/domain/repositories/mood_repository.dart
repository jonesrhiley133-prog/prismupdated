import 'package:prism_plurality/domain/models/mood_entry.dart';

abstract class MoodRepository {
  Stream<List<MoodEntry>> watchAll();
  Future<List<MoodEntry>> getAll();
  Future<MoodEntry?> getById(String id);
  Future<void> create(MoodEntry entry);
  Future<void> update(MoodEntry entry);
  Future<void> delete(String id);
}
