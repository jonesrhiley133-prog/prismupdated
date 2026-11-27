import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_plurality/features/scrapbook/scrap_cover.dart';
import 'package:prism_plurality/features/scrapbook/scrap_cover_templates.dart';
import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_page.dart';
import 'package:prism_plurality/features/scrapbook/scrap_seasonal.dart';
import 'package:prism_plurality/features/scrapbook/scrap_texture_painter.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Holidays and seasons in the order that suits today. This only orders
/// the list; nothing is applied until you tap something.
final scrapSeasonOrderProvider = Provider<List<SeasonalCollection>>((ref) {
  final p = ref.watch(seasonalPrefsProvider);
  // The date when the picker is opened is all it needs (no ticking clock).
  final now = DateTime.now();
  return suggestedCollections(
    now,
    region: p.region,
    hemisphere: p.hemisphere,
    hidden: p.hidden,
    celebrated: p.celebrated,
  );
});

/// A row of holiday/season chips; the first one is what's closest to today.
class SeasonalCollectionChips extends ConsumerWidget {
  const SeasonalCollectionChips({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(scrapSeasonOrderProvider);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in list)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PrismChip(
                label: '${c.emoji} ${c.name}',
                selected: selected == c.id,
                onTap: () => onSelect(c.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// Picks the holiday or season to browse (defaults to the closest to today).
mixin _CollectionChoice<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String? _chosen;
  SeasonalCollection? get collection {
    final order = ref.watch(scrapSeasonOrderProvider);
    return collectionById(_chosen ?? (order.isEmpty ? '' : order.first.id));
  }
}

/// Seasonal page textures: pick a holiday, then one of its looks.
class SeasonalTexturePicker extends ConsumerStatefulWidget {
  const SeasonalTexturePicker({
    super.key,
    required this.current,
    required this.onPick,
  });
  final String current;
  final ValueChanged<String> onPick;
  @override
  ConsumerState<SeasonalTexturePicker> createState() => _SeasonalTextureState();
}

class _SeasonalTextureState extends ConsumerState<SeasonalTexturePicker>
    with _CollectionChoice {
  @override
  Widget build(BuildContext context) {
    final c = collection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            tr(context, 'Holidays & seasons', 'Fiestas y estaciones'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SeasonalCollectionChips(
          selected: c?.id,
          onSelect: (id) => setState(() => _chosen = id),
        ),
        if (c != null)
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final v in c.variations)
                  Builder(
                    builder: (context) {
                      final t = seasonalTexture(v);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8, top: 6),
                        child: Semantics(
                          button: true,
                          selected: widget.current == t.id,
                          label: v.name,
                          child: GestureDetector(
                            key: ValueKey('seas-tex:${v.id}'),
                            onTap: () => widget.onPick(t.id),
                            child: Column(
                              children: [
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: widget.current == t.id
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: CustomPaint(
                                      painter: ScrapTexturePainter(
                                        kind: t.kind,
                                        c1: t.c1,
                                        c2: t.c2,
                                        seed: t.seed,
                                        scale: t.scale,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 62,
                                  child: Text(
                                    v.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Seasonal cover designs: pick a holiday, then one of its looks.
class SeasonalCoverPicker extends ConsumerStatefulWidget {
  const SeasonalCoverPicker({super.key, required this.onPick, this.title = ''});
  final ValueChanged<CoverTemplate> onPick;
  final String title;
  @override
  ConsumerState<SeasonalCoverPicker> createState() => _SeasonalCoverState();
}

class _SeasonalCoverState extends ConsumerState<SeasonalCoverPicker>
    with _CollectionChoice {
  @override
  Widget build(BuildContext context) {
    final c = collection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            tr(context, 'Holidays & seasons', 'Fiestas y estaciones'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SeasonalCollectionChips(
          selected: c?.id,
          onSelect: (id) => setState(() => _chosen = id),
        ),
        if (c != null)
          SizedBox(
            height: 160,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final v in c.variations)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 8),
                    child: Semantics(
                      button: true,
                      label: v.name,
                      child: GestureDetector(
                        key: ValueKey('seas-cover:${v.id}'),
                        onTap: () => widget.onPick(seasonalCoverTemplate(v)),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 118,
                              child: ScrapCoverView(
                                design: coverFromVariation(v),
                                title: widget.title,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 90,
                              child: Text(
                                v.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Seasonal page layouts: pick a holiday, then one of its looks.
class SeasonalPageTemplatePicker extends ConsumerStatefulWidget {
  const SeasonalPageTemplatePicker({super.key, required this.onPick});
  final ValueChanged<ScrapPageTemplate> onPick;
  @override
  ConsumerState<SeasonalPageTemplatePicker> createState() =>
      _SeasonalPageState();
}

class _SeasonalPageState extends ConsumerState<SeasonalPageTemplatePicker>
    with _CollectionChoice {
  @override
  Widget build(BuildContext context) {
    final c = collection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            tr(context, 'Holidays & seasons', 'Fiestas y estaciones'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SeasonalCollectionChips(
          selected: c?.id,
          onSelect: (id) => setState(() => _chosen = id),
        ),
        if (c != null)
          SizedBox(
            height: 132,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final v in c.variations)
                  Padding(
                    padding: const EdgeInsets.only(right: 10, top: 8),
                    child: Semantics(
                      button: true,
                      label: v.name,
                      child: GestureDetector(
                        key: ValueKey('seas-page:${v.id}'),
                        onTap: () => widget.onPick(seasonalPageTemplate(v)),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 70,
                              height: 92,
                              child: _SeasonalThumb(v),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 78,
                              child: Text(
                                v.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SeasonalThumb extends StatelessWidget {
  const _SeasonalThumb(this.v);
  final SeasonalVariation v;
  @override
  Widget build(BuildContext context) {
    final r = seasonalPageTemplate(v).build();
    final s = r.style!;
    final tex = scrapTextureById(s.texture.id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Color(s.color)),
          if (tex != null)
            CustomPaint(
              painter: ScrapTexturePainter(
                kind: tex.kind,
                c1: tex.c1,
                c2: tex.c2,
                seed: tex.seed,
                scale: tex.scale,
                opacity: 0.6,
              ),
            ),
          LayoutBuilder(
            builder: (_, c) => Stack(
              children: [
                for (final e in r.els)
                  Positioned(
                    left: e.x * c.maxWidth,
                    top: e.y * c.maxHeight,
                    width: e.w * c.maxWidth,
                    height: e.h * c.maxHeight,
                    child: e.text != null && e.type.name == 'sticker'
                        ? FittedBox(
                            child: Text(
                              e.text!,
                              style: const TextStyle(fontSize: 40),
                            ),
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: e.type.name == 'photo'
                                  ? Colors.white54
                                  : Colors.transparent,
                              border: e.type.name == 'text'
                                  ? Border(
                                      bottom: BorderSide(
                                        color: Color(e.color ?? 0xFF000000),
                                        width: 1.5,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One frame browser for everywhere frames are picked: the 100+ built-in
/// frames by category, and four frames per holiday or season.
class ScrapFrameBrowser extends ConsumerStatefulWidget {
  const ScrapFrameBrowser({
    super.key,
    required this.current,
    required this.onPick,
  });
  final String current;
  final ValueChanged<String> onPick;
  @override
  ConsumerState<ScrapFrameBrowser> createState() => _FrameBrowserState();
}

class _FrameBrowserState extends ConsumerState<ScrapFrameBrowser>
    with _CollectionChoice {
  String _cat = scrapFrameCategories.first;

  @override
  Widget build(BuildContext context) {
    final seasonal = _cat == seasonalFrameCategory;
    final c = seasonal ? collection : null;
    final list = seasonal
        ? (c == null ? const <ScrapFrameSpec>[] : seasonalFramesFor(c.id))
        : [
            for (final f in scrapFrames)
              if (f.category == _cat) f,
          ];
    const pic = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF35D0FF), Color(0xFFFF7A9C)],
        ),
      ),
      child: Center(child: Icon(Icons.image, color: Colors.white70, size: 28)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final cat in [
                  ...scrapFrameCategories,
                  seasonalFrameCategory,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(
                      label: cat,
                      selected: _cat == cat,
                      onTap: () => setState(() => _cat = cat),
                    ),
                  ),
              ],
            ),
          ),
          if (seasonal) ...[
            const SizedBox(height: 6),
            SeasonalCollectionChips(
              selected: c?.id,
              onSelect: (id) => setState(() => _chosen = id),
            ),
          ],
          const SizedBox(height: 8),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 92,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => Semantics(
                button: true,
                selected: list[i].id == widget.current,
                label: list[i].name,
                child: GestureDetector(
                  onTap: () => widget.onPick(list[i].id),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ScrapFramedImage(frame: list[i], child: pic),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
