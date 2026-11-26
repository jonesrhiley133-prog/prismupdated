import 'dart:math' as math;

/// Planetary positions computed on the device (no network, no data files).
///
/// Orbital elements and perturbation terms follow Paul Schlyter's "How to
/// compute planetary positions": accurate to a few arcminutes for the Sun,
/// Moon and planets between roughly 1900 and 2100 — far finer than the one
/// degree that matters for a sign, house or aspect. Pluto uses Schlyter's
/// fitted series (1885–2099). Chiron uses fixed Keplerian elements and is
/// marked approximate. Positions are tropical, geocentric ecliptic longitudes
/// of date.
enum Body {
  sun,
  moon,
  mercury,
  venus,
  mars,
  jupiter,
  saturn,
  uranus,
  neptune,
  pluto,
  node,
  chiron;

  bool get isLuminary => this == sun || this == moon;

  /// Personal planets move fast enough to colour a single day.
  bool get isPersonal => index <= mars.index;

  /// Shown with an "approximate" note.
  bool get approximate => this == chiron;

  /// Can appear retrograde.
  bool get canRetrograde => !isLuminary && this != node;
}

/// One body's position at a moment.
class BodyPosition {
  const BodyPosition(this.body, this.longitude, this.latitude, this.speed);

  final Body body;

  /// Ecliptic longitude, degrees 0–360 (0 = 0° Aries).
  final double longitude;

  /// Ecliptic latitude, degrees.
  final double latitude;

  /// Degrees per day; negative while retrograde.
  final double speed;

  bool get retrograde => speed < 0 && body.canRetrograde;

  /// 0 = Aries … 11 = Pisces.
  int get sign => signOf(longitude);

  /// Degrees within the sign, 0–30.
  double get degreeInSign => longitude % 30;
}

int signOf(double longitude) => (norm360(longitude) ~/ 30) % 12;

double norm360(double x) {
  final r = x % 360;
  return r < 0 ? r + 360 : r;
}

/// Signed difference a − b in (−180, 180].
double angleDiff(double a, double b) {
  var d = norm360(a - b);
  if (d > 180) d -= 360;
  return d;
}

const _rad = math.pi / 180;
double _sin(double d) => math.sin(d * _rad);
double _cos(double d) => math.cos(d * _rad);
double _atan2d(double y, double x) => math.atan2(y, x) / _rad;

/// Julian day for a UTC moment.
double julianDay(DateTime utc) {
  final u = utc.toUtc();
  return u.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
}

DateTime fromJulianDay(double jd) => DateTime.fromMillisecondsSinceEpoch(
  ((jd - 2440587.5) * 86400000.0).round(),
  isUtc: true,
);

/// Schlyter's day number: days since 2000 Jan 0.0 UT.
double _dayNumber(DateTime utc) => julianDay(utc) - 2451543.5;

/// Obliquity of the ecliptic, degrees.
double obliquity(DateTime utc) => 23.4393 - 3.563e-7 * _dayNumber(utc);

/// Greenwich mean sidereal time, degrees.
double gmst(DateTime utc) {
  final jd = julianDay(utc);
  final t = (jd - 2451545.0) / 36525.0;
  return norm360(
    280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        0.000387933 * t * t -
        t * t * t / 38710000.0,
  );
}

class _Elements {
  const _Elements(this.n, this.i, this.w, this.a, this.e, this.m);
  final double n, i, w, a, e, m;
}

_Elements _elements(Body b, double d) => switch (b) {
  Body.sun => _Elements(
    0,
    0,
    282.9404 + 4.70935e-5 * d,
    1.0,
    0.016709 - 1.151e-9 * d,
    356.0470 + 0.9856002585 * d,
  ),
  Body.moon => _Elements(
    125.1228 - 0.0529538083 * d,
    5.1454,
    318.0634 + 0.1643573223 * d,
    60.2666,
    0.054900,
    115.3654 + 13.0649929509 * d,
  ),
  Body.mercury => _Elements(
    48.3313 + 3.24587e-5 * d,
    7.0047 + 5.00e-8 * d,
    29.1241 + 1.01444e-5 * d,
    0.387098,
    0.205635 + 5.59e-10 * d,
    168.6562 + 4.0923344368 * d,
  ),
  Body.venus => _Elements(
    76.6799 + 2.46590e-5 * d,
    3.3946 + 2.75e-8 * d,
    54.8910 + 1.38374e-5 * d,
    0.723330,
    0.006773 - 1.302e-9 * d,
    48.0052 + 1.6021302244 * d,
  ),
  Body.mars => _Elements(
    49.5574 + 2.11081e-5 * d,
    1.8497 - 1.78e-8 * d,
    286.5016 + 2.92961e-5 * d,
    1.523688,
    0.093405 + 2.516e-9 * d,
    18.6021 + 0.5240207766 * d,
  ),
  Body.jupiter => _Elements(
    100.4542 + 2.76854e-5 * d,
    1.3030 - 1.557e-7 * d,
    273.8777 + 1.64505e-5 * d,
    5.20256,
    0.048498 + 4.469e-9 * d,
    19.8950 + 0.0830853001 * d,
  ),
  Body.saturn => _Elements(
    113.6634 + 2.38980e-5 * d,
    2.4886 - 1.081e-7 * d,
    339.3939 + 2.97661e-5 * d,
    9.55475,
    0.055546 - 9.499e-9 * d,
    316.9670 + 0.0334442282 * d,
  ),
  Body.uranus => _Elements(
    74.0005 + 1.3978e-5 * d,
    0.7733 + 1.9e-8 * d,
    96.6612 + 3.0565e-5 * d,
    19.18171 - 1.55e-8 * d,
    0.047318 + 7.45e-9 * d,
    142.5905 + 0.011725806 * d,
  ),
  Body.neptune => _Elements(
    131.7806 + 3.0173e-5 * d,
    1.7700 - 2.55e-7 * d,
    272.8461 - 6.027e-6 * d,
    30.05826 + 3.313e-8 * d,
    0.008606 + 2.15e-9 * d,
    260.2471 + 0.005995147 * d,
  ),
  // Chiron: osculating elements near its 1996 perihelion; mean motion from
  // the semi-major axis. Good to a degree or two over recent decades.
  Body.chiron => _Elements(
    209.38 + 3.82394e-5 * d,
    6.93,
    339.43,
    13.70,
    0.3831,
    (0.9856076686 / math.pow(13.70, 1.5)) * (d - (2450128.4 - 2451543.5)),
  ),
  _ => throw ArgumentError(b),
};

/// Eccentric anomaly by Newton iteration (degrees).
double _eccentric(double m, double e) {
  final mr = norm360(m) * _rad;
  var ea = mr + e * math.sin(mr) * (1 + e * math.cos(mr));
  for (var k = 0; k < 30; k++) {
    final delta = (ea - e * math.sin(ea) - mr) / (1 - e * math.cos(ea));
    ea -= delta;
    if (delta.abs() < 1e-12) break;
  }
  return ea / _rad;
}

/// Heliocentric (geocentric for Sun/Moon) ecliptic rectangular coords.
({double x, double y, double z}) _orbit(_Elements el) {
  final ea = _eccentric(el.m, el.e);
  final xv = el.a * (_cos(ea) - el.e);
  final yv = el.a * math.sqrt(1 - el.e * el.e) * _sin(ea);
  final v = _atan2d(yv, xv);
  final r = math.sqrt(xv * xv + yv * yv);
  final vw = v + el.w;
  return (
    x: r * (_cos(el.n) * _cos(vw) - _sin(el.n) * _sin(vw) * _cos(el.i)),
    y: r * (_sin(el.n) * _cos(vw) + _cos(el.n) * _sin(vw) * _cos(el.i)),
    z: r * _sin(vw) * _sin(el.i),
  );
}

/// Geocentric apparent ecliptic (longitude, latitude) at day number [d]:
/// adds nutation in longitude (and aberration for the Sun) so sign changes
/// line up with published ephemerides to within about ten minutes.
(double, double) _geocentric(Body b, double d) {
  final (lon, lat) = _geometric(b, d);
  final omega = 125.04452 - 0.0529537648 * d;
  final lSun = 280.4665 + 0.98564736 * d;
  var dpsi = (-17.20 * _sin(omega) - 1.32 * _sin(2 * lSun)) / 3600;
  if (b == Body.sun) dpsi -= 20.4898 / 3600; // aberration
  return (norm360(lon + dpsi), lat);
}

(double, double) _geometric(Body b, double d) {
  if (b == Body.node) {
    return (norm360(125.1228 - 0.0529538083 * d), 0);
  }
  final sunEl = _elements(Body.sun, d);
  final sun = _orbit(sunEl);
  if (b == Body.sun) return (norm360(_atan2d(sun.y, sun.x)), 0);

  if (b == Body.moon) {
    final m = _elements(Body.moon, d);
    final p = _orbit(m);
    var lon = _atan2d(p.y, p.x);
    var lat = _atan2d(p.z, math.sqrt(p.x * p.x + p.y * p.y));
    final ms = sunEl.m, mm = m.m;
    final ls = sunEl.m + sunEl.w;
    final lm = m.m + m.w + m.n;
    final dd = lm - ls, f = lm - m.n;
    lon +=
        -1.274 * _sin(mm - 2 * dd) +
        0.658 * _sin(2 * dd) -
        0.186 * _sin(ms) -
        0.059 * _sin(2 * mm - 2 * dd) -
        0.057 * _sin(mm - 2 * dd + ms) +
        0.053 * _sin(mm + 2 * dd) +
        0.046 * _sin(2 * dd - ms) +
        0.041 * _sin(mm - ms) -
        0.035 * _sin(dd) -
        0.031 * _sin(mm + ms) -
        0.015 * _sin(2 * f - 2 * dd) +
        0.011 * _sin(mm - 4 * dd);
    lat +=
        -0.173 * _sin(f - 2 * dd) -
        0.055 * _sin(mm - f - 2 * dd) -
        0.046 * _sin(mm + f - 2 * dd) +
        0.033 * _sin(f + 2 * dd) +
        0.017 * _sin(2 * mm + f);
    return (norm360(lon), lat);
  }

  double hx, hy, hz;
  if (b == Body.pluto) {
    final s = 50.03 + 0.033459652 * d;
    final p = 238.95 + 0.003968789 * d;
    final lon =
        238.9508 +
        0.00400703 * d -
        19.799 * _sin(p) +
        19.848 * _cos(p) +
        0.897 * _sin(2 * p) -
        4.956 * _cos(2 * p) +
        0.610 * _sin(3 * p) +
        1.211 * _cos(3 * p) -
        0.341 * _sin(4 * p) -
        0.190 * _cos(4 * p) +
        0.128 * _sin(5 * p) -
        0.034 * _cos(5 * p) -
        0.038 * _sin(6 * p) +
        0.031 * _cos(6 * p) +
        0.020 * _sin(s - p) -
        0.010 * _cos(s - p); // Already includes precession.
    final lat =
        -3.9082 -
        5.453 * _sin(p) -
        14.975 * _cos(p) +
        3.527 * _sin(2 * p) +
        1.673 * _cos(2 * p) -
        1.051 * _sin(3 * p) +
        0.328 * _cos(3 * p) +
        0.179 * _sin(4 * p) -
        0.292 * _cos(4 * p) +
        0.019 * _sin(5 * p) +
        0.100 * _cos(5 * p) -
        0.031 * _sin(6 * p) -
        0.026 * _cos(6 * p) +
        0.011 * _cos(s - p);
    final r =
        40.72 +
        6.68 * _sin(p) +
        6.90 * _cos(p) -
        1.18 * _sin(2 * p) -
        0.03 * _cos(2 * p) +
        0.15 * _sin(3 * p) -
        0.14 * _cos(3 * p);
    hx = r * _cos(lon) * _cos(lat);
    hy = r * _sin(lon) * _cos(lat);
    hz = r * _sin(lat);
  } else {
    final el = _elements(b, d);
    final p = _orbit(el);
    var lon = _atan2d(p.y, p.x);
    var lat = _atan2d(p.z, math.sqrt(p.x * p.x + p.y * p.y));
    final r = math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
    if (b == Body.jupiter || b == Body.saturn || b == Body.uranus) {
      final mj = _elements(Body.jupiter, d).m;
      final ms = _elements(Body.saturn, d).m;
      final mu = _elements(Body.uranus, d).m;
      if (b == Body.jupiter) {
        lon +=
            -0.332 * _sin(2 * mj - 5 * ms - 67.6) -
            0.056 * _sin(2 * mj - 2 * ms + 21) +
            0.042 * _sin(3 * mj - 5 * ms + 21) -
            0.036 * _sin(mj - 2 * ms) +
            0.022 * _cos(mj - ms) +
            0.023 * _sin(2 * mj - 3 * ms + 52) -
            0.016 * _sin(mj - 5 * ms - 69);
      } else if (b == Body.saturn) {
        lon +=
            0.812 * _sin(2 * mj - 5 * ms - 67.6) -
            0.229 * _cos(2 * mj - 4 * ms - 2) +
            0.119 * _sin(mj - 2 * ms - 3) +
            0.046 * _sin(2 * mj - 6 * ms - 69) +
            0.014 * _sin(mj - 3 * ms + 32);
        lat +=
            -0.020 * _cos(2 * mj - 4 * ms - 2) +
            0.018 * _sin(2 * mj - 6 * ms - 49);
      } else {
        lon +=
            0.040 * _sin(ms - 2 * mu + 6) +
            0.035 * _sin(ms - 3 * mu + 33) -
            0.015 * _sin(mj - mu + 20);
      }
    }
    hx = r * _cos(lon) * _cos(lat);
    hy = r * _sin(lon) * _cos(lat);
    hz = r * _sin(lat);
  }
  // Heliocentric → geocentric: add the Earth→Sun vector.
  final gx = hx + sun.x, gy = hy + sun.y, gz = hz;
  return (norm360(_atan2d(gy, gx)), _atan2d(gz, math.sqrt(gx * gx + gy * gy)));
}

/// Position of [body] at [utc], with daily motion.
BodyPosition positionOf(Body body, DateTime utc) {
  final d = _dayNumber(utc);
  final (lon, lat) = _geocentric(body, d);
  final step = body == Body.moon ? 0.05 : 0.5;
  final (a, _) = _geocentric(body, d - step);
  final (b, _) = _geocentric(body, d + step);
  return BodyPosition(body, lon, lat, angleDiff(b, a) / (2 * step));
}

/// Fast longitude-only lookup for searches.
double longitudeOf(Body body, DateTime utc) =>
    _geocentric(body, _dayNumber(utc)).$1;

/// Every body at [utc].
Map<Body, BodyPosition> positionsAt(DateTime utc) => {
  for (final b in Body.values) b: positionOf(b, utc),
};

/// Angle Moon − Sun, 0–360 (0 new, 90 first quarter, 180 full).
double moonElongation(DateTime utc) =>
    norm360(longitudeOf(Body.moon, utc) - longitudeOf(Body.sun, utc));

/// Fraction of the Moon's disc lit, 0–1.
double moonIllumination(DateTime utc) => (1 - _cos(moonElongation(utc))) / 2;

// ---------------------------------------------------------------------------
// Angles and houses
// ---------------------------------------------------------------------------

enum HouseSystem { placidus, wholeSign, equal }

class Angles {
  const Angles({
    required this.ascendant,
    required this.midheaven,
    required this.cusps,
    required this.system,
  });

  final double ascendant;
  final double midheaven;

  /// Twelve cusps, house 1 first.
  final List<double> cusps;

  /// May differ from the requested system near the poles (Placidus is
  /// undefined there; Porphyry-style equal division is used instead).
  final HouseSystem system;

  /// House (1–12) holding [longitude].
  int houseOf(double longitude) {
    for (var h = 0; h < 12; h++) {
      final start = cusps[h], end = cusps[(h + 1) % 12];
      final span = norm360(end - start);
      if (norm360(longitude - start) < span) return h + 1;
    }
    return 1;
  }
}

/// Ascendant, Midheaven and house cusps for a moment and place.
/// [lat] north positive, [lon] east positive.
Angles anglesAt(
  DateTime utc,
  double lat,
  double lon, {
  HouseSystem system = HouseSystem.placidus,
}) {
  final eps = obliquity(utc);
  final ramc = norm360(gmst(utc) + lon);
  final mc = norm360(_atan2d(_sin(ramc), _cos(ramc) * _cos(eps)));
  var asc = norm360(
    _atan2d(
      _cos(ramc),
      -(_sin(ramc) * _cos(eps) + math.tan(lat * _rad) * _sin(eps)),
    ),
  );
  // The ascendant is always within 180° ahead of the MC.
  if (norm360(asc - mc) > 180) asc = norm360(asc + 180);

  List<double> cusps;
  var used = system;
  switch (system) {
    case HouseSystem.wholeSign:
      final first = (asc ~/ 30) * 30.0;
      cusps = [for (var h = 0; h < 12; h++) norm360(first + 30.0 * h)];
    case HouseSystem.equal:
      cusps = [for (var h = 0; h < 12; h++) norm360(asc + 30.0 * h)];
    case HouseSystem.placidus:
      final p = _placidus(ramc, mc, asc, lat, eps);
      if (p == null) {
        used = HouseSystem.equal;
        cusps = _porphyry(mc, asc);
      } else {
        cusps = p;
      }
  }
  return Angles(ascendant: asc, midheaven: mc, cusps: cusps, system: used);
}

List<double> _porphyry(double mc, double asc) {
  final q1 = norm360(asc - mc) / 3; // MC → ASC
  final q2 = (180 - norm360(asc - mc)) / 3; // ASC → IC
  final c = List<double>.filled(12, 0);
  c[9] = mc;
  c[10] = norm360(mc + q1);
  c[11] = norm360(mc + 2 * q1);
  c[0] = asc;
  c[1] = norm360(asc + q2);
  c[2] = norm360(asc + 2 * q2);
  for (var h = 0; h < 6; h++) {
    c[(h + 3) % 12] = norm360(c[(h + 9) % 12] + 180);
  }
  return c;
}

/// Placidus cusps by bisection on each point's position along its own
/// diurnal/nocturnal semi-arc. Null where the system is undefined.
List<double>? _placidus(
  double ramc,
  double mc,
  double asc,
  double lat,
  double eps,
) {
  final tanLat = math.tan(lat * _rad);
  // Placidus time 0 (MC) … 3 (ASC) … 6 (IC) for an ecliptic point.
  double? placidusTime(double lambda) {
    final ra = norm360(_atan2d(_sin(lambda) * _cos(eps), _cos(lambda)));
    final dec = math.asin(_sin(eps) * _sin(lambda)) / _rad;
    final x = -tanLat * math.tan(dec * _rad);
    if (x.abs() > 1) return null;
    final dsa = math.acos(x) / _rad;
    final nsa = 180 - dsa;
    final h = norm360(ra - ramc);
    if (h <= dsa) return 3 * h / dsa;
    if (h <= dsa + nsa) return 3 + 3 * (h - dsa) / nsa;
    return null;
  }

  double? solve(double target) {
    var lo = 0.0, hi = 180.0; // offset from MC
    for (var k = 0; k < 60; k++) {
      final mid = (lo + hi) / 2;
      final t = placidusTime(norm360(mc + mid));
      if (t == null) return null;
      if (t < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return norm360(mc + (lo + hi) / 2);
  }

  final c11 = solve(1), c12 = solve(2), c2 = solve(4), c3 = solve(5);
  if (c11 == null || c12 == null || c2 == null || c3 == null) return null;
  final c = List<double>.filled(12, 0);
  c[9] = mc;
  c[10] = c11;
  c[11] = c12;
  c[0] = asc;
  c[1] = c2;
  c[2] = c3;
  for (var h = 0; h < 6; h++) {
    c[(h + 3) % 12] = norm360(c[(h + 9) % 12] + 180);
  }
  return c;
}
