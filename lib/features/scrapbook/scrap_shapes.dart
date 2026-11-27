import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_plurality/features/wallets/id_shapes.dart';

/// Every shape a scrapbook page can hold (the card shapes plus more).
/// Id → label, grouped by [scrapShapeGroups].
const scrapShapeGroups = <String, List<String>>{
  'Basic': [
    'rect',
    'rrect',
    'ellipse',
    'ring',
    'triangle',
    'triDown',
    'rightTri',
    'diamond',
    'kite',
    'trapezoid',
    'para',
    'semicircle',
    'quarter',
    'pie',
    'pill',
    'squircle',
    'lens',
    'minus',
  ],
  'Polygons': [
    'pentagon',
    'hex',
    'heptagon',
    'octagon',
    'nonagon',
    'decagon',
    'dodecagon',
  ],
  'Stars & bursts': [
    'star',
    'star4',
    'star6',
    'star7',
    'star8',
    'star12',
    'star16',
    'sparkle',
    'burst',
    'seal12',
    'seal16',
    'seal24',
    'scallop',
  ],
  'Arrows': [
    'arrowR',
    'arrowL',
    'arrowU',
    'arrowD',
    'arrowDouble',
    'chevronR',
    'chevronL',
  ],
  'Speech': ['speech', 'speechOval', 'speechSquare', 'cloud'],
  'Nature': [
    'heart',
    'moon',
    'drop',
    'leaf',
    'flower',
    'flower6',
    'flower8',
    'clover',
    'bolt',
  ],
  'Critters': ['fish', 'cat', 'bear', 'butterfly', 'bat'],
  'Things': [
    'cross',
    'house',
    'crown',
    'flag',
    'bookmark',
    'gear',
    'arch',
    'tombstone',
    'hourglass',
    'shield',
  ],
  'Labels & edges': [
    'ribbon',
    'ticket',
    'tag',
    'stamp',
    'torn',
    'notch',
    'brackets',
    'wave',
    'arc',
    'blob',
  ],
};

const _extraNames = <String, String>{
  'triDown': 'Triangle down',
  'rightTri': 'Right triangle',
  'kite': 'Kite',
  'trapezoid': 'Trapezoid',
  'semicircle': 'Semicircle',
  'quarter': 'Quarter',
  'pie': 'Pie',
  'pill': 'Pill',
  'squircle': 'Squircle',
  'lens': 'Lens',
  'minus': 'Bar',
  'pentagon': 'Pentagon',
  'heptagon': 'Heptagon',
  'octagon': 'Octagon',
  'nonagon': 'Nonagon',
  'decagon': 'Decagon',
  'dodecagon': 'Dodecagon',
  'star4': '4-point star',
  'star6': '6-point star',
  'star7': '7-point star',
  'star8': '8-point star',
  'star12': '12-point star',
  'star16': '16-point star',
  'sparkle': 'Sparkle',
  'seal12': 'Seal 12',
  'seal16': 'Seal 16',
  'seal24': 'Seal 24',
  'arrowR': 'Arrow right',
  'arrowL': 'Arrow left',
  'arrowU': 'Arrow up',
  'arrowD': 'Arrow down',
  'arrowDouble': 'Double arrow',
  'chevronR': 'Chevron right',
  'chevronL': 'Chevron left',
  'speech': 'Speech bubble',
  'speechOval': 'Round bubble',
  'speechSquare': 'Square bubble',
  'flower6': 'Flower 6',
  'flower8': 'Flower 8',
  'clover': 'Clover',
  'fish': 'Fish',
  'cat': 'Cat',
  'bear': 'Bear',
  'butterfly': 'Butterfly',
  'bat': 'Bat',
  'house': 'House',
  'crown': 'Crown',
  'flag': 'Flag',
  'bookmark': 'Bookmark',
  'gear': 'Gear',
  'arch': 'Arch',
  'tombstone': 'Tombstone',
  'hourglass': 'Hourglass',
};

final List<String> scrapShapeIds = [
  for (final g in scrapShapeGroups.values) ...g,
];

String scrapShapeName(String id) => _extraNames[id] ?? idShapeKinds[id] ?? id;

Path _poly(Rect r, int n, {double inner = 1, double rot = -math.pi / 2}) {
  final c = r.center;
  final path = Path();
  final pts = n * (inner == 1 ? 1 : 2);
  for (var i = 0; i < pts; i++) {
    final a = rot + i * 2 * math.pi / pts;
    final k = inner == 1 ? 1.0 : (i.isEven ? 1.0 : inner);
    final p = Offset(
      c.dx + math.cos(a) * r.width / 2 * k,
      c.dy + math.sin(a) * r.height / 2 * k,
    );
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

Path _pts(Rect r, List<List<double>> unit) {
  final p = Path();
  for (var i = 0; i < unit.length; i++) {
    final o = Offset(
      r.left + unit[i][0] * r.width,
      r.top + unit[i][1] * r.height,
    );
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

Path _petals(Rect r, int n, double petal) {
  final c = r.center;
  final path = Path();
  for (var i = 0; i < n; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / n;
    final pc = Offset(
      c.dx + math.cos(a) * r.width * 0.28,
      c.dy + math.sin(a) * r.height * 0.28,
    );
    path.addOval(
      Rect.fromCenter(
        center: pc,
        width: r.width * petal,
        height: r.height * petal,
      ),
    );
  }
  path.addOval(
    Rect.fromCenter(center: c, width: r.width * 0.34, height: r.height * 0.34),
  );
  return path;
}

Path _bubble(Rect r, Path body) {
  final tail = Path()
    ..moveTo(r.left + r.width * 0.22, r.bottom - r.height * 0.22)
    ..lineTo(r.left + r.width * 0.12, r.bottom)
    ..lineTo(r.left + r.width * 0.42, r.bottom - r.height * 0.2)
    ..close();
  return Path.combine(PathOperation.union, body, tail);
}

/// The outline of shape [id] fitted into [r].
Path scrapShapePath(String id, Rect r) {
  final w = r.width, h = r.height;
  final body = Rect.fromLTWH(r.left, r.top, w, h * 0.8);
  switch (id) {
    case 'triDown':
      return _pts(r, [
        [0, 0],
        [1, 0],
        [0.5, 1],
      ]);
    case 'rightTri':
      return _pts(r, [
        [0, 0],
        [1, 1],
        [0, 1],
      ]);
    case 'kite':
      return _pts(r, [
        [0.5, 0],
        [1, 0.38],
        [0.5, 1],
        [0, 0.38],
      ]);
    case 'trapezoid':
      return _pts(r, [
        [0.2, 0],
        [0.8, 0],
        [1, 1],
        [0, 1],
      ]);
    case 'semicircle':
      return Path()
        ..moveTo(r.left, r.center.dy)
        ..arcTo(Rect.fromLTWH(r.left, r.top, w, h), math.pi, math.pi, false)
        ..close();
    case 'quarter':
      return Path()
        ..moveTo(r.left, r.bottom)
        ..lineTo(r.left, r.top)
        ..arcTo(
          Rect.fromLTWH(r.left, r.top, w * 2, h * 2),
          -math.pi,
          math.pi / 2,
          false,
        )
        ..close();
    case 'pie':
      return Path()
        ..moveTo(r.center.dx, r.center.dy)
        ..arcTo(r, -math.pi / 2, math.pi * 1.5, false)
        ..close();
    case 'pill':
      return Path()..addRRect(
        RRect.fromRectAndRadius(r, Radius.circular(math.min(w, h) / 2)),
      );
    case 'squircle':
      return Path()..addRRect(
        RRect.fromRectAndRadius(r, Radius.circular(math.min(w, h) * 0.34)),
      );
    case 'lens':
      return Path()
        ..moveTo(r.left, r.center.dy)
        ..quadraticBezierTo(r.center.dx, r.top - h * 0.4, r.right, r.center.dy)
        ..quadraticBezierTo(
          r.center.dx,
          r.bottom + h * 0.4,
          r.left,
          r.center.dy,
        );
    case 'minus':
      return Path()
        ..addRect(Rect.fromLTWH(r.left, r.center.dy - h * 0.13, w, h * 0.26));
    case 'pentagon':
      return _poly(r, 5);
    case 'heptagon':
      return _poly(r, 7);
    case 'octagon':
      return _poly(r, 8, rot: -math.pi / 2 + math.pi / 8);
    case 'nonagon':
      return _poly(r, 9);
    case 'decagon':
      return _poly(r, 10);
    case 'dodecagon':
      return _poly(r, 12);
    case 'star4':
      return _poly(r, 4, inner: 0.45);
    case 'star6':
      return _poly(r, 6, inner: 0.55);
    case 'star7':
      return _poly(r, 7, inner: 0.5);
    case 'star8':
      return _poly(r, 8, inner: 0.6);
    case 'star12':
      return _poly(r, 12, inner: 0.72);
    case 'star16':
      return _poly(r, 16, inner: 0.8);
    case 'sparkle':
      final c = r.center;
      return Path()
        ..moveTo(c.dx, r.top)
        ..quadraticBezierTo(c.dx, c.dy, r.right, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, r.bottom)
        ..quadraticBezierTo(c.dx, c.dy, r.left, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, r.top);
    case 'seal12':
      return _poly(r, 12, inner: 0.9);
    case 'seal16':
      return _poly(r, 16, inner: 0.92);
    case 'seal24':
      return _poly(r, 24, inner: 0.94);
    case 'arrowR':
      return _pts(r, [
        [0, 0.3],
        [0.58, 0.3],
        [0.58, 0],
        [1, 0.5],
        [0.58, 1],
        [0.58, 0.7],
        [0, 0.7],
      ]);
    case 'arrowL':
      return _pts(r, [
        [1, 0.3],
        [0.42, 0.3],
        [0.42, 0],
        [0, 0.5],
        [0.42, 1],
        [0.42, 0.7],
        [1, 0.7],
      ]);
    case 'arrowU':
      return _pts(r, [
        [0.3, 1],
        [0.3, 0.42],
        [0, 0.42],
        [0.5, 0],
        [1, 0.42],
        [0.7, 0.42],
        [0.7, 1],
      ]);
    case 'arrowD':
      return _pts(r, [
        [0.3, 0],
        [0.3, 0.58],
        [0, 0.58],
        [0.5, 1],
        [1, 0.58],
        [0.7, 0.58],
        [0.7, 0],
      ]);
    case 'arrowDouble':
      return _pts(r, [
        [0, 0.5],
        [0.24, 0],
        [0.24, 0.3],
        [0.76, 0.3],
        [0.76, 0],
        [1, 0.5],
        [0.76, 1],
        [0.76, 0.7],
        [0.24, 0.7],
        [0.24, 1],
      ]);
    case 'chevronR':
      return _pts(r, [
        [0, 0],
        [0.62, 0],
        [1, 0.5],
        [0.62, 1],
        [0, 1],
        [0.38, 0.5],
      ]);
    case 'chevronL':
      return _pts(r, [
        [1, 0],
        [0.38, 0],
        [0, 0.5],
        [0.38, 1],
        [1, 1],
        [0.62, 0.5],
      ]);
    case 'speech':
      return _bubble(
        r,
        Path()
          ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(h * 0.18))),
      );
    case 'speechOval':
      return _bubble(r, Path()..addOval(body));
    case 'speechSquare':
      return _bubble(r, Path()..addRect(body));
    case 'flower6':
      return _petals(r, 6, 0.4);
    case 'flower8':
      return _petals(r, 8, 0.32);
    case 'clover':
      return _petals(r, 4, 0.5);
    case 'fish':
      return Path()
        ..moveTo(r.left, r.center.dy)
        ..quadraticBezierTo(
          r.left + w * 0.35,
          r.top - h * 0.1,
          r.left + w * 0.72,
          r.center.dy,
        )
        ..lineTo(r.right, r.top + h * 0.12)
        ..lineTo(r.right, r.bottom - h * 0.12)
        ..lineTo(r.left + w * 0.72, r.center.dy)
        ..quadraticBezierTo(
          r.left + w * 0.35,
          r.bottom + h * 0.1,
          r.left,
          r.center.dy,
        );
    case 'cat':
      final head = Path()
        ..addOval(Rect.fromLTWH(r.left, r.top + h * 0.18, w, h * 0.82));
      final ears = _pts(r, [
        [0.04, 0.5],
        [0.06, 0],
        [0.4, 0.26],
        [0.6, 0.26],
        [0.94, 0],
        [0.96, 0.5],
      ]);
      return Path.combine(PathOperation.union, head, ears);
    case 'bear':
      final head = Path()
        ..addOval(
          Rect.fromLTWH(r.left + w * 0.06, r.top + h * 0.1, w * 0.88, h * 0.9),
        );
      final e1 = Path()
        ..addOval(Rect.fromLTWH(r.left, r.top, w * 0.36, h * 0.36));
      final e2 = Path()
        ..addOval(Rect.fromLTWH(r.right - w * 0.36, r.top, w * 0.36, h * 0.36));
      return Path.combine(
        PathOperation.union,
        Path.combine(PathOperation.union, head, e1),
        e2,
      );
    case 'butterfly':
      final c = r.center;
      final wing = Path()
        ..addOval(Rect.fromLTWH(r.left, r.top, w * 0.5, h * 0.55))
        ..addOval(
          Rect.fromLTWH(r.left + w * 0.06, r.top + h * 0.5, w * 0.4, h * 0.45),
        )
        ..addOval(Rect.fromLTWH(c.dx, r.top, w * 0.5, h * 0.55))
        ..addOval(
          Rect.fromLTWH(c.dx + w * 0.04, r.top + h * 0.5, w * 0.4, h * 0.45),
        );
      return Path.combine(
        PathOperation.union,
        wing,
        Path()..addOval(
          Rect.fromLTWH(c.dx - w * 0.04, r.top + h * 0.1, w * 0.08, h * 0.8),
        ),
      );
    case 'bat':
      return _pts(r, [
        [0.5, 0.25],
        [0.58, 0.05],
        [0.64, 0.25],
        [0.9, 0.05],
        [1, 0.5],
        [0.86, 0.45],
        [0.78, 0.72],
        [0.64, 0.5],
        [0.5, 0.95],
        [0.36, 0.5],
        [0.22, 0.72],
        [0.14, 0.45],
        [0, 0.5],
        [0.1, 0.05],
        [0.36, 0.25],
        [0.42, 0.05],
      ]);
    case 'house':
      return _pts(r, [
        [0.5, 0],
        [1, 0.45],
        [0.86, 0.45],
        [0.86, 1],
        [0.14, 1],
        [0.14, 0.45],
        [0, 0.45],
      ]);
    case 'crown':
      return _pts(r, [
        [0, 0.85],
        [0, 0.2],
        [0.25, 0.5],
        [0.5, 0.05],
        [0.75, 0.5],
        [1, 0.2],
        [1, 0.85],
      ]);
    case 'flag':
      return _pts(r, [
        [0.08, 0],
        [0.14, 0],
        [0.14, 0.08],
        [1, 0.08],
        [0.78, 0.38],
        [1, 0.68],
        [0.14, 0.68],
        [0.14, 1],
        [0.08, 1],
      ]);
    case 'bookmark':
      return _pts(r, [
        [0.15, 0],
        [0.85, 0],
        [0.85, 1],
        [0.5, 0.74],
        [0.15, 1],
      ]);
    case 'gear':
      final p = _poly(r, 8, inner: 0.78, rot: -math.pi / 2);
      return Path.combine(
        PathOperation.difference,
        Path.combine(
          PathOperation.union,
          p,
          Path()..addOval(r.deflate(math.min(w, h) * 0.08)),
        ),
        Path()..addOval(r.deflate(math.min(w, h) * 0.34)),
      );
    case 'arch':
      return Path()
        ..moveTo(r.left, r.bottom)
        ..lineTo(r.left, r.top + w / 2)
        ..arcTo(Rect.fromLTWH(r.left, r.top, w, w), math.pi, math.pi, false)
        ..lineTo(r.right, r.bottom)
        ..close();
    case 'tombstone':
      return Path()
        ..moveTo(r.left, r.bottom)
        ..lineTo(r.left, r.top + w * 0.5)
        ..quadraticBezierTo(r.left, r.top, r.center.dx, r.top)
        ..quadraticBezierTo(r.right, r.top, r.right, r.top + w * 0.5)
        ..lineTo(r.right, r.bottom)
        ..close();
    case 'hourglass':
      return _pts(r, [
        [0.12, 0],
        [0.88, 0],
        [0.88, 0.1],
        [0.58, 0.5],
        [0.88, 0.9],
        [0.88, 1],
        [0.12, 1],
        [0.12, 0.9],
        [0.42, 0.5],
        [0.12, 0.1],
      ]);
    default:
      return idShapePath(id.isEmpty ? 'rrect' : id, r);
  }
}

/// A shape with the controls the page editor offers: fill (solid or
/// gradient), border, thickness, shadow.
class ScrapShapePainter extends CustomPainter {
  const ScrapShapePainter({
    required this.shape,
    required this.fill,
    this.fill2,
    this.border,
    this.borderWidth = 0,
    this.shadow = 0,
    this.filled = true,
  });
  final String shape;
  final Color fill;
  final Color? fill2, border;
  final double borderWidth, shadow;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = borderWidth / 2 + (shadow > 0 ? 0 : 0);
    final r = (Offset.zero & size).deflate(inset);
    if (r.width <= 0 || r.height <= 0) return;
    final path = scrapShapePath(shape, r);
    if (shadow > 0) {
      canvas.drawShadow(path, Colors.black, shadow, true);
    }
    if (filled) {
      final p = Paint()..isAntiAlias = true;
      if (fill2 != null) {
        p.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fill, fill2!],
        ).createShader(r);
      } else {
        p.color = fill;
      }
      canvas.drawPath(path, p);
    }
    if (borderWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..strokeJoin = StrokeJoin.round
          ..color = border ?? fill,
      );
    }
  }

  @override
  bool shouldRepaint(ScrapShapePainter o) =>
      o.shape != shape ||
      o.fill != fill ||
      o.fill2 != fill2 ||
      o.border != border ||
      o.borderWidth != borderWidth ||
      o.shadow != shadow ||
      o.filled != filled;
}
