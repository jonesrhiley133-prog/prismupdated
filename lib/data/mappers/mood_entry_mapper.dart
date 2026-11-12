import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/data/mappers/json_list_parsing.dart';
import 'package:prism_plurality/data/utils/sync_datetime.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart' as domain;

class MoodEntryMapper {
  MoodEntryMapper._();

  static domain.MoodEntry toDomain(MoodEntryRow row) {
    return domain.MoodEntry(
      id: row.id,
      memberId: row.memberId,
      mood: _clamp(
        row.mood,
        domain.MoodEntry.minMood,
        domain.MoodEntry.maxMood,
      ),
      intensity: _clamp(
        row.intensity,
        domain.MoodEntry.minIntensity,
        domain.MoodEntry.maxIntensity,
      ),
      emotions: parseJsonStringList(row.emotions),
      energy: _clampOrNull(row.energy),
      stress: _clampOrNull(row.stress),
      sleepQuality: _clampOrNull(row.sleepQuality),
      bodySensations: parseJsonStringList(row.bodySensations),
      note: row.note,
      recordedAt: row.recordedAt,
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
    );
  }

  static MoodEntriesCompanion toCompanion(domain.MoodEntry m) {
    return MoodEntriesCompanion(
      id: Value(m.id),
      memberId: Value(m.memberId),
      mood: Value(m.mood),
      intensity: Value(m.intensity),
      emotions: Value(encodeJsonSetOrNull(m.emotions)),
      energy: Value(m.energy),
      stress: Value(m.stress),
      sleepQuality: Value(m.sleepQuality),
      bodySensations: Value(encodeJsonSetOrNull(m.bodySensations)),
      note: Value(_blankToNull(m.note)),
      recordedAt: Value(m.recordedAt),
      createdAt: Value(m.createdAt),
      modifiedAt: Value(m.modifiedAt),
    );
  }

  /// Sync field map for a domain entry (what the repository emits).
  static Map<String, dynamic> syncFields(domain.MoodEntry m) {
    return {
      'member_id': m.memberId,
      'mood': m.mood,
      'intensity': m.intensity,
      'emotions': encodeJsonSetOrNull(m.emotions),
      'energy': m.energy,
      'stress': m.stress,
      'sleep_quality': m.sleepQuality,
      'body_sensations': encodeJsonSetOrNull(m.bodySensations),
      'note': _blankToNull(m.note),
      'recorded_at': toSyncUtc(m.recordedAt),
      'created_at': toSyncUtc(m.createdAt),
      'modified_at': toSyncUtc(m.modifiedAt),
      'is_deleted': false,
    };
  }

  /// Sync field map for a stored row (used for diffs and the sync adapter).
  static Map<String, dynamic> syncFieldsFromRow(MoodEntryRow r) => {
    'member_id': r.memberId,
    'mood': r.mood,
    'intensity': r.intensity,
    'emotions': r.emotions,
    'energy': r.energy,
    'stress': r.stress,
    'sleep_quality': r.sleepQuality,
    'body_sensations': r.bodySensations,
    'note': r.note,
    'recorded_at': toSyncUtc(r.recordedAt),
    'created_at': toSyncUtc(r.createdAt),
    'modified_at': toSyncUtc(r.modifiedAt),
    'is_deleted': r.isDeleted,
  };

  /// Partial companion holding only the keys present in [fields].
  static MoodEntriesCompanion partialCompanion(Map<String, dynamic> fields) {
    Value<T> v<T>(String key, T Function(Object? raw) read) =>
        fields.containsKey(key) ? Value(read(fields[key])) : Value<T>.absent();
    return MoodEntriesCompanion(
      memberId: v('member_id', (r) => r as String?),
      mood: v('mood', (r) => r as int),
      intensity: v('intensity', (r) => r as int),
      emotions: v('emotions', (r) => r as String?),
      energy: v('energy', (r) => r as int?),
      stress: v('stress', (r) => r as int?),
      sleepQuality: v('sleep_quality', (r) => r as int?),
      bodySensations: v('body_sensations', (r) => r as String?),
      note: v('note', (r) => r as String?),
      recordedAt: v('recorded_at', parseSyncDateTime),
      createdAt: v('created_at', parseSyncDateTime),
      modifiedAt: v('modified_at', parseSyncDateTime),
    );
  }

  static int _clamp(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  static int? _clampOrNull(int? value) => value == null
      ? null
      : _clamp(value, domain.MoodEntry.minScale, domain.MoodEntry.maxScale);
}

String? _blankToNull(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}
