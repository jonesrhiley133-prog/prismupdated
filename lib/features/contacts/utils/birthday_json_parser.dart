import 'dart:convert';

import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';

/// How to read dates like `03/04/1990` where day and month are ambiguous.
enum DateOrder { monthFirst, dayFirst }

/// One record found in a birthday export.
class ParsedBirthday {
  const ParsedBirthday({
    required this.index,
    required this.name,
    required this.birthday,
    this.externalId,
    this.error,
    this.ambiguous = false,
    this.rawDate,
  });

  /// Position in the source file (for messages).
  final int index;
  final String? name;
  final BirthdayDate? birthday;
  final String? externalId;

  /// Why this record can't be imported, or null when it's valid.
  final String? error;

  /// The date could be read either day-first or month-first.
  final bool ambiguous;
  final String? rawDate;

  bool get isValid => error == null;
}

/// Result of reading a birthday export.
class BirthdayParseResult {
  const BirthdayParseResult(this.records, {this.fatalError});

  final List<ParsedBirthday> records;

  /// Set when the file isn't JSON or contains no recognisable records.
  final String? fatalError;

  int get ambiguousCount => records.where((r) => r.ambiguous).length;
}

const _nameKeys = [
  'name',
  'fullname',
  'full_name',
  'displayname',
  'display_name',
  'title',
  'person',
  'label',
  'contact',
  'contactname',
  'contact_name',
  'nickname',
];
const _firstKeys = [
  'firstname',
  'first_name',
  'givenname',
  'given_name',
  'first',
];
const _lastKeys = [
  'lastname',
  'last_name',
  'familyname',
  'family_name',
  'surname',
  'last',
];
const _dateKeys = [
  'birthday',
  'birthdate',
  'birth_date',
  'dateofbirth',
  'date_of_birth',
  'dob',
  'bday',
  'date',
  'birth',
  'born',
  'anniversary_date',
  'event_date',
];
const _idKeys = ['id', 'uuid', 'uid', 'identifier', 'contactid', 'contact_id'];

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  // Spanish
  'ene': 1, 'abr': 4, 'ago': 8, 'dic': 12,
};

/// Reads birthdays from a JSON export of another birthday app.
///
/// Accepts a top-level list of records, or an object whose first list-of-
/// objects value holds them (`{"birthdays": [...]}`, `{"data": [...]}` …).
/// Field names are matched case-insensitively against common spellings,
/// and nested objects (e.g. `{"person": {"name": …}}`) are searched one
/// level deep.
BirthdayParseResult parseBirthdayJson(
  String source, {
  DateOrder order = DateOrder.monthFirst,
}) {
  Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    return const BirthdayParseResult([], fatalError: 'not_json');
  }
  final list = _findRecords(decoded);
  if (list == null || list.isEmpty) {
    return const BirthdayParseResult([], fatalError: 'no_records');
  }
  final out = <ParsedBirthday>[];
  for (var i = 0; i < list.length; i++) {
    final raw = list[i];
    if (raw is! Map) {
      out.add(
        ParsedBirthday(
          index: i,
          name: null,
          birthday: null,
          error: 'not_an_object',
        ),
      );
      continue;
    }
    out.add(_parseRecord(i, _flatten(raw), order));
  }
  return BirthdayParseResult(out);
}

List<Object?>? _findRecords(Object? decoded) {
  if (decoded is List) return decoded;
  if (decoded is Map) {
    // Prefer well-known keys, then any list of maps.
    for (final k in [
      'birthdays',
      'contacts',
      'people',
      'persons',
      'data',
      'items',
      'entries',
      'events',
      'records',
    ]) {
      for (final e in decoded.entries) {
        if (e.key.toString().toLowerCase() == k && e.value is List) {
          return e.value as List;
        }
      }
    }
    for (final v in decoded.values) {
      if (v is List && v.isNotEmpty && v.first is Map) return v;
    }
    // A single record.
    if (decoded.keys.any(
      (k) => _dateKeys.contains(k.toString().toLowerCase()),
    )) {
      return [decoded];
    }
  }
  return null;
}

/// Lower-cased keys, with one level of nested objects merged in.
Map<String, Object?> _flatten(Map raw) {
  final out = <String, Object?>{};
  for (final e in raw.entries) {
    final key = e.key.toString().toLowerCase();
    if (e.value is Map) {
      for (final n in (e.value as Map).entries) {
        out.putIfAbsent(n.key.toString().toLowerCase(), () => n.value);
      }
    }
    out[key] = e.value;
  }
  return out;
}

String? _string(Object? v) {
  if (v is String && v.trim().isNotEmpty) return v.trim();
  if (v is num) return v.toString();
  return null;
}

ParsedBirthday _parseRecord(int i, Map<String, Object?> r, DateOrder order) {
  String? name;
  for (final k in _nameKeys) {
    if (r[k] is String && (r[k] as String).trim().isNotEmpty) {
      name = (r[k] as String).trim();
      break;
    }
  }
  if (name == null) {
    final first = _firstKeys
        .map((k) => _string(r[k]))
        .whereType<String>()
        .firstOrNull;
    final last = _lastKeys
        .map((k) => _string(r[k]))
        .whereType<String>()
        .firstOrNull;
    final joined = [?first, ?last].join(' ').trim();
    if (joined.isNotEmpty) name = joined;
  }
  final id = _idKeys.map((k) => _string(r[k])).whereType<String>().firstOrNull;

  BirthdayDate? date;
  var ambiguous = false;
  String? rawDate;
  for (final k in _dateKeys) {
    final v = r[k];
    if (v == null) continue;
    final (d, amb) = parseLooseDate(v, order: order);
    rawDate = v.toString();
    if (d != null) {
      date = d;
      ambiguous = amb;
      break;
    }
  }
  // Separate day / month / year fields.
  if (date == null) {
    final day = _int(r['day'] ?? r['birthday_day'] ?? r['bday_day']);
    final month = _month(r['month'] ?? r['birthday_month'] ?? r['bday_month']);
    final year = _int(r['year'] ?? r['birthday_year'] ?? r['bday_year']);
    if (day != null && month != null) {
      date = BirthdayDate(
        month,
        day,
        (year == null || year == 0) ? null : year,
      );
      rawDate = '$day/$month${year == null ? '' : '/$year'}';
    }
  }

  String? error;
  if (name == null) {
    error = 'missing_name';
  } else if (date == null) {
    error = rawDate == null ? 'missing_date' : 'unreadable_date';
  } else if (!date.isValid) {
    error = 'invalid_date';
  }
  return ParsedBirthday(
    index: i,
    name: name,
    birthday: date,
    externalId: id,
    error: error,
    ambiguous: error == null && ambiguous,
    rawDate: rawDate,
  );
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

int? _month(Object? v) {
  final n = _int(v);
  if (n != null) return n;
  if (v is String && v.length >= 3) {
    return _months[v.trim().toLowerCase().substring(0, 3)];
  }
  return null;
}

/// Parses many date spellings. Returns the date (which may still be an
/// impossible one, e.g. Feb 30; check [BirthdayDate.isValid]) and whether
/// the day/month order was ambiguous.
(BirthdayDate?, bool) parseLooseDate(
  Object value, {
  DateOrder order = DateOrder.monthFirst,
}) {
  // Epoch numbers: seconds or milliseconds.
  if (value is num) {
    final n = value.toInt();
    final ms = n.abs() > 100000000000 ? n : n * 1000;
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return (BirthdayDate(d.month, d.day, d.year), false);
  }
  if (value is! String) return (null, false);
  final s = value.trim();
  if (s.isEmpty) return (null, false);

  // ISO with optional time: 1990-04-02, 1990-04-02T00:00:00Z, 1990/04/02.
  var m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(s);
  if (m != null) {
    final y = int.parse(m.group(1)!);
    return (
      BirthdayDate(
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        (y == 0 || y == 1 || y == BirthdayDate.noYear) ? null : y,
      ),
      false,
    );
  }
  // Year-less: --04-02 (vCard / ISO), 04-02.
  m = RegExp(r'^-{0,2}(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (m != null) {
    return (
      BirthdayDate(int.parse(m.group(1)!), int.parse(m.group(2)!)),
      false,
    );
  }
  // vCard 4.0 year-less compact: --0402.
  m = RegExp(r'^--(\d{2})(\d{2})$').firstMatch(s);
  if (m != null) {
    return (
      BirthdayDate(int.parse(m.group(1)!), int.parse(m.group(2)!)),
      false,
    );
  }
  // Compact: 19900402.
  m = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(s);
  if (m != null) {
    return (
      BirthdayDate(
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(1)!),
      ),
      false,
    );
  }
  // Numeric with separators: 02/04/1990, 2.4.1990, 04/02 (no year).
  m = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})(?:[/.\-](\d{2,4}))?$').firstMatch(s);
  if (m != null) {
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    int? y = m.group(3) == null ? null : int.parse(m.group(3)!);
    if (y != null && y < 100) {
      y += y > (DateTime.now().year % 100) ? 1900 : 2000;
    }
    // A dot separator is almost always day-first (European).
    final dotted = s.contains('.');
    bool dayFirst;
    var ambiguous = false;
    if (a > 12 && b <= 12) {
      dayFirst = true;
    } else if (b > 12 && a <= 12) {
      dayFirst = false;
    } else {
      dayFirst = dotted || order == DateOrder.dayFirst;
      ambiguous = !dotted && a != b;
    }
    return (
      dayFirst ? BirthdayDate(b, a, y) : BirthdayDate(a, b, y),
      ambiguous,
    );
  }
  // Written month: "April 2, 1990", "2 April 1990", "Apr 2".
  m = RegExp(
    r'^([A-Za-z]{3,})\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?$',
  ).firstMatch(s);
  if (m != null) {
    final mon = _months[m.group(1)!.toLowerCase().substring(0, 3)];
    if (mon != null) {
      return (
        BirthdayDate(
          mon,
          int.parse(m.group(2)!),
          m.group(3) == null ? null : int.parse(m.group(3)!),
        ),
        false,
      );
    }
  }
  m = RegExp(
    r'^(\d{1,2})(?:st|nd|rd|th)?\s+(?:de\s+)?([A-Za-z]{3,})\.?(?:,?\s+(?:de\s+)?(\d{4}))?$',
  ).firstMatch(s);
  if (m != null) {
    final mon = _months[m.group(2)!.toLowerCase().substring(0, 3)];
    if (mon != null) {
      return (
        BirthdayDate(
          mon,
          int.parse(m.group(1)!),
          m.group(3) == null ? null : int.parse(m.group(3)!),
        ),
        false,
      );
    }
  }
  return (null, false);
}
