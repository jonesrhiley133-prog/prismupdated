import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/data/utils/sync_datetime.dart';
import 'package:prism_plurality/domain/models/location.dart' as domain;

/// Maps `location_sessions` rows ↔ domain models ↔ sync field maps.
class LocationSessionMapper {
  LocationSessionMapper._();

  static domain.LocationSession toDomain(LocationSessionRow row) {
    return domain.LocationSession(
      id: row.id,
      locationId: row.locationId,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      note: row.note,
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
    );
  }

  static LocationSessionsCompanion toCompanion(domain.LocationSession m) {
    return LocationSessionsCompanion(
      id: Value(m.id),
      locationId: Value(m.locationId),
      startedAt: Value(m.startedAt),
      endedAt: Value(m.endedAt),
      note: Value(m.note),
      createdAt: Value(m.createdAt),
      modifiedAt: Value(m.modifiedAt),
    );
  }

  /// Sync field map for a domain model (what the repository emits).
  static Map<String, dynamic> syncFields(domain.LocationSession m) {
    return {
      'location_id': m.locationId,
      'started_at': toSyncUtc(m.startedAt),
      'ended_at': toSyncUtcOrNull(m.endedAt),
      'note': m.note,
      'created_at': toSyncUtc(m.createdAt),
      'modified_at': toSyncUtc(m.modifiedAt),
      'is_deleted': false,
    };
  }

  /// Sync field map for a stored row (diffs and the sync adapter).
  static Map<String, dynamic> syncFieldsFromRow(LocationSessionRow r) => {
    'location_id': r.locationId,
    'started_at': toSyncUtc(r.startedAt),
    'ended_at': toSyncUtcOrNull(r.endedAt),
    'note': r.note,
    'created_at': toSyncUtc(r.createdAt),
    'modified_at': toSyncUtc(r.modifiedAt),
    'is_deleted': r.isDeleted,
  };

  /// Partial companion with only the keys present in [fields].
  static LocationSessionsCompanion partialCompanion(
    Map<String, dynamic> fields,
  ) {
    Value<T> v<T>(String key, T Function(Object? raw) read) =>
        fields.containsKey(key) ? Value(read(fields[key])) : Value<T>.absent();
    return LocationSessionsCompanion(
      locationId: v('location_id', (r) => r as String),
      startedAt: v('started_at', parseSyncDateTime),
      endedAt: v('ended_at', (r) => r == null ? null : parseSyncDateTime(r)),
      note: v('note', (r) => r as String?),
      createdAt: v('created_at', parseSyncDateTime),
      modifiedAt: v('modified_at', parseSyncDateTime),
    );
  }
}
