import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/data/utils/sync_datetime.dart';
import 'package:prism_plurality/domain/models/work.dart' as domain;

/// Maps `jobs` rows ↔ domain models ↔ sync field maps.
class JobMapper {
  JobMapper._();

  static domain.Job toDomain(JobRow row) {
    return domain.Job(
      id: row.id,
      name: row.name,
      hourlyRateCents: row.hourlyRateCents,
      currencyCode: row.currencyCode,
      colorHex: row.colorHex,
      notes: row.notes,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
    );
  }

  static JobsCompanion toCompanion(domain.Job m) {
    return JobsCompanion(
      id: Value(m.id),
      name: Value(m.name),
      hourlyRateCents: Value(m.hourlyRateCents),
      currencyCode: Value(m.currencyCode),
      colorHex: Value(m.colorHex),
      notes: Value(m.notes),
      isArchived: Value(m.isArchived),
      createdAt: Value(m.createdAt),
      modifiedAt: Value(m.modifiedAt),
    );
  }

  /// Sync field map for a domain model (what the repository emits).
  static Map<String, dynamic> syncFields(domain.Job m) {
    return {
      'name': m.name,
      'hourly_rate_cents': m.hourlyRateCents,
      'currency_code': m.currencyCode,
      'color_hex': m.colorHex,
      'notes': m.notes,
      'is_archived': m.isArchived,
      'created_at': toSyncUtc(m.createdAt),
      'modified_at': toSyncUtc(m.modifiedAt),
      'is_deleted': false,
    };
  }

  /// Sync field map for a stored row (diffs and the sync adapter).
  static Map<String, dynamic> syncFieldsFromRow(JobRow r) => {
    'name': r.name,
    'hourly_rate_cents': r.hourlyRateCents,
    'currency_code': r.currencyCode,
    'color_hex': r.colorHex,
    'notes': r.notes,
    'is_archived': r.isArchived,
    'created_at': toSyncUtc(r.createdAt),
    'modified_at': toSyncUtc(r.modifiedAt),
    'is_deleted': r.isDeleted,
  };

  /// Partial companion with only the keys present in [fields].
  static JobsCompanion partialCompanion(Map<String, dynamic> fields) {
    Value<T> v<T>(String key, T Function(Object? raw) read) =>
        fields.containsKey(key) ? Value(read(fields[key])) : Value<T>.absent();
    return JobsCompanion(
      name: v('name', (r) => r as String),
      hourlyRateCents: v('hourly_rate_cents', (r) => r as int),
      currencyCode: v('currency_code', (r) => r as String),
      colorHex: v('color_hex', (r) => r as String?),
      notes: v('notes', (r) => r as String?),
      isArchived: v('is_archived', (r) => r as bool),
      createdAt: v('created_at', parseSyncDateTime),
      modifiedAt: v('modified_at', parseSyncDateTime),
    );
  }
}
