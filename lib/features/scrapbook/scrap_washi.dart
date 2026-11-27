import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A washi-tape design: a pattern drawn in two colours.
class WashiPattern {
  const WashiPattern(this.id, this.name, this.kind, this.base, this.ink);
  final String id, name, kind;
  final int base, ink;
}

const washiPatterns = <WashiPattern>[
  WashiPattern('solid-pink', 'Blush', 'solid', 0xFFF8B6C9, 0xFFFFFFFF),
  WashiPattern('solid-mint', 'Mint', 'solid', 0xFFBFE8D4, 0xFFFFFFFF),
  WashiPattern('solid-sky', 'Sky', 'solid', 0xFFBBDDF7, 0xFFFFFFFF),
  WashiPattern('solid-butter', 'Butter', 'solid', 0xFFFBE7A1, 0xFFFFFFFF),
  WashiPattern('solid-lilac', 'Lilac', 'solid', 0xFFD9C8F5, 0xFFFFFFFF),
  WashiPattern('kraft', 'Kraft', 'kraft', 0xFFD2B48C, 0xFF8A6A3C),
  WashiPattern(
    'stripes-red',
    'Candy stripes',
    'stripes',
    0xFFFFFFFF,
    0xFFE8506E,
  ),
  WashiPattern(
    'stripes-navy',
    'Navy stripes',
    'stripes',
    0xFFF4EFE4,
    0xFF2D4A7A,
  ),
  WashiPattern('diag-green', 'Diagonal', 'diagonal', 0xFFF4F9EC, 0xFF6BA36B),
  WashiPattern('dots-white', 'Polka dots', 'dots', 0xFFF5A3B8, 0xFFFFFFFF),
  WashiPattern('dots-blue', 'Blue dots', 'dots', 0xFFFFF8E6, 0xFF4A9BD1),
  WashiPattern('hearts', 'Hearts', 'hearts', 0xFFFFE3EA, 0xFFE8506E),
  WashiPattern('stars-gold', 'Gold stars', 'stars', 0xFF26305A, 0xFFF6D86B),
  WashiPattern('stars-pink', 'Pink stars', 'stars', 0xFFFFF1F5, 0xFFF06292),
  WashiPattern('plaid', 'Plaid', 'plaid', 0xFFF1E6D0, 0xFFB5392B),
  WashiPattern('gingham', 'Gingham', 'gingham', 0xFFFFFFFF, 0xFF6FA2D6),
  WashiPattern('zigzag', 'Zigzag', 'zigzag', 0xFFFFF6D6, 0xFFE8903C),
  WashiPattern('checker', 'Checker', 'checker', 0xFFFFFFFF, 0xFF333333),
  WashiPattern('flowers', 'Little flowers', 'flowers', 0xFFFDF3EA, 0xFFE57C9B),
  WashiPattern('waves', 'Waves', 'waves', 0xFFE3F4FA, 0xFF3C86B5),
  WashiPattern('rainbow', 'Rainbow', 'rainbow', 0xFFFFFFFF, 0xFFFFFFFF),
  WashiPattern('confetti', 'Confetti', 'confetti', 0xFFFFFFFF, 0xFFFF7A9C),
  WashiPattern('triangles', 'Triangles', 'triangles', 0xFFFFF3E0, 0xFF3CA8A0),
  WashiPattern('grid', 'Graph', 'grid', 0xFFF6FFF6, 0xFF58A87A),
  WashiPattern('leaves', 'Leaves', 'leaves', 0xFFF4F9EC, 0xFF5B8F5B),
  WashiPattern('moons', 'Moons', 'moons', 0xFF2A2E57, 0xFFF3E7A6),
];

WashiPattern? washiById(String? id) {
  for (final w in washiPatterns) {
    if (w.id == id) return w;
  }
  return null;
}

/// Draws a strip of tape with torn ends. [tint] recolours the base.
class WashiPainter extends CustomPainter {
  const WashiPainter(this.pattern, {this.tint});
  final WashiPattern pattern;
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final base = tint ?? Color(pattern.base);
    final ink = Color(pattern.ink);
    // Torn, zig-zag ends.
    final path = Path()..moveTo(0, 0);
    const teeth = 7;
    for (var i = 0; i <= teeth; i++) {
      path.lineTo(i.isEven ? 0 : math.min(4, w * 0.04), h * i / teeth);
    }
    path.lineTo(w, h);
    for (var i = teeth; i >= 0; i--) {
      path.lineTo(w - (i.isEven ? 0 : math.min(4, w * 0.04)), h * i / teeth);
    }
    path.close();
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final p = Paint()..color = ink;
    final u = h / 14; // one design unit follows the tape's width
    switch (pattern.kind) {
      case 'stripes':
        for (var x = 0.0; x < w; x += u * 2.2) {
          canvas.drawRect(Rect.fromLTWH(x, 0, u * 1.1, h), p);
        }
      case 'diagonal':
        for (var x = -h; x < w; x += u * 2.4) {
          canvas.drawLine(
            Offset(x, h),
            Offset(x + h, 0),
            p..strokeWidth = u * 0.9,
          );
        }
      case 'dots':
        var row = 0;
        for (var y = u * 1.6; y < h + u; y += u * 3) {
          for (
            var x = u * 1.5 + (row.isOdd ? u * 1.5 : 0);
            x < w + u;
            x += u * 3
          ) {
            canvas.drawCircle(Offset(x, y), u * 0.55, p);
          }
          row++;
        }
      case 'hearts':
        for (var x = u * 1.5; x < w; x += u * 4) {
          for (final y in [u * 3.5, u * 10.0]) {
            _heart(canvas, Offset(x + (y > u * 5 ? u * 2 : 0), y), u * 0.9, p);
          }
        }
      case 'stars':
        for (var x = u * 1.5; x < w; x += u * 3.6) {
          for (final y in [u * 3.5, u * 10.0]) {
            _star(
              canvas,
              Offset(x + (y > u * 5 ? u * 1.8 : 0), y),
              u * 0.95,
              p,
            );
          }
        }
      case 'plaid':
        for (var x = u; x < w; x += u * 5) {
          canvas.drawRect(
            Rect.fromLTWH(x, 0, u * 1.6, h),
            p..color = ink.withValues(alpha: 0.45),
          );
        }
        for (var y = u * 2; y < h; y += u * 5) {
          canvas.drawRect(Rect.fromLTWH(0, y, w, u * 1.6), p);
        }
      case 'gingham':
        for (var x = 0.0; x < w; x += u * 2.4) {
          canvas.drawRect(
            Rect.fromLTWH(x, 0, u * 1.2, h),
            p..color = ink.withValues(alpha: 0.35),
          );
        }
        for (var y = 0.0; y < h; y += u * 2.4) {
          canvas.drawRect(Rect.fromLTWH(0, y, w, u * 1.2), p);
        }
      case 'zigzag':
        final z = Path()..moveTo(0, h * 0.35);
        var up = false;
        for (var x = 0.0; x <= w + u * 2; x += u * 1.6) {
          z.lineTo(x, h * (up ? 0.3 : 0.6));
          up = !up;
        }
        canvas.drawPath(
          z,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = u * 0.7,
        );
        canvas.drawPath(
          z.shift(Offset(0, h * 0.2)),
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = u * 0.7,
        );
      case 'checker':
        final s = h / 3;
        for (var x = 0.0, i = 0; x < w; x += s, i++) {
          for (var j = 0; j < 3; j++) {
            if ((i + j).isEven)
              canvas.drawRect(Rect.fromLTWH(x, j * s, s, s), p);
          }
        }
      case 'flowers':
        for (var x = u * 2; x < w; x += u * 4.5) {
          for (final y in [u * 3.5, u * 10.0]) {
            final c = Offset(x + (y > u * 5 ? u * 2.2 : 0), y);
            for (var k = 0; k < 5; k++) {
              final a = k * 2 * math.pi / 5;
              canvas.drawCircle(
                c + Offset(math.cos(a), math.sin(a)) * u * 0.75,
                u * 0.55,
                p,
              );
            }
            canvas.drawCircle(
              c,
              u * 0.4,
              Paint()..color = const Color(0xFFFFE08A),
            );
          }
        }
      case 'waves':
        for (var y = u * 3; y < h; y += u * 3.2) {
          final wv = Path()..moveTo(0, y);
          for (var x = 0.0; x < w; x += u * 4) {
            wv.quadraticBezierTo(x + u, y - u, x + u * 2, y);
            wv.quadraticBezierTo(x + u * 3, y + u, x + u * 4, y);
          }
          canvas.drawPath(
            wv,
            Paint()
              ..color = ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = u * 0.6,
          );
        }
      case 'rainbow':
        const cols = [
          Color(0xFFFF8A8A),
          Color(0xFFFFC27A),
          Color(0xFFFFEE8A),
          Color(0xFF9EE6A0),
          Color(0xFF8AC8FF),
          Color(0xFFC59AFF),
        ];
        for (var i = 0; i < cols.length; i++) {
          canvas.drawRect(
            Rect.fromLTWH(0, h * i / cols.length, w, h / cols.length + 0.5),
            Paint()..color = cols[i],
          );
        }
      case 'confetti':
        final r = math.Random(5);
        const cols = [
          Color(0xFFFF7A9C),
          Color(0xFF6FC7F2),
          Color(0xFFFFD34E),
          Color(0xFF8BD9A0),
        ];
        for (var i = 0; i < w / u * 1.4; i++) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(r.nextDouble() * w, r.nextDouble() * h),
              width: u * 0.9,
              height: u * 0.4,
            ),
            Paint()..color = cols[i % 4],
          );
        }
      case 'triangles':
        for (var x = 0.0; x < w; x += u * 3) {
          canvas.drawPath(
            Path()
              ..moveTo(x, h)
              ..lineTo(x + u * 1.5, h * 0.35)
              ..lineTo(x + u * 3, h)
              ..close(),
            p,
          );
        }
      case 'grid':
        for (var x = 0.0; x < w; x += u * 1.6) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), p..strokeWidth = 0.7);
        }
        for (var y = 0.0; y < h; y += u * 1.6) {
          canvas.drawLine(Offset(0, y), Offset(w, y), p);
        }
      case 'leaves':
        for (var x = u * 2; x < w; x += u * 4) {
          for (final y in [u * 3.5, u * 10.0]) {
            canvas.save();
            canvas.translate(x + (y > u * 5 ? u * 2 : 0), y);
            canvas.rotate(x * 0.7);
            canvas.drawPath(
              Path()
                ..moveTo(-u, 0)
                ..quadraticBezierTo(0, -u * 1.2, u, 0)
                ..quadraticBezierTo(0, u * 1.2, -u, 0),
              p,
            );
            canvas.restore();
          }
        }
      case 'moons':
        for (var x = u * 2; x < w; x += u * 4) {
          for (final y in [u * 3.5, u * 10.0]) {
            final c = Offset(x + (y > u * 5 ? u * 2 : 0), y);
            canvas.drawPath(
              Path.combine(
                PathOperation.difference,
                Path()..addOval(Rect.fromCircle(center: c, radius: u * 0.9)),
                Path()..addOval(
                  Rect.fromCircle(
                    center: c + Offset(u * 0.5, -u * 0.2),
                    radius: u * 0.8,
                  ),
                ),
              ),
              p,
            );
          }
        }
      case 'kraft':
        final r = math.Random(3);
        for (var i = 0; i < w * h / 40; i++) {
          canvas.drawRect(
            Rect.fromLTWH(r.nextDouble() * w, r.nextDouble() * h, u * 0.8, 0.6),
            Paint()..color = ink.withValues(alpha: 0.3),
          );
        }
    }
    // Sheen so it reads as tape.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.06),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();
  }

  static void _heart(Canvas c, Offset o, double s, Paint p) {
    final path = Path()
      ..moveTo(o.dx, o.dy + s * 0.8)
      ..cubicTo(
        o.dx - s * 1.3,
        o.dy - s * 0.1,
        o.dx - s * 0.5,
        o.dy - s,
        o.dx,
        o.dy - s * 0.3,
      )
      ..cubicTo(
        o.dx + s * 0.5,
        o.dy - s,
        o.dx + s * 1.3,
        o.dy - s * 0.1,
        o.dx,
        o.dy + s * 0.8,
      );
    c.drawPath(path, p);
  }

  static void _star(Canvas c, Offset o, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = o + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(path..close(), p);
  }

  @override
  bool shouldRepaint(WashiPainter o) => o.pattern != pattern || o.tint != tint;
}
