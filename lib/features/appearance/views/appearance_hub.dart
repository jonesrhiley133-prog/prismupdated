import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/app_icon/app_icon.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/appearance/appearance_undo_banner.dart';
import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/features/appearance/services/appearance_store.dart';
import 'package:prism_plurality/features/appearance/views/background_gallery.dart';
import 'package:prism_plurality/features/games/engines/ambience_synth.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/living_environment.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/features/settings/views/app_icon_maker.dart';
import 'package:prism_plurality/shared/theme/collection_backgrounds.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// One place in the Appearance hub.
class _HubSection {
  const _HubSection(
    this.id,
    this.en,
    this.es,
    this.icon,
    this.keywords,
    this.open,
  );
  final String id, en, es;
  final IconData icon;

  /// Extra search words (English and Spanish).
  final String keywords;
  final void Function(BuildContext context, WidgetRef ref) open;
}

void _go(BuildContext c, String path) => c.push(path);

final _sections = <_HubSection>[
  _HubSection(
    'themes',
    'Themes',
    'Temas',
    Icons.palette_outlined,
    'presets studio look preset estudio',
    (c, r) => _go(c, AppRoutePaths.appearanceStudio),
  ),
  _HubSection(
    'colors',
    'Colors',
    'Colores',
    Icons.color_lens_outlined,
    'palette accent mood paleta acento',
    (c, r) => _go(c, AppRoutePaths.settingsPalette),
  ),
  _HubSection(
    'backgrounds',
    'Collection Backgrounds',
    'Fondos de colección',
    Icons.wallpaper,
    'wallpaper background fondo pantalla',
    (c, r) => pickCollectionBackground(c, r),
  ),
  _HubSection(
    'fonts',
    'Fonts',
    'Fuentes',
    Icons.font_download_outlined,
    'typography text tipografía letra',
    (c, r) => _go(c, AppRoutePaths.settingsFonts),
  ),
  _HubSection(
    'living',
    'Living Collections',
    'Colecciones vivas',
    Icons.auto_awesome_outlined,
    'genres aesthetic cottagecore space géneros estética',
    (c, r) => _go(c, AppRoutePaths.living),
  ),
  _HubSection(
    'seasonal',
    'Seasonal Collections',
    'Colecciones de temporada',
    Icons.celebration_outlined,
    'holidays christmas halloween fiestas navidad',
    (c, r) => _go(c, AppRoutePaths.seasonal),
  ),
  _HubSection(
    'studio',
    'Decoration Studio',
    'Estudio de decoración',
    Icons.design_services_outlined,
    'decorate place assets decorar elementos',
    (c, r) => _go(c, AppRoutePaths.seasonalStudio),
  ),
  _HubSection(
    'rooms',
    'Digital Rooms',
    'Salas digitales',
    Icons.meeting_room_outlined,
    'room space sala espacio',
    (c, r) => _go(c, AppRoutePaths.digitalRooms),
  ),
  _HubSection(
    'icons',
    'App Icons',
    'Iconos de la app',
    Icons.apps,
    'launcher icon icono lanzador',
    (c, r) => _go(c, AppRoutePaths.appIcons),
  ),
  _HubSection(
    'iconStudio',
    'Icon Studio',
    'Estudio de iconos',
    Icons.brush_outlined,
    'custom icon design diseñar icono',
    (c, r) => showAppIconMaker(c),
  ),
  _HubSection(
    'environment',
    'Environmental Effects',
    'Efectos ambientales',
    Icons.wb_twilight_outlined,
    'weather time of day rain snow clima lluvia nieve',
    (c, r) => _go(c, AppRoutePaths.environment),
  ),
  _HubSection(
    'audio',
    'Ambient Audio',
    'Sonido ambiental',
    Icons.graphic_eq,
    'sound music ambience sonido música',
    (c, r) => showAmbientAudioSheet(c),
  ),
  _HubSection(
    'layouts',
    'Layouts',
    'Diseños',
    Icons.dashboard_customize_outlined,
    'headers cards dividers frames encabezados tarjetas',
    (c, r) => _go(c, AppRoutePaths.layouts),
  ),
  _HubSection(
    'presets',
    'Saved Presets',
    'Ajustes guardados',
    Icons.bookmarks_outlined,
    'arrangements saved export import arreglos guardados',
    (c, r) => _go(c, AppRoutePaths.seasonalPresets),
  ),
  _HubSection(
    'imported',
    'Imported Assets',
    'Elementos importados',
    Icons.folder_open_outlined,
    'uploads pictures stickers imágenes pegatinas',
    (c, r) => _go(c, AppRoutePaths.importedAssets),
  ),
  _HubSection(
    'accessibility',
    'Accessibility',
    'Accesibilidad',
    Icons.accessibility_new,
    'contrast motion text size contraste movimiento',
    (c, r) => _go(c, AppRoutePaths.settingsAccessibility),
  ),
  _HubSection(
    'performance',
    'Performance & Storage',
    'Rendimiento y almacenamiento',
    Icons.speed,
    'battery storage cache batería almacenamiento caché',
    (c, r) => _go(c, AppRoutePaths.appearancePerformance),
  ),
  _HubSection(
    'banners',
    'Headmate banners',
    'Banners de headmates',
    Icons.panorama_outlined,
    'banner profile perfil',
    (c, r) => _go(c, AppRoutePaths.headmateBanners),
  ),
  _HubSection(
    'launch',
    'Launch screen & greeting',
    'Pantalla de inicio y saludo',
    Icons.waving_hand_outlined,
    'launch greeting splash saludo',
    (c, r) => _go(c, AppRoutePaths.settingsLaunch),
  ),
];

/// Picks a collection background and puts it on the theme in use (keeping
/// an undo). Built-in themes are copied first so they stay untouched.
Future<void> pickCollectionBackground(
  BuildContext context,
  WidgetRef ref,
) async {
  final state = await ref.read(appearanceProvider.future);
  if (!context.mounted) return;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final look = state.active(dark: dark);
  final id = await showBackgroundGallery(
    context,
    current: look.background.kind == BgKind.builtin
        ? look.background.builtin
        : null,
  );
  if (id == null || !context.mounted) return;
  final store = ref.read(appearanceProvider.notifier);
  final previousId = state.auto ? null : state.activeId;
  final saved = await store.saveLook(
    look.copyWith(
      background: look.background.copyWith(kind: BgKind.builtin, builtin: id),
    ),
  );
  if (!state.auto) await store.activate(saved.id);
  if (!context.mounted) return;
  final name = collectionBackgroundById(id)?.name ?? id;
  ref.read(appearanceUndoProvider.notifier).record(
    tr(context, '$name is your background.', '$name es tu fondo.'),
    () async {
      if (previousId != null) {
        await store.activate(previousId);
      } else {
        await store.saveLook(look);
      }
    },
  );
}

/// The top of Settings › Appearance: search, every section, recently used
/// items and the independent layers.
class AppearanceHub extends ConsumerStatefulWidget {
  const AppearanceHub({super.key});
  @override
  ConsumerState<AppearanceHub> createState() => _AppearanceHubState();
}

class _AppearanceHubState extends ConsumerState<AppearanceHub> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = Localizations.localeOf(context).languageCode == 'es';
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final s in _sections)
        if (q.isEmpty ||
            s.en.toLowerCase().contains(q) ||
            s.es.toLowerCase().contains(q) ||
            s.keywords.contains(q))
          s,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppearanceUndoBanner(),
          PrismTextField(
            hintText: tr(context, 'Search appearance', 'Buscar en apariencia'),
            prefixIcon: const Icon(Icons.search),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth > 700
                  ? 4
                  : (box.maxWidth > 420 ? 3 : 2);
              final w = (box.maxWidth - (cols - 1) * 8) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in shown)
                    SizedBox(
                      width: w,
                      child: PrismSurface(
                        key: ValueKey('hub:${s.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        onTap: () => s.open(context, ref),
                        semanticLabel: es ? s.es : s.en,
                        child: Row(
                          children: [
                            Icon(
                              s.icon,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                es ? s.es : s.en,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tr(context, 'Nothing matches.', 'Nada coincide.'),
                textAlign: TextAlign.center,
              ),
            ),
          if (q.isEmpty) ...[const _RecentStrip(), const _LayersCard()],
        ],
      ),
    );
  }
}

/// Recently used living looks, backgrounds and icons, one tap away.
class _RecentStrip extends ConsumerWidget {
  const _RecentStrip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(appearanceLibraryProvider);
    final items = <(String, String, VoidCallback)>[];
    for (final r in lib.recents.take(12)) {
      final i = r.indexOf(':');
      if (i < 0) continue;
      final kind = r.substring(0, i), id = r.substring(i + 1);
      switch (kind) {
        case 'genre':
          final c = collectionById(id);
          if (c != null) {
            items.add((
              '${c.emoji} ${c.name}',
              'genre',
              () => context.push(AppRoutePaths.livingGenre(id)),
            ));
          }
        case 'bg':
          final b = collectionBackgroundById(id);
          if (b != null)
            items.add((
              '🖼️ ${b.name}',
              'bg',
              () => pickCollectionBackground(context, ref),
            ));
        case 'icon':
          final p = appIconPresetById(id);
          if (p != null)
            items.add((
              '📱 ${p.en}',
              'icon',
              () => context.push(AppRoutePaths.appIcons),
            ));
      }
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrismSectionHeader(
            title: tr(context, 'RECENTLY USED', 'USADOS RECIENTEMENTE'),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final i in items)
                PrismChip(label: i.$1, selected: false, onTap: i.$3),
            ],
          ),
        ],
      ),
    );
  }
}

/// Every appearance layer and what it's set to. Each is separate: changing
/// or resetting one never touches another.
class _LayersCard extends ConsumerWidget {
  const _LayersCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(seasonalPrefsProvider);
    final appearance = ref.watch(appearanceProvider).value;
    final dark = theme.brightness == Brightness.dark;
    final look = appearance?.active(dark: dark);
    final icon = ref.watch(appIconProvider).value ?? 'classic';
    final n = ref.read(seasonalPrefsProvider.notifier);
    String? lookName(String? id) {
      final v = id == null ? null : variationById(id);
      return v?.name;
    }

    final seasonal = prefs.manualVariation ?? prefs.permanentVariation;
    final rows = <(String, String, VoidCallback?)>[
      (tr(context, 'Base theme', 'Tema base'), look?.name ?? '—', null),
      (
        tr(context, 'Collection background', 'Fondo de colección'),
        look == null || !look.background.isCustom
            ? tr(context, 'Theme default', 'Del tema')
            : collectionBackgroundName(look.background),
        null,
      ),
      (
        tr(context, 'Living decorations', 'Decoraciones vivas'),
        lookName(prefs.livingVariation) ?? tr(context, 'Off', 'Apagado'),
        prefs.livingVariation == null
            ? null
            : () => n.update((p) => p.copyWith(livingVariation: null)),
      ),
      (
        tr(context, 'Layout', 'Diseño'),
        lookName(prefs.layoutVariation) ?? tr(context, 'Off', 'Apagado'),
        prefs.layoutVariation == null
            ? null
            : () => n.update((p) => p.copyWith(layoutVariation: null)),
      ),
      (
        tr(context, 'Seasonal decorations', 'Decoraciones de temporada'),
        lookName(seasonal) ??
            (prefs.autoSchedule
                ? tr(context, 'Scheduled', 'Programadas')
                : tr(context, 'Off', 'Apagado')),
        seasonal == null
            ? null
            : () => n.update(
                (p) =>
                    p.copyWith(manualVariation: null, permanentVariation: null),
              ),
      ),
      (
        tr(context, 'Environmental effects', 'Efectos ambientales'),
        prefs.env.any
            ? tr(context, 'On', 'Activados')
            : tr(context, 'Off', 'Apagado'),
        prefs.env.any
            ? () => n.update((p) => p.copyWith(env: const EnvSettings()))
            : null,
      ),
      (
        tr(context, 'Ambient audio', 'Sonido ambiental'),
        prefs.audioOn
            ? (ambienceCatalog
                      .where((a) => a.id == prefs.audioId)
                      .firstOrNull
                      ?.label ??
                  '')
            : tr(context, 'Off', 'Apagado'),
        prefs.audioOn
            ? () => n.update((p) => p.copyWith(audioOn: false))
            : null,
      ),
      (
        tr(context, 'App icon', 'Icono de la app'),
        appIconPresetById(icon)?.en ?? tr(context, 'Custom', 'Propio'),
        icon == 'classic' || !appIconSupported
            ? null
            : () => ref.read(appIconProvider.notifier).select('classic'),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PrismSurface(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(context, 'Your layers', 'Tus capas'),
              style: theme.textTheme.titleSmall,
            ),
            Text(
              tr(
                context,
                'Each layer is separate: changing one never changes another. Fonts and colours are set in their own sections.',
                'Cada capa es independiente: cambiar una nunca cambia otra.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            for (final r in rows)
              Row(
                children: [
                  Expanded(
                    child: Text(r.$1, style: theme.textTheme.bodyMedium),
                  ),
                  Flexible(
                    child: Text(
                      r.$2,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: r.$3 == null
                        ? null
                        : IconButton(
                            tooltip: tr(
                              context,
                              'Turn off ${r.$1}',
                              'Apagar ${r.$1}',
                            ),
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            icon: const Icon(Icons.close),
                            onPressed: r.$3,
                          ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Ambient audio ──────────────────────────────────────────────────────

/// Ambient sound on its own: off by default, and only ever quiet and
/// optional. Rooms can bring their own ambience on top of this choice.
Future<void> showAmbientAudioSheet(BuildContext context) =>
    PrismSheet.show<void>(
      context: context,
      title: tr(context, 'Ambient audio', 'Sonido ambiental'),
      builder: (_) => const _AudioSheet(),
    );

class _AudioSheet extends ConsumerWidget {
  const _AudioSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(seasonalPrefsProvider);
    final n = ref.read(seasonalPrefsProvider.notifier);
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismSwitchRow(
          title: tr(
            context,
            'Play ambient sound',
            'Reproducir sonido ambiental',
          ),
          subtitle: tr(
            context,
            'Off until you turn it on. Plays softly alongside music and stops when Prism is in the background.',
            'Apagado hasta que lo actives. Suena bajito y se detiene en segundo plano.',
          ),
          value: prefs.audioOn,
          onChanged: (v) => n.update(
            (p) => p.copyWith(
              audioOn: v,
              audioId: p.audioId ?? 'fire',
              performance: v && p.performance == DecoPerformance.off
                  ? DecoPerformance.minimal
                  : p.performance,
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
                  label: '${a.emoji} ${es ? a.labelEs : a.label}',
                  selected: prefs.audioId == a.id,
                  onTap: () => n.update((p) => p.copyWith(audioId: a.id)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(tr(context, 'Volume', 'Volumen')),
          Slider(
            value: prefs.audioVolume,
            onChanged: (v) => n.update((p) => p.copyWith(audioVolume: v)),
          ),
        ],
      ],
    );
  }
}

// ── Imported assets ────────────────────────────────────────────────────

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// Pictures the person imported for backgrounds, with sizes. Only pictures
/// no theme uses can be removed, so nothing in use ever disappears.
class ImportedAssetsScreen extends ConsumerStatefulWidget {
  const ImportedAssetsScreen({super.key});
  @override
  ConsumerState<ImportedAssetsScreen> createState() =>
      _ImportedAssetsScreenState();
}

class _ImportedAssetsScreenState extends ConsumerState<ImportedAssetsScreen> {
  List<File> _files = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dir = await ref.read(backgroundsDirProvider.future);
    final files = dir == null || !dir.existsSync()
        ? <File>[]
        : dir.listSync().whereType<File>().toList();
    if (mounted) {
      setState(() {
        _files = files;
        _loading = false;
      });
    }
  }

  Set<String> _inUse(AppearanceState? s) => {
    if (s != null)
      for (final l in s.all) ...[
        ?l.background.image,
        for (final b in l.pageBackgrounds.values) ?b.image,
      ],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appearance = ref.watch(appearanceProvider).value;
    final used = _inUse(appearance);
    final total = _files.fold<int>(
      0,
      (a, f) => a + (f.existsSync() ? f.lengthSync() : 0),
    );
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Imported assets', 'Elementos importados'),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: _loading
            ? const PrismLoadingState()
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  40 + NavBarInset.of(context),
                ),
                children: [
                  Text(
                    tr(
                      context,
                      'Background pictures you imported: ${_files.length}, using ${formatBytes(total)}. Pictures a theme uses are kept; only unused ones can be removed. Stickers you import live in the scrapbook sticker library.',
                      'Imágenes de fondo importadas: ${_files.length}, ocupan ${formatBytes(total)}. Las que usa un tema se conservan; solo puedes quitar las que no se usan.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  if (_files.isEmpty)
                    PrismSurface(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        tr(
                          context,
                          'Nothing imported yet.',
                          'Nada importado todavía.',
                        ),
                      ),
                    ),
                  for (final f in _files)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PrismSurface(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                f,
                                width: 56,
                                height: 90,
                                fit: BoxFit.cover,
                                cacheWidth: 120,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatBytes(
                                      f.existsSync() ? f.lengthSync() : 0,
                                    ),
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Text(
                                    used.contains(f.uri.pathSegments.last)
                                        ? tr(
                                            context,
                                            'In use by a theme',
                                            'En uso por un tema',
                                          )
                                        : tr(context, 'Not used', 'Sin usar'),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (!used.contains(f.uri.pathSegments.last))
                              PrismButton(
                                label: tr(context, 'Remove', 'Quitar'),
                                tone: PrismButtonTone.outlined,
                                density: PrismControlDensity.compact,
                                onPressed: () async {
                                  final ok = await PrismDialog.confirm(
                                    context: context,
                                    title: tr(
                                      context,
                                      'Remove this picture?',
                                      '¿Quitar esta imagen?',
                                    ),
                                    message: tr(
                                      context,
                                      'No theme uses it.',
                                      'Ningún tema la usa.',
                                    ),
                                    confirmLabel: tr(
                                      context,
                                      'Remove',
                                      'Quitar',
                                    ),
                                    destructive: true,
                                  );
                                  if (!ok) return;
                                  try {
                                    await f.delete();
                                  } catch (_) {}
                                  await _load();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ── Performance & storage ──────────────────────────────────────────────

class AppearancePerformanceScreen extends ConsumerStatefulWidget {
  const AppearancePerformanceScreen({super.key});
  @override
  ConsumerState<AppearancePerformanceScreen> createState() =>
      _PerformanceState();
}

class _PerformanceState extends ConsumerState<AppearancePerformanceScreen> {
  int _imported = 0;

  @override
  void initState() {
    super.initState();
    ref.read(backgroundsDirProvider.future).then((dir) {
      if (dir == null || !dir.existsSync() || !mounted) return;
      final n = dir.listSync().whereType<File>().fold<int>(
        0,
        (a, f) => a + f.lengthSync(),
      );
      setState(() => _imported = n);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = Localizations.localeOf(context).languageCode == 'es';
    final prefs = ref.watch(seasonalPrefsProvider);
    final n = ref.read(seasonalPrefsProvider.notifier);
    final battery = prefs.integrations['batterySaver'] == true;
    final cache = PaintingBinding.instance.imageCache;
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(
          context,
          'Performance & storage',
          'Rendimiento y almacenamiento',
        ),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + NavBarInset.of(context)),
          children: [
            PrismSectionHeader(
              title: tr(context, 'DECORATIONS', 'DECORACIONES'),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in DecoPerformance.values)
                  PrismChip(
                    label: es ? m.es : m.en,
                    selected: prefs.performance == m,
                    onTap: () => n.update((p) => p.copyWith(performance: m)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              es ? prefs.performance.descEs : prefs.performance.descEn,
              style: theme.textTheme.bodySmall,
            ),
            PrismSwitchRow(
              title: tr(context, 'Battery saver', 'Ahorro de batería'),
              subtitle: tr(
                context,
                'Keeps decorations on screen but stops everything that moves, falls or glows.',
                'Mantiene las decoraciones pero detiene todo lo que se mueve o brilla.',
              ),
              value: battery,
              onChanged: (v) => n.update(
                (p) => p.copyWith(
                  integrations: {...p.integrations, 'batterySaver': v},
                ),
              ),
            ),
            PrismSwitchRow(
              title: tr(context, 'Reduced motion', 'Movimiento reducido'),
              value: prefs.reducedMotion,
              onChanged: (v) => n.update((p) => p.copyWith(reducedMotion: v)),
            ),
            Text(
              tr(
                context,
                'Most moving decorations at once',
                'Máximo de decoraciones en movimiento',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            Slider(
              value: prefs.layers.maxAnimated.toDouble().clamp(0, 60),
              max: 60,
              divisions: 12,
              label: '${prefs.layers.maxAnimated}',
              onChanged: (v) => n.update(
                (p) => p.copyWith(
                  performance: DecoPerformance.custom,
                  layers: p.layers.copyWith(maxAnimated: v.round()),
                ),
              ),
            ),
            Text(
              tr(
                context,
                'Particle limit (falling things)',
                'Límite de partículas',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            Slider(
              value: prefs.layers.particleDensity,
              onChanged: (v) => n.update(
                (p) => p.copyWith(
                  performance: DecoPerformance.custom,
                  layers: p.layers.copyWith(particleDensity: v),
                ),
              ),
            ),
            Text(
              tr(
                context,
                'Decorations pause when Prism is in the background and only draw what\'s on screen.',
                'Las decoraciones se pausan en segundo plano y solo se dibuja lo visible.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            PrismSectionHeader(title: tr(context, 'STORAGE', 'ALMACENAMIENTO')),
            PrismSurface(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      context,
                      'Built-in collections: 0 bytes downloaded',
                      'Colecciones incluidas: 0 bytes descargados',
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      context,
                      'All ${livingCollections.fold<int>(0, (a, c) => a + c.variations.length)} living looks, ${collectionBackgrounds.length} collection backgrounds, ${allAppIconPresets.length} app icons, every seasonal look and the decoration asset library are drawn by your device. Nothing needs downloading, everything works offline, and there is nothing to remove per collection. Only live weather (if you turn it on) uses the internet.',
                      'Todos los estilos, fondos, iconos y decoraciones los dibuja tu dispositivo. No hay que descargar nada, todo funciona sin conexión. Solo el clima real (si lo activas) usa internet.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const Divider(height: 20),
                  Text(
                    '${tr(context, 'Imported background pictures', 'Fondos importados')}: ${formatBytes(_imported)}',
                  ),
                  Text(
                    '${tr(context, 'Picture cache in memory', 'Caché de imágenes en memoria')}: ${formatBytes(cache.currentSizeBytes)}',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PrismButton(
                        label: tr(context, 'Clear caches', 'Vaciar cachés'),
                        icon: Icons.cleaning_services_outlined,
                        tone: PrismButtonTone.outlined,
                        density: PrismControlDensity.compact,
                        onPressed: () {
                          cache.clear();
                          cache.clearLiveImages();
                          setState(() {});
                          PrismToast.show(
                            context,
                            message: tr(
                              context,
                              'Caches cleared. Your designs and presets are untouched.',
                              'Cachés vaciadas. Tus diseños y ajustes no cambian.',
                            ),
                          );
                        },
                      ),
                      PrismButton(
                        label: tr(
                          context,
                          'Imported assets',
                          'Elementos importados',
                        ),
                        icon: Icons.folder_open_outlined,
                        tone: PrismButtonTone.outlined,
                        density: PrismControlDensity.compact,
                        onPressed: () =>
                            context.push(AppRoutePaths.importedAssets),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
