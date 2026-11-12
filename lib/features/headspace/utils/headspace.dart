import 'dart:math' as math;
import 'dart:ui';

import 'package:prism_plurality/domain/models/tracker_record.dart';

/// The virtual canvas every map is drawn on; positions are stored in these
/// units so maps look the same on phones and desktops.
const headspaceCanvas = Size(1600, 1200);

abstract final class HsField {
  static const x = 'x';
  static const y = 'y';
  static const w = 'w';
  static const h = 'h';
  static const color = 'color';
  static const shape = 'shape';
  static const residents = 'residents';
  static const from = 'from';
  static const to = 'to';
  static const label = 'label';
  static const oneWay = 'oneWay';
  static const background = 'background';
}

const headspaceShapes = ['rounded', 'rect', 'circle'];

Rect areaRect(TrackerRecord a) {
  final w = (a.number(HsField.w) ?? 180).clamp(60, 800).toDouble();
  final h = (a.number(HsField.h) ?? 120).clamp(50, 800).toDouble();
  final x = (a.number(HsField.x) ?? 100)
      .clamp(0, headspaceCanvas.width - w)
      .toDouble();
  final y = (a.number(HsField.y) ?? 100)
      .clamp(0, headspaceCanvas.height - h)
      .toDouble();
  return Rect.fromLTWH(x, y, w, h);
}

/// Clamps a moved area inside the canvas.
Offset clampPosition(Offset p, Size areaSize) => Offset(
  p.dx.clamp(0, headspaceCanvas.width - areaSize.width).toDouble(),
  p.dy.clamp(0, headspaceCanvas.height - areaSize.height).toDouble(),
);

/// Grid positions for [count] areas, used by "Arrange".
List<Offset> gridLayout(int count, {Size cell = const Size(240, 180)}) {
  if (count == 0) return const [];
  final cols = math.max(1, math.min(6, math.sqrt(count * 1.4).ceil()));
  return [
    for (var i = 0; i < count; i++)
      Offset(60 + (i % cols) * cell.width, 60 + (i ~/ cols) * cell.height),
  ];
}

/// Point on the edge of [r] in the direction of [toward], so link lines
/// start at the area border rather than its centre.
Offset edgePoint(Rect r, Offset toward) {
  final c = r.center;
  final d = toward - c;
  if (d.distance == 0) return c;
  final sx = d.dx == 0 ? double.infinity : (r.width / 2) / d.dx.abs();
  final sy = d.dy == 0 ? double.infinity : (r.height / 2) / d.dy.abs();
  final s = math.min(sx, sy);
  return c + d * s;
}

/// Links whose both ends exist on the map.
List<TrackerRecord> validLinks(
  List<TrackerRecord> links,
  Set<String> areaIds,
) => [
  for (final l in links)
    if (areaIds.contains(l.str(HsField.from)) &&
        areaIds.contains(l.str(HsField.to)) &&
        l.str(HsField.from) != l.str(HsField.to))
      l,
];
