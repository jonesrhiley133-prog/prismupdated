import 'package:prism_plurality/features/astro/engine/ephemeris.dart';

/// The eight traditional phases.
enum MoonPhase {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  fullMoon,
  waningGibbous,
  lastQuarter,
  waningCrescent;

  String get glyph => const ['🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'][index];

  bool get principal => index.isEven;
}

enum Eclipse { none, solar, lunar }

/// An exact principal phase.
class Lunation {
  const Lunation(this.phase, this.utc, this.longitude, this.eclipse);
  final MoonPhase phase;
  final DateTime utc;

  /// The Moon's longitude at that moment.
  final double longitude;
  final Eclipse eclipse;

  int get sign => signOf(longitude);
}

/// A body changing sign.
class Ingress {
  const Ingress(this.body, this.utc, this.sign, {this.retrograde = false});
  final Body body;
  final DateTime utc;

  /// The sign entered.
  final int sign;
  final bool retrograde;
}

/// A planet appearing to stop and turn.
class Station {
  const Station(this.body, this.utc, this.longitude, {required this.toRetrograde});
  final Body body;
  final DateTime utc;
  final double longitude;
  final bool toRetrograde;
}

/// Bisection for the moment f crosses zero between [a] and [b].
DateTime _root(DateTime a, DateTime b, double Function(DateTime) f) {
  var lo = a, hi = b;
  final flo = f(lo);
  for (var k = 0; k < 40; k++) {
    final mid = lo.add(Duration(milliseconds: hi.difference(lo).inMilliseconds ~/ 2));
    final fm = f(mid);
    if ((fm < 0) == (flo < 0)) {
      lo = mid;
    } else {
      hi = mid;
    }
    if (hi.difference(lo).inSeconds < 30) break;
  }
  return lo;
}

/// Principal lunations between [from] and [to].
List<Lunation> lunations(DateTime from, DateTime to) {
  final out = <Lunation>[];
  const step = Duration(hours: 12);
  var t = from.toUtc();
  var prev = moonElongation(t);
  while (t.isBefore(to)) {
    final next = t.add(step);
    final cur = moonElongation(next);
    for (var q = 0; q < 4; q++) {
      final target = q * 90.0;
      final a = angleDiff(prev, target), b = angleDiff(cur, target);
      if (a < 0 && b >= 0 && (b - a) < 90) {
        final when = _root(t, next, (x) => angleDiff(moonElongation(x), target));
        if (!when.isBefore(from) && when.isBefore(to)) {
          final moon = positionOf(Body.moon, when);
          var eclipse = Eclipse.none;
          if (q == 0 && moon.latitude.abs() < 1.4) eclipse = Eclipse.solar;
          if (q == 2 && moon.latitude.abs() < 1.0) eclipse = Eclipse.lunar;
          out.add(Lunation(MoonPhase.values[q * 2], when, moon.longitude, eclipse));
        }
      }
    }
    prev = cur;
    t = next;
  }
  return out;
}

/// Sign changes of [body] between [from] and [to].
List<Ingress> ingresses(Body body, DateTime from, DateTime to) {
  final step = switch (body) {
    Body.moon => const Duration(hours: 3),
    Body.sun || Body.mercury || Body.venus => const Duration(hours: 12),
    _ => const Duration(days: 1),
  };
  final out = <Ingress>[];
  var t = from.toUtc();
  var prev = longitudeOf(body, t);
  while (t.isBefore(to)) {
    final next = t.add(step);
    final cur = longitudeOf(body, next);
    if (signOf(cur) != signOf(prev)) {
      final forward = angleDiff(cur, prev) > 0;
      final boundary = forward ? (signOf(cur) * 30.0) : (signOf(prev) * 30.0);
      final when = _root(t, next, (x) => angleDiff(longitudeOf(body, x), boundary));
      if (!when.isBefore(from) && when.isBefore(to)) {
        out.add(Ingress(body, when, signOf(cur), retrograde: !forward));
      }
    }
    prev = cur;
    t = next;
  }
  return out;
}

/// Retrograde and direct stations of [body] between [from] and [to].
List<Station> stations(Body body, DateTime from, DateTime to) {
  if (!body.canRetrograde) return const [];
  final out = <Station>[];
  double speed(DateTime x) => positionOf(body, x).speed;
  var t = from.toUtc();
  var prev = speed(t);
  while (t.isBefore(to)) {
    final next = t.add(const Duration(days: 1));
    final cur = speed(next);
    if ((prev < 0) != (cur < 0)) {
      final when = _root(t, next, speed);
      out.add(
        Station(body, when, longitudeOf(body, when), toRetrograde: cur < 0),
      );
    }
    prev = cur;
    t = next;
  }
  return out;
}

/// The phase shown for a local calendar day: a principal phase if one
/// happens that day, otherwise the in-between phase at local noon.
MoonPhase phaseForDay(DateTime localDay, {List<Lunation>? known}) {
  final start = DateTime(localDay.year, localDay.month, localDay.day);
  final end = start.add(const Duration(days: 1));
  final list = known ?? lunations(start.subtract(const Duration(hours: 1)), end);
  for (final l in list) {
    final local = l.utc.toLocal();
    if (!local.isBefore(start) && local.isBefore(end)) return l.phase;
  }
  final e = moonElongation(start.add(const Duration(hours: 12)).toUtc());
  if (e < 90) return MoonPhase.waxingCrescent;
  if (e < 180) return MoonPhase.waxingGibbous;
  if (e < 270) return MoonPhase.waningGibbous;
  return MoonPhase.waningCrescent;
}

/// The Moon's sign through a local day: the sign at the start, and the
/// sign it moves into (with the time) if it changes that day.
({int sign, int? nextSign, DateTime? changeAt}) moonSignForDay(DateTime localDay) {
  final start = DateTime(localDay.year, localDay.month, localDay.day);
  final end = start.add(const Duration(days: 1));
  final s = signOf(longitudeOf(Body.moon, start.toUtc()));
  final ing = ingresses(Body.moon, start.toUtc(), end.toUtc());
  if (ing.isEmpty) return (sign: s, nextSign: null, changeAt: null);
  return (sign: s, nextSign: ing.first.sign, changeAt: ing.first.utc.toLocal());
}
