import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Matrix4;

/// One app icon design, drawn entirely in code so previews cost nothing to
/// ship. [bg] picks the backdrop, [fg] the central figure, [logo] how the
/// Prism mark is treated, and [deco] an extra layer of detail.
@immutable
class IconArt {
  const IconArt({
    required this.bg,
    required this.fg,
    required this.c1,
    required this.c2,
    required this.c3,
    this.logo = 'color',
    this.deco = 'none',
    this.glyph,
  });

  /// See [iconBackgrounds].
  final String bg;

  /// See [iconFigures]; 'prism' draws the Prism mark alone, 'glyph' draws
  /// [glyph] (an emoji) as the figure.
  final String fg;

  /// How the Prism mark is drawn: color | white | black | tint | outline |
  /// glass | pixel | badge (small, in a corner) | none.
  final String logo;

  /// stars | sparkles | rings | dots | none
  final String deco;
  final int c1, c2, c3;
  final String? glyph;

  Color get a => Color(c1);
  Color get b => Color(c2);
  Color get c => Color(c3);
}

const iconBackgrounds = [
  'solid',
  'linear',
  'radial',
  'glass',
  'frosted',
  'matte',
  'chrome',
  'iridescent',
  'starfield',
  'nebula',
  'aurora',
  'grid',
  'circuit',
  'pixel',
  'neon',
  'scanlines',
  'leaves',
  'wood',
  'knit',
  'paper',
  'watercolor',
  'sketch',
  'stained',
  'cutout',
  'plaid',
  'grunge',
  'deco',
  'damask',
  'waves',
  'clouds',
  'forest',
  'rain',
  'stripes',
  'dots',
  'notebook',
  'checker',
  'sunburst',
  'bokeh',
  'mushrooms',
  'staff',
];

const iconFigures = [
  'prism',
  'planet',
  'moon',
  'sun',
  'star',
  'constellation',
  'crystal',
  'mushroom',
  'leaf',
  'cloud',
  'drop',
  'flower',
  'heart',
  'bow',
  'note',
  'gamepad',
  'candy',
  'arch',
  'fan',
  'bolt',
  'pencil',
  'glyph',
];

double _rnd(int seed, int i) {
  var h = seed * 374761393 + i * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return ((h ^ (h >> 16)) & 0xffff) / 0xffff;
}

/// Draws [art] into a [s]×[s] square. [logo] is the Prism mark image (when
/// available); without it a simple prism shape is drawn instead. The art
/// keeps its important parts inside the central 66% so every launcher
/// mask (circle, squircle, teardrop…) shows them.
void paintIconArt(
  Canvas c,
  double s,
  IconArt art, {
  ui.Image? logo,
  int seed = 7,
}) {
  final rect = Rect.fromLTWH(0, 0, s, s);
  c.save();
  c.clipRect(rect);
  _background(c, s, art, seed);
  _deco(c, s, art, seed);
  _figure(c, s, art, logo);
  c.restore();
}

// ── Backgrounds ────────────────────────────────────────────────────────

void _background(Canvas c, double s, IconArt t, int seed) {
  final rect = Rect.fromLTWH(0, 0, s, s);
  Paint lin(
    List<Color> cs, {
    Alignment a = Alignment.topLeft,
    Alignment b = Alignment.bottomRight,
  }) => Paint()
    ..shader = LinearGradient(begin: a, end: b, colors: cs).createShader(rect);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  switch (t.bg) {
    case 'solid':
      c.drawRect(rect, Paint()..color = t.a);
    case 'linear':
      c.drawRect(rect, lin([t.a, t.b]));
    case 'radial':
      c.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [t.a, t.b],
            radius: 0.8,
          ).createShader(rect),
      );
    case 'glass' || 'frosted':
      c.drawRect(rect, lin([t.a, t.b]));
      // A pane of glass with a soft highlight across the top.
      final pane = RRect.fromRectAndRadius(
        rect.deflate(s * 0.14),
        Radius.circular(s * 0.18),
      );
      c.drawRRect(pane, Paint()..color = const Color(0x33FFFFFF));
      c.drawRRect(
        pane,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.01
          ..color = const Color(0x66FFFFFF),
      );
      c.drawOval(
        Rect.fromLTWH(s * 0.1, -s * 0.25, s * 0.8, s * 0.55),
        Paint()..color = const Color(0x22FFFFFF),
      );
      if (t.bg == 'frosted') {
        for (var i = 0; i < 260; i++) {
          c.drawCircle(
            Offset(_rnd(seed, i) * s, _rnd(seed, i + 999) * s),
            s * 0.004,
            Paint()..color = const Color(0x22FFFFFF),
          );
        }
      }
    case 'matte':
      c.drawRect(rect, Paint()..color = t.a);
      for (var i = 0; i < 400; i++) {
        c.drawCircle(
          Offset(_rnd(seed, i) * s, _rnd(seed, i + 7) * s),
          s * 0.003,
          Paint()
            ..color = (i.isEven
                ? const Color(0x0F000000)
                : const Color(0x0FFFFFFF)),
        );
      }
    case 'chrome':
      c.drawRect(
        rect,
        lin(
          [t.c, t.a, const Color(0xFFFFFFFF), t.b, t.c, t.a],
          a: Alignment.topCenter,
          b: Alignment.bottomCenter,
        ),
      );
      c.drawRect(
        Rect.fromLTWH(0, s * 0.48, s, s * 0.04),
        Paint()..color = const Color(0x55FFFFFF),
      );
    case 'iridescent':
      c.drawRect(
        rect,
        Paint()
          ..shader = SweepGradient(
            colors: [t.a, t.b, t.c, const Color(0xFFFFFFFF), t.a],
          ).createShader(rect),
      );
      c.drawRect(rect, Paint()..color = const Color(0x33FFFFFF));
    case 'starfield' || 'nebula':
      c.drawRect(
        rect,
        lin([t.a, t.b], a: Alignment.topCenter, b: Alignment.bottomCenter),
      );
      if (t.bg == 'nebula') {
        for (var i = 0; i < 5; i++) {
          final o = Offset(_rnd(seed, i) * s, _rnd(seed, i + 50) * s);
          c.drawCircle(
            o,
            s * (0.25 + _rnd(seed, i + 9) * 0.2),
            Paint()
              ..color = (i.isEven ? t.c : t.b).withValues(alpha: 0.45)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.12),
          );
        }
      }
      for (var i = 0; i < 70; i++) {
        c.drawCircle(
          Offset(_rnd(seed, i + 3) * s, _rnd(seed, i + 300) * s),
          s * (0.002 + _rnd(seed, i) * 0.006),
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFFFFFF),
              t.c,
              _rnd(seed, i + 77) * 0.5,
            )!,
        );
      }
    case 'aurora':
      c.drawRect(rect, Paint()..color = t.a);
      for (var k = 0; k < 3; k++) {
        final p = Path()..moveTo(0, s * (0.3 + k * 0.15));
        for (var x = 0.0; x <= s; x += s / 10) {
          p.lineTo(
            x,
            s * (0.3 + k * 0.15) + math.sin(x / s * 6 + k) * s * 0.06,
          );
        }
        c.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.12
            ..color = (k == 1 ? t.c : t.b).withValues(alpha: 0.55)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
        );
      }
    case 'grid':
      c.drawRect(
        rect,
        lin([t.a, t.b], a: Alignment.topCenter, b: Alignment.bottomCenter),
      );
      final g = Paint()
        ..color = t.c.withValues(alpha: 0.8)
        ..strokeWidth = s * 0.006;
      final horizon = s * 0.6;
      for (var i = -8; i <= 8; i++) {
        c.drawLine(
          Offset(s / 2 + i * s * 0.04, horizon),
          Offset(s / 2 + i * s * 0.25, s),
          g,
        );
      }
      for (var k = 0; k < 7; k++) {
        final y = horizon + math.pow(k / 6, 1.8) * (s - horizon);
        c.drawLine(Offset(0, y), Offset(s, y), g);
      }
      c.drawCircle(
        Offset(s / 2, horizon),
        s * 0.22,
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [t.c, t.b],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(s / 2, horizon),
                  radius: s * 0.22,
                ),
              ),
      );
      c.drawRect(
        Rect.fromLTWH(0, horizon, s, s),
        Paint()..color = t.a.withValues(alpha: 0.55),
      );
    case 'circuit':
      c.drawRect(rect, Paint()..color = t.a);
      final p = Paint()
        ..color = t.b.withValues(alpha: 0.7)
        ..strokeWidth = s * 0.012
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < 14; i++) {
        final x = _rnd(seed, i) * s, y = _rnd(seed, i + 40) * s;
        final path = Path()
          ..moveTo(x, y)
          ..lineTo(x + s * 0.12, y)
          ..lineTo(x + s * 0.2, y + s * 0.08);
        c.drawPath(path, p);
        c.drawCircle(
          Offset(x + s * 0.2, y + s * 0.08),
          s * 0.015,
          Paint()..color = t.c,
        );
      }
    case 'pixel' || 'checker':
      final n = t.bg == 'pixel' ? 12 : 8;
      final cell = s / n;
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          final v = t.bg == 'pixel'
              ? _rnd(seed, y * n + x)
              : ((x + y).isEven ? 1.0 : 0.0);
          c.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5),
            Paint()..color = v > 0.66 ? t.c : (v > 0.33 ? t.b : t.a),
          );
        }
      }
    case 'neon':
      c.drawRect(rect, Paint()..color = t.a);
      c.drawCircle(
        Offset(s / 2, s / 2),
        s * 0.36,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.03
          ..color = t.b
          ..maskFilter = MaskFilter.blur(BlurStyle.solid, s * 0.03),
      );
      c.drawCircle(
        Offset(s / 2, s / 2),
        s * 0.42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.012
          ..color = t.c
          ..maskFilter = MaskFilter.blur(BlurStyle.solid, s * 0.02),
      );
    case 'scanlines':
      c.drawRect(rect, lin([t.a, t.b]));
      for (var y = 0.0; y < s; y += s * 0.025) {
        c.drawRect(
          Rect.fromLTWH(0, y, s, s * 0.008),
          Paint()..color = const Color(0x22000000),
        );
      }
      c.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(s * 0.08),
          Radius.circular(s * 0.12),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.03
          ..color = t.c.withValues(alpha: 0.6),
      );
    case 'leaves' || 'forest':
      c.drawRect(
        rect,
        lin([t.a, t.b], a: Alignment.topCenter, b: Alignment.bottomCenter),
      );
      for (var i = 0; i < (t.bg == 'forest' ? 9 : 16); i++) {
        final x = _rnd(seed, i) * s,
            y =
                (t.bg == 'forest'
                    ? 0.65 + _rnd(seed, i + 5) * 0.3
                    : _rnd(seed, i + 5)) *
                s;
        if (t.bg == 'forest') {
          final h = s * (0.25 + _rnd(seed, i + 3) * 0.2);
          c.drawPath(
            Path()
              ..moveTo(x, y - h)
              ..lineTo(x - h * 0.35, y)
              ..lineTo(x + h * 0.35, y)
              ..close(),
            Paint()..color = t.c.withValues(alpha: 0.75),
          );
        } else {
          c.save();
          c.translate(x, y);
          c.rotate(_rnd(seed, i + 8) * math.pi * 2);
          c.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: s * 0.16,
              height: s * 0.07,
            ),
            Paint()..color = t.c.withValues(alpha: 0.55),
          );
          c.restore();
        }
      }
    case 'wood':
      c.drawRect(rect, Paint()..color = t.a);
      for (var i = 0; i < 18; i++) {
        final y = i * s / 18;
        final p = Path()..moveTo(0, y);
        for (var x = 0.0; x <= s; x += s / 8) {
          p.lineTo(x, y + math.sin(x / s * 5 + i) * s * 0.012);
        }
        c.drawPath(
          p,
          stroke
            ..color = t.b.withValues(alpha: 0.45)
            ..strokeWidth = s * 0.008,
        );
      }
    case 'knit':
      c.drawRect(rect, Paint()..color = t.a);
      final st = s / 10;
      for (var y = 0; y < 11; y++) {
        for (var x = 0; x < 11; x++) {
          final o = Offset(x * st, y * st);
          final col = (y % 4 == 1) ? t.c : t.b;
          c.drawPath(
            Path()
              ..moveTo(o.dx, o.dy)
              ..quadraticBezierTo(
                o.dx + st * 0.25,
                o.dy + st * 0.8,
                o.dx + st * 0.5,
                o.dy + st * 0.6,
              )
              ..quadraticBezierTo(
                o.dx + st * 0.75,
                o.dy + st * 0.8,
                o.dx + st,
                o.dy,
              ),
            Paint()..color = col.withValues(alpha: 0.7),
          );
        }
      }
    case 'paper' || 'notebook':
      c.drawRect(rect, Paint()..color = t.a);
      if (t.bg == 'notebook') {
        for (var y = s * 0.12; y < s; y += s * 0.085) {
          c.drawLine(
            Offset(0, y),
            Offset(s, y),
            Paint()
              ..color = t.b.withValues(alpha: 0.5)
              ..strokeWidth = s * 0.006,
          );
        }
        c.drawLine(
          Offset(s * 0.18, 0),
          Offset(s * 0.18, s),
          Paint()
            ..color = t.c
            ..strokeWidth = s * 0.008,
        );
      } else {
        for (var i = 0; i < 300; i++) {
          c.drawCircle(
            Offset(_rnd(seed, i) * s, _rnd(seed, i + 3) * s),
            s * 0.004,
            Paint()..color = t.b.withValues(alpha: 0.12),
          );
        }
      }
    case 'watercolor' || 'bokeh':
      c.drawRect(rect, Paint()..color = t.a);
      for (var i = 0; i < (t.bg == 'bokeh' ? 12 : 6); i++) {
        final o = Offset(_rnd(seed, i) * s, _rnd(seed, i + 20) * s);
        c.drawCircle(
          o,
          s * (t.bg == 'bokeh' ? 0.06 + _rnd(seed, i) * 0.06 : 0.22),
          Paint()
            ..color = (i % 3 == 0 ? t.b : t.c).withValues(
              alpha: t.bg == 'bokeh' ? 0.5 : 0.35,
            )
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              s * (t.bg == 'bokeh' ? 0.015 : 0.06),
            ),
        );
      }
    case 'sketch':
      c.drawRect(rect, Paint()..color = t.a);
      for (var i = -20; i < 40; i++) {
        c.drawLine(
          Offset(i * s * 0.05, 0),
          Offset(i * s * 0.05 - s * 0.6, s),
          Paint()
            ..color = t.b.withValues(alpha: 0.18)
            ..strokeWidth = s * 0.004,
        );
      }
    case 'stained':
      c.drawRect(rect, Paint()..color = const Color(0xFF1A1A1A));
      final cols = [t.a, t.b, t.c];
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          final j = (o) => (_rnd(seed, o) - 0.5) * s * 0.08;
          final p = Path()
            ..moveTo(x * s / 4 + j(y * 9 + x), y * s / 4 + j(x * 7 + y))
            ..lineTo(
              (x + 1) * s / 4 + j(y * 9 + x + 1),
              y * s / 4 + j(x * 7 + y + 3),
            )
            ..lineTo(
              (x + 1) * s / 4 + j(y * 9 + x + 5),
              (y + 1) * s / 4 + j(x * 7 + y + 4),
            )
            ..lineTo(
              x * s / 4 + j(y * 9 + x + 2),
              (y + 1) * s / 4 + j(x * 7 + y + 8),
            )
            ..close();
          c.drawPath(
            p,
            Paint()..color = cols[(x + y * 2) % 3].withValues(alpha: 0.85),
          );
          c.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.018
              ..color = const Color(0xFF222222),
          );
        }
      }
    case 'cutout':
      c.drawRect(rect, Paint()..color = t.a);
      for (var k = 0; k < 4; k++) {
        final p = Path()..moveTo(0, s);
        final base = s * (0.45 + k * 0.14);
        for (var x = 0.0; x <= s; x += s / 6) {
          p.lineTo(x, base + math.sin(x / s * 6 + k * 2) * s * 0.05);
        }
        p
          ..lineTo(s, s)
          ..close();
        final col = Color.lerp(t.b, t.c, k / 3)!;
        c.drawShadow(p, const Color(0xFF000000), s * 0.01, false);
        c.drawPath(p, Paint()..color = col);
      }
    case 'plaid':
      c.drawRect(rect, Paint()..color = t.a);
      for (var i = 0; i < 5; i++) {
        final x = i * s / 4;
        c.drawRect(
          Rect.fromLTWH(x - s * 0.05, 0, s * 0.1, s),
          Paint()..color = t.b.withValues(alpha: 0.5),
        );
        c.drawRect(
          Rect.fromLTWH(0, x - s * 0.05, s, s * 0.1),
          Paint()..color = t.b.withValues(alpha: 0.5),
        );
        c.drawRect(
          Rect.fromLTWH(x - s * 0.01, 0, s * 0.02, s),
          Paint()..color = t.c,
        );
        c.drawRect(
          Rect.fromLTWH(0, x - s * 0.01, s, s * 0.02),
          Paint()..color = t.c,
        );
      }
    case 'grunge':
      c.drawRect(rect, Paint()..color = t.a);
      for (var i = 0; i < 40; i++) {
        c.drawCircle(
          Offset(_rnd(seed, i) * s, _rnd(seed, i + 8) * s),
          s * _rnd(seed, i + 2) * 0.05,
          Paint()..color = t.b.withValues(alpha: 0.25),
        );
      }
      for (var i = 0; i < 6; i++) {
        c.drawLine(
          Offset(_rnd(seed, i + 60) * s, 0),
          Offset(_rnd(seed, i + 70) * s, s),
          Paint()
            ..color = t.c.withValues(alpha: 0.2)
            ..strokeWidth = s * 0.006,
        );
      }
    case 'deco' || 'sunburst':
      c.drawRect(rect, Paint()..color = t.a);
      final center = t.bg == 'deco'
          ? Offset(s / 2, s * 1.05)
          : Offset(s / 2, s / 2);
      final n = t.bg == 'deco' ? 13 : 20;
      for (var i = 0; i < n; i++) {
        final a0 =
            (t.bg == 'deco' ? math.pi : 0) +
            i * (t.bg == 'deco' ? math.pi : math.pi * 2) / n;
        final a1 = a0 + (t.bg == 'deco' ? math.pi : math.pi * 2) / n / 2;
        c.drawPath(
          Path()
            ..moveTo(center.dx, center.dy)
            ..lineTo(
              center.dx + math.cos(a0) * s * 1.5,
              center.dy + math.sin(a0) * s * 1.5,
            )
            ..lineTo(
              center.dx + math.cos(a1) * s * 1.5,
              center.dy + math.sin(a1) * s * 1.5,
            )
            ..close(),
          Paint()..color = t.b.withValues(alpha: 0.55),
        );
      }
      if (t.bg == 'deco') {
        for (var k = 1; k < 4; k++) {
          c.drawCircle(
            center,
            s * 0.25 * k,
            stroke
              ..color = t.c
              ..strokeWidth = s * 0.01,
          );
        }
      }
    case 'damask':
      c.drawRect(rect, Paint()..color = t.a);
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 3; x++) {
          final o = Offset(
            (x + (y.isOdd ? 0.5 : 0)) * s / 2.5,
            y * s / 2.5 + s * 0.1,
          );
          for (var k = 0; k < 4; k++) {
            c.save();
            c.translate(o.dx, o.dy);
            c.rotate(k * math.pi / 2);
            c.drawOval(
              Rect.fromLTWH(-s * 0.025, 0, s * 0.05, s * 0.12),
              Paint()..color = t.b.withValues(alpha: 0.35),
            );
            c.restore();
          }
        }
      }
    case 'waves':
      c.drawRect(
        rect,
        lin([t.a, t.b], a: Alignment.topCenter, b: Alignment.bottomCenter),
      );
      for (var k = 0; k < 5; k++) {
        final p = Path()..moveTo(0, s * (0.5 + k * 0.11));
        for (var x = 0.0; x <= s; x += s / 12) {
          p.lineTo(
            x,
            s * (0.5 + k * 0.11) + math.sin(x / s * 10 + k) * s * 0.02,
          );
        }
        c.drawPath(
          p,
          stroke
            ..color = t.c.withValues(alpha: 0.5)
            ..strokeWidth = s * 0.015,
        );
      }
    case 'clouds':
      c.drawRect(
        rect,
        lin([t.a, t.b], a: Alignment.topCenter, b: Alignment.bottomCenter),
      );
      for (var i = 0; i < 5; i++) {
        final o = Offset(
          _rnd(seed, i) * s,
          (0.15 + _rnd(seed, i + 4) * 0.75) * s,
        );
        for (var k = 0; k < 3; k++) {
          c.drawCircle(
            o + Offset((k - 1) * s * 0.07, k == 1 ? -s * 0.03 : 0),
            s * 0.07,
            Paint()..color = t.c.withValues(alpha: 0.7),
          );
        }
      }
    case 'rain':
      c.drawRect(
        rect,
        lin([t.a, t.b], a: Alignment.topCenter, b: Alignment.bottomCenter),
      );
      for (var i = 0; i < 40; i++) {
        final o = Offset(_rnd(seed, i) * s, _rnd(seed, i + 9) * s);
        c.drawLine(
          o,
          o + Offset(-s * 0.01, s * 0.05),
          Paint()
            ..color = t.c.withValues(alpha: 0.55)
            ..strokeWidth = s * 0.006,
        );
      }
      c.drawLine(
        Offset(s / 2, 0),
        Offset(s / 2, s),
        Paint()
          ..color = const Color(0x44FFFFFF)
          ..strokeWidth = s * 0.02,
      );
      c.drawLine(
        Offset(0, s / 2),
        Offset(s, s / 2),
        Paint()
          ..color = const Color(0x44FFFFFF)
          ..strokeWidth = s * 0.02,
      );
    case 'stripes':
      c.drawRect(rect, Paint()..color = t.a);
      for (var i = -10; i < 20; i += 2) {
        c.drawPath(
          Path()
            ..moveTo(i * s * 0.08, 0)
            ..lineTo(i * s * 0.08 + s * 0.08, 0)
            ..lineTo(i * s * 0.08 + s * 0.08 - s, s)
            ..lineTo(i * s * 0.08 - s, s)
            ..close(),
          Paint()..color = (i % 4 == 0 ? t.b : t.c).withValues(alpha: 0.75),
        );
      }
    case 'dots' || 'mushrooms':
      c.drawRect(rect, Paint()..color = t.a);
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 7; x++) {
          final o = Offset((x + (y.isOdd ? 0.5 : 0)) * s / 6, y * s / 6);
          c.drawCircle(
            o,
            s *
                (t.bg == 'mushrooms'
                    ? 0.03 + _rnd(seed, x * 7 + y) * 0.03
                    : 0.025),
            Paint()
              ..color = (t.bg == 'mushrooms' ? const Color(0xFFFFFFFF) : t.b)
                  .withValues(alpha: 0.75),
          );
        }
      }
    case 'staff':
      c.drawRect(rect, lin([t.a, t.b]));
      for (var k = 0; k < 5; k++) {
        c.drawLine(
          Offset(0, s * (0.62 + k * 0.05)),
          Offset(s, s * (0.62 + k * 0.05)),
          Paint()
            ..color = t.c.withValues(alpha: 0.6)
            ..strokeWidth = s * 0.006,
        );
      }
    default:
      c.drawRect(rect, lin([t.a, t.b]));
  }
}

// ── Detail layer ───────────────────────────────────────────────────────

void _deco(Canvas c, double s, IconArt t, int seed) {
  switch (t.deco) {
    case 'stars' || 'sparkles':
      for (var i = 0; i < (t.deco == 'stars' ? 7 : 5); i++) {
        final o = Offset(
          (0.12 + _rnd(seed + 3, i) * 0.76) * s,
          (0.1 + _rnd(seed + 5, i) * 0.8) * s,
        );
        _sparkle(
          c,
          o,
          s * (0.02 + _rnd(seed, i) * 0.03),
          t.deco == 'stars' ? const Color(0xFFFFF4C2) : t.c,
        );
      }
    case 'rings':
      for (var k = 0; k < 3; k++) {
        c.drawCircle(
          Offset(s / 2, s / 2),
          s * (0.3 + k * 0.08),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.006
            ..color = t.c.withValues(alpha: 0.5 - k * 0.12),
        );
      }
    case 'dots':
      for (var i = 0; i < 18; i++) {
        c.drawCircle(
          Offset(_rnd(seed + 9, i) * s, _rnd(seed + 11, i) * s),
          s * 0.012,
          Paint()..color = t.c.withValues(alpha: 0.6),
        );
      }
  }
}

void _sparkle(Canvas c, Offset o, double r, Color col) {
  final p = Path()
    ..moveTo(o.dx, o.dy - r)
    ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
    ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
    ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
    ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
    ..close();
  c.drawPath(p, Paint()..color = col);
}

// ── Figures ────────────────────────────────────────────────────────────

Path _prismPath(double s) {
  final cx = s / 2, cy = s * 0.5;
  final r = s * 0.24;
  return Path()
    ..moveTo(cx, cy - r)
    ..lineTo(cx + r * 0.95, cy + r * 0.62)
    ..lineTo(cx - r * 0.95, cy + r * 0.62)
    ..close();
}

void _drawLogo(
  Canvas c,
  double s,
  IconArt t,
  ui.Image? logo, {
  double scale = 1,
  Offset? at,
}) {
  if (t.logo == 'none') return;
  final size = s * 0.62 * scale;
  final center = at ?? Offset(s / 2, s / 2);
  final dst = Rect.fromCenter(center: center, width: size, height: size);
  ColorFilter? filter;
  switch (t.logo) {
    case 'white':
      filter = const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn);
    case 'black':
      filter = const ColorFilter.mode(Color(0xFF111111), BlendMode.srcIn);
    case 'tint':
      filter = ColorFilter.mode(t.c, BlendMode.srcIn);
    case 'glass':
      filter = const ColorFilter.mode(Color(0xCCFFFFFF), BlendMode.srcIn);
  }
  if (logo == null) {
    // No logo image (tests, very first frame): a plain prism shape.
    final m = Matrix4.identity()
      ..translateByDouble(
        center.dx - s / 2 * scale,
        center.dy - s / 2 * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
    final p = _prismPath(s).transform(m.storage);
    if (t.logo == 'outline') {
      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02 * scale
          ..color = t.c,
      );
    } else {
      c.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            colors: [const Color(0xFFFFFFFF), t.c],
          ).createShader(p.getBounds()),
      );
    }
    return;
  }
  final src = Rect.fromLTWH(
    0,
    0,
    logo.width.toDouble(),
    logo.height.toDouble(),
  );
  if (t.logo == 'outline') {
    c.saveLayer(dst.inflate(s * 0.05), Paint());
    c.drawImageRect(
      logo,
      src,
      dst,
      Paint()
        ..colorFilter = ColorFilter.mode(t.c, BlendMode.srcIn)
        ..imageFilter = ui.ImageFilter.dilate(
          radiusX: s * 0.012,
          radiusY: s * 0.012,
        ),
    );
    c.drawImageRect(logo, src, dst, Paint()..blendMode = BlendMode.dstOut);
    c.restore();
    return;
  }
  if (t.logo == 'pixel') {
    // Draw small, then scale up without smoothing for chunky pixels.
    final rec = ui.PictureRecorder();
    final pc = Canvas(rec);
    pc.drawImageRect(
      logo,
      src,
      const Rect.fromLTWH(0, 0, 20, 20),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final tiny = rec.endRecording().toImageSync(20, 20);
    c.drawImageRect(
      tiny,
      const Rect.fromLTWH(0, 0, 20, 20),
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
    tiny.dispose();
    return;
  }
  if (t.logo == 'glass') {
    c.drawImageRect(
      logo,
      src,
      dst.translate(s * 0.01, s * 0.015),
      Paint()
        ..colorFilter = const ColorFilter.mode(
          Color(0x33000000),
          BlendMode.srcIn,
        ),
    );
  }
  c.drawImageRect(
    logo,
    src,
    dst,
    Paint()
      ..colorFilter = filter
      ..filterQuality = FilterQuality.high,
  );
}

void _figure(Canvas c, double s, IconArt t, ui.Image? logo) {
  final mid = Offset(s / 2, s / 2);
  final fill = Paint()..color = t.c;
  final light = Paint()..color = const Color(0xFFFFFFFF);
  void badge() =>
      _drawLogo(c, s, t, logo, scale: 0.36, at: Offset(s * 0.66, s * 0.66));
  switch (t.fg) {
    case 'prism':
      _drawLogo(c, s, t, logo);
      return;
    case 'planet':
      c.drawCircle(
        mid,
        s * 0.17,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [const Color(0xFFFFFFFF), t.c],
          ).createShader(Rect.fromCircle(center: mid, radius: s * 0.17)),
      );
      c.save();
      c.translate(mid.dx, mid.dy);
      c.rotate(-0.35);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 0.6, height: s * 0.14),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.025
          ..color = t.b,
      );
      c.restore();
    case 'moon':
      c.saveLayer(Rect.fromLTWH(0, 0, s, s), Paint());
      c.drawCircle(mid, s * 0.22, fill);
      c.drawCircle(
        mid + Offset(s * 0.1, -s * 0.06),
        s * 0.2,
        Paint()..blendMode = BlendMode.clear,
      );
      c.restore();
      badge();
    case 'sun':
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        c.drawLine(
          mid + Offset(math.cos(a), math.sin(a)) * s * 0.2,
          mid + Offset(math.cos(a), math.sin(a)) * s * 0.3,
          Paint()
            ..color = t.c
            ..strokeWidth = s * 0.03
            ..strokeCap = StrokeCap.round,
        );
      }
      c.drawCircle(mid, s * 0.16, fill);
      _drawLogo(c, s, t, logo, scale: 0.4);
    case 'star':
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? s * 0.28 : s * 0.12;
        final a = -math.pi / 2 + i * math.pi / 5;
        final o = mid + Offset(math.cos(a), math.sin(a)) * r;
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      c.drawPath(p..close(), fill);
      _drawLogo(c, s, t, logo, scale: 0.34);
    case 'constellation':
      final pts = [
        Offset(s * 0.3, s * 0.34),
        Offset(s * 0.45, s * 0.28),
        Offset(s * 0.58, s * 0.4),
        Offset(s * 0.7, s * 0.33),
        Offset(s * 0.6, s * 0.62),
        Offset(s * 0.4, s * 0.66),
      ];
      final line = Paint()
        ..color = t.c.withValues(alpha: 0.8)
        ..strokeWidth = s * 0.008;
      for (var i = 0; i < pts.length - 1; i++) {
        c.drawLine(pts[i], pts[i + 1], line);
      }
      c.drawLine(pts[2], pts[4], line);
      for (final p in pts) {
        _sparkle(c, p, s * 0.035, const Color(0xFFFFFFFF));
      }
    case 'crystal':
      final p = Path()
        ..moveTo(mid.dx, s * 0.2)
        ..lineTo(s * 0.68, s * 0.42)
        ..lineTo(mid.dx, s * 0.8)
        ..lineTo(s * 0.32, s * 0.42)
        ..close();
      c.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            colors: [const Color(0xFFFFFFFF), t.c, t.b],
          ).createShader(p.getBounds()),
      );
      c.drawLine(
        Offset(s * 0.32, s * 0.42),
        Offset(s * 0.68, s * 0.42),
        Paint()
          ..color = const Color(0x99FFFFFF)
          ..strokeWidth = s * 0.008,
      );
      c.drawLine(
        Offset(mid.dx, s * 0.2),
        Offset(mid.dx, s * 0.8),
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..strokeWidth = s * 0.006,
      );
    case 'mushroom':
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: mid + Offset(0, s * 0.12),
            width: s * 0.16,
            height: s * 0.24,
          ),
          Radius.circular(s * 0.05),
        ),
        light,
      );
      final cap = Path()
        ..moveTo(s * 0.24, s * 0.5)
        ..quadraticBezierTo(s * 0.24, s * 0.22, mid.dx, s * 0.22)
        ..quadraticBezierTo(s * 0.76, s * 0.22, s * 0.76, s * 0.5)
        ..close();
      c.drawPath(cap, fill);
      for (final o in [
        Offset(s * 0.4, s * 0.35),
        Offset(s * 0.58, s * 0.31),
        Offset(s * 0.62, s * 0.44),
        Offset(s * 0.34, s * 0.45),
      ]) {
        c.drawCircle(o, s * 0.03, light);
      }
    case 'leaf':
      c.save();
      c.translate(mid.dx, mid.dy);
      c.rotate(-0.6);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 0.3, height: s * 0.56),
        fill,
      );
      c.drawLine(
        Offset(0, -s * 0.26),
        Offset(0, s * 0.3),
        Paint()
          ..color = t.b
          ..strokeWidth = s * 0.015,
      );
      c.restore();
    case 'cloud':
      for (final (o, r) in [
        (Offset(s * 0.38, s * 0.55), 0.12),
        (Offset(s * 0.52, s * 0.45), 0.16),
        (Offset(s * 0.66, s * 0.56), 0.11),
      ]) {
        c.drawCircle(o, s * r, light);
      }
      c.drawRect(Rect.fromLTWH(s * 0.38, s * 0.52, s * 0.28, s * 0.15), light);
      _drawLogo(c, s, t, logo, scale: 0.3, at: Offset(s * 0.52, s * 0.54));
    case 'drop':
      final p = Path()
        ..moveTo(mid.dx, s * 0.18)
        ..cubicTo(s * 0.56, s * 0.32, s * 0.72, s * 0.46, s * 0.72, s * 0.58)
        ..arcToPoint(
          Offset(s * 0.28, s * 0.58),
          radius: Radius.circular(s * 0.22),
        )
        ..cubicTo(s * 0.28, s * 0.46, s * 0.44, s * 0.32, mid.dx, s * 0.18)
        ..close();
      c.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            colors: [const Color(0xFFFFFFFF), t.c],
          ).createShader(p.getBounds()),
      );
      c.drawOval(
        Rect.fromLTWH(s * 0.36, s * 0.5, s * 0.07, s * 0.12),
        Paint()..color = const Color(0x88FFFFFF),
      );
    case 'flower':
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        c.drawCircle(
          mid + Offset(math.cos(a), math.sin(a)) * s * 0.13,
          s * 0.1,
          fill,
        );
      }
      c.drawCircle(mid, s * 0.09, Paint()..color = t.b);
    case 'heart':
      final p = Path()
        ..moveTo(mid.dx, s * 0.72)
        ..cubicTo(s * 0.12, s * 0.45, s * 0.32, s * 0.16, mid.dx, s * 0.36)
        ..cubicTo(s * 0.68, s * 0.16, s * 0.88, s * 0.45, mid.dx, s * 0.72)
        ..close();
      c.drawPath(p, fill);
      _drawLogo(c, s, t, logo, scale: 0.3, at: Offset(mid.dx, s * 0.48));
    case 'bow':
      for (final dir in [-1, 1]) {
        c.drawPath(
          Path()
            ..moveTo(mid.dx, mid.dy)
            ..quadraticBezierTo(
              mid.dx + dir * s * 0.32,
              s * 0.22,
              mid.dx + dir * s * 0.3,
              mid.dy,
            )
            ..quadraticBezierTo(
              mid.dx + dir * s * 0.32,
              s * 0.7,
              mid.dx,
              mid.dy,
            )
            ..close(),
          fill,
        );
        c.drawPath(
          Path()
            ..moveTo(mid.dx, mid.dy)
            ..lineTo(mid.dx + dir * s * 0.12, s * 0.78)
            ..lineTo(mid.dx + dir * s * 0.02, s * 0.74)
            ..close(),
          Paint()..color = t.b,
        );
      }
      c.drawCircle(mid, s * 0.06, Paint()..color = t.b);
    case 'note':
      final p = Paint()..color = t.c;
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s * 0.4, s * 0.66),
          width: s * 0.18,
          height: s * 0.13,
        ),
        p,
      );
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s * 0.66, s * 0.6),
          width: s * 0.18,
          height: s * 0.13,
        ),
        p,
      );
      c.drawRect(Rect.fromLTWH(s * 0.47, s * 0.26, s * 0.03, s * 0.4), p);
      c.drawRect(Rect.fromLTWH(s * 0.73, s * 0.2, s * 0.03, s * 0.4), p);
      c.drawPath(
        Path()
          ..moveTo(s * 0.47, s * 0.26)
          ..lineTo(s * 0.76, s * 0.2)
          ..lineTo(s * 0.76, s * 0.28)
          ..lineTo(s * 0.47, s * 0.34)
          ..close(),
        p,
      );
    case 'gamepad':
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: mid, width: s * 0.56, height: s * 0.3),
        Radius.circular(s * 0.15),
      );
      c.drawRRect(body, fill);
      c.drawRect(
        Rect.fromCenter(
          center: Offset(s * 0.36, mid.dy),
          width: s * 0.12,
          height: s * 0.035,
        ),
        light,
      );
      c.drawRect(
        Rect.fromCenter(
          center: Offset(s * 0.36, mid.dy),
          width: s * 0.035,
          height: s * 0.12,
        ),
        light,
      );
      c.drawCircle(Offset(s * 0.62, s * 0.47), s * 0.03, Paint()..color = t.b);
      c.drawCircle(Offset(s * 0.68, s * 0.53), s * 0.03, Paint()..color = t.a);
    case 'candy':
      c.drawCircle(mid, s * 0.16, fill);
      for (var k = 0; k < 3; k++) {
        c.drawArc(
          Rect.fromCircle(center: mid, radius: s * (0.05 + k * 0.04)),
          k * 1.0,
          3.5,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.02
            ..color = const Color(0xFFFFFFFF),
        );
      }
      for (final dir in [-1, 1]) {
        c.drawPath(
          Path()
            ..moveTo(mid.dx + dir * s * 0.15, mid.dy)
            ..lineTo(mid.dx + dir * s * 0.3, mid.dy - s * 0.09)
            ..lineTo(mid.dx + dir * s * 0.3, mid.dy + s * 0.09)
            ..close(),
          Paint()..color = t.b,
        );
      }
    case 'arch':
      final p = Path()
        ..moveTo(s * 0.3, s * 0.78)
        ..lineTo(s * 0.3, s * 0.42)
        ..quadraticBezierTo(s * 0.3, s * 0.2, mid.dx, s * 0.18)
        ..quadraticBezierTo(s * 0.7, s * 0.2, s * 0.7, s * 0.42)
        ..lineTo(s * 0.7, s * 0.78)
        ..close();
      c.drawPath(p, Paint()..color = t.b.withValues(alpha: 0.6));
      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.025
          ..color = t.c,
      );
      _drawLogo(c, s, t, logo, scale: 0.55, at: Offset(mid.dx, s * 0.52));
    case 'fan':
      for (var i = 0; i < 7; i++) {
        final a = math.pi + (i + 0.5) * math.pi / 7;
        c.drawPath(
          Path()
            ..moveTo(mid.dx, s * 0.7)
            ..lineTo(
              mid.dx + math.cos(a - 0.2) * s * 0.36,
              s * 0.7 + math.sin(a - 0.2) * s * 0.36,
            )
            ..lineTo(
              mid.dx + math.cos(a + 0.2) * s * 0.36,
              s * 0.7 + math.sin(a + 0.2) * s * 0.36,
            )
            ..close(),
          Paint()..color = (i.isEven ? t.c : t.b),
        );
      }
      _drawLogo(c, s, t, logo, scale: 0.3, at: Offset(mid.dx, s * 0.62));
    case 'bolt':
      c.drawPath(
        Path()
          ..moveTo(s * 0.56, s * 0.18)
          ..lineTo(s * 0.32, s * 0.54)
          ..lineTo(s * 0.48, s * 0.54)
          ..lineTo(s * 0.42, s * 0.82)
          ..lineTo(s * 0.68, s * 0.44)
          ..lineTo(s * 0.52, s * 0.44)
          ..close(),
        fill,
      );
    case 'pencil':
      c.save();
      c.translate(mid.dx, mid.dy);
      c.rotate(math.pi / 4);
      c.drawRect(
        Rect.fromCenter(center: Offset.zero, width: s * 0.12, height: s * 0.46),
        fill,
      );
      c.drawPath(
        Path()
          ..moveTo(-s * 0.06, s * 0.23)
          ..lineTo(s * 0.06, s * 0.23)
          ..lineTo(0, s * 0.33)
          ..close(),
        Paint()..color = const Color(0xFFF2D3A0),
      );
      c.drawRect(
        Rect.fromCenter(
          center: Offset(0, -s * 0.25),
          width: s * 0.12,
          height: s * 0.06,
        ),
        Paint()..color = t.b,
      );
      c.restore();
      badge();
    case 'glyph':
      final g = t.glyph ?? '✨';
      final tp = TextPainter(
        text: TextSpan(
          text: g,
          style: TextStyle(
            fontSize: s * 0.44,
            height: 1,
            fontFamilyFallback: const [
              'NotoColorEmoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, mid - Offset(tp.width / 2, tp.height / 2));
      if (t.logo != 'none') {
        _drawLogo(
          c,
          s,
          t.logo == 'badge' ? t : t,
          logo,
          scale: 0.28,
          at: Offset(s * 0.7, s * 0.7),
        );
      }
  }
}

/// Renders [art] to PNG bytes at [size] px.
Future<ui.Image> renderIconArtImage(
  IconArt art,
  int size, {
  ui.Image? logo,
  int seed = 7,
}) {
  final rec = ui.PictureRecorder();
  paintIconArt(Canvas(rec), size.toDouble(), art, logo: logo, seed: seed);
  return rec.endRecording().toImage(size, size);
}
