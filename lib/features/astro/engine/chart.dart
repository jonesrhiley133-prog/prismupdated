import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:prism_plurality/features/astro/engine/ephemeris.dart';

bool _tzReady = false;

/// Makes sure the time-zone database is loaded (the app does this at
/// start; tests and isolates may not have).
void ensureTimeZones() {
  if (_tzReady) return;
  try {
    tz.getLocation('Europe/London');
  } catch (_) {
    tzdata.initializeTimeZones();
  }
  _tzReady = true;
}

/// Where someone was born: a named place with coordinates and its IANA time
/// zone (which gives the correct historical UTC offset, daylight saving
/// included).
class BirthPlace {
  const BirthPlace({
    required this.name,
    required this.lat,
    required this.lon,
    required this.timeZone,
  });

  final String name;
  final double lat;
  final double lon;
  final String timeZone;

  Map<String, Object?> toJson() => {
    'name': name,
    'lat': lat,
    'lon': lon,
    'tz': timeZone,
  };

  static BirthPlace? fromJson(Object? v) {
    if (v is! Map) return null;
    final lat = (v['lat'] as num?)?.toDouble();
    final lon = (v['lon'] as num?)?.toDouble();
    final zone = v['tz'] as String?;
    if (lat == null || lon == null || zone == null) return null;
    return BirthPlace(
      name: v['name'] as String? ?? '',
      lat: lat,
      lon: lon,
      timeZone: zone,
    );
  }
}

/// What is known about a birth. Only the month and day are required; each
/// extra piece unlocks more of the chart, and nothing is guessed.
class BirthData {
  const BirthData({
    required this.month,
    required this.day,
    this.year,
    this.hour,
    this.minute,
    this.place,
  });

  final int month;
  final int day;
  final int? year;
  final int? hour;
  final int? minute;
  final BirthPlace? place;

  bool get hasYear => year != null;
  bool get hasTime => hour != null;
  bool get hasPlace => place != null;

  /// Enough for an exact chart: rising sign, houses, the Moon's degree.
  bool get isComplete => hasYear && hasTime && hasPlace;

  /// The birth moment in UTC. Without a time, local noon is used (and the
  /// Moon is flagged where it could be in either of two signs); without a
  /// place, the time can't be placed in UTC so noon UTC is used.
  DateTime get utc {
    final y = year ?? 2001;
    final h = hour ?? 12, mi = hour == null ? 0 : (minute ?? 0);
    final p = place;
    if (p != null) ensureTimeZones();
    if (p != null && hasTime) {
      try {
        return tz.TZDateTime(tz.getLocation(p.timeZone), y, month, day, h, mi)
            .toUtc();
      } catch (_) {}
    }
    if (p != null) {
      try {
        return tz.TZDateTime(tz.getLocation(p.timeZone), y, month, day, 12)
            .toUtc();
      } catch (_) {}
    }
    return DateTime.utc(y, month, day, h, mi);
  }

  /// How far the true moment could be from [utc], in hours.
  double get uncertaintyHours => isComplete || (hasTime && hasPlace)
      ? 0
      : hasTime
      ? 14 // time zone unknown
      : 13; // whole day, any time zone

  BirthData copyWith({
    int? month,
    int? day,
    int? year,
    bool clearYear = false,
    int? hour,
    int? minute,
    bool clearTime = false,
    BirthPlace? place,
    bool clearPlace = false,
  }) => BirthData(
    month: month ?? this.month,
    day: day ?? this.day,
    year: clearYear ? null : (year ?? this.year),
    hour: clearTime ? null : (hour ?? this.hour),
    minute: clearTime ? null : (minute ?? this.minute),
    place: clearPlace ? null : (place ?? this.place),
  );
}

enum AspectType {
  conjunction(0, 8),
  sextile(60, 4),
  square(90, 7),
  trine(120, 7),
  opposition(180, 8);

  const AspectType(this.angle, this.orb);
  final double angle;
  final double orb;

  /// Flowing (true) or tense (false); conjunctions depend on the planets.
  bool? get harmonious => switch (this) {
    sextile || trine => true,
    square || opposition => false,
    conjunction => null,
  };
}

class Aspect {
  const Aspect(this.a, this.b, this.type, this.orb, {this.applying});
  final Body a;
  final Body b;
  final AspectType type;

  /// Distance from exact, degrees.
  final double orb;

  /// For transits: still tightening.
  final bool? applying;

  /// 1 when exact, 0 at the edge of the orb.
  double strength(double maxOrb) => (1 - orb / maxOrb).clamp(0, 1);
}

double _maxOrb(AspectType t, Body a, Body b, {double scale = 1}) {
  var orb = t.orb;
  if (a.isLuminary || b.isLuminary) orb += 2;
  if (a == Body.node || b == Body.node || a == Body.chiron || b == Body.chiron) {
    orb = 3;
  }
  return orb * scale;
}

/// The closest major aspect between two longitudes, if any.
(AspectType, double)? aspectBetween(
  double la,
  double lb,
  Body a,
  Body b, {
  double scale = 1,
}) {
  final sep = angleDiff(la, lb).abs();
  for (final t in AspectType.values) {
    final orb = (sep - t.angle).abs();
    if (orb <= _maxOrb(t, a, b, scale: scale)) return (t, orb);
  }
  return null;
}

/// A natal chart built from whatever birth data exists.
class NatalChart {
  NatalChart._(
    this.birth,
    this.utc,
    this.positions,
    this.angles,
    this.aspects,
    this.uncertainSigns,
  );

  factory NatalChart.of(
    BirthData birth, {
    HouseSystem houses = HouseSystem.placidus,
  }) {
    final utc = birth.utc;
    final positions = positionsAt(utc);
    final p = birth.place;
    final angles = birth.hasTime && birth.hasYear && p != null
        ? anglesAt(utc, p.lat, p.lon, system: houses)
        : null;

    // Bodies whose sign could differ within the uncertainty window.
    final uncertain = <Body, int>{};
    final hrs = birth.uncertaintyHours;
    if (hrs > 0) {
      for (final b in Body.values) {
        final s0 = signOf(longitudeOf(b, utc.subtract(Duration(minutes: (hrs * 60).round()))));
        final s1 = signOf(longitudeOf(b, utc.add(Duration(minutes: (hrs * 60).round()))));
        final s = positions[b]!.sign;
        if (s0 != s || s1 != s) uncertain[b] = s0 != s ? s0 : s1;
      }
    }

    final aspects = <Aspect>[];
    final bodies = Body.values;
    for (var i = 0; i < bodies.length; i++) {
      for (var j = i + 1; j < bodies.length; j++) {
        final a = bodies[i], b = bodies[j];
        // The Moon's aspects are unreliable without a time.
        if (!birth.hasTime && (a == Body.moon || b == Body.moon)) continue;
        if (a == Body.node && b == Body.chiron) continue;
        final hit = aspectBetween(
          positions[a]!.longitude,
          positions[b]!.longitude,
          a,
          b,
        );
        if (hit != null) aspects.add(Aspect(a, b, hit.$1, hit.$2));
      }
    }
    aspects.sort((x, y) => x.orb.compareTo(y.orb));
    return NatalChart._(birth, utc, positions, angles, aspects, uncertain);
  }

  final BirthData birth;
  final DateTime utc;
  final Map<Body, BodyPosition> positions;

  /// Null without a birth time and place.
  final Angles? angles;
  final List<Aspect> aspects;

  /// Bodies that might be in another sign (the other possible sign).
  final Map<Body, int> uncertainSigns;

  int get sunSign => positions[Body.sun]!.sign;
  int get moonSign => positions[Body.moon]!.sign;
  int? get risingSign => angles == null ? null : signOf(angles!.ascendant);

  bool get moonCertain => !uncertainSigns.containsKey(Body.moon);

  int? houseOf(Body b) => angles?.houseOf(positions[b]!.longitude);
}

/// Sun sign from month and day alone (typical dates). Near a cusp the sign
/// depends on the year and time, so the other candidate is returned too.
(int sign, int? cuspWith) sunSignForDate(int month, int day) {
  // Start day of each sign in a typical year: Aries Mar 21 … Pisces Feb 19.
  const starts = [
    (3, 21), (4, 20), (5, 21), (6, 21), (7, 23), (8, 23),
    (9, 23), (10, 23), (11, 22), (12, 22), (1, 20), (2, 19),
  ];
  int dayOfYear(int m, int d) => DateTime.utc(2001, m, d).difference(DateTime.utc(2001)).inDays;
  final x = dayOfYear(month, day);
  var sign = 11;
  var best = -1;
  for (var s = 0; s < 12; s++) {
    final st = dayOfYear(starts[s].$1, starts[s].$2);
    final rel = (x - st) % 365;
    if (best == -1 || rel < best) {
      best = rel;
      sign = s;
    }
  }
  final nextStart = dayOfYear(starts[(sign + 1) % 12].$1, starts[(sign + 1) % 12].$2);
  final toNext = (nextStart - x) % 365;
  if (best == 0) return (sign, (sign + 11) % 12);
  if (toNext == 1) return (sign, (sign + 1) % 12);
  return (sign, null);
}
