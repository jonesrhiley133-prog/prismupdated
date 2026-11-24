/// Holiday calendar: dates are computed (fixed days, "nth weekday" rules,
/// Easter) so it works offline for any year. Lunar-calendar holidays use a
/// table of expected dates and may differ by a day where you live.
library;

enum HolidayCategory {
  public('Public holidays', '🏛️'),
  observance('Observances', '📅'),
  cultural('Cultural', '🎉'),
  religious('Religious', '🕯️'),
  awareness('Awareness days', '🎗️');

  const HolidayCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// Countries with public-holiday rules. Days without a country list apply
/// everywhere.
const holidayCountries = <String, String>{
  'US': 'United States',
  'CA': 'Canada',
  'GB': 'United Kingdom',
  'IE': 'Ireland',
  'AU': 'Australia',
  'NZ': 'New Zealand',
  'MX': 'Mexico',
  'ES': 'Spain',
};

class Holiday {
  const Holiday(
    this.id,
    this.name,
    this.emoji,
    this.category,
    this.dateFor, {
    this.countries = const {},
    this.approximate = false,
  });
  final String id;
  final String name;
  final String emoji;
  final HolidayCategory category;
  final DateTime? Function(int year) dateFor;
  final Set<String> countries;

  /// Date follows a lunar calendar and may vary by a day locally.
  final bool approximate;

  bool appliesTo(String country) =>
      countries.isEmpty || countries.contains(country);
}

/// The [n]th [weekday] (DateTime.monday…sunday) of [month]; n = -1 is the last.
DateTime nthWeekday(int year, int month, int weekday, int n) {
  if (n < 0) {
    var d = DateTime(year, month + 1, 0);
    while (d.weekday != weekday) {
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return d;
  }
  var d = DateTime(year, month, 1);
  while (d.weekday != weekday) {
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return DateTime(d.year, d.month, d.day + 7 * (n - 1));
}

/// Western (Gregorian) Easter Sunday.
DateTime easterSunday(int year) {
  final a = year % 19, b = year ~/ 100, c = year % 100;
  final d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

DateTime? Function(int) _fixed(int month, int day) =>
    (y) => DateTime(y, month, day);
DateTime? Function(int) _nth(int month, int weekday, int n) =>
    (y) => nthWeekday(y, month, weekday, n);
DateTime? Function(int) _easter(int offset) => (y) {
  final e = easterSunday(y);
  return DateTime(e.year, e.month, e.day + offset);
};
DateTime? Function(int) _table(Map<int, String> t) => (y) {
  final s = t[y];
  if (s == null) return null;
  final p = s.split('-');
  return DateTime(y, int.parse(p[0]), int.parse(p[1]));
};

const _mon = DateTime.monday, _thu = DateTime.thursday, _sun = DateTime.sunday;

final List<Holiday> allHolidays = [
  // Everywhere
  Holiday(
    'new_year',
    "New Year's Day",
    '🎆',
    HolidayCategory.public,
    _fixed(1, 1),
  ),
  Holiday(
    'valentines',
    "Valentine's Day",
    '💝',
    HolidayCategory.observance,
    _fixed(2, 14),
  ),
  Holiday(
    'st_patrick',
    "St. Patrick's Day",
    '☘️',
    HolidayCategory.cultural,
    _fixed(3, 17),
  ),
  Holiday(
    'earth_day',
    'Earth Day',
    '🌍',
    HolidayCategory.observance,
    _fixed(4, 22),
  ),
  Holiday(
    'halloween',
    'Halloween',
    '🎃',
    HolidayCategory.cultural,
    _fixed(10, 31),
  ),
  Holiday(
    'dia_muertos',
    'Día de Muertos',
    '💀',
    HolidayCategory.cultural,
    _fixed(11, 2),
  ),
  Holiday(
    'nye',
    "New Year's Eve",
    '🥂',
    HolidayCategory.observance,
    _fixed(12, 31),
  ),
  // Religious
  Holiday(
    'good_friday',
    'Good Friday',
    '✝️',
    HolidayCategory.religious,
    _easter(-2),
  ),
  Holiday(
    'easter',
    'Easter Sunday',
    '🐣',
    HolidayCategory.religious,
    _easter(0),
  ),
  Holiday(
    'christmas_eve',
    'Christmas Eve',
    '🎄',
    HolidayCategory.religious,
    _fixed(12, 24),
  ),
  Holiday(
    'christmas',
    'Christmas Day',
    '🎄',
    HolidayCategory.religious,
    _fixed(12, 25),
  ),
  Holiday(
    'lunar_new_year',
    'Lunar New Year',
    '🧧',
    HolidayCategory.cultural,
    approximate: true,
    _table({
      2025: '1-29',
      2026: '2-17',
      2027: '2-6',
      2028: '1-26',
      2029: '2-13',
      2030: '2-3',
      2031: '1-23',
      2032: '2-11',
      2033: '1-31',
      2034: '2-19',
      2035: '2-8',
    }),
  ),
  Holiday(
    'diwali',
    'Diwali',
    '🪔',
    HolidayCategory.religious,
    approximate: true,
    _table({
      2025: '10-20',
      2026: '11-8',
      2027: '10-29',
      2028: '10-17',
      2029: '11-5',
      2030: '10-26',
    }),
  ),
  Holiday(
    'hanukkah',
    'Hanukkah begins (evening)',
    '🕎',
    HolidayCategory.religious,
    approximate: true,
    _table({
      2025: '12-14',
      2026: '12-4',
      2027: '12-24',
      2028: '12-12',
      2029: '12-1',
      2030: '12-20',
    }),
  ),
  Holiday(
    'rosh_hashanah',
    'Rosh Hashanah begins (evening)',
    '🍎',
    HolidayCategory.religious,
    approximate: true,
    _table({
      2025: '9-22',
      2026: '9-11',
      2027: '10-1',
      2028: '9-20',
      2029: '9-9',
      2030: '9-27',
    }),
  ),
  Holiday(
    'eid_al_fitr',
    'Eid al-Fitr',
    '🌙',
    HolidayCategory.religious,
    approximate: true,
    _table({
      2025: '3-30',
      2026: '3-20',
      2027: '3-9',
      2028: '2-26',
      2029: '2-14',
      2030: '2-4',
    }),
  ),
  // Awareness
  Holiday(
    'did_awareness',
    'DID Awareness Day',
    '🌈',
    HolidayCategory.awareness,
    _fixed(3, 5),
  ),
  Holiday(
    'tdov',
    'Trans Day of Visibility',
    '🏳️‍⚧️',
    HolidayCategory.awareness,
    _fixed(3, 31),
  ),
  Holiday(
    'mh_month',
    'Mental Health Awareness Month begins',
    '💚',
    HolidayCategory.awareness,
    _fixed(5, 1),
  ),
  Holiday(
    'pride_month',
    'Pride Month begins',
    '🏳️‍🌈',
    HolidayCategory.awareness,
    _fixed(6, 1),
  ),
  Holiday(
    'suicide_prevention',
    'World Suicide Prevention Day',
    '🎗️',
    HolidayCategory.awareness,
    _fixed(9, 10),
  ),
  Holiday(
    'world_mh_day',
    'World Mental Health Day',
    '💚',
    HolidayCategory.awareness,
    _fixed(10, 10),
  ),
  Holiday(
    'tdor',
    'Trans Day of Remembrance',
    '🕯️',
    HolidayCategory.awareness,
    _fixed(11, 20),
  ),
  // United States
  Holiday(
    'mlk',
    'Martin Luther King Jr. Day',
    '✊',
    HolidayCategory.public,
    _nth(1, _mon, 3),
    countries: {'US'},
  ),
  Holiday(
    'presidents',
    "Presidents' Day",
    '🇺🇸',
    HolidayCategory.public,
    _nth(2, _mon, 3),
    countries: {'US'},
  ),
  Holiday(
    'memorial',
    'Memorial Day',
    '🇺🇸',
    HolidayCategory.public,
    _nth(5, _mon, -1),
    countries: {'US'},
  ),
  Holiday(
    'juneteenth',
    'Juneteenth',
    '✊🏿',
    HolidayCategory.public,
    _fixed(6, 19),
    countries: {'US'},
  ),
  Holiday(
    'us_independence',
    'Independence Day',
    '🎆',
    HolidayCategory.public,
    _fixed(7, 4),
    countries: {'US'},
  ),
  Holiday(
    'labor_day',
    'Labor Day',
    '🛠️',
    HolidayCategory.public,
    _nth(9, _mon, 1),
    countries: {'US', 'CA'},
  ),
  Holiday(
    'veterans',
    'Veterans Day',
    '🎖️',
    HolidayCategory.public,
    _fixed(11, 11),
    countries: {'US'},
  ),
  Holiday(
    'us_thanksgiving',
    'Thanksgiving',
    '🦃',
    HolidayCategory.public,
    _nth(11, _thu, 4),
    countries: {'US'},
  ),
  // Canada
  Holiday(
    'family_day',
    'Family Day',
    '👪',
    HolidayCategory.public,
    _nth(2, _mon, 3),
    countries: {'CA'},
  ),
  Holiday('victoria_day', 'Victoria Day', '🇨🇦', HolidayCategory.public, (y) {
    var d = DateTime(y, 5, 24);
    while (d.weekday != _mon) {
      d = DateTime(y, 5, d.day - 1);
    }
    return d;
  }, countries: {'CA'}),
  Holiday(
    'canada_day',
    'Canada Day',
    '🍁',
    HolidayCategory.public,
    _fixed(7, 1),
    countries: {'CA'},
  ),
  Holiday(
    'ca_thanksgiving',
    'Thanksgiving',
    '🦃',
    HolidayCategory.public,
    _nth(10, _mon, 2),
    countries: {'CA'},
  ),
  Holiday(
    'remembrance',
    'Remembrance Day',
    '🌺',
    HolidayCategory.public,
    _fixed(11, 11),
    countries: {'CA', 'GB', 'AU', 'NZ'},
  ),
  // UK, Ireland, Australia, New Zealand
  Holiday(
    'easter_monday',
    'Easter Monday',
    '🐣',
    HolidayCategory.public,
    _easter(1),
    countries: {'GB', 'IE', 'AU', 'NZ', 'CA', 'ES'},
  ),
  Holiday(
    'early_may',
    'Early May bank holiday',
    '🌷',
    HolidayCategory.public,
    _nth(5, _mon, 1),
    countries: {'GB', 'IE'},
  ),
  Holiday(
    'spring_bank',
    'Spring bank holiday',
    '🌸',
    HolidayCategory.public,
    _nth(5, _mon, -1),
    countries: {'GB'},
  ),
  Holiday(
    'summer_bank',
    'Summer bank holiday',
    '☀️',
    HolidayCategory.public,
    _nth(8, _mon, -1),
    countries: {'GB'},
  ),
  Holiday(
    'boxing_day',
    'Boxing Day',
    '🎁',
    HolidayCategory.public,
    _fixed(12, 26),
    countries: {'GB', 'IE', 'CA', 'AU', 'NZ'},
  ),
  Holiday(
    'australia_day',
    'Australia Day',
    '🇦🇺',
    HolidayCategory.public,
    _fixed(1, 26),
    countries: {'AU'},
  ),
  Holiday(
    'waitangi',
    'Waitangi Day',
    '🇳🇿',
    HolidayCategory.public,
    _fixed(2, 6),
    countries: {'NZ'},
  ),
  Holiday(
    'anzac',
    'ANZAC Day',
    '🌺',
    HolidayCategory.public,
    _fixed(4, 25),
    countries: {'AU', 'NZ'},
  ),
  Holiday(
    'nz_labour',
    'Labour Day',
    '🛠️',
    HolidayCategory.public,
    _nth(10, _mon, 4),
    countries: {'NZ'},
  ),
  // Mexico & Spain
  Holiday(
    'mx_independence',
    'Día de la Independencia',
    '🇲🇽',
    HolidayCategory.public,
    _fixed(9, 16),
    countries: {'MX'},
  ),
  Holiday(
    'mx_revolution',
    'Día de la Revolución',
    '🇲🇽',
    HolidayCategory.public,
    _nth(11, _mon, 3),
    countries: {'MX'},
  ),
  Holiday(
    'es_national',
    'Fiesta Nacional de España',
    '🇪🇸',
    HolidayCategory.public,
    _fixed(10, 12),
    countries: {'ES'},
  ),
  Holiday(
    'epiphany',
    'Epiphany (Día de Reyes)',
    '👑',
    HolidayCategory.religious,
    _fixed(1, 6),
    countries: {'ES', 'MX'},
  ),
  // Parents' days, by country
  Holiday(
    'mothers_day',
    "Mother's Day",
    '💐',
    HolidayCategory.observance,
    _nth(5, _sun, 2),
    countries: {'US', 'CA', 'AU', 'NZ'},
  ),
  Holiday(
    'mothering_sunday',
    'Mothering Sunday',
    '💐',
    HolidayCategory.observance,
    _easter(-21),
    countries: {'GB', 'IE'},
  ),
  Holiday(
    'mx_mothers',
    'Día de las Madres',
    '💐',
    HolidayCategory.observance,
    _fixed(5, 10),
    countries: {'MX'},
  ),
  Holiday(
    'es_mothers',
    'Día de la Madre',
    '💐',
    HolidayCategory.observance,
    _nth(5, _sun, 1),
    countries: {'ES'},
  ),
  Holiday(
    'fathers_day',
    "Father's Day",
    '👔',
    HolidayCategory.observance,
    _nth(6, _sun, 3),
    countries: {'US', 'CA', 'GB', 'IE', 'MX'},
  ),
  Holiday(
    'au_fathers',
    "Father's Day",
    '👔',
    HolidayCategory.observance,
    _nth(9, _sun, 1),
    countries: {'AU', 'NZ'},
  ),
  Holiday(
    'es_fathers',
    'Día del Padre',
    '👔',
    HolidayCategory.observance,
    _fixed(3, 19),
    countries: {'ES'},
  ),
];

/// Holidays falling within [from, to) for [country] and the enabled
/// [categories], minus individually [disabled] ones, sorted by date.
List<(Holiday, DateTime)> holidaysBetween(
  DateTime from,
  DateTime to, {
  required String country,
  required Set<HolidayCategory> categories,
  Set<String> disabled = const {},
}) {
  final out = <(Holiday, DateTime)>[];
  for (var y = from.year; y <= to.year; y++) {
    for (final h in allHolidays) {
      if (!h.appliesTo(country) ||
          !categories.contains(h.category) ||
          disabled.contains(h.id))
        continue;
      final d = h.dateFor(y);
      if (d == null ||
          d.isBefore(DateTime(from.year, from.month, from.day)) ||
          !d.isBefore(to))
        continue;
      out.add((h, d));
    }
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}
