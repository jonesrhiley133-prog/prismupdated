import 'package:intl/intl.dart';

import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/features/links/views/record_opener.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

String shortDate(BuildContext context, DateTime? d) =>
    d == null ? '' : DateFormat.yMMMd(context.dateLocale).format(d);

/// "Connected records" block for any detail page: lists links, opens the
/// other record, and adds new links.
class RelatedRecordsSection extends ConsumerWidget {
  const RelatedRecordsSection({super.key, required this.self, this.padding = const EdgeInsets.only(top: 16)});

  final RecordRef self;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(linksForRecordProvider(self.key));
    final cats = {
      for (final c in ref.watch(linkCategoriesProvider(Localizations.localeOf(context).languageCode))) c.id: c,
    };
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.linkSimple(), size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(context, 'Connected records', 'Registros conectados'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              PrismButton(
                label: tr(context, 'Connect', 'Conectar'),
                icon: AppIcons.add,
                onPressed: () => showLinkPicker(context, self),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (links.isEmpty)
            Text(
              tr(context, 'Nothing connected yet. Link moods, dreams, events, alters and more to see them together.',
                  'Nada conectado aún. Enlaza ánimos, sueños, eventos, alters y más para verlos juntos.'),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            for (final (link, info) in links)
              _LinkRow(link: link, info: info, category: cats[link.category]),
        ],
      ),
    );
  }
}

class _LinkRow extends ConsumerWidget {
  const _LinkRow({required this.link, required this.info, this.category});
  final RecordLink link;
  final RecordInfo info;
  final LinkCategory? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = moduleFor(info.module);
    final theme = Theme.of(context);
    return PrismSurface(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => openRecord(context, ref, info),
      onLongPress: () => _edit(context, ref),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: m.color.withValues(alpha: 0.18),
            child: Icon(m.icon, size: 16, color: m.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.isPrivate ? tr(context, 'Private record', 'Registro privado') : info.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                Text(
                  [
                    m.label(context),
                    if (category != null) category!.label,
                    if (info.date != null) shortDate(context, info.date),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (link.note != null)
                  Text(link.note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Edit link', 'Editar enlace'),
            icon: Icon(AppIcons.moreVert, size: 18),
            onPressed: () => _edit(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    await PrismSheet.show(
      context: context,
      title: tr(context, 'Link', 'Enlace'),
      builder: (ctx) => _LinkEditor(link: link),
    );
  }
}

class _LinkEditor extends ConsumerStatefulWidget {
  const _LinkEditor({required this.link});
  final RecordLink link;

  @override
  ConsumerState<_LinkEditor> createState() => _LinkEditorState();
}

class _LinkEditorState extends ConsumerState<_LinkEditor> {
  late String _cat = widget.link.category;
  late final _note = TextEditingController(text: widget.link.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(linkCategoriesProvider(Localizations.localeOf(context).languageCode));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CategoryChips(categories: cats, selected: _cat, onSelected: (c) => setState(() => _cat = c)),
          const SizedBox(height: 12),
          PrismTextField(controller: _note, labelText: tr(context, 'Note', 'Nota'), maxLines: 3, minLines: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              PrismButton(
                label: tr(context, 'Remove link', 'Quitar enlace'),
                icon: AppIcons.linkOff,
                tone: PrismButtonTone.destructive,
                onPressed: () async {
                  await ref.read(linkActionsProvider).unlink(widget.link.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const Spacer(),
              PrismButton(
                label: tr(context, 'Save', 'Guardar'),
                tone: PrismButtonTone.filled,
                onPressed: () async {
                  await ref.read(linkActionsProvider).update(widget.link, category: _cat, note: _note.text.trim());
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Category chips with "+ New category".
class CategoryChips extends ConsumerWidget {
  const CategoryChips({super.key, required this.categories, required this.selected, required this.onSelected});
  final List<LinkCategory> categories;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in categories)
          PrismChip(
            label: c.label,
            selected: selected == c.id,
            selectedColor: Color(c.color),
            onTap: () => onSelected(c.id),
          ),
        PrismChip(
          label: tr(context, '+ New category', '+ Nueva categoría'),
          selected: false,
          variant: PrismChipVariant.inline,
          onTap: () async {
            final name = await promptText(context, tr(context, 'Category name', 'Nombre de la categoría'));
            if (name == null || name.isEmpty) return;
            final palette = trackerPalette;
            final rec = await ref.read(linkActionsProvider).addCategory(name, palette[categories.length % palette.length]);
            onSelected(rec.id);
          },
        ),
      ],
    );
  }
}

/// Simple one-field prompt.
Future<String?> promptText(BuildContext context, String title, {String? initial, String? hint, int maxLines = 1}) async {
  final c = TextEditingController(text: initial);
  final ok = await PrismDialog.show<bool>(
    context: context,
    title: title,
    builder: (ctx) => PrismTextField(
      controller: c,
      autofocus: true,
      hintText: hint,
      maxLines: maxLines,
      minLines: 1,
      onSubmitted: (_) => Navigator.of(ctx, rootNavigator: true).pop(true),
    ),
    actions: [
      PrismButton(label: context.l10n.cancel, onPressed: () => Navigator.of(context, rootNavigator: true).pop(false)),
      PrismButton(
        label: context.l10n.save,
        tone: PrismButtonTone.filled,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
      ),
    ],
  );
  final v = c.text.trim();
  c.dispose();
  return ok == true ? v : null;
}

/// Searchable picker across every module; links the chosen records to [self].
Future<void> showLinkPicker(BuildContext context, RecordRef self) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) => _LinkPicker(self: self, scroll: scroll),
);

class _LinkPicker extends ConsumerStatefulWidget {
  const _LinkPicker({required this.self, required this.scroll});
  final RecordRef self;
  final ScrollController scroll;

  @override
  ConsumerState<_LinkPicker> createState() => _LinkPickerState();
}

class _LinkPickerState extends ConsumerState<_LinkPicker> {
  final _q = TextEditingController();
  String? _module;
  String _cat = 'related';
  final Set<String> _chosen = {};

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(recordCatalogProvider);
    final existing = {for (final (_, i) in ref.watch(linksForRecordProvider(widget.self.key))) i.ref.key};
    final q = _q.text.trim().toLowerCase();
    final items = [
      for (final i in catalog.values)
        if (i.ref != widget.self &&
            (_module == null || i.module == _module) &&
            (q.isEmpty || i.title.toLowerCase().contains(q) || (i.subtitle?.toLowerCase().contains(q) ?? false)))
          i,
    ]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    final modules = {for (final i in catalog.values) i.module};
    final cats = ref.watch(linkCategoriesProvider(Localizations.localeOf(context).languageCode));
    return TrackerEditorScaffold(
      title: tr(context, 'Connect records', 'Conectar registros'),
      canSave: _chosen.isNotEmpty,
      scrollController: widget.scroll,
      onSave: () async {
        final actions = ref.read(linkActionsProvider);
        for (final k in _chosen) {
          final r = RecordRef.parse(k);
          if (r != null) await actions.link(widget.self, r, category: _cat);
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        PrismTextField(
          controller: _q,
          hintText: tr(context, 'Search everything', 'Buscar en todo'),
          prefixIcon: Icon(AppIcons.search),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PrismChip(label: tr(context, 'All', 'Todo'), selected: _module == null, onTap: () => setState(() => _module = null)),
              ),
              for (final m in recordModules)
                if (modules.contains(m.key))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(
                      label: m.label(context),
                      selected: _module == m.key,
                      selectedColor: m.color,
                      onTap: () => setState(() => _module = _module == m.key ? null : m.key),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TrackerLabel(tr(context, 'Relationship', 'Relación')),
        CategoryChips(categories: cats, selected: _cat, onSelected: (c) => setState(() => _cat = c)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(tr(context, 'No matching records', 'No hay registros que coincidan'))),
          ),
        for (final i in items.take(300))
          _PickRow(
            info: i,
            linked: existing.contains(i.ref.key),
            chosen: _chosen.contains(i.ref.key),
            onTap: () => setState(() => _chosen.contains(i.ref.key) ? _chosen.remove(i.ref.key) : _chosen.add(i.ref.key)),
          ),
      ],
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.info, required this.linked, required this.chosen, required this.onTap});
  final RecordInfo info;
  final bool linked;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = moduleFor(info.module);
    return PrismListRow(
      dense: true,
      leading: Icon(m.icon, color: m.color),
      title: Text(info.isPrivate ? tr(context, 'Private record', 'Registro privado') : info.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [m.label(context), if (info.date != null) shortDate(context, info.date), if (linked) tr(context, 'already linked', 'ya enlazado')].join(' · '),
      ),
      trailing: Icon(chosen ? AppIcons.checkCircle : AppIcons.addCircleOutline,
          color: chosen ? Theme.of(context).colorScheme.primary : null),
      onTap: onTap,
    );
  }
}
