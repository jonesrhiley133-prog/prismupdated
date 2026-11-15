import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/dictionary/importer/wiki_providers.dart';
import 'package:prism_plurality/features/dictionary/utils/dictionary_import.dart';
import 'package:prism_plurality/features/dictionary/views/dictionary_import_flow.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

Future<void> openUniversalImport(BuildContext context) => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const UniversalImportScreen()));

enum _Method { url, file, api, paste, history }

/// A fetched or parsed article plus the user's choices.
class _Item {
  _Item(this.a, {this.selected = true});
  WikiArticle a;
  bool selected;
}

class UniversalImportScreen extends ConsumerStatefulWidget {
  const UniversalImportScreen({super.key});
  @override
  ConsumerState<UniversalImportScreen> createState() => _UniversalImportScreenState();
}

class _UniversalImportScreenState extends ConsumerState<UniversalImportScreen> {
  final _http = WikiHttp();
  _Method _method = _Method.url;
  final _url = TextEditingController();
  final _more = TextEditingController();
  final _paste = TextEditingController();
  final _api = TextEditingController();

  WikiProvider? _provider;
  WikiRequest? _request;
  List<String> _titles = [];
  int _limit = 200;
  bool _busy = false;
  bool _cancel = false;
  int _done = 0;
  int _total = 0;
  String? _error;
  String _sourceLabel = '';
  final _items = <_Item>[];
  final _failed = <String>[];

  String? _collection; // null = use source categories / none
  bool _useCategories = true;
  TermDuplicateAction _dup = TermDuplicateAction.skip;
  bool _keepFullText = false;

  @override
  void dispose() {
    for (final c in [_url, _more, _paste, _api]) {
      c.dispose();
    }
    super.dispose();
  }

  void _err(Object e) => setState(() => _error = tr(context, wikiErrorText(e).$1, wikiErrorText(e).$2));

  Future<void> _detect() async {
    setState(() {
      _busy = true;
      _error = null;
      _provider = null;
      _titles = [];
    });
    try {
      final (p, r) = await detectProvider(_http, _url.text);
      setState(() {
        _provider = p;
        _request = r;
        _sourceLabel = '${p.name} · ${r.uri.host}';
      });
      if (r.scope == WikiScope.article) await _fetchTitles([r.page!], p, r);
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _listAll() async {
    final p = _provider, r = _request;
    if (p == null || r == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final t = await p.listTitles(_http, r, limit: _limit);
      setState(() => _titles = t);
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Fetches articles one by one (politely), with progress and cancel.
  Future<void> _fetchTitles(List<String> titles, WikiProvider p, WikiRequest r) async {
    setState(() {
      _busy = true;
      _cancel = false;
      _done = 0;
      _total = titles.length;
      _error = null;
    });
    final existing = {for (final i in _items) i.a.title.toLowerCase()};
    for (final t in titles) {
      if (_cancel || !mounted) break;
      try {
        final a = await p.fetchArticle(_http, r, t);
        if (!existing.contains(a.title.toLowerCase())) _items.add(_Item(a));
        _failed.remove(t);
      } catch (e) {
        if (!_failed.contains(t)) _failed.add(t);
        if (e is WikiImportError && (e.code == 'blocked_by_robots' || e.code == 'auth_required' || e.code == 'rate_limited')) {
          _err(e);
          break;
        }
      }
      if (mounted) setState(() => _done++);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _fetchMoreUrls() async {
    final urls = [for (final l in _more.text.split(RegExp(r'[\n\s]+'))) if (l.trim().startsWith('http')) l.trim()];
    if (urls.isEmpty) return;
    for (final u in urls) {
      if (_cancel) break;
      try {
        final (p, r) = await detectProvider(_http, u);
        await _fetchTitles([r.page ?? u], p, r);
      } catch (e) {
        _failed.add(u);
      }
    }
    _more.clear();
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xml', 'wiki', 'wikitext', 'mediawiki', 'html', 'htm', 'json', 'csv', 'tsv', 'txt', 'md', 'markdown', 'zip'], withData: true);
    final f = res?.files.firstOrNull;
    if (f == null || f.bytes == null) return;
    try {
      final list = parseImportFile(f.name, f.bytes!);
      setState(() {
        _sourceLabel = f.name;
        _items.addAll([for (final a in list) _Item(a, selected: a.ok)]);
      });
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _fromApi() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uri = Uri.tryParse(_api.text.trim());
      if (uri == null || !uri.hasScheme) throw const WikiImportError('not_a_url');
      if (uri.path.endsWith('api.php')) {
        _url.text = uri.toString();
        setState(() => _method = _Method.url);
        await _detect();
        return;
      }
      final res = await _http.get(uri, json: true);
      final list = parseImportFile('api.json', res.bodyBytes);
      setState(() {
        _sourceLabel = uri.host;
        _items.addAll([for (final a in list) _Item(a, selected: a.ok)]);
      });
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fromPaste() {
    final t = _paste.text;
    if (t.trim().isEmpty) return;
    final looksWiki = t.contains('[[') || t.contains("'''") || t.contains('{{');
    final looksMd = RegExp(r'^#{1,3} ', multiLine: true).hasMatch(t);
    final looksXml = t.contains('<mediawiki') || t.contains('<page>');
    final list = looksXml
        ? parseMediaWikiXml(t)
        : (looksMd ? parseMarkdown(t) : (looksWiki ? [WikiArticle(title: wikitextToText(t).split('\n').first, content: wikitextToText(t))] : parseImportFile('pasted.txt', utf8.encode(t))));
    setState(() {
      _sourceLabel = tr(context, 'Pasted text', 'Texto pegado');
      _items.addAll([for (final a in list) _Item(a, selected: a.ok)]);
    });
  }

  Future<void> _import() async {
    final chosen = _items.where((i) => i.selected && i.a.ok).toList();
    if (chosen.isEmpty) return;
    setState(() => _busy = true);
    final notifier = ref.read(trackerNotifierProvider.notifier);
    final terms = ref.read(trackerKindProvider(TrackerKind.dictTerm)).value ?? const <TrackerRecord>[];
    final cols = ref.read(trackerKindProvider(TrackerKind.dictCollection)).value ?? const <TrackerRecord>[];
    final cands = [for (final (i, it) in chosen.indexed) it.a.toCandidate(i)];
    final extra = {
      for (final (i, it) in chosen.indexed)
        'a$i': {
          'categories': it.a.categories.isEmpty ? null : it.a.categories,
          'images': it.a.images.isEmpty ? null : it.a.images,
          'references': it.a.references.isEmpty ? null : it.a.references.take(20).toList(),
          'updated': it.a.updated?.toIso8601String(),
          'license': it.a.license,
          'fullText': _keepFullText && it.a.content.length > it.a.summary.length ? it.a.content : null,
          DictField.description: null,
        },
    };
    try {
      final r = await importTerms(
        notifier: notifier,
        chosen: cands,
        existingTerms: terms,
        existingCollections: cols,
        actionFor: (_) => _dup,
        collectionId: _useCategories ? null : _collection,
        useSourceCategories: _useCategories,
        extraFields: extra,
      );
      await notifier.create(
        kind: TrackerKind.dictImport,
        title: _sourceLabel,
        occurredAt: DateTime.now(),
        fields: {
          'method': _method.name,
          'provider': _provider?.id,
          'origin': _request?.origin,
          'found': _items.length + _failed.length,
          'imported': r.created,
          'replaced': r.replaced,
          'skipped': r.skipped + _items.where((i) => !i.selected).length,
          'failed': _failed.length,
          'failedTitles': _failed.isEmpty ? null : _failed.take(200).toList(),
          'status': _failed.isEmpty ? 'done' : 'partial',
          'termIds': r.ids,
        },
      );
      if (!mounted) return;
      PrismToast.show(context, message: tr(context, 'Imported ${r.created} · updated ${r.replaced} · skipped ${r.skipped}', 'Importados ${r.created} · actualizados ${r.replaced} · omitidos ${r.skipped}'), icon: PhosphorIcons.check());
      setState(() {
        _items.clear();
        _method = _Method.history;
      });
    } catch (e) {
      if (mounted) PrismToast.show(context, message: tr(context, 'Import failed: $e', 'Error al importar: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryFromHistory(TrackerRecord r) async {
    final origin = r.str('origin');
    if (origin == null) return;
    setState(() => _method = _Method.url);
    try {
      final (p, req) = await detectProvider(_http, origin);
      _provider = p;
      _request = req;
      _sourceLabel = '${p.name} · ${req.uri.host}';
      await _fetchTitles(r.strings('failedTitles'), p, req);
    } catch (e) {
      _err(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final terms = ref.watch(trackerKindProvider(TrackerKind.dictTerm)).value ?? const <TrackerRecord>[];
    final index = indexTerms(terms);
    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, 'Import into Dictionary', 'Importar al diccionario'), showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 32),
        children: [
          ClampedBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final (m, label) in [
                        (_Method.url, tr(context, 'From a link', 'Desde un enlace')),
                        (_Method.file, tr(context, 'From a file', 'Desde un archivo')),
                        (_Method.api, tr(context, 'API endpoint', 'Endpoint de API')),
                        (_Method.paste, tr(context, 'Paste text', 'Pegar texto')),
                        (_Method.history, tr(context, 'History', 'Historial')),
                      ])
                        Padding(padding: const EdgeInsets.only(right: 6), child: PrismChip(label: label, selected: _method == m, onTap: () => setState(() => _method = m))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_method == _Method.history) const _ImportHistory() else ...[
                  ..._methodInputs(context),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600))),
                  if (_busy && _total > 0) ...[
                    const SizedBox(height: 12),
                    Text(tr(context, 'Fetching $_done of $_total…', 'Obteniendo $_done de $_total…'), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _total == 0 ? null : _done / _total, minHeight: 6)),
                    Align(alignment: Alignment.centerLeft, child: PrismButton(label: tr(context, 'Cancel', 'Cancelar'), density: PrismControlDensity.compact, onPressed: () => setState(() => _cancel = true))),
                  ] else if (_busy)
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: PrismLoadingState())),
                  if (_failed.isNotEmpty && !_busy && _provider != null && _request != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text(tr(context, '${_failed.length} couldn’t be fetched.', 'No se pudieron obtener ${_failed.length}.'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error))),
                        PrismButton(label: tr(context, 'Retry failed', 'Reintentar fallidos'), density: PrismControlDensity.compact, onPressed: () => _fetchTitles([..._failed], _provider!, _request!)),
                      ],
                    ),
                  ],
                  if (_items.isNotEmpty) ..._preview(context, index),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _methodInputs(BuildContext context) {
    final theme = Theme.of(context);
    switch (_method) {
      case _Method.url:
        return [
          Text(
            tr(context, 'Paste an article, category or wiki link. Works with MediaWiki sites (Wikipedia, Fandom, Miraheze, Pluralpedia, LGBTQ wikis, self-hosted), Wikidot, DokuWiki and most public pages.', 'Pega un enlace a un artículo, categoría o wiki. Funciona con sitios MediaWiki (Wikipedia, Fandom, Miraheze, Pluralpedia, wikis LGBTQ, propios), Wikidot, DokuWiki y la mayoría de páginas públicas.'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: PrismTextField(controller: _url, hintText: 'https://…', keyboardType: TextInputType.url, onSubmitted: (_) => _detect())),
              const SizedBox(width: 8),
              PrismButton(label: tr(context, 'Go', 'Ir'), tone: PrismButtonTone.filled, onPressed: _busy ? () {} : _detect),
            ],
          ),
          if (_provider != null && _request != null) ...[
            const SizedBox(height: 10),
            PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, 'Detected: $_sourceLabel', 'Detectado: $_sourceLabel'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(switch (_request!.scope) {
                    WikiScope.article => tr(context, 'A single article', 'Un solo artículo'),
                    WikiScope.category => tr(context, 'Category “${_request!.category}”', 'Categoría «${_request!.category}»'),
                    WikiScope.wholeWiki => tr(context, 'The whole wiki', 'Toda la wiki'),
                  }, style: theme.textTheme.bodySmall),
                  Text(_provider!.usesApi ? tr(context, 'Read through the site’s official API.', 'Se lee mediante la API oficial del sitio.') : tr(context, 'Read from public pages (robots.txt respected).', 'Se lee de páginas públicas (respetando robots.txt).'), style: theme.textTheme.bodySmall),
                  if (_request!.scope != WikiScope.article) ...[
                    const SizedBox(height: 8),
                    if ((_request!.scope == WikiScope.category && _provider!.canListCategory) || (_request!.scope == WikiScope.wholeWiki && _provider!.canListAll)) ...[
                      Wrap(spacing: 6, children: [for (final n in const [50, 200, 500, 2000]) PrismChip(label: tr(context, 'Up to $n', 'Hasta $n'), selected: _limit == n, onTap: () => setState(() => _limit = n))]),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          PrismButton(label: tr(context, 'Find articles', 'Buscar artículos'), icon: AppIcons.search, onPressed: _busy ? () {} : _listAll),
                          if (_titles.isNotEmpty) PrismButton(label: tr(context, 'Fetch ${_titles.length} articles', 'Obtener ${_titles.length} artículos'), tone: PrismButtonTone.filled, onPressed: _busy ? () {} : () => _fetchTitles(_titles, _provider!, _request!)),
                        ],
                      ),
                      if (_titles.isNotEmpty) Text(tr(context, '${_titles.length} articles found', 'Se encontraron ${_titles.length} artículos'), style: theme.textTheme.bodySmall),
                    ] else
                      Text(tr(context, 'This platform can’t list pages for import. Add article links below instead.', 'Esta plataforma no puede listar páginas. Añade enlaces a artículos abajo.'), style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          PrismTextField(controller: _more, labelText: tr(context, 'More article links (one per line)', 'Más enlaces (uno por línea)'), minLines: 2, maxLines: 6),
          Align(alignment: Alignment.centerLeft, child: PrismButton(label: tr(context, 'Fetch these', 'Obtener estos'), density: PrismControlDensity.compact, onPressed: _busy ? () {} : _fetchMoreUrls)),
        ];
      case _Method.file:
        return [
          Text(tr(context, 'MediaWiki XML dumps (Special:Export), wikitext, HTML, JSON, CSV/TSV, Markdown, plain text, or a ZIP of any of these.', 'Volcados XML de MediaWiki (Special:Export), wikitext, HTML, JSON, CSV/TSV, Markdown, texto, o un ZIP con cualquiera de ellos.'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: PrismButton(label: tr(context, 'Choose a file', 'Elegir archivo'), icon: PhosphorIcons.fileArrowUp(), tone: PrismButtonTone.filled, onPressed: _pickFile)),
        ];
      case _Method.api:
        return [
          Text(tr(context, 'A JSON endpoint that returns terms (a list, or an object of term → definition), or a MediaWiki api.php address.', 'Un endpoint JSON que devuelva términos (una lista, o un objeto término → definición), o una dirección api.php de MediaWiki.'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: PrismTextField(controller: _api, hintText: 'https://…/terms.json', keyboardType: TextInputType.url)),
              const SizedBox(width: 8),
              PrismButton(label: tr(context, 'Load', 'Cargar'), tone: PrismButtonTone.filled, onPressed: _busy ? () {} : _fromApi),
            ],
          ),
        ];
      case _Method.paste:
        return [
          PrismTextField(controller: _paste, hintText: tr(context, 'Paste wikitext, Markdown, CSV, “Term: definition” lines or an XML export', 'Pega wikitext, Markdown, CSV, líneas «Término: definición» o un XML'), minLines: 6, maxLines: 16),
          Align(alignment: Alignment.centerLeft, child: PrismButton(label: tr(context, 'Read text', 'Leer texto'), tone: PrismButtonTone.filled, onPressed: _fromPaste)),
        ];
      case _Method.history:
        return const [];
    }
  }

  List<Widget> _preview(BuildContext context, Map<String, TrackerRecord> index) {
    final theme = Theme.of(context);
    final cols = ref.watch(trackerKindProvider(TrackerKind.dictCollection)).value ?? const <TrackerRecord>[];
    final selected = _items.where((i) => i.selected && i.a.ok).length;
    final dups = _items.where((i) => findDuplicateTerm(i.a.toCandidate(0), index) != null).length;
    return [
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: Text(tr(context, 'Preview · ${_items.length} articles · $dups already in your dictionary', 'Vista previa · ${_items.length} artículos · $dups ya en tu diccionario'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          PrismButton(label: tr(context, 'Clear', 'Vaciar'), density: PrismControlDensity.compact, onPressed: () => setState(() {
            _items.clear();
            _failed.clear();
          })),
        ],
      ),
      const SizedBox(height: 6),
      for (final (i, it) in _items.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
            onTap: () => _edit(it),
            child: Row(
              children: [
                Checkbox(value: it.selected && it.a.ok, onChanged: it.a.ok ? (v) => setState(() => it.selected = v ?? false) : null),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.a.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text(it.a.ok ? it.a.summary : tr(context, 'Couldn’t read this one', 'No se pudo leer'), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (it.a.source != null) Text(it.a.source!, style: theme.textTheme.labelSmall),
                          if (findDuplicateTerm(it.a.toCandidate(i), index) != null) Text(tr(context, 'Duplicate', 'Duplicado'), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w700)),
                          if (it.a.categories.isNotEmpty) Text(it.a.categories.take(2).join(', '), style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(PhosphorIcons.caretRight(), size: 14),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
      PrismSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrismSwitchRow(title: tr(context, 'File under the source’s categories', 'Archivar según las categorías de origen'), value: _useCategories, onChanged: (v) => setState(() => _useCategories = v)),
            if (!_useCategories && cols.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PrismChip(label: tr(context, 'No collection', 'Sin colección'), selected: _collection == null, onTap: () => setState(() => _collection = null)),
                  for (final c in cols) PrismChip(label: c.title, selected: _collection == c.id, onTap: () => setState(() => _collection = c.id)),
                ],
              ),
            const SizedBox(height: 8),
            TrackerLabel(tr(context, 'When a term already exists', 'Si el término ya existe')),
            PrismSegmentedControl<TermDuplicateAction>(
              segments: [
                PrismSegment(value: TermDuplicateAction.skip, label: tr(context, 'Skip', 'Omitir')),
                PrismSegment(value: TermDuplicateAction.replace, label: tr(context, 'Update', 'Actualizar')),
                PrismSegment(value: TermDuplicateAction.keepBoth, label: tr(context, 'Keep both', 'Ambos')),
              ],
              selected: _dup,
              onChanged: (v) => setState(() => _dup = v),
            ),
            PrismSwitchRow(title: tr(context, 'Keep the full article text too', 'Guardar también el texto completo'), value: _keepFullText, onChanged: (v) => setState(() => _keepFullText = v)),
            Text(tr(context, 'The original link and source are always kept for attribution. Check each site’s licence before sharing imported text.', 'Siempre se guardan el enlace original y la fuente para la atribución. Revisa la licencia de cada sitio antes de compartir el texto.'), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: PrismButton(label: tr(context, 'Import $selected', 'Importar $selected'), icon: PhosphorIcons.downloadSimple(), tone: PrismButtonTone.filled, isLoading: _busy, onPressed: _busy || selected == 0 ? () {} : _import),
      ),
    ];
  }

  Future<void> _edit(_Item it) async {
    final title = TextEditingController(text: it.a.title);
    final desc = TextEditingController(text: it.a.summary);
    final df = DateFormat.yMMMd(context.dateLocale);
    await PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(ctx, 'Edit before importing', 'Editar antes de importar'), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          PrismTextField(controller: title, labelText: tr(ctx, 'Term', 'Término')),
          const SizedBox(height: 10),
          PrismTextField(controller: desc, labelText: tr(ctx, 'Definition', 'Definición'), minLines: 4, maxLines: 14),
          const SizedBox(height: 12),
          if (it.a.url != null) SelectableText('${tr(ctx, 'Source', 'Fuente')}: ${it.a.url}'),
          if (it.a.updated != null) Text('${tr(ctx, 'Last updated', 'Última actualización')}: ${df.format(it.a.updated!)}'),
          if (it.a.license != null) Text(it.a.license!),
          if (it.a.categories.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${tr(ctx, 'Categories', 'Categorías')}: ${it.a.categories.join(', ')}')),
          if (it.a.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(height: 90, child: ListView(scrollDirection: Axis.horizontal, children: [for (final u in it.a.images.take(6)) Padding(padding: const EdgeInsets.only(right: 6), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(u, height: 90, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())))])),
          ],
          if (it.a.references.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(tr(ctx, 'References', 'Referencias'), style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final r in it.a.references.take(10)) Text('• $r', maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          Text(tr(ctx, 'Full text', 'Texto completo'), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(it.a.content.length > 4000 ? '${it.a.content.substring(0, 4000)}…' : it.a.content),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: PrismButton(
              label: ctx.l10n.save,
              tone: PrismButtonTone.filled,
              onPressed: () {
                setState(() {
                  it.a.title = title.text.trim();
                  it.a.description = desc.text.trim();
                });
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportHistory extends ConsumerWidget {
  const _ImportHistory();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = ref.watch(trackerKindProvider(TrackerKind.dictImport)).value ?? const <TrackerRecord>[];
    final df = DateFormat.yMMMd(context.dateLocale).add_jm();
    if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Text(tr(context, 'No imports yet.', 'Aún no hay importaciones.'), textAlign: TextAlign.center));
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title.isEmpty ? tr(context, 'Import', 'Importación') : r.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(df.format(r.occurredAt ?? r.createdAt), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    tr(context, 'Imported ${r.integer('imported') ?? 0} · updated ${r.integer('replaced') ?? 0} · skipped ${r.integer('skipped') ?? 0} · failed ${r.integer('failed') ?? 0}${r.flag('removed') ? ' · removed' : ''}', 'Importados ${r.integer('imported') ?? 0} · actualizados ${r.integer('replaced') ?? 0} · omitidos ${r.integer('skipped') ?? 0} · fallidos ${r.integer('failed') ?? 0}${r.flag('removed') ? ' · quitados' : ''}'),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (r.strings('failedTitles').isNotEmpty) Text(tr(context, 'Failed: ${r.strings('failedTitles').take(5).join(', ')}${r.strings('failedTitles').length > 5 ? '…' : ''}', 'Fallidos: ${r.strings('failedTitles').take(5).join(', ')}${r.strings('failedTitles').length > 5 ? '…' : ''}'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (r.strings('failedTitles').isNotEmpty && r.str('origin') != null)
                        PrismButton(
                          label: tr(context, 'Retry failed', 'Reintentar fallidos'),
                          density: PrismControlDensity.compact,
                          onPressed: () {
                            final state = context.findAncestorStateOfType<_UniversalImportScreenState>();
                            state?._retryFromHistory(r);
                          },
                        ),
                      if (r.strings('termIds').isNotEmpty && !r.flag('removed'))
                        PrismButton(
                          label: tr(context, 'Remove imported entries', 'Quitar lo importado'),
                          tone: PrismButtonTone.destructive,
                          density: PrismControlDensity.compact,
                          onPressed: () async {
                            final ok = await PrismDialog.confirm(
                              context: context,
                              title: tr(context, 'Remove ${r.strings('termIds').length} imported terms?', '¿Quitar ${r.strings('termIds').length} términos importados?'),
                              message: tr(context, 'Terms you edited after importing are removed too. Other terms stay.', 'También se quitan los que editaste después. Los demás términos se quedan.'),
                              destructive: true,
                              confirmLabel: tr(context, 'Remove', 'Quitar'),
                              cancelLabel: context.l10n.cancel,
                            );
                            if (ok != true) return;
                            final n = ref.read(trackerNotifierProvider.notifier);
                            for (final id in r.strings('termIds')) {
                              await n.delete(id);
                            }
                            await n.save(r.withFields({'removed': true}));
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
