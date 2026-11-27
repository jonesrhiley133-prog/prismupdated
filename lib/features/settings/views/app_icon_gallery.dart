import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:prism_plurality/core/app_icon/app_icon.dart';
import 'package:prism_plurality/core/app_icon/custom_icon.dart';
import 'package:prism_plurality/core/app_icon/icon_art.dart';
import 'package:prism_plurality/core/app_icon/icon_catalog.dart';
import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/settings/views/app_icon_maker.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Launcher mask shapes for previews.
const iconMasks = <(String, String, String)>[
  ('squircle', 'Squircle', 'Squircle'),
  ('circle', 'Circle', 'Círculo'),
  ('rounded', 'Rounded square', 'Cuadrado redondeado'),
  ('teardrop', 'Teardrop', 'Lágrima'),
  ('square', 'Square', 'Cuadrado'),
];

/// Clips [child] the way a launcher with [shape] would.
class IconMask extends StatelessWidget {
  const IconMask({super.key, required this.shape, required this.child});
  final String shape;
  final Widget child;
  @override
  Widget build(BuildContext context) => switch (shape) {
    'circle' => ClipOval(child: child),
    'square' => child,
    'rounded' => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: child,
    ),
    'teardrop' => ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(999),
        bottomLeft: Radius.circular(999),
        bottomRight: Radius.circular(999),
        topRight: Radius.circular(8),
      ),
      child: child,
    ),
    _ => ClipPath(
      clipper: ShapeBorderClipper(
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(60),
        ),
      ),
      child: child,
    ),
  };
}

/// Draws an icon design at [size], zoomed to the part launchers show.
class IconArtView extends StatefulWidget {
  const IconArtView({
    super.key,
    required this.art,
    this.size = 64,
    this.shape = 'squircle',
    this.monochrome = false,
  });
  final IconArt art;
  final double size;
  final String shape;
  final bool monochrome;

  @override
  State<IconArtView> createState() => _IconArtViewState();
}

ui.Image? _logo;

class _IconArtViewState extends State<IconArtView> {
  @override
  void initState() {
    super.initState();
    if (_logo == null) {
      prismLogoImage().then((l) {
        _logo = l;
        if (mounted) setState(() {});
      }, onError: (_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.monochrome
        ? IconArt(
            bg: 'solid',
            fg: 'prism',
            logo: 'tint',
            c1: Theme.of(context).colorScheme.primaryContainer.toARGB32(),
            c2: 0,
            c3: Theme.of(context).colorScheme.onPrimaryContainer.toARGB32(),
          )
        : widget.art;
    return SizedBox.square(
      dimension: widget.size,
      child: IconMask(
        shape: widget.shape,
        child: CustomPaint(painter: _ArtPainter(art, _logo)),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art, this.logo);
  final IconArt art;
  final ui.Image? logo;
  @override
  void paint(Canvas canvas, Size size) {
    // Launchers show the middle two-thirds of an adaptive icon.
    final full = size.width / 0.66;
    canvas.save();
    canvas.translate(-(full - size.width) / 2, -(full - size.height) / 2);
    paintIconArt(canvas, full, art, logo: logo);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter o) => o.art != art || o.logo != logo;
}

/// A preset tile's picture: drawn art for gallery designs, the bundled
/// preview for the original set.
Widget appIconPicture(AppIconPreset p, double size, String shape) =>
    p.art != null
    ? IconArtView(art: p.art!, size: size, shape: shape)
    : SizedBox.square(
        dimension: size,
        child: IconMask(
          shape: shape,
          child: Image.asset(p.asset, fit: BoxFit.cover, gaplessPlayback: true),
        ),
      );

String _platformNote(BuildContext context) {
  if (kIsWeb) {
    return tr(
      context,
      'On the web, icons change this browser tab\'s icon.',
      'En la web, los iconos cambian el icono de esta pestaña.',
    );
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => tr(
      context,
      'Permanent icons switch Prism\'s real launcher icon (some launchers take a few seconds). Seasonal and custom icons go on a home-screen shortcut, because Android only switches between icons built into the app; once added, seasonal changes update it without asking again.',
      'Los iconos permanentes cambian el icono real del lanzador. Los de temporada y personalizados van en un acceso directo, porque Android solo cambia entre iconos incluidos; después se actualiza sin preguntar.',
    ),
    TargetPlatform.iOS => tr(
      context,
      'This build of Prism can\'t change its icon on iPhone or iPad yet. You can still browse, design and export icons as images.',
      'Esta versión no puede cambiar su icono en iPhone o iPad todavía. Puedes explorar, diseñar y exportar iconos como imágenes.',
    ),
    _ => tr(
      context,
      'Desktop systems don\'t let apps change their own icon while running. Export any icon as an image to use for a shortcut.',
      'Los sistemas de escritorio no permiten que las apps cambien su icono. Exporta cualquier icono como imagen para un acceso directo.',
    ),
  };
}

class AppIconGalleryScreen extends ConsumerStatefulWidget {
  const AppIconGalleryScreen({super.key});
  @override
  ConsumerState<AppIconGalleryScreen> createState() =>
      _AppIconGalleryScreenState();
}

class _AppIconGalleryScreenState extends ConsumerState<AppIconGalleryScreen> {
  String _q = '';

  /// all | ★ | recent | classic | plural | <art group> | seasonal
  String _group = 'all';
  String _shape = 'squircle';
  String? _season;
  bool _auto = false;

  @override
  void initState() {
    super.initState();
    ref.read(appIconServiceProvider).autoSeasonal().then((v) {
      if (mounted) setState(() => _auto = v);
    });
  }

  Future<void> _export(String name, Future<Uint8List> Function() png) async {
    final bytes = await png();
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'image/png', name: '$name.png'),
        ],
        fileNameOverrides: ['$name.png'],
      ),
    );
  }

  Future<void> _preview(AppIconPreset p) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final lib = ref.read(appIconProvider.notifier);
    final current = ref.read(appIconProvider).value;
    await PrismSheet.show<void>(
      context: context,
      title: es ? p.es : p.en,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final fav = ref
              .watch(appearanceLibraryProvider)
              .isFavorite('icon:${p.id}');
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final bg in const [Color(0xFFF2EEE8), Color(0xFF15131C)])
                    Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: appIconPicture(p, 96, _shape),
                    ),
                ],
              ),
              Text(
                tr(
                  ctx,
                  'On a light and a dark home screen',
                  'En una pantalla de inicio clara y oscura',
                ),
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final m in iconMasks)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: appIconPicture(p, 40, m.$1),
                    ),
                  if (p.art != null)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Tooltip(
                        message: tr(
                          ctx,
                          'Themed (monochrome)',
                          'Tema (monocromo)',
                        ),
                        child: IconArtView(
                          art: p.art!,
                          size: 40,
                          monochrome: true,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              PrismButton(
                label: p.id == current
                    ? tr(ctx, 'In use', 'En uso')
                    : tr(ctx, 'Use as app icon', 'Usar como icono'),
                icon: Icons.check,
                tone: PrismButtonTone.filled,
                expanded: true,
                onPressed: !appIconSupported || p.id == current
                    ? () {}
                    : () async {
                        final ok = await lib.select(p.id);
                        ref
                            .read(appearanceLibraryProvider.notifier)
                            .used('icon:${p.id}');
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (!mounted) return;
                        if (ok && current != null) {
                          ref
                              .read(appearanceUndoProvider.notifier)
                              .record(
                                tr(context, 'Icon changed.', 'Icono cambiado.'),
                                () => lib.select(current),
                              );
                        }
                        PrismToast.show(
                          context,
                          message: ok
                              ? tr(context, 'Icon changed', 'Icono cambiado')
                              : tr(
                                  context,
                                  'This device can\'t change the icon.',
                                  'Este dispositivo no puede cambiar el icono.',
                                ),
                        );
                      },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PrismButton(
                      label: fav
                          ? tr(ctx, 'Favourite', 'Favorito')
                          : tr(ctx, 'Add to favourites', 'Añadir a favoritos'),
                      icon: fav
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      tone: PrismButtonTone.outlined,
                      onPressed: () => ref
                          .read(appearanceLibraryProvider.notifier)
                          .toggleFavorite('icon:${p.id}'),
                    ),
                  ),
                  if (p.art != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: PrismButton(
                        label: tr(ctx, 'Export', 'Exportar'),
                        icon: Icons.ios_share,
                        tone: PrismButtonTone.outlined,
                        onPressed: () => _export(
                          'prism-${p.id}',
                          () => renderIconArtPng(p.art!, 1024),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _seasonPreview(IconDesign d) async {
    await PrismSheet.show<void>(
      context: context,
      title: d.en,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final m in iconMasks.take(3))
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: IconArtView(art: d.art, size: 84, shape: m.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          PrismButton(
            label: kIsWeb
                ? tr(ctx, 'Use on this tab', 'Usar en esta pestaña')
                : tr(
                    ctx,
                    'Add as home-screen icon',
                    'Añadir a la pantalla de inicio',
                  ),
            icon: Icons.add_to_home_screen,
            tone: PrismButtonTone.filled,
            expanded: true,
            onPressed: !appIconSupported
                ? () {}
                : () async {
                    final ok = await ref
                        .read(appIconServiceProvider)
                        .setDesign(d);
                    ref
                        .read(appearanceLibraryProvider.notifier)
                        .used('icon:${d.id}');
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (!mounted) return;
                    PrismToast.show(
                      context,
                      message: ok
                          ? (kIsWeb
                                ? tr(context, 'Icon changed', 'Icono cambiado')
                                : tr(
                                    context,
                                    'Confirm to add it to your home screen',
                                    'Confirma para añadirlo a la pantalla de inicio',
                                  ))
                          : tr(
                              context,
                              'This launcher doesn\'t support home-screen shortcuts.',
                              'Este lanzador no admite accesos directos.',
                            ),
                    );
                  },
          ),
          const SizedBox(height: 8),
          PrismButton(
            label: tr(ctx, 'Export', 'Exportar'),
            icon: Icons.ios_share,
            tone: PrismButtonTone.outlined,
            expanded: true,
            onPressed: () => _export(
              'prism-${d.id.replaceAll('.', '-')}',
              () => renderIconArtPng(d.art, 1024),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = Localizations.localeOf(context).languageCode == 'es';
    final lib = ref.watch(appearanceLibraryProvider);
    final current = ref.watch(appIconProvider).value ?? 'classic';
    final q = _q.trim().toLowerCase();
    bool match(String name, String group) =>
        q.isEmpty || name.toLowerCase().contains(q) || group.contains(q);

    final groups = <(String, String)>[
      ('all', tr(context, 'All', 'Todos')),
      ('★', tr(context, '★ Favourites', '★ Favoritos')),
      ('recent', tr(context, 'Recent', 'Recientes')),
      for (final g in iconArtGroups) (g.$1, es ? g.$3 : g.$2),
      ('classic', tr(context, 'Original set', 'Serie original')),
      ('plural', tr(context, 'Plurality', 'Pluralidad')),
      ('seasonal', tr(context, 'Seasonal library', 'Biblioteca de temporada')),
    ];

    List<AppIconPreset> shown() {
      final all = allAppIconPresets;
      final list = switch (_group) {
        '★' => [
          for (final id in lib.favoritesIn('icon:')) ?appIconPresetById(id),
        ],
        'recent' => [
          for (final id in lib.recentsIn('icon:')) ?appIconPresetById(id),
        ],
        'all' => all,
        _ => [
          for (final p in all)
            if (p.group == _group) p,
        ],
      };
      return [
        for (final p in list)
          if (match(es ? p.es : p.en, p.group)) p,
      ];
    }

    Widget tile(String id, String label, Widget pic, VoidCallback onTap) =>
        Semantics(
          button: true,
          selected: id == current,
          label: label,
          child: InkWell(
            key: ValueKey('icon:$id'),
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              width: 84,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        width: 2,
                        color: id == current
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: pic,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        );

    final seasonal = _group == 'seasonal';
    final seasonCols = seasonalCollections;
    final season = _season ?? seasonCols.first.id;

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'App icons', 'Iconos de la app'),
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: Icons.brush_outlined,
            tooltip: tr(context, 'Icon Studio', 'Estudio de iconos'),
            onPressed: () => showAppIconMaker(context),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + NavBarInset.of(context)),
          children: [
            Text(_platformNote(context), style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            PrismTextField(
              hintText: tr(
                context,
                'Search ${allAppIconPresets.length} icons',
                'Buscar ${allAppIconPresets.length} iconos',
              ),
              prefixIcon: const Icon(Icons.search),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final g in groups)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: g.$2,
                        selected: _group == g.$1,
                        onTap: () => setState(() => _group = g.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  tr(context, 'Preview shape', 'Forma de vista previa'),
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final m in iconMasks)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: PrismChip(
                              label: es ? m.$3 : m.$2,
                              selected: _shape == m.$1,
                              onTap: () => setState(() => _shape = m.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!seasonal) ...[
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final p in shown())
                    tile(
                      p.id,
                      es ? p.es : p.en,
                      appIconPicture(p, 70, _shape),
                      () => _preview(p),
                    ),
                ],
              ),
              if (shown().isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _group == '★'
                        ? tr(
                            context,
                            'Add icons to your favourites to find them here.',
                            'Añade iconos a favoritos para verlos aquí.',
                          )
                        : _group == 'recent'
                        ? tr(
                            context,
                            'Icons you use show up here.',
                            'Los iconos que uses aparecerán aquí.',
                          )
                        : tr(context, 'Nothing matches.', 'Nada coincide.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 12),
              if (current != 'classic')
                PrismButton(
                  label: tr(
                    context,
                    'Restore the original icon',
                    'Restaurar el icono original',
                  ),
                  icon: Icons.restore,
                  tone: PrismButtonTone.outlined,
                  expanded: true,
                  onPressed: !appIconSupported
                      ? () {}
                      : () => ref
                            .read(appIconProvider.notifier)
                            .select('classic'),
                ),
            ] else ...[
              Text(
                tr(
                  context,
                  'Fifteen icons for each holiday and season, kept apart from the permanent set. Seasonal decorations never change your icon on their own.',
                  'Quince iconos para cada fiesta y estación. Las decoraciones de temporada nunca cambian tu icono por sí solas.',
                ),
                style: theme.textTheme.bodySmall,
              ),
              PrismSwitchRow(
                title: tr(
                  context,
                  'Change the icon for holidays automatically',
                  'Cambiar el icono en fiestas automáticamente',
                ),
                subtitle: tr(
                  context,
                  'Uses a seasonal icon while a holiday you celebrate is showing in Seasonal Living, then goes back. Android: updates the Prism home-screen shortcut once you\'ve added one.',
                  'Usa un icono de temporada mientras se muestra una fiesta que celebras y luego vuelve. Android: actualiza el acceso directo de Prism.',
                ),
                value: _auto,
                onChanged: (v) async {
                  await ref.read(appIconServiceProvider).setAutoSeasonal(v);
                  setState(() => _auto = v);
                },
              ),
              PrismSelect<String>(
                labelText: tr(
                  context,
                  'Holiday or season',
                  'Fiesta o estación',
                ),
                value: season,
                items: [
                  for (final c in seasonCols)
                    PrismSelectItem(value: c.id, label: '${c.emoji} ${c.name}'),
                ],
                onChanged: (v) => setState(() => _season = v),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final d in seasonalIconDesigns(season))
                    if (match(d.en, season))
                      tile(
                        d.id,
                        d.en.split(' · ').last,
                        IconArtView(art: d.art, size: 70, shape: _shape),
                        () => _seasonPreview(d),
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
