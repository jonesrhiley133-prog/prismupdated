import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative shapes a card layer can be (kind `shape`, shape id in `text`;
/// an empty id is the plain rounded rectangle old cards use).
const idShapeKinds = <String, String>{
  'rect': 'Rectangle',
  'rrect': 'Rounded',
  'ellipse': 'Ellipse',
  'ring': 'Ring',
  'triangle': 'Triangle',
  'diamond': 'Diamond',
  'star': 'Star',
  'burst': 'Starburst',
  'heart': 'Heart',
  'hex': 'Hexagon',
  'cross': 'Cross',
  'wave': 'Wave',
  'ribbon': 'Ribbon',
  'arc': 'Arc',
  'para': 'Slant',
  'ticket': 'Ticket',
  'tag': 'Tag',
  'scallop': 'Scallop',
  'blob': 'Blob',
  'shield': 'Shield',
  'moon': 'Moon',
  'cloud': 'Cloud',
  'drop': 'Drop',
  'leaf': 'Leaf',
  'flower': 'Flower',
  'bolt': 'Bolt',
  'brackets': 'Corners',
  'notch': 'Notched',
  'stamp': 'Stamp edge',
  'torn': 'Torn edge',
};

Path _poly(Rect r, int n, {double rot = -math.pi / 2, double inner = 1}) {
  final c = r.center;
  final rx = r.width / 2, ry = r.height / 2;
  final path = Path();
  final pts = n * (inner == 1 ? 1 : 2);
  for (var i = 0; i < pts; i++) {
    final a = rot + i * 2 * math.pi / pts;
    final k = inner == 1 ? 1.0 : (i.isEven ? 1.0 : inner);
    final p = Offset(c.dx + math.cos(a) * rx * k, c.dy + math.sin(a) * ry * k);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// The outline of shape [kind] fitted into [r].
Path idShapePath(String kind, Rect r) {
  final w = r.width, h = r.height;
  switch (kind) {
    case 'ellipse':
      return Path()..addOval(r);
    case 'ring':
      return Path()
        ..addOval(r)
        ..addOval(r.deflate(math.min(w, h) * 0.2))
        ..fillType = PathFillType.evenOdd;
    case 'triangle':
      return Path()
        ..moveTo(r.center.dx, r.top)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.left, r.bottom)
        ..close();
    case 'diamond':
      return Path()
        ..moveTo(r.center.dx, r.top)
        ..lineTo(r.right, r.center.dy)
        ..lineTo(r.center.dx, r.bottom)
        ..lineTo(r.left, r.center.dy)
        ..close();
    case 'star':
      return _poly(r, 5, inner: 0.42);
    case 'burst':
      return _poly(r, 12, inner: 0.72);
    case 'hex':
      return _poly(r, 6, rot: 0);
    case 'heart':
      return Path()
        ..moveTo(r.center.dx, r.bottom)
        ..cubicTo(
          r.left - w * 0.1,
          r.top + h * 0.62,
          r.left + w * 0.02,
          r.top - h * 0.12,
          r.center.dx,
          r.top + h * 0.28,
        )
        ..cubicTo(
          r.right - w * 0.02,
          r.top - h * 0.12,
          r.right + w * 0.1,
          r.top + h * 0.62,
          r.center.dx,
          r.bottom,
        )
        ..close();
    case 'cross':
      final t = math.min(w, h) * 0.34;
      return Path()
        ..addRect(Rect.fromCenter(center: r.center, width: w, height: t))
        ..addRect(Rect.fromCenter(center: r.center, width: t, height: h));
    case 'wave':
      final path = Path()..moveTo(r.left, r.top + h * 0.5);
      const waves = 3;
      for (var i = 0; i < waves; i++) {
        final x0 = r.left + w * i / waves, x1 = r.left + w * (i + 1) / waves;
        path.quadraticBezierTo(
          (x0 + x1) / 2,
          i.isEven ? r.top : r.bottom,
          x1,
          r.top + h * 0.5,
        );
      }
      return path
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.left, r.bottom)
        ..close();
    case 'ribbon':
      final n = w * 0.14;
      return Path()
        ..moveTo(r.left, r.top)
        ..lineTo(r.right, r.top)
        ..lineTo(r.right - n, r.center.dy)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.left, r.bottom)
        ..lineTo(r.left + n, r.center.dy)
        ..close();
    case 'arc':
      return Path()
        ..moveTo(r.left, r.bottom)
        ..arcTo(Rect.fromLTWH(r.left, r.top, w, h * 2), math.pi, math.pi, false)
        ..close();
    case 'para':
      final k = w * 0.22;
      return Path()
        ..moveTo(r.left + k, r.top)
        ..lineTo(r.right, r.top)
        ..lineTo(r.right - k, r.bottom)
        ..lineTo(r.left, r.bottom)
        ..close();
    case 'ticket':
      final d = math.min(w, h) * 0.16;
      return Path()
        ..moveTo(r.left, r.top)
        ..lineTo(r.right, r.top)
        ..arcToPoint(
          Offset(r.right, r.top + d * 2),
          radius: Radius.circular(d),
          clockwise: false,
        )
        ..lineTo(r.right, r.bottom - d * 2)
        ..arcToPoint(
          Offset(r.right, r.bottom),
          radius: Radius.circular(d),
          clockwise: false,
        )
        ..lineTo(r.left, r.bottom)
        ..lineTo(r.left, r.bottom - d * 2)
        ..arcToPoint(
          Offset(r.left, r.bottom - d * 4),
          radius: Radius.circular(d),
          clockwise: true,
        )
        ..lineTo(r.left, r.top)
        ..close();
    case 'tag':
      final k = math.min(w, h) * 0.3;
      return Path()
        ..moveTo(r.left + k, r.top)
        ..lineTo(r.right, r.top)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.left + k, r.bottom)
        ..lineTo(r.left, r.center.dy)
        ..close();
    case 'scallop':
      final path = Path();
      final n = math.max(4, (w / (h * 0.5)).round());
      final sw = w / n;
      path.moveTo(r.left, r.top + h * 0.5);
      path.lineTo(r.left, r.bottom - h * 0.2);
      for (var i = 0; i < n; i++) {
        path.arcToPoint(
          Offset(r.left + sw * (i + 1), r.bottom - h * 0.2),
          radius: Radius.circular(sw / 2),
          clockwise: false,
        );
      }
      path.lineTo(r.right, r.top);
      path.lineTo(r.left, r.top);
      return path..close();
    case 'blob':
      final c = r.center;
      final path = Path();
      const n = 10;
      for (var i = 0; i <= n; i++) {
        final a = i * 2 * math.pi / n;
        final k = 0.78 + 0.22 * math.sin(a * 3 + 1) * math.cos(a * 2);
        final p = Offset(
          c.dx + math.cos(a) * w / 2 * k,
          c.dy + math.sin(a) * h / 2 * k,
        );
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      return path..close();
    case 'shield':
      return Path()
        ..moveTo(r.left, r.top)
        ..lineTo(r.right, r.top)
        ..lineTo(r.right, r.top + h * 0.55)
        ..quadraticBezierTo(r.right, r.bottom - h * 0.15, r.center.dx, r.bottom)
        ..quadraticBezierTo(
          r.left,
          r.bottom - h * 0.15,
          r.left,
          r.top + h * 0.55,
        )
        ..close();
    case 'moon':
      final a = Path()..addOval(r);
      final b = Path()
        ..addOval(
          r.translate(w * 0.28, -h * 0.05).deflate(math.min(w, h) * 0.04),
        );
      return Path.combine(PathOperation.difference, a, b);
    case 'cloud':
      final path = Path()
        ..addOval(Rect.fromLTWH(r.left, r.top + h * 0.35, w * 0.45, h * 0.65));
      path.addOval(Rect.fromLTWH(r.left + w * 0.22, r.top, w * 0.5, h * 0.75));
      path.addOval(
        Rect.fromLTWH(r.left + w * 0.5, r.top + h * 0.3, w * 0.5, h * 0.7),
      );
      path.addRect(
        Rect.fromLTWH(r.left + w * 0.2, r.top + h * 0.55, w * 0.6, h * 0.45),
      );
      return path;
    case 'drop':
      return Path()
        ..moveTo(r.center.dx, r.top)
        ..cubicTo(
          r.right + w * 0.1,
          r.top + h * 0.55,
          r.right,
          r.bottom,
          r.center.dx,
          r.bottom,
        )
        ..cubicTo(
          r.left,
          r.bottom,
          r.left - w * 0.1,
          r.top + h * 0.55,
          r.center.dx,
          r.top,
        )
        ..close();
    case 'leaf':
      return Path()
        ..moveTo(r.left, r.bottom)
        ..quadraticBezierTo(r.left, r.top, r.right, r.top)
        ..quadraticBezierTo(r.right, r.bottom, r.left, r.bottom)
        ..close();
    case 'flower':
      final path = Path();
      final c = r.center;
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        path.addOval(
          Rect.fromCenter(
            center: Offset(
              c.dx + math.cos(a) * w * 0.28,
              c.dy + math.sin(a) * h * 0.28,
            ),
            width: w * 0.42,
            height: h * 0.42,
          ),
        );
      }
      return path;
    case 'bolt':
      return Path()
        ..moveTo(r.left + w * 0.6, r.top)
        ..lineTo(r.left + w * 0.1, r.top + h * 0.58)
        ..lineTo(r.left + w * 0.46, r.top + h * 0.58)
        ..lineTo(r.left + w * 0.34, r.bottom)
        ..lineTo(r.right - w * 0.05, r.top + h * 0.38)
        ..lineTo(r.left + w * 0.56, r.top + h * 0.38)
        ..close();
    case 'notch':
      final k = math.min(w, h) * 0.22;
      return Path()
        ..moveTo(r.left + k, r.top)
        ..lineTo(r.right - k, r.top)
        ..lineTo(r.right, r.top + k)
        ..lineTo(r.right, r.bottom - k)
        ..lineTo(r.right - k, r.bottom)
        ..lineTo(r.left + k, r.bottom)
        ..lineTo(r.left, r.bottom - k)
        ..lineTo(r.left, r.top + k)
        ..close();
    case 'stamp':
      final path = Path();
      final step = math.min(w, h) * 0.12;
      final nx = math.max(4, (w / step).round()),
          ny = math.max(4, (h / step).round());
      path.addRect(r.deflate(step * 0.5));
      for (var i = 0; i <= nx; i++) {
        path.addOval(
          Rect.fromCircle(
            center: Offset(r.left + w * i / nx, r.top),
            radius: step * 0.32,
          ),
        );
        path.addOval(
          Rect.fromCircle(
            center: Offset(r.left + w * i / nx, r.bottom),
            radius: step * 0.32,
          ),
        );
      }
      for (var j = 1; j < ny; j++) {
        path.addOval(
          Rect.fromCircle(
            center: Offset(r.left, r.top + h * j / ny),
            radius: step * 0.32,
          ),
        );
        path.addOval(
          Rect.fromCircle(
            center: Offset(r.right, r.top + h * j / ny),
            radius: step * 0.32,
          ),
        );
      }
      return path;
    case 'torn':
      final rnd = math.Random(5);
      final path = Path()..moveTo(r.left, r.top);
      path.lineTo(r.right, r.top);
      path.lineTo(r.right, r.bottom - h * 0.1);
      final n = math.max(8, (w / 6).round());
      for (var i = n; i >= 0; i--) {
        path.lineTo(r.left + w * i / n, r.bottom - h * 0.1 * rnd.nextDouble());
      }
      return path..close();
    case 'brackets':
      final k = math.min(w, h) * 0.3, t = math.min(w, h) * 0.07;
      final path = Path();
      for (final (sx, sy) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)]) {
        final ox = r.left + w * sx, oy = r.top + h * sy;
        final dx = sx == 0 ? 1.0 : -1.0, dy = sy == 0 ? 1.0 : -1.0;
        path.addRect(
          Rect.fromPoints(Offset(ox, oy), Offset(ox + dx * k, oy + dy * t)),
        );
        path.addRect(
          Rect.fromPoints(Offset(ox, oy), Offset(ox + dx * t, oy + dy * k)),
        );
      }
      return path;
    case 'rect':
      return Path()..addRect(r);
    case 'rrect':
    default:
      return Path()..addRRect(
        RRect.fromRectAndRadius(r, Radius.circular(math.min(w, h) * 0.12)),
      );
  }
}

/// Fills or outlines one decorative shape, optionally as a gradient.
class IdShapePainter extends CustomPainter {
  IdShapePainter({
    required this.kind,
    required this.color,
    this.color2,
    this.stroke = 0,
  });
  final String kind;
  final Color color;
  final Color? color2;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final path = idShapePath(
      kind.isEmpty ? 'rrect' : kind,
      r.deflate(
        stroke > 0 ? math.min(size.width, size.height) * stroke / 2 : 0,
      ),
    );
    final paint = Paint()..isAntiAlias = true;
    if (color2 != null && stroke == 0) {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, color2!],
      ).createShader(r);
    } else {
      paint.color = color;
    }
    if (stroke > 0) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, math.min(size.width, size.height) * stroke);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(IdShapePainter o) =>
      o.kind != kind ||
      o.color != color ||
      o.color2 != color2 ||
      o.stroke != stroke;
}

/// Extra background patterns, beyond the original few.
const idExtraPatterns = <String>[
  'hex',
  'diamonds',
  'scanlines',
  'checker',
  'floral',
  'circuit',
  'paper',
  'zigzag',
  'confetti',
  'bokeh',
  'film',
  'gingham',
  'plaid',
  'rays',
  'brick',
  'bubbles',
  'notes',
  'topo',
  'crosshatch',
  'scales',
  'snow',
  'grunge',
];

/// Paints one of [idExtraPatterns]. Returns false for unknown kinds.
bool paintIdExtraPattern(Canvas canvas, Size s, String kind, Color a, Color b) {
  final ink = Color.lerp(a, b, 0.5)!;
  final dark = Color.lerp(a, Colors.black, 0.35)!;
  final light = Color.lerp(a, Colors.white, 0.55)!;
  final line = Paint()
    ..color = dark.withValues(alpha: 0.22)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9;
  final fill = Paint()..color = dark.withValues(alpha: 0.12);
  switch (kind) {
    case 'hex':
      const r = 12.0;
      final dx = r * 1.5, dy = r * math.sqrt(3);
      for (var col = 0; col * dx < s.width + r; col++) {
        for (var row = 0; row * dy < s.height + dy; row++) {
          final c = Offset(col * dx, row * dy + (col.isOdd ? dy / 2 : 0));
          canvas.drawPath(
            _poly(Rect.fromCircle(center: c, radius: r), 6, rot: 0),
            line,
          );
        }
      }
    case 'diamonds':
      for (var x = -s.height; x < s.width + s.height; x += 16) {
        canvas.drawLine(Offset(x, 0), Offset(x + s.height, s.height), line);
        canvas.drawLine(Offset(x + s.height, 0), Offset(x, s.height), line);
      }
    case 'scanlines':
      for (var y = 0.0; y < s.height; y += 4) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, s.width, 1.2),
          Paint()..color = Colors.black.withValues(alpha: 0.12),
        );
      }
    case 'checker':
      const t = 14.0;
      for (var i = 0; i * t < s.width; i++) {
        for (var j = 0; j * t < s.height; j++) {
          if ((i + j).isEven)
            canvas.drawRect(Rect.fromLTWH(i * t, j * t, t, t), fill);
        }
      }
    case 'floral':
      final rnd = math.Random(3);
      for (var i = 0; i < 26; i++) {
        final c = Offset(
          rnd.nextDouble() * s.width,
          rnd.nextDouble() * s.height,
        );
        final r = 3 + rnd.nextDouble() * 4;
        for (var k = 0; k < 5; k++) {
          final ang = k * 2 * math.pi / 5;
          canvas.drawCircle(
            c + Offset(math.cos(ang), math.sin(ang)) * r,
            r * 0.7,
            Paint()..color = light.withValues(alpha: 0.55),
          );
        }
        canvas.drawCircle(
          c,
          r * 0.5,
          Paint()..color = ink.withValues(alpha: 0.5),
        );
      }
    case 'circuit':
      final rnd = math.Random(11);
      final p = Paint()
        ..color = light.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (var i = 0; i < 16; i++) {
        var x = rnd.nextDouble() * s.width, y = rnd.nextDouble() * s.height;
        final path = Path()..moveTo(x, y);
        for (var k = 0; k < 4; k++) {
          if (rnd.nextBool()) {
            x += (rnd.nextDouble() - 0.3) * 40;
          } else {
            y += (rnd.nextDouble() - 0.3) * 30;
          }
          path.lineTo(x, y);
        }
        canvas.drawPath(path, p);
        canvas.drawCircle(
          Offset(x, y),
          2.2,
          Paint()..color = light.withValues(alpha: 0.5),
        );
      }
    case 'paper' || 'grunge':
      final rnd = math.Random(kind == 'paper' ? 2 : 9);
      final n = kind == 'paper' ? 220 : 160;
      for (var i = 0; i < n; i++) {
        final c = Offset(
          rnd.nextDouble() * s.width,
          rnd.nextDouble() * s.height,
        );
        final r = kind == 'paper'
            ? rnd.nextDouble() * 0.8
            : rnd.nextDouble() * 2.4;
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = (rnd.nextBool() ? Colors.black : Colors.white).withValues(
              alpha: kind == 'paper' ? 0.06 : 0.1,
            ),
        );
      }
      if (kind == 'grunge') {
        for (var i = 0; i < 9; i++) {
          final y = rnd.nextDouble() * s.height;
          canvas.drawLine(
            Offset(rnd.nextDouble() * s.width * 0.4, y),
            Offset(
              s.width * (0.5 + rnd.nextDouble() * 0.5),
              y + rnd.nextDouble() * 6 - 3,
            ),
            Paint()
              ..color = Colors.black.withValues(alpha: 0.12)
              ..strokeWidth = 1.2,
          );
        }
      }
    case 'zigzag':
      for (var y = 8.0; y < s.height; y += 18) {
        final path = Path()..moveTo(0, y);
        for (var x = 0.0; x < s.width; x += 12) {
          path.lineTo(x + 6, y - 5);
          path.lineTo(x + 12, y);
        }
        canvas.drawPath(path, line);
      }
    case 'confetti':
      final rnd = math.Random(4);
      final colors = [light, ink, dark, Colors.white];
      for (var i = 0; i < 44; i++) {
        canvas.save();
        canvas.translate(
          rnd.nextDouble() * s.width,
          rnd.nextDouble() * s.height,
        );
        canvas.rotate(rnd.nextDouble() * math.pi);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 6, height: 2.6),
          Paint()..color = colors[i % colors.length].withValues(alpha: 0.55),
        );
        canvas.restore();
      }
    case 'bokeh':
      final rnd = math.Random(6);
      for (var i = 0; i < 18; i++) {
        canvas.drawCircle(
          Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height),
          6 + rnd.nextDouble() * 18,
          Paint()
            ..color = Colors.white.withValues(
              alpha: 0.05 + rnd.nextDouble() * 0.1,
            ),
        );
      }
    case 'film':
      for (var x = 4.0; x < s.width; x += 14) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 3, 7, 5),
            const Radius.circular(1.2),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.35),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, s.height - 8, 7, 5),
            const Radius.circular(1.2),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.35),
        );
      }
    case 'gingham':
      const t = 16.0;
      for (var i = 0; i * t < s.width; i++) {
        if (i.isEven)
          canvas.drawRect(Rect.fromLTWH(i * t, 0, t, s.height), fill);
      }
      for (var j = 0; j * t < s.height; j++) {
        if (j.isEven)
          canvas.drawRect(Rect.fromLTWH(0, j * t, s.width, t), fill);
      }
    case 'plaid':
      for (var x = 10.0; x < s.width; x += 34) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 6, s.height), fill);
        canvas.drawLine(Offset(x + 12, 0), Offset(x + 12, s.height), line);
      }
      for (var y = 8.0; y < s.height; y += 30) {
        canvas.drawRect(Rect.fromLTWH(0, y, s.width, 5), fill);
        canvas.drawLine(Offset(0, y + 11), Offset(s.width, y + 11), line);
      }
    case 'rays':
      final c = Offset(s.width * 0.8, s.height * 1.1);
      for (var i = 0; i < 24; i++) {
        final a0 = math.pi + i * math.pi / 24, a1 = a0 + math.pi / 48;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(
              c.dx + math.cos(a0) * s.width * 2,
              c.dy + math.sin(a0) * s.width * 2,
            )
            ..lineTo(
              c.dx + math.cos(a1) * s.width * 2,
              c.dy + math.sin(a1) * s.width * 2,
            )
            ..close(),
          fill,
        );
      }
    case 'brick':
      const bh = 12.0, bw = 28.0;
      for (var j = 0; j * bh < s.height; j++) {
        canvas.drawLine(Offset(0, j * bh), Offset(s.width, j * bh), line);
        for (var x = (j.isOdd ? bw / 2 : 0.0); x < s.width; x += bw) {
          canvas.drawLine(Offset(x, j * bh), Offset(x, (j + 1) * bh), line);
        }
      }
    case 'bubbles':
      final rnd = math.Random(8);
      for (var i = 0; i < 24; i++) {
        final c = Offset(
          rnd.nextDouble() * s.width,
          rnd.nextDouble() * s.height,
        );
        final r = 3 + rnd.nextDouble() * 9;
        canvas.drawCircle(
          c,
          r,
          Paint()..color = Colors.white.withValues(alpha: 0.12),
        );
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white.withValues(alpha: 0.4)
            ..strokeWidth = 0.8,
        );
      }
    case 'notes':
      for (var y = 14.0; y < s.height; y += 9) {
        canvas.drawLine(Offset(0, y), Offset(s.width, y), line);
      }
      final rnd = math.Random(12);
      for (var i = 0; i < 12; i++) {
        final c = Offset(
          rnd.nextDouble() * s.width,
          14 + (rnd.nextInt(((s.height - 20) / 9).floor())) * 9,
        );
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 6, height: 4.4),
          Paint()..color = dark.withValues(alpha: 0.35),
        );
        canvas.drawLine(
          c + const Offset(3, 0),
          c + const Offset(3, -14),
          Paint()
            ..color = dark.withValues(alpha: 0.35)
            ..strokeWidth = 1,
        );
      }
    case 'topo':
      for (var i = 0; i < 12; i++) {
        final path = Path();
        for (var x = 0.0; x <= s.width; x += 5) {
          final y =
              s.height * (i / 11) +
              math.sin(x / 26 + i) * 7 +
              math.cos(x / 41 - i * 0.5) * 5;
          x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        canvas.drawPath(path, line);
      }
    case 'crosshatch':
      for (var x = -s.height; x < s.width; x += 7) {
        canvas.drawLine(
          Offset(x, s.height),
          Offset(x + s.height, 0),
          line..strokeWidth = 0.6,
        );
      }
      for (var x = 0.0; x < s.width + s.height; x += 7) {
        canvas.drawLine(
          Offset(x, s.height),
          Offset(x - s.height, 0),
          line..strokeWidth = 0.6,
        );
      }
    case 'scales':
      const r = 10.0;
      for (var j = 0; j * r < s.height + r; j++) {
        for (var x = (j.isOdd ? r : 0.0); x < s.width + r; x += r * 2) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x, j * r), radius: r),
            0,
            math.pi,
            false,
            line,
          );
        }
      }
    case 'snow':
      final rnd = math.Random(2);
      for (var i = 0; i < 46; i++) {
        canvas.drawCircle(
          Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height),
          0.8 + rnd.nextDouble() * 2.2,
          Paint()..color = Colors.white.withValues(alpha: 0.7),
        );
      }
    default:
      return false;
  }
  return true;
}
