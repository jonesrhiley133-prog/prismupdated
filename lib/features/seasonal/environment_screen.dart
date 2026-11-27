import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/astro/engine/places.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decor_preview.dart';
import 'package:prism_plurality/features/seasonal/living_environment.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Environmental effects: time-of-day light, weather and music reactions.
/// All decorative; nothing here changes the theme, background or fonts.
class EnvironmentScreen extends ConsumerStatefulWidget {
  const EnvironmentScreen({super.key});
  @override
  ConsumerState<EnvironmentScreen> createState() => _EnvironmentScreenState();
}

class _EnvironmentScreenState extends ConsumerState<EnvironmentScreen> {
  final _city = TextEditingController();
  List<City> _hits = const [];
  CityIndex? _index;

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  void _set(EnvSettings Function(EnvSettings e) f) => ref
      .read(seasonalPrefsProvider.notifier)
      .update(
        (p) => p.copyWith(
          env: f(p.env),
          // Choosing an effect is choosing to see it.
          performance: p.performance == DecoPerformance.off
              ? DecoPerformance.balanced
              : p.performance,
        ),
      );

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _hits = const []);
      return;
    }
    _index ??= await CityIndex.load();
    if (!mounted) return;
    setState(() => _hits = _index!.search(q, limit: 8));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = Localizations.localeOf(context).languageCode == 'es';
    final env = ref.watch(seasonalPrefsProvider.select((p) => p.env));
    final phase = timePhaseOf(DateTime.now());
    final weather = ref.watch(currentWeatherProvider);
    final preview = environmentItems(
      env,
      phase: phase,
      weather: weather,
      musicPlaying: env.music,
    );

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Environmental effects', 'Efectos ambientales'),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + NavBarInset.of(context)),
          children: [
            Text(
              tr(
                context,
                'Gentle light for the time of day, weather and music reactions over your decorations. Decorative only: your theme, background and fonts never change.',
                'Luz suave según la hora, clima y reacciones a la música sobre tus decoraciones. Solo decorativo: tu tema, fondo y fuentes no cambian.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Center(
              child: DecorPreview(items: preview, width: 160, height: 260),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '${es ? phase.es : phase.en}${weather == null ? '' : ' · ${weather.emoji} ${es ? weather.es : weather.en}'}',
                style: theme.textTheme.labelMedium,
              ),
            ),
            PrismSectionHeader(
              title: tr(context, 'TIME OF DAY', 'HORA DEL DÍA'),
            ),
            PrismSwitchRow(
              title: tr(context, 'Follow the time of day', 'Seguir la hora'),
              subtitle: tr(
                context,
                'Early morning, morning, afternoon, sunset, evening and midnight light. Decorations can also be set to show only at certain times in the Decoration Studio.',
                'Luz de madrugada, mañana, tarde, atardecer, noche y medianoche.',
              ),
              value: env.phases,
              onChanged: (v) => _set((e) => e.copyWith(phases: v)),
            ),
            PrismSwitchRow(
              title: tr(
                context,
                'Fireflies in the evening',
                'Luciérnagas de noche',
              ),
              value: env.fireflies,
              onChanged: (v) => _set((e) => e.copyWith(fireflies: v)),
            ),
            PrismSwitchRow(
              title: tr(
                context,
                'Birds along the bottom edge',
                'Pájaros en el borde inferior',
              ),
              subtitle: tr(context, 'During the day.', 'Durante el día.'),
              value: env.birds,
              onChanged: (v) => _set((e) => e.copyWith(birds: v)),
            ),
            PrismSectionHeader(title: tr(context, 'WEATHER', 'CLIMA')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in WeatherMode.values)
                  PrismChip(
                    label: switch (m) {
                      WeatherMode.off => tr(context, 'Off', 'Apagado'),
                      WeatherMode.manual => tr(
                        context,
                        'I choose',
                        'Lo elijo yo',
                      ),
                      WeatherMode.live => tr(
                        context,
                        'Real weather',
                        'Clima real',
                      ),
                    },
                    selected: env.mode == m,
                    onTap: () => _set((e) => e.copyWith(mode: m)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (env.mode != WeatherMode.off) ...[
              Text(
                env.mode == WeatherMode.live
                    ? tr(
                        context,
                        'Shown until the real weather arrives, or if it can\'t be reached:',
                        'Se muestra hasta que llegue el clima real o si no se puede obtener:',
                      )
                    : tr(context, 'Weather to show:', 'Clima a mostrar:'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final w in WeatherKind.values)
                    PrismChip(
                      label: '${w.emoji} ${es ? w.es : w.en}',
                      selected: env.weather == w,
                      onTap: () => _set((e) => e.copyWith(weather: w)),
                    ),
                ],
              ),
            ],
            if (env.mode == WeatherMode.live) ...[
              const SizedBox(height: 12),
              PrismSurface(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      env.placeName == null
                          ? tr(context, 'Choose a city', 'Elige una ciudad')
                          : '${tr(context, 'Weather for', 'Clima de')} ${env.placeName}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        context,
                        'Pick from Prism\'s built-in city list: no location permission is asked for. Only the city\'s rounded coordinates are sent to the free Open-Meteo weather service, every 30 minutes while this is on.',
                        'Elige de la lista de ciudades de Prism: no se pide permiso de ubicación. Solo se envían las coordenadas redondeadas a Open-Meteo cada 30 minutos.',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    PrismTextField(
                      controller: _city,
                      hintText: tr(context, 'Search cities', 'Buscar ciudades'),
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      onChanged: _search,
                    ),
                    for (final c in _hits)
                      PrismListRow(
                        dense: true,
                        title: Text(c.name),
                        subtitle: Text(
                          [
                            c.region,
                            c.country,
                          ].where((x) => x.isNotEmpty).join(', '),
                        ),
                        onTap: () {
                          _set(
                            (e) => e.copyWith(
                              placeName: c.name,
                              lat: c.lat,
                              lon: c.lon,
                            ),
                          );
                          _city.clear();
                          setState(() => _hits = const []);
                        },
                      ),
                    if (env.placeName != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PrismButton(
                          label: tr(
                            context,
                            'Forget this city',
                            'Olvidar ciudad',
                          ),
                          tone: PrismButtonTone.outlined,
                          density: PrismControlDensity.compact,
                          onPressed: () => _set(
                            (e) => e.copyWith(
                              placeName: null,
                              lat: null,
                              lon: null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            PrismSectionHeader(title: tr(context, 'MUSIC', 'MÚSICA')),
            PrismSwitchRow(
              title: tr(context, 'React to music', 'Reaccionar a la música'),
              subtitle: tr(
                context,
                'While Prism\'s music player is playing: notes float up and record players spin.',
                'Mientras suena el reproductor de Prism: flotan notas y giran los tocadiscos.',
              ),
              value: env.music,
              onChanged: (v) => _set((e) => e.copyWith(music: v)),
            ),
            PrismSectionHeader(title: tr(context, 'STRENGTH', 'INTENSIDAD')),
            Slider(
              value: env.intensity,
              onChanged: (v) => _set((e) => e.copyWith(intensity: v)),
            ),
            Text(
              tr(
                context,
                'With reduced motion on, weather and light stay but nothing falls or drifts.',
                'Con movimiento reducido, el clima y la luz se quedan pero nada cae ni se mueve.',
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
