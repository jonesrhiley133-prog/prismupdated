import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/appearance/appearance_undo_banner.dart';
import 'package:prism_plurality/features/seasonal/decor_assets.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decor_painter.dart';
import 'package:prism_plurality/features/seasonal/decor_preview.dart';
import 'package:prism_plurality/features/seasonal/layouts_screen.dart';
import 'package:prism_plurality/features/seasonal/living_data.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Turns a living look on. Applying one never touches the theme, colours,
/// background or fonts; it only adds decorations.
void applyLivingLook(
  WidgetRef ref,
  String? variationId, {
  String? undoMessage,
}) {
  final previous = ref.read(effectiveLivingProvider);
  if (undoMessage != null && previous != variationId) {
    ref
        .read(appearanceUndoProvider.notifier)
        .record(undoMessage, () => applyLivingLook(ref, previous));
  }
  ref.read(decorLayersProvider).setLiving(variationId);
  if (variationId != null) {
    final g = variationId.split('.').first;
    ref.read(appearanceLibraryProvider.notifier).used('genre:$g');
  }
}

// ── Families & genres ──────────────────────────────────────────────────

/// Permanent decoration genres, grouped into their eight families.
class LivingCollectionsScreen extends ConsumerStatefulWidget {
  const LivingCollectionsScreen({super.key});
  @override
  ConsumerState<LivingCollectionsScreen> createState() =>
      _LivingCollectionsScreenState();
}

class _LivingCollectionsScreenState
    extends ConsumerState<LivingCollectionsScreen> {
  final _q = TextEditingController();
  String _family = 'all';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lib = ref.watch(appearanceLibraryProvider);
    final q = _q.text.trim().toLowerCase();
    final livingId = ref.watch(effectiveLivingProvider);
    final current = livingId == null ? null : variationById(livingId);

    bool hit(SeasonalCollection c) =>
        q.isEmpty ||
        c.name.toLowerCase().contains(q) ||
        c.blurb.toLowerCase().contains(q) ||
        c.variations.any((v) => v.name.toLowerCase().contains(q));

    final favs = [
      for (final id in lib.favoritesIn('genre:')) ?collectionById(id),
    ].where(hit).toList();
    final recent = [
      for (final id in lib.recentsIn('genre:').take(10)) ?collectionById(id),
    ].where(hit).toList();

    Widget genreRow(SeasonalCollection c) {
      final fav = lib.isFavorite('genre:${c.id}');
      return PrismListRow(
        leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
        title: Text(c.name),
        subtitle: Text(
          '${c.variations.length} ${tr(context, 'looks', 'estilos')} · ${c.blurb}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: fav
              ? tr(context, 'Remove favourite', 'Quitar favorito')
              : tr(context, 'Favourite', 'Favorito'),
          icon: Icon(
            fav ? Icons.star_rounded : Icons.star_outline_rounded,
            color: fav ? theme.colorScheme.primary : null,
          ),
          onPressed: () => ref
              .read(appearanceLibraryProvider.notifier)
              .toggleFavorite('genre:${c.id}'),
        ),
        showChevron: true,
        onTap: () => context.push(AppRoutePaths.livingGenre(c.id)),
      );
    }

    final families = [
      for (final f in livingFamilies)
        if (_family == 'all' || _family == f.$1) f,
    ];

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Living Collections', 'Colecciones vivas'),
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: Icons.category_outlined,
            tooltip: tr(context, 'Decoration assets', 'Elementos decorativos'),
            onPressed: () => context.push(AppRoutePaths.livingAssets),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(600),
          padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + NavBarInset.of(context)),
          children: [
            const AppearanceUndoBanner(),
            Text(
              tr(
                context,
                'Year-round aesthetics, each with 25 looks. A living look sits on its own layer: it never changes your theme, colours, background or fonts, and seasonal looks can show alongside it.',
                'Estéticas para todo el año, cada una con 25 estilos. Un estilo vivo va en su propia capa: nunca cambia tu tema, colores, fondo ni fuentes.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (current != null)
              PrismSurface(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    DecorPreview(
                      items: arrangementForVariation(current),
                      width: 60,
                      height: 100,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, 'Showing now', 'Mostrando ahora'),
                            style: theme.textTheme.labelSmall,
                          ),
                          Text(
                            current.name,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            collectionById(current.collectionId)?.name ?? '',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    PrismButton(
                      label: tr(context, 'Remove', 'Quitar'),
                      tone: PrismButtonTone.outlined,
                      density: PrismControlDensity.compact,
                      onPressed: () => applyLivingLook(
                        ref,
                        null,
                        undoMessage: tr(
                          context,
                          '${current.name} removed.',
                          '${current.name} quitado.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            PrismTextField(
              controller: _q,
              hintText: tr(
                context,
                'Search genres and looks',
                'Buscar géneros y estilos',
              ),
              prefixIcon: const Icon(Icons.search),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  PrismChip(
                    label: tr(context, 'All', 'Todo'),
                    selected: _family == 'all',
                    onTap: () => setState(() => _family = 'all'),
                  ),
                  for (final f in livingFamilies)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: PrismChip(
                        label: '${f.$3} ${f.$2}',
                        selected: _family == f.$1,
                        onTap: () => setState(() => _family = f.$1),
                      ),
                    ),
                ],
              ),
            ),
            if (_family == 'all' && favs.isNotEmpty) ...[
              PrismSectionHeader(title: tr(context, 'FAVOURITES', 'FAVORITOS')),
              for (final c in favs) genreRow(c),
            ],
            if (_family == 'all' && recent.isNotEmpty && q.isEmpty) ...[
              PrismSectionHeader(
                title: tr(context, 'RECENTLY USED', 'USADOS RECIENTEMENTE'),
              ),
              for (final c in recent.take(4)) genreRow(c),
            ],
            for (final f in families) ...[
              if (livingInGroup(f.$1).any(hit))
                PrismSectionHeader(title: f.$2.toUpperCase()),
              for (final c in livingInGroup(f.$1))
                if (hit(c)) genreRow(c),
            ],
            if (!livingCollections.any(hit))
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(context, 'Nothing matches.', 'Nada coincide.'),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One genre and its 25 looks.
class LivingGenreScreen extends ConsumerWidget {
  const LivingGenreScreen({super.key, required this.genreId});
  final String genreId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = collectionById(genreId);
    if (c == null || c.kind != SeasonalKind.living) {
      return PrismPageScaffold(
        topBar: PrismTopBar(
          title: tr(context, 'Collection', 'Colección'),
          showBackButton: true,
        ),
        body: Center(
          child: Text(
            tr(
              context,
              'This collection is gone.',
              'Esta colección ya no existe.',
            ),
          ),
        ),
      );
    }
    final living = ref.watch(effectiveLivingProvider);
    final theme = Theme.of(context);
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
                  const AppearanceUndoBanner(),
                  Text(c.blurb, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (final e in c.variations.first.icons)
                        Text(e, style: const TextStyle(fontSize: 22)),
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
                  mainAxisExtent: 330,
                ),
                itemCount: c.variations.length,
                itemBuilder: (context, i) {
                  final v = c.variations[i];
                  final on = living == v.id;
                  return Semantics(
                    button: true,
                    selected: on,
                    label: v.name,
                    child: InkWell(
                      key: ValueKey('living-look:${v.id}'),
                      borderRadius: prismCorners(context, 16),
                      onTap: () => _look(context, ref, v),
                      child: Column(
                        children: [
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
                              if (on)
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
    SeasonalVariation v,
  ) async {
    final on = ref.read(effectiveLivingProvider) == v.id;
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
            label: on
                ? tr(ctx, 'Remove this look', 'Quitar este estilo')
                : tr(ctx, 'Use this look', 'Usar este estilo'),
            icon: on ? Icons.close : Icons.check,
            tone: PrismButtonTone.filled,
            onPressed: () {
              applyLivingLook(
                ref,
                on ? null : v.id,
                undoMessage: on
                    ? tr(context, '${v.name} removed.', '${v.name} quitado.')
                    : tr(
                        context,
                        '${v.name} is on. Your theme is untouched.',
                        '${v.name} está activo. Tu tema no cambia.',
                      ),
              );
              Navigator.of(ctx).pop();
            },
          ),
          const SizedBox(height: 8),
          PrismButton(
            label: ref.read(effectiveLayoutProvider).$1 == v.id
                ? tr(ctx, 'Turn its layout off', 'Apagar su diseño')
                : tr(ctx, 'Use its layout too', 'Usar también su diseño'),
            icon: Icons.dashboard_customize_outlined,
            tone: PrismButtonTone.outlined,
            onPressed: () {
              final on = ref.read(effectiveLayoutProvider).$1 == v.id;
              applyLayout(
                ref,
                on ? null : v.id,
                undoMessage: on
                    ? tr(context, 'Layout off.', 'Diseño apagado.')
                    : tr(
                        context,
                        '${v.name} layout on. Choose its parts in Layouts.',
                        'Diseño de ${v.name} activado.',
                      ),
              );
              Navigator.of(ctx).pop();
            },
          ),
          const SizedBox(height: 8),
          PrismButton(
            label: tr(ctx, 'Mix into my arrangement', 'Añadir a mi arreglo'),
            icon: Icons.design_services_outlined,
            tone: PrismButtonTone.outlined,
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(AppRoutePaths.seasonalStudio, extra: v.id);
            },
          ),
        ],
      ),
    );
  }
}

// ── Asset library ──────────────────────────────────────────────────────

/// A decoration glyph (emoji, line art, frame, tape, shape or a styled
/// garland / light string…) drawn small for lists and pickers.
class DecorGlyphView extends StatelessWidget {
  const DecorGlyphView(this.glyph, {super.key, this.size = 32});
  final String glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = decorStyleOf(glyph);
    if (style != null) {
      final kind = switch (style.part) {
        'g' => DecoKind.garland,
        'l' => DecoKind.fairyLights,
        'b' => DecoKind.border,
        'c' => DecoKind.corner,
        _ => DecoKind.particles,
      };
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecorPreview(
          items: [decorItemForAsset(DecorAsset('p', '', '', glyph, kind), 'p')],
          width: size * 1.6,
          height: size * 1.6,
          showMockUi: false,
        ),
      );
    }
    if (glyph.length > 3 && glyph[2] == ':') {
      return SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _GlyphPainter(glyph, cs.primary, cs.tertiary),
        ),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Text(
          glyph,
          style: TextStyle(
            fontSize: size * 0.8,
            height: 1,
            fontFamilyFallback: const [
              'NotoColorEmoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.a, this.b);
  final String glyph;
  final Color a, b;
  @override
  void paint(Canvas canvas, Size size) => paintDecorGlyph(
    canvas,
    glyph,
    size.center(Offset.zero),
    size.shortestSide * 0.9,
    tint: a,
    tint2: b,
  );
  @override
  bool shouldRepaint(_GlyphPainter o) =>
      o.glyph != glyph || o.a != a || o.b != b;
}

/// Lets the person pick one decoration from the 1,500+ asset library.
Future<DecorAsset?> showDecorAssetPicker(BuildContext context) =>
    PrismSheet.show<DecorAsset>(
      context: context,
      title: tr(context, 'Decoration assets', 'Elementos decorativos'),
      maxHeightFactor: 0.92,
      builder: (_) => const _AssetBrowser(pick: true),
    );

/// The asset library on its own page, for browsing and favouriting.
class DecorAssetLibraryScreen extends StatelessWidget {
  const DecorAssetLibraryScreen({super.key});
  @override
  Widget build(BuildContext context) => PrismPageScaffold(
    topBar: PrismTopBar(
      title: tr(context, 'Decoration assets', 'Elementos decorativos'),
      showBackButton: true,
    ),
    body: const ClampedBody(child: _AssetBrowser(pick: false)),
  );
}

class _AssetBrowser extends ConsumerStatefulWidget {
  const _AssetBrowser({required this.pick});
  final bool pick;
  @override
  ConsumerState<_AssetBrowser> createState() => _AssetBrowserState();
}

class _AssetBrowserState extends ConsumerState<_AssetBrowser> {
  String _q = '';

  /// A category id, or '★' (favourites) / 'recent'.
  String _tab = 'hanging';

  void _chosen(DecorAsset a) {
    ref.read(appearanceLibraryProvider.notifier).used('asset:${a.id}');
    if (widget.pick) {
      Navigator.of(context).pop(a);
    } else {
      _details(a);
    }
  }

  void _details(DecorAsset a) {
    PrismSheet.show<void>(
      context: context,
      title: a.name,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecorGlyphView(a.glyph, size: 96),
          const SizedBox(height: 8),
          Text(decorAssetCategoryById(a.category)?.name ?? ''),
          const SizedBox(height: 12),
          PrismButton(
            label: tr(
              ctx,
              'Place in Decoration Studio',
              'Colocar en el Estudio',
            ),
            icon: Icons.add,
            tone: PrismButtonTone.filled,
            expanded: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(
                AppRoutePaths.seasonalStudio,
                extra: 'asset:${a.id}',
              );
            },
          ),
        ],
      ),
    );
  }

  /// A fixed-height grid in the picker sheet; the rest of the page otherwise.
  Widget _sized(Widget child) => widget.pick
      ? SizedBox(height: 420, child: child)
      : Expanded(child: child);

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(appearanceLibraryProvider);
    final theme = Theme.of(context);
    final q = _q.trim();
    final List<DecorAsset> shown;
    if (q.isNotEmpty) {
      shown = [
        for (final a in decorAssets)
          if (a.matches(q)) a,
      ];
    } else if (_tab == '★') {
      shown = [for (final id in lib.favoritesIn('asset:')) ?decorAssetById(id)];
    } else if (_tab == 'recent') {
      shown = [for (final id in lib.recentsIn('asset:')) ?decorAssetById(id)];
    } else {
      shown = decorAssetsIn(_tab);
    }

    final body = Column(
      mainAxisSize: widget.pick ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          child: PrismTextField(
            hintText: tr(
              context,
              'Search ${decorAssets.length} decorations',
              'Buscar ${decorAssets.length} decoraciones',
            ),
            prefixIcon: const Icon(Icons.search),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final t in [
                ('★', tr(context, '★ Favourites', '★ Favoritos')),
                ('recent', tr(context, 'Recent', 'Recientes')),
                for (final c in decorAssetCategories)
                  (c.id, '${c.emoji} ${c.name}'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    label: t.$2,
                    selected: q.isEmpty && _tab == t.$1,
                    onTap: () => setState(() {
                      _tab = t.$1;
                      _q = '';
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _sized(
          shown.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _tab == '★' && q.isEmpty
                          ? tr(
                              context,
                              'Tap the star on any decoration to keep it here.',
                              'Toca la estrella de cualquier decoración para guardarla aquí.',
                            )
                          : _tab == 'recent' && q.isEmpty
                          ? tr(
                              context,
                              'Decorations you use show up here.',
                              'Las decoraciones que uses aparecerán aquí.',
                            )
                          : tr(context, 'Nothing matches.', 'Nada coincide.'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 92,
                    mainAxisExtent: 104,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final a = shown[i];
                    final fav = lib.isFavorite('asset:${a.id}');
                    return Semantics(
                      button: true,
                      label: a.name,
                      child: InkWell(
                        key: ValueKey('asset:${a.id}'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _chosen(a),
                        onLongPress: () => ref
                            .read(appearanceLibraryProvider.notifier)
                            .toggleFavorite('asset:${a.id}'),
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                const SizedBox(height: 6),
                                DecorGlyphView(a.glyph, size: 44),
                                const SizedBox(height: 4),
                                Text(
                                  a.name,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 16,
                                tooltip: fav
                                    ? tr(
                                        context,
                                        'Remove favourite',
                                        'Quitar favorito',
                                      )
                                    : tr(context, 'Favourite', 'Favorito'),
                                icon: Icon(
                                  fav
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: fav ? theme.colorScheme.primary : null,
                                ),
                                onPressed: () => ref
                                    .read(appearanceLibraryProvider.notifier)
                                    .toggleFavorite('asset:${a.id}'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
    if (widget.pick) return body;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: body,
    );
  }
}
