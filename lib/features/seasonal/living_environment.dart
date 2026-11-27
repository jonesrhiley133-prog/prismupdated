import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:prism_plurality/features/seasonal/decor_models.dart';

/// The six parts of the day decorations can follow.
enum TimePhase {
  earlyMorning('Early morning', 'Madrugada'),
  morning('Morning', 'Mañana'),
  afternoon('Afternoon', 'Tarde'),
  sunset('Sunset', 'Atardecer'),
  evening('Evening', 'Noche'),
  midnight('Midnight', 'Medianoche');

  const TimePhase(this.en, this.es);
  final String en, es;

  /// How much daylight there is, 0–1 (flowers open with it).
  double get daylight => switch (this) {
    earlyMorning => 0.45,
    morning => 0.85,
    afternoon => 1,
    sunset => 0.65,
    evening => 0.3,
    midnight => 0.15,
  };

  bool get isDark => this == evening || this == midnight;
}

TimePhase timePhaseOf(DateTime t) {
  final h = t.hour + t.minute / 60;
  if (h >= 5 && h < 8) return TimePhase.earlyMorning;
  if (h >= 8 && h < 12) return TimePhase.morning;
  if (h >= 12 && h < 17) return TimePhase.afternoon;
  if (h >= 17 && h < 19.5) return TimePhase.sunset;
  if (h >= 19.5 && h < 23) return TimePhase.evening;
  return TimePhase.midnight;
}

enum WeatherKind {
  clear('Clear', 'Despejado', '🌙'),
  cloudy('Cloudy', 'Nublado', '☁️'),
  lightRain('Light rain', 'Lluvia ligera', '🌦️'),
  heavyRain('Heavy rain', 'Lluvia fuerte', '🌧️'),
  snow('Snow', 'Nieve', '❄️'),
  fog('Fog', 'Niebla', '🌫️'),
  wind('Gentle wind', 'Brisa', '🌬️'),
  leaves('Falling leaves', 'Hojas que caen', '🍂'),
  sunshine('Sunshine', 'Sol', '☀️'),
  mist('Mist', 'Neblina', '💧');

  const WeatherKind(this.en, this.es, this.emoji);
  final String en, es, emoji;
}

/// Where the weather comes from: nowhere, the person's choice, or the real
/// forecast for a place they picked.
enum WeatherMode { off, manual, live }

/// Living environment settings. Everything is off until chosen; live
/// weather only ever uses a city the person picked from Prism's offline
/// list, so it never asks for location permission.
@immutable
class EnvSettings {
  const EnvSettings({
    this.phases = false,
    this.mode = WeatherMode.off,
    this.weather = WeatherKind.clear,
    this.placeName,
    this.lat,
    this.lon,
    this.music = false,
    this.fireflies = false,
    this.birds = false,
    this.intensity = 0.6,
  });

  /// Soft morning / sunset / night light washes.
  final bool phases;
  final WeatherMode mode;

  /// The manual choice (also the fallback while live weather loads).
  final WeatherKind weather;
  final String? placeName;
  final double? lat, lon;

  /// Decorations react to music playing in Prism's player.
  final bool music;

  /// Fireflies in the evening, birds along the bottom edge.
  final bool fireflies, birds;

  /// 0–1: how strong weather and light effects are.
  final double intensity;

  bool get any =>
      phases || mode != WeatherMode.off || music || fireflies || birds;

  bool get hasPlace => lat != null && lon != null;

  EnvSettings copyWith({
    bool? phases,
    WeatherMode? mode,
    WeatherKind? weather,
    Object? placeName = _k,
    Object? lat = _k,
    Object? lon = _k,
    bool? music,
    bool? fireflies,
    bool? birds,
    double? intensity,
  }) => EnvSettings(
    phases: phases ?? this.phases,
    mode: mode ?? this.mode,
    weather: weather ?? this.weather,
    placeName: identical(placeName, _k) ? this.placeName : placeName as String?,
    lat: identical(lat, _k) ? this.lat : lat as double?,
    lon: identical(lon, _k) ? this.lon : lon as double?,
    music: music ?? this.music,
    fireflies: fireflies ?? this.fireflies,
    birds: birds ?? this.birds,
    intensity: intensity ?? this.intensity,
  );

  static const _k = Object();

  Map<String, Object?> toJson() => {
    if (phases) 'ph': true,
    if (mode != WeatherMode.off) 'md': mode.name,
    if (weather != WeatherKind.clear) 'wx': weather.name,
    'pn': ?placeName,
    'la': ?lat,
    'lo': ?lon,
    if (music) 'mu': true,
    if (fireflies) 'ff': true,
    if (birds) 'bd': true,
    if (intensity != 0.6) 'in': intensity,
  };

  static EnvSettings fromJson(Object? o) {
    if (o is! Map) return const EnvSettings();
    double? num_(Object? x) => x is num ? x.toDouble() : null;
    final lat = num_(o['la']), lon = num_(o['lo']);
    final okPlace =
        lat != null && lon != null && lat.abs() <= 90 && lon.abs() <= 180;
    return EnvSettings(
      phases: o['ph'] == true,
      mode:
          WeatherMode.values.where((m) => m.name == o['md']).firstOrNull ??
          WeatherMode.off,
      weather:
          WeatherKind.values.where((w) => w.name == o['wx']).firstOrNull ??
          WeatherKind.clear,
      placeName: okPlace && o['pn'] is String ? o['pn'] as String : null,
      lat: okPlace ? lat : null,
      lon: okPlace ? lon : null,
      music: o['mu'] == true,
      fireflies: o['ff'] == true,
      birds: o['bd'] == true,
      intensity: (num_(o['in']) ?? 0.6).clamp(0.0, 1.0),
    );
  }
}

/// Maps a WMO weather code (as Open-Meteo reports it) to a decoration.
WeatherKind weatherFromWmo(int code, {double windKmh = 0, bool isDay = true}) {
  final w = switch (code) {
    0 => isDay ? WeatherKind.sunshine : WeatherKind.clear,
    1 => isDay ? WeatherKind.sunshine : WeatherKind.clear,
    2 || 3 => WeatherKind.cloudy,
    45 || 48 => WeatherKind.fog,
    51 || 53 || 55 || 56 || 57 => WeatherKind.mist,
    61 || 80 => WeatherKind.lightRain,
    63 || 65 || 66 || 67 || 81 || 82 || 95 || 96 || 99 => WeatherKind.heavyRain,
    71 || 73 || 75 || 77 || 85 || 86 => WeatherKind.snow,
    _ => WeatherKind.clear,
  };
  // A clear or cloudy windy day shows as wind.
  if (windKmh >= 30 &&
      (w == WeatherKind.clear ||
          w == WeatherKind.sunshine ||
          w == WeatherKind.cloudy)) {
    return WeatherKind.wind;
  }
  return w;
}

/// Reads the current weather for a place. Only the coordinates the person
/// chose are sent; nothing else about them is.
Future<WeatherKind?> fetchLiveWeather(
  double lat,
  double lon, {
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  try {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(2),
      'longitude': lon.toStringAsFixed(2),
      'current': 'weather_code,wind_speed_10m,is_day',
    });
    final r = await c.get(uri).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200 || r.body.length > 100000) return null;
    final o = jsonDecode(r.body);
    if (o is! Map || o['current'] is! Map) return null;
    final cur = o['current'] as Map;
    final code = cur['weather_code'];
    if (code is! num) return null;
    final wind = cur['wind_speed_10m'];
    return weatherFromWmo(
      code.toInt(),
      windKmh: wind is num ? wind.toDouble() : 0,
      isDay: cur['is_day'] != 0,
    );
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

// ── Providers ──────────────────────────────────────────────────────────

/// The current time phase, checked every few minutes. Only runs while
/// something actually follows the time of day.
final livingPhaseProvider = StreamProvider<TimePhase>((ref) {
  final c = StreamController<TimePhase>();
  var last = timePhaseOf(DateTime.now());
  c.add(last);
  final t = Timer.periodic(const Duration(minutes: 2), (_) {
    final now = timePhaseOf(DateTime.now());
    if (now != last && !c.isClosed) {
      last = now;
      c.add(now);
    }
  });
  ref.onDispose(() {
    t.cancel();
    c.close();
  });
  return c.stream;
});

/// Live weather for (lat, lon), refreshed every 30 minutes.
final liveWeatherProvider =
    StreamProvider.family<WeatherKind?, (double, double)>((ref, place) {
      final c = StreamController<WeatherKind?>();
      Future<void> load() async {
        final w = await fetchLiveWeather(place.$1, place.$2);
        if (!c.isClosed && w != null) c.add(w);
      }

      load();
      final t = Timer.periodic(const Duration(minutes: 30), (_) => load());
      ref.onDispose(() {
        t.cancel();
        c.close();
      });
      return c.stream;
    });

/// The weather to show right now under [env], given what live weather (if
/// any) reported.
WeatherKind? effectiveWeather(EnvSettings env, WeatherKind? live) =>
    switch (env.mode) {
      WeatherMode.off => null,
      WeatherMode.manual => env.weather,
      WeatherMode.live => live ?? env.weather,
    };

/// The decorations the environment adds: light for the time of day,
/// weather, evening fireflies, birds and music notes. All of it is
/// decorative, faint, and sits behind interactive parts of the app.
List<DecorItem> environmentItems(
  EnvSettings env, {
  required TimePhase phase,
  WeatherKind? weather,
  bool musicPlaying = false,
}) {
  final k = env.intensity;
  var n = 0;
  String id(String s) => 'env-$s-${n++}';
  DecorItem wash(String glyph, double opacity) => DecorItem(
    id: id('wash'),
    kind: DecoKind.environment,
    glyph: glyph,
    w: 1,
    z: -10,
    opacity: opacity.clamp(0.0, 1.0),
  );
  DecorItem fall(String style, double freq, {double speed = 1}) => DecorItem(
    id: id(style),
    kind: DecoKind.particles,
    glyph: 'st:p.$style',
    w: 1,
    z: 6,
    frequency: freq.clamp(0.05, 1.0),
    speed: speed,
  );

  final out = <DecorItem>[];
  if (env.phases) out.add(wash('env:phase.${phase.name}', 0.5 + k * 0.5));
  switch (weather) {
    case null || WeatherKind.clear:
      break;
    case WeatherKind.cloudy:
      out.add(fall('clouds', 0.3 + k * 0.4, speed: 0.6));
    case WeatherKind.lightRain:
      out.add(fall('rain', 0.25 + k * 0.25));
    case WeatherKind.heavyRain:
      out
        ..add(fall('rain', 0.7 + k * 0.3, speed: 1.6))
        ..add(wash('env:storm', 0.4 + k * 0.4));
    case WeatherKind.snow:
      out.add(fall('snow', 0.4 + k * 0.5, speed: 0.8));
    case WeatherKind.fog:
      out.add(wash('env:fog', 0.5 + k * 0.5));
    case WeatherKind.mist:
      out
        ..add(wash('env:mist', 0.4 + k * 0.4))
        ..add(fall('rain', 0.1 + k * 0.1, speed: 0.6));
    case WeatherKind.wind:
      out.add(fall('feathers', 0.3 + k * 0.4, speed: 1.8));
    case WeatherKind.leaves:
      out.add(fall('leaves', 0.35 + k * 0.45));
    case WeatherKind.sunshine:
      out.add(wash('env:sun', 0.5 + k * 0.5));
  }
  if (env.fireflies && phase.isDark) {
    out.add(fall('fireflies', 0.4 + k * 0.4, speed: 0.7));
  }
  if (env.birds && !phase.isDark) {
    for (var i = 0; i < 2; i++) {
      out.add(
        DecorItem(
          id: id('bird'),
          kind: DecoKind.illustration,
          glyph: i == 0 ? '🐦' : '🕊️',
          anchor: DecoAnchor.bottom,
          x: 0.3 + i * 0.4,
          y: 0.0,
          w: 0.06,
          z: 8,
          behavior: 'walk',
          range: 0.12,
          speed: 0.5 + i * 0.2,
        ),
      );
    }
  }
  if (env.music && musicPlaying) {
    for (var i = 0; i < 3; i++) {
      out.add(
        DecorItem(
          id: id('note'),
          kind: DecoKind.illustration,
          glyph: const ['🎵', '🎶', '🎼'][i],
          anchor: DecoAnchor.bottomRight,
          x: 0.82 - i * 0.07,
          y: 0.86,
          w: 0.05,
          z: 8,
          behavior: 'float',
          range: 0.06,
          speed: 0.8 + i * 0.3,
          opacity: 0.85,
        ),
      );
    }
  }
  return out;
}
