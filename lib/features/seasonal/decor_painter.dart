import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_shapes.dart';
import 'package:prism_plurality/features/scrapbook/scrap_washi.dart';
import 'package:prism_plurality/features/seasonal/decor_assets.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_vocab.dart';

const _tau = math.pi * 2;

/// What's on screen right now: the items, the device, and where real parts
/// of the UI currently are (for decorations attached to a profile picture,
/// a widget, a card…).
class DecorScene {
  const DecorScene({
    required this.items,
    required this.layers,
    this.device = DeviceClass.mobile,
    this.route,
    this.uiAnchors = const {},
    this.safe = EdgeInsets.zero,
    this.images = const {},
    this.lightsOn = true,
    this.burst = 0,
  });

  final List<DecorItem> items;
  final DecoLayerSettings layers;
  final DeviceClass device;
  final String? route;
  final Map<DecoAnchor, Rect> uiAnchors;
  final EdgeInsets safe;

  /// Decoded pictures for imported decorations, by media id.
  final Map<String, ui.Image> images;

  /// Interactive fairy lights can be switched off.
  final bool lightsOn;

  /// 0–1: a short burst of extra falling things (a shaken snow globe).
  final double burst;
}

// ── Cached glyphs ──────────────────────────────────────────────────────

final _glyphs = <String, TextPainter>{};

TextPainter _glyph(String g, double size) {
  final s = size.clamp(6.0, 220.0).roundToDouble();
  final key = '$g@$s';
  final hit = _glyphs[key];
  if (hit != null) return hit;
  if (_glyphs.length > 260) _glyphs.remove(_glyphs.keys.first);
  final tp = TextPainter(
    text: TextSpan(
      text: g,
      style: TextStyle(
        fontSize: s,
        fontFamilyFallback: const [
          'NotoColorEmoji',
          'Apple Color Emoji',
          'Segoe UI Emoji',
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return _glyphs[key] = tp;
}

/// Colours for library pieces drawn through [_drawGlyph] (line-art icons,
/// shapes, frames, tape), set per item so they follow its look.
Color _assetTint = const Color(0xFFB07CC6);
Color _assetTint2 = const Color(0xFFFFC857);

final _icons = <String, TextPainter>{};

TextPainter? _iconGlyph(String g, double size, Color color) {
  final icon = decorIconFor(g);
  if (icon == null) return null;
  final s = size.clamp(6.0, 220.0).roundToDouble();
  final key = '$g@$s@${color.toARGB32()}';
  final hit = _icons[key];
  if (hit != null) return hit;
  if (_icons.length > 200) _icons.remove(_icons.keys.first);
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: s,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return _icons[key] = tp;
}

/// Draws a library piece that isn't an emoji. Returns false for emoji.
bool _drawAsset(Canvas c, String g, Offset center, double size) {
  if (g.length < 4 || g[2] != ':') return false;
  final kind = g.substring(0, 2);
  final id = g.substring(3);
  switch (kind) {
    case 'ph':
      final tp = _iconGlyph(g, size, _assetTint);
      if (tp == null) return false;
      // A soft halo of the second colour keeps line art readable on any
      // background.
      final halo = _iconGlyph(g, size, _assetTint2.withValues(alpha: 0.35));
      halo?.paint(c, center - Offset(halo.width / 2 - 1, halo.height / 2 - 1));
      tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
      return true;
    case 'sh':
      c.save();
      c.translate(center.dx - size / 2, center.dy - size / 2);
      ScrapShapePainter(
        shape: id,
        fill: _assetTint,
        fill2: _assetTint2,
        border: _assetTint2,
        borderWidth: size * 0.03,
      ).paint(c, Size.square(size));
      c.restore();
      return true;
    case 'wa':
      final w = washiPatterns.where((p) => p.id == id).firstOrNull;
      if (w == null) return false;
      c.save();
      c.translate(center.dx - size / 2, center.dy - size / 8);
      WashiPainter(w).paint(c, Size(size, size / 4));
      c.restore();
      return true;
    case 'fr':
      final f = scrapFrameById(id);
      if (f == null) return false;
      c.save();
      c.translate(center.dx - size / 2, center.dy - size / 2);
      paintScrapFrame(c, Size.square(size), f, tint: null);
      c.restore();
      return true;
  }
  return false;
}

/// Draws any decoration glyph (emoji or library piece) for previews and
/// pickers, in the given colours.
void paintDecorGlyph(
  Canvas c,
  String g,
  Offset center,
  double size, {
  Color tint = const Color(0xFFB07CC6),
  Color tint2 = const Color(0xFFFFC857),
}) {
  _assetTint = tint;
  _assetTint2 = tint2;
  _drawGlyph(c, g, center, size);
}

void _drawGlyph(
  Canvas c,
  String g,
  Offset center,
  double size, {
  double rot = 0,
  double alpha = 1,
}) {
  if (g.length > 3 && g[2] == ':') {
    c.save();
    c.translate(center.dx, center.dy);
    if (rot != 0) c.rotate(rot);
    if (alpha < 1) {
      c.saveLayer(
        Rect.fromCircle(center: Offset.zero, radius: size),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
    final drawn = _drawAsset(c, g, Offset.zero, size);
    if (alpha < 1) c.restore();
    c.restore();
    if (drawn) return;
  }
  final tp = _glyph(g, size);
  c.save();
  c.translate(center.dx, center.dy);
  if (rot != 0) c.rotate(rot);
  if (alpha < 1) {
    c.saveLayer(
      Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 4,
        height: tp.height + 4,
      ),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
  }
  tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
  if (alpha < 1) c.restore();
  c.restore();
}

double _hash01(Object o, [int salt = 0]) {
  var h = o.hashCode ^ (salt * 0x9E3779B1);
  h = (h ^ (h >> 15)) * 0x2C1B3C6D & 0x7fffffff;
  h = (h ^ (h >> 12)) * 0x297A2D39 & 0x7fffffff;
  return ((h ^ (h >> 15)) & 0xffff) / 0xffff;
}

Color _c(int v, [double a = 1]) => Color(v).withValues(alpha: a);

/// [v] (or a neutral look when the piece has none) with one part pinned:
/// `g` garland, `l` lights, `b` border, `c` corner, `p` falling things.
SeasonalVariation? _pinStyle(SeasonalVariation? v, String part, String style) {
  final base = v ?? livingCollections.first.variations.first;
  return switch (part) {
    'g' => base.withStyle(garland: garlandOf(style)),
    'l' => base.withStyle(lights: lightsOf(style)),
    'b' => base.withStyle(border: borderOf(style)),
    'c' => base.withStyle(corner: cornerOf(style)),
    'p' => base.withStyle(particle: particleOf(style)),
    _ => v,
  };
}

/// Draws everything for one frame. One painter, one pass: items are
/// clipped to the layers that are on and to the pages they belong to.
class DecorPainter extends CustomPainter {
  DecorPainter({
    required this.scene,
    required double t,
    required this.layersToDraw,
    Listenable? repaint,
  }) : _t0 = t,
       _clock = repaint is ValueListenable<double> ? repaint : null,
       super(repaint: repaint);

  final DecorScene scene;
  final double _t0;

  /// The shared clock this painter repaints on, read at paint time so every
  /// repaint draws the current frame (not the one from the last rebuild).
  final ValueListenable<double>? _clock;

  /// Seconds on the shared clock; 0 when nothing should move.
  double get t => _clock?.value ?? _t0;

  /// Which layers this painter draws (static / animated / ambient).
  final Set<DecoLayer> layersToDraw;

  @override
  void paint(Canvas canvas, Size size) {
    final items = [
      for (final i in scene.items)
        if (i.enabled &&
            layersToDraw.contains(i.layer) &&
            scene.layers.on(i.layer) &&
            i.showsOn(scene.route) &&
            !i.tweakFor(scene.device).hidden &&
            i.kind != DecoKind.interactive)
          i,
    ]..sort((a, b) => a.z.compareTo(b.z));
    var animatedDrawn = 0;
    for (final item in items) {
      if (item.layer == DecoLayer.animated) {
        if (animatedDrawn >= scene.layers.maxAnimated) continue;
        animatedDrawn++;
      }
      final frame = frameFor(item.anchor, size);
      if (frame == null) continue;
      _drawItem(canvas, size, item, frame);
    }
  }

  /// The rectangle an anchor refers to on this screen, or null when it
  /// follows a part of the UI that isn't showing.
  Rect? frameFor(DecoAnchor a, Size s) {
    final safe = scene.safe;
    final w = s.width, h = s.height;
    switch (a) {
      case DecoAnchor.screen || DecoAnchor.floating || DecoAnchor.loading:
        return Offset.zero & s;
      case DecoAnchor.top:
        return Rect.fromLTWH(0, 0, w, safe.top + 64);
      case DecoAnchor.pageHeader:
        return scene.uiAnchors[a] ?? Rect.fromLTWH(0, safe.top, w, 72);
      case DecoAnchor.calendarHeader:
        return scene.uiAnchors[a] ?? Rect.fromLTWH(0, safe.top + 56, w, 72);
      case DecoAnchor.bottom:
        return Rect.fromLTWH(0, h - safe.bottom - 96, w, safe.bottom + 96);
      case DecoAnchor.sidebar:
        return Rect.fromLTWH(0, 0, math.min(260, w * 0.3), h);
      case DecoAnchor.topLeft:
        return Rect.fromLTWH(0, safe.top, 120, 120);
      case DecoAnchor.topRight:
        return Rect.fromLTWH(w - 120, safe.top, 120, 120);
      case DecoAnchor.bottomLeft:
        return Rect.fromLTWH(0, h - safe.bottom - 100 - 96, 120, 120);
      case DecoAnchor.bottomRight:
        return Rect.fromLTWH(w - 120, h - safe.bottom - 100 - 96, 120, 120);
      case DecoAnchor.dashboardEdge:
        return Rect.fromLTWH(0, safe.top + 64, w, 140);
      case DecoAnchor.empty:
        return Rect.fromLTWH(w * 0.2, h * 0.35, w * 0.6, h * 0.3);
      case DecoAnchor.profilePicture ||
          DecoAnchor.banner ||
          DecoAnchor.widget ||
          DecoAnchor.card ||
          DecoAnchor.divider ||
          DecoAnchor.companionArea:
        return scene.uiAnchors[a];
    }
  }

  // ── Items ───────────────────────────────────────────────────────────

  void _drawItem(Canvas canvas, Size size, DecorItem item, Rect frame) {
    var v = item.variationId == null ? null : variationById(item.variationId!);
    // A library piece can pin one part to a specific style.
    final pinned = decorStyleOf(item.glyph);
    if (pinned != null) v = _pinStyle(v, pinned.part, pinned.style);
    final tw = item.tweakFor(scene.device);
    final speed = item.speed * scene.layers.animationSpeed;
    final phase = _hash01(item.id) * _tau;
    final pal = v?.palette;
    final main = item.color ?? pal?.primary ?? 0xFFB07CC6;
    final second = item.color2 ?? pal?.secondary ?? 0xFFFFC857;
    final accent = pal?.accent ?? 0xFF6B4E9B;
    _assetTint = Color(main);
    _assetTint2 = Color(second);

    final width = frame.width * item.w * tw.scale;
    final cx = frame.left + frame.width * (item.x + tw.dx);
    final cy = frame.top + frame.height * (item.y + tw.dy);

    canvas.save();
    if (item.opacity < 1) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white.withValues(alpha: item.opacity),
      );
    }
    // Flip and rotate around the item's own origin.
    canvas.translate(cx, cy);
    if (item.rot != 0) canvas.rotate(item.rot * math.pi / 180);
    if (item.flipX || item.flipY)
      canvas.scale(item.flipX ? -1 : 1, item.flipY ? -1 : 1);

    switch (item.kind) {
      case DecoKind.garland:
        _garland(
          canvas,
          frame,
          item,
          v,
          width,
          main,
          second,
          accent,
          t * speed,
          phase,
        );
      case DecoKind.fairyLights:
        _lights(canvas, frame, item, v, width, main, second, t * speed, phase);
      case DecoKind.ribbon:
        _ribbon(canvas, width, main, second);
      case DecoKind.bow:
        _bow(canvas, width, main, second);
      case DecoKind.lantern:
        _lantern(canvas, width, main, second, t * speed, phase);
      case DecoKind.wreath:
        _wreath(
          canvas,
          width,
          main,
          second,
          accent,
          item.glyph ?? v?.icons.first,
        );
      case DecoKind.ornament:
        _ornament(canvas, frame, item, width, main, second, t * speed, phase);
      case DecoKind.window:
        _window(canvas, width, main, second, accent, t * speed, phase);
      case DecoKind.flower:
        _cluster(canvas, item.glyph ?? '🌷', width, t * speed, phase, 3);
      case DecoKind.candle:
        _candle(canvas, width, t * speed, phase);
      case DecoKind.foliage:
        _foliage(canvas, width, main, second);
      case DecoKind.corner:
        _corner(canvas, v, width, main, second, accent, t * speed, phase);
      case DecoKind.border:
        // Borders are drawn in screen space, not around the origin.
        canvas.translate(-cx, -cy);
        _border(
          canvas,
          frame,
          v?.border ?? DecoBorder.hairline,
          main,
          accent,
          second,
        );
      case DecoKind.illustration:
        _drawGlyph(
          canvas,
          item.glyph ?? v?.icons.first ?? '✨',
          Offset.zero,
          width,
        );
      case DecoKind.furniture:
        _drawGlyph(canvas, item.glyph ?? '🪑', Offset.zero, width);
      case DecoKind.sticker:
        _sticker(canvas, item, width);
      case DecoKind.particles:
        canvas.translate(-cx, -cy);
        _particles(canvas, frame, item, v, t * speed, scene.burst);
      case DecoKind.interactive:
        break;
    }
    if (item.opacity < 1) canvas.restore();
    canvas.restore();
  }

  // ── Garlands ────────────────────────────────────────────────────────

  /// A drape across [width]: three swags sagging from the top edge.
  Path _swags(
    double width,
    double sag, {
    int swags = 3,
    double wobble = 0,
    double phase = 0,
  }) {
    final p = Path()..moveTo(-width / 2, 0);
    final sw = width / swags;
    for (var i = 0; i < swags; i++) {
      final x0 = -width / 2 + sw * i, x1 = x0 + sw;
      final s = sag * (1 + 0.15 * math.sin(wobble + phase + i));
      p.cubicTo(x0 + sw * 0.25, s, x1 - sw * 0.25, s, x1, 0);
    }
    return p;
  }

  /// Points evenly spaced along [path], with a unit tangent.
  List<(Offset, double)> _along(Path path, double step) {
    final out = <(Offset, double)>[];
    for (final m in path.computeMetrics()) {
      for (var d = step / 2; d < m.length; d += step) {
        final tan = m.getTangentForOffset(d);
        if (tan != null)
          out.add((tan.position, math.atan2(tan.vector.dy, tan.vector.dx)));
      }
    }
    return out;
  }

  void _garland(
    Canvas c,
    Rect frame,
    DecorItem item,
    SeasonalVariation? v,
    double width,
    int main,
    int second,
    int accent,
    double tt,
    double phase,
  ) {
    final style = v?.garland ?? GarlandStyle.vine;
    final sag = math.max(10.0, width * 0.035);
    final path = _swags(width, sag, wobble: tt * 0.6, phase: phase);
    final unit = math.max(12.0, math.min(26.0, width / 18));
    final points = _along(path, unit * 1.15);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final pal = [main, second, accent, v?.palette.base ?? 0xFFFFFFFF];
    switch (style) {
      case GarlandStyle.kente:
        // A woven strip: blocks of colour with dark weft stripes and a
        // little zigzag in each block, like kente cloth.
        const weft = 0xFF1A1A1A;
        for (var i = 0; i < points.length; i++) {
          final (p, a) = points[i];
          final w = unit * 1.16, h = unit * 0.78;
          c.save();
          c.translate(p.dx, p.dy + unit * 0.3);
          c.rotate(a);
          final block = Rect.fromCenter(
            center: Offset.zero,
            width: w,
            height: h,
          );
          c.drawRect(block, Paint()..color = _c(pal[i % 3]));
          c.drawRect(
            Rect.fromLTWH(block.left, block.top, w, h * 0.14),
            Paint()..color = _c(weft, 0.9),
          );
          c.drawRect(
            Rect.fromLTWH(block.left, block.bottom - h * 0.14, w, h * 0.14),
            Paint()..color = _c(weft, 0.9),
          );
          final z = Path()..moveTo(block.left, 0);
          for (var k = 0; k <= 4; k++) {
            z.lineTo(block.left + w * k / 4, k.isEven ? -h * 0.16 : h * 0.16);
          }
          c.drawPath(
            z,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = _c(pal[(i + 1) % 3]),
          );
          if (i.isOdd) {
            c.drawRect(
              Rect.fromCenter(
                center: Offset.zero,
                width: w * 0.18,
                height: h * 0.18,
              ),
              Paint()..color = _c(pal[(i + 2) % 3]),
            );
          }
          c.restore();
        }
      case GarlandStyle.papel:
        // Papel picado: cut-paper banners with little holes punched out.
        c.drawPath(
          path,
          line
            ..color = _c(0xFF6B5B4B, 0.8)
            ..strokeWidth = 1.1,
        );
        for (var i = 0; i < points.length; i++) {
          final p = points[i].$1;
          final w = unit * 1.05, h = unit * 1.35;
          final sway = math.sin(tt * 1.3 + i + phase) * 0.06;
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(sway);
          final flag = Path()
            ..moveTo(-w / 2, 0)
            ..lineTo(w / 2, 0)
            ..lineTo(w / 2, h * 0.86);
          for (var k = 4; k >= 0; k--) {
            flag.lineTo(-w / 2 + w * k / 4, k.isEven ? h : h * 0.86);
          }
          flag.close();
          final holes = Path();
          for (var k = 0; k < 3; k++) {
            final y = h * (0.25 + k * 0.22);
            holes.addOval(
              Rect.fromCenter(
                center: Offset(0, y),
                width: w * 0.22,
                height: w * 0.22,
              ),
            );
            holes.addRect(
              Rect.fromCenter(
                center: Offset(-w * 0.28, y),
                width: w * 0.1,
                height: w * 0.1,
              ),
            );
            holes.addRect(
              Rect.fromCenter(
                center: Offset(w * 0.28, y),
                width: w * 0.1,
                height: w * 0.1,
              ),
            );
          }
          c.drawPath(
            Path.combine(PathOperation.difference, flag, holes),
            Paint()
              ..color = _c(
                pal[i % 4] == (v?.palette.base ?? 0) ? main : pal[i % 4],
                0.92,
              ),
          );
          c.restore();
        }
      case GarlandStyle.streamers:
        c.drawPath(
          path,
          line
            ..color = _c(main, 0.7)
            ..strokeWidth = 1.6,
        );
        for (var i = 0; i < points.length; i += 2) {
          final p = points[i].$1;
          final curl = Path()..moveTo(p.dx, p.dy);
          final len = unit * (2.2 + 1.2 * _hash01(i, 9));
          for (var k = 1; k <= 12; k++) {
            final y = p.dy + len * k / 12;
            final x = p.dx + math.sin(k * 0.9 + tt * 1.6 + i) * unit * 0.32;
            curl.lineTo(x, y);
          }
          c.drawPath(
            curl,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = unit * 0.16
              ..strokeCap = StrokeCap.round
              ..color = _c(pal[(i ~/ 2) % 3]),
          );
        }
      case GarlandStyle.tassels:
        c.drawPath(
          path,
          line
            ..color = _c(main)
            ..strokeWidth = 2,
        );
        for (var i = 0; i < points.length; i++) {
          final p = points[i].$1;
          final col = _c(pal[i % 3]);
          final sway = math.sin(tt + i * 0.7 + phase) * unit * 0.12;
          c.drawCircle(
            p + Offset(0, unit * 0.12),
            unit * 0.18,
            Paint()..color = col,
          );
          for (var k = -3; k <= 3; k++) {
            c.drawLine(
              p + Offset(k * unit * 0.05, unit * 0.25),
              p + Offset(k * unit * 0.07 + sway, unit * 1.1),
              Paint()
                ..color = col
                ..strokeWidth = 1.3,
            );
          }
        }
      case GarlandStyle.flags:
        c.drawPath(
          path,
          line
            ..color = _c(0xFF5B4B3B, 0.8)
            ..strokeWidth = 1.2,
        );
        for (var i = 0; i < points.length; i++) {
          final p = points[i].$1;
          final w = unit * 1.05, h = unit * 0.95;
          final flag = Path()
            ..moveTo(p.dx - w / 2, p.dy)
            ..lineTo(p.dx + w / 2, p.dy)
            ..lineTo(p.dx + w / 2, p.dy + h)
            ..lineTo(p.dx, p.dy + h * 0.72)
            ..lineTo(p.dx - w / 2, p.dy + h)
            ..close();
          c.drawPath(flag, Paint()..color = _c(pal[i % 3]));
          c.drawLine(
            Offset(p.dx - w / 2, p.dy + h * 0.3),
            Offset(p.dx + w / 2, p.dy + h * 0.3),
            Paint()
              ..color = _c(pal[(i + 1) % 3], 0.8)
              ..strokeWidth = 2,
          );
        }
      case GarlandStyle.vine:
        c.drawPath(
          path,
          line
            ..color = _c(0xFF3F6B3A)
            ..strokeWidth = 2.2,
        );
        for (var i = 0; i < points.length; i++) {
          final (p, a) = points[i];
          final flip = i.isEven ? 1 : -1;
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(a + flip * 0.9);
          c.drawOval(
            Rect.fromLTWH(0, -unit * 0.22, unit * 0.9, unit * 0.44),
            Paint()..color = _c(i % 3 == 0 ? second : main, 0.95),
          );
          c.restore();
        }
        for (var i = 3; i < points.length; i += 5) {
          c.drawCircle(
            points[i].$1 + Offset(0, unit * 0.2),
            unit * 0.22,
            Paint()..color = _c(accent),
          );
        }
      case GarlandStyle.bunting:
        c.drawPath(
          path,
          line
            ..color = _c(0xFF6B5B4B, 0.8)
            ..strokeWidth = 1.2,
        );
        for (var i = 0; i < points.length; i++) {
          final p = points[i].$1;
          final tri = Path()
            ..moveTo(p.dx - unit * 0.55, p.dy)
            ..lineTo(p.dx + unit * 0.55, p.dy)
            ..lineTo(p.dx, p.dy + unit * 1.1)
            ..close();
          c.drawPath(tri, Paint()..color = _c(pal[i % 3]));
        }
      case GarlandStyle.ribbon:
        c.drawPath(
          path,
          line
            ..color = _c(main)
            ..strokeWidth = unit * 0.55,
        );
        c.drawPath(
          path,
          line
            ..color = _c(second, 0.8)
            ..strokeWidth = unit * 0.14,
        );
      case GarlandStyle.beads:
        c.drawPath(
          path,
          line
            ..color = _c(0xFF8B8B8B, 0.6)
            ..strokeWidth = 1,
        );
        for (var i = 0; i < points.length; i++) {
          final p = points[i].$1;
          c.drawCircle(
            p + Offset(0, unit * 0.2),
            unit * 0.3,
            Paint()..color = _c(pal[i % 4]),
          );
          c.drawCircle(
            p + Offset(-unit * 0.08, unit * 0.1),
            unit * 0.08,
            Paint()..color = Colors.white.withValues(alpha: 0.7),
          );
        }
      case GarlandStyle.tinsel:
        for (var i = 0; i < points.length * 3; i++) {
          final k = i / (points.length * 3);
          final m = path.computeMetrics().first;
          final tan = m.getTangentForOffset(m.length * k);
          if (tan == null) continue;
          final len = unit * (0.5 + 0.5 * _hash01(i));
          final ang = _hash01(i, 3) * math.pi;
          c.drawLine(
            tan.position,
            tan.position + Offset(math.cos(ang), math.sin(ang).abs()) * len,
            Paint()
              ..color = _c(pal[i % 3], 0.9)
              ..strokeWidth = 1.4,
          );
        }
      case GarlandStyle.chain:
        for (var i = 0; i < points.length; i++) {
          final (p, a) = points[i];
          c.save();
          c.translate(p.dx, p.dy + unit * 0.15);
          c.rotate(a);
          c.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: unit * 0.95,
              height: unit * 0.55,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = unit * 0.16
              ..color = _c(pal[i % 3]),
          );
          c.restore();
        }
      case GarlandStyle.pompom:
        c.drawPath(
          path,
          line
            ..color = _c(0xFF9A8F85, 0.7)
            ..strokeWidth = 1.1,
        );
        for (var i = 0; i < points.length; i++) {
          final p = points[i].$1 + Offset(0, unit * 0.45);
          for (var k = 0; k < 6; k++) {
            final a = k * _tau / 6;
            c.drawCircle(
              p + Offset(math.cos(a), math.sin(a)) * unit * 0.14,
              unit * 0.2,
              Paint()..color = _c(pal[i % 3], 0.95),
            );
          }
          c.drawCircle(p, unit * 0.22, Paint()..color = _c(pal[i % 3]));
        }
      case GarlandStyle.swag:
        final drape = Path.from(path);
        final fill = Path.from(path)
          ..relativeLineTo(0, 0)
          ..lineTo(width / 2, -2)
          ..lineTo(-width / 2, -2)
          ..close();
        c.drawPath(fill, Paint()..color = _c(main, 0.25));
        c.drawPath(
          drape,
          line
            ..color = _c(main)
            ..strokeWidth = unit * 0.34,
        );
        for (var i = 0; i < points.length; i += 2) {
          c.drawCircle(points[i].$1, unit * 0.2, Paint()..color = _c(second));
        }
      case GarlandStyle.emoji:
        c.drawPath(
          path,
          line
            ..color = _c(second, 0.55)
            ..strokeWidth = 1.2,
        );
        final glyphs = v?.garlandEmoji ?? const ['✨'];
        for (var i = 0; i < points.length; i++) {
          final (p, a) = points[i];
          _drawGlyph(
            c,
            glyphs[i % glyphs.length],
            p + Offset(0, unit * 0.45),
            unit * 1.05,
            rot: a * 0.4 + math.sin(tt * 0.8 + i + phase) * 0.06,
          );
        }
    }
  }

  // ── Lights ──────────────────────────────────────────────────────────

  void _lights(
    Canvas c,
    Rect frame,
    DecorItem item,
    SeasonalVariation? v,
    double width,
    int main,
    int second,
    double tt,
    double phase,
  ) {
    final style = v?.lights ?? LightsStyle.fairy;
    final path = _swags(
      width,
      math.max(14.0, width * 0.045),
      swags: 4,
      phase: phase,
    );
    final points = _along(path, math.max(22.0, width / 26));
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x886B6B6B),
    );
    final on = scene.lightsOn;
    if (style == LightsStyle.neon) {
      // A glowing tube along the line instead of separate bulbs.
      final flicker = on ? 0.75 + 0.25 * math.sin(tt * 3.1 + phase) : 0.15;
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = _c(main, 0.22 * flicker)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..color = _c(main, flicker),
      );
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.7 * flicker),
      );
      return;
    }
    final colors = style == LightsStyle.fairy
        ? [0xFFFFE9A8, 0xFFFFD27A, 0xFFFFF3C9]
        : [
            main,
            second,
            v?.palette.accent ?? 0xFFFFFFFF,
            v?.palette.base ?? 0xFFFFEDB0,
          ];
    for (var i = 0; i < points.length; i++) {
      final p = points[i].$1 + const Offset(0, 5);
      // Gentle twinkle; `frequency` decides how many bulbs flicker at all.
      final twinkles = _hash01(i, 5) < item.frequency;
      final glow = on
          ? (twinkles
                ? 0.55 + 0.45 * math.sin(tt * 2.2 + i * 1.7 + phase)
                : 0.85)
          : 0.15;
      final col = colors[i % colors.length];
      switch (style) {
        case LightsStyle.icicle:
          final len = 10 + 10 * _hash01(i, 6);
          final ice = Path()
            ..moveTo(p.dx - 3, p.dy - 4)
            ..lineTo(p.dx + 3, p.dy - 4)
            ..lineTo(p.dx, p.dy - 4 + len)
            ..close();
          c.drawPath(
            ice,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  const Color(0xFFBFE3FF).withValues(alpha: 0.6 * glow),
                ],
              ).createShader(Rect.fromLTWH(p.dx - 3, p.dy - 4, 6, len)),
          );
          c.drawCircle(
            Offset(p.dx, p.dy - 4 + len),
            2.2,
            Paint()..color = Colors.white.withValues(alpha: 0.5 * glow),
          );
        case LightsStyle.diya:
          // A small clay lamp with a living flame.
          final bowl = Path()
            ..moveTo(p.dx - 7, p.dy + 2)
            ..quadraticBezierTo(p.dx, p.dy + 11, p.dx + 7, p.dy + 2)
            ..lineTo(p.dx + 9, p.dy)
            ..close();
          c.drawPath(bowl, Paint()..color = _c(i.isEven ? 0xFFB5532A : main));
          c.drawCircle(
            Offset(p.dx, p.dy - 4),
            7,
            Paint()
              ..color = const Color(0xFFFFB347).withValues(alpha: 0.25 * glow),
          );
          final flame = Path()
            ..moveTo(p.dx, p.dy - 9 - 2 * glow)
            ..quadraticBezierTo(p.dx + 3.4, p.dy - 2, p.dx, p.dy)
            ..quadraticBezierTo(
              p.dx - 3.4,
              p.dy - 2,
              p.dx,
              p.dy - 9 - 2 * glow,
            );
          c.drawPath(
            flame,
            Paint()
              ..color = const Color(
                0xFFFFC94D,
              ).withValues(alpha: glow.clamp(0.3, 1.0)),
          );
        case LightsStyle.stars:
          _drawGlyph(
            c,
            '⭐',
            p + const Offset(0, 4),
            13,
            alpha: glow.clamp(0.2, 1.0),
          );
        case LightsStyle.lanterns:
          _miniLantern(c, p, col, glow);
        case LightsStyle.candles:
          _drawGlyph(
            c,
            '🕯️',
            p + const Offset(0, 6),
            15,
            alpha: glow.clamp(0.3, 1.0),
          );
        case _:
          c.drawCircle(p, 9, Paint()..color = _c(col, 0.16 * glow));
          c.drawCircle(p, 5.5, Paint()..color = _c(col, 0.3 * glow));
          c.drawCircle(p, 3.2, Paint()..color = _c(col, glow.clamp(0.2, 1.0)));
      }
    }
  }

  void _miniLantern(Canvas c, Offset p, int col, double glow) {
    c.drawLine(
      p - const Offset(0, 5),
      p,
      Paint()
        ..color = const Color(0x886B6B6B)
        ..strokeWidth = 1,
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: p + const Offset(0, 8), width: 9, height: 13),
      const Radius.circular(3.5),
    );
    c.drawCircle(
      p + const Offset(0, 8),
      10,
      Paint()..color = _c(col, 0.18 * glow),
    );
    c.drawRRect(body, Paint()..color = _c(col, 0.55 + 0.4 * glow));
    c.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x886B4E2B),
    );
  }

  // ── Ribbons and bows ────────────────────────────────────────────────

  void _ribbon(Canvas c, double width, int main, int second) {
    final p = Path()..moveTo(-width / 2, 0);
    for (var i = 0; i < 4; i++) {
      final x = -width / 2 + width * (i + 1) / 4;
      p.quadraticBezierTo(x - width / 8, i.isEven ? 14 : -14, x, 0);
    }
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..color = _c(main)
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = _c(second, 0.85),
    );
  }

  void _bow(Canvas c, double width, int main, int second) {
    final r = width / 2;
    final loop = Paint()..color = _c(main);
    for (final s in [-1.0, 1.0]) {
      c.save();
      c.scale(s, 1);
      final p = Path()
        ..moveTo(0, 0)
        ..cubicTo(r * 0.5, -r * 0.9, r * 1.05, -r * 0.4, r * 0.95, r * 0.15)
        ..cubicTo(r * 0.8, r * 0.55, r * 0.3, r * 0.3, 0, 0);
      c.drawPath(p, loop);
      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _c(second, 0.7),
      );
      final tail = Path()
        ..moveTo(0, 0)
        ..lineTo(r * 0.35, r * 1.0)
        ..lineTo(r * 0.12, r * 0.88)
        ..lineTo(r * 0.0, r * 1.05)
        ..close();
      c.drawPath(tail, Paint()..color = _c(main, 0.9));
      c.restore();
    }
    c.drawCircle(Offset.zero, r * 0.2, Paint()..color = _c(second));
  }

  // ── Hanging things ──────────────────────────────────────────────────

  void _lantern(
    Canvas c,
    double width,
    int main,
    int second,
    double tt,
    double phase,
  ) {
    final sway = math.sin(tt * 0.9 + phase) * 0.07;
    c.rotate(sway);
    final h = width * 1.35;
    c.drawLine(
      Offset.zero,
      Offset(0, width * 0.4),
      Paint()
        ..color = const Color(0xAA6B5B4B)
        ..strokeWidth = 1.2,
    );
    final flick = 0.8 + 0.2 * math.sin(tt * 5 + phase);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(-width / 2, width * 0.4, width, h),
      Radius.circular(width * 0.35),
    );
    c.drawCircle(
      Offset(0, width * 0.4 + h / 2),
      width * 0.9,
      Paint()..color = _c(second, 0.16 * flick),
    );
    c.drawRRect(body, Paint()..color = _c(main));
    c.drawRRect(
      body.deflate(width * 0.12),
      Paint()..color = _c(second, 0.5 + 0.4 * flick),
    );
    for (var i = -1; i <= 1; i++) {
      c.drawLine(
        Offset(i * width * 0.22, width * 0.45),
        Offset(i * width * 0.22, width * 0.4 + h - 2),
        Paint()
          ..color = _c(main, 0.7)
          ..strokeWidth = 1,
      );
    }
    c.drawRect(
      Rect.fromLTWH(-width * 0.22, width * 0.34, width * 0.44, width * 0.1),
      Paint()..color = const Color(0xCC3E2F22),
    );
  }

  void _ornament(
    Canvas c,
    Rect frame,
    DecorItem item,
    double width,
    int main,
    int second,
    double tt,
    double phase,
  ) {
    final sway = math.sin(tt * 1.1 + phase) * 0.09;
    c.rotate(sway);
    final drop = math.max(18.0, frame.height * 0.22);
    c.drawLine(
      Offset.zero,
      Offset(0, drop),
      Paint()
        ..color = const Color(0x99806E5E)
        ..strokeWidth = 1,
    );
    final centre = Offset(0, drop + width * 0.5);
    if (item.glyph != null) {
      _drawGlyph(c, item.glyph!, centre, width * 1.1);
      return;
    }
    c.drawCircle(
      centre,
      width * 0.5,
      Paint()
        ..shader = ui.Gradient.radial(
          centre - Offset(width * 0.15, width * 0.15),
          width * 0.7,
          [_c(second), _c(main)],
        ),
    );
    c.drawCircle(
      centre - Offset(width * 0.17, width * 0.17),
      width * 0.1,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    c.drawRect(
      Rect.fromCenter(
        center: centre - Offset(0, width * 0.52),
        width: width * 0.22,
        height: width * 0.1,
      ),
      Paint()..color = const Color(0xFFCDB26B),
    );
  }

  void _window(
    Canvas c,
    double width,
    int main,
    int second,
    int accent,
    double tt,
    double phase,
  ) {
    final h = width * 1.25;
    final rect = Rect.fromCenter(center: Offset.zero, width: width, height: h);
    final arch = Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + width / 2)
      ..arcToPoint(
        Offset(rect.right, rect.top + width / 2),
        radius: Radius.circular(width / 2),
      )
      ..lineTo(rect.right, rect.bottom)
      ..close();
    final glow = 0.75 + 0.25 * math.sin(tt * 1.3 + phase);
    c.drawPath(
      arch,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
          _c(second, 0.9 * glow),
          _c(main, 0.55),
        ]),
    );
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, width * 0.06)
      ..color = _c(accent);
    c.drawPath(arch, frame);
    c.drawLine(
      Offset(0, rect.top + 2),
      Offset(0, rect.bottom),
      frame..strokeWidth = 1.6,
    );
    c.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      frame,
    );
  }

  // ── Little things ───────────────────────────────────────────────────

  void _cluster(
    Canvas c,
    String g,
    double width,
    double tt,
    double phase,
    int n,
  ) {
    for (var i = 0; i < n; i++) {
      final off = Offset(
        (i - (n - 1) / 2) * width * 0.5,
        (i.isEven ? 0 : -width * 0.25),
      );
      _drawGlyph(
        c,
        g,
        off,
        width * 0.7,
        rot: math.sin(tt * 0.9 + phase + i) * 0.1,
      );
    }
  }

  void _candle(Canvas c, double width, double tt, double phase) {
    final flick =
        0.7 + 0.3 * math.sin(tt * 6 + phase) * math.cos(tt * 3.7 + phase);
    c.drawCircle(
      Offset(0, -width * 0.2),
      width * 0.9,
      Paint()..color = const Color(0xFFFFC857).withValues(alpha: 0.13 * flick),
    );
    _drawGlyph(c, '🕯️', Offset.zero, width);
  }

  void _foliage(Canvas c, double width, int main, int second) {
    for (var i = -1; i <= 1; i++) {
      final stem = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(
          i * width * 0.25,
          -width * 0.5,
          i * width * 0.42,
          -width * 0.95,
        );
      c.drawPath(
        stem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _c(0xFF4E6B3A),
      );
      for (var k = 1; k <= 4; k++) {
        final tpos = k / 4.5;
        final pt = Offset(i * width * 0.42 * tpos, -width * 0.95 * tpos);
        c.save();
        c.translate(pt.dx, pt.dy);
        c.rotate((k.isEven ? -1 : 1) * 0.9 + i * 0.2);
        c.drawOval(
          Rect.fromLTWH(0, -width * 0.06, width * 0.3, width * 0.12),
          Paint()..color = _c(k.isEven ? main : second, 0.95),
        );
        c.restore();
      }
    }
  }

  void _wreath(
    Canvas c,
    double width,
    int main,
    int second,
    int accent,
    String? glyph,
  ) {
    final r = width / 2;
    for (var k = 0; k < 20; k++) {
      final a = k * _tau / 20;
      final p = Offset(math.cos(a), math.sin(a)) * r * 0.82;
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(a + math.pi / 2 + (k.isEven ? 0.55 : -0.55));
      c.drawOval(
        Rect.fromLTWH(0, -r * 0.09, r * 0.34, r * 0.18),
        Paint()..color = _c(k % 3 == 0 ? second : main, 0.95),
      );
      c.restore();
    }
    for (var k = 0; k < 5; k++) {
      final a = k * _tau / 5 + 0.4;
      c.drawCircle(
        Offset(math.cos(a), math.sin(a)) * r * 0.82,
        r * 0.07,
        Paint()..color = _c(accent),
      );
    }
    if (glyph != null) _drawGlyph(c, glyph, Offset(0, r * 0.82), r * 0.36);
  }

  void _sticker(Canvas c, DecorItem item, double width) {
    final img = item.image == null ? null : scene.images[item.image!];
    if (img == null) return;
    final ratio = img.width / img.height;
    final dst = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: width / ratio,
    );
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  // ── Corner pieces ───────────────────────────────────────────────────

  void _corner(
    Canvas c,
    SeasonalVariation? v,
    double width,
    int main,
    int second,
    int accent,
    double tt,
    double phase,
  ) {
    final style = v?.corner ?? CornerStyle.cluster;
    final glyphs = v?.cornerEmoji ?? const ['✨', '🌿', '⭐'];
    final s = width;
    switch (style) {
      case CornerStyle.kinara:
        // Seven candles (mishumaa saba): three red, one black, three green.
        const candles = [
          0xFFC8102E,
          0xFFC8102E,
          0xFFC8102E,
          0xFF161616,
          0xFF1E7B34,
          0xFF1E7B34,
          0xFF1E7B34,
        ];
        final baseY = s * 0.62, left = s * 0.08, w = s * 0.84;
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, baseY, w, s * 0.08),
            Radius.circular(s * 0.02),
          ),
          Paint()..color = _c(0xFF6B4226),
        );
        c.drawRect(
          Rect.fromLTWH(left + w * 0.4, baseY + s * 0.08, w * 0.2, s * 0.1),
          Paint()..color = _c(0xFF5A3A1E),
        );
        for (var k = 0; k < 7; k++) {
          final x = left + w * (k + 0.5) / 7;
          final hgt = s * (k == 3 ? 0.34 : 0.28 - (k - 3).abs() * 0.02);
          c.drawRect(
            Rect.fromLTWH(x - s * 0.028, baseY - hgt, s * 0.056, hgt),
            Paint()..color = _c(candles[k]),
          );
          final fl = 0.8 + 0.2 * math.sin(tt * 3 + k + phase);
          final fy = baseY - hgt;
          c.drawCircle(
            Offset(x, fy - s * 0.03),
            s * 0.05,
            Paint()
              ..color = const Color(0xFFFFB347).withValues(alpha: 0.25 * fl),
          );
          final flame = Path()
            ..moveTo(x, fy - s * 0.07 * fl)
            ..quadraticBezierTo(x + s * 0.022, fy - s * 0.015, x, fy)
            ..quadraticBezierTo(
              x - s * 0.022,
              fy - s * 0.015,
              x,
              fy - s * 0.07 * fl,
            );
          c.drawPath(flame, Paint()..color = const Color(0xFFFFC94D));
        }
      case CornerStyle.fan:
        final cols = [main, second, accent];
        for (var k = 0; k < 9; k++) {
          final a0 = k * (math.pi / 2) / 9, a1 = (k + 1) * (math.pi / 2) / 9;
          final seg = Path()
            ..moveTo(0, 0)
            ..arcTo(
              Rect.fromCircle(center: Offset.zero, radius: s * 0.72),
              a0,
              a1 - a0,
              false,
            )
            ..close();
          c.drawPath(seg, Paint()..color = _c(cols[k % 3], 0.92));
          c.drawLine(
            Offset.zero,
            Offset(math.cos(a0), math.sin(a0)) * s * 0.72,
            Paint()
              ..color = _c(0xFF3A2A1A, 0.5)
              ..strokeWidth = 1,
          );
        }
        for (var k = 0; k <= 9; k++) {
          final a = k * (math.pi / 2) / 9;
          c.drawCircle(
            Offset(math.cos(a), math.sin(a)) * s * 0.72,
            s * 0.04,
            Paint()..color = _c(accent),
          );
        }
      case CornerStyle.rangoli:
        // A rangoli mandala: rings of petals and dots.
        final ctr = Offset(s * 0.36, s * 0.36);
        final cols = [main, second, accent];
        for (var ring = 3; ring >= 1; ring--) {
          final r = s * 0.1 * ring;
          final n = 6 + ring * 2;
          for (var k = 0; k < n; k++) {
            final a =
                k * _tau / n + ring * 0.2 + math.sin(tt * 0.2 + phase) * 0.05;
            c.save();
            c.translate(ctr.dx + math.cos(a) * r, ctr.dy + math.sin(a) * r);
            c.rotate(a);
            c.drawOval(
              Rect.fromCenter(
                center: Offset.zero,
                width: s * 0.11,
                height: s * 0.055,
              ),
              Paint()..color = _c(cols[ring % 3]),
            );
            c.restore();
          }
        }
        for (var k = 0; k < 16; k++) {
          final a = k * _tau / 16;
          c.drawCircle(
            ctr + Offset(math.cos(a), math.sin(a)) * s * 0.38,
            s * 0.018,
            Paint()..color = _c(cols[k % 3]),
          );
        }
        c.drawCircle(ctr, s * 0.05, Paint()..color = _c(accent));
      case CornerStyle.sunburst:
        for (var k = 0; k < 12; k++) {
          final a0 = k * (math.pi / 2) / 12, a1 = a0 + (math.pi / 2) / 24;
          final ray = Path()
            ..moveTo(0, 0)
            ..lineTo(math.cos(a0) * s * 0.8, math.sin(a0) * s * 0.8)
            ..lineTo(math.cos(a1) * s * 0.8, math.sin(a1) * s * 0.8)
            ..close();
          c.drawPath(ray, Paint()..color = _c(k.isEven ? main : second, 0.75));
        }
        c.drawCircle(Offset.zero, s * 0.24, Paint()..color = _c(accent));
        _drawGlyph(c, glyphs[0], Offset(s * 0.14, s * 0.14), s * 0.2);
      case CornerStyle.cluster:
        _drawGlyph(
          c,
          glyphs[0],
          Offset(s * 0.28, s * 0.28),
          s * 0.46,
          rot: math.sin(tt * 0.8 + phase) * 0.05,
        );
        _drawGlyph(
          c,
          glyphs[1 % glyphs.length],
          Offset(s * 0.62, s * 0.2),
          s * 0.3,
        );
        _drawGlyph(
          c,
          glyphs[2 % glyphs.length],
          Offset(s * 0.2, s * 0.64),
          s * 0.3,
        );
      case CornerStyle.sprig:
        final branch = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(s * 0.4, s * 0.1, s * 0.75, s * 0.55);
        c.drawPath(
          branch,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = _c(0xFF6B4E2B),
        );
        for (var k = 1; k <= 5; k++) {
          final m = branch.computeMetrics().first;
          final tan = m.getTangentForOffset(m.length * k / 5.5)!;
          c.save();
          c.translate(tan.position.dx, tan.position.dy);
          c.rotate(
            math.atan2(tan.vector.dy, tan.vector.dx) + (k.isEven ? 0.9 : -0.9),
          );
          c.drawOval(
            Rect.fromLTWH(0, -s * 0.05, s * 0.2, s * 0.1),
            Paint()..color = _c(k.isEven ? main : second),
          );
          c.restore();
        }
        _drawGlyph(c, glyphs[0], Offset(s * 0.7, s * 0.52), s * 0.26);
      case CornerStyle.wreath:
        for (var k = 0; k < 9; k++) {
          final a = k * (math.pi / 2) / 8;
          final p = Offset(math.cos(a), math.sin(a)) * s * 0.7;
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(a + math.pi / 2 + (k.isEven ? 0.5 : -0.5));
          c.drawOval(
            Rect.fromLTWH(0, -s * 0.05, s * 0.22, s * 0.1),
            Paint()..color = _c(k.isEven ? main : second),
          );
          c.restore();
        }
        _drawGlyph(c, glyphs[0], Offset(s * 0.5, s * 0.5), s * 0.28);
      case CornerStyle.lantern:
        _drawLanternPair(c, s, main, second, tt, phase);
      case CornerStyle.scroll:
        final p = Path()
          ..moveTo(0, s * 0.5)
          ..cubicTo(s * 0.0, s * 0.1, s * 0.1, 0, s * 0.5, 0)
          ..cubicTo(s * 0.3, s * 0.12, s * 0.2, s * 0.22, s * 0.2, s * 0.5);
        c.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..color = _c(accent),
        );
        c.drawCircle(
          Offset(s * 0.32, s * 0.08),
          s * 0.05,
          Paint()..color = _c(second),
        );
        _drawGlyph(c, glyphs[0], Offset(s * 0.2, s * 0.2), s * 0.22);
      case CornerStyle.frame:
        final line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _c(accent);
        c.drawLine(Offset(0, s * 0.62), Offset(0, 0), line);
        c.drawLine(Offset.zero, Offset(s * 0.62, 0), line);
        c.drawArc(
          Rect.fromLTWH(s * 0.05, s * 0.05, s * 0.34, s * 0.34),
          math.pi,
          math.pi / 2,
          false,
          line..strokeWidth = 1.4,
        );
        c.drawCircle(
          Offset(s * 0.12, s * 0.12),
          2.6,
          Paint()..color = _c(second),
        );
        _drawGlyph(c, glyphs[0], Offset(s * 0.34, s * 0.34), s * 0.2);
      case CornerStyle.ribbon:
        c.save();
        c.translate(s * 0.28, s * 0.28);
        c.rotate(-0.5);
        _bow(c, s * 0.5, main, second);
        c.restore();
      case CornerStyle.window:
        c.save();
        c.translate(s * 0.4, s * 0.55);
        _window(c, s * 0.5, main, second, accent, tt, phase);
        c.restore();
    }
  }

  void _drawLanternPair(
    Canvas c,
    double s,
    int main,
    int second,
    double tt,
    double phase,
  ) {
    for (final (dx, scale, ph) in [
      (s * 0.22, 1.0, 0.0),
      (s * 0.58, 0.7, 1.3),
    ]) {
      c.save();
      c.translate(dx, 0);
      _lantern(c, s * 0.2 * scale, main, second, tt, phase + ph);
      c.restore();
    }
  }

  // ── Borders ─────────────────────────────────────────────────────────

  void _border(
    Canvas c,
    Rect frame,
    DecoBorder style,
    int main,
    int accent,
    int second,
  ) {
    final r = frame.deflate(5);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _c(accent, 0.75);
    switch (style) {
      case DecoBorder.mkeka:
        // A woven mat edge: short blocks of colour along every side.
        final cols = [main, second, accent];
        final band = 7.0;
        var k = 0;
        for (var x = r.left; x < r.right; x += band * 1.6, k++) {
          c.drawRect(
            Rect.fromLTWH(x, r.top, band * 1.4, band),
            Paint()..color = _c(cols[k % 3], 0.85),
          );
          c.drawRect(
            Rect.fromLTWH(x, r.bottom - band, band * 1.4, band),
            Paint()..color = _c(cols[(k + 1) % 3], 0.85),
          );
        }
        k = 0;
        for (var y = r.top + band; y < r.bottom - band; y += band * 1.6, k++) {
          c.drawRect(
            Rect.fromLTWH(r.left, y, band, band * 1.4),
            Paint()..color = _c(cols[(k + 2) % 3], 0.85),
          );
          c.drawRect(
            Rect.fromLTWH(r.right - band, y, band, band * 1.4),
            Paint()..color = _c(cols[k % 3], 0.85),
          );
        }
      case DecoBorder.zigzag:
        final zp = Path();
        void edge(Offset a, Offset b) {
          final d = b - a;
          final len = d.distance;
          final n = (len / 9).floor().clamp(2, 400);
          final nrm = Offset(-d.dy, d.dx) / len;
          zp.moveTo(a.dx, a.dy);
          for (var i = 1; i <= n; i++) {
            final p = a + d * (i / n) + nrm * (i.isOdd ? 4.0 : 0.0);
            zp.lineTo(p.dx, p.dy);
          }
        }
        edge(r.topLeft, r.topRight);
        edge(r.topRight, r.bottomRight);
        edge(r.bottomRight, r.bottomLeft);
        edge(r.bottomLeft, r.topLeft);
        c.drawPath(
          zp,
          line
            ..color = _c(main, 0.8)
            ..strokeWidth = 1.6,
        );
      case DecoBorder.lace:
        final p = Path()
          ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)));
        for (final m in p.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 14) {
            final tan = m.getTangentForOffset(d)!;
            c.drawCircle(
              tan.position,
              5,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2
                ..color = _c(0xFFFFFFFF, 0.8),
            );
            c.drawCircle(
              tan.position,
              1.4,
              Paint()..color = _c(0xFFFFFFFF, 0.8),
            );
          }
        }
        c.drawRRect(
          RRect.fromRectAndRadius(r.deflate(6), const Radius.circular(8)),
          line
            ..color = _c(accent, 0.5)
            ..strokeWidth = 0.8,
        );
      case DecoBorder.stitched:
        final p = Path()
          ..addRRect(
            RRect.fromRectAndRadius(r.deflate(3), const Radius.circular(10)),
          );
        for (final m in p.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 10) {
            c.drawPath(
              m.extractPath(d, math.min(d + 6, m.length)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.6
                ..strokeCap = StrokeCap.round
                ..color = _c(main, 0.85),
            );
          }
        }
      case DecoBorder.none:
        break;
      case DecoBorder.hairline:
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(10)),
          line..strokeWidth = 1,
        );
      case DecoBorder.double:
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(10)),
          line,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(r.deflate(5), const Radius.circular(7)),
          line..strokeWidth = 0.8,
        );
      case DecoBorder.dotted:
        final p = Path()
          ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)));
        for (final m in p.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 11) {
            final tan = m.getTangentForOffset(d)!;
            c.drawCircle(tan.position, 1.8, Paint()..color = _c(main, 0.8));
          }
        }
      case DecoBorder.scallop:
        final p = Path()
          ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)));
        for (final m in p.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 16) {
            final tan = m.getTangentForOffset(d)!;
            c.drawCircle(
              tan.position,
              5,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.3
                ..color = _c(main, 0.8),
            );
          }
        }
      case DecoBorder.frost:
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(10)),
          line..color = _c(0xFFBFE3F5, 0.7),
        );
        for (final (cx, cy) in [
          (r.left, r.top),
          (r.right, r.top),
          (r.left, r.bottom),
          (r.right, r.bottom),
        ]) {
          for (var k = 0; k < 6; k++) {
            final a = k * math.pi / 3;
            c.drawLine(
              Offset(cx, cy),
              Offset(cx + math.cos(a) * 12, cy + math.sin(a) * 12),
              Paint()
                ..color = _c(0xFFFFFFFF, 0.9)
                ..strokeWidth = 1.2,
            );
          }
        }
      case DecoBorder.vine:
        final p = Path()
          ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)));
        c.drawPath(p, line..color = _c(0xFF4E6B3A, 0.8));
        for (final m in p.computeMetrics()) {
          var i = 0;
          for (var d = 0.0; d < m.length; d += 22) {
            final tan = m.getTangentForOffset(d)!;
            c.save();
            c.translate(tan.position.dx, tan.position.dy);
            c.rotate(
              math.atan2(tan.vector.dy, tan.vector.dx) +
                  (i.isEven ? 0.8 : -0.8),
            );
            c.drawOval(
              const Rect.fromLTWH(0, -2.2, 9, 4.4),
              Paint()..color = _c(i % 3 == 0 ? second : main, 0.9),
            );
            c.restore();
            i++;
          }
        }
      case DecoBorder.ornate:
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(8)),
          line..strokeWidth = 1,
        );
        for (final (cx, cy, sx, sy) in [
          (r.left, r.top, 1.0, 1.0),
          (r.right, r.top, -1.0, 1.0),
          (r.left, r.bottom, 1.0, -1.0),
          (r.right, r.bottom, -1.0, -1.0),
        ]) {
          c.save();
          c.translate(cx, cy);
          c.scale(sx, sy);
          final corner = Path()
            ..moveTo(0, 26)
            ..quadraticBezierTo(0, 0, 26, 0)
            ..moveTo(5, 18)
            ..quadraticBezierTo(5, 5, 18, 5);
          c.drawPath(
            corner,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = _c(accent),
          );
          c.drawCircle(const Offset(5, 5), 2.6, Paint()..color = _c(second));
          c.restore();
        }
    }
  }

  // ── Falling things ──────────────────────────────────────────────────

  void _particles(
    Canvas c,
    Rect frame,
    DecorItem item,
    SeasonalVariation? v,
    double tt,
    double burst,
  ) {
    final kind = v?.particle ?? ParticleKind.sparkles;
    if (kind == ParticleKind.none) return;
    final area = frame.width * frame.height / (400 * 800);
    final base = switch (kind) {
      ParticleKind.rain => 70,
      ParticleKind.snow => 46,
      ParticleKind.stars ||
      ParticleKind.sparkles ||
      ParticleKind.confetti => 28,
      ParticleKind.bokeh || ParticleKind.clouds => 8,
      ParticleKind.butterflies => 4,
      ParticleKind.skylanterns => 7,
      ParticleKind.feathers => 9,
      ParticleKind.glitter => 40,
      _ => 22,
    };
    final n =
        (base *
                area.clamp(0.5, 2.2) *
                scene.layers.particleDensity *
                item.frequency *
                (1 + burst * 1.5))
            .round()
            .clamp(0, 140);
    final pal = v?.palette;
    final emoji = v?.garlandEmoji ?? const ['🍂'];
    for (var i = 0; i < n; i++) {
      final seed = item.id.hashCode ^ i * 7919;
      final spd = 0.35 + 0.65 * _hash01(seed, 1);
      final cycle = switch (kind) {
        ParticleKind.rain => 0.9,
        ParticleKind.clouds => 60.0,
        _ => 9.0 / spd,
      };
      final prog = ((tt / cycle) + _hash01(seed, 2)) % 1.0;
      final bx = frame.left + frame.width * _hash01(seed, 3);
      final size = 0.6 + 0.9 * _hash01(seed, 4);
      final cols =
          pal?.all ?? const [0xFFFF5E8A, 0xFF3DD6D0, 0xFFFFC43D, 0xFFFFFFFF];
      switch (kind) {
        case ParticleKind.feathers:
          final x = bx + math.sin(tt * 0.5 + i * 1.3) * 34;
          final y = frame.top + frame.height * prog;
          c.save();
          c.translate(x, y);
          c.rotate(math.sin(tt * 0.9 + i) * 0.7);
          final len = 14 * size + 6;
          final quill = Path()
            ..moveTo(0, -len / 2)
            ..quadraticBezierTo(len * 0.32, 0, 0, len / 2)
            ..quadraticBezierTo(-len * 0.32, 0, 0, -len / 2);
          c.drawPath(quill, Paint()..color = _c(cols[1 + i % 3], 0.85));
          c.drawLine(
            Offset(0, -len / 2),
            Offset(0, len / 2 + 3),
            Paint()
              ..color = _c(0xFFFFFFFF, 0.7)
              ..strokeWidth = 0.8,
          );
          c.restore();
        case ParticleKind.glitter:
          final x = bx + math.sin(tt * 0.4 + i) * 6;
          final y = frame.top + frame.height * prog;
          final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(tt * 4 + i * 2.1));
          c.save();
          c.translate(x, y);
          c.rotate(tt * 2 + i);
          c.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: 2.4 * size + 1,
              height: 2.4 * size + 1,
            ),
            Paint()..color = _c(cols[i % 4], tw),
          );
          c.restore();
        case ParticleKind.skylanterns:
          // Paper lanterns rising slowly and glowing.
          final x = bx + math.sin(tt * 0.25 + i) * 22;
          final y = frame.bottom - frame.height * prog;
          final w = 9 + 7 * size, h = w * 1.25;
          final glow = 0.75 + 0.25 * math.sin(tt * 2 + i);
          c.drawCircle(
            Offset(x, y),
            w,
            Paint()
              ..color = const Color(0xFFFFB347).withValues(alpha: 0.18 * glow),
          );
          final body = Path()
            ..moveTo(x - w / 2, y - h / 2)
            ..lineTo(x + w / 2, y - h / 2)
            ..lineTo(x + w * 0.36, y + h / 2)
            ..lineTo(x - w * 0.36, y + h / 2)
            ..close();
          c.drawPath(
            body,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _c(cols[1 % 4], 0.9),
                  const Color(0xFFFFD27A).withValues(alpha: 0.95 * glow),
                ],
              ).createShader(Rect.fromLTWH(x - w / 2, y - h / 2, w, h)),
          );
        case ParticleKind.ribbons:
          final x = bx + math.sin(tt * 0.7 + i) * 20;
          final y = frame.top + frame.height * prog;
          final rib = Path()..moveTo(x, y);
          for (var k = 1; k <= 8; k++) {
            rib.lineTo(
              x + math.sin(k * 1.1 + tt * 2 + i) * 4,
              y + k * 2.4 * size + k,
            );
          }
          c.drawPath(
            rib,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..strokeCap = StrokeCap.round
              ..color = _c(cols[1 + i % 3], 0.9),
          );
        case ParticleKind.snow:
          final x = bx + math.sin(tt * 0.7 + i) * 14;
          final y = frame.top + frame.height * prog;
          c.drawCircle(
            Offset(x, y),
            1.4 + 2.4 * size,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.4 + 0.4 * size / 1.5),
          );
        case ParticleKind.rain:
          final x = bx;
          final y = frame.top + frame.height * prog;
          c.drawLine(
            Offset(x, y),
            Offset(x - 3, y + 11 * size),
            Paint()
              ..color = const Color(0xFF9CC3E3).withValues(alpha: 0.5)
              ..strokeWidth = 1.1,
          );
        case ParticleKind.leaves:
          final x = bx + math.sin(tt * 0.6 + i * 2) * 26;
          final y = frame.top + frame.height * prog;
          _drawGlyph(
            c,
            emoji[i % emoji.length] == '🍂' || emoji[i % emoji.length] == '🍁'
                ? emoji[i % emoji.length]
                : '🍂',
            Offset(x, y),
            13 * size,
            rot: tt * 0.9 + i,
            alpha: 0.85,
          );
        case ParticleKind.petals:
          final x = bx + math.sin(tt * 0.5 + i) * 30;
          final y = frame.top + frame.height * prog;
          c.save();
          c.translate(x, y);
          c.rotate(tt * 0.8 + i);
          c.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: 8 * size,
              height: 5 * size,
            ),
            Paint()..color = _c(pal?.primary ?? 0xFFF7B7CE, 0.85),
          );
          c.restore();
        case ParticleKind.fireflies:
          final x = bx + math.sin(tt * 0.4 + i) * 24;
          final y =
              frame.top +
              frame.height * (0.2 + 0.7 * _hash01(seed, 5)) +
              math.cos(tt * 0.5 + i) * 14;
          final a = (0.5 + 0.5 * math.sin(tt * 1.6 + i * 2)).clamp(0.0, 1.0);
          c.drawCircle(
            Offset(x, y),
            7,
            Paint()
              ..color = const Color(0xFFFFE08A).withValues(alpha: 0.18 * a),
          );
          c.drawCircle(
            Offset(x, y),
            2.2,
            Paint()
              ..color = const Color(
                0xFFFFF3B0,
              ).withValues(alpha: 0.5 + 0.5 * a),
          );
        case ParticleKind.stars || ParticleKind.sparkles:
          final x = bx;
          final y = frame.top + frame.height * _hash01(seed, 6);
          final a = (0.5 + 0.5 * math.sin(tt * 1.8 + i * 3)).clamp(0.0, 1.0);
          final s2 = (2 + 3 * size) * (0.6 + 0.4 * a);
          final col =
              (kind == ParticleKind.stars
                      ? const Color(0xFFFFF1B0)
                      : _c(pal?.accent ?? 0xFFFFFFFF))
                  .withValues(alpha: 0.35 + 0.6 * a);
          c.drawLine(
            Offset(x - s2, y),
            Offset(x + s2, y),
            Paint()
              ..color = col
              ..strokeWidth = 1.2,
          );
          c.drawLine(
            Offset(x, y - s2),
            Offset(x, y + s2),
            Paint()
              ..color = col
              ..strokeWidth = 1.2,
          );
        case ParticleKind.confetti:
          final x = bx + math.sin(tt + i) * 20;
          final y = frame.top + frame.height * prog;
          c.save();
          c.translate(x, y);
          c.rotate(tt * 2 + i);
          c.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: 6 * size,
              height: 3 * size,
            ),
            Paint()
              ..color = _c(
                (pal?.all ?? const [0xFFFF5E8A, 0xFF3DD6D0, 0xFFFFC43D])[i % 4],
                0.9,
              ),
          );
          c.restore();
        case ParticleKind.hearts:
          final x = bx + math.sin(tt * 0.8 + i) * 18;
          final y = frame.bottom - frame.height * prog;
          _drawGlyph(
            c,
            i.isEven ? '💕' : '💗',
            Offset(x, y),
            12 * size,
            alpha: (1 - prog).clamp(0.0, 0.85),
          );
        case ParticleKind.bubbles:
          final x = bx + math.sin(tt * 0.9 + i) * 14;
          final y = frame.bottom - frame.height * prog;
          c.drawCircle(
            Offset(x, y),
            3 + 6 * size,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.white.withValues(alpha: 0.55),
          );
        case ParticleKind.embers:
          final x = bx + math.sin(tt * 1.2 + i) * 16;
          final y = frame.bottom - frame.height * prog;
          c.drawCircle(
            Offset(x, y),
            1.2 + 1.6 * size,
            Paint()
              ..color = const Color(
                0xFFFFA24A,
              ).withValues(alpha: (1 - prog).clamp(0.0, 0.9)),
          );
        case ParticleKind.clouds:
          final x = frame.left - 80 + (frame.width + 160) * prog;
          final y = frame.top + frame.height * (0.1 + 0.5 * _hash01(seed, 7));
          final w = 70 + 50 * size;
          c.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.4),
            Paint()..color = Colors.white.withValues(alpha: 0.18),
          );
          c.drawOval(
            Rect.fromCenter(
              center: Offset(x + w * 0.2, y - w * 0.08),
              width: w * 0.6,
              height: w * 0.32,
            ),
            Paint()..color = Colors.white.withValues(alpha: 0.16),
          );
        case ParticleKind.butterflies:
          final x =
              frame.left +
              frame.width * (0.5 + 0.4 * math.sin(tt * 0.25 + i * 2));
          final y =
              frame.top +
              frame.height * (0.3 + 0.3 * math.cos(tt * 0.3 + i)) +
              math.sin(tt * 3 + i) * 5;
          _drawGlyph(
            c,
            '🦋',
            Offset(x, y),
            17,
            rot: math.sin(tt * 0.5 + i) * 0.3,
          );
        case ParticleKind.bokeh:
          final x = bx;
          final y = frame.top + frame.height * _hash01(seed, 8);
          final a = (0.5 + 0.5 * math.sin(tt * 0.6 + i)).clamp(0.0, 1.0);
          c.drawCircle(
            Offset(x, y),
            10 + 22 * size,
            Paint()
              ..color = _c(
                (pal?.all ?? const [0xFFFFFFFF])[i % 4],
                0.05 + 0.07 * a,
              ),
          );
        case ParticleKind.none:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(DecorPainter old) =>
      old.scene != scene ||
      old.t != t ||
      !identical(old.layersToDraw, layersToDraw);
}

/// Roughly where an item is on screen, for hit-testing and selection
/// handles in the Decoration Studio. In screen coordinates.
Rect decorItemBounds(DecorItem item, Size size, DecorScene scene) {
  final painter = DecorPainter(scene: scene, t: 0, layersToDraw: const {});
  final frame = painter.frameFor(item.anchor, size);
  if (frame == null) return Rect.zero;
  final tw = item.tweakFor(scene.device);
  final w = frame.width * item.w * tw.scale;
  final cx = frame.left + frame.width * (item.x + tw.dx);
  final cy = frame.top + frame.height * (item.y + tw.dy);
  switch (item.kind) {
    case DecoKind.garland:
    case DecoKind.fairyLights:
      return Rect.fromLTWH(cx - w / 2, cy - 4, w, math.max(36, w * 0.09));
    case DecoKind.ribbon:
      return Rect.fromLTWH(cx - w / 2, cy - 16, w, 32);
    case DecoKind.bow:
    case DecoKind.wreath:
    case DecoKind.illustration:
    case DecoKind.furniture:
    case DecoKind.sticker:
    case DecoKind.flower:
    case DecoKind.interactive:
    case DecoKind.candle:
      return Rect.fromCenter(
        center: Offset(cx, cy),
        width: math.max(w, 28),
        height: math.max(w, 28),
      );
    case DecoKind.lantern:
      return Rect.fromLTWH(cx - w / 2, cy, w, w * 1.8);
    case DecoKind.ornament:
      return Rect.fromLTWH(
        cx - w / 2,
        cy,
        w,
        math.max(18.0, frame.height * 0.22) + w,
      );
    case DecoKind.window:
      return Rect.fromCenter(
        center: Offset(cx, cy),
        width: w,
        height: w * 1.25,
      );
    case DecoKind.foliage:
      return Rect.fromLTWH(cx - w / 2, cy - w, w, w);
    case DecoKind.corner:
      final left = item.flipX ? cx - w : cx;
      return Rect.fromLTWH(left, cy, w, w);
    case DecoKind.border:
    case DecoKind.particles:
      return frame;
  }
}
