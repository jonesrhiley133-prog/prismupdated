import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Node positions plus the size of the drawing area.
class RelLayoutResult {
  const RelLayoutResult(this.positions, this.size);
  final Map<String, Offset> positions;
  final Size size;
}

const _pad = 90.0;

RelLayoutResult _normalise(Map<String, Offset> raw, {double minW = 600, double minH = 500}) {
  if (raw.isEmpty) return RelLayoutResult(const {}, Size(minW, minH));
  var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
  for (final p in raw.values) {
    l = math.min(l, p.dx);
    t = math.min(t, p.dy);
    r = math.max(r, p.dx);
    b = math.max(b, p.dy);
  }
  final w = math.max(minW, r - l + _pad * 2), h = math.max(minH, b - t + _pad * 2);
  final ox = (w - (r - l)) / 2 - l, oy = (h - (b - t)) / 2 - t;
  return RelLayoutResult({for (final e in raw.entries) e.key: e.value.translate(ox, oy)}, Size(w, h));
}

/// Force-directed layout, run a fixed number of steps once (no ongoing
/// simulation). Deterministic for the same input.
RelLayoutResult networkLayout(List<String> nodes, List<(String, String)> edges, {int iterations = 220}) {
  final n = nodes.length;
  if (n == 0) return _normalise(const {});
  if (n == 1) return _normalise({nodes.first: Offset.zero});
  final rnd = math.Random(n * 7919 + edges.length);
  final area = 170.0 * 170.0 * n;
  final k = math.sqrt(area / n);
  final radius = math.sqrt(area) / 2;
  final pos = <String, Offset>{
    for (var i = 0; i < n; i++) nodes[i]: Offset(radius * math.cos(2 * math.pi * i / n) + rnd.nextDouble(), radius * math.sin(2 * math.pi * i / n) + rnd.nextDouble()),
  };
  final idx = {for (var i = 0; i < n; i++) nodes[i]: i};
  final validEdges = [for (final (a, b) in edges) if (idx.containsKey(a) && idx.containsKey(b) && a != b) (a, b)];
  var temp = radius / 4;
  for (var it = 0; it < iterations; it++) {
    final disp = <String, Offset>{for (final v in nodes) v: Offset.zero};
    for (var i = 0; i < n; i++) {
      final vi = nodes[i];
      for (var j = i + 1; j < n; j++) {
        final vj = nodes[j];
        var d = pos[vi]! - pos[vj]!;
        var dist = d.distance;
        if (dist < 0.01) {
          d = Offset(rnd.nextDouble() - 0.5, rnd.nextDouble() - 0.5);
          dist = 0.5;
        }
        final f = k * k / dist;
        final push = d / dist * f;
        disp[vi] = disp[vi]! + push;
        disp[vj] = disp[vj]! - push;
      }
    }
    for (final (a, b) in validEdges) {
      final d = pos[a]! - pos[b]!;
      final dist = math.max(d.distance, 0.01);
      final pull = d / dist * (dist * dist / k);
      disp[a] = disp[a]! - pull;
      disp[b] = disp[b]! + pull;
    }
    for (final v in nodes) {
      // Gentle pull to the centre keeps separate groups together.
      final p = pos[v]!;
      final dv = disp[v]! - p * 0.02;
      final len = dv.distance;
      if (len > 0) pos[v] = p + dv / len * math.min(len, temp);
    }
    temp *= 0.975;
  }
  return _normalise(pos);
}

/// Generation layout for family view. [edges] are (older, younger, levels)
/// for parent-like links (levels 1 for parent, 2 for grandparent) and
/// (a, b, 0) for same-generation links (siblings, cousins, partners).
RelLayoutResult familyLayout(List<String> nodes, List<(String, String, int)> edges) {
  if (nodes.isEmpty) return _normalise(const {});
  final level = <String, int>{};
  final adj = <String, List<(String, int)>>{};
  for (final (a, b, d) in edges) {
    (adj[a] ??= []).add((b, d));
    (adj[b] ??= []).add((a, -d));
  }
  // Breadth-first per connected group: older generations on top.
  for (final start in nodes) {
    if (level.containsKey(start)) continue;
    level[start] = 0;
    final queue = [start];
    final group = <String>[start];
    while (queue.isNotEmpty) {
      final v = queue.removeAt(0);
      for (final (u, d) in adj[v] ?? const <(String, int)>[]) {
        if (level.containsKey(u)) continue;
        level[u] = level[v]! + d;
        queue.add(u);
        group.add(u);
      }
    }
    final minL = group.map((g) => level[g]!).reduce(math.min);
    for (final g in group) {
      level[g] = level[g]! - minL;
    }
  }
  // Groups side by side; within a generation, order by neighbours' average x.
  final groups = <List<String>>[];
  final seen = <String>{};
  for (final s in nodes) {
    if (!seen.add(s)) continue;
    final g = [s];
    for (var i = 0; i < g.length; i++) {
      for (final (u, _) in adj[g[i]] ?? const <(String, int)>[]) {
        if (seen.add(u)) g.add(u);
      }
    }
    groups.add(g);
  }
  const dx = 150.0, dy = 150.0;
  final pos = <String, Offset>{};
  var x0 = 0.0;
  for (final g in groups) {
    final byLevel = <int, List<String>>{};
    for (final v in g) {
      (byLevel[level[v]!] ??= []).add(v);
    }
    final levels = byLevel.keys.toList()..sort();
    final width = byLevel.values.map((l) => l.length).reduce(math.max);
    for (final lv in levels) {
      final row = byLevel[lv]!;
      if (lv > levels.first) {
        double bx(String v) {
          final xs = [for (final (u, d) in adj[v] ?? const <(String, int)>[]) if (d < 0 && pos.containsKey(u)) pos[u]!.dx];
          return xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
        }

        row.sort((a, b) => bx(a).compareTo(bx(b)));
      }
      final offset = (width - row.length) * dx / 2;
      for (var i = 0; i < row.length; i++) {
        pos[row[i]] = Offset(x0 + offset + i * dx, lv * dy);
      }
    }
    x0 += width * dx + 120;
  }
  return _normalise(pos);
}

/// One alter in the middle, their connections around them.
RelLayoutResult radialLayout(String center, List<String> others) {
  final pos = <String, Offset>{center: Offset.zero};
  final n = others.length;
  final r = math.max(180.0, n * 40.0);
  for (var i = 0; i < n; i++) {
    final a = -math.pi / 2 + 2 * math.pi * i / math.max(n, 1);
    pos[others[i]] = Offset(r * math.cos(a), r * math.sin(a));
  }
  return _normalise(pos);
}
