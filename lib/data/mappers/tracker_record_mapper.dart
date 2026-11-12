import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/data/mappers/json_list_parsing.dart';
import 'package:prism_plurality/data/utils/sync_datetime.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart' as domain;

/// Maps `tracker_records` rows ↔ domain models ↔ sync field maps.
class TrackerRecordMapper {
  TrackerRecordMapper._();

  static domain.TrackerRecord toDomain(TrackerRecordRow row) {
    return domain.TrackerRecord(
      id: row.id,
      kind: row.kind,
      parentId: row.parentId,
      title: row.title,
      body: row.body,
      data: row.data,
      tags: parseJsonStringList(row.tags),
      occurredAt: row.occurredAt,
      endedAt: row.endedAt,
      amount: row.amount,
      memberId: row.memberId,
      isPrivate: row.isPrivate,
      isPinned: row.isPinned,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
    );
  }

  static TrackerRecordsCompanion toCompanion(domain.TrackerRecord m) {
    return TrackerRecordsCompanion(
      id: Value(m.id),
      kind: Value(m.kind),
      parentId: Value(m.parentId),
      title: Value(m.title),
      body: Value(m.body),
      data: Value(m.data),
      tags: Value(encodeJsonListOrNull(m.tags)),
      occurredAt: Value(m.occurredAt),
      endedAt: Value(m.endedAt),
      amount: Value(m.amount),
      memberId: Value(m.memberId),
      isPrivate: Value(m.isPrivate),
      isPinned: Value(m.isPinned),
      sortOrder: Value(m.sortOrder),
      createdAt: Value(m.createdAt),
      modifiedAt: Value(m.modifiedAt),
    );
  }

  /// Sync field map for a domain model (what the repository emits).
  static Map<String, dynamic> syncFields(domain.TrackerRecord m) {
    return {
      'kind': m.kind,
      'parent_id': m.parentId,
      'title': m.title,
      'body': m.body,
      'data': m.data,
      'tags': encodeJsonListOrNull(m.tags),
      'occurred_at': toSyncUtcOrNull(m.occurredAt),
      'ended_at': toSyncUtcOrNull(m.endedAt),
      'amount': m.amount,
      'member_id': m.memberId,
      'is_private': m.isPrivate,
      'is_pinned': m.isPinned,
      'sort_order': m.sortOrder,
      'created_at': toSyncUtc(m.createdAt),
      'modified_at': toSyncUtc(m.modifiedAt),
      'is_deleted': false,
    };
  }

  /// Sync field map for a stored row (diffs and the sync adapter).
  static Map<String, dynamic> syncFieldsFromRow(TrackerRecordRow r) => {
    'kind': r.kind,
    'parent_id': r.parentId,
    'title': r.title,
    'body': r.body,
    'data': r.data,
    'tags': r.tags,
    'occurred_at': toSyncUtcOrNull(r.occurredAt),
    'ended_at': toSyncUtcOrNull(r.endedAt),
    'amount': r.amount,
    'member_id': r.memberId,
    'is_private': r.isPrivate,
    'is_pinned': r.isPinned,
    'sort_order': r.sortOrder,
    'created_at': toSyncUtc(r.createdAt),
    'modified_at': toSyncUtc(r.modifiedAt),
    'is_deleted': r.isDeleted,
  };

  /// Partial companion with only the keys present in [fields].
  static TrackerRecordsCompanion partialCompanion(Map<String, dynamic> fields) {
    Value<T> v<T>(String key, T Function(Object? raw) read) =>
        fields.containsKey(key) ? Value(read(fields[key])) : Value<T>.absent();
    return TrackerRecordsCompanion(
      kind: v('kind', (r) => r as String),
      parentId: v('parent_id', (r) => r as String?),
      title: v('title', (r) => r as String),
      body: v('body', (r) => r as String?),
      data: v('data', (r) => r as String?),
      tags: v('tags', (r) => r as String?),
      occurredAt: v('occurred_at', (r) => r == null ? null : parseSyncDateTime(r)),
      endedAt: v('ended_at', (r) => r == null ? null : parseSyncDateTime(r)),
      amount: v('amount', (r) => r as int?),
      memberId: v('member_id', (r) => r as String?),
      isPrivate: v('is_private', (r) => r as bool),
      isPinned: v('is_pinned', (r) => r as bool),
      sortOrder: v('sort_order', (r) => r as int),
      createdAt: v('created_at', parseSyncDateTime),
      modifiedAt: v('modified_at', parseSyncDateTime),
    );
  }
}
