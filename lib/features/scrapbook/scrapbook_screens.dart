import 'dart:typed_data';

import 'package:prism_plurality/shared/fonts/font_browser.dart';
import 'package:prism_plurality/shared/utils/prism_image_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/scrapbook/scrap_canvas.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

String scrapBookPath(String id) => '/scrapbook/book/$id';

void registerScrapOpeners(
  Map<String, void Function(BuildContext, String)> openers,
) {
  openers[TrackerKind.scrapBook] = (c, id) => c.push(scrapBookPath(id));
  openers[TrackerKind.scrapPage] = (c, id) {
    final container = ProviderScope.containerOf(c, listen: false);
    final page =
        (container.read(trackerKindProvider(TrackerKind.scrapPage)).value ??
                const <TrackerRecord>[])
            .where((p) => p.id == id)
            .firstOrNull;
    if (page?.parentId != null)
      c.push('${scrapBookPath(page!.parentId!)}?page=$id');
  };
}

final scrapBooksProvider = Provider<List<TrackerRecord>>(
  (ref) =>
      ref.watch(trackerKindProvider(TrackerKind.scrapBook)).value ?? const [],
);

final scrapPagesProvider = Provider.family<List<TrackerRecord>, String>((
  ref,
  bookId,
) {
  final pages = [
    for (final p
        in ref.watch(trackerKindProvider(TrackerKind.scrapPage)).value ??
            const <TrackerRecord>[])
      if (p.parentId == bookId) p,
  ];
  pages.sort(
    (a, b) => a.sortOrder != b.sortOrder
        ? a.sortOrder.compareTo(b.sortOrder)
        : a.createdAt.compareTo(b.createdAt),
  );
  return pages;
});

/// Whether [memberId] may add to or edit [book].
bool canContribute(TrackerRecord book, String? memberId) {
  final allowed = book.strings('contributors');
  return allowed.isEmpty || (memberId != null && allowed.contains(memberId));
}

class ScrapbooksScreen extends ConsumerWidget {
  const ScrapbooksScreen({super.key, this.showBackButton = false});
  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(scrapBooksProvider);
    final allPages =
        ref.watch(trackerKindProvider(TrackerKind.scrapPage)).value ??
        const <TrackerRecord>[];
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'System Scrapbook', 'Álbum del sistema'),
        showBackButton: showBackButton || Navigator.of(context).canPop(),
        actions: [
          FeatureDataAction(featureId: 'scrapbook'),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: tr(context, 'New scrapbook', 'Nuevo álbum'),
            onPressed: () => showBookEditor(context),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: books.isEmpty
          ? EmptyState(
              icon: Icon(PhosphorIcons.books()),
              title: tr(
                context,
                'Start your first scrapbook',
                'Empieza tu primer álbum',
              ),
              subtitle: tr(
                context,
                'Collect photos, drawings, notes, stickers and voice clips into shared memory books — for the whole system, one alter, a group or a special day.',
                'Reúne fotos, dibujos, notas, pegatinas y audios en álbumes compartidos: para todo el sistema, un alter, un grupo o un día especial.',
              ),
              actionLabel: tr(context, 'Create scrapbook', 'Crear álbum'),
              onAction: () => showBookEditor(context),
            )
          : LayoutBuilder(
              builder: (context, c) {
                final cols = (c.maxWidth / 190).floor().clamp(2, 6);
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    NavBarInset.of(context) + 16,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, i) {
                    final b = books[i];
                    final pages = allPages
                        .where((p) => p.parentId == b.id)
                        .length;
                    return _BookCover(
                      book: b,
                      pages: pages,
                      onTap: () => context.push(scrapBookPath(b.id)),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _BookCover extends ConsumerWidget {
  const _BookCover({
    required this.book,
    required this.pages,
    required this.onTap,
  });
  final TrackerRecord book;
  final int pages;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = themeById(book.str('theme'));
    final cover = book.str('cover');
    final t = Theme.of(context);
    return Semantics(
      button: true,
      label: book.title,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Color(book.integer('color') ?? theme.$4),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(4, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      width: 3,
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                      child: Column(
                        children: [
                          Expanded(
                            child: book.isPrivate
                                ? Center(
                                    child: Icon(
                                      AppIcons.lock,
                                      color: Colors.white70,
                                      size: 36,
                                    ),
                                  )
                                : cover == null
                                ? Center(
                                    child: Text(
                                      book.str('emoji') ?? '📖',
                                      style: const TextStyle(fontSize: 44),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(4),
                                    color: Colors.white,
                                    child: PrismMediaView(id: cover),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            book.title,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: scrapFont(
                              book.str('font') ?? 'serif',
                              t.textTheme.titleSmall!.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(context, '$pages pages', '$pages páginas'),
              textAlign: TextAlign.center,
              style: t.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

enum _BookView { pages, grid, timeline, gallery }

class ScrapBookScreen extends ConsumerStatefulWidget {
  const ScrapBookScreen({super.key, required this.bookId, this.initialPageId});
  final String bookId;
  final String? initialPageId;
  @override
  ConsumerState<ScrapBookScreen> createState() => _ScrapBookScreenState();
}

class _ScrapBookScreenState extends ConsumerState<ScrapBookScreen> {
  _BookView _view = _BookView.pages;
  PageController? _pc;
  int _index = 0;
  bool _revealed = false;

  @override
  void dispose() {
    _pc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = ref
        .watch(scrapBooksProvider)
        .where((b) => b.id == widget.bookId)
        .firstOrNull;
    if (book == null) {
      return PrismPageScaffold(
        topBar: PrismTopBar(
          title: tr(context, 'Scrapbook', 'Álbum'),
          showBackButton: true,
        ),
        body: Center(
          child: Text(
            tr(
              context,
              'This scrapbook was deleted.',
              'Este álbum fue eliminado.',
            ),
          ),
        ),
      );
    }
    final pages = ref.watch(scrapPagesProvider(widget.bookId));
    if (_pc == null) {
      final start = widget.initialPageId == null
          ? 0
          : pages
                .indexWhere((p) => p.id == widget.initialPageId)
                .clamp(0, 9999);
      _index = start;
      _pc = PageController(initialPage: start, viewportFraction: 0.9);
    }
    final theme = themeById(book.str('theme'));
    final fronter = currentFronterId(ref);
    final canEdit = canContribute(book, fronter);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: book.title,
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: PhosphorIcons.gearSix(),
            tooltip: tr(context, 'Scrapbook settings', 'Ajustes del álbum'),
            onPressed: () => showBookEditor(context, editing: book),
          ),
          if (canEdit)
            PrismTopBarAction(
              icon: AppIcons.add,
              tooltip: tr(context, 'Add page', 'Añadir página'),
              onPressed: () => _addPage(book, pages),
            ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: book.isPrivate && !_revealed
          ? Center(
              child: PrismButton(
                label: tr(
                  context,
                  'This scrapbook is private — tap to open',
                  'Este álbum es privado: toca para abrir',
                ),
                icon: AppIcons.lockOpen,
                onPressed: () => setState(() => _revealed = true),
              ),
            )
          : Column(
              children: [
                if (!canEdit)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      tr(
                        context,
                        'Only the chosen contributors can add to this scrapbook. You can still look through it.',
                        'Solo los colaboradores elegidos pueden añadir a este álbum. Puedes verlo igualmente.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: PrismSegmentedControl<_BookView>(
                    segments: [
                      PrismSegment(
                        value: _BookView.pages,
                        label: tr(context, 'Pages', 'Páginas'),
                      ),
                      PrismSegment(
                        value: _BookView.grid,
                        label: tr(context, 'Arrange', 'Ordenar'),
                      ),
                      PrismSegment(
                        value: _BookView.timeline,
                        label: tr(context, 'Timeline', 'Cronología'),
                      ),
                      PrismSegment(
                        value: _BookView.gallery,
                        label: tr(context, 'Gallery', 'Galería'),
                      ),
                    ],
                    selected: _view,
                    onChanged: (v) => setState(() => _view = v),
                  ),
                ),
                Expanded(
                  child: pages.isEmpty
                      ? EmptyState(
                          icon: Icon(PhosphorIcons.notebook()),
                          title: tr(
                            context,
                            'No pages yet',
                            'Aún no hay páginas',
                          ),
                          subtitle: tr(
                            context,
                            'Add a page and start decorating.',
                            'Añade una página y empieza a decorar.',
                          ),
                          actionLabel: canEdit
                              ? tr(context, 'Add page', 'Añadir página')
                              : null,
                          onAction: canEdit
                              ? () => _addPage(book, pages)
                              : null,
                        )
                      : SectionSwitcher(
                          id: _view,
                          child: switch (_view) {
                            _BookView.pages => _pagesView(
                              book,
                              pages,
                              theme,
                              canEdit,
                            ),
                            _BookView.grid => _grid(
                              book,
                              pages,
                              theme,
                              canEdit,
                            ),
                            _BookView.timeline => _timeline(book, pages, theme),
                            _BookView.gallery => _gallery(pages),
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Color _pageColor(
    TrackerRecord book,
    TrackerRecord page,
    (String, String, String, int, int, int) theme,
  ) => Color(page.integer('bg') ?? book.integer('pageColor') ?? theme.$5);

  Widget _pagesView(
    TrackerRecord book,
    List<TrackerRecord> pages,
    (String, String, String, int, int, int) theme,
    bool canEdit,
  ) {
    final page = pages[_index.clamp(0, pages.length - 1)];
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pc,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final p = pages[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Center(
                  child: GestureDetector(
                    onTap: canEdit
                        ? () => openPageEditor(context, book: book, page: p)
                        : null,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ScrapPageCanvas(
                        elements: elementsOf(p),
                        background: _pageColor(book, p, theme),
                        pattern:
                            p.str('pattern') ?? book.str('pattern') ?? 'paper',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, NavBarInset.of(context) + 8),
          child: Column(
            children: [
              Text(
                [
                  '${_index + 1} / ${pages.length}',
                  if (page.title.isNotEmpty) page.title,
                  if (page.occurredAt != null)
                    DateFormat.yMMMd(
                      context.dateLocale,
                    ).format(page.occurredAt!),
                  ?memberNameFor(ref, page.memberId),
                ].join(' · '),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (page.tags.isNotEmpty) TagWrap(tags: page.tags),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (canEdit)
                    PrismButton(
                      label: tr(context, 'Edit page', 'Editar página'),
                      icon: AppIcons.edit,
                      onPressed: () =>
                          openPageEditor(context, book: book, page: page),
                    ),
                  const SizedBox(width: 8),
                  PrismButton(
                    label: tr(context, 'Details', 'Detalles'),
                    icon: AppIcons.infoOutline,
                    onPressed: () => _pageDetails(book, page),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pageDetails(TrackerRecord book, TrackerRecord page) =>
      PrismSheet.showFullScreen(
        context: context,
        builder: (ctx, scroll) =>
            _PageDetailsSheet(book: book, pageId: page.id, scroll: scroll),
      );

  Widget _grid(
    TrackerRecord book,
    List<TrackerRecord> pages,
    (String, String, String, int, int, int) theme,
    bool canEdit,
  ) {
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 16),
      itemCount: pages.length,
      buildDefaultDragHandles: canEdit,
      onReorderItem: (from, to) async {
        final list = [...pages];
        final p = list.removeAt(from);
        list.insert(to, p);
        final t = ref.read(trackerNotifierProvider.notifier);
        for (var i = 0; i < list.length; i++) {
          if (list[i].sortOrder != i)
            await t.save(list[i].copyWith(sortOrder: i));
        }
      },
      itemBuilder: (context, i) {
        final p = pages[i];
        return PrismSurface(
          key: ValueKey(p.id),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          onTap: () => setState(() {
            _view = _BookView.pages;
            _index = i;
            _pc?.dispose();
            _pc = PageController(initialPage: i, viewportFraction: 0.9);
          }),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: IgnorePointer(
                  child: ScrapPageCanvas(
                    elements: elementsOf(p),
                    background: _pageColor(book, p, theme),
                    pattern: p.str('pattern') ?? 'paper',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title.isEmpty
                          ? tr(context, 'Page ${i + 1}', 'Página ${i + 1}')
                          : p.title,
                    ),
                    if (p.occurredAt != null)
                      Text(
                        DateFormat.yMMMd(
                          context.dateLocale,
                        ).format(p.occurredAt!),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              if (canEdit) ...[
                IconButton(
                  tooltip: tr(context, 'Duplicate page', 'Duplicar página'),
                  icon: Icon(AppIcons.copy),
                  onPressed: () => ref
                      .read(trackerNotifierProvider.notifier)
                      .create(
                        kind: TrackerKind.scrapPage,
                        parentId: book.id,
                        title: p.title,
                        occurredAt: p.occurredAt,
                        memberId: currentFronterId(ref),
                        tags: p.tags,
                        sortOrder: pages.length,
                        fields: {
                          ...p.fields,
                          'els': [
                            for (final e in elementsOf(p))
                              (e.copy()
                                    ..x = e.x
                                    ..y = e.y)
                                  .toJson(),
                          ],
                        },
                      ),
                ),
                IconButton(
                  tooltip: tr(context, 'Delete page', 'Eliminar página'),
                  icon: Icon(AppIcons.deleteOutline),
                  onPressed: () async {
                    final ok = await PrismDialog.confirm(
                      context: context,
                      title: tr(
                        context,
                        'Delete this page?',
                        '¿Eliminar esta página?',
                      ),
                      destructive: true,
                      confirmLabel: tr(context, 'Delete', 'Eliminar'),
                      cancelLabel: context.l10n.cancel,
                    );
                    if (ok)
                      await ref
                          .read(trackerNotifierProvider.notifier)
                          .delete(p.id);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _timeline(
    TrackerRecord book,
    List<TrackerRecord> pages,
    (String, String, String, int, int, int) theme,
  ) {
    final dated = [...pages]
      ..sort(
        (a, b) => (a.occurredAt ?? a.createdAt).compareTo(
          b.occurredAt ?? b.createdAt,
        ),
      );
    final t = Theme.of(context);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 16),
      itemCount: dated.length,
      itemBuilder: (context, i) {
        final p = dated[i];
        final d = p.occurredAt ?? p.createdAt;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Color(theme.$6),
                        borderRadius: prismRound(context),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: Color(theme.$6).withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMMd(context.dateLocale).format(d),
                        style: t.textTheme.labelLarge,
                      ),
                      if (p.title.isNotEmpty)
                        Text(p.title, style: t.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 160,
                        child: GestureDetector(
                          onTap: () => _pageDetails(book, p),
                          child: IgnorePointer(
                            child: ScrapPageCanvas(
                              elements: elementsOf(p),
                              background: _pageColor(book, p, theme),
                              pattern: p.str('pattern') ?? 'paper',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _gallery(List<TrackerRecord> pages) {
    final items = <(String, TrackerRecord)>[
      for (final p in pages)
        for (final e in elementsOf(p))
          if (e.media != null && !e.media!.startsWith('audio:')) (e.media!, p),
    ];
    if (items.isEmpty)
      return Center(
        child: Text(
          tr(
            context,
            'Photos and drawings you add will gather here.',
            'Las fotos y dibujos que añadas aparecerán aquí.',
          ),
        ),
      );
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, NavBarInset.of(context) + 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => setState(() {
          final idx = pages.indexOf(items[i].$2);
          _view = _BookView.pages;
          _index = idx;
          _pc?.dispose();
          _pc = PageController(initialPage: idx, viewportFraction: 0.9);
        }),
        child: ClipRRect(
          borderRadius: prismCorners(context, 8),
          child: PrismMediaView(id: items[i].$1),
        ),
      ),
    );
  }

  Future<void> _addPage(TrackerRecord book, List<TrackerRecord> pages) async {
    final layouts = [
      (
        'blank',
        tr(context, 'Blank page', 'Página en blanco'),
        PhosphorIcons.file(),
      ),
      (
        'journal',
        tr(context, 'Photo + writing', 'Foto + texto'),
        PhosphorIcons.article(),
      ),
      (
        'polaroids',
        tr(context, 'Polaroid spread', 'Polaroids'),
        PhosphorIcons.images(),
      ),
      (
        'collage2',
        tr(context, 'Two photos', 'Dos fotos'),
        PhosphorIcons.rows(),
      ),
      (
        'collage4',
        tr(context, 'Four-photo collage', 'Collage de cuatro'),
        PhosphorIcons.gridFour(),
      ),
      (
        'memory',
        tr(context, 'Memory page', 'Página de recuerdo'),
        PhosphorIcons.heart(),
      ),
    ];
    final layout = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Choose a layout', 'Elige un diseño'),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final (id, label, icon) in layouts)
            PrismListRow(
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.of(ctx).pop(id),
            ),
        ],
      ),
    );
    if (layout == null || !mounted) return;
    final els = layoutTemplate(layout);
    final fronter = currentFronterId(ref);
    for (final e in els) {
      e.by = fronter;
    }
    final page = await ref
        .read(trackerNotifierProvider.notifier)
        .create(
          kind: TrackerKind.scrapPage,
          parentId: book.id,
          memberId: fronter,
          occurredAt: DateTime.now(),
          sortOrder: pages.length,
          fields: {
            'els': [for (final e in els) e.toJson()],
          },
        );
    if (mounted) await openPageEditor(context, book: book, page: page);
  }
}

class _PageDetailsSheet extends ConsumerStatefulWidget {
  const _PageDetailsSheet({
    required this.book,
    required this.pageId,
    required this.scroll,
  });
  final TrackerRecord book;
  final String pageId;
  final ScrollController scroll;
  @override
  ConsumerState<_PageDetailsSheet> createState() => _PageDetailsSheetState();
}

class _PageDetailsSheetState extends ConsumerState<_PageDetailsSheet> {
  TrackerRecord? _page;
  late final _caption = TextEditingController();
  late final _tags = TextEditingController();
  DateTime? _date;
  final Set<String> _members = {};

  @override
  void dispose() {
    _caption.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref
        .watch(scrapPagesProvider(widget.book.id))
        .where((p) => p.id == widget.pageId)
        .firstOrNull;
    if (page == null) return const SizedBox.shrink();
    if (_page == null) {
      _page = page;
      _caption.text = page.title;
      _tags.text = page.tags.join(', ');
      _date = page.occurredAt;
      _members.addAll(page.strings('members'));
    }
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final preferDisplay = ref.watch(memberNamePreferDisplayProvider);
    final canEdit = canContribute(widget.book, currentFronterId(ref));
    final contributors = {
      for (final e in elementsOf(page)) ?e.by,
      ?page.memberId,
    };
    return TrackerEditorScaffold(
      title: tr(context, 'Page details', 'Detalles de la página'),
      canSave: canEdit,
      scrollController: widget.scroll,
      onSave: () async {
        await ref
            .read(trackerNotifierProvider.notifier)
            .save(
              page
                  .copyWith(
                    title: _caption.text,
                    occurredAt: _date,
                    tags: parseTagInput(_tags.text),
                  )
                  .withFields({'members': _members.toList()}),
            );
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        PrismTextField(
          controller: _caption,
          labelText: tr(context, 'Caption', 'Pie de foto'),
          enabled: canEdit,
        ),
        const SizedBox(height: 8),
        PrismButton(
          label: _date == null
              ? tr(context, 'Add a date', 'Añadir fecha')
              : DateFormat.yMMMMd(context.dateLocale).format(_date!),
          icon: AppIcons.calendarToday,
          onPressed: () async {
            if (!canEdit) return;
            final d = await showPrismDatePicker(
              context: context,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              initialDate: _date ?? DateTime.now(),
            );
            if (d != null) setState(() => _date = d);
          },
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _tags,
          labelText: tr(context, 'Tags', 'Etiquetas'),
          enabled: canEdit,
        ),
        const SizedBox(height: 10),
        TrackerLabel(
          tr(context, 'Alters in this memory', 'Alters en este recuerdo'),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in members)
              PrismChip(
                label: m.effectiveName(preferDisplayName: preferDisplay),
                selected: _members.contains(m.id),
                onTap: canEdit
                    ? () => setState(
                        () => _members.contains(m.id)
                            ? _members.remove(m.id)
                            : _members.add(m.id),
                      )
                    : () {},
              ),
          ],
        ),
        if (contributors.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '${tr(context, 'Contributed by', 'Aportado por')}: ${[for (final c in contributors) ?memberNameFor(ref, c)].join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        RelatedRecordsSection(self: RecordRef(RecordRef.rec, page.id)),
      ],
    );
  }
}

Future<void> openPageEditor(
  BuildContext context, {
  required TrackerRecord book,
  required TrackerRecord page,
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ScrapPageEditor(book: book, page: page),
  ),
);

class ScrapPageEditor extends ConsumerStatefulWidget {
  const ScrapPageEditor({super.key, required this.book, required this.page});
  final TrackerRecord book;
  final TrackerRecord page;
  @override
  ConsumerState<ScrapPageEditor> createState() => _ScrapPageEditorState();
}

class _ScrapPageEditorState extends ConsumerState<ScrapPageEditor> {
  late final List<ScrapElement> _els = elementsOf(widget.page);
  late int? _bg = widget.page.integer('bg');
  late String _pattern =
      widget.page.str('pattern') ?? widget.book.str('pattern') ?? 'paper';
  String? _sel;
  final List<List<Map<String, Object?>>> _undo = [];
  bool _dirty = false;

  ScrapElement? get _selected => _els.where((e) => e.id == _sel).firstOrNull;

  List<Map<String, Object?>> _snapshot() => [for (final e in _els) e.toJson()];

  void _changed() {
    _undo.add(_snapshot());
    if (_undo.length > 30) _undo.removeAt(0);
    setState(() => _dirty = true);
  }

  Future<void> _save() async {
    await ref
        .read(trackerNotifierProvider.notifier)
        .save(
          widget.page.withFields({
            'els': [for (final e in _els) e.toJson()],
            'bg': _bg,
            'pattern': _pattern,
          }),
        );
    _dirty = false;
  }

  int get _topZ => _els.fold(0, (a, e) => e.z > a ? e.z : a) + 1;

  void _add(ScrapElement e) {
    e
      ..z = _topZ
      ..by = currentFronterId(ref);
    setState(() {
      _els.add(e);
      _sel = e.id;
    });
    _changed();
  }

  Future<void> _addMedia(ScrapType type) async {
    String? id;
    if (type == ScrapType.photo)
      id = await PrismMedia.pickImage(ref, owner: currentFronterId(ref));
    if (type == ScrapType.video) {
      final res = await PrismMedia.pickVideoResult(ref);
      if (res.error != null && mounted) {
        PrismToast.error(
          context,
          message: switch (res.error) {
            'tooLarge' => tr(
              context,
              'That video is too large (200 MB max).',
              'Ese vídeo es demasiado grande (máx. 200 MB).',
            ),
            'format' => tr(
              context,
              'That video format isn\'t supported.',
              'Ese formato de vídeo no es compatible.',
            ),
            'unsupported' => tr(
              context,
              'Videos can\'t be stored on this device.',
              'No se pueden guardar vídeos en este dispositivo.',
            ),
            _ => tr(
              context,
              'Couldn\'t add that video.',
              'No se pudo añadir ese vídeo.',
            ),
          },
        );
      }
      id = res.id;
    }
    if (type == ScrapType.audio && mounted)
      id = await PrismMedia.recordAudio(context);
    if (id == null) return;
    // Fill an empty photo placeholder first.
    final empty = _els
        .where((e) => e.type == ScrapType.photo && e.media == null)
        .firstOrNull;
    if (empty != null && type == ScrapType.photo) {
      setState(() {
        empty.media = id;
        _sel = empty.id;
      });
      _changed();
      return;
    }
    _add(
      ScrapElement(
        type: type,
        media: id,
        x: 0.2,
        y: 0.25,
        w: type == ScrapType.audio ? 0.5 : 0.6,
        h: type == ScrapType.audio ? 0.08 : 0.4,
        frame: type == ScrapType.photo ? ScrapFrame.polaroid : ScrapFrame.none,
      ),
    );
  }

  /// Per-video playback options. They live on the element itself, so editing
  /// one video never changes another.
  Future<void> _videoOptions(ScrapElement e) => PrismSheet.show<void>(
    context: context,
    title: tr(context, 'Video options', 'Opciones de vídeo'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        void upd(VoidCallback f) {
          setState(f);
          set(() {});
          _changed();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrismSwitchRow(
              title: tr(ctx, 'Loop', 'Repetir'),
              value: e.opt('loop', false),
              onChanged: (v) => upd(() => e.setOpt('loop', v ? true : null)),
            ),
            PrismSwitchRow(
              title: tr(ctx, 'Autoplay when visible', 'Reproducir al verse'),
              subtitle: tr(
                ctx,
                'Plays only while this page is on screen.',
                'Solo se reproduce mientras la página está en pantalla.',
              ),
              value: e.opt('auto', false),
              onChanged: (v) => upd(() => e.setOpt('auto', v ? true : null)),
            ),
            const SizedBox(height: 8),
            Text(tr(ctx, 'Volume', 'Volumen')),
            Slider(
              value: e.opt('vol', 1.0).clamp(0.0, 1.0),
              onChanged: (v) => set(() => e.setOpt('vol', v)),
              onChangeEnd: (_) => upd(() {}),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                PrismButton(
                  icon: PhosphorIcons.image(),
                  label: tr(ctx, 'Custom thumbnail', 'Miniatura propia'),
                  tone: PrismButtonTone.outlined,
                  onPressed: () async {
                    final id = await PrismMedia.pickImage(ref);
                    if (id != null) upd(() => e.setOpt('thumb', id));
                  },
                ),
                if (e.opts['thumb'] != null)
                  PrismButton(
                    label: tr(ctx, 'Remove thumbnail', 'Quitar miniatura'),
                    tone: PrismButtonTone.outlined,
                    onPressed: () => upd(() => e.setOpt('thumb', null)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(tr(ctx, 'Opacity', 'Opacidad')),
            Slider(
              value: e.opacity.clamp(0.1, 1.0),
              min: 0.1,
              onChanged: (v) => set(() => e.opacity = v),
              onChangeEnd: (_) => upd(() {}),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _editText(ScrapElement e) async {
    final v = await promptText(
      context,
      tr(context, 'Text', 'Texto'),
      initial: e.text,
      maxLines: 6,
    );
    if (v == null) return;
    setState(() => e.text = v);
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeById(widget.book.str('theme'));
    final bg = Color(_bg ?? widget.book.integer('pageColor') ?? theme.$5);
    final s = _selected;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        await _save();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: LookBackdrop(
        builder: (lookBg) => Scaffold(
          backgroundColor:
              lookBg ?? Theme.of(context).colorScheme.surfaceContainerLowest,
          body: SafeArea(
            child: Column(
              children: [
                PrismSheetTopBar(
                  title: tr(context, 'Edit page', 'Editar página'),
                  leading: IconButton(
                    tooltip: tr(context, 'Undo', 'Deshacer'),
                    icon: Icon(PhosphorIcons.arrowCounterClockwise()),
                    onPressed: _undo.length < 2
                        ? null
                        : () {
                            _undo.removeLast();
                            setState(() {
                              _els
                                ..clear()
                                ..addAll([
                                  for (final m in _undo.last)
                                    ?ScrapElement.fromJson(m),
                                ]);
                              _sel = null;
                              _dirty = true;
                            });
                          },
                  ),
                  trailing: IconButton(
                    tooltip: context.l10n.save,
                    icon: Icon(AppIcons.check),
                    onPressed: () async {
                      await _save();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ScrapPageCanvas(
                        elements: _els,
                        background: bg,
                        pattern: _pattern,
                        selectedId: _sel,
                        onSelect: (id) => setState(() => _sel = id),
                        onChanged: _changed,
                        onEditElement: (e) {
                          if (e.type == ScrapType.text ||
                              e.type == ScrapType.note)
                            _editText(e);
                        },
                      ),
                    ),
                  ),
                ),
                if (s != null) _elementBar(s) else _addBar(bg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _undo.add(_snapshot());
  }

  Widget _addBar(Color bg) {
    final tools = [
      (
        PhosphorIcons.image(),
        tr(context, 'Photo / GIF', 'Foto / GIF'),
        () => _addMedia(ScrapType.photo),
      ),
      (
        PhosphorIcons.videoCamera(),
        tr(context, 'Video', 'Vídeo'),
        () => _addMedia(ScrapType.video),
      ),
      (
        PhosphorIcons.microphone(),
        tr(context, 'Audio', 'Audio'),
        () => _addMedia(ScrapType.audio),
      ),
      (
        PhosphorIcons.textT(),
        tr(context, 'Text', 'Texto'),
        () => _add(
          ScrapElement(
            type: ScrapType.text,
            text: '',
            x: 0.1,
            y: 0.1,
            w: 0.8,
            h: 0.2,
            font: 'hand',
          ),
        ),
      ),
      (
        PhosphorIcons.note(),
        tr(context, 'Note', 'Nota'),
        () => _add(
          ScrapElement(
            type: ScrapType.note,
            text: '',
            x: 0.25,
            y: 0.3,
            w: 0.5,
            h: 0.22,
            color: 0xFFFFF3A3,
            rot: 0.04,
          ),
        ),
      ),
      (
        PhosphorIcons.smiley(),
        tr(context, 'Sticker', 'Pegatina'),
        _pickSticker,
      ),
      (PhosphorIcons.pencilSimpleLine(), tr(context, 'Draw', 'Dibujar'), _draw),
      (
        PhosphorIcons.bandaids(),
        tr(context, 'Tape', 'Cinta'),
        () => _add(
          ScrapElement(
            type: ScrapType.tape,
            x: 0.3,
            y: 0.05,
            w: 0.4,
            h: 0.05,
            rot: -0.1,
            color: colorChoices[_els.length % colorChoices.length],
          ),
        ),
      ),
      (PhosphorIcons.heart(), tr(context, 'Shape', 'Forma'), _pickShape),
      (
        PhosphorIcons.paintBucket(),
        tr(context, 'Background', 'Fondo'),
        _background,
      ),
    ];
    return SizedBox(
      height: 78,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final (icon, label, onTap) in tools)
            InkWell(
              borderRadius: prismCorners(context, 12),
              onTap: onTap,
              child: SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _elementBar(ScrapElement e) {
    final actions = <(IconData, String, VoidCallback)>[
      if (e.type == ScrapType.text || e.type == ScrapType.note)
        (
          PhosphorIcons.pencilSimple(),
          tr(context, 'Edit text', 'Editar texto'),
          () => _editText(e),
        ),
      if (e.type == ScrapType.photo)
        (
          PhosphorIcons.image(),
          tr(context, 'Replace', 'Reemplazar'),
          () async {
            final id = await PrismMedia.pickImage(ref);
            if (id == null) return;
            setState(() => e.media = id);
            _changed();
          },
        ),
      if (e.type == ScrapType.video)
        (
          PhosphorIcons.sliders(),
          tr(context, 'Video', 'Vídeo'),
          () => _videoOptions(e),
        ),
      if (e.type == ScrapType.photo && e.media != null)
        (
          PhosphorIcons.crop(),
          tr(context, 'Crop', 'Recortar'),
          () async {
            final id = await PrismMedia.recropImage(ref, e.media!);
            if (id == null) return;
            setState(() => e.media = id);
            _changed();
          },
        ),
      if (e.type == ScrapType.photo ||
          e.type == ScrapType.drawing ||
          e.type == ScrapType.video)
        (
          PhosphorIcons.frameCorners(),
          tr(context, 'Frame', 'Marco'),
          () {
            setState(
              () => e.frame = ScrapFrame
                  .values[(e.frame.index + 1) % ScrapFrame.values.length],
            );
            _changed();
          },
        ),
      if (e.type == ScrapType.text || e.type == ScrapType.note)
        (
          PhosphorIcons.textAa(),
          tr(context, 'Font', 'Fuente'),
          () async {
            final pick = await showPrismFontBrowser(
              context,
              current: e.font,
              allowDefault: false,
            );
            if (pick?.key == null) return;
            setState(() => e.font = pick!.key);
            _changed();
          },
        ),
      if (e.type == ScrapType.text ||
          e.type == ScrapType.note ||
          e.type == ScrapType.tape ||
          e.type == ScrapType.shape)
        (
          PhosphorIcons.palette(),
          tr(context, 'Colour', 'Color'),
          () async {
            final c = await _pickColor(e.color);
            if (c == null) return;
            setState(() => e.color = c);
            _changed();
          },
        ),
      if (e.type == ScrapType.text)
        (
          PhosphorIcons.textT(),
          tr(context, 'Size', 'Tamaño'),
          () {
            setState(() => e.size = e.size >= 2.5 ? 0.8 : e.size + 0.35);
            _changed();
          },
        ),
      (
        PhosphorIcons.stackSimple(),
        tr(context, 'To front', 'Al frente'),
        () {
          setState(() => e.z = _topZ);
          _changed();
        },
      ),
      (
        PhosphorIcons.stack(),
        tr(context, 'To back', 'Al fondo'),
        () {
          setState(() => e.z = _els.fold(0, (a, x) => x.z < a ? x.z : a) - 1);
          _changed();
        },
      ),
      (
        AppIcons.copy,
        tr(context, 'Duplicate', 'Duplicar'),
        () => _add(e.copy()),
      ),
      (
        AppIcons.deleteOutline,
        tr(context, 'Delete', 'Eliminar'),
        () {
          setState(() {
            _els.remove(e);
            _sel = null;
          });
          _changed();
        },
      ),
      (
        AppIcons.close,
        tr(context, 'Done', 'Listo'),
        () => setState(() => _sel = null),
      ),
    ];
    return SizedBox(
      height: 78,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final (icon, label, onTap) in actions)
            InkWell(
              borderRadius: prismCorners(context, 12),
              onTap: onTap,
              child: SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<int?> _pickColor(int? current) => PrismSheet.show<int>(
    context: context,
    title: tr(context, 'Colour', 'Color'),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: ColorChoiceRow(
        value: current,
        colors: const [
          0xFF000000,
          0xFFFFFFFF,
          0xFFFFF3A3,
          0xFFFFD1DC,
          0xFFC9F2D9,
          0xFFCDE7FF,
          0xFFE8D9FF,
          ...colorChoices,
        ],
        onChanged: (c) => Navigator.of(ctx).pop(c),
      ),
    ),
  );

  Future<void> _pickSticker() async {
    final s = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Stickers', 'Pegatinas'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in scrapStickers)
              InkWell(
                onTap: () => Navigator.of(ctx).pop(e),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(e, style: const TextStyle(fontSize: 32)),
                ),
              ),
          ],
        ),
      ),
    );
    if (s != null)
      _add(
        ScrapElement(
          type: ScrapType.sticker,
          text: s,
          x: 0.4,
          y: 0.4,
          w: 0.18,
          h: 0.13,
        ),
      );
  }

  Future<void> _pickShape() async {
    final s = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Shapes', 'Formas'),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final (id, en, es) in const [
            ('heart', 'Heart', 'Corazón'),
            ('star', 'Star', 'Estrella'),
            ('circle', 'Circle', 'Círculo'),
            ('banner', 'Banner', 'Banderín'),
          ])
            PrismListRow(
              title: Text(tr(ctx, en, es)),
              onTap: () => Navigator.of(ctx).pop(id),
            ),
        ],
      ),
    );
    if (s != null)
      _add(
        ScrapElement(
          type: ScrapType.shape,
          text: s,
          x: 0.35,
          y: 0.35,
          w: s == 'banner' ? 0.6 : 0.25,
          h: s == 'banner' ? 0.08 : 0.18,
          color: 0xFFE74C3C,
        ),
      );
  }

  Future<void> _draw() async {
    final bytes = await DrawingPad.show(context);
    if (bytes == null) return;
    final id = await ref
        .read(socialMediaStoreProvider)
        .addImage(Uint8List.fromList(bytes), owner: currentFronterId(ref));
    if (id != null)
      _add(
        ScrapElement(
          type: ScrapType.drawing,
          media: id,
          x: 0.15,
          y: 0.2,
          w: 0.7,
          h: 0.5,
        ),
      );
  }

  Future<void> _background() async {
    await PrismSheet.show(
      context: context,
      title: tr(context, 'Page background', 'Fondo de página'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColorChoiceRow(
                value: _bg,
                colors: const [
                  0xFFFFF8EC,
                  0xFFFFFFFF,
                  0xFFFFF5FA,
                  0xFFF4F9EF,
                  0xFFEFF7FC,
                  0xFFE9D8B4,
                  0xFF2A2E57,
                  0xFF1E1E1E,
                  0xFFFFE0B2,
                  0xFFE1F5FE,
                ],
                onChanged: (c) {
                  setState(() => _bg = c);
                  set(() {});
                  _changed();
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (final p in scrapPatterns)
                    PrismChip(
                      label: p,
                      selected: _pattern == p,
                      onTap: () {
                        setState(() => _pattern = p);
                        set(() {});
                        _changed();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showBookEditor(BuildContext context, {TrackerRecord? editing}) =>
    PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) => _BookEditor(editing: editing, scroll: scroll),
    );

class _BookEditor extends ConsumerStatefulWidget {
  const _BookEditor({this.editing, required this.scroll});
  final TrackerRecord? editing;
  final ScrollController scroll;
  @override
  ConsumerState<_BookEditor> createState() => _BookEditorState();
}

class _BookEditorState extends ConsumerState<_BookEditor> {
  late final e = widget.editing;
  late final _name = TextEditingController(text: e?.title);
  late final _desc = TextEditingController(text: e?.body);
  late final _emoji = TextEditingController(text: e?.str('emoji') ?? '📖');
  late String _theme = e?.str('theme') ?? 'classic';
  late String? _cover = e?.str('cover');
  late String _font = e?.str('font') ?? 'serif';
  late String _pattern = e?.str('pattern') ?? 'paper';
  late int? _color = e?.integer('color');
  late bool _private = e?.isPrivate ?? false;
  late final Set<String> _contributors = {...?e?.strings('contributors')};
  late String _dedication = e?.str('for') ?? 'system';
  late String? _dedicationRef = e?.str('forRef');

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _emoji.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final preferDisplay = ref.watch(memberNamePreferDisplayProvider);
    final catalog = ref.watch(recordCatalogProvider);
    final dedicationOptions = [
      ('system', tr(context, 'Whole system', 'Todo el sistema')),
      ('alter', tr(context, 'An alter', 'Un alter')),
      ('group', tr(context, 'A group or subsystem', 'Un grupo o subsistema')),
      ('relationship', tr(context, 'A relationship', 'Una relación')),
      ('event', tr(context, 'An event', 'Un evento')),
      ('memory', tr(context, 'A memory or theme', 'Un recuerdo o tema')),
    ];
    final refChoices = switch (_dedication) {
      'alter' => [
        for (final i in catalog.values)
          if (i.module == 'member') i,
      ],
      'group' => [
        for (final i in catalog.values)
          if (i.module == 'subsystem') i,
      ],
      'relationship' => [
        for (final i in catalog.values)
          if (i.module == 'rel') i,
      ],
      'event' => [
        for (final i in catalog.values)
          if (i.module == 'event') i,
      ],
      _ => const <RecordInfo>[],
    };
    return TrackerEditorScaffold(
      title: e == null
          ? tr(context, 'New scrapbook', 'Nuevo álbum')
          : tr(context, 'Scrapbook settings', 'Ajustes del álbum'),
      canSave: _name.text.trim().isNotEmpty,
      scrollController: widget.scroll,
      onSave: () async {
        final t = ref.read(trackerNotifierProvider.notifier);
        final fields = <String, Object?>{
          'theme': _theme,
          'cover': _cover,
          'font': _font,
          'pattern': _pattern,
          'color': _color,
          'emoji': _emoji.text.trim().isEmpty ? null : _emoji.text.trim(),
          'contributors': _contributors.toList(),
          'for': _dedication,
          'forRef': _dedicationRef,
        };
        TrackerRecord book;
        if (e != null) {
          book = e!
              .copyWith(
                title: _name.text,
                body: _desc.text,
                isPrivate: _private,
              )
              .withFields(fields);
          await t.save(book);
        } else {
          book = await t.create(
            kind: TrackerKind.scrapBook,
            title: _name.text,
            body: _desc.text,
            isPrivate: _private,
            memberId: currentFronterId(ref),
            fields: fields,
          );
        }
        // Dedicated books are linked to what they are about.
        final target = RecordRef.parse(_dedicationRef);
        if (target != null)
          await ref
              .read(linkActionsProvider)
              .link(
                RecordRef(RecordRef.rec, book.id),
                target,
                category: 'partOf',
              );
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        Row(
          children: [
            SizedBox(
              width: 70,
              child: PrismTextField(
                controller: _emoji,
                labelText: tr(context, 'Icon', 'Icono'),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PrismTextField(
                controller: _name,
                labelText: tr(context, 'Name', 'Nombre'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _desc,
          labelText: tr(context, 'Description', 'Descripción'),
          maxLines: 3,
          minLines: 1,
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Made for', 'Hecho para')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (id, label) in dedicationOptions)
              PrismChip(
                label: label,
                selected: _dedication == id,
                onTap: () => setState(() {
                  _dedication = id;
                  _dedicationRef = null;
                }),
              ),
          ],
        ),
        if (refChoices.isNotEmpty) ...[
          const SizedBox(height: 6),
          PrismSelect<String>(
            value: _dedicationRef,
            hintText: tr(context, 'Choose…', 'Elegir…'),
            items: [
              for (final i in refChoices)
                PrismSelectItem(value: i.ref.key, label: i.title),
            ],
            onChanged: (v) => setState(() => _dedicationRef = v),
          ),
        ],
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Theme', 'Tema')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in scrapThemes)
              GestureDetector(
                onTap: () => setState(() {
                  _theme = t.$1;
                  _color = null;
                }),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Color(t.$4),
                        borderRadius: prismCorners(context, 6),
                        border: Border.all(
                          color: _theme == t.$1
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 30,
                          color: Color(t.$5),
                        ),
                      ),
                    ),
                    Text(
                      tr(context, t.$2, t.$3),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Cover colour', 'Color de portada')),
        ColorChoiceRow(
          value: _color,
          onChanged: (c) => setState(() => _color = c),
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Cover picture', 'Imagen de portada')),
        Row(
          children: [
            if (_cover != null)
              ClipRRect(
                borderRadius: prismCorners(context, 8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: PrismMediaView(id: _cover!),
                ),
              ),
            const SizedBox(width: 8),
            PrismButton(
              label: tr(context, 'Choose', 'Elegir'),
              icon: AppIcons.imageOutlined,
              onPressed: () async {
                final id = await PrismMedia.pickImage(
                  ref,
                  spec: const PrismCropSpec(aspect: scrapPageAspect),
                );
                if (id != null) setState(() => _cover = id);
              },
            ),
            if (_cover != null)
              PrismButton(
                label: tr(context, 'Remove', 'Quitar'),
                onPressed: () => setState(() => _cover = null),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Title font', 'Fuente del título')),
        Wrap(
          spacing: 6,
          children: [
            for (final (id, label) in scrapFonts)
              PrismChip(
                label: label,
                selected: _font == id,
                onTap: () => setState(() => _font = id),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Default page style', 'Estilo de página')),
        Wrap(
          spacing: 6,
          children: [
            for (final p in scrapPatterns)
              PrismChip(
                label: p,
                selected: _pattern == p,
                onTap: () => setState(() => _pattern = p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PrismSwitchRow(
          title: tr(context, 'Private scrapbook', 'Álbum privado'),
          subtitle: tr(
            context,
            'Hidden behind a tap and left out of summaries and the connections explorer.',
            'Oculto tras un toque y fuera de resúmenes y del explorador.',
          ),
          value: _private,
          onChanged: (v) => setState(() => _private = v),
        ),
        TrackerLabel(
          tr(context, 'Who can contribute', 'Quién puede colaborar'),
        ),
        Text(
          tr(
            context,
            'Leave all unselected to let every alter add pages.',
            'Deja todos sin marcar para que cualquier alter pueda añadir.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in members)
              PrismChip(
                label: m.effectiveName(preferDisplayName: preferDisplay),
                selected: _contributors.contains(m.id),
                onTap: () => setState(
                  () => _contributors.contains(m.id)
                      ? _contributors.remove(m.id)
                      : _contributors.add(m.id),
                ),
              ),
          ],
        ),
        if (e != null) ...[
          const SizedBox(height: 16),
          RelatedRecordsSection(self: RecordRef(RecordRef.rec, e!.id)),
          const SizedBox(height: 16),
          PrismButton(
            label: tr(context, 'Delete scrapbook', 'Eliminar álbum'),
            tone: PrismButtonTone.destructive,
            icon: AppIcons.delete,
            onPressed: () async {
              final ok = await PrismDialog.confirm(
                context: context,
                title: tr(
                  context,
                  'Delete this scrapbook and all its pages?',
                  '¿Eliminar este álbum y todas sus páginas?',
                ),
                destructive: true,
                confirmLabel: tr(context, 'Delete', 'Eliminar'),
                cancelLabel: context.l10n.cancel,
              );
              if (!ok) return;
              await ref.read(trackerNotifierProvider.notifier).delete(e!.id);
              if (context.mounted) {
                Navigator.of(context).pop();
                if (GoRouter.of(context).canPop()) context.pop();
              }
            },
          ),
        ],
      ],
    );
  }
}
