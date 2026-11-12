import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracker_record.freezed.dart';
part 'tracker_record.g.dart';

/// See `TrackerRecords` for the meaning of each field.
@freezed
abstract class TrackerRecord with _$TrackerRecord {
  const TrackerRecord._();

  const factory TrackerRecord({
    required String id,
    required String kind,
    String? parentId,
    @Default('') String title,
    String? body,
    String? data,
    @Default(<String>[]) List<String> tags,
    DateTime? occurredAt,
    DateTime? endedAt,
    int? amount,
    String? memberId,
    @Default(false) bool isPrivate,
    @Default(false) bool isPinned,
    @Default(0) int sortOrder,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) = _TrackerRecord;

  factory TrackerRecord.fromJson(Map<String, dynamic> json) =>
      _$TrackerRecordFromJson(json);

  /// [data] decoded; an empty map when absent or unreadable.
  Map<String, dynamic> get fields {
    final d = data;
    if (d == null || d.isEmpty) return const {};
    try {
      final v = jsonDecode(d);
      return v is Map<String, dynamic> ? v : const {};
    } on FormatException {
      return const {};
    }
  }

  String? str(String key) {
    final v = fields[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  int? integer(String key) {
    final v = fields[key];
    return v is int ? v : (v is num ? v.round() : null);
  }

  double? number(String key) {
    final v = fields[key];
    return v is num ? v.toDouble() : null;
  }

  bool flag(String key) => fields[key] == true;

  List<String> strings(String key) {
    final v = fields[key];
    return v is List ? [for (final x in v) if (x is String) x] : const [];
  }

  /// Returns a copy with [changes] merged into [data] (null values remove a
  /// key).
  TrackerRecord withFields(Map<String, Object?> changes) {
    final next = Map<String, dynamic>.of(fields);
    changes.forEach((k, v) => v == null ? next.remove(k) : next[k] = v);
    return copyWith(data: next.isEmpty ? null : jsonEncode(next));
  }
}
