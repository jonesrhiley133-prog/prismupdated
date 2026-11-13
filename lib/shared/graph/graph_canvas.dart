import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A node on a [GraphCanvas]. Positions are in world units around
/// [GraphCanvas.worldCenter].
class GraphNode {
  const GraphNode({
    required this.id,
    required this.label,
    required this.position,
    required this.color,
    this.subtitle,
    this.icon,
    this.emoji,
    this.size = 56,
    this.shape = GraphNodeShape.circle,
  });

  final String id;
  final String label;
  final String? subtitle;
  final Offset position;
  final Color color;
  final IconData? icon;
  final String? emoji;
  final double size;
  final GraphNodeShape shape;
}

enum GraphNodeShape { circle, rounded, diamond, hexagon }

enum GraphEdgeStyle { solid, dashed, dotted }

class GraphEdge {
  const GraphEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.color,
    this.label,
    this.width = 2,
    this.style = GraphEdgeStyle.solid,
    this.directed = false,
  });

  final String id;
  final String from;
  final String to;
  final Color color;
  final String? label;
  final double width;
  final GraphEdgeStyle style;
  final bool directed;
}

enum GraphLayout { free, circle, grid, force, tree }

const double _world = 4000;
const Offset _center = Offset(_world / 2, _world / 2);

/// Positions for [layout]. `free` keeps the given positions.
Map<String, Offset> computeGraphLayout(
  GraphLayout layout,
  List<GraphNode> nodes,
  List<GraphEdge> edges,
) {
  final n = nodes.length;
  if (n == 0) return const {};
  switch (layout) {
    case GraphLayout.free:
      return {for (final x in nodes) x.id: x.position};
    case GraphLayout.circle:
      final r = math.max(160.0, n * 34.0);
      return {
        for (var i = 0; i < n; i++)
          nodes[i].id:
              _center +
              Offset(
                r * math.cos(2 * math.pi * i / n - math.pi / 2),
                r * math.sin(2 * math.pi * i / n - math.pi / 2),
              ),
      };
    case GraphLayout.grid:
      final cols = math.max(1, math.sqrt(n).ceil());
      const gap = 150.0;
      final rows = (n / cols).ceil();
      final origin =
          _center - Offset((cols - 1) * gap / 2, (rows - 1) * gap / 2);
      return {
        for (var i = 0; i < n; i++)
          nodes[i].id: origin + Offset((i % cols) * gap, (i ~/ cols) * gap),
      };
    case GraphLayout.tree:
      return _treeLayout(nodes, edges);
    case GraphLayout.force:
      return _forceLayout(nodes, edges);
  }
}

Map<String, Offset> _treeLayout(List<GraphNode> nodes, List<GraphEdge> edges) {
  final ids = {for (final x in nodes) x.id};
  final adj = <String, List<String>>{};
  final indeg = <String, int>{for (final i in ids) i: 0};
  for (final e in edges) {
    if (!ids.contains(e.from) || !ids.contains(e.to) || e.from == e.to) {
      continue;
    }
    adj.putIfAbsent(e.from, () => []).add(e.to);
    adj.putIfAbsent(e.to, () => []).add(e.from);
    indeg[e.to] = indeg[e.to]! + 1;
  }
  final level = <String, int>{};
  final order = [...ids]
    ..sort((a, b) {
      final d = (adj[b]?.length ?? 0).compareTo(adj[a]?.length ?? 0);
      return d != 0 ? d : indeg[a]!.compareTo(indeg[b]!);
    });
  for (final root in order) {
    if (level.containsKey(root)) continue;
    level[root] = 0;
    final queue = [root];
    while (queue.isNotEmpty) {
      final c = queue.removeAt(0);
      for (final nb in adj[c] ?? const <String>[]) {
        if (level.containsKey(nb)) continue;
        level[nb] = level[c]! + 1;
        queue.add(nb);
      }
    }
  }
  final byLevel = <int, List<String>>{};
  for (final id in order) {
    byLevel.putIfAbsent(level[id]!, () => []).add(id);
  }
  final out = <String, Offset>{};
  final depth = byLevel.keys.fold(0, math.max);
  byLevel.forEach((l, list) {
    for (var i = 0; i < list.length; i++) {
      out[list[i]] =
          _center +
          Offset((i - (list.length - 1) / 2) * 150, (l - depth / 2) * 170);
    }
  });
  return out;
}

Map<String, Offset> _forceLayout(List<GraphNode> nodes, List<GraphEdge> edges) {
  final n = nodes.length;
  final rnd = math.Random(7);
  final pos = <String, Offset>{
    for (var i = 0; i < n; i++)
      nodes[i].id:
          _center +
          Offset(
            (rnd.nextDouble() - .5) * 60 * math.sqrt(n + 1),
            (rnd.nextDouble() - .5) * 60 * math.sqrt(n + 1),
          ),
  };
  const k = 140.0;
  final iterations = n > 200 ? 60 : (n > 80 ? 120 : 220);
  var temp = 120.0;
  final ids = [for (final x in nodes) x.id];
  for (var it = 0; it < iterations; it++) {
    final disp = <String, Offset>{for (final i in ids) i: Offset.zero};
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final a = ids[i], b = ids[j];
        var d = pos[a]! - pos[b]!;
        var dist = d.distance;
        if (dist < 0.01) {
          d = const Offset(0.1, 0.1);
          dist = 0.14;
        }
        final f = k * k / dist;
        final v = d / dist * f;
        disp[a] = disp[a]! + v;
        disp[b] = disp[b]! - v;
      }
    }
    for (final e in edges) {
      final a = pos[e.from], b = pos[e.to];
      if (a == null || b == null || e.from == e.to) continue;
      final d = a - b;
      final dist = math.max(d.distance, 0.01);
      final v = d / dist * (dist * dist / k);
      disp[e.from] = disp[e.from]! - v;
      disp[e.to] = disp[e.to]! + v;
    }
    for (final i in ids) {
      final d = disp[i]!;
      final len = math.max(d.distance, 0.01);
      var p = pos[i]! + d / len * math.min(len, temp);
      // Gentle gravity keeps disconnected parts together.
      p = p + (_center - p) * 0.01;
      pos[i] = p;
    }
    temp = math.max(2, temp * 0.97);
  }
  return pos;
}

/// Zoomable, pannable node map. Nodes can be dragged when [onNodeMoved] is
/// given; tapping a node or an edge calls back.
class GraphCanvas extends StatefulWidget {
  const GraphCanvas({
    super.key,
    required this.nodes,
    required this.edges,
    this.onNodeTap,
    this.onNodeLongPress,
    this.onNodeMoved,
    this.onEdgeTap,
    this.onBackgroundTap,
    this.selectedNodeId,
    this.highlightIds = const {},
    this.background,
    this.showEdgeLabels = true,
  });

  static const Offset worldCenter = _center;

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final ValueChanged<String>? onNodeTap;
  final ValueChanged<String>? onNodeLongPress;
  final void Function(String id, Offset position)? onNodeMoved;
  final ValueChanged<String>? onEdgeTap;
  final ValueChanged<Offset>? onBackgroundTap;
  final String? selectedNodeId;
  final Set<String> highlightIds;
  final Color? background;
  final bool showEdgeLabels;

  @override
  State<GraphCanvas> createState() => GraphCanvasState();
}

class GraphCanvasState extends State<GraphCanvas> {
  final _controller = TransformationController();
  final Map<String, Offset> _dragging = {};
  Size? _viewport;
  bool _fitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _posOf(GraphNode n) => _dragging[n.id] ?? n.position;

  /// Zooms and pans so every node is visible.
  void fit() {
    final v = _viewport;
    if (v == null || widget.nodes.isEmpty) {
      if (v != null) {
        _controller.value = Matrix4.identity()
          ..translateByDouble(
            -_center.dx + v.width / 2,
            -_center.dy + v.height / 2,
            0,
            1,
          );
      }
      return;
    }
    var rect = Rect.fromCenter(center: _posOf(widget.nodes.first), width: 1, height: 1);
    for (final n in widget.nodes) {
      rect = rect.expandToInclude(
        Rect.fromCenter(center: _posOf(n), width: n.size + 80, height: n.size + 60),
      );
    }
    final scale = math
        .min(v.width / rect.width, v.height / rect.height)
        .clamp(0.25, 1.6);
    final tx = v.width / 2 - rect.center.dx * scale;
    final ty = v.height / 2 - rect.center.dy * scale;
    _controller.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void zoom(double factor) {
    final v = _viewport;
    if (v == null) return;
    final c = Offset(v.width / 2, v.height / 2);
    final m = _controller.value.clone()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    _controller.value = m;
  }

  /// Converts a viewport point to world coordinates.
  Offset toWorld(Offset local) => _controller.toScene(local);

  Offset get viewportCenterInWorld {
    final v = _viewport ?? const Size(400, 400);
    return toWorld(Offset(v.width / 2, v.height / 2));
  }

  String? _edgeAt(Offset world) {
    final byId = {for (final n in widget.nodes) n.id: _posOf(n)};
    String? best;
    var bestD = 18.0;
    for (final e in widget.edges) {
      final a = byId[e.from], b = byId[e.to];
      if (a == null || b == null) continue;
      final d = _distToSegment(world, a, b);
      if (d < bestD) {
        bestD = d;
        best = e.id;
      }
    }
    return best;
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        _viewport = c.biggest;
        if (!_fitted) {
          _fitted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) fit();
          });
        }
        final positions = {for (final n in widget.nodes) n.id: _posOf(n)};
        return ClipRect(
          child: ColoredBox(
            color: widget.background ?? theme.colorScheme.surfaceContainerLowest,
            child: InteractiveViewer(
              transformationController: _controller,
              constrained: false,
              minScale: 0.15,
              maxScale: 3,
              boundaryMargin: const EdgeInsets.all(1200),
              child: SizedBox(
                width: _world,
                height: _world,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          final edge = widget.onEdgeTap == null
                              ? null
                              : _edgeAt(d.localPosition);
                          if (edge != null) {
                            widget.onEdgeTap!(edge);
                          } else {
                            widget.onBackgroundTap?.call(d.localPosition);
                          }
                        },
                        child: CustomPaint(
                          painter: _EdgePainter(
                            edges: widget.edges,
                            positions: positions,
                            sizes: {for (final n in widget.nodes) n.id: n.size},
                            labelStyle: theme.textTheme.labelSmall!.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            labelBg: theme.colorScheme.surface,
                            showLabels: widget.showEdgeLabels,
                            gridColor: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    ),
                    for (final n in widget.nodes)
                      Positioned(
                        left: positions[n.id]!.dx - 60,
                        top: positions[n.id]!.dy - n.size / 2,
                        width: 120,
                        child: _NodeWidget(
                          node: n,
                          selected: widget.selectedNodeId == n.id,
                          dimmed: widget.highlightIds.isNotEmpty &&
                              !widget.highlightIds.contains(n.id),
                          onTap: widget.onNodeTap == null
                              ? null
                              : () => widget.onNodeTap!(n.id),
                          onLongPress: widget.onNodeLongPress == null
                              ? null
                              : () => widget.onNodeLongPress!(n.id),
                          onDrag: widget.onNodeMoved == null
                              ? null
                              : (delta) => setState(() {
                                  _dragging[n.id] = _posOf(n) + delta;
                                }),
                          onDragEnd: widget.onNodeMoved == null
                              ? null
                              : () {
                                  final p = _dragging.remove(n.id);
                                  if (p != null) widget.onNodeMoved!(n.id, p);
                                  setState(() {});
                                },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NodeWidget extends StatelessWidget {
  const _NodeWidget({
    required this.node,
    required this.selected,
    required this.dimmed,
    this.onTap,
    this.onLongPress,
    this.onDrag,
    this.onDragEnd,
  });

  final GraphNode node;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<Offset>? onDrag;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg =
        ThemeData.estimateBrightnessForColor(node.color) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final s = node.size;
    final Widget inner = node.emoji != null && node.emoji!.isNotEmpty
        ? Text(node.emoji!, style: TextStyle(fontSize: s * 0.42))
        : Icon(node.icon ?? Icons.circle, color: fg, size: s * 0.42);
    final OutlinedBorder shape = switch (node.shape) {
      GraphNodeShape.circle => const CircleBorder(),
      GraphNodeShape.rounded => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(s * 0.28),
      ),
      GraphNodeShape.diamond => const StarBorder.polygon(sides: 4),
      GraphNodeShape.hexagon => const StarBorder.polygon(sides: 6),
    };
    return Opacity(
      opacity: dimmed ? 0.3 : 1,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        onPanUpdate: onDrag == null ? null : (d) => onDrag!(d.delta),
        onPanEnd: onDragEnd == null ? null : (_) => onDragEnd!(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: s,
              height: s,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: node.color,
                shape: shape.copyWith(
                  side: BorderSide(
                    color: selected
                        ? theme.colorScheme.primary
                        : node.color.withValues(alpha: 0.5),
                    width: selected ? 3 : 1,
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: node.color.withValues(alpha: 0.35),
                    blurRadius: selected ? 14 : 6,
                  ),
                ],
              ),
              child: inner,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Text(
                    node.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium,
                  ),
                  if (node.subtitle != null)
                    Text(
                      node.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.edges,
    required this.positions,
    required this.sizes,
    required this.labelStyle,
    required this.labelBg,
    required this.showLabels,
    required this.gridColor,
  });

  final List<GraphEdge> edges;
  final Map<String, Offset> positions;
  final Map<String, double> sizes;
  final TextStyle labelStyle;
  final Color labelBg;
  final bool showLabels;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = gridColor;
    for (double x = 0; x < size.width; x += 80) {
      for (double y = 0; y < size.height; y += 80) {
        canvas.drawCircle(Offset(x, y), 1.4, grid);
      }
    }
    // Parallel edges between the same pair curve apart.
    final pairCount = <String, int>{};
    for (final e in edges) {
      final a = positions[e.from], b = positions[e.to];
      if (a == null || b == null) continue;
      final key = ([e.from, e.to]..sort()).join('|');
      final idx = pairCount[key] = (pairCount[key] ?? 0) + 1;
      final paint = Paint()
        ..color = e.color
        ..strokeWidth = e.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final mid = (a + b) / 2;
      final dir = b - a;
      final normal = dir.distance == 0
          ? Offset.zero
          : Offset(-dir.dy, dir.dx) / dir.distance;
      final bend = (idx - 1) * 28.0 * (idx.isEven ? 1 : -1);
      final ctrl = mid + normal * bend;
      final path = Path()..moveTo(a.dx, a.dy);
      if (e.from == e.to) {
        final r = (sizes[e.from] ?? 56) * 0.6;
        path.addOval(Rect.fromCircle(center: a + Offset(0, -r), radius: r * 0.6));
      } else {
        path.quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
      }
      switch (e.style) {
        case GraphEdgeStyle.solid:
          canvas.drawPath(path, paint);
        case GraphEdgeStyle.dashed:
        case GraphEdgeStyle.dotted:
          final on = e.style == GraphEdgeStyle.dashed ? 10.0 : 2.0;
          final off = e.style == GraphEdgeStyle.dashed ? 7.0 : 6.0;
          for (final m in path.computeMetrics()) {
            var d = 0.0;
            while (d < m.length) {
              canvas.drawPath(m.extractPath(d, math.min(d + on, m.length)), paint);
              d += on + off;
            }
          }
      }
      if (e.directed && e.from != e.to) {
        final r = (sizes[e.to] ?? 56) / 2 + 4;
        final tangent = (b - ctrl);
        final u = tangent.distance == 0 ? Offset.zero : tangent / tangent.distance;
        final tip = b - u * r;
        final left = tip - u * 12 + Offset(-u.dy, u.dx) * 6;
        final right = tip - u * 12 - Offset(-u.dy, u.dx) * 6;
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(left.dx, left.dy)
            ..lineTo(right.dx, right.dy)
            ..close(),
          Paint()..color = e.color,
        );
      }
      final label = e.label;
      if (showLabels && label != null && label.isNotEmpty) {
        final at = e.from == e.to ? a + const Offset(0, -60) : (mid + ctrl) / 2;
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 140);
        final rect = Rect.fromCenter(
          center: at,
          width: tp.width + 10,
          height: tp.height + 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = labelBg.withValues(alpha: 0.9),
        );
        tp.paint(canvas, rect.topLeft + const Offset(5, 2));
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.edges != edges || old.positions != positions || old.showLabels != showLabels;
}
