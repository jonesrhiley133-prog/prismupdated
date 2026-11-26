import 'package:flutter/foundation.dart';

/// Where someone is, for holidays and seasons that depend on place.
enum SeasonalRegion {
  global('Anywhere', 'Cualquier lugar'),
  northAmerica('North America', 'Norteamérica'),
  latinAmerica('Latin America', 'Latinoamérica'),
  europe('Europe', 'Europa'),
  eastAsia('East Asia', 'Asia oriental'),
  southAsia('South Asia', 'Asia meridional'),
  southeastAsia('Southeast Asia', 'Sudeste asiático'),
  middleEast('Middle East & North Africa', 'Oriente Medio y norte de África'),
  africa('Sub-Saharan Africa', 'África subsahariana'),
  oceania('Oceania', 'Oceanía');

  const SeasonalRegion(this.en, this.es);
  final String en, es;
}

enum Hemisphere { auto, north, south }

/// A date range, inclusive of both days.
@immutable
class DayRange {
  const DayRange(this.start, this.end);
  final DateTime start, end;

  bool contains(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  int get days => end.difference(start).inDays + 1;

  DayRange shifted({int before = 0, int after = 0}) => DayRange(
    start.subtract(Duration(days: before)),
    end.add(Duration(days: after)),
  );

  @override
  String toString() => '$start → $end';
}

DateTime _d(int y, int m, int d) => DateTime(y, m, d);
DateTime _add(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Western (Gregorian) Easter Sunday.
DateTime easterSunday(int y) {
  final a = y % 19, b = y ~/ 100, c = y % 100, d = b ~/ 4, e = b % 4;
  final f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return _d(y, month, day);
}

/// n-th [weekday] (1 = Monday … 7 = Sunday) of [month].
DateTime nthWeekday(int y, int month, int weekday, int n) {
  final first = _d(y, month, 1);
  final offset = (weekday - first.weekday) % 7;
  return _d(y, month, 1 + offset + (n - 1) * 7);
}

// ── Lunar new year family (tables; the lunar calendar can't be derived
//    from a simple rule, so these are published dates) ─────────────────

const _lunarNewYear = <int, (int, int)>{
  2024: (2, 10),
  2025: (1, 29),
  2026: (2, 17),
  2027: (2, 6),
  2028: (1, 26),
  2029: (2, 13),
  2030: (2, 3),
  2031: (1, 23),
  2032: (2, 11),
  2033: (1, 31),
  2034: (2, 19),
  2035: (2, 8),
  2036: (1, 28),
  2037: (2, 15),
  2038: (2, 4),
  2039: (1, 24),
  2040: (2, 12),
  2041: (2, 1),
  2042: (1, 22),
  2043: (2, 10),
  2044: (1, 30),
  2045: (2, 17),
  2046: (2, 6),
  2047: (1, 26),
  2048: (2, 14),
  2049: (2, 2),
  2050: (1, 23),
};

const _midAutumn = <int, (int, int)>{
  2024: (9, 17),
  2025: (10, 6),
  2026: (9, 25),
  2027: (9, 15),
  2028: (10, 3),
  2029: (9, 22),
  2030: (9, 12),
  2031: (10, 1),
  2032: (9, 19),
  2033: (9, 8),
  2034: (9, 27),
  2035: (9, 16),
  2036: (10, 4),
  2037: (9, 24),
  2038: (9, 13),
  2039: (10, 2),
  2040: (9, 20),
};

const _diwali = <int, (int, int)>{
  2024: (11, 1),
  2025: (10, 20),
  2026: (11, 8),
  2027: (10, 29),
  2028: (10, 17),
  2029: (11, 5),
  2030: (10, 26),
  2031: (11, 14),
  2032: (11, 2),
  2033: (10, 22),
  2034: (11, 10),
  2035: (10, 30),
  2036: (10, 19),
};

const _holi = <int, (int, int)>{
  2024: (3, 25),
  2025: (3, 14),
  2026: (3, 4),
  2027: (3, 22),
  2028: (3, 11),
  2029: (3, 1),
  2030: (3, 20),
  2031: (3, 9),
  2032: (3, 25),
  2033: (3, 14),
  2034: (3, 4),
  2035: (3, 23),
  2036: (3, 12),
};

DateTime? _fromTable(Map<int, (int, int)> t, int y) {
  final v = t[y];
  return v == null ? null : _d(y, v.$1, v.$2);
}

DateTime? lunarNewYear(int y) => _fromTable(_lunarNewYear, y);
DateTime? midAutumnFestival(int y) => _fromTable(_midAutumn, y);
DateTime? diwaliDate(int y) => _fromTable(_diwali, y);
DateTime? holiDate(int y) => _fromTable(_holi, y);

// ── Hebrew calendar (exact arithmetic) ────────────────────────────────

const _hebrewEpoch = -1373427; // R.D. of 1 Tishri, year 1

int _rdFromDate(DateTime d) =>
    DateTime.utc(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime.utc(1, 1, 1)).inDays +
    1;

DateTime _dateFromRd(int rd) {
  final u = DateTime.utc(1, 1, 1).add(Duration(days: rd - 1));
  return DateTime(u.year, u.month, u.day);
}

int _hebrewElapsedDays(int year) {
  final monthsElapsed = (235 * year - 234) ~/ 19;
  final partsElapsed = 12084 + 13753 * monthsElapsed;
  var day = 29 * monthsElapsed + partsElapsed ~/ 25920;
  if ((3 * (day + 1)) % 7 < 3) day++;
  return day;
}

int _hebrewNewYearDelay(int year) {
  final ny0 = _hebrewElapsedDays(year - 1),
      ny1 = _hebrewElapsedDays(year),
      ny2 = _hebrewElapsedDays(year + 1);
  if (ny2 - ny1 == 356) return 2;
  if (ny1 - ny0 == 382) return 1;
  return 0;
}

int _hebrewNewYear(int year) =>
    _hebrewEpoch + _hebrewElapsedDays(year) + _hebrewNewYearDelay(year);

/// 25 Kislev: the first day of Hanukkah (the first candle is lit the
/// evening before).
DateTime hanukkahStart(int gregorianYear) {
  final hy = gregorianYear + 3761;
  final ny = _hebrewNewYear(hy);
  final len = _hebrewNewYear(hy + 1) - ny;
  final heshvan = (len % 10 == 5) ? 30 : 29;
  return _dateFromRd(ny + 30 + heshvan + 24);
}

// ── Islamic calendar (tabular; matches observed dates within a day or two)

int _islamicToRd(int y, int m, int d) =>
    d +
    29 * (m - 1) +
    (m / 2).floor() +
    (y - 1) * 354 +
    ((3 + 11 * y) / 30).floor() +
    227014;

DateTime _islamic(int hy, int m, int d) => _dateFromRd(_islamicToRd(hy, m, d));

/// 1 Ramadan, 1 Shawwal (Eid al-Fitr) or 10 Dhu al-Hijjah (Eid al-Adha)
/// that falls in Gregorian [y]. Approximate: real dates depend on moon
/// sighting.
DateTime? islamicDateIn(int y, int month, int day) {
  final guess = ((y - 622) * 33 / 32).floor();
  for (final hy in [guess - 1, guess, guess + 1, guess + 2]) {
    final d = _islamic(hy, month, day);
    if (d.year == y) return d;
  }
  return null;
}

// ── Seasons ───────────────────────────────────────────────────────────

Hemisphere resolveHemisphere(Hemisphere h, SeasonalRegion r) {
  if (h != Hemisphere.auto) return h;
  return r == SeasonalRegion.oceania ? Hemisphere.south : Hemisphere.north;
}

/// Meteorological seasons, flipped for the southern hemisphere.
DayRange? seasonRange(String season, int y, Hemisphere hemi) {
  final south = hemi == Hemisphere.south;
  String s = season;
  if (south) {
    s = switch (season) {
      'spring' => 'autumn',
      'summer' => 'winter',
      'autumn' => 'spring',
      _ => 'summer',
    };
  }
  switch (s) {
    case 'spring':
      return DayRange(_d(y, 3, 1), _d(y, 5, 31));
    case 'summer':
      return DayRange(_d(y, 6, 1), _d(y, 8, 31));
    case 'autumn':
      return DayRange(_d(y, 9, 1), _d(y, 11, 30));
    default:
      // Winter straddles the new year: pick the stretch that touches [y].
      return DayRange(_d(y, 12, 1), _d(y + 1, 2, 28));
  }
}

/// The range a collection is "in season" for the year containing [on].
/// Returns the range nearest to [on] (this year's or the adjacent one).
class SeasonalWindows {
  const SeasonalWindows._();

  /// Collections whose windows can span new year need the previous year too.
  static List<DayRange> candidates(
    String id,
    int year, {
    SeasonalRegion region = SeasonalRegion.global,
    Hemisphere hemisphere = Hemisphere.auto,
  }) {
    final out = <DayRange>[];
    for (final y in [year - 1, year, year + 1]) {
      final r = windowFor(id, y, region: region, hemisphere: hemisphere);
      if (r != null) out.add(r);
    }
    return out;
  }

  /// The default window for collection [id] in [year], or null when no date
  /// is known (outside the published tables, for lunar holidays).
  static DayRange? windowFor(
    String id,
    int year, {
    SeasonalRegion region = SeasonalRegion.global,
    Hemisphere hemisphere = Hemisphere.auto,
  }) {
    final y = year;
    DayRange around(DateTime? d, int before, int after) => d == null
        ? throw StateError('')
        : DayRange(_add(d, -before), _add(d, after));
    try {
      switch (id) {
        case 'christmas':
          return DayRange(_d(y, 12, 1), _d(y, 12, 26));
        case 'halloween':
          return DayRange(_d(y, 10, 1), _d(y, 11, 1));
        case 'thanksgiving':
          final day =
              region == SeasonalRegion.northAmerica ||
                  region == SeasonalRegion.global
              ? nthWeekday(y, 11, 4, 4)
              : nthWeekday(y, 10, 1, 2);
          return DayRange(_add(day, -7), _add(day, 1));
        case 'nye':
          return DayRange(_d(y, 12, 26), _d(y, 12, 31));
        case 'newyear':
          return DayRange(_d(y, 1, 1), _d(y, 1, 3));
        case 'valentine':
          return DayRange(_d(y, 2, 7), _d(y, 2, 14));
        case 'easter':
          final e = easterSunday(y);
          return DayRange(_add(e, -14), _add(e, 1));
        case 'lunarnewyear':
          return around(lunarNewYear(y), 14, 15);
        case 'midautumn':
          return around(midAutumnFestival(y), 7, 1);
        case 'chuseok':
          return around(midAutumnFestival(y), 7, 2);
        case 'seollal':
          return around(lunarNewYear(y), 3, 3);
        case 'diwali':
          return around(diwaliDate(y), 7, 3);
        case 'holi':
          return around(holiDate(y), 2, 1);
        case 'ramadan':
          final r = islamicDateIn(y, 9, 1);
          return r == null ? null : DayRange(r, _add(r, 29));
        case 'eidfitr':
          final r = islamicDateIn(y, 10, 1);
          return r == null ? null : DayRange(r, _add(r, 3));
        case 'eidadha':
          final r = islamicDateIn(y, 12, 10);
          return r == null ? null : DayRange(_add(r, -1), _add(r, 3));
        case 'hanukkah':
          final h = hanukkahStart(y);
          return DayRange(_add(h, -1), _add(h, 7));
        case 'kwanzaa':
          return DayRange(_d(y, 12, 26), _d(y + 1, 1, 1));
        case 'diademuertos':
          return DayRange(_d(y, 10, 28), _d(y, 11, 2));
        case 'mardigras':
          final e = easterSunday(y);
          return DayRange(_d(y, 1, 6), _add(e, -47));
        case 'carnival':
          final e = easterSunday(y);
          return DayRange(_add(e, -54), _add(e, -46));
        case 'stpatricks':
          return DayRange(_d(y, 3, 10), _d(y, 3, 17));
        case 'pride':
          return DayRange(_d(y, 6, 1), _d(y, 6, 30));
        case 'childrensday':
          final day = switch (region) {
            SeasonalRegion.eastAsia => _d(y, 5, 5),
            SeasonalRegion.southAsia => _d(y, 11, 14),
            SeasonalRegion.latinAmerica => _d(y, 4, 30),
            SeasonalRegion.middleEast => _d(y, 4, 23),
            _ => _d(y, 6, 1),
          };
          return DayRange(_add(day, -3), day);
        case 'earthday':
          return DayRange(_d(y, 4, 15), _d(y, 4, 22));
        case 'cherryblossom':
          final south =
              resolveHemisphere(hemisphere, region) == Hemisphere.south;
          return south
              ? DayRange(_d(y, 9, 10), _d(y, 10, 15))
              : DayRange(_d(y, 3, 15), _d(y, 4, 25));
        case 'spring' || 'summer' || 'autumn' || 'winter':
          return seasonRange(id, y, resolveHemisphere(hemisphere, region));
        case 'rainy':
          return switch (region) {
            SeasonalRegion.eastAsia => DayRange(_d(y, 6, 7), _d(y, 7, 19)),
            SeasonalRegion.southAsia ||
            SeasonalRegion.southeastAsia => DayRange(_d(y, 6, 1), _d(y, 9, 30)),
            SeasonalRegion.africa => DayRange(_d(y, 4, 1), _d(y, 6, 30)),
            SeasonalRegion.oceania => DayRange(_d(y, 12, 1), _d(y + 1, 3, 31)),
            _ => DayRange(_d(y, 4, 1), _d(y, 5, 15)),
          };
        case 'monsoon':
          return switch (region) {
            SeasonalRegion.southeastAsia => DayRange(
              _d(y, 5, 15),
              _d(y, 10, 15),
            ),
            SeasonalRegion.africa => DayRange(_d(y, 6, 1), _d(y, 9, 30)),
            SeasonalRegion.oceania => DayRange(_d(y, 12, 1), _d(y + 1, 3, 31)),
            _ => DayRange(_d(y, 6, 1), _d(y, 9, 30)),
          };
      }
    } on StateError {
      return null;
    }
    return null;
  }
}
