import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/dictionary/importer/import_job.dart';
import 'package:prism_plurality/features/dictionary/importer/wiki_providers.dart';
import 'package:prism_plurality/features/dictionary/utils/dictionary_import.dart';
import 'package:prism_plurality/features/dictionary/views/dictionary_import_flow.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_expandable_section.dart';

Future<void> openUniversalImport(BuildContext context) => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const UniversalImportScreen()));

enum _Method { url, file, api, paste, history }

String importStatusText(BuildContext c, ImportJob j) => switch (j.status) {
  ImportJobStatus.listing => tr(c, 'Finding articles…', 'Buscando artículos…'),
  ImportJobStatus.fetching => tr(c, 'Fetching ${j.done} of ${j.total}…', 'Obteniendo ${j.done} de ${j.total}…'),
  ImportJobStatus.paused => tr(c, 'Paused at ${j.done} of ${j.total}', 'En pausa en ${j.done} de ${j.total}'),
  ImportJobStatus.ready => tr(c, '${j.items.length} ready to review', '${j.items.length} listos para revisar'),
  ImportJobStatus.importing => tr(c, 'Adding to your dictionary…', 'Añadiendo a tu diccionario…'),
  ImportJobStatus.done => tr(c, 'Added ${j.result?['created'] ?? 0} · updated ${j.result?['replaced'] ?? 0} · skipped ${j.result?['skipped'] ?? 0}', 'Añadidos ${j.result?['created'] ?? 0} · actualizados ${j.result?['replaced'] ?? 0} · omitidos ${j.result?['skipped'] ?? 0}'),
  ImportJobStatus.error => tr(c, 'Stopped at ${j.done} of ${j.total}', 'Detenido en ${j.done} de ${j.total}'),
  ImportJobStatus.idle => '',
};

/// Shows a running, paused or finished wiki import (on the Dictionary
/// screen), so it's clear the import is still going. Tap to open it.
class ImportJobBanner extends ConsumerStatefulWidget {
  const ImportJobBanner({super.key});
  @override
  ConsumerState<ImportJobBanner> createState() => _ImportJobBannerState();
}

class _ImportJobBannerState extends ConsumerState<ImportJobBanner> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(importJobProvider.notifier).ready());
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(importJobProvider);
    final job = ref.read(importJobProvider.notifier).job;
    if (!job.hasWork || job.status == ImportJobStatus.idle) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final running = isRunningStatus(job.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PrismSurface(
        onTap: () => openUniversalImport(context),
        semanticLabel: '${job.sourceLabel}. ${importStatusText(context, job)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(running ? PhosphorIcons.cloudArrowDown() : (job.status == ImportJobStatus.done ? PhosphorIcons.checkCircle() : PhosphorIcons.pauseCircle()), size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('${importStatusText(context, job)} · ${job.sourceLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                Icon(PhosphorIcons.caretRight(), size: 14),
              ],
            ),
            if (job.status == ImportJobStatus.fetching || job.status == ImportJobStatus.listing) ...[
              const SizedBox(height: 6),
              ClipRRect(borderRadius: prismCorners(context, 4), child: LinearProgressIndicator(value: job.total == 0 || job.status == ImportJobStatus.listing ? null : job.done / job.total, minHeight: 4)),
            ],
          ],
        ),
      ),
    );
  }
}

class UniversalImportScreen extends ConsumerStatefulWidget {
  const UniversalImportScreen({super.key});
  @override
  ConsumerState<UniversalImportScreen> createState() => _UniversalImportScreenState();
}

class _UniversalImportScreenState extends ConsumerState<UniversalImportScreen> {
  _Method _method = _Method.url;
  final _url = TextEditingController();
  final _more = TextEditingController();
  final _paste = TextEditingController();
  final _api = TextEditingController();
  final _scroll = ScrollController();
  String? _localError;
  bool _localBusy = false;
  bool _showJump = false;

  ImportJobNotifier get _n => ref.read(importJobProvider.notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_n.ready().then((_) {
      if (mounted && _url.text.isEmpty) _url.text = _n.job.input ?? '';
    }));
  }

  void _onScroll() {
    final show = _scroll.hasClients && _scroll.position.maxScrollExtent > 800;
    if (show != _showJump) setState(() => _showJump = show);
  }

  @override
  void dispose() {
    for (final c in [_url, _more, _paste, _api]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  String? _errText(ImportJob j) {
    if (_localError != null) return _localError;
    if (j.errorCode == null) return null;
    if (j.errorCode == 'import_failed') return tr(context, 'Adding to the dictionary failed. Try again.', 'No se pudo añadir al diccionario. Vuelve a intentarlo.');
    final t = wikiErrorText(WikiImportError(j.errorCode!));
    return tr(context, t.$1, t.$2);
  }

  Future<void> _pickFile() async {
    setState(() => _localError = null);
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xml', 'wiki', 'wikitext', 'mediawiki', 'html', 'htm', 'json', 'csv', 'tsv', 'txt', 'md', 'markdown', 'zip'], withData: true);
    final f = res?.files.firstOrNull;
    if (f == null || f.bytes == null) return;
    try {
      _n.addArticles(parseImportFile(f.name, f.bytes!), label: f.name);
    } catch (e) {
      if (mounted) setState(() => _localError = tr(context, wikiErrorText(e).$1, wikiErrorText(e).$2));
    }
  }

  Future<void> _fromApi() async {
    setState(() {
      _localBusy = true;
      _localError = null;
    });
    try {
      final uri = Uri.tryParse(_api.text.trim());
      if (uri == null || !uri.hasScheme) throw const WikiImportError('not_a_url');
      if (uri.path.endsWith('api.php')) {
        _url.text = uri.toString();
        setState(() => _method = _Method.url);
        await _n.detect(uri.toString());
        return;
      }
      final res = await ref.read(wikiHttpProvider).get(uri, json: true);
      _n.addArticles(parseImportFile('api.json', res.bodyBytes), label: uri.host);
    } catch (e) {
      if (mounted) setState(() => _localError = tr(context, wikiErrorText(e).$1, wikiErrorText(e).$2));
    } finally {
      if (mounted) setState(() => _localBusy = false);
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
    _n.addArticles(list, label: tr(context, 'Pasted text', 'Texto pegado'));
  }

  Future<void> _import() async {
    try {
      final r = await _n.importNow(method: _method.name);
      if (r == null || !mounted) return;
      PrismToast.show(context, message: tr(context, 'Imported ${r.created} · updated ${r.replaced} · skipped ${r.skipped}', 'Importados ${r.created} · actualizados ${r.replaced} · omitidos ${r.skipped}'), icon: PhosphorIcons.check());
    } catch (e) {
      if (mounted) PrismToast.show(context, message: tr(context, 'Import failed: $e', 'Error al importar: $e'));
    }
  }

  Future<void> _retryFromHistory(TrackerRecord r) async {
    final origin = r.str('origin');
    if (origin == null) return;
    setState(() => _method = _Method.url);
    await _n.fetchTitlesFrom(origin, r.strings('failedTitles'));
  }

  void _jump({required bool bottom}) {
    if (!_scroll.hasClients) return;
    final target = bottom ? _scroll.position.maxScrollExtent : 0.0;
    // Jump (not animate) for long lists: animating through thousands of rows
    // is what makes slower phones stutter.
    if ((_scroll.offset - target).abs() > 6000) {
      _scroll.jumpTo(target);
    } else {
      unawaited(_scroll.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(importJobProvider);
    final job = _n.job;
    final theme = Theme.of(context);
    final terms = ref.watch(trackerKindProvider(TrackerKind.dictTerm)).value ?? const <TrackerRecord>[];
    final index = indexTerms(terms);
    final items = job.items;
    final running = isRunningStatus(job.status);
    final selected = items.where((i) => i.selected && i.a.ok).length;
    final showReview = _method != _Method.history && items.isNotEmpty;
    final err = _errText(job);

    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, 'Import into Dictionary', 'Importar al diccionario'), showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: ClampedBody(
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
                        if (_method == _Method.history)
                          const _ImportHistory()
                        else ...[
                          if (job.hasWork) _JobCard(job: job, onRetry: _n.retryFailed, onResume: _n.resume, onPause: _n.pause, onDiscard: _n.discard),
                          ..._methodInputs(context, job, running),
                          if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600))),
                          if (_localBusy) const Padding(padding: EdgeInsets.all(16), child: Center(child: PrismLoadingState())),
                          const SizedBox(height: 12),
                          _OptionsCard(job: job),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (showReview) ...[
                // The Import button stays at the top while you scroll.
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ReviewBar(
                    height: 64,
                    child: ColoredBox(
                      color: theme.scaffoldBackgroundColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ClampedBody(
                          child: Row(
                            children: [
                              Expanded(child: Text(tr(context, '$selected of ${items.length} selected', '$selected de ${items.length} seleccionados'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                              PrismPopupMenu<String>(
                                icon: AppIcons.moreVert,
                                tooltip: tr(context, 'Selection', 'Selección'),
                                items: [
                                  PrismMenuItem(value: 'all', label: tr(context, 'Select all', 'Seleccionar todo'), icon: PhosphorIcons.checkSquare()),
                                  PrismMenuItem(value: 'none', label: tr(context, 'Select none', 'Ninguno'), icon: PhosphorIcons.square()),
                                  PrismMenuItem(value: 'clear', label: tr(context, 'Clear list', 'Vaciar lista'), icon: PhosphorIcons.trash(), destructive: true),
                                ],
                                onSelected: (v) => switch (v) {
                                  'all' => _n.selectAll(true),
                                  'none' => _n.selectAll(false),
                                  _ => _n.discard(),
                                },
                              ),
                              const SizedBox(width: 6),
                              PrismButton(
                                label: tr(context, 'Import $selected', 'Importar $selected'),
                                icon: PhosphorIcons.downloadSimple(),
                                tone: PrismButtonTone.filled,
                                isLoading: job.status == ImportJobStatus.importing,
                                enabled: !running && selected > 0,
                                onPressed: _import,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, NavBarInset.of(context) + 96),
                  // Fixed-height rows built lazily: smooth even with thousands of terms.
                  sliver: SliverFixedExtentList(
                    itemExtent: 76,
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _ItemRow(item: items[i], duplicate: findDuplicateTerm(items[i].a.toCandidate(i), index) != null, onEdit: () => _edit(items[i])),
                      childCount: items.length,
                      addAutomaticKeepAlives: false,
                    ),
                  ),
                ),
              ] else
                SliverToBoxAdapter(child: SizedBox(height: NavBarInset.of(context) + 32)),
            ],
          ),
          if (_showJump && showReview)
            Positioned(
              right: 16,
              bottom: NavBarInset.of(context) + 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundButton(icon: PhosphorIcons.arrowLineUp(), label: tr(context, 'Jump to top', 'Ir arriba'), onTap: () => _jump(bottom: false)),
                  const SizedBox(height: 8),
                  _RoundButton(icon: PhosphorIcons.arrowLineDown(), label: tr(context, 'Jump to bottom', 'Ir al final'), onTap: () => _jump(bottom: true)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _methodInputs(BuildContext context, ImportJob job, bool running) {
    final theme = Theme.of(context);
    final p = _n.provider, r = _n.request;
    switch (_method) {
      case _Method.url:
        final canList = p != null && r != null && ((r.scope == WikiScope.category && p.canListCategory) || (r.scope == WikiScope.wholeWiki && p.canListAll));
        return [
          Text(
            tr(context, 'Paste an article, category or wiki link. Works with MediaWiki sites (Wikipedia, Fandom, Miraheze, Pluralpedia, LGBTQ wikis, self-hosted), Wikidot, DokuWiki and most public pages.', 'Pega un enlace a un artículo, categoría o wiki. Funciona con sitios MediaWiki (Wikipedia, Fandom, Miraheze, Pluralpedia, wikis LGBTQ, propios), Wikidot, DokuWiki y la mayoría de páginas públicas.'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: PrismTextField(controller: _url, hintText: 'https://…', keyboardType: TextInputType.url, enabled: !running, onSubmitted: (_) => _n.detect(_url.text))),
              const SizedBox(width: 8),
              PrismButton(label: tr(context, 'Go', 'Ir'), tone: PrismButtonTone.filled, enabled: !running, onPressed: () => _n.detect(_url.text)),
            ],
          ),
          if (p != null && r != null) ...[
            const SizedBox(height: 10),
            PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, 'Detected: ${job.sourceLabel}', 'Detectado: ${job.sourceLabel}'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(switch (r.scope) {
                    WikiScope.article => tr(context, 'A single article', 'Un solo artículo'),
                    WikiScope.category => tr(context, 'Category “${r.category}”', 'Categoría «${r.category}»'),
                    WikiScope.wholeWiki => tr(context, 'The whole wiki', 'Toda la wiki'),
                  }, style: theme.textTheme.bodySmall),
                  Text(p.usesApi ? tr(context, 'Read through the site’s official API.', 'Se lee mediante la API oficial del sitio.') : tr(context, 'Read from public pages (robots.txt respected).', 'Se lee de páginas públicas (respetando robots.txt).'), style: theme.textTheme.bodySmall),
                  if (r.scope != WikiScope.article) ...[
                    const SizedBox(height: 8),
                    if (canList) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final n in const [50, 200, 500, 2000]) PrismChip(label: tr(context, 'Up to $n', 'Hasta $n'), selected: job.options.limit == n, onTap: () => _n.setOptions((o) => o.limit = n)),
                          PrismChip(label: tr(context, 'All', 'Todos'), selected: job.options.limit == wikiNoLimit, onTap: () => _n.setOptions((o) => o.limit = wikiNoLimit)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      PrismButton(
                        label: job.options.limit == wikiNoLimit ? tr(context, 'Import all articles', 'Importar todos los artículos') : tr(context, 'Import up to ${job.options.limit} articles', 'Importar hasta ${job.options.limit} artículos'),
                        icon: PhosphorIcons.downloadSimple(),
                        tone: PrismButtonTone.filled,
                        enabled: !running,
                        onPressed: _n.listAndFetch,
                      ),
                    ] else
                      Text(tr(context, 'This platform can’t list pages for import. Add article links below instead.', 'Esta plataforma no puede listar páginas. Añade enlaces a artículos abajo.'), style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          PrismTextField(controller: _more, labelText: tr(context, 'More article links (one per line)', 'Más enlaces (uno por línea)'), minLines: 2, maxLines: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: PrismButton(
              label: tr(context, 'Fetch these', 'Obtener estos'),
              density: PrismControlDensity.compact,
              enabled: !running,
              onPressed: () {
                final urls = [for (final l in _more.text.split(RegExp(r'[\n\s]+'))) if (l.trim().startsWith('http')) l.trim()];
                _more.clear();
                unawaited(_n.fetchLinks(urls));
              },
            ),
          ),
        ];
      case _Method.file:
        return [
          Text(tr(context, 'MediaWiki XML dumps (Special:Export), wikitext, HTML, JSON, CSV/TSV, Markdown, plain text, or a ZIP of any of these.', 'Volcados XML de MediaWiki (Special:Export), wikitext, HTML, JSON, CSV/TSV, Markdown, texto, o un ZIP con cualquiera de ellos.'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: PrismButton(label: tr(context, 'Choose a file', 'Elegir archivo'), icon: PhosphorIcons.fileArrowUp(), tone: PrismButtonTone.filled, enabled: !running, onPressed: _pickFile)),
        ];
      case _Method.api:
        return [
          Text(tr(context, 'A JSON endpoint that returns terms (a list, or an object of term → definition), or a MediaWiki api.php address.', 'Un endpoint JSON que devuelva términos (una lista, o un objeto término → definición), o una dirección api.php de MediaWiki.'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: PrismTextField(controller: _api, hintText: 'https://…/terms.json', keyboardType: TextInputType.url)),
              const SizedBox(width: 8),
              PrismButton(label: tr(context, 'Load', 'Cargar'), tone: PrismButtonTone.filled, enabled: !running && !_localBusy, onPressed: _fromApi),
            ],
          ),
        ];
      case _Method.paste:
        return [
          PrismTextField(controller: _paste, hintText: tr(context, 'Paste wikitext, Markdown, CSV, “Term: definition” lines or an XML export', 'Pega wikitext, Markdown, CSV, líneas «Término: definición» o un XML'), minLines: 6, maxLines: 16),
          Align(alignment: Alignment.centerLeft, child: PrismButton(label: tr(context, 'Read text', 'Leer texto'), tone: PrismButtonTone.filled, enabled: !running, onPressed: _fromPaste)),
        ];
      case _Method.history:
        return const [];
    }
  }

  Future<void> _edit(ImportItem it) async {
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
          if (it.a.flags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(tr(ctx, 'Flags (${it.a.flags.length})', 'Banderas (${it.a.flags.length})'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in it.a.flags)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Tooltip(message: f.label, child: ClipRRect(borderRadius: prismCorners(context, 6), child: Image.network(f.url, height: 70, cacheHeight: 140, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox(width: 70)))),
                    ),
                ],
              ),
            ),
          ] else if (it.a.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(height: 90, child: ListView(scrollDirection: Axis.horizontal, children: [for (final u in it.a.images.take(6)) Padding(padding: const EdgeInsets.only(right: 6), child: ClipRRect(borderRadius: prismCorners(context, 8), child: Image.network(u, height: 90, cacheHeight: 180, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())))])),
          ],
          if (it.a.references.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(tr(ctx, 'References', 'Referencias'), style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final r in it.a.references.take(10)) Text('• $r', maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          Text(tr(ctx, 'Text', 'Texto'), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(it.a.content.length > 4000 ? '${it.a.content.substring(0, 4000)}…' : it.a.content),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: PrismButton(
              label: ctx.l10n.save,
              tone: PrismButtonTone.filled,
              onPressed: () {
                it.a.title = title.text.trim();
                it.a.description = desc.text.trim();
                _n.edited();
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress of the background job, with pause/resume.
class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onRetry, required this.onResume, required this.onPause, required this.onDiscard});
  final ImportJob job;
  final Future<void> Function() onRetry;
  final Future<void> Function() onResume;
  final VoidCallback onPause;
  final Future<void> Function() onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = job.status;
    final running = isRunningStatus(s);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PrismSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(running ? PhosphorIcons.cloudArrowDown() : (s == ImportJobStatus.done ? PhosphorIcons.checkCircle() : PhosphorIcons.pauseCircle()), color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(job.sourceLabel.isEmpty ? tr(context, 'Import', 'Importación') : job.sourceLabel, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 4),
            Text(importStatusText(context, job), style: theme.textTheme.bodySmall),
            if (s == ImportJobStatus.fetching || s == ImportJobStatus.listing || s == ImportJobStatus.paused || s == ImportJobStatus.error) ...[
              const SizedBox(height: 6),
              ClipRRect(borderRadius: prismCorners(context, 4), child: LinearProgressIndicator(value: job.total == 0 || s == ImportJobStatus.listing ? null : job.done / job.total, minHeight: 6)),
            ],
            if (running)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(tr(context, 'Keeps going in the background — you can leave this page or Prism. It picks up where it left off if Prism is closed.', 'Sigue en segundo plano: puedes salir de esta página o de Prism. Si Prism se cierra, continúa donde se quedó.'), style: theme.textTheme.bodySmall),
              ),
            if (job.failed.isNotEmpty && !running) Text(tr(context, '${job.failed.length} couldn’t be fetched.', 'No se pudieron obtener ${job.failed.length}.'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s == ImportJobStatus.fetching || s == ImportJobStatus.listing) PrismButton(label: tr(context, 'Pause', 'Pausar'), icon: PhosphorIcons.pause(), density: PrismControlDensity.compact, onPressed: onPause),
                if (s == ImportJobStatus.paused || s == ImportJobStatus.error) PrismButton(label: tr(context, 'Resume', 'Reanudar'), icon: PhosphorIcons.play(), tone: PrismButtonTone.filled, density: PrismControlDensity.compact, onPressed: onResume),
                if (job.failed.isNotEmpty && !running) PrismButton(label: tr(context, 'Retry failed', 'Reintentar fallidos'), density: PrismControlDensity.compact, onPressed: onRetry),
                if (!running) PrismButton(label: s == ImportJobStatus.done ? tr(context, 'Dismiss', 'Cerrar') : tr(context, 'Discard', 'Descartar'), density: PrismControlDensity.compact, onPressed: onDiscard),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionsCard extends ConsumerWidget {
  const _OptionsCard({required this.job});
  final ImportJob job;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final n = ref.read(importJobProvider.notifier);
    final o = job.options;
    final cols = ref.watch(trackerKindProvider(TrackerKind.dictCollection)).value ?? const <TrackerRecord>[];
    return PrismExpandableSection(
      title: Text(tr(context, 'Import settings', 'Ajustes de importación')),
      initiallyExpanded: false,
      children: [
          PrismSwitchRow(title: tr(context, 'Add to my dictionary automatically when done', 'Añadir al diccionario automáticamente al terminar'), subtitle: tr(context, 'Off: review the list first, then tap Import.', 'Desactivado: revisa la lista y luego pulsa Importar.'), value: o.autoImport, onChanged: (v) => n.setOptions((x) => x.autoImport = v)),
          PrismSwitchRow(title: tr(context, 'Download the full article text (slower)', 'Descargar el texto completo (más lento)'), subtitle: tr(context, 'Off: just the introduction, about 20× faster.', 'Desactivado: solo la introducción, unas 20 veces más rápido.'), value: o.fullText, onChanged: (v) => n.setOptions((x) => x.fullText = v)),
          PrismSwitchRow(title: tr(context, 'File under the source’s categories', 'Archivar según las categorías de origen'), value: o.useCategories, onChanged: (v) => n.setOptions((x) => x.useCategories = v)),
          if (!o.useCategories && cols.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PrismChip(label: tr(context, 'No collection', 'Sin colección'), selected: o.collection == null, onTap: () => n.setOptions((x) => x.collection = null)),
                for (final c in cols) PrismChip(label: c.title, selected: o.collection == c.id, onTap: () => n.setOptions((x) => x.collection = c.id)),
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
            selected: o.dup,
            onChanged: (v) => n.setOptions((x) => x.dup = v),
          ),
          const SizedBox(height: 6),
          Text(tr(context, 'Flags (including alternate flags) are imported when the wiki has them. The original link and source are always kept for attribution.', 'Las banderas (también las alternativas) se importan cuando la wiki las tiene. Siempre se guardan el enlace original y la fuente.'), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// One lightweight preview row (fixed height, no images) for smooth scrolling.
class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item, required this.duplicate, required this.onEdit});
  final ImportItem item;
  final bool duplicate;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final a = item.a;
    final meta = [
      if (duplicate) tr(context, 'Duplicate', 'Duplicado'),
      if (a.flags.isNotEmpty) tr(context, '${a.flags.length} flag${a.flags.length == 1 ? '' : 's'}', '${a.flags.length} bandera${a.flags.length == 1 ? '' : 's'}'),
      if (a.categories.isNotEmpty) a.categories.take(2).join(', '),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: prismCorners(context, 14),
        child: InkWell(
          borderRadius: prismCorners(context, 14),
          onTap: onEdit,
          child: Row(
            children: [
              Checkbox(value: item.selected && a.ok, onChanged: a.ok ? (v) => ref.read(importJobProvider.notifier).select(item, v ?? false) : null),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    Text(a.ok ? a.summary.replaceAll('\n', ' ') : tr(context, 'Couldn’t read this one', 'No se pudo leer'), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                    if (meta.isNotEmpty) Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: duplicate ? theme.colorScheme.error : null)),
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.only(right: 10), child: Icon(PhosphorIcons.caretRight(), size: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewBar extends SliverPersistentHeaderDelegate {
  _ReviewBar({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox(height: height, child: child);
  @override
  bool shouldRebuild(_ReviewBar old) => true;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: theme.colorScheme.primaryContainer,
        shape: prismCircleBorder(context),
        elevation: 3,
        child: InkWell(customBorder: prismCircleBorder(context), onTap: onTap, child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, color: theme.colorScheme.onPrimaryContainer))),
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
