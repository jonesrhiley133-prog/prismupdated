import 'dart:convert';

/// Defensive decoders for JSON-list columns.
///
/// A single malformed row from a peer device must not crash a screen, so
/// these return an empty list (never throw) for null, malformed JSON, or a
/// non-list payload, and silently drop elements of the wrong type.
List<String> parseJsonStringList(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final v in decoded)
        if (v is String && v.isNotEmpty) v,
    ];
  } catch (_) {
    return const [];
  }
}

List<int> parseJsonIntList(String? raw, {int? min, int? max}) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final v in decoded)
        if (v is int && (min == null || v >= min) && (max == null || v <= max))
          v,
    ];
  } catch (_) {
    return const [];
  }
}

/// Encodes a set-semantic list as sorted, de-duplicated JSON, or null when
/// empty, so equal sets always produce byte-identical strings.
String? encodeJsonSetOrNull<T extends Comparable<T>>(Iterable<T> values) {
  final unique = values.toSet().toList()..sort();
  if (unique.isEmpty) return null;
  return jsonEncode(unique);
}
