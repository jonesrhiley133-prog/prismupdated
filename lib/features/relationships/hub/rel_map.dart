import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/studio/profile_config.dart';
import 'package:prism_plurality/features/relationships/hub/rel_layout.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

enum RelMapView { network, family, romantic, social, individual }

String relViewLabel(BuildContext c, RelMapView v) => switch (v) {
  RelMapView.network => tr(c, 'Network', 'Red'),
  RelMapView.family => tr(c, 'Family', 'Familia'),
  RelMapView.romantic => tr(c, 'Romantic', 'Romántica'),
  RelMapView.social => tr(c, 'Social', 'Social'),
  RelMapView.individual => tr(c, 'Individual', 'Individual'),
};

/// One drawn connection between two alters (all their labels together).
class MapEdge {
  MapEdge(this.rel, this.a, this.b, this.styles, this.directional);
  final Rel rel;
  final String a;
  final String b;
  final List<String> styles;

  /// Whether the first label points from [a] to [b] (parent → child etc.).
  final bool directional;
}

const _directionalStyles = {'parent', 'mentor', 'protective'};

/// Edges for a view (pure, so it can be tested).
List<MapEdge> mapEdges({
  required List<Rel> rels,
  required Set<String> alterIds,
  required RelSettings settings,
  required RelMapView view,
  String? focus,
  Set<String> hiddenCategories = const {},
  bool hidePrivate = false,
}) {
  final out = <MapEdge>[];
  for (final r in rels) {
    final a = r.a, b = r.b;
    if (a == null ||
        b == null ||
        !alterIds.contains(a) ||
        !alterIds.contains(b))
      continue;
    if (hidePrivate && r.private) continue;
    var labels = [
      for (final l in r.labels)
        if (!hiddenCategories.contains(categoryOf(l, settings))) l,
    ];
    labels = switch (view) {
      RelMapView.family => [
        for (final l in labels)
          if (categoryOf(l, settings) == 'familial') l,
      ],
      RelMapView.romantic => [
        for (final l in labels)
          if (categoryOf(l, settings) == 'romantic') l,
      ],
      RelMapView.social => [
        for (final l in labels)
          if (categoryOf(l, settings) == 'platonic') l,
      ],
      _ => labels,
    };
    if (labels.isEmpty) continue;
    if (view == RelMapView.individual && focus != null && !r.involves(focus))
      continue;
    final styles = <String>[];
    for (final l in labels) {
      final s =
          isComplicated(r) && l == labels.first && r.status == 'complicated'
          ? 'complicated'
          : styleOf(l, settings);
      if (!styles.contains(s)) styles.add(s);
    }
    final first = relLabelIndex[labels.first];
    // Directional labels are stored "A is B's X"; parent → child arrows point at B.
    final dir =
        first != null &&
        first.directional &&
        _directionalStyles.contains(first.style) &&
        const {
          'parent',
          'grandparent',
          'guardian',
          'mentor',
          'protector',
          'caregiver',
        }.contains(first.key);
    final inv =
        first != null &&
        first.directional &&
        const {
          'child',
          'grandchild',
          'ward',
          'mentee',
          'protected',
          'dependent',
        }.contains(first.key);
    out.add(
      inv ? MapEdge(r, b, a, styles, true) : MapEdge(r, a, b, styles, dir),
    );
  }
  return out;
}

List<double> _layoutJob(Map<String, Object> job) {
  final nodes = (job['nodes']! as List).cast<String>();
  final edges = (job['edges']! as List).cast<List<Object?>>();
  final res = networkLayout(nodes, [
    for (final e in edges) (e[0]! as String, e[1]! as String),
  ]);
  return [
    res.size.width,
    res.size.height,
    for (final n in nodes) ...[res.positions[n]!.dx, res.positions[n]!.dy],
  ];
}

class RelationshipMap extends ConsumerStatefulWidget {
  const RelationshipMap({
    super.key,
    required this.view,
    this.focus,
    this.hiddenCategories = const {},
    this.onOpenAlter,
    this.onOpenRel,
    this.onFocus,
    this.height = 460,
  });
  final RelMapView view;
  final String? focus;
  final Set<String> hiddenCategories;
  final ValueChanged<String>? onOpenAlter;
  final ValueChanged<Rel>? onOpenRel;
  final ValueChanged<String>? onFocus;
  final double height;
  @override
  ConsumerState<RelationshipMap> createState() => RelationshipMapState();
}

class RelationshipMapState extends ConsumerState<RelationshipMap> {
  final _tc = TransformationController();
  String? _layoutKey;
  RelLayoutResult? _layout;
  Map<String, Offset> _manual = {};
  bool _arrange = false;
  bool _dirty = false;
  String? _selNode;
  Rel? _selEdge;
  Size? _viewport;
  int _job = 0;

  String get _posKey => widget.view == RelMapView.individual
      ? 'individual:${widget.focus}'
      : widget.view.name;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void zoom(double f) {
    final vp = _viewport;
    if (vp == null) return;
    final c = Offset(vp.width / 2, vp.height / 2);
    final m = _tc.value.clone()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(f, f, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    final s = m.getMaxScaleOnAxis();
    if (s < 0.2 || s > 3) return;
    _tc.value = m;
  }

  void resetView() {
    final l = _layout, vp = _viewport;
    if (l == null || vp == null) return;
    final s = math.min(
      1.2,
      math.max(
        0.2,
        math.min(vp.width / l.size.width, vp.height / l.size.height),
      ),
    );
    final dx = (vp.width - l.size.width * s) / 2,
        dy = (vp.height - l.size.height * s) / 2;
    _tc.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  /// Centres on an alter and selects it.
  void focusOn(String id) {
    final p = _pos(id), vp = _viewport;
    if (p == null || vp == null) return;
    const s = 1.0;
    _tc.value = Matrix4.identity()
      ..translateByDouble(
        vp.width / 2 - p.dx * s,
        vp.height / 2 - p.dy * s,
        0,
        1,
      )
      ..scaleByDouble(s, s, 1, 1);
    setState(() {
      _selNode = id;
      _selEdge = null;
    });
  }

  /// Throws away manual positions and recalculates this layout.
  Future<void> relayout() async {
    await ref.read(relActionsProvider).clearPositions(_posKey);
    setState(() {
      _manual = {};
      _layoutKey = null;
    });
  }

  Offset? _pos(String id) => _manual[id] ?? _layout?.positions[id];

  void _ensureLayout(
    List<String> nodes,
    List<MapEdge> edges,
    RelSettings settings,
  ) {
    final sig =
        '${widget.view.name}|${widget.focus}|${nodes.join(',')}|${[for (final e in edges) '${e.a}-${e.b}'].join(',')}';
    if (sig == _layoutKey) return;
    _layoutKey = sig;
    final saved = settings.positions[_posKey] ?? const {};
    _manual = {
      for (final e in saved.entries)
        if (nodes.contains(e.key)) e.key: Offset(e.value.$1, e.value.$2),
    };
    final job = ++_job;
    var sync = true;
    void done(RelLayoutResult r) {
      if (!mounted || job != _job) return;
      // Grow the canvas to fit any manually placed nodes.
      var w = r.size.width, h = r.size.height;
      for (final p in _manual.values) {
        w = math.max(w, p.dx + 90);
        h = math.max(h, p.dy + 90);
      }
      final result = RelLayoutResult(r.positions, Size(w, h));
      if (sync) {
        _layout = result; // computed during this build
      } else {
        setState(() => _layout = result);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) resetView();
      });
    }

    switch (widget.view) {
      case RelMapView.family:
        final fe = <(String, String, int)>[];
        for (final e in edges) {
          final l = e.rel.labels.firstWhere(
            (x) => categoryOf(x, settings) == 'familial',
            orElse: () => '',
          );
          final gen =
              const {
                'parent': 1,
                'guardian': 1,
                'grandparent': 2,
                'aunt_uncle': 1,
                'child': -1,
                'ward': -1,
                'grandchild': -2,
                'niece_nephew': -1,
              }[l] ??
              0;
          final ra = e.rel.a!, rb = e.rel.b!;
          fe.add(gen >= 0 ? (ra, rb, gen) : (rb, ra, -gen));
        }
        done(familyLayout(nodes, fe));
      case RelMapView.individual:
        done(
          radialLayout(widget.focus ?? nodes.first, [
            for (final n in nodes)
              if (n != widget.focus) n,
          ]),
        );
      default:
        final pairs = [for (final e in edges) (e.a, e.b)];
        if (nodes.length <= 60) {
          done(networkLayout(nodes, pairs));
        } else {
          compute(_layoutJob, {
            'nodes': nodes,
            'edges': [
              for (final p in pairs) [p.$1, p.$2],
            ],
          }).then((v) {
            sync = false;
            done(
              RelLayoutResult({
                for (var i = 0; i < nodes.length; i++)
                  nodes[i]: Offset(v[2 + i * 2], v[3 + i * 2]),
              }, Size(v[0], v[1])),
            );
          });
        }
    }
  }

  void _tapCanvas(Offset p, List<MapEdge> edges) {
    final s = _tc.value.getMaxScaleOnAxis();
    MapEdge? best;
    var bestD = 14 / s;
    for (final e in edges) {
      final a = _pos(e.a), b = _pos(e.b);
      if (a == null || b == null) continue;
      final d = _segDist(p, a, b);
      if (d < bestD) {
        bestD = d;
        best = e;
      }
    }
    setState(() {
      _selEdge = best?.rel;
      _selNode = null;
    });
  }

  static double _segDist(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(relSettingsProvider);
    final alters = ref.watch(relAlterIndexProvider);
    final rels = ref.watch(relsProvider);
    final edges = mapEdges(
      rels: rels,
      alterIds: alters.keys.toSet(),
      settings: settings,
      view: widget.view,
      focus: widget.focus,
      hiddenCategories: widget.hiddenCategories,
      hidePrivate: settings.hidePrivate,
    );
    final involved = {
      for (final e in edges) ...[e.a, e.b],
    };
    final nodes = switch (widget.view) {
      RelMapView.network => [
        for (final m in alters.values)
          if (m.isActive || involved.contains(m.id)) m.id,
      ],
      RelMapView.individual => [
        if (widget.focus != null && alters.containsKey(widget.focus))
          widget.focus!,
        for (final id in involved)
          if (id != widget.focus) id,
      ],
      _ => [
        for (final m in alters.values)
          if (involved.contains(m.id)) m.id,
      ],
    };
    final theme = Theme.of(context);

    if (nodes.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: prismCorners(context, PrismTokens.radiusMedium),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          widget.view == RelMapView.individual
              ? tr(
                  context,
                  'Choose an alter to see their connections.',
                  'Elige un alter para ver sus conexiones.',
                )
              : tr(
                  context,
                  'Nothing to show for this view yet.',
                  'Aún no hay nada que mostrar en esta vista.',
                ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    _ensureLayout(nodes, edges, settings);
    final layout = _layout;
    final fronting = {
      for (final f
          in ref.watch(activeSessionsProvider).value ??
              const <FrontingSession>[])
        ?f.memberId,
    };
    final neighbours = _selNode == null
        ? const <String>{}
        : {
            for (final e in edges)
              if (e.a == _selNode || e.b == _selNode) ...[e.a, e.b],
          };

    return ClipRRect(
      borderRadius: prismCorners(context, PrismTokens.radiusMedium),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: prismCorners(context, PrismTokens.radiusMedium),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            _viewport = Size(box.maxWidth, box.maxHeight);
            if (layout == null) return const Center(child: PrismLoadingState());
            final scale = _tc.value.getMaxScaleOnAxis();
            return Stack(
              children: [
                InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  minScale: 0.2,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(400),
                  panEnabled: !_arrange,
                  child: SizedBox(
                    width: layout.size.width,
                    height: layout.size.height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (d) => _tapCanvas(d.localPosition, edges),
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _EdgePainter(
                                  edges: edges,
                                  pos: {for (final n in nodes) n: ?_pos(n)},
                                  settings: settings,
                                  selNode: _selNode,
                                  selEdge: _selEdge?.id,
                                  showLabels: settings.showLabels,
                                  labelOf: (l) =>
                                      labelText(context, l, settings),
                                  textColor: theme.colorScheme.onSurface,
                                  bg: theme.colorScheme.surfaceContainerHigh,
                                ),
                              ),
                            ),
                          ),
                        ),
                        for (final id in nodes)
                          if (_pos(id) case final p? when alters[id] != null)
                            Positioned(
                              left: p.dx - 45,
                              top: p.dy - 30,
                              width: 90,
                              child: _Node(
                                member: alters[id]!,
                                showAvatar: settings.showAvatars,
                                fronting: fronting.contains(id),
                                selected: _selNode == id,
                                faded:
                                    _selNode != null &&
                                    !neighbours.contains(id),
                                arrange: _arrange,
                                onTap: () => setState(() {
                                  if (_selNode == id) {
                                    widget.onOpenAlter?.call(id);
                                  } else {
                                    _selNode = id;
                                    _selEdge = null;
                                  }
                                }),
                                onDoubleTap: () => widget.onOpenAlter?.call(id),
                                onDrag: (d) => setState(() {
                                  _manual[id] =
                                      (_pos(id) ?? Offset.zero) + d / scale;
                                  _dirty = true;
                                }),
                                onDragEnd: _savePositions,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: _MapControls(
                    arrange: _arrange,
                    onZoomIn: () => zoom(1.25),
                    onZoomOut: () => zoom(0.8),
                    onReset: resetView,
                    onRelayout: relayout,
                    onArrange: () => setState(() => _arrange = !_arrange),
                  ),
                ),
                if (_arrange)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _Badge(
                      text: tr(
                        context,
                        'Arrange mode: drag alters to move them',
                        'Modo organizar: arrastra los alters',
                      ),
                    ),
                  ),
                if (_selNode != null || _selEdge != null)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: _InfoBar(
                      node: _selNode == null ? null : alters[_selNode],
                      edge: _selEdge,
                      connections: _selNode == null
                          ? 0
                          : edges
                                .where(
                                  (e) => e.a == _selNode || e.b == _selNode,
                                )
                                .length,
                      alters: alters,
                      settings: settings,
                      onOpenAlter: widget.onOpenAlter,
                      onOpenRel: widget.onOpenRel,
                      onFocus: widget.onFocus,
                      onClose: () => setState(() {
                        _selNode = null;
                        _selEdge = null;
                      }),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _savePositions() {
    if (!_dirty) return;
    _dirty = false;
    final l = _layout;
    if (l == null) return;
    final all = {
      for (final e in l.positions.entries) e.key: (_manual[e.key] ?? e.value),
    };
    ref.read(relActionsProvider).savePositions(_posKey, {
      for (final e in all.entries) e.key: (e.value.dx, e.value.dy),
    });
  }
}

class _Node extends ConsumerWidget {
  const _Node({
    required this.member,
    required this.showAvatar,
    required this.fronting,
    required this.selected,
    required this.faded,
    required this.arrange,
    required this.onTap,
    required this.onDoubleTap,
    required this.onDrag,
    required this.onDragEnd,
  });
  final Member member;
  final bool showAvatar, fronting, selected, faded, arrange;
  final VoidCallback onTap, onDoubleTap, onDragEnd;
  final ValueChanged<Offset> onDrag;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final name = member.effectiveName(preferDisplayName: prefer);
    final role = ref
        .watch(memberProfileProvider(member.id))
        ?.roles
        .where((r) => r.visible)
        .firstOrNull
        ?.name;
    final avatar = showAvatar
        ? MemberAvatar(
            avatarImageData: member.avatarImageData,
            memberName: name,
            emoji: member.emoji,
            customColorEnabled: member.customColorEnabled,
            customColorHex: member.customColorHex,
            size: 40,
          )
        : PrismCircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
    return Semantics(
      button: true,
      label: [
        name,
        if (member.pronouns != null) member.pronouns!,
        ?role,
        if (fronting) tr(context, 'fronting', 'al frente'),
      ].join(', '),
      child: Tooltip(
        message: [
          name,
          if ((member.pronouns ?? '').isNotEmpty) member.pronouns!,
          ?role,
        ].join(' · '),
        waitDuration: const Duration(milliseconds: 400),
        child: GestureDetector(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onPanUpdate: arrange ? (d) => onDrag(d.delta) : null,
          onPanEnd: arrange ? (_) => onDragEnd() : null,
          child: Opacity(
            opacity: faded ? 0.35 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: prismRound(context),
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: avatar,
                    ),
                    if (fronting)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            borderRadius: prismRound(context),
                            color: theme.colorScheme.tertiary,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: prismCorners(context, 6),
                  ),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (role != null)
                  Text(
                    role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dash patterns per style so colour is never the only difference.
List<double>? relDash(String style, String confidence) {
  if (style == 'complicated') return const [8, 6];
  if (style == 'unknown') return const [2, 5];
  return switch (confidence) {
    'developing' => const [10, 5],
    'suspected' || 'uncertain' => const [3, 4],
    _ => null,
  };
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.edges,
    required this.pos,
    required this.settings,
    required this.selNode,
    required this.selEdge,
    required this.showLabels,
    required this.labelOf,
    required this.textColor,
    required this.bg,
  });
  final List<MapEdge> edges;
  final Map<String, Offset> pos;
  final RelSettings settings;
  final String? selNode;
  final String? selEdge;
  final bool showLabels;
  final String Function(String) labelOf;
  final Color textColor;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final a = pos[e.a], b = pos[e.b];
      if (a == null || b == null) continue;
      final focused =
          selEdge == e.rel.id ||
          (selNode != null && (e.a == selNode || e.b == selNode));
      final dimmed = (selNode != null || selEdge != null) && !focused;
      final d = b - a;
      final len = d.distance;
      if (len < 1) continue;
      final nrm = Offset(-d.dy / len, d.dx / len);
      for (var i = 0; i < e.styles.length; i++) {
        final off = nrm * ((i - (e.styles.length - 1) / 2) * 4.5);
        final color = relColor(settings, e.styles[i]).withValues(
          alpha: dimmed ? 0.18 : (e.rel.confidence == 'outdated' ? 0.4 : 0.9),
        );
        final paint = Paint()
          ..color = color
          ..strokeWidth = focused ? 3 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final p1 = a + off + d / len * 26, p2 = b + off - d / len * 26;
        final dash = relDash(e.styles[i], e.rel.confidence);
        if (dash == null) {
          canvas.drawLine(p1, p2, paint);
        } else {
          _dashed(canvas, p1, p2, paint, dash);
        }
        if (i == 0 && e.directional) {
          final tip = p2;
          final u = d / len;
          final left = tip - u * 9 + nrm * 5, right = tip - u * 9 - nrm * 5;
          canvas.drawPath(
            Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo(left.dx, left.dy)
              ..lineTo(right.dx, right.dy)
              ..close(),
            Paint()..color = color,
          );
        }
      }
      if (showLabels || focused) {
        final text = e.rel.labels.take(2).map(labelOf).join(' · ');
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: textColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 160);
        final mid = (a + b) / 2;
        final r = Rect.fromCenter(
          center: mid,
          width: tp.width + 10,
          height: tp.height + 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()..color = bg.withValues(alpha: dimmed ? 0.3 : 0.95),
        );
        tp.paint(canvas, Offset(r.left + 5, r.top + 2));
      }
    }
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p, List<double> pattern) {
    final d = b - a;
    final len = d.distance;
    final u = d / len;
    var t = 0.0;
    var i = 0;
    while (t < len) {
      final seg = pattern[i % pattern.length];
      if (i.isEven) c.drawLine(a + u * t, a + u * math.min(t + seg, len), p);
      t += seg;
      i++;
    }
  }

  @override
  bool shouldRepaint(_EdgePainter o) =>
      o.edges != edges ||
      o.pos != pos ||
      o.selNode != selNode ||
      o.selEdge != selEdge ||
      o.showLabels != showLabels ||
      o.settings != settings ||
      o.textColor != textColor;
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.arrange,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.onRelayout,
    required this.onArrange,
  });
  final bool arrange;
  final VoidCallback onZoomIn, onZoomOut, onReset, onRelayout, onArrange;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget b(IconData icon, String tip, VoidCallback f, {bool on = false}) =>
        PrismTopBarAction(
          icon: icon,
          tooltip: tip,
          onPressed: f,
          tint: on ? theme.colorScheme.primary : null,
        );
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: prismCorners(context, 12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          b(
            PhosphorIcons.magnifyingGlassPlus(),
            tr(context, 'Zoom in', 'Acercar'),
            onZoomIn,
          ),
          b(
            PhosphorIcons.magnifyingGlassMinus(),
            tr(context, 'Zoom out', 'Alejar'),
            onZoomOut,
          ),
          b(
            PhosphorIcons.arrowsIn(),
            tr(context, 'Reset view', 'Restablecer vista'),
            onReset,
          ),
          b(
            PhosphorIcons.handGrabbing(),
            tr(context, 'Arrange alters', 'Organizar alters'),
            onArrange,
            on: arrange,
          ),
          b(
            PhosphorIcons.shuffleSimple(),
            tr(context, 'Recalculate layout', 'Recalcular diseño'),
            onRelayout,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: prismCorners(context, 10),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _InfoBar extends ConsumerWidget {
  const _InfoBar({
    required this.node,
    required this.edge,
    required this.connections,
    required this.alters,
    required this.settings,
    this.onOpenAlter,
    this.onOpenRel,
    this.onFocus,
    required this.onClose,
  });
  final Member? node;
  final Rel? edge;
  final int connections;
  final Map<String, Member> alters;
  final RelSettings settings;
  final ValueChanged<String>? onOpenAlter;
  final ValueChanged<Rel>? onOpenRel;
  final ValueChanged<String>? onFocus;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    String nm(String? id) =>
        alters[id]?.effectiveName(preferDisplayName: prefer) ?? '—';
    final n = node, e = edge;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: prismCorners(context, 14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: n != null
                  ? Text(
                      '${n.effectiveName(preferDisplayName: prefer)} · ${tr(context, '$connections connections', '$connections conexiones')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text(
                      '${nm(e!.a)} & ${nm(e.b)}: ${e.labels.map((l) => labelText(context, l, settings)).join(', ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            if (n != null && onFocus != null)
              PrismButton(
                label: tr(context, 'Focus', 'Enfocar'),
                density: PrismControlDensity.compact,
                onPressed: () => onFocus!(n.id),
              ),
            if (n != null && onOpenAlter != null)
              PrismButton(
                label: tr(context, 'Profile', 'Perfil'),
                density: PrismControlDensity.compact,
                onPressed: () => onOpenAlter!(n.id),
              ),
            if (e != null && onOpenRel != null)
              PrismButton(
                label: tr(context, 'Open', 'Abrir'),
                tone: PrismButtonTone.filled,
                density: PrismControlDensity.compact,
                onPressed: () => onOpenRel!(e),
              ),
            PrismTopBarAction(
              icon: AppIcons.close,
              tooltip: tr(context, 'Close', 'Cerrar'),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Accessible text alternative to the map.
class RelationshipListView extends ConsumerWidget {
  const RelationshipListView({
    super.key,
    required this.view,
    this.focus,
    this.hiddenCategories = const {},
    this.onOpenRel,
  });
  final RelMapView view;
  final String? focus;
  final Set<String> hiddenCategories;
  final ValueChanged<Rel>? onOpenRel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(relSettingsProvider);
    final alters = ref.watch(relAlterIndexProvider);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final edges = mapEdges(
      rels: ref.watch(relsProvider),
      alterIds: alters.keys.toSet(),
      settings: settings,
      view: view,
      focus: focus,
      hiddenCategories: hiddenCategories,
      hidePrivate: settings.hidePrivate,
    );
    String nm(String id) =>
        alters[id]?.effectiveName(preferDisplayName: prefer) ?? '—';
    if (edges.isEmpty)
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          tr(
            context,
            'No connections in this view.',
            'No hay conexiones en esta vista.',
          ),
        ),
      );
    return Column(
      children: [
        for (final e in edges)
          PrismListRow(
            dense: true,
            leading: Container(
              width: 14,
              height: 4,
              color: relColor(settings, e.styles.first),
            ),
            title: Text(
              '${nm(e.rel.a!)} ${e.directional ? '→' : '↔'} ${nm(e.rel.b!)}',
            ),
            subtitle: Text(
              '${e.rel.labels.map((l) => labelText(context, l, settings)).join(', ')} · ${relConfidenceText(context, e.rel.confidence)}',
            ),
            showChevron: true,
            onTap: onOpenRel == null ? null : () => onOpenRel!(e.rel),
          ),
      ],
    );
  }
}
