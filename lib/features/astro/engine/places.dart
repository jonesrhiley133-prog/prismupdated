import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:prism_plurality/features/astro/engine/chart.dart';

/// A city from the bundled GeoNames list (34k places with 15,000+ people).
/// Everything stays on the device: searching never sends the birthplace
/// anywhere.
class City {
  const City({
    required this.name,
    required this.ascii,
    required this.country,
    required this.region,
    required this.lat,
    required this.lon,
    required this.timeZone,
    required this.population,
  });

  final String name;
  final String ascii;
  final String country;
  final String region;
  final double lat;
  final double lon;
  final String timeZone;
  final int population;

  String get label => [
    name,
    if (region.isNotEmpty && region != name) region,
    country,
  ].join(', ');

  BirthPlace toPlace() =>
      BirthPlace(name: label, lat: lat, lon: lon, timeZone: timeZone);
}

/// Lower-case and strip common accents so "Sao Paulo" finds "São Paulo".
String foldForSearch(String s) {
  const from = 'áàâäãåāăąçćčďéèêëēėęěğíìîïīįıłńñňóòôöõøōőřśšşťúùûüūůűųýÿźżžßæœ';
  const to = 'aaaaaaaaacccdeeeeeeeegiiiiiiilnnnooooooooorssstuuuuuuuuyyzzzsae';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString();
}

class CityIndex {
  CityIndex._(this.cities, this._folded);

  final List<City> cities;
  final List<String> _folded;

  static CityIndex? _cache;
  static Future<CityIndex>? _loading;

  /// Loads the bundled list once.
  static Future<CityIndex> load([AssetBundle? bundle]) {
    if (_cache != null) return Future.value(_cache);
    return _loading ??= (bundle ?? rootBundle)
        .loadString('assets/astro/cities.tsv')
        .then((text) => _cache = parse(text));
  }

  @visibleForTesting
  static CityIndex parse(String text) {
    final lines = text.split('\n');
    var i = 0;
    while (lines[i].startsWith('#')) {
      i++;
    }
    final zones = lines[i++].split('|');
    final countries = {
      for (final p in lines[i++].split('|'))
        if (p.contains('='))
          p.substring(0, p.indexOf('=')): p.substring(p.indexOf('=') + 1),
    };
    final regions = {
      for (final p in lines[i++].split('|'))
        if (p.contains('='))
          p.substring(0, p.indexOf('=')): p.substring(p.indexOf('=') + 1),
    };
    final cities = <City>[];
    final folded = <String>[];
    for (; i < lines.length; i++) {
      final f = lines[i].split('\t');
      if (f.length < 8) continue;
      final city = City(
        name: f[0],
        ascii: f[1].isEmpty ? f[0] : f[1],
        country: countries[f[2]] ?? f[2],
        region: regions['${f[2]}.${f[3]}'] ?? '',
        lat: double.parse(f[4]),
        lon: double.parse(f[5]),
        timeZone: zones[int.parse(f[6])],
        population: int.parse(f[7]),
      );
      cities.add(city);
      folded.add(foldForSearch('${city.name}|${city.ascii}'));
    }
    return CityIndex._(cities, folded);
  }

  /// Best matches for [query]: names starting with it first (largest
  /// places first), then names containing it. "Paris, France" narrows by
  /// region or country after the comma.
  List<City> search(String query, {int limit = 25}) {
    final parts = query.split(',');
    final q = foldForSearch(parts.first.trim());
    final rest = parts.length > 1
        ? foldForSearch(parts.sublist(1).join(',').trim())
        : '';
    if (q.length < 2) return const [];
    final starts = <City>[], contains = <City>[];
    for (var i = 0; i < cities.length; i++) {
      final f = _folded[i];
      final at = f.indexOf(q);
      if (at < 0) continue;
      final c = cities[i];
      if (rest.isNotEmpty &&
          !foldForSearch('${c.region} ${c.country}').contains(rest)) {
        continue;
      }
      final atWordStart =
          at == 0 || f[at - 1] == '|' || f[at - 1] == ' ' || f[at - 1] == '-';
      (atWordStart ? starts : contains).add(c);
      if (starts.length >= limit) break;
    }
    // The list is stored largest first, so each group is already ordered.
    return [...starts, ...contains].take(limit).toList();
  }
}

/// Every IANA time zone name, for the manual entry picker.
List<String> allTimeZones() {
  ensureTimeZones();
  return tz.timeZoneDatabase.locations.keys.toList()..sort();
}

/// The UTC offset in effect at a local wall-clock time in [zone], or null
/// for an unknown zone.
Duration? utcOffsetAt(String zone, int y, int m, int d, int h, int mi) {
  ensureTimeZones();
  try {
    final t = tz.TZDateTime(tz.getLocation(zone), y, m, d, h, mi);
    return t.timeZoneOffset;
  } catch (_) {
    return null;
  }
}

/// "UTC+5:30" style label.
String formatOffset(Duration o) {
  final sign = o.isNegative ? '−' : '+';
  final mins = o.inMinutes.abs();
  final h = mins ~/ 60, m = mins % 60;
  return 'UTC$sign$h${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'}';
}
