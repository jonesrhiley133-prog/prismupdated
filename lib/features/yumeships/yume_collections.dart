import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_editing.dart';
import 'package:prism_plurality/features/yumeships/yume_hub.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/prism_image_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_emoji_picker.dart';

/// A collection's cover on a shelf.
class YumeCollectionCover extends ConsumerWidget {
  const YumeCollectionCover({super.key, required this.c});
  final YumeCollection c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = yumeAccent(context, c.accent);
    final count = ref.watch(yumeCollectionShipsProvider(c.id)).length;
    final theme = Theme.of(context);
    return YumeCard(
      accent: a,
      card: 'paper',
      padding: EdgeInsets.zero,
      radius: 12,
      onTap: () => _open(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: c.cover != null
                  ? YumeMediaImage(id: c.cover!)
                  : ColoredBox(
                      color: a.withValues(alpha: 0.16),
                      child: Center(
                        child: Text(
                          c.emoji,
                          style: const TextStyle(fontSize: 36),
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  c.locked && yumeIsHidden(ref, true, c.id)
                      ? '🔒'
                      : tr(context, '$count ships', '$count ships'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (c.locked && !ref.read(yumeUnlocksProvider.notifier).isOpen(c.id)) {
      if (!await yumeUnlock(context, ref, id: c.id)) return;
    }
    if (context.mounted) context.push(AppRoutePaths.yumeCollection(c.id));
  }
}

/// One collection: its ships in your order (drag to rearrange).
class YumeCollectionScreen extends ConsumerStatefulWidget {
  const YumeCollectionScreen({super.key, required this.collectionId});
  final String collectionId;
  @override
  ConsumerState<YumeCollectionScreen> createState() =>
      _YumeCollectionScreenState();
}

class _YumeCollectionScreenState extends ConsumerState<YumeCollectionScreen> {
  bool _arrange = false;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(yumeCollectionByIdProvider(widget.collectionId));
    final viewer = ref.watch(yumeViewerProvider);
    if (c == null || !c.canView(viewer)) {
      return PrismPageScaffold(
        topBar: const PrismTopBar(title: '', showBackButton: true),
        body: Center(
          child: Text(
            tr(
              context,
              'Collection not available.',
              'Colección no disponible.',
            ),
          ),
        ),
      );
    }
    if (yumeIsHidden(ref, c.locked, c.id)) {
      return PrismPageScaffold(
        topBar: PrismTopBar(title: c.name, showBackButton: true),
        body: EmptyState(
          icon: Icon(Icons.lock_outline),
          title: tr(context, 'Locked', 'Bloqueado'),
          subtitle: tr(
            context,
            'Enter your Yumeships PIN.',
            'Introduce tu PIN de Yumeships.',
          ),
          actionLabel: tr(context, 'Unlock', 'Desbloquear'),
          onAction: () => yumeUnlock(context, ref, id: c.id),
        ),
      );
    }
    final ships = ref.watch(yumeCollectionShipsProvider(c.id));
    final view = ref.watch(yumeSettingsProvider).view;
    final a = yumeAccent(context, c.accent);
    final canEdit = c.canEdit(viewer);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: '${c.emoji} ${c.name}',
        showBackButton: true,
        actions: [
          if (canEdit)
            PrismTopBarAction(
              icon: _arrange ? Icons.check : Icons.swap_vert,
              tooltip: _arrange
                  ? tr(context, 'Done', 'Listo')
                  : tr(context, 'Arrange', 'Ordenar'),
              onPressed: () => setState(() => _arrange = !_arrange),
            ),
          if (canEdit)
            PrismTopBarAction(
              icon: Icons.playlist_add,
              tooltip: tr(context, 'Choose ships', 'Elegir ships'),
              onPressed: () => _pickShips(c),
            ),
          if (canEdit)
            PrismTopBarAction(
              icon: Icons.edit_outlined,
              tooltip: tr(context, 'Edit collection', 'Editar colección'),
              onPressed: () => showYumeCollectionEditor(context, editing: c),
            ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: _arrange
            ? ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: ships.length,
                onReorder: (from, to) {
                  final ids = [for (final s in ships) s.id];
                  if (to > from) to--;
                  ids.insert(to, ids.removeAt(from));
                  ref.read(yumeActionsProvider).saveCollection(c, {
                    'shipIds': ids,
                  });
                },
                itemBuilder: (context, i) => Padding(
                  key: ValueKey(ships[i].id),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: YumeShipRow(
                    ship: ships[i],
                    trailing: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                ),
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  32 + NavBarInset.of(context),
                ),
                children: [
                  if (c.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(c.description),
                    ),
                  if (c.smart)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        tr(
                          context,
                          'Fills itself: ${yumeCollectionTypes[c.type]!.$1.toLowerCase()}${c.type == 'source' ? ' (${c.source})' : ''}. You can add others by hand too.',
                          'Se llena sola. También puedes añadir otros a mano.',
                        ),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: a),
                      ),
                    ),
                  if (ships.isEmpty)
                    EmptyState(
                      icon: Icon(Icons.collections_bookmark_outlined),
                      title: tr(context, 'An empty shelf', 'Un estante vacío'),
                      subtitle: tr(
                        context,
                        'Add yumeships to this collection.',
                        'Añade yumeships a esta colección.',
                      ),
                      actionLabel: canEdit
                          ? tr(context, 'Choose ships', 'Elegir ships')
                          : null,
                      onAction: canEdit ? () => _pickShips(c) : null,
                    )
                  else
                    YumeShipViews(
                      ships: ships,
                      view: view == 'shelves' ? 'gallery' : view,
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickShips(YumeCollection c) async {
    final all = ref.read(yumeShipsProvider);
    await PrismSheet.show<void>(
      context: context,
      title: tr(context, 'Ships in ${c.name}', 'Ships en ${c.name}'),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final cur = ref.watch(yumeCollectionByIdProvider(c.id)) ?? c;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in all)
                  CheckboxListTile(
                    value: cur.shipIds.contains(s.id),
                    title: Text(s.name),
                    subtitle: s.sources.isEmpty
                        ? null
                        : Text(s.sources.join(' · ')),
                    onChanged: (_) => ref
                        .read(yumeActionsProvider)
                        .toggleInCollection(cur, s.id),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tick the collections a ship belongs to.
Future<void> showYumeAddToCollections(BuildContext context, YumeShip s) =>
    PrismSheet.show<void>(
      context: context,
      title: tr(context, 'Collections', 'Colecciones'),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final cols = ref.watch(yumeCollectionsProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in cols)
                CheckboxListTile(
                  value: c.shipIds.contains(s.id) || c.includes(s),
                  title: Text('${c.emoji} ${c.name}'),
                  subtitle: !c.shipIds.contains(s.id) && c.includes(s)
                      ? Text(
                          tr(
                            ctx,
                            'Added automatically',
                            'Añadido automáticamente',
                          ),
                        )
                      : null,
                  onChanged: !c.shipIds.contains(s.id) && c.includes(s)
                      ? null
                      : (_) => ref
                            .read(yumeActionsProvider)
                            .toggleInCollection(c, s.id),
                ),
              PrismListRow(
                leading: const Icon(Icons.add),
                title: Text(tr(ctx, 'New collection', 'Nueva colección')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showYumeCollectionEditor(context, addShip: s.id);
                },
              ),
            ],
          );
        },
      ),
    );

/// Create or edit a collection.
Future<void> showYumeCollectionEditor(
  BuildContext context, {
  YumeCollection? editing,
  String? addShip,
}) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (ctx, scroll) =>
      _CollectionEditor(editing: editing, scroll: scroll, addShip: addShip),
);

class _CollectionEditor extends ConsumerStatefulWidget {
  const _CollectionEditor({this.editing, required this.scroll, this.addShip});
  final YumeCollection? editing;
  final ScrollController scroll;
  final String? addShip;
  @override
  ConsumerState<_CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends ConsumerState<_CollectionEditor> {
  late final c = widget.editing;
  late final _name = TextEditingController(text: c?.r.title);
  late final _desc = TextEditingController(text: c?.description);
  late final _source = TextEditingController(text: c?.source);
  late String _type = c?.type ?? 'custom';
  late Map<String, Object?> _d = c == null
      ? {'owners': const <String>[], 'visibility': 'system', 'smart': true}
      : Map<String, Object?>.of(c!.r.fields);

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = {
      for (final s in ref.watch(yumeShipsProvider)) ...s.sources,
    }.toList()..sort();
    return TrackerEditorScaffold(
      title: c == null
          ? tr(context, 'New collection', 'Nueva colección')
          : tr(context, 'Edit collection', 'Editar colección'),
      canSave: _name.text.trim().isNotEmpty || _type != 'custom',
      scrollController: widget.scroll,
      onSave: () async {
        final a = ref.read(yumeActionsProvider);
        final fields = {..._d, 'type': _type, 'source': _source.text.trim()};
        if (c == null) {
          final rec = await a.createCollection(
            name: _name.text.trim().isEmpty
                ? yumeCollectionTypes[_type]!.$1
                : _name.text,
            type: _type,
            owner: null,
            source: _source.text.trim(),
          );
          final made = YumeCollection(rec);
          await a.saveCollection(made, {
            ...fields,
            'shipIds': [?widget.addShip],
          }, body: _desc.text);
        } else {
          await a.saveCollection(
            c!,
            fields,
            title: _name.text,
            body: _desc.text,
          );
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        TrackerLabel(tr(context, 'Kind', 'Tipo')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in yumeCollectionTypes.entries)
              PrismChip(
                label: '${t.value.$3} ${tr(context, t.value.$1, t.value.$2)}',
                selected: _type == t.key,
                onTap: () => setState(() => _type = t.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _name,
          labelText: tr(context, 'Name', 'Nombre'),
          hintText: yumeCollectionTypes[_type]!.$1,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        PrismTextField(
          controller: _desc,
          labelText: tr(context, 'Description', 'Descripción'),
          minLines: 2,
          maxLines: 5,
        ),
        if (_type == 'source') ...[
          const SizedBox(height: 10),
          PrismTextField(
            controller: _source,
            labelText: tr(context, 'Source', 'Obra'),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final s in sources)
                PrismChip(
                  label: s,
                  selected: false,
                  onTap: () => setState(() => _source.text = s),
                ),
            ],
          ),
        ],
        if (_type != 'custom')
          PrismSwitchRow(
            padding: EdgeInsets.zero,
            title: tr(context, 'Fill automatically', 'Llenar automáticamente'),
            subtitle: tr(
              context,
              'Adds matching ships for you.',
              'Añade los ships que coinciden.',
            ),
            value: _d['smart'] != false,
            onChanged: (v) => setState(() => _d = {..._d, 'smart': v}),
          ),
        const SizedBox(height: 10),
        YumeImageField(
          label: tr(context, 'Cover', 'Portada'),
          value: _d['cover'] as String?,
          spec: const PrismCropSpec(aspect: 0.8),
          onChanged: (v) => setState(() => _d = {..._d, 'cover': v}),
        ),
        PrismListRow(
          padding: EdgeInsets.zero,
          title: Text(tr(context, 'Emoji', 'Emoji')),
          trailing: Text(
            '${_d['emoji'] ?? yumeCollectionTypes[_type]!.$3}',
            style: const TextStyle(fontSize: 22),
          ),
          onTap: () async {
            final e = await PrismEmojiPicker.showPicker(context);
            if (e != null) setState(() => _d = {..._d, 'emoji': e});
          },
        ),
        TrackerLabel(tr(context, 'Colour', 'Color')),
        ColorChoiceRow(
          value: (_d['accent'] as num?)?.toInt(),
          onChanged: (v) => setState(() => _d = {..._d, 'accent': v}),
        ),
        const SizedBox(height: 16),
        YumePrivacyEditor(
          draft: _d,
          collaborators: false,
          onChanged: (d) => setState(() => _d = d),
        ),
        if (c != null) ...[
          const SizedBox(height: 16),
          PrismButton(
            label: tr(context, 'Delete collection', 'Eliminar colección'),
            icon: Icons.delete_outline,
            onPressed: () async {
              final ok = await PrismDialog.confirm(
                context: context,
                title: tr(
                  context,
                  'Delete this collection?',
                  '¿Eliminar esta colección?',
                ),
                message: tr(
                  context,
                  'The yumeships in it are kept.',
                  'Los yumeships se conservan.',
                ),
                destructive: true,
                confirmLabel: tr(context, 'Delete', 'Eliminar'),
              );
              if (!ok) return;
              await ref.read(yumeActionsProvider).deleteCollection(c!);
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

/// Reorder the collections themselves.
class YumeCollectionsArrangeScreen extends ConsumerWidget {
  const YumeCollectionsArrangeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cols = ref.watch(yumeCollectionsProvider);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Arrange collections', 'Ordenar colecciones'),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: cols.length,
          onReorder: (from, to) {
            final list = [...cols];
            if (to > from) to--;
            list.insert(to, list.removeAt(from));
            ref.read(yumeActionsProvider).reorderCollections(list);
          },
          itemBuilder: (context, i) => PrismListRow(
            key: ValueKey(cols[i].id),
            leading: Text(cols[i].emoji, style: const TextStyle(fontSize: 22)),
            title: Text(cols[i].name),
            trailing: const Icon(Icons.drag_handle),
            onTap: () => context.push(AppRoutePaths.yumeCollection(cols[i].id)),
          ),
        ),
      ),
    );
  }
}
