import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const _tau = math.pi * 2;

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;

/// Draws one procedural texture or material over [size].
///
/// Everything is generated from a seed, so a texture looks the same every
/// time, on every device, without downloading or storing a single image.
/// [scale] stretches the pattern, [intensity] fades it between barely-there
/// and bold, and [c1] / [c2] are the base and ink colours.
void paintScrapTexture(
  Canvas canvas,
  Size size, {
  required String kind,
  required Color c1,
  required Color c2,
  int seed = 1,
  double scale = 1,
  double intensity = 1,
}) {
  if (size.width <= 0 || size.height <= 0) return;
  final rnd = math.Random(seed);
  final w = size.width, h = size.height;
  final u = (w / 360) * scale; // one design unit
  // Counts follow the area in design units, so a thumbnail has the same
  // density as a full page.
  final area = (w * h) / (u * u);
  final a = intensity.clamp(0.0, 2.0);
  Paint ink(
    double alpha, {
    double stroke = 1,
    PaintingStyle style = PaintingStyle.fill,
  }) => Paint()
    ..color = c2.withValues(alpha: (alpha * a).clamp(0.0, 1.0))
    ..strokeWidth = stroke
    ..style = style
    ..isAntiAlias = true;
  Paint light(double alpha) =>
      Paint()
        ..color = Colors.white.withValues(alpha: (alpha * a).clamp(0.0, 1.0));
  Paint dark(double alpha) =>
      Paint()
        ..color = Colors.black.withValues(alpha: (alpha * a).clamp(0.0, 1.0));
  final rect = Offset.zero & size;
  canvas.save();
  canvas.clipRect(rect);
  canvas.drawRect(rect, Paint()..color = c1);

  void speckle(int n, double r, Paint Function() paint) {
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
        r * (0.4 + rnd.nextDouble()),
        paint(),
      );
    }
  }

  void fibers(int n, double len, double alpha, Color col) {
    for (var i = 0; i < n; i++) {
      final x = rnd.nextDouble() * w, y = rnd.nextDouble() * h;
      final ang = rnd.nextDouble() * _tau;
      final l = len * (0.4 + rnd.nextDouble());
      final p = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(
          x + math.cos(ang + 0.6) * l * 0.5,
          y + math.sin(ang + 0.6) * l * 0.5,
          x + math.cos(ang) * l,
          y + math.sin(ang) * l,
        );
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6 * u
          ..color = col.withValues(alpha: (alpha * a).clamp(0.0, 1.0)),
      );
    }
  }

  void vignette(double strength, Color col) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w / 2, h / 2),
          math.max(w, h) * 0.75,
          [
            col.withValues(alpha: 0),
            col.withValues(alpha: (strength * a).clamp(0.0, 1.0)),
          ],
          const [0.55, 1.0],
        ),
    );
  }

  void blobs(int n, double minR, double maxR, List<Color> cols, double alpha) {
    for (var i = 0; i < n; i++) {
      final c = cols[i % cols.length];
      final r = (minR + rnd.nextDouble() * (maxR - minR)) * u;
      final cx = rnd.nextDouble() * w, cy = rnd.nextDouble() * h;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(cx, cy), r, [
            c.withValues(alpha: (alpha * a).clamp(0.0, 1.0)),
            c.withValues(alpha: 0),
          ]),
      );
    }
  }

  void star(Offset c, double r, Paint p, {int points = 4}) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isEven ? r : r * 0.35;
      final ang = i * math.pi / points - math.pi / 2;
      final pt = c + Offset(math.cos(ang) * rr, math.sin(ang) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), p);
  }

  void heart(Offset c, double s, Paint p) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.9)
      ..cubicTo(
        c.dx - s * 1.4,
        c.dy - s * 0.1,
        c.dx - s * 0.5,
        c.dy - s * 1.1,
        c.dx,
        c.dy - s * 0.3,
      )
      ..cubicTo(
        c.dx + s * 0.5,
        c.dy - s * 1.1,
        c.dx + s * 1.4,
        c.dy - s * 0.1,
        c.dx,
        c.dy + s * 0.9,
      )
      ..close();
    canvas.drawPath(path, p);
  }

  void flower(Offset c, double r, Color petal, Color centre) {
    for (var i = 0; i < 5; i++) {
      final ang = i * _tau / 5;
      canvas.drawCircle(
        c + Offset(math.cos(ang), math.sin(ang)) * r * 0.62,
        r * 0.5,
        Paint()..color = petal.withValues(alpha: (0.85 * a).clamp(0.0, 1.0)),
      );
    }
    canvas.drawCircle(
      c,
      r * 0.32,
      Paint()..color = centre.withValues(alpha: (0.95 * a).clamp(0.0, 1.0)),
    );
  }

  void leaf(Offset c, double len, double ang, Paint p) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(ang);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.5, -len * 0.38, len, 0)
      ..quadraticBezierTo(len * 0.5, len * 0.38, 0, 0);
    canvas.drawPath(path, p);
    canvas.restore();
  }

  switch (kind) {
    // ── Paper ─────────────────────────────────────────────────────────
    case 'paper':
      speckle((area / 160).round(), 0.5 * u, () => ink(0.06));
    case 'aged':
      blobs(7, 40, 120, [c2, const Color(0xFF8B5A2B)], 0.16);
      vignette(0.4, const Color(0xFF6B4A1E));
      speckle((area / 400).round(), 0.8 * u, () => dark(0.07));
    case 'fibers':
      fibers((area / 700).round(), 14 * u, 0.22, c2);
    case 'handmade':
      fibers((area / 500).round(), 18 * u, 0.3, c2);
      speckle((area / 3000).round(), 1.2 * u, () => ink(0.18));
      canvas.drawRect(
        rect.deflate(2 * u),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * u
          ..color = Colors.white.withValues(alpha: 0.35),
      );
    case 'construction':
      fibers((area / 450).round(), 10 * u, 0.2, Colors.black);
      speckle((area / 700).round(), 0.7 * u, () => light(0.18));
    case 'parchment':
      blobs(9, 50, 130, [c2, const Color(0xFFB5832F)], 0.2);
      vignette(0.55, const Color(0xFF5A3A12));
      for (var i = 0; i < 6; i++) {
        final p = Path()..moveTo(rnd.nextDouble() * w, rnd.nextDouble() * h);
        for (var k = 0; k < 4; k++) {
          p.relativeQuadraticBezierTo(
            (rnd.nextDouble() - .5) * 60 * u,
            (rnd.nextDouble() - .5) * 60 * u,
            (rnd.nextDouble() - .5) * 80 * u,
            (rnd.nextDouble() - .5) * 80 * u,
          );
        }
        canvas.drawPath(
          p,
          ink(0.06, stroke: 0.7 * u, style: PaintingStyle.stroke),
        );
      }
    case 'crumple':
      for (var i = 0; i < (area / 2600).round(); i++) {
        final cx = rnd.nextDouble() * w, cy = rnd.nextDouble() * h;
        final p = Path()..moveTo(cx, cy);
        for (var k = 0; k < 4; k++) {
          p.lineTo(
            cx + (rnd.nextDouble() - .5) * 70 * u,
            cy + (rnd.nextDouble() - .5) * 70 * u,
          );
        }
        canvas.drawPath(
          p..close(),
          rnd.nextBool()
              ? light(0.1 + rnd.nextDouble() * 0.12)
              : dark(0.04 + rnd.nextDouble() * 0.08),
        );
      }
    case 'newsprint':
      final colW = 54 * u;
      for (var x = 12 * u; x < w - colW * 0.6; x += colW + 8 * u) {
        for (var y = 18 * u; y < h - 8 * u; y += 6 * u) {
          final len = colW * (0.55 + rnd.nextDouble() * 0.45);
          canvas.drawRect(Rect.fromLTWH(x, y, len, 2.2 * u), ink(0.28));
        }
        canvas.drawRect(Rect.fromLTWH(x, 6 * u, colW, 7 * u), ink(0.42));
      }
      speckle((area / 500).round(), 0.5 * u, () => dark(0.05));
    case 'watercolor':
      blobs(7, 90, 230, [
        c2,
        _mix(c2, Colors.white, 0.4),
        _mix(c2, c1, 0.5),
      ], 0.32);
      fibers((area / 2500).round(), 12 * u, 0.12, c2);
    case 'wash2':
      blobs(6, 100, 260, [
        c2,
        const Color(0xFFF4A6B8),
        const Color(0xFF8EC5E8),
      ], 0.28);
    // ── Notebook and graph ────────────────────────────────────────────
    case 'ruled' || 'ruledWide' || 'ruledNarrow' || 'ruledCollege':
      final step =
          (switch (kind) {
            'ruledWide' => 32.0,
            'ruledNarrow' => 15.0,
            'ruledCollege' => 20.0,
            _ => 24.0,
          }) *
          u;
      for (var y = step * 1.6; y < h; y += step) {
        canvas.drawLine(Offset(0, y), Offset(w, y), ink(0.5, stroke: 0.9 * u));
      }
      canvas.drawLine(
        Offset(step * 2.3, 0),
        Offset(step * 2.3, h),
        Paint()
          ..color = const Color(
            0xFFE74C3C,
          ).withValues(alpha: (0.6 * a).clamp(0.0, 1.0))
          ..strokeWidth = 1.2 * u,
      );
      if (kind == 'ruledCollege') {
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(step * 0.8, h * (0.2 + i * 0.3)),
            5 * u,
            dark(0.18),
          );
        }
      }
    case 'grid' || 'gridCoarse' || 'graphPaper':
      final step =
          (switch (kind) {
            'gridCoarse' => 28.0,
            'graphPaper' => 10.0,
            _ => 16.0,
          }) *
          u;
      for (var x = step; x < w; x += step) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, h),
          ink(
            kind == 'graphPaper' && ((x / step).round() % 5 == 0) ? 0.55 : 0.28,
            stroke: 0.7 * u,
          ),
        );
      }
      for (var y = step; y < h; y += step) {
        canvas.drawLine(
          Offset(0, y),
          Offset(w, y),
          ink(
            kind == 'graphPaper' && ((y / step).round() % 5 == 0) ? 0.55 : 0.28,
            stroke: 0.7 * u,
          ),
        );
      }
    case 'dotGrid':
      final step = 16 * u;
      for (var x = step; x < w; x += step) {
        for (var y = step; y < h; y += step) {
          canvas.drawCircle(Offset(x, y), 1.1 * u, ink(0.5));
        }
      }
    case 'isoDots':
      final step = 18 * u;
      var row = 0;
      for (var y = step; y < h; y += step * 0.866) {
        for (var x = step + (row.isOdd ? step / 2 : 0); x < w; x += step) {
          canvas.drawCircle(Offset(x, y), 1.1 * u, ink(0.5));
        }
        row++;
      }
    // ── Cloth ─────────────────────────────────────────────────────────
    case 'linen':
      for (var x = 0.0; x < w; x += 2.4 * u) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, h),
          ink(0.05 + rnd.nextDouble() * 0.09, stroke: 0.7 * u),
        );
      }
      for (var y = 0.0; y < h; y += 2.4 * u) {
        canvas.drawLine(
          Offset(0, y),
          Offset(w, y),
          light(0.06 + rnd.nextDouble() * 0.1)..strokeWidth = 0.7 * u,
        );
      }
    case 'canvas':
      for (var x = 0.0; x < w; x += 3 * u) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, h),
          dark(0.05)..strokeWidth = 1 * u,
        );
      }
      for (var y = 0.0; y < h; y += 3 * u) {
        canvas.drawLine(
          Offset(0, y),
          Offset(w, y),
          light(0.09)..strokeWidth = 1 * u,
        );
      }
      speckle((area / 900).round(), 0.5 * u, () => dark(0.05));
    case 'denim':
      for (var d = -h; d < w; d += 2.6 * u) {
        canvas.drawLine(
          Offset(d, h),
          Offset(d + h, 0),
          (rnd.nextBool() ? light(0.11) : dark(0.1))..strokeWidth = 1 * u,
        );
      }
      speckle((area / 900).round(), 0.6 * u, () => light(0.1));
    case 'corduroy':
      for (var x = 0.0; x < w; x += 5 * u) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, h),
          dark(0.16)..strokeWidth = 1.4 * u,
        );
        canvas.drawLine(
          Offset(x + 2.2 * u, 0),
          Offset(x + 2.2 * u, h),
          light(0.1)..strokeWidth = 1.2 * u,
        );
      }
    case 'tweed':
      for (var i = 0; i < (area / 40).round(); i++) {
        final x = rnd.nextDouble() * w, y = rnd.nextDouble() * h;
        canvas.drawRect(
          Rect.fromLTWH(x, y, 2.2 * u, 1 * u),
          [dark(0.2), light(0.18), ink(0.3)][i % 3],
        );
      }
    case 'felt':
      speckle(
        (area / 70).round(),
        0.55 * u,
        () => rnd.nextBool() ? light(0.12) : dark(0.1),
      );
      fibers((area / 1200).round(), 7 * u, 0.15, Colors.white);
    case 'burlap':
      for (var x = 0.0; x < w; x += 4.5 * u) {
        canvas.drawLine(
          Offset(x + rnd.nextDouble() * u, 0),
          Offset(x + rnd.nextDouble() * u, h),
          dark(0.18)..strokeWidth = 1.5 * u,
        );
      }
      for (var y = 0.0; y < h; y += 4.5 * u) {
        canvas.drawLine(
          Offset(0, y + rnd.nextDouble() * u),
          Offset(w, y + rnd.nextDouble() * u),
          light(0.14)..strokeWidth = 1.5 * u,
        );
      }
    case 'knit':
      final sx = 9 * u, sy = 11 * u;
      for (var y = 0.0; y < h; y += sy) {
        for (var x = 0.0; x < w; x += sx) {
          final p = Path()
            ..moveTo(x, y)
            ..lineTo(x + sx / 2, y + sy * 0.9)
            ..lineTo(x + sx, y);
          canvas.drawPath(
            p,
            light(0.22)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2 * u
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawPath(
            p.shift(Offset(0.7 * u, 0.7 * u)),
            dark(0.2)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4 * u
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    case 'silk':
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(w, h),
            [
              light(0.0).color,
              light(0.34).color,
              dark(0.0).color,
              light(0.24).color,
              dark(0.18).color,
            ],
            const [0, 0.25, 0.5, 0.75, 1],
          ),
      );
    case 'velvet':
      speckle(
        (area / 55).round(),
        0.5 * u,
        () => rnd.nextBool() ? light(0.1) : dark(0.12),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, 0),
            Offset(w, h),
            [light(0.18).color, dark(0.0).color, dark(0.22).color],
            const [0, 0.5, 1],
          ),
      );
    case 'suede':
      speckle(
        (area / 45).round(),
        0.5 * u,
        () => rnd.nextBool() ? light(0.1) : dark(0.08),
      );
    case 'quilted':
      final s = 34 * u;
      for (var d = -h; d < w + h; d += s) {
        canvas.drawLine(
          Offset(d, 0),
          Offset(d + h, h),
          ink(0.5, stroke: 1.1 * u),
        );
        canvas.drawLine(
          Offset(d + h, 0),
          Offset(d, h),
          ink(0.5, stroke: 1.1 * u),
        );
      }
      for (var y = 0.0; y < h; y += s) {
        for (var x = 0.0; x < w; x += s) {
          canvas.drawCircle(
            Offset(x + s / 2, y),
            s * 0.45,
            Paint()
              ..shader = ui.Gradient.radial(Offset(x + s / 2, y), s * 0.5, [
                light(0.2).color,
                dark(0.12).color,
              ]),
          );
        }
      }
    case 'tartan':
      for (var x = 0.0; x < w; x += 44 * u) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 16 * u, h), ink(0.28));
        canvas.drawRect(Rect.fromLTWH(x + 20 * u, 0, 4 * u, h), light(0.4));
      }
      for (var y = 0.0; y < h; y += 44 * u) {
        canvas.drawRect(Rect.fromLTWH(0, y, w, 16 * u), ink(0.28));
        canvas.drawRect(Rect.fromLTWH(0, y + 20 * u, w, 4 * u), light(0.4));
      }
    case 'gingham':
      for (var x = 0.0; x < w; x += 24 * u) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 12 * u, h), ink(0.22));
      }
      for (var y = 0.0; y < h; y += 24 * u) {
        canvas.drawRect(Rect.fromLTWH(0, y, w, 12 * u), ink(0.22));
      }
    case 'plaid':
      for (var x = 12 * u; x < w; x += 70 * u) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 14 * u, h), ink(0.22));
        canvas.drawLine(
          Offset(x + 30 * u, 0),
          Offset(x + 30 * u, h),
          light(0.5)..strokeWidth = 1.5 * u,
        );
      }
      for (var y = 12 * u; y < h; y += 70 * u) {
        canvas.drawRect(Rect.fromLTWH(0, y, w, 14 * u), ink(0.22));
        canvas.drawLine(
          Offset(0, y + 30 * u),
          Offset(w, y + 30 * u),
          light(0.5)..strokeWidth = 1.5 * u,
        );
      }
    // ── Hard surfaces ─────────────────────────────────────────────────
    case 'leather':
      final s = 5 * u;
      for (var y = 0.0; y < h; y += s) {
        for (var x = 0.0; x < w; x += s) {
          final ox = (rnd.nextDouble() - .5) * s,
              oy = (rnd.nextDouble() - .5) * s;
          canvas.drawCircle(
            Offset(x + ox, y + oy),
            s * (0.35 + rnd.nextDouble() * 0.25),
            rnd.nextBool() ? dark(0.13) : light(0.07),
          );
        }
      }
      vignette(0.35, Colors.black);
    case 'snake':
      final s = 14 * u;
      var r2 = 0;
      for (var y = 0.0; y < h; y += s * 0.55) {
        for (var x = (r2.isOdd ? s / 2 : 0.0); x < w; x += s) {
          final p = Path()
            ..moveTo(x, y - s * 0.5)
            ..lineTo(x + s * 0.5, y)
            ..lineTo(x, y + s * 0.5)
            ..lineTo(x - s * 0.5, y)
            ..close();
          canvas.drawPath(
            p,
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(x, y - s * 0.5),
                Offset(x, y + s * 0.5),
                [light(0.22).color, dark(0.26).color],
              ),
          );
          canvas.drawPath(
            p,
            dark(0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.7 * u,
          );
        }
        r2++;
      }
    case 'croc':
      for (var i = 0; i < (area / 700).round(); i++) {
        final cx = rnd.nextDouble() * w, cy = rnd.nextDouble() * h;
        final r = (5 + rnd.nextDouble() * 9) * u;
        final rr = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: r * 2.2,
            height: r * 1.6,
          ),
          Radius.circular(r * 0.5),
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..shader = ui.Gradient.radial(Offset(cx, cy), r, [
              light(0.18).color,
              dark(0.2).color,
            ]),
        );
        canvas.drawRRect(
          rr,
          dark(0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8 * u,
        );
      }
    case 'cardboard':
      for (var y = 0.0; y < h; y += 3.2 * u) {
        canvas.drawLine(
          Offset(0, y),
          Offset(w, y),
          (y ~/ (3.2 * u)).isEven ? dark(0.09) : light(0.08)
            ..strokeWidth = 1.4 * u,
        );
      }
      fibers((area / 900).round(), 8 * u, 0.2, Colors.black);
      speckle((area / 800).round(), 0.7 * u, () => dark(0.07));
    case 'kraft':
      fibers((area / 700).round(), 12 * u, 0.28, const Color(0xFF5A3A1E));
      speckle((area / 600).round(), 0.8 * u, () => dark(0.07));
    case 'cork':
      for (var i = 0; i < (area / 160).round(); i++) {
        final r = (1 + rnd.nextDouble() * 3.2) * u;
        canvas.drawCircle(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          r,
          [dark(0.22), light(0.18), ink(0.3)][i % 3],
        );
      }
    case 'wood':
      for (var y = -20.0; y < h + 20; y += 5 * u) {
        final p = Path()..moveTo(0, y);
        for (var x = 0.0; x <= w; x += 12 * u) {
          p.lineTo(
            x,
            y +
                math.sin(x / (40 * u) + y * 0.05) * 3.2 * u +
                math.sin(x / (13 * u) + y) * 0.8 * u,
          );
        }
        canvas.drawPath(
          p,
          (rnd.nextBool() ? dark(0.18) : light(0.07))
            ..style = PaintingStyle.stroke
            ..strokeWidth = (0.6 + rnd.nextDouble() * 1.4) * u,
        );
      }
      for (var i = 0; i < 2; i++) {
        final c = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
        for (var r = 3.0; r < 20; r += 3.5) {
          canvas.drawOval(
            Rect.fromCenter(center: c, width: r * 2.4 * u, height: r * u),
            dark(0.2)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8 * u,
          );
        }
      }
    case 'bamboo':
      for (var x = 0.0; x < w; x += 22 * u) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 2 * u, h), dark(0.2));
        for (
          var y = rnd.nextDouble() * 60 * u;
          y < h;
          y += (50 + rnd.nextDouble() * 40) * u
        ) {
          canvas.drawRect(Rect.fromLTWH(x, y, 22 * u, 3 * u), dark(0.22));
        }
        canvas.drawRect(Rect.fromLTWH(x + 6 * u, 0, 3 * u, h), light(0.14));
      }
    case 'metal':
      for (var y = 0.0; y < h; y += 1.1 * u) {
        canvas.drawLine(
          Offset(0, y),
          Offset(w, y),
          (rnd.nextBool() ? light(0.12) : dark(0.08))..strokeWidth = 0.9 * u,
        );
      }
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(w, h * 0.4),
            [light(0.0).color, light(0.28).color, light(0.0).color],
            const [0.1, 0.45, 0.8],
          ),
      );
    case 'foil':
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(w, h),
            [
              dark(0.28).color,
              light(0.5).color,
              dark(0.12).color,
              light(0.42).color,
              dark(0.3).color,
            ],
            const [0, 0.22, 0.5, 0.78, 1],
          ),
      );
      for (var i = 0; i < (area / 700).round(); i++) {
        final p = Path()..moveTo(rnd.nextDouble() * w, rnd.nextDouble() * h);
        p.relativeLineTo(
          (rnd.nextDouble() - .5) * 30 * u,
          (rnd.nextDouble() - .5) * 30 * u,
        );
        canvas.drawPath(
          p,
          (rnd.nextBool() ? light(0.35) : dark(0.18))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7 * u,
        );
      }
    case 'carbon':
      final s = 6 * u;
      for (var y = 0.0; y < h; y += s) {
        for (var x = 0.0; x < w; x += s) {
          final alt = ((x / s).floor() + (y / s).floor()).isEven;
          canvas.drawRect(
            Rect.fromLTWH(x, y, s, s),
            alt ? dark(0.28) : light(0.1),
          );
          canvas.drawLine(
            Offset(x, y + s / 2),
            Offset(x + s, y + s / 2),
            light(0.1)..strokeWidth = 0.7 * u,
          );
        }
      }
    case 'glitter':
      speckle(
        (area / 40).round(),
        0.8 * u,
        () => Paint()
          ..color = HSVColor.fromAHSV(
            (0.55 * a).clamp(0.0, 1.0),
            rnd.nextDouble() * 360,
            0.35,
            1,
          ).toColor(),
      );
      for (var i = 0; i < (area / 600).round(); i++) {
        star(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          (1.5 + rnd.nextDouble() * 2.5) * u,
          light(0.8),
        );
      }
    case 'holo':
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(w, h),
            const [
              Color(0x66FF9AE6),
              Color(0x669AE6FF),
              Color(0x66FFF59A),
              Color(0x66B39AFF),
              Color(0x66FF9AE6),
            ],
            const [0, 0.25, 0.5, 0.75, 1],
          ),
      );
      for (var d = -h; d < w; d += 11 * u) {
        canvas.drawLine(
          Offset(d, h),
          Offset(d + h, 0),
          light(0.14)..strokeWidth = 2 * u,
        );
      }
      for (var i = 0; i < (area / 1500).round(); i++) {
        star(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          (1.4 + rnd.nextDouble() * 2) * u,
          light(0.85),
        );
      }
    case 'marble':
      blobs(5, 90, 200, [Colors.white, c2], 0.16);
      for (var i = 0; i < 6; i++) {
        final p = Path()..moveTo(rnd.nextDouble() * w, 0);
        var x = rnd.nextDouble() * w, y = 0.0;
        while (y < h) {
          x += (rnd.nextDouble() - .5) * 60 * u;
          y += (10 + rnd.nextDouble() * 22) * u;
          p.lineTo(x, y);
        }
        canvas.drawPath(
          p,
          ink(
            0.22 + rnd.nextDouble() * 0.2,
            stroke: (0.5 + rnd.nextDouble() * 1.5) * u,
            style: PaintingStyle.stroke,
          ),
        );
      }
    case 'concrete':
      speckle(
        (area / 60).round(),
        0.8 * u,
        () => rnd.nextBool() ? dark(0.12) : light(0.1),
      );
      blobs(6, 40, 100, [Colors.black, Colors.white], 0.08);
    case 'lace':
      final r = 15 * u;
      for (var y = 0.0; y < h + r; y += r * 1.7) {
        for (var x = 0.0; x < w + r; x += r * 2) {
          final cx = x + ((y / (r * 1.7)).round().isOdd ? r : 0);
          canvas.drawCircle(
            Offset(cx, y),
            r * 0.95,
            light(0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2 * u,
          );
          for (var k = 0; k < 8; k++) {
            final ang = k * _tau / 8;
            canvas.drawCircle(
              Offset(cx, y) + Offset(math.cos(ang), math.sin(ang)) * r * 0.62,
              r * 0.18,
              light(0.5),
            );
          }
          canvas.drawCircle(Offset(cx, y), r * 0.2, light(0.65));
        }
      }
    case 'starfield':
      blobs(4, 80, 200, [
        const Color(0xFF7A5CFF),
        const Color(0xFF37C6E8),
        const Color(0xFFFF5E8A),
      ], 0.26);
      speckle((area / 450).round(), 0.6 * u, () => light(0.8));
      for (var i = 0; i < (area / 6000).round(); i++) {
        star(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          (2 + rnd.nextDouble() * 3) * u,
          light(0.95),
        );
      }
    // ── Patterns ──────────────────────────────────────────────────────
    case 'floral':
      for (var i = 0; i < (area / 3600).round(); i++) {
        flower(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          (6 + rnd.nextDouble() * 7) * u,
          c2,
          const Color(0xFFFFD96B),
        );
      }
    case 'ditsy':
      for (var y = 14 * u; y < h; y += 28 * u) {
        for (var x = 14 * u; x < w; x += 28 * u) {
          final o = Offset(
            x + (rnd.nextDouble() - .5) * 8 * u,
            y + (rnd.nextDouble() - .5) * 8 * u,
          );
          flower(o, 4.2 * u, c2, const Color(0xFFFFF3B0));
          leaf(
            o + Offset(4 * u, 3 * u),
            7 * u,
            0.6,
            Paint()
              ..color = const Color(
                0xFF6FA06B,
              ).withValues(alpha: (0.8 * a).clamp(0.0, 1.0)),
          );
        }
      }
    case 'vines':
      for (var i = 0; i < 4; i++) {
        final x0 = (i + 0.5) * w / 4;
        final p = Path()..moveTo(x0, 0);
        for (var y = 0.0; y < h; y += 30 * u) {
          p.quadraticBezierTo(
            x0 + math.sin(y / 30) * 28 * u,
            y + 15 * u,
            x0 + math.sin((y + 30 * u) / 30) * 28 * u,
            y + 30 * u,
          );
          leaf(
            Offset(x0 + math.sin(y / 30) * 28 * u, y + 15 * u),
            11 * u,
            (i.isEven ? 0.7 : -0.7) + math.sin(y),
            Paint()..color = c2.withValues(alpha: (0.7 * a).clamp(0.0, 1.0)),
          );
        }
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 * u
            ..color = c2.withValues(alpha: (0.6 * a).clamp(0.0, 1.0)),
        );
      }
    case 'snowflakes':
      for (var i = 0; i < (area / 3500).round(); i++) {
        final c = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
        final r = (4 + rnd.nextDouble() * 8) * u;
        for (var k = 0; k < 3; k++) {
          final ang = k * math.pi / 3;
          canvas.drawLine(
            c - Offset(math.cos(ang), math.sin(ang)) * r,
            c + Offset(math.cos(ang), math.sin(ang)) * r,
            ink(0.55, stroke: 1 * u),
          );
        }
      }
    case 'leaves':
      for (var i = 0; i < (area / 3000).round(); i++) {
        leaf(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          (12 + rnd.nextDouble() * 12) * u,
          rnd.nextDouble() * _tau,
          Paint()
            ..color = _mix(
              c2,
              const Color(0xFFD9822B),
              rnd.nextDouble(),
            ).withValues(alpha: (0.7 * a).clamp(0.0, 1.0)),
        );
      }
    case 'hearts':
      for (var i = 0; i < (area / 3500).round(); i++) {
        heart(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          (3 + rnd.nextDouble() * 5) * u,
          ink(0.4),
        );
      }
    case 'stars':
      for (var i = 0; i < (area / 2500).round(); i++) {
        star(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          (3 + rnd.nextDouble() * 6) * u,
          ink(0.5),
          points: 5,
        );
      }
    case 'moons':
      for (var i = 0; i < (area / 6000).round(); i++) {
        final c = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
        final r = (5 + rnd.nextDouble() * 6) * u;
        final path = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: c, radius: r)),
          Path()..addOval(
            Rect.fromCircle(
              center: c + Offset(r * 0.5, -r * 0.2),
              radius: r * 0.85,
            ),
          ),
        );
        canvas.drawPath(path, ink(0.55));
      }
      speckle((area / 800).round(), 0.7 * u, () => ink(0.4));
    case 'constellations':
      final pts = [
        for (var i = 0; i < (area / 8000).round() + 6; i++)
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
      ];
      for (var i = 1; i < pts.length; i++) {
        if ((pts[i] - pts[i - 1]).distance < 110 * u)
          canvas.drawLine(pts[i - 1], pts[i], ink(0.3, stroke: 0.8 * u));
      }
      for (final p in pts) {
        star(p, 3.2 * u, ink(0.8));
      }
    case 'clouds':
      for (var i = 0; i < (area / 14000).round() + 2; i++) {
        final c = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
        final r = (14 + rnd.nextDouble() * 14) * u;
        for (final (dx, dy, k) in [
          (-0.9, 0.1, 0.8),
          (0.0, -0.3, 1.0),
          (0.9, 0.1, 0.85),
          (0.0, 0.3, 0.9),
        ]) {
          canvas.drawCircle(c + Offset(dx * r, dy * r), r * k * 0.7, ink(0.35));
        }
      }
    case 'polka' || 'polkaBig':
      final s = (kind == 'polkaBig' ? 36.0 : 20.0) * u;
      var row = 0;
      for (var y = s / 2; y < h + s; y += s) {
        for (var x = s / 2 + (row.isOdd ? s / 2 : 0); x < w + s; x += s) {
          canvas.drawCircle(Offset(x, y), s * 0.2, ink(0.4));
        }
        row++;
      }
    case 'stripes':
      for (var x = 0.0; x < w; x += 20 * u) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 10 * u, h), ink(0.18));
      }
    case 'diagonal':
      for (var d = -h; d < w; d += 22 * u) {
        canvas.drawLine(
          Offset(d, h),
          Offset(d + h, 0),
          ink(0.3, stroke: 5 * u),
        );
      }
    case 'chevron':
      final s = 22 * u;
      for (var y = 0.0; y < h + s; y += s) {
        final p = Path()..moveTo(0, y);
        var up = true;
        for (var x = 0.0; x <= w + s; x += s) {
          p.lineTo(x, y + (up ? -s * 0.5 : 0));
          up = !up;
        }
        canvas.drawPath(
          p,
          ink(0.4, stroke: 2.2 * u, style: PaintingStyle.stroke),
        );
      }
    case 'checker':
      final s = 24 * u;
      for (var y = 0.0; y < h; y += s) {
        for (var x = 0.0; x < w; x += s) {
          if (((x / s).floor() + (y / s).floor()).isEven)
            canvas.drawRect(Rect.fromLTWH(x, y, s, s), ink(0.16));
        }
      }
    case 'waves':
      for (var y = 10 * u; y < h + 10 * u; y += 14 * u) {
        final p = Path()..moveTo(0, y);
        for (var x = 0.0; x < w; x += 24 * u) {
          p.quadraticBezierTo(x + 6 * u, y - 6 * u, x + 12 * u, y);
          p.quadraticBezierTo(x + 18 * u, y + 6 * u, x + 24 * u, y);
        }
        canvas.drawPath(
          p,
          ink(0.4, stroke: 1.2 * u, style: PaintingStyle.stroke),
        );
      }
    case 'diamonds':
      final s = 26 * u;
      for (var y = 0.0; y < h + s; y += s) {
        for (var x = 0.0; x < w + s; x += s) {
          final c = Offset(x + ((y / s).round().isOdd ? s / 2 : 0), y);
          canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - s * 0.4)
              ..lineTo(c.dx + s * 0.3, c.dy)
              ..lineTo(c.dx, c.dy + s * 0.4)
              ..lineTo(c.dx - s * 0.3, c.dy)
              ..close(),
            ink(0.3),
          );
        }
      }
    case 'scales':
      final r = 14 * u;
      var row = 0;
      for (var y = 0.0; y < h + r; y += r * 0.8) {
        for (var x = (row.isOdd ? r : 0.0); x < w + r; x += r * 2) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x, y), radius: r),
            0,
            math.pi,
            false,
            ink(0.4, stroke: 1 * u, style: PaintingStyle.stroke),
          );
        }
        row++;
      }
    case 'grunge':
      blobs(10, 30, 110, [Colors.black, c2], 0.14);
      for (var i = 0; i < (area / 4000).round() + 6; i++) {
        final y = rnd.nextDouble() * h;
        canvas.drawLine(
          Offset(rnd.nextDouble() * w * 0.5, y),
          Offset(
            w * (0.4 + rnd.nextDouble() * 0.6),
            y + (rnd.nextDouble() - .5) * 14 * u,
          ),
          dark(0.18)..strokeWidth = (0.5 + rnd.nextDouble() * 1.3) * u,
        );
      }
      speckle(
        (area / 120).round(),
        0.9 * u,
        () => rnd.nextBool() ? dark(0.18) : light(0.12),
      );
    case 'scratches':
      for (var i = 0; i < (area / 900).round(); i++) {
        final x = rnd.nextDouble() * w, y = rnd.nextDouble() * h;
        final ang = rnd.nextDouble() * math.pi;
        final l = (10 + rnd.nextDouble() * 40) * u;
        canvas.drawLine(
          Offset(x, y),
          Offset(x + math.cos(ang) * l, y + math.sin(ang) * l),
          (rnd.nextBool() ? light(0.3) : dark(0.25))..strokeWidth = 0.6 * u,
        );
      }
    case 'halftone':
      final s = 9 * u;
      for (var y = 0.0; y < h; y += s) {
        for (var x = 0.0; x < w; x += s) {
          final k =
              (0.5 + 0.5 * math.sin(x / (50 * u)) * math.cos(y / (50 * u)));
          canvas.drawCircle(Offset(x, y), s * 0.42 * k, ink(0.45));
        }
      }
    case 'plain':
    default:
      break;
  }
  canvas.restore();
}

/// A [CustomPainter] for one texture, with the blend and opacity a page uses.
class ScrapTexturePainter extends CustomPainter {
  const ScrapTexturePainter({
    required this.kind,
    required this.c1,
    required this.c2,
    this.seed = 1,
    this.scale = 1,
    this.intensity = 1,
    this.opacity = 1,
    this.blend = BlendMode.srcOver,
  });
  final String kind;
  final Color c1, c2;
  final int seed;
  final double scale, intensity, opacity;
  final BlendMode blend;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity >= 0.999 && blend == BlendMode.srcOver) {
      paintScrapTexture(
        canvas,
        size,
        kind: kind,
        c1: c1,
        c2: c2,
        seed: seed,
        scale: scale,
        intensity: intensity,
      );
      return;
    }
    // Draw the texture on its own, then lay it over what's beneath.
    canvas.saveLayer(
      Offset.zero & size,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..blendMode = blend,
    );
    paintScrapTexture(
      canvas,
      size,
      kind: kind,
      c1: c1,
      c2: c2,
      seed: seed,
      scale: scale,
      intensity: intensity,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ScrapTexturePainter o) =>
      o.kind != kind ||
      o.c1 != c1 ||
      o.c2 != c2 ||
      o.seed != seed ||
      o.scale != scale ||
      o.intensity != intensity ||
      o.opacity != opacity ||
      o.blend != blend;
}
