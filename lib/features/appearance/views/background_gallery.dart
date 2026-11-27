import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/shared/theme/collection_backgrounds.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Lets the person pick one of the 120 collection backgrounds (returns its
/// id). Thumbnails are drawn lazily as they scroll into view.
Future<String?> showBackgroundGallery(
  BuildContext context, {
  String? current,
}) => PrismSheet.show<String>(
  context: context,
  title: tr(context, 'Collection backgrounds', 'Fondos de colección'),
  maxHeightFactor: 0.92,
  builder: (_) => _Gallery(current: current),
);

class _Gallery extends ConsumerStatefulWidget {
  const _Gallery({this.current});
  final String? current;
  @override
  ConsumerState<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends ConsumerState<_Gallery> {
  String _q = '';

  /// A collection id, or 'all' / '★' / 'recent'.
  String _tab = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = Localizations.localeOf(context).languageCode == 'es';
    final lib = ref.watch(appearanceLibraryProvider);
    final q = _q.trim().toLowerCase();
    final List<CollectionBackground> list;
    if (_tab == '★') {
      list = [
        for (final id in lib.favoritesIn('bg:')) ?collectionBackgroundById(id),
      ];
    } else if (_tab == 'recent') {
      list = [
        for (final id in lib.recentsIn('bg:')) ?collectionBackgroundById(id),
      ];
    } else {
      list = [
        for (final b in collectionBackgrounds)
          if (_tab == 'all' || b.collection == _tab) b,
      ];
    }
    final shown = [
      for (final b in list)
        if (q.isEmpty ||
            b.name.toLowerCase().contains(q) ||
            b.collection.contains(q) ||
            b.style.contains(q))
          b,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismTextField(
          hintText: tr(
            context,
            'Search ${collectionBackgrounds.length} backgrounds',
            'Buscar ${collectionBackgrounds.length} fondos',
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
              for (final t in [
                ('all', tr(context, 'All', 'Todos')),
                ('★', tr(context, '★ Favourites', '★ Favoritos')),
                ('recent', tr(context, 'Recent', 'Recientes')),
                for (final c in backgroundCollections) (c.$1, es ? c.$3 : c.$2),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    label: t.$2,
                    selected: _tab == t.$1,
                    onTap: () => setState(() => _tab = t.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 460,
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    _tab == '★'
                        ? tr(
                            context,
                            'Hold a background to add it to your favourites.',
                            'Mantén pulsado un fondo para añadirlo a favoritos.',
                          )
                        : tr(context, 'Nothing matches.', 'Nada coincide.'),
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 110,
                    mainAxisExtent: 196,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final b = shown[i];
                    final fav = lib.isFavorite('bg:${b.id}');
                    final selected = widget.current == b.id;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: b.name,
                      child: GestureDetector(
                        key: ValueKey('bg:${b.id}'),
                        onTap: () {
                          ref
                              .read(appearanceLibraryProvider.notifier)
                              .used('bg:${b.id}');
                          Navigator.of(context).pop(b.id);
                        },
                        onLongPress: () => ref
                            .read(appearanceLibraryProvider.notifier)
                            .toggleFavorite('bg:${b.id}'),
                        child: Column(
                          children: [
                            Container(
                              height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  width: selected ? 3 : 1,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CustomPaint(painter: _BgPainter(b)),
                                    if (fav)
                                      const Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Icon(
                                          Icons.star_rounded,
                                          size: 18,
                                          color: Color(0xFFFFD54F),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              b.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
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
  }
}

class _BgPainter extends CustomPainter {
  _BgPainter(this.b);
  final CollectionBackground b;
  @override
  void paint(Canvas canvas, Size size) => b.paint(canvas, size);
  @override
  bool shouldRepaint(_BgPainter o) => o.b != b;
}

/// The name of whatever a collection background spec shows.
String collectionBackgroundName(BgSpec s) =>
    builtInBackgrounds[s.builtin]?.name ??
    collectionBackgroundById(s.builtin)?.name ??
    s.builtin;
