import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/data/utils/sync_datetime.dart';
import 'package:prism_plurality/domain/models/work.dart' as domain;

/// Maps `work_sessions` rows ↔ domain models ↔ sync field maps.
class WorkSessionMapper {
  WorkSessionMapper._();

  static domain.WorkSession toDomain(WorkSessionRow row) {
    return domain.WorkSession(
      id: row.id,
      jobId: row.jobId,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      hourlyRateCents: row.hourlyRateCents,
      currencyCode: row.currencyCode,
      breakSeconds: row.breakSeconds,
      memberId: row.memberId,
      note: row.note,
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
    );
  }

  static WorkSessionsCompanion toCompanion(domain.WorkSession m) {
    return WorkSessionsCompanion(
      id: Value(m.id),
      jobId: Value(m.jobId),
      startedAt: Value(m.startedAt),
      endedAt: Value(m.endedAt),
      hourlyRateCents: Value(m.hourlyRateCents),
      currencyCode: Value(m.currencyCode),
      breakSeconds: Value(m.breakSeconds),
      memberId: Value(m.memberId),
      note: Value(m.note),
      createdAt: Value(m.createdAt),
      modifiedAt: Value(m.modifiedAt),
    );
  }

  /// Sync field map for a domain model (what the repository emits).
  static Map<String, dynamic> syncFields(domain.WorkSession m) {
    return {
      'job_id': m.jobId,
      'started_at': toSyncUtc(m.startedAt),
      'ended_at': toSyncUtcOrNull(m.endedAt),
      'hourly_rate_cents': m.hourlyRateCents,
      'currency_code': m.currencyCode,
      'break_seconds': m.breakSeconds,
      'member_id': m.memberId,
      'note': m.note,
      'created_at': toSyncUtc(m.createdAt),
      'modified_at': toSyncUtc(m.modifiedAt),
      'is_deleted': false,
    };
  }

  /// Sync field map for a stored row (diffs and the sync adapter).
  static Map<String, dynamic> syncFieldsFromRow(WorkSessionRow r) => {
    'job_id': r.jobId,
    'started_at': toSyncUtc(r.startedAt),
    'ended_at': toSyncUtcOrNull(r.endedAt),
    'hourly_rate_cents': r.hourlyRateCents,
    'currency_code': r.currencyCode,
    'break_seconds': r.breakSeconds,
    'member_id': r.memberId,
    'note': r.note,
    'created_at': toSyncUtc(r.createdAt),
    'modified_at': toSyncUtc(r.modifiedAt),
    'is_deleted': r.isDeleted,
  };

  /// Partial companion with only the keys present in [fields].
  static WorkSessionsCompanion partialCompanion(Map<String, dynamic> fields) {
    Value<T> v<T>(String key, T Function(Object? raw) read) =>
        fields.containsKey(key) ? Value(read(fields[key])) : Value<T>.absent();
    return WorkSessionsCompanion(
      jobId: v('job_id', (r) => r as String),
      startedAt: v('started_at', parseSyncDateTime),
      endedAt: v('ended_at', (r) => r == null ? null : parseSyncDateTime(r)),
      hourlyRateCents: v('hourly_rate_cents', (r) => r as int),
      currencyCode: v('currency_code', (r) => r as String),
      breakSeconds: v('break_seconds', (r) => r as int),
      memberId: v('member_id', (r) => r as String?),
      note: v('note', (r) => r as String?),
      createdAt: v('created_at', parseSyncDateTime),
      modifiedAt: v('modified_at', parseSyncDateTime),
    );
  }
}
