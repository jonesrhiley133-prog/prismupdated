import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/data/utils/sync_datetime.dart';
import 'package:prism_plurality/domain/models/location.dart' as domain;

/// Maps `saved_locations` rows ↔ domain models ↔ sync field maps.
class SavedLocationMapper {
  SavedLocationMapper._();

  static domain.SavedLocation toDomain(SavedLocationRow row) {
    return domain.SavedLocation(
      id: row.id,
      name: row.name,
      emoji: row.emoji,
      colorHex: row.colorHex,
      address: row.address,
      notes: row.notes,
      isFavorite: row.isFavorite,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
    );
  }

  static SavedLocationsCompanion toCompanion(domain.SavedLocation m) {
    return SavedLocationsCompanion(
      id: Value(m.id),
      name: Value(m.name),
      emoji: Value(m.emoji),
      colorHex: Value(m.colorHex),
      address: Value(m.address),
      notes: Value(m.notes),
      isFavorite: Value(m.isFavorite),
      sortOrder: Value(m.sortOrder),
      createdAt: Value(m.createdAt),
      modifiedAt: Value(m.modifiedAt),
    );
  }

  /// Sync field map for a domain model (what the repository emits).
  static Map<String, dynamic> syncFields(domain.SavedLocation m) {
    return {
      'name': m.name,
      'emoji': m.emoji,
      'color_hex': m.colorHex,
      'address': m.address,
      'notes': m.notes,
      'is_favorite': m.isFavorite,
      'sort_order': m.sortOrder,
      'created_at': toSyncUtc(m.createdAt),
      'modified_at': toSyncUtc(m.modifiedAt),
      'is_deleted': false,
    };
  }

  /// Sync field map for a stored row (diffs and the sync adapter).
  static Map<String, dynamic> syncFieldsFromRow(SavedLocationRow r) => {
    'name': r.name,
    'emoji': r.emoji,
    'color_hex': r.colorHex,
    'address': r.address,
    'notes': r.notes,
    'is_favorite': r.isFavorite,
    'sort_order': r.sortOrder,
    'created_at': toSyncUtc(r.createdAt),
    'modified_at': toSyncUtc(r.modifiedAt),
    'is_deleted': r.isDeleted,
  };

  /// Partial companion with only the keys present in [fields].
  static SavedLocationsCompanion partialCompanion(Map<String, dynamic> fields) {
    Value<T> v<T>(String key, T Function(Object? raw) read) =>
        fields.containsKey(key) ? Value(read(fields[key])) : Value<T>.absent();
    return SavedLocationsCompanion(
      name: v('name', (r) => r as String),
      emoji: v('emoji', (r) => r as String?),
      colorHex: v('color_hex', (r) => r as String?),
      address: v('address', (r) => r as String?),
      notes: v('notes', (r) => r as String?),
      isFavorite: v('is_favorite', (r) => r as bool),
      sortOrder: v('sort_order', (r) => r as int),
      createdAt: v('created_at', parseSyncDateTime),
      modifiedAt: v('modified_at', parseSyncDateTime),
    );
  }
}
