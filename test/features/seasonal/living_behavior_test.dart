import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/seasonal/decor_assets.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decor_painter.dart';
import 'package:prism_plurality/features/seasonal/environment_screen.dart';
import 'package:prism_plurality/features/seasonal/living_environment.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

class _FakePrefs extends SeasonalPrefsNotifier {
  @override
  Future<void> flush() async {}
}

void _paint(DecorScene scene, double t, Set<DecoLayer> layers) {
  final rec = ui.PictureRecorder();
  DecorPainter(
    scene: scene,
    t: t,
    layersToDraw: layers,
  ).paint(Canvas(rec), const Size(400, 800));
  rec.endRecording().dispose();
}

void main() {
  test('behaviour settings round-trip and are bounded', () {
    final i = DecorItem(
      id: 'a',
      kind: DecoKind.illustration,
      glyph: '🐈',
      behavior: 'walk',
      range: 0.3,
      direction: 90,
      sensitivity: 0.8,
      sound: true,
      tap: true,
      phases: ['evening', 'midnight'],
      idle: 'breathe',
      companion: true,
      still: 'hide',
      animate: false,
    );
    final b = DecorItem.fromJson(i.toJson())!;
    expect(b.behavior, 'walk');
    expect(b.range, 0.3);
    expect(b.direction, 90);
    expect(b.sensitivity, 0.8);
    expect(b.sound && b.tap && b.companion, isTrue);
    expect(b.phases, ['evening', 'midnight']);
    expect(b.idle, 'breathe');
    expect(b.still, 'hide');
    expect(b.animate, isFalse);
    expect(b.moves, isFalse, reason: 'animation switched off');
    final bad = DecorItem.fromJson({
      'id': 'x',
      'k': 'illustration',
      'rg': 9,
      'se': -3,
      'idl': 'explode',
      'rms': 'weird',
    })!;
    expect(bad.range, 1);
    expect(bad.sensitivity, 0);
    expect(bad.idle, 'none');
    expect(bad.still, 'still');
    // Defaults stay out of the saved JSON.
    expect(
      DecorItem(id: 'p', kind: DecoKind.flower).toJson().keys,
      isNot(contains('bh')),
    );
  });

  test('library pieces start with their category behaviour', () {
    final cat = decorAssetsIn('animals').first;
    expect(decorItemForAsset(cat, 'x').behavior, 'walk');
    final fish = decorAssetsIn('aquatic').first;
    expect(decorItemForAsset(fish, 'x').behavior, 'swim');
    final clock = decorAssetsIn('clocks').first;
    expect(decorItemForAsset(clock, 'x').behavior, 'tick');
    final vinyl = decorAssets.firstWhere((a) => a.glyph == '💿');
    expect(decorItemForAsset(vinyl, 'x').behavior, 'play');
    final garland = decorAssets.firstWhere((a) => a.glyph.startsWith('st:g.'));
    expect(decorItemForAsset(garland, 'x').behavior, isNull);
  });

  test('time phases cover the whole day', () {
    expect(timePhaseOf(DateTime(2026, 1, 1, 6)), TimePhase.earlyMorning);
    expect(timePhaseOf(DateTime(2026, 1, 1, 9)), TimePhase.morning);
    expect(timePhaseOf(DateTime(2026, 1, 1, 14)), TimePhase.afternoon);
    expect(timePhaseOf(DateTime(2026, 1, 1, 18)), TimePhase.sunset);
    expect(timePhaseOf(DateTime(2026, 1, 1, 21)), TimePhase.evening);
    expect(timePhaseOf(DateTime(2026, 1, 1, 2)), TimePhase.midnight);
    expect(timePhaseOf(DateTime(2026, 1, 1, 23, 30)), TimePhase.midnight);
  });

  test('weather codes map to decorations', () {
    expect(weatherFromWmo(0), WeatherKind.sunshine);
    expect(weatherFromWmo(0, isDay: false), WeatherKind.clear);
    expect(weatherFromWmo(3), WeatherKind.cloudy);
    expect(weatherFromWmo(45), WeatherKind.fog);
    expect(weatherFromWmo(61), WeatherKind.lightRain);
    expect(weatherFromWmo(65), WeatherKind.heavyRain);
    expect(weatherFromWmo(73), WeatherKind.snow);
    expect(weatherFromWmo(53), WeatherKind.mist);
    expect(weatherFromWmo(1, windKmh: 40), WeatherKind.wind);
    expect(weatherFromWmo(65, windKmh: 40), WeatherKind.heavyRain);
  });

  test('environment settings round-trip; bad places are dropped', () {
    const e = EnvSettings(
      phases: true,
      mode: WeatherMode.live,
      weather: WeatherKind.snow,
      placeName: 'Oslo',
      lat: 59.9,
      lon: 10.7,
      music: true,
      fireflies: true,
      birds: true,
      intensity: 0.3,
    );
    final b = EnvSettings.fromJson(e.toJson());
    expect(b.toJson(), e.toJson());
    final bad = EnvSettings.fromJson({'la': 500, 'lo': 3, 'pn': 'Nowhere'});
    expect(bad.hasPlace, isFalse);
    expect(bad.placeName, isNull);
    expect(const EnvSettings().toJson(), isEmpty);
    final p = const SeasonalPrefs().copyWith(env: e);
    expect(SeasonalPrefs.fromJson(p.toJson()).env.toJson(), e.toJson());
  });

  test('environment adds the right decorations', () {
    expect(
      environmentItems(const EnvSettings(), phase: TimePhase.morning),
      isEmpty,
    );
    final storm = environmentItems(
      const EnvSettings(mode: WeatherMode.manual),
      phase: TimePhase.afternoon,
      weather: WeatherKind.heavyRain,
    );
    expect(storm.map((i) => i.glyph), containsAll(['st:p.rain', 'env:storm']));
    const ff = EnvSettings(fireflies: true, birds: true, music: true);
    final night = environmentItems(ff, phase: TimePhase.evening);
    expect(night.any((i) => i.glyph == 'st:p.fireflies'), isTrue);
    expect(night.any((i) => i.glyph == '🐦'), isFalse);
    final day = environmentItems(ff, phase: TimePhase.morning);
    expect(day.any((i) => i.glyph == 'st:p.fireflies'), isFalse);
    expect(day.any((i) => i.glyph == '🐦'), isTrue);
    expect(day.any((i) => i.glyph == '🎵'), isFalse);
    final playing = environmentItems(
      ff,
      phase: TimePhase.morning,
      musicPlaying: true,
    );
    expect(playing.any((i) => i.glyph == '🎵'), isTrue);
    expect(
      effectiveWeather(
        const EnvSettings(mode: WeatherMode.live, weather: WeatherKind.fog),
        null,
      ),
      WeatherKind.fog,
    );
    expect(
      effectiveWeather(
        const EnvSettings(mode: WeatherMode.live),
        WeatherKind.snow,
      ),
      WeatherKind.snow,
    );
    expect(effectiveWeather(const EnvSettings(), WeatherKind.snow), isNull);
  });

  test('live weather reads Open-Meteo and sends only coordinates', () async {
    Uri? asked;
    final ok = MockClient((r) async {
      asked = r.url;
      return http.Response(
        '{"current":{"weather_code":71,"wind_speed_10m":5,"is_day":1}}',
        200,
      );
    });
    expect(await fetchLiveWeather(59.91, 10.75, client: ok), WeatherKind.snow);
    expect(asked!.host, 'api.open-meteo.com');
    expect(asked!.queryParameters['latitude'], '59.91');
    expect(asked!.queryParameters.keys, isNot(contains('name')));
    final down = MockClient((_) async => http.Response('nope', 500));
    expect(await fetchLiveWeather(1, 2, client: down), isNull);
    final junk = MockClient((_) async => http.Response('{"x":1}', 200));
    expect(await fetchLiveWeather(1, 2, client: junk), isNull);
  });

  test('every behaviour paints, stays in range and respects layers', () {
    final items = [
      for (final b in AssetBehavior.values)
        DecorItem(
          id: b.name,
          kind: DecoKind.illustration,
          glyph: b == AssetBehavior.tick ? 'ph:clock' : '🐈',
          behavior: b.name,
          range: 0.2,
        ),
      for (final w in [
        'env:phase.sunset',
        'env:phase.midnight',
        'env:fog',
        'env:mist',
        'env:sun',
        'env:storm',
      ])
        DecorItem(id: w, kind: DecoKind.environment, glyph: w, w: 1),
    ];
    const layers = DecoLayerSettings();
    final scene = DecorScene(
      items: items,
      layers: layers,
      phase: 'sunset',
      music: true,
      toggled: {'toggle', 'open'},
    );
    for (final t in [0.0, 0.5, 3.3, 42.0]) {
      _paint(scene, t, {DecoLayer.staticDeco});
      _paint(scene, t, {DecoLayer.animated});
    }
    final p = DecorPainter(scene: scene, t: 0, layersToDraw: const {});
    final walker = items.firstWhere((i) => i.id == 'walk');
    expect(p.layerOf(walker), DecoLayer.animated);
    walker.animate = false;
    expect(p.layerOf(walker), DecoLayer.staticDeco);
    // Minimal mode (no animated layer): moving things stay, still.
    final still = DecorPainter(
      scene: DecorScene(
        items: items,
        layers: layers.forMode(DecoPerformance.minimal),
      ),
      t: 0,
      layersToDraw: const {},
    );
    expect(still.layerOf(items.first..behavior = 'sway'), DecoLayer.staticDeco);
  });

  testWidgets('environment screen turns effects on', (tester) async {
    final c = ProviderContainer(
      overrides: [
        seasonalPrefsProvider.overrideWith(_FakePrefs.new),
        trackerKindProvider.overrideWith(
          (ref, kind) => const AsyncValue.data(<TrackerRecord>[]),
        ),
      ],
    );
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EnvironmentScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Follow the time of day'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('I choose'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.textContaining('Snow'));
    await tester.pump(const Duration(milliseconds: 200));
    final env = c.read(seasonalPrefsProvider).env;
    expect(env.phases, isTrue);
    expect(env.mode, WeatherMode.manual);
    expect(env.weather, WeatherKind.snow);
    expect(
      c.read(seasonalPrefsProvider).performance,
      isNot(DecoPerformance.off),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
