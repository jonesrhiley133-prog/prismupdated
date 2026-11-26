import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/games/engines/ambience_synth.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decor_preview.dart';
import 'package:prism_plurality/features/seasonal/seasonal_calendar.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

String _fmt(BuildContext context, DateTime d) =>
    MaterialLocalizations.of(context).formatMediumDate(d);

/// Seasonal Living: a cozy layer of decorations over your own theme.
class SeasonalHubScreen extends ConsumerWidget {
  const SeasonalHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(seasonalPrefsProvider);
    final n = ref.read(seasonalPrefsProvider.notifier);
    final active = ref.watch(activeSeasonProvider);
    final l = Localizations.localeOf(context).languageCode == 'es';
    final off = prefs.performance == DecoPerformance.off;

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Seasonal Living', 'Vida estacional'),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + NavBarInset.of(context)),
          children: [
            PrismSurface(
              tone: PrismSurfaceTone.strong,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🏡', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        'Seasonal Living adds decorations on top of your own theme. It never changes your background, colours, fonts or theme — you can celebrate Christmas with a gothic theme, or Halloween with a pastel one.',
                        'La vida estacional añade decoraciones sobre tu propio tema. Nunca cambia tu fondo, colores, fuentes ni tema.',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            PrismSectionHeader(title: tr(context, 'HOW MUCH', 'CUÁNTO')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in DecoPerformance.values)
                  PrismChip(
                    label: l ? m.es : m.en,
                    selected: prefs.performance == m,
                    onTap: () => n.update((p) => p.copyWith(performance: m)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                l ? prefs.performance.descEs : prefs.performance.descEn,
                style: theme.textTheme.bodySmall,
              ),
            ),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: PrismSwitchRow(
                title: tr(context, 'Reduced motion', 'Movimiento reducido'),
                subtitle: tr(
                  context,
                  'Keeps decorations still and quiet. Prism also follows your device\'s setting.',
                  'Mantiene las decoraciones quietas. Prism también sigue el ajuste de tu dispositivo.',
                ),
                value: prefs.reducedMotion,
                onChanged: (v) => n.update((p) => p.copyWith(reducedMotion: v)),
              ),
            ),
            PrismSectionHeader(
              title: tr(context, 'SHOWING NOW', 'MOSTRANDO AHORA'),
            ),
            if (off)
              PrismSurface(
                padding: const EdgeInsets.all(14),
                child: Text(
                  tr(
                    context,
                    'Seasonal Living is off. Pick how much you want above, then choose a look.',
                    'La vida estacional está apagada. Elige cuánto quieres arriba y luego un estilo.',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else if (active == null || active.variation == null)
              PrismSurface(
                padding: const EdgeInsets.all(14),
                child: Text(
                  prefs.autoSchedule
                      ? tr(
                          context,
                          'Nothing is in season right now. Your scheduled holidays will appear on their own.',
                          'Nada está de temporada ahora. Tus fiestas programadas aparecerán solas.',
                        )
                      : tr(
                          context,
                          'No look is showing. Browse the collections to choose one, or turn on scheduling in Preferences.',
                          'No se muestra ningún estilo. Explora las colecciones o activa la programación en Preferencias.',
                        ),
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              _NowCard(active: active),
            const SizedBox(height: 10),
            PrismButton(
              label: tr(
                context,
                'Browse holidays & seasons',
                'Explorar fiestas y estaciones',
              ),
              icon: Icons.celebration_outlined,
              expanded: true,
              onPressed: () => context.push(AppRoutePaths.seasonalCollections),
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: tr(context, 'Decoration Studio', 'Estudio de decoración'),
              icon: Icons.auto_fix_high_outlined,
              expanded: true,
              tone: PrismButtonTone.outlined,
              onPressed: () => context.push(AppRoutePaths.seasonalStudio),
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: tr(context, 'My arrangements', 'Mis arreglos'),
              icon: Icons.bookmarks_outlined,
              expanded: true,
              tone: PrismButtonTone.outlined,
              onPressed: () => context.push(AppRoutePaths.seasonalPresets),
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: tr(
                context,
                'Preferences & schedule',
                'Preferencias y programación',
              ),
              icon: Icons.event_available_outlined,
              expanded: true,
              tone: PrismButtonTone.outlined,
              onPressed: () => context.push(AppRoutePaths.seasonalPrefs),
            ),
            PrismSectionHeader(title: tr(context, 'LAYERS', 'CAPAS')),
            PrismSurface(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, t) in [
                    (1, tr(context, 'Base theme', 'Tema base')),
                    (2, tr(context, 'Your background', 'Tu fondo')),
                    (3, tr(context, 'UI styling', 'Estilo de la interfaz')),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$i · $t — ${tr(context, 'yours, never changed here', 'tuyo, nunca se cambia aquí')}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, layer) in DecoLayer.values.indexed)
              PrismSurface(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: PrismSwitchRow(
                  title: '${i + 4} · ${l ? layer.es : layer.en}',
                  value: prefs.layers.on(layer),
                  onChanged: off
                      ? (_) {}
                      : (v) => n.update((p) {
                          final set = {...p.layers.enabled};
                          v ? set.add(layer) : set.remove(layer);
                          // Changing a layer by hand means you want control.
                          return p.copyWith(
                            layers: p.layers.copyWith(enabled: set),
                            performance: DecoPerformance.custom,
                          );
                        }),
                ),
              ),
            if (prefs.performance == DecoPerformance.custom) ...[
              const SizedBox(height: 6),
              _Slider(
                label: tr(context, 'Falling things', 'Cosas que caen'),
                value: prefs.layers.particleDensity,
                min: 0,
                max: 1,
                text: '${(prefs.layers.particleDensity * 100).round()}%',
                onChanged: (v) => n.update(
                  (p) =>
                      p.copyWith(layers: p.layers.copyWith(particleDensity: v)),
                ),
              ),
              _Slider(
                label: tr(context, 'Animation speed', 'Velocidad de animación'),
                value: prefs.layers.animationSpeed,
                min: 0.2,
                max: 2,
                text: '${prefs.layers.animationSpeed.toStringAsFixed(1)}×',
                onChanged: (v) => n.update(
                  (p) =>
                      p.copyWith(layers: p.layers.copyWith(animationSpeed: v)),
                ),
              ),
              _Slider(
                label: tr(
                  context,
                  'Most animated things at once',
                  'Máx. de cosas animadas',
                ),
                value: prefs.layers.maxAnimated.toDouble(),
                min: 0,
                max: 40,
                text: '${prefs.layers.maxAnimated}',
                onChanged: (v) => n.update(
                  (p) => p.copyWith(
                    layers: p.layers.copyWith(maxAnimated: v.round()),
                  ),
                ),
              ),
            ],
            PrismSectionHeader(
              title: tr(context, 'AMBIENT SOUND', 'SONIDO AMBIENTE'),
            ),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: PrismSwitchRow(
                title: tr(
                  context,
                  'Play a soft ambience',
                  'Reproducir un ambiente suave',
                ),
                subtitle: tr(
                  context,
                  'Off by default. It fades in and out, has its own volume and plays alongside your music.',
                  'Apagado por defecto. Entra y sale suavemente, tiene su propio volumen y suena junto a tu música.',
                ),
                value: prefs.audioOn,
                onChanged: (v) => n.update(
                  (p) => p.copyWith(audioOn: v, audioId: p.audioId ?? 'fire'),
                ),
              ),
            ),
            if (prefs.audioOn) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in ambienceCatalog)
                    PrismChip(
                      label: '${a.emoji} ${l ? a.labelEs : a.label}',
                      selected: prefs.audioId == a.id,
                      onTap: () => n.update((p) => p.copyWith(audioId: a.id)),
                    ),
                ],
              ),
              _Slider(
                label: tr(context, 'Volume', 'Volumen'),
                value: prefs.audioVolume,
                min: 0,
                max: 1,
                text: '${(prefs.audioVolume * 100).round()}%',
                onChanged: (v) => n.update((p) => p.copyWith(audioVolume: v)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.text,
    required this.onChanged,
  });
  final String label, text;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            Text(text, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _NowCard extends ConsumerWidget {
  const _NowCard({required this.active});
  final ActiveSeason active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = active.variation!;
    final col = collectionById(v.collectionId)!;
    final theme = Theme.of(context);
    final reason = switch (active.reason) {
      ActiveReason.manual => tr(
        context,
        'You switched it on',
        'Lo activaste tú',
      ),
      ActiveReason.celebration => tr(
        context,
        'Your celebration: ${active.celebration?.name ?? ''}',
        'Tu celebración: ${active.celebration?.name ?? ''}',
      ),
      ActiveReason.scheduled => tr(context, 'In season', 'De temporada'),
      ActiveReason.permanent => tr(context, 'Kept all year', 'Todo el año'),
    };
    return PrismSurface(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          DecorPreview(items: arrangementForVariation(v), width: 88),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${col.emoji} ${col.name}',
                  style: theme.textTheme.labelMedium,
                ),
                Text(v.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(reason, style: theme.textTheme.bodySmall),
                if (active.range != null)
                  Text(
                    '${_fmt(context, active.range!.start)} – ${_fmt(context, active.range!.end)}',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    PrismButton(
                      label: tr(context, 'Change', 'Cambiar'),
                      density: PrismControlDensity.compact,
                      tone: PrismButtonTone.outlined,
                      onPressed: () => context.push(
                        AppRoutePaths.seasonalCollection(col.id),
                      ),
                    ),
                    if (active.reason == ActiveReason.manual ||
                        active.reason == ActiveReason.permanent)
                      PrismButton(
                        label: tr(context, 'Stop', 'Detener'),
                        density: PrismControlDensity.compact,
                        tone: PrismButtonTone.outlined,
                        onPressed: () => ref
                            .read(seasonalPrefsProvider.notifier)
                            .update(
                              (p) => p.copyWith(
                                manualVariation: null,
                                manualUntil: null,
                                permanentVariation:
                                    active.reason == ActiveReason.permanent
                                    ? null
                                    : p.permanentVariation,
                              ),
                            ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Collections ────────────────────────────────────────────────────────

class SeasonalCollectionsScreen extends ConsumerStatefulWidget {
  const SeasonalCollectionsScreen({super.key});
  @override
  ConsumerState<SeasonalCollectionsScreen> createState() =>
      _SeasonalCollectionsScreenState();
}

class _SeasonalCollectionsScreenState
    extends ConsumerState<SeasonalCollectionsScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(seasonalPrefsProvider);
    final q = _q.text.trim().toLowerCase();
    final all = seasonalCollections
        .where(
          (c) =>
              q.isEmpty ||
              c.name.toLowerCase().contains(q) ||
              c.variations.any((v) => v.name.toLowerCase().contains(q)),
        )
        .toList();
    final theme = Theme.of(context);
    final today = DateTime.now();

    Widget group(String title, Iterable<SeasonalCollection> cols) {
      final list = cols.toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismSectionHeader(title: title),
          for (final c in list)
            Builder(
              builder: (context) {
                final w = SeasonalWindows.windowFor(
                  c.id,
                  today.year,
                  region: prefs.region,
                  hemisphere: prefs.hemisphere,
                );
                final upcoming = w != null && w.end.isBefore(today)
                    ? SeasonalWindows.windowFor(
                        c.id,
                        today.year + 1,
                        region: prefs.region,
                        hemisphere: prefs.hemisphere,
                      )
                    : w;
                return PrismListRow(
                  leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(c.name),
                  subtitle: Text(
                    '${c.variations.length} ${tr(context, 'looks', 'estilos')}${upcoming == null ? '' : ' · ${_fmt(context, upcoming.start)}'}${c.approximateDates ? ' ~' : ''}',
                  ),
                  trailing: prefs.hidden.contains(c.id)
                      ? Icon(
                          Icons.visibility_off_outlined,
                          size: 18,
                          color: theme.colorScheme.outline,
                        )
                      : prefs.celebrated.contains(c.id)
                      ? Icon(
                          Icons.favorite,
                          size: 18,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  showChevron: true,
                  onTap: () =>
                      context.push(AppRoutePaths.seasonalCollection(c.id)),
                );
              },
            ),
        ],
      );
    }

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Holidays & seasons', 'Fiestas y estaciones'),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + NavBarInset.of(context)),
          children: [
            PrismTextField(
              controller: _q,
              hintText: tr(
                context,
                'Search holidays and looks',
                'Buscar fiestas y estilos',
              ),
              prefixIcon: const Icon(Icons.search),
              onChanged: (_) => setState(() {}),
            ),
            group(
              tr(context, 'HOLIDAYS', 'FIESTAS'),
              all.where((c) => c.kind == SeasonalKind.holiday),
            ),
            group(
              tr(context, 'SEASONS', 'ESTACIONES'),
              all.where((c) => c.kind == SeasonalKind.season),
            ),
            group(
              tr(context, 'AWARENESS', 'CONCIENCIA'),
              all.where((c) => c.kind == SeasonalKind.awareness),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                tr(
                  context,
                  '~ marks dates that follow a lunar or observational calendar and can differ by a day or two where you live.',
                  '~ indica fechas de calendarios lunares u observacionales que pueden variar uno o dos días.',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One collection and its 25+ looks.
class SeasonalCollectionScreen extends ConsumerWidget {
  const SeasonalCollectionScreen({super.key, required this.collectionId});
  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = collectionById(collectionId);
    if (c == null) {
      return PrismPageScaffold(
        topBar: PrismTopBar(
          title: tr(context, 'Collection', 'Colección'),
          showBackButton: true,
        ),
        body: const SizedBox.shrink(),
      );
    }
    final prefs = ref.watch(seasonalPrefsProvider);
    final n = ref.read(seasonalPrefsProvider.notifier);
    final theme = Theme.of(context);
    final now = DateTime.now();
    var w = SeasonalWindows.windowFor(
      c.id,
      now.year,
      region: prefs.region,
      hemisphere: prefs.hemisphere,
    );
    if (w != null && w.end.isBefore(now))
      w =
          SeasonalWindows.windowFor(
            c.id,
            now.year + 1,
            region: prefs.region,
            hemisphere: prefs.hemisphere,
          ) ??
          w;
    final chosen = prefs.variationFor[c.id];
    final celebrated = prefs.celebrated.contains(c.id);
    final hidden = prefs.hidden.contains(c.id);
    final es = Localizations.localeOf(context).languageCode == 'es';

    return PrismPageScaffold(
      topBar: PrismTopBar(title: '${c.emoji} ${c.name}', showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList.list(
                children: [
                  Text(c.blurb, style: theme.textTheme.bodyLarge),
                  if (c.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: PrismSurface(
                        padding: const EdgeInsets.all(12),
                        child: Text(c.note!, style: theme.textTheme.bodySmall),
                      ),
                    ),
                  if (w != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${tr(context, 'Next season', 'Próxima temporada')}: ${_fmt(context, w.start)} – ${_fmt(context, w.end)}${c.approximateDates ? '  (${tr(context, 'approximate', 'aprox.')})' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        tr(
                          context,
                          'No automatic date for this year — set your own in Preferences, or switch a look on by hand.',
                          'Sin fecha automática este año: ponla en Preferencias o activa un estilo a mano.',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PrismChip(
                        label: celebrated
                            ? tr(context, 'I celebrate this', 'Lo celebro')
                            : tr(context, 'I celebrate this?', '¿Lo celebro?'),
                        selected: celebrated,
                        onTap: () => n.update(
                          (p) => p.copyWith(
                            celebrated: celebrated
                                ? ({...p.celebrated}..remove(c.id))
                                : {...p.celebrated, c.id},
                            hidden: {...p.hidden}..remove(c.id),
                          ),
                        ),
                      ),
                      PrismChip(
                        label: hidden
                            ? tr(context, 'Hidden', 'Oculto')
                            : tr(context, 'Hide this', 'Ocultar'),
                        selected: hidden,
                        onTap: () => n.update(
                          (p) => p.copyWith(
                            hidden: hidden
                                ? ({...p.hidden}..remove(c.id))
                                : {...p.hidden, c.id},
                            celebrated: {...p.celebrated}..remove(c.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                  PrismSectionHeader(
                    title:
                        '${c.variations.length} ${tr(context, 'LOOKS', 'ESTILOS')}',
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                40 + NavBarInset.of(context),
              ),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 360,
                ),
                itemCount: c.variations.length,
                itemBuilder: (context, i) {
                  final v = c.variations[i];
                  final isChosen = chosen == v.id || (chosen == null && false);
                  final isNow =
                      prefs.manualVariation == v.id ||
                      prefs.permanentVariation == v.id;
                  return Semantics(
                    button: true,
                    label: v.name,
                    child: InkWell(
                      borderRadius: prismCorners(context, 16),
                      onTap: () => _look(context, ref, c, v),
                      child: Column(
                        children: [
                          // Only the rows on screen are ever built.
                          DecorPreview(
                            items: arrangementForVariation(v),
                            width: 170,
                            height: 290,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  v.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                              if (isChosen || isNow)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            es ? 'Toca para elegir' : 'Tap to choose',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _look(
    BuildContext context,
    WidgetRef ref,
    SeasonalCollection c,
    SeasonalVariation v,
  ) async {
    final n = ref.read(seasonalPrefsProvider.notifier);
    await PrismSheet.show<void>(
      context: context,
      title: v.name,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DecorPreview(items: arrangementForVariation(v), width: 200),
          ),
          const SizedBox(height: 12),
          PrismButton(
            label: tr(ctx, 'Show it now', 'Mostrarlo ahora'),
            icon: Icons.play_arrow_rounded,
            tone: PrismButtonTone.filled,
            onPressed: () {
              n.update(
                (p) => p.copyWith(
                  manualVariation: v.id,
                  manualUntil: null,
                  performance: p.performance == DecoPerformance.off
                      ? DecoPerformance.balanced
                      : p.performance,
                ),
              );
              Navigator.of(ctx).pop();
              PrismToast.show(
                context,
                message: tr(
                  context,
                  '${v.name} is on. Your theme is untouched.',
                  '${v.name} está activo. Tu tema no cambia.',
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              PrismButton(
                label: tr(ctx, 'Show for a week', 'Mostrar una semana'),
                tone: PrismButtonTone.outlined,
                density: PrismControlDensity.compact,
                onPressed: () {
                  n.update(
                    (p) => p.copyWith(
                      manualVariation: v.id,
                      manualUntil: DateTime.now().add(const Duration(days: 7)),
                      performance: p.performance == DecoPerformance.off
                          ? DecoPerformance.balanced
                          : p.performance,
                    ),
                  );
                  Navigator.of(ctx).pop();
                },
              ),
              PrismButton(
                label: tr(
                  ctx,
                  'Use for ${c.name} each year',
                  'Usar cada año para ${c.name}',
                ),
                tone: PrismButtonTone.outlined,
                density: PrismControlDensity.compact,
                onPressed: () {
                  n.update(
                    (p) => p.copyWith(
                      variationFor: {...p.variationFor, c.id: v.id},
                      celebrated: {...p.celebrated, c.id},
                      hidden: {...p.hidden}..remove(c.id),
                    ),
                  );
                  Navigator.of(ctx).pop();
                  PrismToast.show(
                    context,
                    message: tr(
                      context,
                      'Saved. Turn on scheduling in Preferences to have it appear on its own.',
                      'Guardado. Activa la programación en Preferencias para que aparezca sola.',
                    ),
                  );
                },
              ),
              PrismButton(
                label: tr(ctx, 'Keep all year', 'Todo el año'),
                tone: PrismButtonTone.outlined,
                density: PrismControlDensity.compact,
                onPressed: () {
                  n.update(
                    (p) => p.copyWith(
                      permanentVariation: v.id,
                      performance: p.performance == DecoPerformance.off
                          ? DecoPerformance.balanced
                          : p.performance,
                    ),
                  );
                  Navigator.of(ctx).pop();
                },
              ),
              PrismButton(
                label: tr(
                  ctx,
                  'Mix into my arrangement',
                  'Añadir a mi arreglo',
                ),
                tone: PrismButtonTone.outlined,
                density: PrismControlDensity.compact,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push(AppRoutePaths.seasonalStudio, extra: v.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
