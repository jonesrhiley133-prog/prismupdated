import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/shared/fonts/font_catalog.dart';
import 'package:prism_plurality/shared/fonts/font_prefs.dart';
import 'package:prism_plurality/shared/fonts/prism_fonts.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// What the person picked in the browser. [key] null means "use the
/// default / inherit".
class FontPick {
  const FontPick(this.key);
  final String? key;
}

const _samples = <String, String>{
  'latin': 'Pack my box with five dozen liquor jugs',
  'cyrillic': 'Съешь же ещё этих мягких французских булок',
  'greek': 'Ξεσκεπάζω την ψυχοφθόρα βδελυγμία',
  'korean': '다람쥐 헌 쳇바퀴에 타고파',
  'japanese': 'いろはにほへと ちりぬるを プリズム',
  'chinese': '天地玄黄 宇宙洪荒 棱镜',
  'arabic': 'نص حكيم له سر قاطع وذو شأن عظيم',
  'hebrew': 'דג סקרן שט בים מאוכזב ולפתע מצא חברה',
  'thai': 'เป็นมนุษย์สุดประเสริฐเลิศคุณค่า',
  'devanagari': 'ऋषियों को सताने वाले दुष्ट राक्षसों',
  'bengali': 'আমি বাংলায় গান গাই',
};

/// Opens Prism's font browser: search, 19 categories, writing systems,
/// favourites, recents and imported fonts, each with a live preview. Fonts
/// are fetched only as their rows scroll into view.
Future<FontPick?> showPrismFontBrowser(
  BuildContext context, {
  String? current,
  bool allowDefault = true,
  String defaultLabel = 'Default (inherit)',
}) => PrismSheet.showFullScreen<FontPick>(
  context: context,
  builder: (ctx, scroll) => _FontBrowser(
    current: current,
    allowDefault: allowDefault,
    defaultLabel: defaultLabel,
  ),
);

class _FontBrowser extends ConsumerStatefulWidget {
  const _FontBrowser({
    required this.current,
    required this.allowDefault,
    required this.defaultLabel,
  });
  final String? current;
  final bool allowDefault;
  final String defaultLabel;

  @override
  ConsumerState<_FontBrowser> createState() => _FontBrowserState();
}

class _FontBrowserState extends ConsumerState<_FontBrowser> {
  final _search = TextEditingController();
  final _sample = TextEditingController();
  String _tab = 'all'; // all, fav, recent, imported
  String? _category;
  String? _script;

  @override
  void dispose() {
    _search.dispose();
    _sample.dispose();
    super.dispose();
  }

  List<PrismFont> _filtered(FontPrefs prefs) {
    final q = _search.text.trim().toLowerCase();
    Iterable<PrismFont> it = fontCatalog;
    if (_tab == 'fav') {
      it = it.where((f) => prefs.favorites.contains(f.id));
    } else if (_tab == 'recent') {
      final order = prefs.recents;
      it = fontCatalog.where((f) => order.contains(f.id)).toList()
        ..sort((a, b) => order.indexOf(a.id).compareTo(order.indexOf(b.id)));
    }
    if (_category != null)
      it = it.where((f) => f.categories.contains(_category));
    if (_script != null) it = it.where((f) => f.scripts.contains(_script));
    if (q.isNotEmpty) {
      it = it.where(
        (f) =>
            f.family.toLowerCase().contains(q) ||
            f.categories.any(
              (c) => (fontCategories[c] ?? '').toLowerCase().contains(q),
            ),
      );
    }
    return it.toList();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(fontPrefsProvider);
    final theme = Theme.of(context);
    final fonts = _tab == 'imported' ? const <PrismFont>[] : _filtered(prefs);
    final imported =
        _tab == 'imported' ||
            (_tab == 'all' &&
                _search.text.isEmpty &&
                _category == null &&
                _script == null)
        ? prefs.imported
        : const <ImportedFont>[];
    final sample = _sample.text.isNotEmpty
        ? _sample.text
        : _samples[_script ?? 'latin']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: PrismTextField(
            controller: _search,
            hintText: tr(
              context,
              'Search ${fontCatalog.length} fonts',
              'Buscar ${fontCatalog.length} fuentes',
            ),
            prefixIcon: const Icon(Icons.search),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final t in const [
                ('all', 'All', 'Todas'),
                ('fav', 'Favorites', 'Favoritas'),
                ('recent', 'Recent', 'Recientes'),
                ('imported', 'Imported', 'Importadas'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    label: tr(context, t.$2, t.$3),
                    selected: _tab == t.$1,
                    onTap: () => setState(() => _tab = t.$1),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in fontCategories.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    label: c.value,
                    selected: _category == c.key,
                    onTap: () => setState(
                      () => _category = _category == c.key ? null : c.key,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final s in fontScripts.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    label: s.value,
                    selected: _script == s.key,
                    onTap: () => setState(
                      () => _script = _script == s.key ? null : s.key,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: PrismTextField(
            controller: _sample,
            hintText: tr(
              context,
              'Type your own preview text',
              'Escribe tu texto de vista previa',
            ),
            prefixIcon: const Icon(Icons.edit_outlined),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
            itemCount:
                (widget.allowDefault ? 1 : 0) +
                imported.length +
                fonts.length +
                (fonts.isEmpty && imported.isEmpty ? 1 : 0),
            itemBuilder: (context, i) {
              var n = i;
              if (widget.allowDefault) {
                if (n == 0) {
                  return _Row(
                    title: widget.defaultLabel,
                    sample: sample,
                    fontKey: null,
                    selected: widget.current == null,
                    favorite: null,
                    onPick: () =>
                        Navigator.of(context).pop(const FontPick(null)),
                  );
                }
                n--;
              }
              if (n < imported.length) {
                final f = imported[n];
                return _Row(
                  title: f.name,
                  sample: sample,
                  fontKey: f.key,
                  imported: prefs.imported,
                  selected: widget.current == f.key,
                  favorite: null,
                  badge: tr(context, 'Imported', 'Importada'),
                  onPick: () => Navigator.of(context).pop(FontPick(f.key)),
                );
              }
              n -= imported.length;
              if (fonts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      tr(
                        context,
                        'No fonts match.',
                        'Ninguna fuente coincide.',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              final f = fonts[n];
              return _Row(
                title: f.family,
                sample: sample,
                fontKey: f.id,
                selected: widget.current == f.id,
                favorite: prefs.favorites.contains(f.id),
                badge: f.decorative
                    ? tr(context, 'Decorative', 'Decorativa')
                    : null,
                onFavorite: () =>
                    ref.read(fontPrefsProvider.notifier).toggleFavorite(f.id),
                onPick: () => Navigator.of(context).pop(FontPick(f.id)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Row extends ConsumerStatefulWidget {
  const _Row({
    required this.title,
    required this.sample,
    required this.fontKey,
    required this.selected,
    required this.favorite,
    required this.onPick,
    this.onFavorite,
    this.badge,
    this.imported = const [],
  });
  final String title, sample;
  final String? fontKey;
  final bool selected;
  final bool? favorite;
  final VoidCallback onPick;
  final VoidCallback? onFavorite;
  final String? badge;
  final List<ImportedFont> imported;

  @override
  ConsumerState<_Row> createState() => _RowState();
}

class _RowState extends ConsumerState<_Row> {
  @override
  void initState() {
    super.initState();
    // Only rows that are actually built (scrolled into view) load a font.
    PrismFonts.ensureLoaded(widget.fontKey, imported: widget.imported);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(fontLoadTickProvider);
    final ready =
        widget.fontKey == null ||
        PrismFonts.isLoaded(widget.fontKey) ||
        (!PrismFonts.isCatalog(widget.fontKey) &&
            !PrismFonts.isImported(widget.fontKey));
    final style = PrismFonts.style(widget.fontKey, theme.textTheme.titleMedium);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.title,
      child: InkWell(
        borderRadius: prismCorners(context, 12),
        onTap: widget.onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.badge != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· ${widget.badge}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: ready ? 1 : 0.35,
                      child: Text(
                        widget.sample,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.favorite != null)
                IconButton(
                  tooltip: widget.favorite!
                      ? tr(context, 'Remove favorite', 'Quitar favorita')
                      : tr(context, 'Favorite', 'Favorita'),
                  icon: Icon(
                    widget.favorite!
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: widget.favorite! ? theme.colorScheme.primary : null,
                  ),
                  onPressed: widget.onFavorite,
                ),
              if (widget.selected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
