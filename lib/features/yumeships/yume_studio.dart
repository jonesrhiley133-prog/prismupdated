import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/experiences/export_kit.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/features/scrapbook/scrapbook_screens.dart'
    show scrapBookPath;
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_editing.dart';
import 'package:prism_plurality/features/yumeships/yume_studio_content.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/prism_image_picker.dart';

/// Opens a creation, asking for the PIN first when it's locked.
Future<void> yumeOpenCreation(
  BuildContext context,
  WidgetRef ref,
  YumeCreation c,
) async {
  if (c.locked && !ref.read(yumeUnlocksProvider.notifier).isOpen(c.id)) {
    if (!await yumeUnlock(context, ref, id: c.id)) return;
  }
  if (context.mounted) context.push(AppRoutePaths.yumeCreation(c.id));
}

/// Default content a new entry starts with.
Map<String, Object?> yumeToolTemplate(String tool, {String? shipId}) =>
    switch (tool) {
      'introCard' => {'shipId': shipId, 'layout': 'classic', 'tagline': ''},
      'chart' => {
        'rows': [
          for (final (l, a, b) in yumeChartTemplates['Dynamics sheet']!)
            {'label': l, 'left': a, 'right': b, 'value': 50},
        ],
      },
      'bingo' => {
        'size': 5,
        'free': true,
        'cells': (List.of(
          yumeBingoSquares,
        )..shuffle(math.Random())).take(25).toList(),
        'marked': const <int>[],
      },
      'questionnaire' => {
        'items': [
          for (final q in yumeQuestionBanks.values.first)
            {'title': q, 'text': ''},
        ],
      },
      'matchingPfp' => {'frame': 'circle', 'symbol': '💞'},
      'moodboard' => {
        'images': const <String>[],
        'layout': 'grid',
        'words': const <String>[],
        'colors': const <int>[],
      },
      _ => {'items': const <Object>[]},
    };

/// The Creative Studio: tools plus everything you've made.
class YumeStudioScreen extends ConsumerStatefulWidget {
  const YumeStudioScreen({super.key, this.shipId});

  /// Start new entries linked to this ship.
  final String? shipId;
  @override
  ConsumerState<YumeStudioScreen> createState() => _YumeStudioScreenState();
}

class _YumeStudioScreenState extends ConsumerState<YumeStudioScreen> {
  final _q = TextEditingController();
  String? _tool;
  String? _folder;
  bool _favorites = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _create(String tool) async {
    final rec = await ref
        .read(yumeActionsProvider)
        .createCreation(
          tool: tool,
          owner: ref.read(yumeViewerProvider),
          shipIds: [?widget.shipId],
          data: yumeToolTemplate(tool, shipId: widget.shipId),
        );
    if (mounted) context.push(AppRoutePaths.yumeCreation(rec.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(yumeCreationsProvider);
    final q = _q.text.trim().toLowerCase();
    final folders = {
      for (final c in all)
        if (c.folder.isNotEmpty) c.folder,
    }.toList()..sort();
    final list = [
      for (final c in all)
        if ((_tool == null || c.tool == _tool) &&
            (_folder == null || c.folder == _folder) &&
            (!_favorites || c.favorite) &&
            (widget.shipId == null || c.shipIds.contains(widget.shipId)) &&
            (q.isEmpty || c.title.toLowerCase().contains(q)))
          c,
    ]..sort((a, b) => a.pinned != b.pinned ? (a.pinned ? -1 : 1) : 0);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Creative Studio', 'Estudio creativo'),
        showBackButton: true,
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            YumeSectionTitle(
              tr(context, 'Make something', 'Crea algo'),
              emoji: '✨',
            ),
            LayoutBuilder(
              builder: (context, box) => GridView.count(
                crossAxisCount: (box.maxWidth / 170).floor().clamp(2, 6),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.38,
                children: [
                  for (final t in yumeTools.entries)
                    YumeCard(
                      card: 'soft',
                      onTap: () => _create(t.key),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.value.$3,
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr(context, t.value.$1, t.value.$2),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Expanded(
                            child: Text(
                              t.value.$4,
                              overflow: TextOverflow.fade,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            YumeSectionTitle(
              tr(context, 'Your creations', 'Tus creaciones'),
              emoji: '🗂️',
            ),
            PrismTextField(
              controller: _q,
              prefixIcon: const Icon(Icons.search),
              hintText: tr(context, 'Search creations', 'Buscar creaciones'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(
                      label: '⭐ ${tr(context, 'Favorites', 'Favoritos')}',
                      selected: _favorites,
                      onTap: () => setState(() => _favorites = !_favorites),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(
                      label:
                          '${_tool == null ? tr(context, 'Any tool', 'Cualquier herramienta') : yumeTools[_tool]!.$1} ▾',
                      selected: _tool != null,
                      onTap: () async {
                        final v = await yumeChoose(
                          context,
                          title: tr(context, 'Tool', 'Herramienta'),
                          selected: _tool ?? '',
                          options: {
                            '': tr(context, 'Any', 'Cualquiera'),
                            for (final t in yumeTools.entries)
                              t.key: '${t.value.$3} ${t.value.$1}',
                          },
                        );
                        if (v != null)
                          setState(() => _tool = v.isEmpty ? null : v);
                      },
                    ),
                  ),
                  for (final f in folders)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: '📁 $f',
                        selected: _folder == f,
                        onTap: () =>
                            setState(() => _folder = _folder == f ? null : f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  tr(
                    context,
                    'Nothing here yet — pick a tool above.',
                    'Aún nada — elige una herramienta.',
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, box) => GridView.count(
                  crossAxisCount: (box.maxWidth / 180).floor().clamp(2, 6),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.35,
                  children: [for (final c in list) YumeCreationTile(c: c)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A creation on a shelf or grid.
class YumeCreationTile extends ConsumerWidget {
  const YumeCreationTile({super.key, required this.c});
  final YumeCreation c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (yumeIsHidden(ref, c.locked, c.id))
      return YumeLockedTile(onUnlock: () => yumeOpenCreation(context, ref, c));
    final theme = Theme.of(context);
    final ship = c.shipIds.isEmpty
        ? null
        : ref.watch(yumeShipByIdProvider(c.shipIds.first));
    return YumeCard(
      accent: yumeAccent(context, ship?.accent),
      card: 'paper',
      onTap: () => yumeOpenCreation(context, ref, c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(yumeTools[c.tool]!.$3, style: const TextStyle(fontSize: 22)),
              const Spacer(),
              if (c.favorite) const Icon(Icons.star_rounded, size: 16),
              if (c.locked) const Icon(Icons.lock_outline, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            c.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          Text(
            ship?.name ?? yumeTools[c.tool]!.$1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// One creation, edited in place (changes save as you go).
class YumeCreationScreen extends ConsumerStatefulWidget {
  const YumeCreationScreen({super.key, required this.creationId});
  final String creationId;
  @override
  ConsumerState<YumeCreationScreen> createState() => _YumeCreationScreenState();
}

class _YumeCreationScreenState extends ConsumerState<YumeCreationScreen> {
  Map<String, Object?>? _data;
  Timer? _debounce;
  final _exportKey = GlobalKey();

  @override
  void dispose() {
    _debounce?.cancel();
    final c = ref.read(yumeCreationByIdProvider(widget.creationId));
    if (_data != null && c != null && _pending) {
      ref.read(yumeActionsProvider).saveCreation(c, {'data': _data});
    }
    super.dispose();
  }

  bool _pending = false;

  void _update(Map<String, Object?> d) {
    setState(() => _data = d);
    _pending = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _flush);
  }

  Future<void> _flush() async {
    final c = ref.read(yumeCreationByIdProvider(widget.creationId));
    if (c == null || _data == null) return;
    _pending = false;
    await ref.read(yumeActionsProvider).saveCreation(c, {'data': _data});
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(yumeCreationByIdProvider(widget.creationId));
    final viewer = ref.watch(yumeViewerProvider);
    if (c == null || !c.canView(viewer)) {
      return PrismPageScaffold(
        topBar: const PrismTopBar(title: '', showBackButton: true),
        body: Center(
          child: Text(tr(context, 'Not available.', 'No disponible.')),
        ),
      );
    }
    if (yumeIsHidden(ref, c.locked, c.id)) {
      return PrismPageScaffold(
        topBar: const PrismTopBar(title: '', showBackButton: true),
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
    final data = _data ?? Map<String, Object?>.of(c.data);
    final canEdit = c.canEdit(viewer);
    final visual = const {
      'introCard',
      'bingo',
      'matchingPfp',
      'moodboard',
      'chart',
    }.contains(c.tool);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: c.title,
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: visual ? Icons.image_outlined : Icons.copy,
            tooltip: visual
                ? tr(context, 'Save as image', 'Guardar como imagen')
                : tr(context, 'Copy as text', 'Copiar como texto'),
            onPressed: () async {
              if (visual) {
                final b = await captureBoundary(_exportKey, pixelRatio: 3);
                final ok = b != null && await saveImageBytes(ref, b, c.title);
                if (context.mounted)
                  PrismToast.show(
                    context,
                    message: ok
                        ? tr(context, 'Image saved', 'Imagen guardada')
                        : tr(context, 'Not saved', 'No guardado'),
                  );
              } else {
                await Clipboard.setData(
                  ClipboardData(text: yumeCreationText(c.title, c.tool, data)),
                );
                if (context.mounted)
                  PrismToast.success(
                    context,
                    message: tr(context, 'Copied', 'Copiado'),
                  );
              }
            },
          ),
          if (canEdit)
            PrismTopBarAction(
              icon: Icons.more_horiz,
              tooltip: tr(context, 'More', 'Más'),
              onPressed: () => _more(c),
            ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _ShipLinks(c: c, canEdit: canEdit),
            const SizedBox(height: 8),
            AbsorbPointer(absorbing: !canEdit, child: _toolEditor(c, data)),
            const SizedBox(height: 16),
            RelatedRecordsSection(
              self: RecordRef(RecordRef.rec, c.id),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolEditor(
    YumeCreation c,
    Map<String, Object?> d,
  ) => switch (c.tool) {
    'introCard' => _IntroCardEditor(
      data: d,
      onChanged: _update,
      exportKey: _exportKey,
    ),
    'chart' => _ChartEditor(data: d, onChanged: _update, exportKey: _exportKey),
    'bingo' => _BingoEditor(data: d, onChanged: _update, exportKey: _exportKey),
    'matchingPfp' => _MatchingEditor(
      data: d,
      onChanged: _update,
      exportKey: _exportKey,
    ),
    'moodboard' => _MoodboardEditor(
      data: d,
      onChanged: _update,
      exportKey: _exportKey,
      creation: c,
    ),
    'questionnaire' => _ItemsEditor(
      data: d,
      onChanged: _update,
      schema: const _Schema(titleLabel: 'Question', textLabel: 'Answer'),
      extra: (add) => Wrap(
        spacing: 6,
        children: [
          for (final bank in yumeQuestionBanks.entries)
            PrismChip(
              label: '+ ${bank.key}',
              selected: false,
              onTap: () => add([
                for (final q in bank.value)
                  {'id': yumeId(), 'title': q, 'text': ''},
              ]),
            ),
        ],
      ),
    ),
    'fic' => _ItemsEditor(
      data: d,
      onChanged: _update,
      schema: const _Schema(
        titleLabel: 'Title',
        textLabel: 'Summary / notes',
        statuses: yumeFicStatuses,
        link: true,
        number: 'Words',
      ),
    ),
    'timeline' => _ItemsEditor(
      data: d,
      onChanged: _update,
      schema: const _Schema(
        titleLabel: 'Moment',
        textLabel: 'What happened',
        date: true,
      ),
    ),
    'headcanons' => _ItemsEditor(
      data: d,
      onChanged: _update,
      schema: const _Schema(titleLabel: 'Theme', textLabel: 'Headcanon'),
    ),
    'wishlist' => _ItemsEditor(
      data: d,
      onChanged: _update,
      schema: const _Schema(
        titleLabel: 'Piece',
        textLabel: 'Artist & notes',
        statuses: yumeWishStatuses,
        link: true,
        number: 'Budget',
        date: true,
        dateLabel: 'Deadline',
      ),
    ),
    'appreciation' => _ItemsEditor(
      data: d,
      onChanged: _update,
      schema: const _Schema(
        titleLabel: 'Feeling (emoji or word)',
        textLabel: 'What I love today',
        date: true,
        newestFirst: true,
      ),
    ),
    _ => _ItemsEditor(
      data: d,
      onChanged: _update,
      schema: const _Schema(titleLabel: 'Prompt', showText: false, done: true),
      extra: (add) => Wrap(
        spacing: 6,
        children: [
          PrismChip(
            label: tr(context, 'Random prompt', 'Idea al azar'),
            selected: false,
            avatar: const Icon(Icons.casino_outlined, size: 18),
            onTap: () => add([
              {
                'id': yumeId(),
                'title':
                    yumePromptBank[math.Random().nextInt(
                      yumePromptBank.length,
                    )],
                'done': false,
              },
            ]),
          ),
          PrismChip(
            label: tr(context, '+ Whole prompt bank', '+ Todas las ideas'),
            selected: false,
            onTap: () => add([
              for (final p in yumePromptBank)
                {'id': yumeId(), 'title': p, 'done': false},
            ]),
          ),
        ],
      ),
    ),
  };

  Future<void> _more(YumeCreation c) async {
    final a = ref.read(yumeActionsProvider);
    final v = await yumeChoose(
      context,
      title: c.title,
      options: {
        'rename': tr(context, 'Rename', 'Renombrar'),
        'favorite': c.favorite
            ? tr(context, 'Remove from favorites', 'Quitar de favoritos')
            : tr(context, 'Add to favorites', 'Añadir a favoritos'),
        'pin': c.pinned
            ? tr(context, 'Unpin', 'Desfijar')
            : tr(context, 'Pin to top', 'Fijar arriba'),
        'folder': tr(context, 'Move to folder…', 'Mover a carpeta…'),
        'privacy': tr(context, 'Privacy…', 'Privacidad…'),
        'text': tr(context, 'Copy as text', 'Copiar como texto'),
        'duplicate': tr(context, 'Duplicate', 'Duplicar'),
        'delete': tr(context, 'Delete', 'Eliminar'),
      },
    );
    if (!mounted || v == null) return;
    await _flush();
    final cur = ref.read(yumeCreationByIdProvider(c.id)) ?? c;
    switch (v) {
      case 'rename' || 'folder':
        final ctrl = TextEditingController(
          text: v == 'rename' ? cur.title : cur.folder,
        );
        final out = await PrismDialog.show<String>(
          context: context,
          title: v == 'rename'
              ? tr(context, 'Rename', 'Renombrar')
              : tr(context, 'Folder', 'Carpeta'),
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrismTextField(controller: ctrl, autofocus: true),
              const SizedBox(height: 12),
              PrismButton(
                label: tr(ctx, 'Save', 'Guardar'),
                tone: PrismButtonTone.filled,
                onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              ),
            ],
          ),
        );
        if (out == null) return;
        if (v == 'rename') {
          await a.saveCreation(cur, const {}, title: out);
        } else {
          await a.saveCreation(cur, {'folder': out});
        }
      case 'favorite':
        await a.saveCreation(cur, {'favorite': !cur.favorite});
      case 'pin':
        await a.saveCreation(cur, const {}, pinned: !cur.pinned);
      case 'privacy':
        var draft = Map<String, Object?>.of(cur.r.fields);
        await PrismSheet.showFullScreen<void>(
          context: context,
          builder: (ctx, scroll) => StatefulBuilder(
            builder: (ctx, set) => TrackerEditorScaffold(
              title: tr(ctx, 'Privacy', 'Privacidad'),
              canSave: true,
              scrollController: scroll,
              onSave: () async {
                await a.saveCreation(cur, {
                  for (final k in [
                    'owners',
                    'collab',
                    'shared',
                    'visibility',
                    'locked',
                  ])
                    k: draft[k],
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              children: [
                YumePrivacyEditor(
                  draft: draft,
                  onChanged: (d) => set(() => draft = d),
                ),
              ],
            ),
          ),
        );
      case 'text':
        await Clipboard.setData(
          ClipboardData(text: yumeCreationText(cur.title, cur.tool, cur.data)),
        );
        if (mounted)
          PrismToast.success(
            context,
            message: tr(context, 'Copied', 'Copiado'),
          );
      case 'duplicate':
        final copy = await a.duplicateCreation(cur);
        if (mounted) context.push(AppRoutePaths.yumeCreation(copy.id));
      case 'delete':
        final ok = await PrismDialog.confirm(
          context: context,
          title: tr(context, 'Delete ${cur.title}?', '¿Eliminar ${cur.title}?'),
          destructive: true,
          confirmLabel: tr(context, 'Delete', 'Eliminar'),
        );
        if (!ok) return;
        _pending = false;
        await a.deleteCreation(cur);
        if (mounted) context.pop();
    }
  }
}

class _ShipLinks extends ConsumerWidget {
  const _ShipLinks({required this.c, required this.canEdit});
  final YumeCreation c;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ships = ref.watch(yumeShipsProvider);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final id in c.shipIds)
          if (ships.where((s) => s.id == id).firstOrNull case final s?)
            PrismChip(
              label: s.name,
              selected: false,
              avatar: Text(s.symbol),
              onTap: () => context.push(AppRoutePaths.yumeShip(s.id)),
            ),
        if (canEdit)
          PrismChip(
            label: tr(context, 'Yumeships…', 'Yumeships…'),
            selected: false,
            avatar: const Icon(Icons.link, size: 18),
            onTap: () => PrismSheet.show<void>(
              context: context,
              title: tr(context, 'Linked yumeships', 'Yumeships vinculados'),
              builder: (ctx) => Consumer(
                builder: (ctx, ref, _) {
                  final cur = ref.watch(yumeCreationByIdProvider(c.id)) ?? c;
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.6,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final s in ships)
                          CheckboxListTile(
                            value: cur.shipIds.contains(s.id),
                            title: Text(s.name),
                            onChanged: (v) {
                              final ids = [...cur.shipIds]..remove(s.id);
                              if (v == true) ids.add(s.id);
                              ref.read(yumeActionsProvider).saveCreation(cur, {
                                'shipIds': ids,
                              });
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Plain-text version of a creation (for copying or sharing).
String yumeCreationText(String title, String tool, Map<String, Object?> d) {
  final b = StringBuffer('$title\n');
  List<Map> items() => [
    for (final x in (d['items'] as List?) ?? const [])
      if (x is Map) x,
  ];
  switch (tool) {
    case 'chart':
      for (final r in (d['rows'] as List?) ?? const []) {
        final m = r as Map;
        b.writeln(
          '${m['label']}: ${m['left']} ${'·' * (((m['value'] as num?) ?? 50) ~/ 10)}| ${m['right']}',
        );
      }
    case 'bingo':
      final cells = [for (final c in (d['cells'] as List?) ?? const []) '$c'];
      final marked = {
        for (final m in (d['marked'] as List?) ?? const []) (m as num).toInt(),
      };
      final n = (d['size'] as num?)?.toInt() ?? 5;
      for (var r = 0; r < n; r++) {
        b.writeln(
          [
            for (var c = 0; c < n; c++)
              if (r * n + c < cells.length)
                '${marked.contains(r * n + c) ? '✅' : '⬜'} ${cells[r * n + c]}',
          ].join(' | '),
        );
      }
    case 'introCard' || 'matchingPfp' || 'moodboard':
      if ((d['tagline'] ?? '').toString().isNotEmpty) b.writeln(d['tagline']);
      for (final w in (d['words'] as List?) ?? const []) {
        b.write('$w · ');
      }
    default:
      for (final m in items()) {
        final date = DateTime.tryParse('${m['date'] ?? ''}');
        final status = '${m['status'] ?? ''}';
        b.writeln(
          [
            if (m['done'] == true) '✅' else if (tool == 'prompts') '⬜',
            if (date != null) yumeDate(date),
            '${m['title'] ?? ''}',
            if (status.isNotEmpty) '[$status]',
          ].where((x) => x.isNotEmpty).join(' '),
        );
        if ('${m['text'] ?? ''}'.isNotEmpty) b.writeln('  ${m['text']}');
        if ('${m['link'] ?? ''}'.isNotEmpty) b.writeln('  ${m['link']}');
      }
  }
  return b.toString().trim();
}

// ── Generic list tools ──────────────────────────────────────────────────

class _Schema {
  const _Schema({
    required this.titleLabel,
    this.textLabel = 'Notes',
    this.showText = true,
    this.date = false,
    this.dateLabel = 'Date',
    this.statuses = const [],
    this.link = false,
    this.number,
    this.done = false,
    this.newestFirst = false,
  });
  final String titleLabel, textLabel, dateLabel;
  final bool showText, date, link, done, newestFirst;
  final List<String> statuses;
  final String? number;
}

class _ItemsEditor extends StatelessWidget {
  const _ItemsEditor({
    required this.data,
    required this.onChanged,
    required this.schema,
    this.extra,
  });
  final Map<String, Object?> data;
  final ValueChanged<Map<String, Object?>> onChanged;
  final _Schema schema;
  final Widget Function(void Function(List<Map<String, Object?>>) add)? extra;

  List<Map<String, Object?>> get _items => [
    for (final x in (data['items'] as List?) ?? const [])
      if (x is Map) x.cast<String, Object?>(),
  ];

  void _setItems(List<Map<String, Object?>> v) =>
      onChanged({...data, 'items': v});

  @override
  Widget build(BuildContext context) {
    final items = _items;
    void add(List<Map<String, Object?>> more) => _setItems(
      schema.newestFirst ? [...more, ...items] : [...items, ...more],
    );
    final done = items.where((i) => i['done'] == true).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (schema.done && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tr(
                context,
                '$done of ${items.length} done',
                '$done de ${items.length} hechas',
              ),
            ),
          ),
        for (var i = 0; i < items.length; i++)
          Padding(
            key: ValueKey(items[i]['id'] ?? i),
            padding: const EdgeInsets.only(bottom: 8),
            child: PrismSurface(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (schema.done)
                    Checkbox(
                      value: items[i]['done'] == true,
                      onChanged: (v) => _setItems(
                        [...items]..[i] = {...items[i], 'done': v == true},
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PrismTextField(
                          initialValue: '${items[i]['title'] ?? ''}',
                          labelText: schema.titleLabel,
                          maxLines: 3,
                          onChanged: (v) => _setItems(
                            [...items]..[i] = {...items[i], 'title': v},
                          ),
                        ),
                        if (schema.showText) ...[
                          const SizedBox(height: 6),
                          PrismTextField(
                            initialValue: '${items[i]['text'] ?? ''}',
                            labelText: schema.textLabel,
                            minLines: 2,
                            maxLines: 12,
                            onChanged: (v) => _setItems(
                              [...items]..[i] = {...items[i], 'text': v},
                            ),
                          ),
                        ],
                        if (schema.link) ...[
                          const SizedBox(height: 6),
                          PrismTextField(
                            initialValue: '${items[i]['link'] ?? ''}',
                            labelText: tr(context, 'Link', 'Enlace'),
                            keyboardType: TextInputType.url,
                            onChanged: (v) => _setItems(
                              [...items]..[i] = {...items[i], 'link': v},
                            ),
                          ),
                        ],
                        if (schema.number != null) ...[
                          const SizedBox(height: 6),
                          PrismTextField(
                            initialValue: '${items[i]['number'] ?? ''}',
                            labelText: schema.number,
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _setItems(
                              [...items]..[i] = {...items[i], 'number': v},
                            ),
                          ),
                        ],
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (schema.date)
                              YumeAction(
                                label:
                                    DateTime.tryParse(
                                          '${items[i]['date'] ?? ''}',
                                        ) ==
                                        null
                                    ? schema.dateLabel
                                    : yumeDate(
                                        DateTime.parse('${items[i]['date']}'),
                                      ),
                                icon: Icons.event_outlined,
                                onPressed: () async {
                                  final d = await showPrismDatePicker(
                                    context: context,
                                    initialDate:
                                        DateTime.tryParse(
                                          '${items[i]['date'] ?? ''}',
                                        ) ??
                                        DateTime.now(),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime(2200),
                                  );
                                  if (d != null)
                                    _setItems(
                                      [...items]
                                        ..[i] = {
                                          ...items[i],
                                          'date': d.toIso8601String(),
                                        },
                                    );
                                },
                              ),
                            for (final s in schema.statuses)
                              PrismChip(
                                label: s,
                                selected: items[i]['status'] == s,
                                onTap: () => _setItems(
                                  [...items]..[i] = {...items[i], 'status': s},
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        tooltip: tr(context, 'Remove', 'Quitar'),
                        icon: const Icon(Icons.close),
                        onPressed: () => _setItems([...items]..removeAt(i)),
                      ),
                      if (i > 0)
                        IconButton(
                          tooltip: tr(context, 'Move up', 'Subir'),
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          onPressed: () {
                            final next = [...items];
                            next.insert(i - 1, next.removeAt(i));
                            _setItems(next);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: YumeAction(
            label: tr(context, 'Add', 'Añadir'),
            icon: Icons.add,
            onPressed: () => add([
              {
                'id': yumeId(),
                if (schema.date && schema.newestFirst)
                  'date': DateTime.now().toIso8601String(),
              },
            ]),
          ),
        ),
        if (extra != null) extra!(add),
      ],
    );
  }
}

// ── Visual tools ────────────────────────────────────────────────────────

class _IntroCardEditor extends ConsumerWidget {
  const _IntroCardEditor({
    required this.data,
    required this.onChanged,
    required this.exportKey,
  });
  final Map<String, Object?> data;
  final ValueChanged<Map<String, Object?>> onChanged;
  final GlobalKey exportKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ships = ref.watch(yumeShipsProvider);
    final ship = ships.where((s) => s.id == data['shipId']).firstOrNull;
    final layout = '${data['layout'] ?? 'classic'}';
    final a = yumeAccent(
      context,
      (data['accent'] as num?)?.toInt() ?? ship?.accent,
    );
    final theme = Theme.of(context);
    final tagline = '${data['tagline'] ?? ''}';
    Widget card() {
      if (ship == null) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr(context, 'Choose a yumeship below.', 'Elige un yumeship abajo.'),
          ),
        );
      }
      final names = ship.fos
          .map((f) => f.name)
          .where((n) => n.isNotEmpty)
          .join(' & ');
      return YumeFontScope(
        font: ship.font,
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          child: YumeCard(
            accent: a,
            card: layout == 'ticket' ? 'outlined' : ship.card,
            frame: layout == 'polaroid'
                ? 'tape'
                : (layout == 'ticket' ? 'stamp' : ship.frame),
            ribbon: ship.ribbon,
            stickers: ship.stickers,
            radius: layout == 'polaroid' ? 6 : 20,
            padding: const EdgeInsets.all(18),
            child: layout == 'polaroid'
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: (ship.banner ?? ship.avatar) != null
                            ? YumeMediaImage(id: (ship.banner ?? ship.avatar)!)
                            : ColoredBox(
                                color: a.withValues(alpha: 0.15),
                                child: Center(
                                  child: Text(
                                    ship.symbol,
                                    style: const TextStyle(fontSize: 60),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        ship.name,
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      if (tagline.isNotEmpty)
                        Text(tagline, textAlign: TextAlign.center),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          YumePairAvatars(
                            left: ship.avatar,
                            right: ship.fos.firstOrNull?.avatar,
                            accent: a,
                            symbol: ship.symbol,
                            size: 56,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ship.name,
                                  style: theme.textTheme.titleLarge,
                                ),
                                if (ship.shipName.isNotEmpty)
                                  Text(
                                    '${ship.symbol} ${ship.shipName}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: a,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (tagline.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          '“$tagline”',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (names.isNotEmpty) Text('✦ $names'),
                      if (ship.sources.isNotEmpty)
                        Text('📚 ${ship.sources.join(' · ')}'),
                      if (ship.status.isNotEmpty)
                        Text('${ship.symbol} ${ship.status}'),
                      if (ship.anniversary != null)
                        Text('💍 ${yumeDate(ship.anniversary!)}'),
                      Text('🤝 ${yumeSharing[ship.sharing]!.$1}'),
                      if (ship.tropes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          ship.tropes.take(5).join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: RepaintBoundary(
            key: exportKey,
            child: SizedBox(width: 340, child: card()),
          ),
        ),
        const SizedBox(height: 16),
        PrismSelect<String>(
          labelText: tr(context, 'Yumeship', 'Yumeship'),
          value: ship?.id,
          items: [
            for (final s in ships) PrismSelectItem(value: s.id, label: s.name),
          ],
          onChanged: (v) => onChanged({...data, 'shipId': v}),
        ),
        const SizedBox(height: 8),
        PrismSegmentedControl<String>(
          segments: const [
            PrismSegment(value: 'classic', label: 'Classic'),
            PrismSegment(value: 'polaroid', label: 'Polaroid'),
            PrismSegment(value: 'ticket', label: 'Ticket'),
          ],
          selected: layout,
          onChanged: (v) => onChanged({...data, 'layout': v}),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          initialValue: tagline,
          labelText: tr(context, 'Tagline', 'Lema'),
          onChanged: (v) => onChanged({...data, 'tagline': v}),
        ),
        const SizedBox(height: 8),
        TrackerLabel(tr(context, 'Card colour', 'Color')),
        ColorChoiceRow(
          value: (data['accent'] as num?)?.toInt(),
          onChanged: (v) => onChanged({...data, 'accent': v}),
        ),
      ],
    );
  }
}

class _ChartEditor extends StatelessWidget {
  const _ChartEditor({
    required this.data,
    required this.onChanged,
    required this.exportKey,
  });
  final Map<String, Object?> data;
  final ValueChanged<Map<String, Object?>> onChanged;
  final GlobalKey exportKey;

  List<Map<String, Object?>> get _rows => [
    for (final x in (data['rows'] as List?) ?? const [])
      if (x is Map) x.cast<String, Object?>(),
  ];

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final theme = Theme.of(context);
    void set(List<Map<String, Object?>> v) => onChanged({...data, 'rows': v});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          key: exportKey,
          child: Material(
            color: theme.colorScheme.surface,
            child: YumeCard(
              card: 'paper',
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${rows[i]['label'] ?? ''}',
                            style: theme.textTheme.titleSmall,
                          ),
                          Row(
                            children: [
                              SizedBox(
                                width: 70,
                                child: Text(
                                  '${rows[i]['left'] ?? ''}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  value: ((rows[i]['value'] as num?) ?? 50)
                                      .toDouble()
                                      .clamp(0, 100),
                                  max: 100,
                                  onChanged: (v) => set(
                                    [...rows]
                                      ..[i] = {...rows[i], 'value': v.round()},
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  '${rows[i]['right'] ?? ''}',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Rows', 'Filas')),
        for (var i = 0; i < rows.length; i++)
          Padding(
            key: ValueKey('row$i${rows.length}'),
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PrismTextField(
                    initialValue: '${rows[i]['label'] ?? ''}',
                    labelText: tr(context, 'Label', 'Etiqueta'),
                    onChanged: (v) =>
                        set([...rows]..[i] = {...rows[i], 'label': v}),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: PrismTextField(
                    initialValue: '${rows[i]['left'] ?? ''}',
                    labelText: '←',
                    onChanged: (v) =>
                        set([...rows]..[i] = {...rows[i], 'left': v}),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: PrismTextField(
                    initialValue: '${rows[i]['right'] ?? ''}',
                    labelText: '→',
                    onChanged: (v) =>
                        set([...rows]..[i] = {...rows[i], 'right': v}),
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Remove', 'Quitar'),
                  icon: const Icon(Icons.close),
                  onPressed: () => set([...rows]..removeAt(i)),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 6,
          children: [
            PrismChip(
              label: tr(context, 'Add row', 'Añadir fila'),
              selected: false,
              avatar: const Icon(Icons.add, size: 18),
              onTap: () => set([
                ...rows,
                {'label': '', 'left': 'Me', 'right': 'Them', 'value': 50},
              ]),
            ),
            for (final t in yumeChartTemplates.entries)
              PrismChip(
                label: '+ ${t.key}',
                selected: false,
                onTap: () => set([
                  ...rows,
                  for (final (l, a, b) in t.value)
                    {'label': l, 'left': a, 'right': b, 'value': 50},
                ]),
              ),
          ],
        ),
      ],
    );
  }
}

class _BingoEditor extends StatelessWidget {
  const _BingoEditor({
    required this.data,
    required this.onChanged,
    required this.exportKey,
  });
  final Map<String, Object?> data;
  final ValueChanged<Map<String, Object?>> onChanged;
  final GlobalKey exportKey;

  @override
  Widget build(BuildContext context) {
    final n = ((data['size'] as num?)?.toInt() ?? 5).clamp(3, 5);
    final cells = [for (final c in (data['cells'] as List?) ?? const []) '$c'];
    while (cells.length < n * n) {
      cells.add('');
    }
    final marked = {
      for (final m in (data['marked'] as List?) ?? const []) (m as num).toInt(),
    };
    final free = data['free'] != false && n.isOdd;
    final center = (n * n) ~/ 2;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            context,
            'Tap a square to mark it; long-press to change its text.',
            'Toca para marcar; mantén pulsado para cambiar el texto.',
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Center(
          child: RepaintBoundary(
            key: exportKey,
            child: Material(
              color: cs.surface,
              child: SizedBox(
                width: math.min(MediaQuery.of(context).size.width - 32, 460),
                child: GridView.count(
                  crossAxisCount: n,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  children: [
                    for (var i = 0; i < n * n; i++)
                      Semantics(
                        button: true,
                        selected: marked.contains(i),
                        label: free && i == center ? 'Free' : cells[i],
                        child: InkWell(
                          onTap: free && i == center
                              ? null
                              : () {
                                  final next = {...marked};
                                  next.contains(i)
                                      ? next.remove(i)
                                      : next.add(i);
                                  onChanged({...data, 'marked': next.toList()});
                                },
                          onLongPress: () async {
                            final ctrl = TextEditingController(text: cells[i]);
                            final out = await PrismDialog.show<String>(
                              context: context,
                              title: tr(context, 'Square', 'Casilla'),
                              builder: (ctx) => Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  PrismTextField(
                                    controller: ctrl,
                                    autofocus: true,
                                  ),
                                  const SizedBox(height: 12),
                                  PrismButton(
                                    label: tr(ctx, 'Save', 'Guardar'),
                                    tone: PrismButtonTone.filled,
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(ctrl.text),
                                  ),
                                ],
                              ),
                            );
                            if (out != null)
                              onChanged({
                                ...data,
                                'cells': [...cells]..[i] = out,
                              });
                          },
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: marked.contains(i) || (free && i == center)
                                  ? cs.primary.withValues(alpha: 0.25)
                                  : cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              free && i == center ? '★ FREE' : cells[i],
                              textAlign: TextAlign.center,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrismSegmentedControl<int>(
          segments: const [
            PrismSegment(value: 3, label: '3×3'),
            PrismSegment(value: 4, label: '4×4'),
            PrismSegment(value: 5, label: '5×5'),
          ],
          selected: n,
          onChanged: (v) =>
              onChanged({...data, 'size': v, 'marked': const <int>[]}),
        ),
        PrismSwitchRow(
          padding: EdgeInsets.zero,
          title: tr(context, 'Free centre square', 'Casilla central libre'),
          value: data['free'] != false,
          onChanged: (v) => onChanged({...data, 'free': v}),
        ),
        Wrap(
          spacing: 6,
          children: [
            PrismChip(
              label: tr(context, 'Shuffle tropes', 'Mezclar tropos'),
              selected: false,
              avatar: const Icon(Icons.shuffle, size: 18),
              onTap: () => onChanged({
                ...data,
                'cells': (List.of(
                  yumeBingoSquares,
                )..shuffle(math.Random())).take(n * n).toList(),
                'marked': const <int>[],
              }),
            ),
            PrismChip(
              label: tr(context, 'Clear marks', 'Borrar marcas'),
              selected: false,
              avatar: const Icon(Icons.refresh, size: 18),
              onTap: () => onChanged({...data, 'marked': const <int>[]}),
            ),
          ],
        ),
      ],
    );
  }
}

class _MatchingEditor extends ConsumerWidget {
  const _MatchingEditor({
    required this.data,
    required this.onChanged,
    required this.exportKey,
  });
  final Map<String, Object?> data;
  final ValueChanged<Map<String, Object?>> onChanged;
  final GlobalKey exportKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frame = '${data['frame'] ?? 'circle'}';
    final color = Color(
      (data['color'] as num?)?.toInt() ??
          Theme.of(context).colorScheme.primary.toARGB32(),
    );
    final symbol = '${data['symbol'] ?? '💞'}';
    Widget icon(String? id, String side) {
      final shape = switch (frame) {
        'square' => RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        'heart' => const StarBorder(
          points: 8,
          innerRadiusRatio: 0.82,
          pointRounding: 0.9,
        ),
        _ => const CircleBorder(),
      };
      return Column(
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: ShapeDecoration(
              shape: shape.copyWith(side: BorderSide(color: color, width: 5)),
              color: color.withValues(alpha: 0.18),
            ),
            clipBehavior: Clip.antiAlias,
            child: id == null
                ? Center(
                    child: Text(symbol, style: const TextStyle(fontSize: 40)),
                  )
                : ClipPath(
                    clipper: ShapeBorderClipper(shape: shape),
                    child: YumeMediaImage(id: id),
                  ),
          ),
          YumeAction(
            label: id == null
                ? tr(context, 'Choose', 'Elegir')
                : tr(context, 'Replace', 'Cambiar'),
            onPressed: () async {
              final picked = await PrismMedia.pickImage(
                ref,
                spec: PrismCropSpec.avatar,
              );
              if (picked != null) onChanged({...data, side: picked});
            },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          key: exportKey,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon(data['left'] as String?, 'left'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(symbol, style: const TextStyle(fontSize: 26)),
                  ),
                  icon(data['right'] as String?, 'right'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrismSegmentedControl<String>(
          segments: const [
            PrismSegment(value: 'circle', label: 'Circle'),
            PrismSegment(value: 'square', label: 'Rounded'),
            PrismSegment(value: 'heart', label: 'Scalloped'),
          ],
          selected: frame,
          onChanged: (v) => onChanged({...data, 'frame': v}),
        ),
        const SizedBox(height: 8),
        TrackerLabel(tr(context, 'Frame colour', 'Color del marco')),
        ColorChoiceRow(
          value: color.toARGB32(),
          onChanged: (v) => onChanged({...data, 'color': v}),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final s in ['💞', '💕', '✨', '🌙', '⭐', '🎀', '🥀', '♡'])
              PrismChip(
                label: s,
                selected: symbol == s,
                onTap: () => onChanged({...data, 'symbol': s}),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            context,
            'Save the pair as one image from the top bar.',
            'Guarda la pareja como una imagen desde la barra superior.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _MoodboardEditor extends ConsumerWidget {
  const _MoodboardEditor({
    required this.data,
    required this.onChanged,
    required this.exportKey,
    required this.creation,
  });
  final Map<String, Object?> data;
  final ValueChanged<Map<String, Object?>> onChanged;
  final GlobalKey exportKey;
  final YumeCreation creation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = [
      for (final x in (data['images'] as List?) ?? const []) '$x',
    ];
    final words = [for (final x in (data['words'] as List?) ?? const []) '$x'];
    final colors = [
      for (final x in (data['colors'] as List?) ?? const []) (x as num).toInt(),
    ];
    final layout = '${data['layout'] ?? 'grid'}';
    final theme = Theme.of(context);
    final cols = layout == 'collage' ? 3 : (images.length <= 4 ? 2 : 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          key: exportKey,
          child: Material(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  if (images.isEmpty)
                    Container(
                      height: 160,
                      alignment: Alignment.center,
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: Text(
                        tr(
                          context,
                          'Add pictures below',
                          'Añade imágenes abajo',
                        ),
                      ),
                    )
                  else
                    GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: [
                        for (var i = 0; i < images.length; i++)
                          Transform.rotate(
                            angle:
                                layout == 'collage' &&
                                    !MediaQuery.of(context).disableAnimations
                                ? ((i % 3) - 1) * 0.05
                                : 0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                layout == 'collage' ? 2 : 10,
                              ),
                              child: YumeMediaImage(id: images[i]),
                            ),
                          ),
                      ],
                    ),
                  if (colors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final c in colors)
                          Expanded(
                            child: Container(height: 22, color: Color(c)),
                          ),
                      ],
                    ),
                  ],
                  if (words.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      words.join('  ·  '),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrismSegmentedControl<String>(
          segments: const [
            PrismSegment(value: 'grid', label: 'Grid'),
            PrismSegment(value: 'collage', label: 'Collage'),
          ],
          selected: layout,
          onChanged: (v) => onChanged({...data, 'layout': v}),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismChip(
              label: tr(context, 'Add pictures', 'Añadir imágenes'),
              selected: false,
              avatar: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              onTap: () async {
                final ids = await PrismMedia.pickImages(
                  ref,
                  spec: PrismCropSpec.square,
                );
                if (ids.isNotEmpty)
                  onChanged({
                    ...data,
                    'images': [...images, ...ids],
                  });
              },
            ),
            if (images.isNotEmpty)
              PrismChip(
                label: tr(context, 'Remove last', 'Quitar la última'),
                selected: false,
                avatar: const Icon(Icons.undo, size: 18),
                onTap: () => onChanged({
                  ...data,
                  'images': [...images]..removeLast(),
                }),
              ),
            PrismChip(
              label: tr(context, 'Continue in Scrapbook', 'Seguir en el álbum'),
              selected: false,
              avatar: const Icon(Icons.auto_stories_outlined, size: 18),
              onTap: () => _toScrapbook(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 8),
        YumeStringListField(
          label: tr(context, 'Words', 'Palabras'),
          values: words,
          onChanged: (v) => onChanged({...data, 'words': v}),
        ),
        const SizedBox(height: 8),
        TrackerLabel(tr(context, 'Palette', 'Paleta')),
        Wrap(
          spacing: 6,
          children: [
            for (final c in colors)
              PrismChip(
                label: '✕',
                selected: false,
                avatar: CircleAvatar(backgroundColor: Color(c)),
                onTap: () => onChanged({
                  ...data,
                  'colors': [...colors]..remove(c),
                }),
              ),
          ],
        ),
        ColorChoiceRow(
          value: null,
          onChanged: (v) => onChanged({
            ...data,
            'colors': [...colors, v],
          }),
        ),
      ],
    );
  }

  /// The full scrapbook editor (stickers, textures, frames, fonts...) for
  /// anything a quick moodboard can't do. The new book is linked back here.
  Future<void> _toScrapbook(BuildContext context, WidgetRef ref) async {
    final t = ref.read(trackerNotifierProvider.notifier);
    final ship = creation.shipIds.isEmpty
        ? null
        : ref.read(yumeShipByIdProvider(creation.shipIds.first));
    final book = await t.create(
      kind: TrackerKind.scrapBook,
      title: creation.title,
      isPrivate: creation.visibility != 'system',
      memberId: creation.owners.firstOrNull,
      fields: {
        'theme': 'classic',
        'font': 'serif',
        'pattern': 'paper',
        'emoji': '🧩',
        'color': ship?.accent,
        'contributors': creation.owners,
        if (ship != null) 'for': 'yumeship',
        if (ship != null) 'forRef': RecordRef(RecordRef.rec, ship.id).key,
      },
    );
    await ref
        .read(linkActionsProvider)
        .link(
          RecordRef(RecordRef.rec, book.id),
          RecordRef(RecordRef.rec, creation.id),
          category: 'partOf',
        );
    if (context.mounted) context.push(scrapBookPath(book.id));
  }
}
