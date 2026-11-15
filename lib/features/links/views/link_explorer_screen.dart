import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/features/links/views/record_opener.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/shared/graph/graph_canvas.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Visual explorer of every connection between records.
class LinkExplorerScreen extends ConsumerStatefulWidget {
  const LinkExplorerScreen({super.key});

  @override
  ConsumerState<LinkExplorerScreen> createState() => _LinkExplorerScreenState();
}

class _LinkExplorerScreenState extends ConsumerState<LinkExplorerScreen> {
  final _canvas = GlobalKey<GraphCanvasState>();
  final _q = TextEditingController();
  final Set<String> _modules = {};
  final Set<String> _cats = {};
  GraphLayout _layout = GraphLayout.force;
  bool _list = false;
  String? _selected;
  Map<String, Offset> _positions = {};
  String _layoutKey = '';

  @override
  void initState() {
    super.initState();
    // Tidy links whose records were deleted elsewhere.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) await ref.read(linkActionsProvider).removeBroken();
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final catalog = ref.watch(recordCatalogProvider);
    final links = ref.watch(recordLinksProvider);
    final cats = {for (final c in ref.watch(linkCategoriesProvider(lang))) c.id: c};
    final q = _q.text.trim().toLowerCase();
    final visible = <RecordLink>[];
    final nodeIds = <String>{};
    for (final l in links) {
      final a = catalog[l.a.key], b = catalog[l.b.key];
      if (a == null || b == null) continue;
      if (_cats.isNotEmpty && !_cats.contains(l.category)) continue;
      if (_modules.isNotEmpty && !_modules.contains(a.module) && !_modules.contains(b.module)) continue;
      visible.add(l);
      nodeIds..add(a.ref.key)..add(b.ref.key);
    }
    final match = q.isEmpty
        ? <String>{}
        : {for (final k in nodeIds) if (catalog[k]!.title.toLowerCase().contains(q)) k};
    final key = '${_layout.name}|${nodeIds.length}|${visible.length}';
    if (key != _layoutKey) {
      _layoutKey = key;
      final seed = [
        for (final k in nodeIds) GraphNode(id: k, label: '', position: GraphCanvas.worldCenter, color: Colors.grey),
      ];
      final edges = [for (final l in visible) GraphEdge(id: l.id, from: l.a.key, to: l.b.key, color: Colors.grey)];
      _positions = computeGraphLayout(_layout == GraphLayout.free ? GraphLayout.force : _layout, seed, edges);
      WidgetsBinding.instance.addPostFrameCallback((_) => _canvas.currentState?.fit());
    }
    final nodes = [
      for (final k in nodeIds)
        () {
          final i = catalog[k]!;
          final m = moduleFor(i.module);
          return GraphNode(
            id: k,
            label: i.isPrivate ? '🔒' : i.title,
            subtitle: shortDate(context, i.date),
            position: _positions[k] ?? GraphCanvas.worldCenter,
            color: m.color,
            icon: m.icon,
            size: i.module == 'member' ? 64 : 48,
            shape: i.module == 'member' ? GraphNodeShape.circle : GraphNodeShape.rounded,
          );
        }(),
    ];
    final edges = [
      for (final l in visible)
        GraphEdge(
          id: l.id,
          from: l.a.key,
          to: l.b.key,
          color: Color(cats[l.category]?.color ?? 0xFF8C8C8C).withValues(alpha: 0.8),
          label: cats[l.category]?.label,
        ),
    ];
    final selectedInfo = _selected == null ? null : catalog[_selected];
    final modulesPresent = {for (final k in nodeIds) catalog[k]!.module};
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Connections explorer', 'Explorador de conexiones'),
        showBackButton: true,
        actions: [FeatureDataAction(featureId: 'links'), 
          PrismTopBarAction(
            icon: _list ? PhosphorIcons.graph() : AppIcons.listView,
            tooltip: _list ? tr(context, 'Map view', 'Vista de mapa') : tr(context, 'List view', 'Vista de lista'),
            onPressed: () => setState(() => _list = !_list),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: PrismTextField(
              controller: _q,
              hintText: tr(context, 'Search connected records', 'Buscar registros conectados'),
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
                for (final m in recordModules)
                  if (modulesPresent.contains(m.key) || _modules.contains(m.key))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: m.label(context),
                        selected: _modules.contains(m.key),
                        selectedColor: m.color,
                        onTap: () => setState(() => _modules.contains(m.key) ? _modules.remove(m.key) : _modules.add(m.key)),
                      ),
                    ),
                for (final c in cats.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(
                      label: c.label,
                      variant: PrismChipVariant.inline,
                      selected: _cats.contains(c.id),
                      selectedColor: Color(c.color),
                      onTap: () => setState(() => _cats.contains(c.id) ? _cats.remove(c.id) : _cats.add(c.id)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? EmptyState(
                    icon: Icon(PhosphorIcons.graph()),
                    title: tr(context, 'No connections yet', 'Aún no hay conexiones'),
                    subtitle: tr(
                      context,
                      'Open any journal entry, dream, meal, event or alter and tap “Connect” to link records together.',
                      'Abre una entrada, sueño, comida, evento o alter y toca «Conectar» para enlazar registros.',
                    ),
                  )
                : _list
                ? _LinkList(links: visible, catalog: catalog, cats: cats, query: q)
                : Stack(
                    children: [
                      GraphCanvas(
                        key: _canvas,
                        nodes: nodes,
                        edges: edges,
                        selectedNodeId: _selected,
                        highlightIds: match.isNotEmpty
                            ? match
                            : _selected == null
                            ? const {}
                            : {
                                _selected!,
                                for (final l in visible)
                                  if (l.a.key == _selected) l.b.key else if (l.b.key == _selected) l.a.key,
                              },
                        onNodeTap: (id) => setState(() => _selected = _selected == id ? null : id),
                        onNodeMoved: (id, p) => setState(() => _positions[id] = p),
                        onBackgroundTap: (_) => setState(() => _selected = null),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _CanvasControls(
                          layout: _layout,
                          onLayout: (l) => setState(() => _layout = l),
                          onFit: () => _canvas.currentState?.fit(),
                          onZoom: (f) => _canvas.currentState?.zoom(f),
                        ),
                      ),
                      if (selectedInfo != null)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12 + NavBarInset.of(context),
                          child: PrismSurface(
                            tone: PrismSurfaceTone.strong,
                            onTap: () => openRecord(context, ref, selectedInfo),
                            child: Row(
                              children: [
                                Icon(moduleFor(selectedInfo.module).icon, color: moduleFor(selectedInfo.module).color),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(selectedInfo.isPrivate ? '🔒' : selectedInfo.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(
                                        tr(context, '${ref.read(linksForRecordProvider(selectedInfo.ref.key)).length} connections · tap to open',
                                            '${ref.read(linksForRecordProvider(selectedInfo.ref.key)).length} conexiones · toca para abrir'),
                                        style: Theme.of(context).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(AppIcons.chevronRight),
                              ],
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

class _CanvasControls extends StatelessWidget {
  const _CanvasControls({required this.layout, required this.onLayout, required this.onFit, required this.onZoom});
  final GraphLayout layout;
  final ValueChanged<GraphLayout> onLayout;
  final VoidCallback onFit;
  final ValueChanged<double> onZoom;

  @override
  Widget build(BuildContext context) => GraphControls(layout: layout, onLayout: onLayout, onFit: onFit, onZoom: onZoom);
}

/// Zoom / fit / layout buttons shared by the node maps.
class GraphControls extends StatelessWidget {
  const GraphControls({super.key, required this.layout, required this.onLayout, required this.onFit, required this.onZoom, this.includeFree = false});
  final GraphLayout layout;
  final ValueChanged<GraphLayout> onLayout;
  final VoidCallback onFit;
  final ValueChanged<double> onZoom;
  final bool includeFree;

  static String label(BuildContext context, GraphLayout l) => switch (l) {
    GraphLayout.free => tr(context, 'Freeform', 'Libre'),
    GraphLayout.circle => tr(context, 'Circle', 'Círculo'),
    GraphLayout.grid => tr(context, 'Grid', 'Cuadrícula'),
    GraphLayout.force => tr(context, 'Web', 'Red'),
    GraphLayout.tree => tr(context, 'Hierarchy', 'Jerarquía'),
  };

  @override
  Widget build(BuildContext context) {
    return PrismSurface(
      padding: const EdgeInsets.all(4),
      tone: PrismSurfaceTone.strong,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(tooltip: tr(context, 'Zoom in', 'Acercar'), icon: Icon(PhosphorIcons.magnifyingGlassPlus()), onPressed: () => onZoom(1.25)),
          IconButton(tooltip: tr(context, 'Zoom out', 'Alejar'), icon: Icon(PhosphorIcons.magnifyingGlassMinus()), onPressed: () => onZoom(0.8)),
          IconButton(tooltip: tr(context, 'Fit to screen', 'Ajustar'), icon: Icon(PhosphorIcons.cornersOut()), onPressed: onFit),
          PrismPopupMenu<GraphLayout>(
            tooltip: tr(context, 'Layout', 'Diseño'),
            icon: PhosphorIcons.shapes(),
            onSelected: onLayout,
            items: [
              for (final l in GraphLayout.values)
                if (includeFree || l != GraphLayout.free)
                  PrismMenuItem(value: l, label: label(context, l), icon: l == layout ? AppIcons.check : PhosphorIcons.circle()),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkList extends ConsumerWidget {
  const _LinkList({required this.links, required this.catalog, required this.cats, required this.query});
  final List<RecordLink> links;
  final Map<String, RecordInfo> catalog;
  final Map<String, LinkCategory> cats;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = [
      for (final l in links)
        if (query.isEmpty ||
            catalog[l.a.key]!.title.toLowerCase().contains(query) ||
            catalog[l.b.key]!.title.toLowerCase().contains(query))
          l,
    ];
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 16),
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final l = shown[i];
        final a = catalog[l.a.key]!, b = catalog[l.b.key]!;
        Widget end(RecordInfo x) => Expanded(
          child: InkWell(
            onTap: () => openRecord(context, ref, x),
            child: Row(
              children: [
                Icon(moduleFor(x.module).icon, size: 16, color: moduleFor(x.module).color),
                const SizedBox(width: 6),
                Expanded(child: Text(x.isPrivate ? '🔒' : x.title, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        );
        return PrismSurface(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [end(a), Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(PhosphorIcons.arrowsLeftRight(), size: 16)), end(b)]),
              const SizedBox(height: 4),
              Text(
                [cats[l.category]?.label ?? l.category, if (l.note != null) l.note!].join(' · '),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
