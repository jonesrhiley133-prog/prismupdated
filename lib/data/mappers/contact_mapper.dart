import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/data/mappers/json_list_parsing.dart';
import 'package:prism_plurality/data/utils/sync_datetime.dart';
import 'package:prism_plurality/domain/models/contact.dart' as domain;

/// Maps `contacts` rows ↔ domain models ↔ sync field maps.
class ContactMapper {
  ContactMapper._();

  static domain.Contact toDomain(ContactRow row) {
    return domain.Contact(
      id: row.id,
      displayName: row.displayName,
      phones: parseJsonStringList(row.phones),
      emails: parseJsonStringList(row.emails),
      birthday: row.birthday,
      notes: row.notes,
      source: row.source,
      externalId: row.externalId,
      isFavorite: row.isFavorite,
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
    );
  }

  static ContactsCompanion toCompanion(domain.Contact m) {
    return ContactsCompanion(
      id: Value(m.id),
      displayName: Value(m.displayName),
      phones: Value(encodeJsonListOrNull(m.phones)),
      emails: Value(encodeJsonListOrNull(m.emails)),
      birthday: Value(m.birthday),
      notes: Value(m.notes),
      source: Value(m.source),
      externalId: Value(m.externalId),
      isFavorite: Value(m.isFavorite),
      createdAt: Value(m.createdAt),
      modifiedAt: Value(m.modifiedAt),
    );
  }

  /// Sync field map for a domain model (what the repository emits).
  static Map<String, dynamic> syncFields(domain.Contact m) {
    return {
      'display_name': m.displayName,
      'phones': encodeJsonListOrNull(m.phones),
      'emails': encodeJsonListOrNull(m.emails),
      'birthday': m.birthday,
      'notes': m.notes,
      'source': m.source,
      'external_id': m.externalId,
      'is_favorite': m.isFavorite,
      'created_at': toSyncUtc(m.createdAt),
      'modified_at': toSyncUtc(m.modifiedAt),
      'is_deleted': false,
    };
  }

  /// Sync field map for a stored row (diffs and the sync adapter).
  static Map<String, dynamic> syncFieldsFromRow(ContactRow r) => {
    'display_name': r.displayName,
    'phones': r.phones,
    'emails': r.emails,
    'birthday': r.birthday,
    'notes': r.notes,
    'source': r.source,
    'external_id': r.externalId,
    'is_favorite': r.isFavorite,
    'created_at': toSyncUtc(r.createdAt),
    'modified_at': toSyncUtc(r.modifiedAt),
    'is_deleted': r.isDeleted,
  };

  /// Partial companion with only the keys present in [fields].
  static ContactsCompanion partialCompanion(Map<String, dynamic> fields) {
    Value<T> v<T>(String key, T Function(Object? raw) read) =>
        fields.containsKey(key) ? Value(read(fields[key])) : Value<T>.absent();
    return ContactsCompanion(
      displayName: v('display_name', (r) => r as String),
      phones: v('phones', (r) => r as String?),
      emails: v('emails', (r) => r as String?),
      birthday: v('birthday', (r) => r as String?),
      notes: v('notes', (r) => r as String?),
      source: v('source', (r) => r as String),
      externalId: v('external_id', (r) => r as String?),
      isFavorite: v('is_favorite', (r) => r as bool),
      createdAt: v('created_at', parseSyncDateTime),
      modifiedAt: v('modified_at', parseSyncDateTime),
    );
  }
}
