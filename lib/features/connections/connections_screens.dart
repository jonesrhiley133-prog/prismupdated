import 'package:go_router/go_router.dart';

import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/features/links/views/link_explorer_screen.dart'
    show GraphControls;
import 'package:prism_plurality/features/links/views/record_opener.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/graph/graph_canvas.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

String connMapPath(String id) => '/connections/map/$id';

void registerConnOpeners(
  Map<String, void Function(BuildContext, String)> openers,
) {
  openers[TrackerKind.connMap] = (c, id) => c.push(connMapPath(id));
  openers[TrackerKind.connNode] = (c, id) {
    final container = ProviderScope.containerOf(c, listen: false);
    final n =
        (container.read(trackerKindProvider(TrackerKind.connNode)).value ??
                const <TrackerRecord>[])
            .where((x) => x.id == id)
            .firstOrNull;
    if (n?.parentId != null) c.push('${connMapPath(n!.parentId!)}?node=$id');
  };
}

/// Built-in connection types.
const connTypes = [
  ('friends', 'Friends', 'Amistad', 0xFF3BA55C, false),
  ('protects', 'Protects', 'Protege', 0xFF5865F2, true),
  ('cares', 'Cares for', 'Cuida de', 0xFFEB459E, true),
  ('family', 'Family', 'Familia', 0xFFF1C40F, false),
  ('partners', 'Partners', 'Pareja', 0xFFE74C3C, false),
  ('mentor', 'Mentors', 'Guía', 0xFF1ABC9C, true),
  ('tension', 'Tension', 'Tensión', 0xFF95A5A6, false),
  ('memberOf', 'Part of', 'Parte de', 0xFF9B59B6, true),
  ('livesIn', 'Lives in / found at', 'Vive en / está en', 0xFF59A14F, true),
  ('path', 'Path between', 'Camino entre', 0xFF9C755F, false),
  ('related', 'Connected', 'Conectado', 0xFF8C8C8C, false),
];

const nodeKinds = [
  ('alter', 'Alter', 'Alter', 0xFF8E7CC3, 'users', GraphNodeShape.circle),
  (
    'subsystem',
    'Subsystem',
    'Subsistema',
    0xFF6C8EBF,
    'tree',
    GraphNodeShape.hexagon,
  ),
  ('group', 'Group', 'Grupo', 0xFF4FA3A5, 'users', GraphNodeShape.hexagon),
  ('location', 'Location', 'Lugar', 0xFF59A14F, 'pin', GraphNodeShape.rounded),
  (
    'custom',
    'Custom',
    'Personalizado',
    0xFFE6A23C,
    'star',
    GraphNodeShape.diamond,
  ),
];

final connMapsProvider = Provider<List<TrackerRecord>>(
  (ref) =>
      ref.watch(trackerKindProvider(TrackerKind.connMap)).value ?? const [],
);

final connNodesProvider = Provider.family<List<TrackerRecord>, String>(
  (ref, mapId) => [
    for (final n
        in ref.watch(trackerKindProvider(TrackerKind.connNode)).value ??
            const <TrackerRecord>[])
      if (n.parentId == mapId) n,
  ],
);

final connEdgesProvider = Provider.family<List<TrackerRecord>, String>(
  (ref, mapId) => [
    for (final e
        in ref.watch(trackerKindProvider(TrackerKind.connEdge)).value ??
            const <TrackerRecord>[])
      if (e.parentId == mapId) e,
  ],
);

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key, this.showBackButton = false});
  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maps = ref.watch(connMapsProvider);
    final nodes =
        ref.watch(trackerKindProvider(TrackerKind.connNode)).value ??
        const <TrackerRecord>[];
    final edges =
        ref.watch(trackerKindProvider(TrackerKind.connEdge)).value ??
        const <TrackerRecord>[];
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Internal Connections', 'Conexiones internas'),
        showBackButton: showBackButton || Navigator.of(context).canPop(),
        actions: [
          FeatureDataAction(featureId: 'connections'),
          PrismTopBarAction(
            icon: PhosphorIcons.graph(),
            tooltip: tr(
              context,
              'Record connections explorer',
              'Explorador de registros',
            ),
            onPressed: () => context.push('/links'),
          ),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: tr(context, 'New map', 'Nuevo mapa'),
            onPressed: () => _newMap(context, ref),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      body: maps.isEmpty
          ? EmptyState(
              icon: Icon(PhosphorIcons.graph()),
              title: tr(
                context,
                'Map your inner world',
                'Mapea tu mundo interior',
              ),
              subtitle: tr(
                context,
                'Create maps of how alters, subsystems and inner places relate. Make as many maps as you like — one for relationships, one for the headspace, one per subsystem.',
                'Crea mapas de cómo se relacionan alters, subsistemas y lugares internos. Haz tantos como quieras.',
              ),
              actionLabel: tr(context, 'Create a map', 'Crear un mapa'),
              onAction: () => _newMap(context, ref),
            )
          : ListView(
              padding: EdgeInsets.only(
                top: 8,
                bottom: NavBarInset.of(context) + 16,
              ),
              children: [
                for (final m in maps)
                  PrismSurface(
                    margin: const EdgeInsets.only(bottom: 10),
                    onTap: () => context.push(connMapPath(m.id)),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Color(
                              m.integer('color') ?? 0xFF8E7CC3,
                            ).withValues(alpha: 0.18),
                            borderRadius: prismCorners(context, 14),
                          ),
                          child: Icon(
                            PhosphorIcons.graph(),
                            color: Color(m.integer('color') ?? 0xFF8E7CC3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.title,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                tr(
                                  context,
                                  '${nodes.where((n) => n.parentId == m.id).length} nodes · ${edges.where((e) => e.parentId == m.id).length} connections',
                                  '${nodes.where((n) => n.parentId == m.id).length} nodos · ${edges.where((e) => e.parentId == m.id).length} conexiones',
                                ),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              if (m.body != null)
                                Text(
                                  m.body!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        Icon(AppIcons.chevronRight),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _newMap(BuildContext context, WidgetRef ref) async {
    final name = await promptText(
      context,
      tr(context, 'Map name', 'Nombre del mapa'),
      hint: tr(
        context,
        'e.g. Who protects who',
        'p. ej. Quién protege a quién',
      ),
    );
    if (name == null || name.isEmpty) return;
    final m = await ref
        .read(trackerNotifierProvider.notifier)
        .create(
          kind: TrackerKind.connMap,
          title: name,
          fields: {
            'color':
                colorChoices[ref.read(connMapsProvider).length %
                    colorChoices.length],
            'layout': 'free',
          },
        );
    if (context.mounted) await context.push(connMapPath(m.id));
  }
}

class ConnectionMapScreen extends ConsumerStatefulWidget {
  const ConnectionMapScreen({super.key, required this.mapId, this.focusNodeId});
  final String mapId;
  final String? focusNodeId;
  @override
  ConsumerState<ConnectionMapScreen> createState() =>
      _ConnectionMapScreenState();
}

class _ConnectionMapScreenState extends ConsumerState<ConnectionMapScreen> {
  final _canvas = GlobalKey<GraphCanvasState>();
  final _q = TextEditingController();
  late String? _selected = widget.focusNodeId;
  String? _connectFrom;
  final Set<String> _types = {};
  final Set<String> _kinds = {};

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String _lang() => Localizations.localeOf(context).languageCode;

  (String, String, String, int, bool)? _type(String? id) =>
      connTypes.where((t) => t.$1 == id).firstOrNull;
  (String, String, String, int, String, GraphNodeShape) _kind(String? id) =>
      nodeKinds.firstWhere((k) => k.$1 == id, orElse: () => nodeKinds.last);

  @override
  Widget build(BuildContext context) {
    final map = ref
        .watch(connMapsProvider)
        .where((m) => m.id == widget.mapId)
        .firstOrNull;
    if (map == null) {
      return PrismPageScaffold(
        topBar: PrismTopBar(
          title: tr(context, 'Map', 'Mapa'),
          showBackButton: true,
        ),
        body: Center(
          child: Text(
            tr(context, 'This map was deleted.', 'Este mapa fue eliminado.'),
          ),
        ),
      );
    }
    final nodes = ref.watch(connNodesProvider(widget.mapId));
    final edges = ref.watch(connEdgesProvider(widget.mapId));
    final catalog = ref.watch(recordCatalogProvider);
    final visibleNodes = [
      for (final n in nodes)
        if (_kinds.isEmpty || _kinds.contains(n.str('type') ?? 'custom')) n,
    ];
    final ids = {for (final n in visibleNodes) n.id};
    final visibleEdges = [
      for (final e in edges)
        if (ids.contains(e.str('from')) &&
            ids.contains(e.str('to')) &&
            (_types.isEmpty || _types.contains(e.str('ctype') ?? 'related')))
          e,
    ];
    final q = _q.text.trim().toLowerCase();
    final match = q.isEmpty
        ? <String>{}
        : {
            for (final n in visibleNodes)
              if (_label(n, catalog).toLowerCase().contains(q)) n.id,
          };
    final gNodes = [
      for (final n in visibleNodes)
        () {
          final k = _kind(n.str('type'));
          return GraphNode(
            id: n.id,
            label: _label(n, catalog),
            subtitle: n.str('subtitle'),
            position: Offset(
              n.number('x') ?? GraphCanvas.worldCenter.dx,
              n.number('y') ?? GraphCanvas.worldCenter.dy,
            ),
            color: Color(n.integer('color') ?? k.$4),
            icon: iconFor(n.str('icon') ?? k.$5),
            emoji: n.str('emoji'),
            size: (n.number('size') ?? 56).toDouble(),
            shape:
                GraphNodeShape.values
                    .where((s) => s.name == n.str('shape'))
                    .firstOrNull ??
                k.$6,
          );
        }(),
    ];
    final gEdges = [
      for (final e in visibleEdges)
        () {
          final t = _type(e.str('ctype'));
          return GraphEdge(
            id: e.id,
            from: e.str('from')!,
            to: e.str('to')!,
            color: Color(e.integer('color') ?? t?.$4 ?? 0xFF8C8C8C),
            label: e.title.isNotEmpty
                ? e.title
                : (t == null
                      ? e.str('ctype')
                      : (_lang() == 'es' ? t.$3 : t.$2)),
            width: (e.number('width') ?? 2.5).toDouble(),
            style:
                GraphEdgeStyle.values
                    .where((s) => s.name == e.str('style'))
                    .firstOrNull ??
                GraphEdgeStyle.solid,
            directed:
                e.fields['directed'] == true ||
                (e.fields['directed'] == null && (t?.$5 ?? false)),
          );
        }(),
    ];
    final sel = nodes.where((n) => n.id == _selected).firstOrNull;
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: map.title,
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: PhosphorIcons.gearSix(),
            tooltip: tr(context, 'Map settings', 'Ajustes del mapa'),
            onPressed: () => _mapSettings(map),
          ),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: tr(context, 'Add node', 'Añadir nodo'),
            onPressed: () => _addNode(map, nodes),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: PrismTextField(
              controller: _q,
              hintText: tr(context, 'Find on map', 'Buscar en el mapa'),
              prefixIcon: Icon(AppIcons.search),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final k in nodeKinds)
                  if (nodes.any((n) => (n.str('type') ?? 'custom') == k.$1))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: tr(context, k.$2, k.$3),
                        selected: _kinds.contains(k.$1),
                        selectedColor: Color(k.$4),
                        onTap: () => setState(
                          () => _kinds.contains(k.$1)
                              ? _kinds.remove(k.$1)
                              : _kinds.add(k.$1),
                        ),
                      ),
                    ),
                for (final t in {
                  for (final e in edges) e.str('ctype') ?? 'related',
                })
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(
                      label: _type(t) == null
                          ? t
                          : tr(context, _type(t)!.$2, _type(t)!.$3),
                      variant: PrismChipVariant.inline,
                      selected: _types.contains(t),
                      selectedColor: Color(_type(t)?.$4 ?? 0xFF8C8C8C),
                      onTap: () => setState(
                        () => _types.contains(t)
                            ? _types.remove(t)
                            : _types.add(t),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: nodes.isEmpty
                ? EmptyState(
                    icon: Icon(PhosphorIcons.circlesThreePlus()),
                    title: tr(context, 'Empty map', 'Mapa vacío'),
                    subtitle: tr(
                      context,
                      'Add alters, subsystems, places or anything else, then connect them.',
                      'Añade alters, subsistemas, lugares o lo que quieras y conéctalos.',
                    ),
                    actionLabel: tr(context, 'Add node', 'Añadir nodo'),
                    onAction: () => _addNode(map, nodes),
                  )
                : Stack(
                    children: [
                      GraphCanvas(
                        key: _canvas,
                        nodes: gNodes,
                        edges: gEdges,
                        selectedNodeId: _selected ?? _connectFrom,
                        showEdgeLabels: map.fields['labels'] != false,
                        background: map.integer('bg') == null
                            ? null
                            : Color(map.integer('bg')!),
                        highlightIds: match.isNotEmpty
                            ? match
                            : _selected == null
                            ? const {}
                            : {
                                _selected!,
                                for (final e in visibleEdges)
                                  if (e.str('from') == _selected)
                                    e.str('to')!
                                  else if (e.str('to') == _selected)
                                    e.str('from')!,
                              },
                        onNodeTap: (id) async {
                          if (_connectFrom != null) {
                            final from = _connectFrom!;
                            setState(() => _connectFrom = null);
                            if (from != id)
                              await _editEdge(map, from: from, to: id);
                            return;
                          }
                          setState(
                            () => _selected = _selected == id ? null : id,
                          );
                        },
                        onNodeMoved: (id, p) {
                          final n = nodes.where((x) => x.id == id).firstOrNull;
                          if (n != null)
                            ref
                                .read(trackerNotifierProvider.notifier)
                                .save(
                                  n.withFields({
                                    'x': p.dx.roundToDouble(),
                                    'y': p.dy.roundToDouble(),
                                  }),
                                );
                        },
                        onEdgeTap: (id) {
                          final e = edges.where((x) => x.id == id).firstOrNull;
                          if (e != null) _editEdge(map, editing: e);
                        },
                        onBackgroundTap: (_) => setState(() {
                          _selected = null;
                          _connectFrom = null;
                        }),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: GraphControls(
                          layout:
                              GraphLayout.values
                                  .where((l) => l.name == map.str('layout'))
                                  .firstOrNull ??
                              GraphLayout.free,
                          includeFree: true,
                          onFit: () => _canvas.currentState?.fit(),
                          onZoom: (f) => _canvas.currentState?.zoom(f),
                          onLayout: (l) =>
                              _applyLayout(map, l, nodes, gNodes, gEdges),
                        ),
                      ),
                      if (_connectFrom != null)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 80,
                          child: PrismSurface(
                            tone: PrismSurfaceTone.strong,
                            child: Text(
                              tr(
                                context,
                                'Tap another node to connect, or the background to cancel.',
                                'Toca otro nodo para conectar, o el fondo para cancelar.',
                              ),
                            ),
                          ),
                        ),
                      if (sel != null && _connectFrom == null)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12 + NavBarInset.of(context),
                          child: _nodePanel(map, sel, edges, catalog),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _label(TrackerRecord n, Map<String, RecordInfo> catalog) {
    if (n.title.isNotEmpty) return n.title;
    final r = n.str('ref');
    return r == null ? '?' : (catalog[r]?.title ?? '?');
  }

  Widget _nodePanel(
    TrackerRecord map,
    TrackerRecord n,
    List<TrackerRecord> edges,
    Map<String, RecordInfo> catalog,
  ) {
    final linked = n.str('ref') == null ? null : catalog[n.str('ref')];
    final count = edges
        .where((e) => e.str('from') == n.id || e.str('to') == n.id)
        .length;
    final k = _kind(n.str('type'));
    return PrismSurface(
      tone: PrismSurfaceTone.strong,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                iconFor(n.str('icon') ?? k.$5),
                color: Color(n.integer('color') ?? k.$4),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _label(n, catalog),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                tr(context, '$count links', '$count enlaces'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          if (n.body != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                n.body!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PrismButton(
                label: tr(context, 'Connect', 'Conectar'),
                icon: PhosphorIcons.lineSegment(),
                tone: PrismButtonTone.filled,
                onPressed: () => setState(() {
                  _connectFrom = n.id;
                  _selected = null;
                }),
              ),
              PrismButton(
                label: context.l10n.edit,
                icon: AppIcons.edit,
                onPressed: () => _editNode(map, n),
              ),
              if (linked != null)
                PrismButton(
                  label: tr(context, 'Open profile', 'Abrir'),
                  icon: AppIcons.chevronRight,
                  onPressed: () => openRecord(context, ref, linked),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _applyLayout(
    TrackerRecord map,
    GraphLayout l,
    List<TrackerRecord> nodes,
    List<GraphNode> gNodes,
    List<GraphEdge> gEdges,
  ) async {
    final t = ref.read(trackerNotifierProvider.notifier);
    await t.save(map.withFields({'layout': l.name}));
    if (l == GraphLayout.free) return;
    final pos = computeGraphLayout(l, gNodes, gEdges);
    for (final n in nodes) {
      final p = pos[n.id];
      if (p != null)
        await t.save(
          n.withFields({'x': p.dx.roundToDouble(), 'y': p.dy.roundToDouble()}),
        );
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _canvas.currentState?.fit(),
    );
  }

  Future<void> _addNode(TrackerRecord map, List<TrackerRecord> nodes) async {
    final catalog = ref.read(recordCatalogProvider);
    final used = {for (final n in nodes) ?n.str('ref')};
    final kind = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Add to map', 'Añadir al mapa'),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final k in nodeKinds)
            PrismListRow(
              leading: Icon(iconFor(k.$5), color: Color(k.$4)),
              title: Text(tr(ctx, k.$2, k.$3)),
              onTap: () => Navigator.of(ctx).pop(k.$1),
            ),
          PrismListRow(
            leading: Icon(PhosphorIcons.usersThree()),
            title: Text(
              tr(ctx, 'All alters at once', 'Todos los alters a la vez'),
            ),
            onTap: () => Navigator.of(ctx).pop('allAlters'),
          ),
        ],
      ),
    );
    if (kind == null || !mounted) return;
    final center =
        _canvas.currentState?.viewportCenterInWorld ?? GraphCanvas.worldCenter;
    final t = ref.read(trackerNotifierProvider.notifier);
    if (kind == 'allAlters') {
      var i = 0;
      for (final info in catalog.values.where(
        (x) => x.module == 'member' && !used.contains(x.ref.key),
      )) {
        await t.create(
          kind: TrackerKind.connNode,
          parentId: map.id,
          fields: {
            'type': 'alter',
            'ref': info.ref.key,
            'x': center.dx + (i % 6) * 140 - 350,
            'y': center.dy + (i ~/ 6) * 140,
          },
          sortOrder: i,
        );
        i++;
      }
      return;
    }
    String? refKey;
    String title = '';
    final module = switch (kind) {
      'alter' => 'member',
      'subsystem' => 'subsystem',
      'location' => 'location',
      _ => null,
    };
    if (module != null) {
      final options = [
        for (final i in catalog.values)
          if (i.module == module ||
              (kind == 'location' && i.kind == TrackerKind.headspaceArea))
            i,
      ];
      if (options.isNotEmpty) {
        refKey = await PrismSheet.show<String>(
          context: context,
          title: tr(context, 'Choose', 'Elegir'),
          builder: (ctx) => ListView(
            shrinkWrap: true,
            children: [
              PrismListRow(
                leading: Icon(AppIcons.edit),
                title: Text(
                  tr(
                    ctx,
                    'Not in Prism yet — type a name',
                    'Aún no está en Prism: escribe un nombre',
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(''),
              ),
              for (final o in options)
                PrismListRow(
                  title: Text(o.title),
                  subtitle: used.contains(o.ref.key)
                      ? Text(tr(ctx, 'already on this map', 'ya en este mapa'))
                      : null,
                  onTap: () => Navigator.of(ctx).pop(o.ref.key),
                ),
            ],
          ),
        );
        if (refKey == null) return;
        if (refKey.isEmpty) refKey = null;
      }
    }
    if (refKey == null && mounted) {
      final name = await promptText(context, tr(context, 'Name', 'Nombre'));
      if (name == null || name.isEmpty) return;
      title = name;
    }
    await t.create(
      kind: TrackerKind.connNode,
      parentId: map.id,
      title: title,
      fields: {
        'type': kind == 'group' ? 'group' : kind,
        'ref': refKey,
        'x': center.dx,
        'y': center.dy,
      },
    );
  }

  Future<void> _editNode(TrackerRecord map, TrackerRecord n) =>
      PrismSheet.showFullScreen(
        context: context,
        builder: (ctx, scroll) => _NodeEditor(node: n, scroll: scroll),
      );

  Future<void> _editEdge(
    TrackerRecord map, {
    TrackerRecord? editing,
    String? from,
    String? to,
  }) => PrismSheet.showFullScreen(
    context: context,
    builder: (ctx, scroll) => _EdgeEditor(
      mapId: map.id,
      editing: editing,
      from: from,
      to: to,
      scroll: scroll,
    ),
  );

  Future<void> _mapSettings(TrackerRecord map) async {
    final name = TextEditingController(text: map.title);
    final desc = TextEditingController(text: map.body);
    var labels = map.fields['labels'] != false;
    int? bg = map.integer('bg');
    await PrismSheet.show(
      context: context,
      title: tr(context, 'Map settings', 'Ajustes del mapa'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrismTextField(
                controller: name,
                labelText: tr(ctx, 'Name', 'Nombre'),
              ),
              const SizedBox(height: 8),
              PrismTextField(
                controller: desc,
                labelText: tr(ctx, 'Description', 'Descripción'),
                maxLines: 3,
                minLines: 1,
              ),
              PrismSwitchRow(
                title: tr(ctx, 'Show connection labels', 'Mostrar etiquetas'),
                value: labels,
                onChanged: (v) => set(() => labels = v),
              ),
              TrackerLabel(tr(ctx, 'Background', 'Fondo')),
              ColorChoiceRow(
                value: bg,
                colors: const [
                  0xFFFAF7F2,
                  0xFFEEF3FB,
                  0xFFF3FAF0,
                  0xFF1B1D2E,
                  0xFF10241C,
                  0xFF261A2E,
                ],
                onChanged: (c) => set(() => bg = c),
              ),
              const SizedBox(height: 16),
              PrismButton(
                label: ctx.l10n.save,
                tone: PrismButtonTone.filled,
                onPressed: () async {
                  await ref
                      .read(trackerNotifierProvider.notifier)
                      .save(
                        map
                            .copyWith(
                              title: name.text.trim().isEmpty
                                  ? map.title
                                  : name.text.trim(),
                              body: desc.text,
                            )
                            .withFields({'labels': labels, 'bg': bg}),
                      );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 8),
              RelatedRecordsSection(self: RecordRef(RecordRef.rec, map.id)),
              const SizedBox(height: 8),
              PrismButton(
                label: tr(ctx, 'Delete map', 'Eliminar mapa'),
                tone: PrismButtonTone.destructive,
                icon: AppIcons.delete,
                onPressed: () async {
                  final ok = await PrismDialog.confirm(
                    context: ctx,
                    title: tr(ctx, 'Delete this map?', '¿Eliminar este mapa?'),
                    message: tr(
                      ctx,
                      'Alters, places and other records stay; only this map goes.',
                      'Los alters, lugares y registros se mantienen; solo se elimina el mapa.',
                    ),
                    destructive: true,
                    confirmLabel: tr(ctx, 'Delete', 'Eliminar'),
                    cancelLabel: ctx.l10n.cancel,
                  );
                  if (!ok) return;
                  await ref
                      .read(trackerNotifierProvider.notifier)
                      .delete(map.id);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) context.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    desc.dispose();
  }
}

class _NodeEditor extends ConsumerStatefulWidget {
  const _NodeEditor({required this.node, required this.scroll});
  final TrackerRecord node;
  final ScrollController scroll;
  @override
  ConsumerState<_NodeEditor> createState() => _NodeEditorState();
}

class _NodeEditorState extends ConsumerState<_NodeEditor> {
  late final n = widget.node;
  late final _title = TextEditingController(text: n.title);
  late final _subtitle = TextEditingController(text: n.str('subtitle'));
  late final _desc = TextEditingController(text: n.body);
  late final _emoji = TextEditingController(text: n.str('emoji'));
  late int? _color = n.integer('color');
  late String? _icon = n.str('icon');
  late String _shape = n.str('shape') ?? '';
  late double _size = (n.number('size') ?? 56).toDouble();

  @override
  void dispose() {
    for (final c in [_title, _subtitle, _desc, _emoji]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linked = n.str('ref') == null
        ? null
        : ref.watch(recordCatalogProvider)[n.str('ref')];
    return TrackerEditorScaffold(
      title: tr(context, 'Node', 'Nodo'),
      canSave: true,
      scrollController: widget.scroll,
      onSave: () async {
        await ref
            .read(trackerNotifierProvider.notifier)
            .save(
              n.copyWith(title: _title.text, body: _desc.text).withFields({
                'subtitle': _subtitle.text.trim().isEmpty
                    ? null
                    : _subtitle.text.trim(),
                'emoji': _emoji.text.trim().isEmpty ? null : _emoji.text.trim(),
                'color': _color,
                'icon': _icon,
                'shape': _shape.isEmpty ? null : _shape,
                'size': _size,
              }),
            );
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        if (linked != null)
          Text(
            tr(
              context,
              'Linked to: ${linked.title}',
              'Vinculado a: ${linked.title}',
            ),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        PrismTextField(
          controller: _title,
          labelText: linked == null
              ? tr(context, 'Label', 'Etiqueta')
              : tr(
                  context,
                  'Label (leave empty to use the profile name)',
                  'Etiqueta (vacía = nombre del perfil)',
                ),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _subtitle,
          labelText: tr(context, 'Short subtitle', 'Subtítulo corto'),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _desc,
          labelText: tr(context, 'Description', 'Descripción'),
          maxLines: 4,
          minLines: 1,
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _emoji,
          labelText: tr(
            context,
            'Emoji instead of icon (optional)',
            'Emoji en lugar de icono (opcional)',
          ),
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Colour', 'Color')),
        ColorChoiceRow(
          value: _color,
          onChanged: (c) => setState(() => _color = c),
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Icon', 'Icono')),
        IconChoiceGrid(
          value: _icon,
          color: _color == null ? null : Color(_color!),
          onChanged: (k) => setState(() => _icon = k),
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Shape', 'Forma')),
        Wrap(
          spacing: 6,
          children: [
            for (final s in GraphNodeShape.values)
              PrismChip(
                label: s.name,
                selected: _shape == s.name,
                onTap: () => setState(() => _shape = s.name),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Size', 'Tamaño')),
        Slider(
          value: _size,
          min: 36,
          max: 110,
          onChanged: (v) => setState(() => _size = v),
        ),
        const SizedBox(height: 8),
        RelatedRecordsSection(self: RecordRef(RecordRef.rec, n.id)),
        const SizedBox(height: 12),
        PrismButton(
          label: tr(context, 'Remove from map', 'Quitar del mapa'),
          tone: PrismButtonTone.destructive,
          icon: AppIcons.delete,
          onPressed: () async {
            final t = ref.read(trackerNotifierProvider.notifier);
            for (final e in ref.read(connEdgesProvider(n.parentId ?? ''))) {
              if (e.str('from') == n.id || e.str('to') == n.id)
                await t.delete(e.id);
            }
            await t.delete(n.id);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class _EdgeEditor extends ConsumerStatefulWidget {
  const _EdgeEditor({
    required this.mapId,
    this.editing,
    this.from,
    this.to,
    required this.scroll,
  });
  final String mapId;
  final TrackerRecord? editing;
  final String? from;
  final String? to;
  final ScrollController scroll;
  @override
  ConsumerState<_EdgeEditor> createState() => _EdgeEditorState();
}

class _EdgeEditorState extends ConsumerState<_EdgeEditor> {
  late final e = widget.editing;
  late String _type = e?.str('ctype') ?? 'related';
  late final _label = TextEditingController(text: e?.title);
  late final _desc = TextEditingController(text: e?.body);
  late final _custom = TextEditingController(
    text: connTypes.any((t) => t.$1 == _type) ? '' : _type,
  );
  late int? _color = e?.integer('color');
  late String _style = e?.str('style') ?? 'solid';
  late bool? _directed = e?.fields['directed'] as bool?;
  late double _width = (e?.number('width') ?? 2.5).toDouble();

  @override
  void dispose() {
    _label.dispose();
    _desc.dispose();
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = {
      for (final n in ref.watch(connNodesProvider(widget.mapId))) n.id: n,
    };
    final catalog = ref.watch(recordCatalogProvider);
    String name(String? id) {
      final n = nodes[id];
      if (n == null) return '?';
      return n.title.isNotEmpty
          ? n.title
          : (catalog[n.str('ref')]?.title ?? '?');
    }

    final from = e?.str('from') ?? widget.from;
    final to = e?.str('to') ?? widget.to;
    final builtIn = connTypes.where((t) => t.$1 == _type).firstOrNull;
    return TrackerEditorScaffold(
      title: tr(context, 'Connection', 'Conexión'),
      canSave: from != null && to != null,
      scrollController: widget.scroll,
      onSave: () async {
        final type = _custom.text.trim().isNotEmpty
            ? _custom.text.trim()
            : _type;
        final fields = {
          'from': from,
          'to': to,
          'ctype': type,
          'color': _color,
          'style': _style,
          'directed': _directed,
          'width': _width,
        };
        final t = ref.read(trackerNotifierProvider.notifier);
        if (e != null) {
          await t.save(
            e!
                .copyWith(title: _label.text, body: _desc.text)
                .withFields(fields),
          );
        } else {
          await t.create(
            kind: TrackerKind.connEdge,
            parentId: widget.mapId,
            title: _label.text,
            body: _desc.text,
            fields: fields,
          );
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        Text(
          '${name(from)}  ⟷  ${name(to)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Type of connection', 'Tipo de conexión')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in connTypes)
              PrismChip(
                label: tr(context, t.$2, t.$3),
                selected: _type == t.$1 && _custom.text.isEmpty,
                selectedColor: Color(t.$4),
                onTap: () => setState(() {
                  _type = t.$1;
                  _custom.clear();
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _custom,
          labelText: tr(context, 'Or a custom type', 'O un tipo personalizado'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _label,
          labelText: tr(
            context,
            'Label on the line (optional)',
            'Etiqueta en la línea (opcional)',
          ),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _desc,
          labelText: tr(context, 'Description', 'Descripción'),
          maxLines: 4,
          minLines: 1,
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Line colour', 'Color de la línea')),
        ColorChoiceRow(
          value: _color ?? builtIn?.$4,
          onChanged: (c) => setState(() => _color = c),
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Line style', 'Estilo de línea')),
        Wrap(
          spacing: 6,
          children: [
            for (final s in GraphEdgeStyle.values)
              PrismChip(
                label: s.name,
                selected: _style == s.name,
                onTap: () => setState(() => _style = s.name),
              ),
          ],
        ),
        PrismSwitchRow(
          title: tr(
            context,
            'One-directional (arrow)',
            'En un sentido (flecha)',
          ),
          value: _directed ?? builtIn?.$5 ?? false,
          onChanged: (v) => setState(() => _directed = v),
        ),
        TrackerLabel(tr(context, 'Thickness', 'Grosor')),
        Slider(
          value: _width,
          min: 1,
          max: 8,
          onChanged: (v) => setState(() => _width = v),
        ),
        if (e != null) ...[
          const SizedBox(height: 12),
          PrismButton(
            label: tr(context, 'Remove connection', 'Quitar conexión'),
            tone: PrismButtonTone.destructive,
            icon: AppIcons.delete,
            onPressed: () async {
              await ref.read(trackerNotifierProvider.notifier).delete(e!.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}
