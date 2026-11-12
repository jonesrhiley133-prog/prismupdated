import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/data/mappers/json_list_parsing.dart';
import 'package:prism_plurality/data/utils/sync_datetime.dart';
import 'package:prism_plurality/domain/models/cycle_entry.dart' as domain;

/// Maps `cycle_entries` rows ↔ domain models ↔ sync field maps.
class CycleEntryMapper {
  CycleEntryMapper._();

  static domain.CycleEntry toDomain(CycleEntryRow row) {
    return domain.CycleEntry(
      id: row.id,
      date: row.date,
      flow: row.flow,
      symptoms: parseJsonStringList(row.symptoms),
      note: row.note,
      memberId: row.memberId,
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
    );
  }

  static CycleEntriesCompanion toCompanion(domain.CycleEntry m) {
    return CycleEntriesCompanion(
      id: Value(m.id),
      date: Value(m.date),
      flow: Value(m.flow),
      symptoms: Value(encodeJsonSetOrNull(m.symptoms)),
      note: Value(m.note),
      memberId: Value(m.memberId),
      createdAt: Value(m.createdAt),
      modifiedAt: Value(m.modifiedAt),
    );
  }

  /// Sync field map for a domain model (what the repository emits).
  static Map<String, dynamic> syncFields(domain.CycleEntry m) {
    return {
      'date': m.date,
      'flow': m.flow,
      'symptoms': encodeJsonSetOrNull(m.symptoms),
      'note': m.note,
      'member_id': m.memberId,
      'created_at': toSyncUtc(m.createdAt),
      'modified_at': toSyncUtc(m.modifiedAt),
      'is_deleted': false,
    };
  }

  /// Sync field map for a stored row (diffs and the sync adapter).
  static Map<String, dynamic> syncFieldsFromRow(CycleEntryRow r) => {
    'date': r.date,
    'flow': r.flow,
    'symptoms': r.symptoms,
    'note': r.note,
    'member_id': r.memberId,
    'created_at': toSyncUtc(r.createdAt),
    'modified_at': toSyncUtc(r.modifiedAt),
    'is_deleted': r.isDeleted,
  };

  /// Partial companion with only the keys present in [fields].
  static CycleEntriesCompanion partialCompanion(Map<String, dynamic> fields) {
    Value<T> v<T>(String key, T Function(Object? raw) read) =>
        fields.containsKey(key) ? Value(read(fields[key])) : Value<T>.absent();
    return CycleEntriesCompanion(
      date: v('date', (r) => r as String),
      flow: v('flow', (r) => r as int),
      symptoms: v('symptoms', (r) => r as String?),
      note: v('note', (r) => r as String?),
      memberId: v('member_id', (r) => r as String?),
      createdAt: v('created_at', parseSyncDateTime),
      modifiedAt: v('modified_at', parseSyncDateTime),
    );
  }
}
