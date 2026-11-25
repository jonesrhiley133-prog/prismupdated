import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/relationships/hub/rel_editor.dart';
import 'package:prism_plurality/features/relationships/hub/rel_insights.dart';
import 'package:prism_plurality/features/relationships/hub/rel_layout.dart';
import 'package:prism_plurality/features/relationships/hub/rel_map.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';
import 'package:prism_plurality/features/relationships/hub/rel_profile.dart';
import 'package:prism_plurality/features/relationships/hub/rel_randomize_sheet.dart';
import 'package:prism_plurality/features/relationships/hub/rel_settings_sheet.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_expandable_section.dart';

enum _Below { directory, family, insights }

enum _Sort { recent, alpha, oldest, interactions }

/// Special statistic filters beyond plain categories.
const _complicatedFilter = '__complicated';
const _exploringFilter = '__exploring';

class RelationshipsHubScreen extends ConsumerStatefulWidget {
  const RelationshipsHubScreen({super.key});
  @override
  ConsumerState<RelationshipsHubScreen> createState() => _RelationshipsHubScreenState();
}

class _RelationshipsHubScreenState extends ConsumerState<RelationshipsHubScreen> {
  final _mapKey = GlobalKey<RelationshipMapState>();
  RelMapView? _view;
  String? _focus;
  final _hidden = <String>{};
  bool _listView = false;
  _Below _below = _Below.directory;
  String? _filter; // category or special filter from the stat cards
  String? _status;
  String _query = '';
  _Sort _sort = _Sort.recent;
  bool _grid = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openRel(Rel r) => context.push(relRoute(r.id));
  void _openAlter(String id) => context.push(AppRoutePaths.member(id));

  void _applyStatFilter(String? f, RelSettings s) {
    setState(() {
      _filter = _filter == f ? null : f;
      _hidden.clear();
      if (_filter != null && s.categories.contains(_filter)) {
        _hidden.addAll(s.categories.where((c) => c != _filter));
      }
      _below = _Below.directory;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(relSettingsProvider);
    final rels = ref.watch(relsProvider);
    final stats = RelStats(rels, settings);
    final view = _view ?? RelMapView.values.firstWhere((v) => v.name == settings.defaultLayout, orElse: () => RelMapView.network);
    final undo = ref.watch(relUndoProvider);

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Relationships', 'Relaciones'),
        actions: [FeatureDataAction(featureId: 'relationships'), PrismTopBarAction(icon: AppIcons.navSettings, tooltip: tr(context, 'Relationship settings', 'Ajustes de relaciones'), onPressed: () => showRelSettings(context))],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, NavBarInset.of(context) + 32),
        children: [
          ClampedBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A. Header
                Text(tr(context, 'Explore, understand, and organize the connections within your system.', 'Explora, comprende y organiza las conexiones dentro de tu sistema.'), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(
                  tr(
                    context,
                    '${stats.total} relationships · ${stats.alters} alters connected · ${stats.romantic} romantic · ${stats.familial} familial · ${stats.platonic} platonic',
                    '${stats.total} relaciones · ${stats.alters} alters conectados · ${stats.romantic} románticas · ${stats.familial} familiares · ${stats.platonic} platónicas',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrismButton(label: tr(context, 'Add relationship', 'Añadir relación'), icon: AppIcons.add, tone: PrismButtonTone.filled, onPressed: () => showRelEditor(context)),
                    PrismButton(label: tr(context, 'Randomize relationship', 'Relación aleatoria'), icon: PhosphorIcons.shuffle(), onPressed: () => showRandomizer(context)),
                  ],
                ),
                if (undo != null && DateTime.now().difference(undo.at).inMinutes < 2) ...[
                  const SizedBox(height: 12),
                  _UndoBar(undo: undo),
                ],
                // B. Statistics
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, box) {
                    final cols = box.maxWidth >= 900 ? 6 : (box.maxWidth >= 560 ? 3 : 2);
                    final w = (box.maxWidth - (cols - 1) * 8) / cols;
                    Widget card(String? f, String label, int n, IconData icon) => SizedBox(
                      width: w,
                      child: PrismSurface(
                        padding: const EdgeInsets.all(12),
                        onTap: () => _applyStatFilter(f, settings),
                        borderColor: _filter == f && f != null ? theme.colorScheme.primary : null,
                        semanticLabel: '$label: $n',
                        child: Row(
                          children: [
                            Icon(icon, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$n', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        card(null, tr(context, 'Documented relationships', 'Relaciones documentadas'), stats.total, PhosphorIcons.graph()),
                        card('romantic', tr(context, 'Romantic', 'Románticas'), stats.romantic, PhosphorIcons.heart()),
                        card('platonic', tr(context, 'Platonic', 'Platónicas'), stats.platonic, PhosphorIcons.handshake()),
                        card('familial', tr(context, 'Familial', 'Familiares'), stats.familial, PhosphorIcons.treeStructure()),
                        card(_complicatedFilter, tr(context, 'Complicated or uncertain', 'Complicadas o inciertas'), stats.complicated, PhosphorIcons.question()),
                        card(_exploringFilter, tr(context, 'Being explored', 'Explorándose'), stats.exploring, PhosphorIcons.compass()),
                      ],
                    );
                  },
                ),
                // C. Map
                const SizedBox(height: 20),
                Text(tr(context, 'Relationship map', 'Mapa de relaciones'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final v in RelMapView.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: PrismChip(
                            label: relViewLabel(context, v),
                            selected: view == v,
                            onTap: () async {
                              if (v == RelMapView.individual && _focus == null) {
                                final id = await pickAlter(context, ref, title: tr(context, 'Whose connections?', '¿Las conexiones de quién?'));
                                if (id == null) return;
                                setState(() => _focus = id);
                              }
                              setState(() => _view = v);
                            },
                          ),
                        ),
                      if (view == RelMapView.individual)
                        PrismButton(
                          label: tr(context, 'Change alter', 'Cambiar alter'),
                          density: PrismControlDensity.compact,
                          onPressed: () async {
                            final id = await pickAlter(context, ref);
                            if (id != null) setState(() => _focus = id);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: PrismTextField(
                        controller: _search,
                        hintText: tr(context, 'Find an alter on the map', 'Busca un alter en el mapa'),
                        prefixIcon: Icon(AppIcons.search),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (q) => _findOnMap(q),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PrismButton(label: _listView ? tr(context, 'Map', 'Mapa') : tr(context, 'List', 'Lista'), icon: _listView ? PhosphorIcons.graph() : PhosphorIcons.listBullets(), onPressed: () => setState(() => _listView = !_listView)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in settings.categories)
                      PrismChip(
                        label: '${_hidden.contains(c) ? '○' : '●'} ${relCategoryLabel(context, c, settings)}',
                        selected: !_hidden.contains(c),
                        onTap: () => setState(() => _hidden.contains(c) ? _hidden.remove(c) : _hidden.add(c)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_listView)
                  PrismSurface(padding: EdgeInsets.zero, child: RelationshipListView(view: view, focus: _focus, hiddenCategories: _hidden, onOpenRel: _openRel))
                else
                  RelationshipMap(
                    key: _mapKey,
                    view: view,
                    focus: _focus,
                    hiddenCategories: _hidden,
                    height: MediaQuery.sizeOf(context).width < 600 ? 420 : 520,
                    onOpenAlter: _openAlter,
                    onOpenRel: _openRel,
                    onFocus: (id) => setState(() {
                      _focus = id;
                      _view = RelMapView.individual;
                    }),
                  ),
                const SizedBox(height: 8),
                _Legend(settings: settings),
                const SizedBox(height: 4),
                Text(tr(context, 'Tap an alter to highlight their connections (tap again for their profile); tap a line for the relationship. Pinch or scroll to zoom, drag to pan.', 'Toca un alter para resaltar sus conexiones (otra vez para su perfil); toca una línea para ver la relación. Pellizca o desplaza para hacer zoom, arrastra para mover.'), style: theme.textTheme.bodySmall),
                // D. Directory / family / insights
                const SizedBox(height: 20),
                PrismSegmentedControl<_Below>(
                  segments: [
                    PrismSegment(value: _Below.directory, label: tr(context, 'Directory', 'Directorio')),
                    PrismSegment(value: _Below.family, label: tr(context, 'Family tree', 'Árbol familiar')),
                    PrismSegment(value: _Below.insights, label: tr(context, 'Insights', 'Perspectivas')),
                  ],
                  selected: _below,
                  onChanged: (v) => setState(() => _below = v),
                ),
                const SizedBox(height: 12),
                switch (_below) {
                  _Below.directory => _directory(context, rels, settings),
                  _Below.family => const _FamilyTree(),
                  _Below.insights => const _Insights(),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _findOnMap(String q) {
    final prefer = ref.read(memberNamePreferDisplayProvider);
    final m = ref.read(relAltersProvider).where((m) => m.effectiveName(preferDisplayName: prefer).toLowerCase().contains(q.trim().toLowerCase())).firstOrNull;
    if (m == null || q.trim().isEmpty) {
      PrismToast.show(context, message: tr(context, 'No alter found', 'No se encontró el alter'));
      return;
    }
    if (_listView) setState(() => _listView = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _mapKey.currentState?.focusOn(m.id));
  }

  Widget _directory(BuildContext context, List<Rel> rels, RelSettings settings) {
    final alters = ref.watch(relAlterIndexProvider);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final counts = ref.watch(relInteractionCountsProvider);
    String nm(String? id) => alters[id]?.effectiveName(preferDisplayName: prefer) ?? '';
    final q = _query.trim().toLowerCase();
    var list = [
      for (final r in rels)
        if ((_filter == null ||
                (_filter == _complicatedFilter && isComplicated(r)) ||
                (_filter == _exploringFilter && isExploring(r)) ||
                relCategoriesOf(r, settings).contains(_filter)) &&
            (_status == null || r.status == _status) &&
            (!settings.hidePrivate || !r.private) &&
            (q.isEmpty ||
                nm(r.a).toLowerCase().contains(q) ||
                nm(r.b).toLowerCase().contains(q) ||
                (r.otherName ?? '').toLowerCase().contains(q) ||
                r.title.toLowerCase().contains(q) ||
                r.labels.any((l) => labelText(context, l, settings).toLowerCase().contains(q))))
          r,
    ];
    String key(Rel r) => r.title.isNotEmpty ? r.title.toLowerCase() : '${nm(r.a)} ${nm(r.b).isEmpty ? r.otherName ?? '' : nm(r.b)}'.toLowerCase();
    list = switch (_sort) {
      _Sort.recent => list..sort((a, b) => b.updated.compareTo(a.updated)),
      _Sort.alpha => list..sort((a, b) => key(a).compareTo(key(b))),
      _Sort.oldest => list..sort((a, b) => a.documented.compareTo(b.documented)),
      _Sort.interactions => list..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0)),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismTextField(hintText: tr(context, 'Search by alter, label or title', 'Busca por alter, etiqueta o título'), prefixIcon: Icon(AppIcons.search), onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PrismChip(label: tr(context, 'All', 'Todas'), selected: _filter == null, onTap: () => setState(() => _filter = null)),
            for (final c in settings.categories) PrismChip(label: relCategoryLabel(context, c, settings), selected: _filter == c, onTap: () => setState(() => _filter = _filter == c ? null : c)),
            if (_filter == _complicatedFilter) PrismChip(label: tr(context, 'Complicated', 'Complicadas'), selected: true, onTap: () => setState(() => _filter = null)),
            if (_filter == _exploringFilter) PrismChip(label: tr(context, 'Being explored', 'Explorándose'), selected: true, onTap: () => setState(() => _filter = null)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PrismSelect<String?>(
                value: _status,
                items: [PrismSelectItem(value: null, label: tr(context, 'Any status', 'Cualquier estado')), for (final s in relStatuses) PrismSelectItem(value: s, label: relStatusText(context, s))],
                onChanged: (v) => setState(() => _status = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PrismSelect<_Sort>(
                value: _sort,
                items: [
                  PrismSelectItem(value: _Sort.recent, label: tr(context, 'Recently updated', 'Actualizadas recientemente')),
                  PrismSelectItem(value: _Sort.alpha, label: tr(context, 'Alphabetical', 'Alfabético')),
                  PrismSelectItem(value: _Sort.oldest, label: tr(context, 'Oldest first', 'Más antiguas')),
                  PrismSelectItem(value: _Sort.interactions, label: tr(context, 'Most documented', 'Más documentadas')),
                ],
                onChanged: (v) => setState(() => _sort = v ?? _Sort.recent),
              ),
            ),
            PrismTopBarAction(icon: _grid ? PhosphorIcons.rows() : PhosphorIcons.squaresFour(), tooltip: _grid ? tr(context, 'List layout', 'Vista de lista') : tr(context, 'Grid layout', 'Vista de cuadrícula'), onPressed: () => setState(() => _grid = !_grid)),
          ],
        ),
        const SizedBox(height: 10),
        if (rels.isEmpty)
          EmptyState(
            icon: Icon(PhosphorIcons.graph()),
            title: tr(context, 'No relationships yet', 'Aún no hay relaciones'),
            subtitle: tr(context, 'Document how your alters connect — friendships, family, romance and more. Labels can be combined, and nothing is ever assumed for you.', 'Documenta cómo se conectan tus alters: amistades, familia, romance y más. Las etiquetas se pueden combinar y nunca se asume nada por ti.'),
            actionLabel: tr(context, 'Add your first relationship', 'Añade tu primera relación'),
            onAction: () => showRelEditor(context),
          )
        else if (list.isEmpty)
          Padding(padding: const EdgeInsets.all(24), child: Text(tr(context, 'Nothing matches these filters.', 'Nada coincide con estos filtros.'), textAlign: TextAlign.center))
        else
          LayoutBuilder(
            builder: (context, box) {
              final cols = _grid ? (box.maxWidth >= 900 ? 3 : (box.maxWidth >= 520 ? 2 : 1)) : 1;
              final w = (box.maxWidth - (cols - 1) * 8) / cols;
              return Wrap(spacing: 8, runSpacing: 8, children: [for (final r in list) SizedBox(width: w, child: RelCard(rel: r, interactions: counts[r.id] ?? 0, onTap: () => _openRel(r)))]);
            },
          ),
      ],
    );
  }
}

class _UndoBar extends ConsumerWidget {
  const _UndoBar({required this.undo});
  final RelUndo undo;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: prismCorners(context, 12)),
      child: Row(
        children: [
          Expanded(child: Text(tr(context, 'Relationship deleted.', 'Relación eliminada.'), style: TextStyle(color: theme.colorScheme.onSecondaryContainer))),
          PrismButton(
            label: tr(context, 'Undo', 'Deshacer'),
            density: PrismControlDensity.compact,
            onPressed: () async {
              await ref.read(relActionsProvider).restore(undo.records);
              ref.read(relUndoProvider.notifier).set(null);
            },
          ),
          PrismTopBarAction(icon: AppIcons.close, tooltip: tr(context, 'Dismiss', 'Descartar'), onPressed: () => ref.read(relUndoProvider.notifier).set(null)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.settings});
  final RelSettings settings;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final s in relStyles)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(size: const Size(22, 8), painter: _LegendLine(relColor(settings, s), relDash(s, 'confirmed'))),
              const SizedBox(width: 4),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(relStyleText(context, s), style: theme.textTheme.labelSmall)),
            ],
          ),
        Row(mainAxisSize: MainAxisSize.min, children: [CustomPaint(size: const Size(22, 8), painter: _LegendLine(theme.colorScheme.onSurfaceVariant, const [3, 4])), const SizedBox(width: 4), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(tr(context, 'Suspected / uncertain', 'Sospechada / incierta'), style: theme.textTheme.labelSmall))]),
        Row(mainAxisSize: MainAxisSize.min, children: [Text('→', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(width: 4), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(tr(context, 'Arrow shows direction (parent → child)', 'La flecha indica dirección (madre/padre → hijo)'), style: theme.textTheme.labelSmall))]),
      ],
    );
  }
}

class _LegendLine extends CustomPainter {
  _LegendLine(this.color, this.dash);
  final Color color;
  final List<double>? dash;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (dash == null) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      return;
    }
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final seg = dash![i % dash!.length];
      if (i.isEven) canvas.drawLine(Offset(x, y), Offset((x + seg).clamp(0, size.width), y), p);
      x += seg;
      i++;
    }
  }

  @override
  bool shouldRepaint(_LegendLine o) => o.color != color;
}

/// A relationship in the directory or on an alter's profile.
class RelCard extends ConsumerWidget {
  const RelCard({super.key, required this.rel, this.interactions = 0, this.onTap, this.viewer});
  final Rel rel;
  final int interactions;
  final VoidCallback? onTap;

  /// When shown on an alter's profile: labels read from their side.
  final String? viewer;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(relSettingsProvider);
    final alters = ref.watch(relAlterIndexProvider);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final df = DateFormat.yMMMd(context.dateLocale);
    final a = alters[rel.a], b = alters[rel.b];
    final labels = viewer == null ? rel.labels : rel.labelsFor(viewer!);
    final cats = relCategoriesOf(rel, settings);
    String n(Member? m, String? fb) => m?.effectiveName(preferDisplayName: prefer) ?? fb ?? '—';
    return PrismSurface(
      onTap: onTap,
      semanticLabel: '${n(a, null)} and ${n(b, rel.otherName)}: ${labels.map((l) => labelText(context, l, settings)).join(', ')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 36,
                child: Stack(
                  children: [
                    if (a != null) Positioned(left: 0, child: relAvatar(ref, a, 34)),
                    Positioned(left: 20, child: b != null ? relAvatar(ref, b, 34) : PrismCircleAvatar(radius: 17, child: Icon(PhosphorIcons.user(), size: 16))),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(viewer != null ? n(viewer == rel.a ? b : a, rel.otherName) : (rel.title.isNotEmpty ? rel.title : '${n(a, null)} & ${n(b, rel.otherName)}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(labels.map((l) => labelText(context, l, settings)).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (rel.private) Icon(PhosphorIcons.lockSimple(), size: 15, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(cats.map((c) => relCategoryLabel(context, c, settings)).join(', '), style: theme.textTheme.labelSmall),
              Text(relStatusText(context, rel.status), style: theme.textTheme.labelSmall),
              if (rel.confidence != 'confirmed') Text(relConfidenceText(context, rel.confidence), style: theme.textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic)),
              Text(tr(context, 'Updated ${df.format(rel.updated)}', 'Actualizada ${df.format(rel.updated)}'), style: theme.textTheme.labelSmall),
              if (interactions > 0) Text(tr(context, '$interactions entries', '$interactions entradas'), style: theme.textTheme.labelSmall),
            ],
          ),
          if (rel.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(rel.private ? tr(context, 'Private description', 'Descripción privada') : rel.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: rel.private ? FontStyle.italic : null)),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Family tree ─────────────────────────

class _FamilyTree extends ConsumerWidget {
  const _FamilyTree();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(relSettingsProvider);
    final alters = ref.watch(relAlterIndexProvider);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final fam = [for (final r in ref.watch(relsProvider)) if (r.internal && alters.containsKey(r.a) && alters.containsKey(r.b) && r.labels.any((l) => categoryOf(l, settings) == 'familial')) r];
    final notes = ref.watch(trackerKindProvider(TrackerKind.relationshipFamilyNote)).value ?? const <TrackerRecord>[];

    // Family groups = connected parts of the family graph.
    final adj = <String, Set<String>>{};
    for (final r in fam) {
      (adj[r.a!] ??= {}).add(r.b!);
      (adj[r.b!] ??= {}).add(r.a!);
    }
    final seen = <String>{};
    final groups = <List<String>>[];
    for (final s in adj.keys) {
      if (!seen.add(s)) continue;
      final g = [s];
      for (var i = 0; i < g.length; i++) {
        for (final u in adj[g[i]]!) {
          if (seen.add(u)) g.add(u);
        }
      }
      groups.add(g);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(tr(context, 'Family groups are built from familial labels. Alters can belong to more than one family.', 'Los grupos familiares se forman con etiquetas familiares. Un alter puede estar en varias familias.'), style: theme.textTheme.bodySmall)),
            PrismButton(label: tr(context, 'Add family connection', 'Añadir conexión familiar'), icon: AppIcons.add, tone: PrismButtonTone.filled, density: PrismControlDensity.compact, onPressed: () => showRelEditor(context, category: 'familial')),
          ],
        ),
        const SizedBox(height: 10),
        if (groups.isEmpty)
          Padding(padding: const EdgeInsets.all(24), child: Text(tr(context, 'No family connections yet. Add parents, siblings, cousins, guardians or your own family roles.', 'Aún no hay conexiones familiares. Añade madres/padres, hermanos, primos, tutores o tus propios roles.'), textAlign: TextAlign.center)),
        for (final (gi, g) in groups.indexed) ...[
          _FamilyGroup(index: gi, members: g, rels: [for (final r in fam) if (g.contains(r.a)) r], notes: [for (final n in notes) if (n.strings('members').any(g.contains)) n], alters: alters, settings: settings, prefer: prefer),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FamilyGroup extends ConsumerWidget {
  const _FamilyGroup({required this.index, required this.members, required this.rels, required this.notes, required this.alters, required this.settings, required this.prefer});
  final int index;
  final List<String> members;
  final List<Rel> rels;
  final List<TrackerRecord> notes;
  final Map<String, Member> alters;
  final RelSettings settings;
  final bool prefer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    String nm(String? id) => alters[id]?.effectiveName(preferDisplayName: prefer) ?? '—';
    // Generations from parent-like labels.
    final edges = <(String, String, int)>[];
    for (final r in rels) {
      final l = r.labels.firstWhere((x) => categoryOf(x, settings) == 'familial');
      final gen = const {'parent': 1, 'guardian': 1, 'grandparent': 2, 'aunt_uncle': 1, 'child': -1, 'ward': -1, 'grandchild': -2, 'niece_nephew': -1}[l] ?? 0;
      edges.add(gen >= 0 ? (r.a!, r.b!, gen) : (r.b!, r.a!, -gen));
    }
    final layout = familyLayout(members, edges);
    final rows = <double, List<String>>{};
    for (final m in members) {
      (rows[layout.positions[m]!.dy] ??= []).add(m);
    }
    final ys = rows.keys.toList()..sort();
    for (final y in ys) {
      rows[y]!.sort((a, b) => layout.positions[a]!.dx.compareTo(layout.positions[b]!.dx));
    }
    final title = members.length <= 3 ? members.map(nm).join(', ') : '${members.take(2).map(nm).join(', ')} +${members.length - 2}';
    return PrismExpandableSection(
      initiallyExpanded: index == 0,
      leading: Icon(PhosphorIcons.treeStructure(), color: theme.colorScheme.primary),
      title: Text(tr(context, 'Family: $title', 'Familia: $title'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(tr(context, '${members.length} alters · ${rels.length} connections', '${members.length} alters · ${rels.length} conexiones')),
      children: [
        for (final (i, y) in ys.indexed)
          Column(
            children: [
              if (i > 0) Icon(PhosphorIcons.caretDown(), size: 14, color: theme.colorScheme.onSurfaceVariant),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in rows[y]!)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: GestureDetector(
                          onTap: () => context.push(AppRoutePaths.member(m)),
                          child: SizedBox(
                            width: 76,
                            child: Column(
                              children: [
                                if (alters[m] != null) relAvatar(ref, alters[m]!, 42),
                                const SizedBox(height: 4),
                                Text(nm(m), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        const Divider(),
        for (final r in rels)
          PrismListRow(
            dense: true,
            title: Text('${nm(r.a)} → ${nm(r.b)}'),
            subtitle: Text(r.labels.where((l) => categoryOf(l, settings) == 'familial').map((l) => '${nm(r.a)} ${tr(context, 'is', 'es')} ${labelText(context, l, settings).toLowerCase()}').join(', ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrismTopBarAction(icon: AppIcons.editOutlined, tooltip: tr(context, 'Edit connection', 'Editar conexión'), onPressed: () => showRelEditor(context, editing: r)),
                PrismTopBarAction(icon: AppIcons.deleteOutline, tooltip: tr(context, 'Remove connection', 'Quitar conexión'), onPressed: () => confirmDeleteRel(context, ref, r)),
              ],
            ),
            onTap: () => context.push(relRoute(r.id)),
          ),
        const Divider(),
        Row(
          children: [
            Expanded(child: Text(tr(context, 'Family notes', 'Notas familiares'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            PrismButton(label: tr(context, 'Add note', 'Añadir nota'), icon: AppIcons.add, density: PrismControlDensity.compact, onPressed: () => _editFamilyNote(context, ref, members, null)),
          ],
        ),
        for (final n in notes)
          PrismListRow(
            dense: true,
            title: Text(n.title.isEmpty ? tr(context, 'Note', 'Nota') : n.title),
            subtitle: (n.body ?? '').isEmpty ? null : Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
            showChevron: true,
            onTap: () => _editFamilyNote(context, ref, members, n),
          ),
      ],
    );
  }
}

Future<void> _editFamilyNote(BuildContext context, WidgetRef ref, List<String> members, TrackerRecord? n) async {
  final title = TextEditingController(text: n?.title);
  final body = TextEditingController(text: n?.body);
  await PrismSheet.show(
    context: context,
    title: tr(context, 'Family note', 'Nota familiar'),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(controller: title, labelText: tr(ctx, 'Title', 'Título')),
          const SizedBox(height: 10),
          PrismTextField(controller: body, labelText: tr(ctx, 'Note', 'Nota'), minLines: 3, maxLines: 10),
          const SizedBox(height: 12),
          Row(
            children: [
              if (n != null)
                PrismButton(
                  label: tr(ctx, 'Delete', 'Eliminar'),
                  tone: PrismButtonTone.destructive,
                  onPressed: () async {
                    await ref.read(trackerNotifierProvider.notifier).delete(n.id);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              const Spacer(),
              PrismButton(
                label: ctx.l10n.save,
                tone: PrismButtonTone.filled,
                onPressed: () async {
                  if (title.text.trim().isEmpty && body.text.trim().isEmpty) return;
                  final t = ref.read(trackerNotifierProvider.notifier);
                  if (n == null) {
                    await t.create(kind: TrackerKind.relationshipFamilyNote, title: title.text.trim(), body: body.text.trim(), occurredAt: DateTime.now(), fields: {'members': members});
                  } else {
                    await t.save(n.copyWith(title: title.text.trim(), body: body.text.trim()).withFields({'members': members}));
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────── Insights ─────────────────────────

class _Insights extends ConsumerWidget {
  const _Insights();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(relSettingsProvider);
    if (!settings.insightsEnabled) {
      return PrismSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(context, 'Insights are turned off.', 'Las perspectivas están desactivadas.')),
            const SizedBox(height: 8),
            PrismButton(label: tr(context, 'Turn on', 'Activar'), onPressed: () => ref.read(relActionsProvider).saveSettings({'insights': true})),
          ],
        ),
      );
    }
    final alters = ref.watch(relAlterIndexProvider);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final rels = ref.watch(relsProvider);
    final insights = computeInsights(
      rels: rels,
      names: {for (final m in alters.values) m.id: m.effectiveName(preferDisplayName: prefer)},
      events: ref.watch(trackerKindProvider(TrackerKind.relationshipEvent)).value ?? const [],
      checkins: ref.watch(trackerKindProvider(TrackerKind.relationshipCheckin)).value ?? const [],
      notes: ref.watch(trackerKindProvider(TrackerKind.relationshipNote)).value ?? const [],
      settings: settings,
      now: DateTime.now(),
    );
    final byId = {for (final r in rels) r.id: r};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            context,
            'Patterns found in what you have documented — counts, check-in ratings, timeline events and update dates. They are computed on this device from your records (no AI service is used), never diagnose anyone, and each one lists the relationships it comes from.',
            'Patrones encontrados en lo que has documentado: recuentos, puntuaciones de registros, eventos y fechas. Se calculan en este dispositivo a partir de tus registros (sin servicios de IA), nunca diagnostican a nadie y cada uno indica de qué relaciones procede.',
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        if (insights.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(tr(context, 'Add relationships, timeline events or check-ins to see patterns here.', 'Añade relaciones, eventos o registros para ver patrones aquí.'), textAlign: TextAlign.center)),
        for (final i in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PrismExpandableSection(
              leading: Icon(switch (i.kind) { 'improving' => PhosphorIcons.trendUp(), 'declining' => PhosphorIcons.trendDown(), 'stale' => PhosphorIcons.clock(), 'conflicts' => PhosphorIcons.lightning(), _ => PhosphorIcons.lightbulb() }, color: theme.colorScheme.primary),
              title: Text(tr(context, i.title.$1, i.title.$2), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(tr(context, i.body.$1, i.body.$2)),
              children: [
                Text(tr(context, 'Based on:', 'Basado en:'), style: theme.textTheme.labelMedium),
                for (final id in i.sources.take(8))
                  if (byId[id] case final r?) RelCard(rel: r, onTap: () => context.push(relRoute(r.id))),
              ],
            ),
          ),
      ],
    );
  }
}
