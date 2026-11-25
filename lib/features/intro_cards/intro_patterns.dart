import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Scattered or arranged motifs.
const introMotifs = <String, String>{
  'stars': 'Stars',
  'sparkles': 'Sparkles',
  'moons': 'Moons',
  'suns': 'Suns',
  'planets': 'Planets',
  'comets': 'Comets',
  'hearts': 'Hearts',
  'flowers': 'Flowers',
  'daisies': 'Daisies',
  'petals': 'Petals',
  'leaves': 'Leaves',
  'clovers': 'Clovers',
  'mushrooms': 'Mushrooms',
  'cherries': 'Cherries',
  'snowflakes': 'Snowflakes',
  'raindrops': 'Raindrops',
  'clouds': 'Clouds',
  'lightning': 'Lightning',
  'flames': 'Flames',
  'bubbles': 'Bubbles',
  'dots': 'Dots',
  'rings': 'Rings',
  'squares': 'Squares',
  'diamonds': 'Diamonds',
  'triangles': 'Triangles',
  'hexagons': 'Hexagons',
  'crosses': 'Crosses',
  'plus': 'Plus signs',
  'notes': 'Music notes',
  'paws': 'Paw prints',
  'feathers': 'Feathers',
  'butterflies': 'Butterflies',
  'bats': 'Bats',
  'crystals': 'Crystals',
  'swirls': 'Swirls',
  'spirals': 'Spirals',
  'zigzags': 'Zigzags',
  'arrows': 'Arrows',
  'crowns': 'Crowns',
  'keys': 'Keys',
  'eyes': 'Eyes',
  'bows': 'Bows',
  'shells': 'Shells',
  'fish': 'Fish',
  'confetti': 'Confetti',
  'sprinkles': 'Sprinkles',
  'waves': 'Little waves',
};

/// Patterns that tile across the whole card.
const introTiles = <String, String>{
  'stripes': 'Stripes',
  'diagonal': 'Diagonal stripes',
  'pinstripes': 'Pinstripes',
  'plaid': 'Plaid',
  'gingham': 'Gingham',
  'checker': 'Checkerboard',
  'grid': 'Grid',
  'graph': 'Graph paper',
  'polka': 'Polka dots',
  'halftone': 'Halftone',
  'herringbone': 'Herringbone',
  'chevron': 'Chevrons',
  'wavelines': 'Wave lines',
  'scales': 'Scales',
  'honeycomb': 'Honeycomb',
  'brick': 'Brick',
  'concentric': 'Concentric circles',
  'sunburst': 'Sunburst',
  'topographic': 'Topographic',
  'crosshatch': 'Crosshatch',
  'triangletile': 'Triangle tiles',
  'argyle': 'Argyle',
  'lattice': 'Lattice',
  'fans': 'Art deco fans',
  'constellation': 'Constellations',
  'speckle': 'Speckle',
  'terrazzo': 'Terrazzo',
  'diamondgrid': 'Diamond grid',
  'ripples': 'Ripples',
};

Map<String, String> get introPatternNames => {
  ...introMotifs,
  ...introTiles,
  'none': 'None',
};

const introPlacements = <String, String>{
  'all': 'Everywhere',
  'border': 'Border',
  'corners': 'Corners',
  'top': 'Top',
  'bottom': 'Bottom',
  'left': 'Left side',
  'right': 'Right side',
  'center': 'Centre',
  'diagonal': 'Diagonal band',
  'frame': 'Frame inset',
};

const introFades = <String, String>{
  'none': 'No fade',
  'top': 'Fade to top',
  'bottom': 'Fade to bottom',
  'center': 'Fade at centre',
  'edges': 'Fade at edges',
};

/// Every setting of a pattern layer. Stored on the card (or design).
@immutable
class IntroPattern {
  const IntroPattern({
    this.kind = 'stars',
    this.color,
    this.opacity = 0.18,
    this.scale = 1,
    this.density = 1,
    this.rotation = 0,
    this.jitter = 1,
    this.variety = 0.6,
    this.stroke = 1.4,
    this.filled = true,
    this.placement = 'all',
    this.fade = 'none',
    this.seed = 0,
    this.layer2,
  });
  final String kind;

  /// null = the card's border colour.
  final int? color;
  final double opacity, scale, density, rotation, jitter, variety, stroke;
  final bool filled;
  final String placement, fade;
  final int seed;

  /// An optional second pattern drawn on top.
  final IntroPattern? layer2;

  IntroPattern copyWith({
    String? kind,
    int? color,
    bool clearColor = false,
    double? opacity,
    double? scale,
    double? density,
    double? rotation,
    double? jitter,
    double? variety,
    double? stroke,
    bool? filled,
    String? placement,
    String? fade,
    int? seed,
    IntroPattern? layer2,
    bool clearLayer2 = false,
  }) => IntroPattern(
    kind: kind ?? this.kind,
    color: clearColor ? null : (color ?? this.color),
    opacity: opacity ?? this.opacity,
    scale: scale ?? this.scale,
    density: density ?? this.density,
    rotation: rotation ?? this.rotation,
    jitter: jitter ?? this.jitter,
    variety: variety ?? this.variety,
    stroke: stroke ?? this.stroke,
    filled: filled ?? this.filled,
    placement: placement ?? this.placement,
    fade: fade ?? this.fade,
    seed: seed ?? this.seed,
    layer2: clearLayer2 ? null : (layer2 ?? this.layer2),
  );

  Map<String, Object?> toJson() => {
    'k': kind,
    'c': color,
    'o': opacity,
    's': scale,
    'd': density,
    'r': rotation,
    'j': jitter,
    'v': variety,
    'w': stroke,
    'f': filled,
    'p': placement,
    'fd': fade,
    'seed': seed,
    if (layer2 != null) 'l2': layer2!.toJson(),
  };

  static IntroPattern fromJson(Object? raw, {String fallbackKind = 'stars'}) {
    final j = raw is Map ? raw : const {};
    double d(String k, double def, double lo, double hi) =>
        ((j[k] as num?)?.toDouble() ?? def).clamp(lo, hi);
    final k = '${j['k'] ?? fallbackKind}';
    return IntroPattern(
      kind: introPatternNames.containsKey(k) ? k : fallbackKind,
      color: (j['c'] as num?)?.toInt(),
      opacity: d('o', 0.18, 0.02, 1),
      scale: d('s', 1, 0.3, 3),
      density: d('d', 1, 0.2, 3),
      rotation: d('r', 0, -180, 180),
      jitter: d('j', 1, 0, 1),
      variety: d('v', 0.6, 0, 1),
      stroke: d('w', 1.4, 0.4, 5),
      filled: j['f'] != false,
      placement: introPlacements.containsKey(j['p']) ? j['p'] as String : 'all',
      fade: introFades.containsKey(j['fd']) ? j['fd'] as String : 'none',
      seed: (j['seed'] as num?)?.toInt() ?? 0,
      layer2: j['l2'] is Map ? IntroPattern.fromJson(j['l2']) : null,
    );
  }
}

/// Draws an [IntroPattern] (and its second layer) over a card.
class IntroPatternPainter extends CustomPainter {
  IntroPatternPainter(this.pattern, this.defaultColor);
  final IntroPattern pattern;
  final Color defaultColor;

  @override
  void paint(Canvas canvas, Size size) {
    _layer(canvas, size, pattern);
    if (pattern.layer2 != null) _layer(canvas, size, pattern.layer2!);
  }

  void _layer(Canvas canvas, Size size, IntroPattern p) {
    if (p.kind == 'none') return;
    final rect = Offset.zero & size;
    final color = (p.color == null ? defaultColor : Color(p.color!)).withValues(
      alpha: p.opacity,
    );
    canvas.save();
    canvas.clipPath(_placementPath(p.placement, size));
    final fading = p.fade != 'none';
    if (fading) canvas.saveLayer(rect, Paint());
    final paint = Paint()
      ..color = color
      ..strokeWidth = p.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = p.filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..isAntiAlias = true;
    final rnd = math.Random(p.kind.hashCode ^ (p.seed * 7919));
    if (introTiles.containsKey(p.kind)) {
      canvas.save();
      if (p.rotation != 0) {
        canvas.translate(size.width / 2, size.height / 2);
        canvas.rotate(p.rotation * math.pi / 180);
        canvas.translate(-size.width / 2, -size.height / 2);
      }
      _tile(canvas, size, p, paint, rnd);
      canvas.restore();
    } else {
      _motifs(canvas, size, p, paint, rnd);
    }
    if (fading) {
      final g = switch (p.fade) {
        'top' => const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, Colors.transparent],
        ),
        'bottom' => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.transparent],
        ),
        'center' => const RadialGradient(
          colors: [Colors.transparent, Colors.black],
          stops: [0.15, 0.85],
        ),
        _ => const RadialGradient(
          colors: [Colors.black, Colors.transparent],
          stops: [0.3, 1],
        ),
      };
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = (g as Gradient).createShader(rect),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  Path _placementPath(String placement, Size s) {
    final w = s.width, h = s.height;
    final band = math.min(w, h) * 0.18;
    switch (placement) {
      case 'border':
        return Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & s)
          ..addRect(Rect.fromLTRB(band, band, w - band, h - band));
      case 'frame':
        final r = Rect.fromLTRB(
          band * 0.5,
          band * 0.5,
          w - band * 0.5,
          h - band * 0.5,
        );
        return Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(r)
          ..addRect(r.deflate(band * 0.6));
      case 'corners':
        final c = math.min(w, h) * 0.38;
        return Path()
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: c))
          ..addOval(Rect.fromCircle(center: Offset(w, 0), radius: c))
          ..addOval(Rect.fromCircle(center: Offset(0, h), radius: c))
          ..addOval(Rect.fromCircle(center: Offset(w, h), radius: c));
      case 'top':
        return Path()..addRect(Rect.fromLTWH(0, 0, w, h * 0.42));
      case 'bottom':
        return Path()..addRect(Rect.fromLTWH(0, h * 0.58, w, h * 0.42));
      case 'left':
        return Path()..addRect(Rect.fromLTWH(0, 0, w * 0.45, h));
      case 'right':
        return Path()..addRect(Rect.fromLTWH(w * 0.55, 0, w * 0.45, h));
      case 'center':
        return Path()..addOval(
          Rect.fromCenter(
            center: s.center(Offset.zero),
            width: w * 0.8,
            height: h * 0.6,
          ),
        );
      case 'diagonal':
        return Path()
          ..moveTo(0, h * 0.25)
          ..lineTo(w * 0.75, h)
          ..lineTo(w * 0.25, h)
          ..lineTo(0, h * 0.75)
          ..close()
          ..moveTo(w * 0.25, 0)
          ..lineTo(w, h * 0.75)
          ..lineTo(w, h * 0.25)
          ..lineTo(w * 0.75, 0)
          ..close();
      default:
        return Path()..addRect(Offset.zero & s);
    }
  }

  void _motifs(
    Canvas canvas,
    Size size,
    IntroPattern p,
    Paint paint,
    math.Random rnd,
  ) {
    final cell = (34 / p.density).clamp(8.0, 200.0);
    final cols = (size.width / cell).ceil() + 1,
        rows = (size.height / cell).ceil() + 1;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final ox = (x + (y.isOdd ? 0.5 : 0)) * cell;
        final oy = y * cell;
        final o = Offset(
          ox + (rnd.nextDouble() - 0.5) * cell * p.jitter,
          oy + (rnd.nextDouble() - 0.5) * cell * p.jitter,
        );
        final r =
            5 *
            p.scale *
            (1 - p.variety * 0.6 + rnd.nextDouble() * p.variety * 1.2);
        final a =
            p.rotation * math.pi / 180 +
            (rnd.nextDouble() - 0.5) * math.pi * p.jitter;
        canvas.save();
        canvas.translate(o.dx, o.dy);
        canvas.rotate(a);
        _motif(canvas, p.kind, r, paint, rnd);
        canvas.restore();
      }
    }
  }

  Path _star(double r, int points, double inner) {
    final path = Path();
    for (var k = 0; k < points * 2; k++) {
      final rr = k.isEven ? r : r * inner;
      final a = -math.pi / 2 + k * math.pi / points;
      final pt = Offset(math.cos(a) * rr, math.sin(a) * rr);
      k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  Path _poly(double r, int n) {
    final path = Path();
    for (var k = 0; k < n; k++) {
      final a = -math.pi / 2 + k * 2 * math.pi / n;
      final pt = Offset(math.cos(a) * r, math.sin(a) * r);
      k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  Path _heart(double r) => Path()
    ..moveTo(0, r * 0.35)
    ..cubicTo(-r * 1.2, -r * 0.4, -r * 0.5, -r * 1.2, 0, -r * 0.45)
    ..cubicTo(r * 0.5, -r * 1.2, r * 1.2, -r * 0.4, 0, r * 0.35)
    ..close();

  void _motif(Canvas c, String kind, double r, Paint p, math.Random rnd) {
    final line = Paint()
      ..color = p.color
      ..strokeWidth = p.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (kind) {
      case 'stars':
        c.drawPath(_star(r, 5, 0.45), p);
      case 'sparkles':
        c.drawPath(_star(r * 1.2, 4, 0.22), p);
      case 'moons':
        c.drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)),
            Path()..addOval(
              Rect.fromCircle(center: Offset(r * 0.5, -r * 0.2), radius: r),
            ),
          ),
          p,
        );
      case 'suns':
        c.drawCircle(Offset.zero, r * 0.55, p);
        for (var k = 0; k < 8; k++) {
          final a = k * math.pi / 4;
          c.drawLine(
            Offset(math.cos(a), math.sin(a)) * r * 0.85,
            Offset(math.cos(a), math.sin(a)) * r * 1.4,
            line,
          );
        }
      case 'planets':
        c.drawCircle(Offset.zero, r * 0.6, p);
        c.drawOval(
          Rect.fromCenter(center: Offset.zero, width: r * 2.4, height: r * 0.7),
          line,
        );
      case 'comets':
        c.drawCircle(Offset(r * 0.6, 0), r * 0.4, p);
        for (final dy in [-0.25, 0.0, 0.25]) {
          c.drawLine(
            Offset(r * 0.3, dy * r),
            Offset(-r * 1.4, dy * r * 2.2),
            line,
          );
        }
      case 'hearts':
        c.drawPath(_heart(r), p);
      case 'flowers':
        for (var k = 0; k < 5; k++) {
          final a = k * 2 * math.pi / 5;
          c.drawCircle(
            Offset(math.cos(a), math.sin(a)) * r * 0.55,
            r * 0.45,
            p,
          );
        }
        c.drawCircle(
          Offset.zero,
          r * 0.3,
          Paint()
            ..color = p.color.withValues(alpha: (p.color.a * 1.5).clamp(0, 1)),
        );
      case 'daisies':
        for (var k = 0; k < 8; k++) {
          c.save();
          c.rotate(k * math.pi / 4);
          c.drawOval(
            Rect.fromCenter(
              center: Offset(0, -r * 0.6),
              width: r * 0.35,
              height: r * 0.9,
            ),
            p,
          );
          c.restore();
        }
        c.drawCircle(Offset.zero, r * 0.25, p);
      case 'petals':
        c.drawPath(
          Path()
            ..moveTo(0, -r)
            ..quadraticBezierTo(r * 0.8, 0, 0, r)
            ..quadraticBezierTo(-r * 0.8, 0, 0, -r),
          p,
        );
      case 'leaves':
        c.drawPath(
          Path()
            ..moveTo(0, -r * 1.3)
            ..quadraticBezierTo(r * 0.9, 0, 0, r * 1.3)
            ..quadraticBezierTo(-r * 0.9, 0, 0, -r * 1.3),
          p,
        );
        c.drawLine(
          Offset(0, -r * 1.1),
          Offset(0, r * 1.1),
          line..color = p.color.withValues(alpha: p.color.a * 0.6),
        );
      case 'clovers':
        for (var k = 0; k < 4; k++) {
          c.save();
          c.rotate(k * math.pi / 2);
          c.drawPath(_heart(r * 0.55).shift(Offset(0, -r * 0.4)), p);
          c.restore();
        }
      case 'mushrooms':
        c.drawPath(
          Path()
            ..addArc(
              Rect.fromCenter(
                center: Offset(0, 0),
                width: r * 2.2,
                height: r * 1.8,
              ),
              math.pi,
              math.pi,
            )
            ..close(),
          p,
        );
        c.drawRect(Rect.fromLTWH(-r * 0.3, 0, r * 0.6, r * 0.9), p);
      case 'cherries':
        c.drawCircle(Offset(-r * 0.45, r * 0.4), r * 0.4, p);
        c.drawCircle(Offset(r * 0.45, r * 0.5), r * 0.4, p);
        c.drawPath(
          Path()
            ..moveTo(-r * 0.45, r * 0.1)
            ..quadraticBezierTo(0, -r * 0.9, r * 0.3, -r)
            ..moveTo(r * 0.45, r * 0.2)
            ..quadraticBezierTo(r * 0.4, -r * 0.5, r * 0.3, -r),
          line,
        );
      case 'snowflakes':
        for (var k = 0; k < 6; k++) {
          final a = k * math.pi / 3;
          final e = Offset(math.cos(a), math.sin(a)) * r;
          c.drawLine(Offset.zero, e, line);
          c.drawLine(
            e * 0.6,
            e * 0.6 + Offset(math.cos(a + 0.6), math.sin(a + 0.6)) * r * 0.3,
            line,
          );
          c.drawLine(
            e * 0.6,
            e * 0.6 + Offset(math.cos(a - 0.6), math.sin(a - 0.6)) * r * 0.3,
            line,
          );
        }
      case 'raindrops':
        c.drawPath(
          Path()
            ..moveTo(0, -r)
            ..quadraticBezierTo(r * 0.8, r * 0.3, 0, r * 0.7)
            ..quadraticBezierTo(-r * 0.8, r * 0.3, 0, -r),
          p,
        );
      case 'clouds':
        for (final (dx, dy, rr) in const [
          (-0.5, 0.15, 0.45),
          (0.0, -0.15, 0.6),
          (0.55, 0.15, 0.45),
        ]) {
          c.drawCircle(Offset(dx * r * 1.4, dy * r), rr * r, p);
        }
      case 'lightning':
        c.drawPath(
          Path()
            ..moveTo(r * 0.2, -r)
            ..lineTo(-r * 0.4, r * 0.1)
            ..lineTo(0, r * 0.1)
            ..lineTo(-r * 0.2, r)
            ..lineTo(r * 0.45, -r * 0.15)
            ..lineTo(r * 0.05, -r * 0.15)
            ..close(),
          p,
        );
      case 'flames':
        c.drawPath(
          Path()
            ..moveTo(0, -r * 1.2)
            ..cubicTo(r * 0.9, -r * 0.2, r * 0.8, r, 0, r)
            ..cubicTo(-r * 0.8, r, -r * 0.9, -r * 0.2, 0, -r * 1.2),
          p,
        );
      case 'bubbles':
        c.drawCircle(Offset.zero, r, line);
        c.drawCircle(Offset(-r * 0.35, -r * 0.35), r * 0.2, p);
      case 'dots':
        c.drawCircle(Offset.zero, r * 0.5, p);
      case 'rings':
        c.drawCircle(Offset.zero, r * 0.8, line);
      case 'squares':
        c.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 1.4, height: r * 1.4),
          p,
        );
      case 'diamonds':
        c.drawPath(_poly(r, 4), p);
      case 'triangles':
        c.drawPath(_poly(r, 3), p);
      case 'hexagons':
        c.drawPath(_poly(r, 6), p);
      case 'crosses':
        c.drawLine(Offset(-r * 0.7, -r * 0.7), Offset(r * 0.7, r * 0.7), line);
        c.drawLine(Offset(r * 0.7, -r * 0.7), Offset(-r * 0.7, r * 0.7), line);
      case 'plus':
        c.drawLine(Offset(-r * 0.8, 0), Offset(r * 0.8, 0), line);
        c.drawLine(Offset(0, -r * 0.8), Offset(0, r * 0.8), line);
      case 'notes':
        c.drawOval(
          Rect.fromCenter(
            center: Offset(-r * 0.3, r * 0.6),
            width: r * 0.8,
            height: r * 0.55,
          ),
          p,
        );
        c.drawLine(Offset(r * 0.05, r * 0.55), Offset(r * 0.05, -r), line);
        c.drawLine(Offset(r * 0.05, -r), Offset(r * 0.6, -r * 0.6), line);
      case 'paws':
        c.drawOval(
          Rect.fromCenter(
            center: Offset(0, r * 0.35),
            width: r * 1.1,
            height: r * 0.9,
          ),
          p,
        );
        for (final dx in [-0.55, -0.2, 0.2, 0.55]) {
          c.drawCircle(
            Offset(dx * r, dx.abs() > 0.4 ? -r * 0.25 : -r * 0.5),
            r * 0.22,
            p,
          );
        }
      case 'feathers':
        c.drawPath(
          Path()
            ..moveTo(0, -r * 1.3)
            ..quadraticBezierTo(r * 0.7, -r * 0.2, 0, r * 1.1)
            ..quadraticBezierTo(-r * 0.5, -r * 0.2, 0, -r * 1.3),
          p,
        );
        c.drawLine(Offset(0, -r * 1.2), Offset(0, r * 1.4), line);
      case 'butterflies':
        for (final s in [-1.0, 1.0]) {
          c.drawOval(
            Rect.fromCenter(
              center: Offset(s * r * 0.5, -r * 0.3),
              width: r * 0.9,
              height: r * 1.0,
            ),
            p,
          );
          c.drawOval(
            Rect.fromCenter(
              center: Offset(s * r * 0.4, r * 0.45),
              width: r * 0.6,
              height: r * 0.7,
            ),
            p,
          );
        }
      case 'bats':
        c.drawPath(
          Path()
            ..moveTo(0, -r * 0.2)
            ..quadraticBezierTo(-r * 0.6, -r * 0.8, -r * 1.3, -r * 0.3)
            ..quadraticBezierTo(-r * 0.9, -r * 0.1, -r * 0.8, r * 0.2)
            ..quadraticBezierTo(-r * 0.4, 0, 0, r * 0.4)
            ..quadraticBezierTo(r * 0.4, 0, r * 0.8, r * 0.2)
            ..quadraticBezierTo(r * 0.9, -r * 0.1, r * 1.3, -r * 0.3)
            ..quadraticBezierTo(r * 0.6, -r * 0.8, 0, -r * 0.2),
          p,
        );
      case 'crystals':
        c.drawPath(
          Path()
            ..moveTo(0, -r * 1.2)
            ..lineTo(r * 0.5, -r * 0.3)
            ..lineTo(r * 0.35, r)
            ..lineTo(-r * 0.35, r)
            ..lineTo(-r * 0.5, -r * 0.3)
            ..close(),
          p,
        );
      case 'swirls':
        final path = Path()..moveTo(0, 0);
        for (var t = 0.0; t < math.pi * 3; t += 0.3) {
          final rr = r * t / (math.pi * 3);
          path.lineTo(math.cos(t) * rr, math.sin(t) * rr);
        }
        c.drawPath(path, line);
      case 'spirals':
        final path = Path()..moveTo(0, 0);
        for (var t = 0.0; t < math.pi * 5; t += 0.25) {
          final rr = r * 1.2 * t / (math.pi * 5);
          path.lineTo(math.cos(t) * rr, math.sin(t) * rr);
        }
        c.drawPath(path, line);
      case 'zigzags':
        c.drawPath(
          Path()
            ..moveTo(-r * 1.2, 0)
            ..lineTo(-r * 0.6, -r * 0.5)
            ..lineTo(0, 0)
            ..lineTo(r * 0.6, -r * 0.5)
            ..lineTo(r * 1.2, 0),
          line,
        );
      case 'arrows':
        c.drawLine(Offset(-r, 0), Offset(r, 0), line);
        c.drawPath(
          Path()
            ..moveTo(r * 0.4, -r * 0.45)
            ..lineTo(r, 0)
            ..lineTo(r * 0.4, r * 0.45),
          line,
        );
      case 'crowns':
        c.drawPath(
          Path()
            ..moveTo(-r, r * 0.5)
            ..lineTo(-r, -r * 0.4)
            ..lineTo(-r * 0.5, r * 0.05)
            ..lineTo(0, -r * 0.7)
            ..lineTo(r * 0.5, r * 0.05)
            ..lineTo(r, -r * 0.4)
            ..lineTo(r, r * 0.5)
            ..close(),
          p,
        );
      case 'keys':
        c.drawCircle(Offset(-r * 0.6, 0), r * 0.4, line);
        c.drawLine(Offset(-r * 0.2, 0), Offset(r, 0), line);
        c.drawLine(Offset(r * 0.6, 0), Offset(r * 0.6, r * 0.3), line);
        c.drawLine(Offset(r * 0.9, 0), Offset(r * 0.9, r * 0.3), line);
      case 'eyes':
        c.drawPath(
          Path()
            ..moveTo(-r, 0)
            ..quadraticBezierTo(0, -r * 0.9, r, 0)
            ..quadraticBezierTo(0, r * 0.9, -r, 0),
          line,
        );
        c.drawCircle(Offset.zero, r * 0.3, p);
      case 'bows':
        c.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(-r, -r * 0.6)
            ..lineTo(-r, r * 0.6)
            ..close()
            ..moveTo(0, 0)
            ..lineTo(r, -r * 0.6)
            ..lineTo(r, r * 0.6)
            ..close(),
          p,
        );
        c.drawCircle(Offset.zero, r * 0.22, p);
      case 'shells':
        for (var k = -3; k <= 3; k++) {
          c.drawLine(
            Offset(0, r * 0.7),
            Offset(k * r * 0.3, -r * 0.7 + (k.abs() * r * 0.1)),
            line,
          );
        }
        c.drawPath(
          Path()
            ..moveTo(-r, -r * 0.4)
            ..quadraticBezierTo(0, -r * 1.2, r, -r * 0.4),
          line,
        );
      case 'fish':
        c.drawOval(
          Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 0.9),
          p,
        );
        c.drawPath(
          Path()
            ..moveTo(r * 0.7, 0)
            ..lineTo(r * 1.3, -r * 0.45)
            ..lineTo(r * 1.3, r * 0.45)
            ..close(),
          p,
        );
      case 'confetti':
        c.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 0.6, height: r * 1.3),
          p,
        );
      case 'sprinkles':
        c.drawLine(
          Offset(0, -r * 0.6),
          Offset(0, r * 0.6),
          line..strokeWidth = math.max(1.5, p.strokeWidth * 1.6),
        );
      case 'waves':
        c.drawPath(
          Path()
            ..moveTo(-r * 2, 0)
            ..quadraticBezierTo(-r, -r, 0, 0)
            ..quadraticBezierTo(r, r, r * 2, 0),
          line,
        );
    }
  }

  void _tile(Canvas c, Size s, IntroPattern p, Paint paint, math.Random rnd) {
    final step = (16 / p.density * p.scale).clamp(3.0, 200.0);
    final big = math.max(s.width, s.height) * 1.5;
    final cx = s.width / 2, cy = s.height / 2;
    final line = Paint()
      ..color = paint.color
      ..strokeWidth = p.stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = paint.color;
    double x0 = cx - big, x1 = cx + big, y0 = cy - big, y1 = cy + big;
    switch (p.kind) {
      case 'stripes':
        for (var y = y0; y < y1; y += step * 2) {
          c.drawRect(Rect.fromLTRB(x0, y, x1, y + step), fill);
        }
      case 'diagonal':
        c.save();
        c.translate(cx, cy);
        c.rotate(math.pi / 4);
        c.translate(-cx, -cy);
        for (var y = y0; y < y1; y += step * 2) {
          c.drawRect(Rect.fromLTRB(x0, y, x1, y + step), fill);
        }
        c.restore();
      case 'pinstripes':
        for (var x = x0; x < x1; x += step) {
          c.drawLine(
            Offset(x, y0),
            Offset(x, y1),
            line..strokeWidth = p.stroke * 0.6,
          );
        }
      case 'plaid':
        final soft = Paint()
          ..color = paint.color.withValues(alpha: paint.color.a * 0.6);
        for (var y = y0; y < y1; y += step * 4) {
          c.drawRect(Rect.fromLTRB(x0, y, x1, y + step * 1.4), soft);
          c.drawLine(
            Offset(x0, y + step * 2.4),
            Offset(x1, y + step * 2.4),
            line,
          );
        }
        for (var x = x0; x < x1; x += step * 4) {
          c.drawRect(Rect.fromLTRB(x, y0, x + step * 1.4, y1), soft);
          c.drawLine(
            Offset(x + step * 2.4, y0),
            Offset(x + step * 2.4, y1),
            line,
          );
        }
      case 'gingham':
        final soft = Paint()
          ..color = paint.color.withValues(alpha: paint.color.a * 0.55);
        for (var y = y0; y < y1; y += step * 2) {
          c.drawRect(Rect.fromLTRB(x0, y, x1, y + step), soft);
        }
        for (var x = x0; x < x1; x += step * 2) {
          c.drawRect(Rect.fromLTRB(x, y0, x + step, y1), soft);
        }
      case 'checker':
        var row = 0;
        for (var y = y0; y < y1; y += step, row++) {
          var col = 0;
          for (var x = x0; x < x1; x += step, col++) {
            if ((row + col).isEven)
              c.drawRect(Rect.fromLTWH(x, y, step, step), fill);
          }
        }
      case 'grid' || 'graph':
        for (var x = x0; x < x1; x += step) {
          c.drawLine(
            Offset(x, y0),
            Offset(x, y1),
            line..strokeWidth = p.kind == 'graph' ? p.stroke * 0.5 : p.stroke,
          );
        }
        for (var y = y0; y < y1; y += step) {
          c.drawLine(Offset(x0, y), Offset(x1, y), line);
        }
        if (p.kind == 'graph') {
          line.strokeWidth = p.stroke * 1.2;
          for (var x = x0; x < x1; x += step * 5) {
            c.drawLine(Offset(x, y0), Offset(x, y1), line);
          }
          for (var y = y0; y < y1; y += step * 5) {
            c.drawLine(Offset(x0, y), Offset(x1, y), line);
          }
        }
      case 'polka':
        var row = 0;
        for (var y = y0; y < y1; y += step * 1.5, row++) {
          for (
            var x = x0 + (row.isOdd ? step * 0.75 : 0);
            x < x1;
            x += step * 1.5
          ) {
            c.drawCircle(Offset(x, y), step * 0.35, paint);
          }
        }
      case 'halftone':
        for (var y = 0.0; y < s.height + step; y += step * 0.8) {
          for (var x = 0.0; x < s.width + step; x += step * 0.8) {
            final k = (x / s.width + y / s.height) / 2;
            c.drawCircle(Offset(x, y), step * 0.42 * (0.15 + k), fill);
          }
        }
      case 'herringbone':
        var col = 0;
        for (var x = x0; x < x1; x += step, col++) {
          for (var y = y0; y < y1; y += step * 2) {
            final dy = col.isEven ? step : -step;
            c.drawLine(Offset(x, y), Offset(x + step, y + dy), line);
          }
        }
      case 'chevron':
        for (var y = y0; y < y1; y += step * 1.5) {
          final path = Path()..moveTo(x0, y);
          var up = true;
          for (var x = x0; x < x1; x += step) {
            path.lineTo(x + step, y + (up ? -step * 0.7 : 0));
            up = !up;
          }
          c.drawPath(path, line);
        }
      case 'wavelines':
        for (var y = y0; y < y1; y += step * 1.4) {
          final path = Path()..moveTo(x0, y);
          for (var x = x0; x < x1; x += step * 2) {
            path.quadraticBezierTo(x + step * 0.5, y - step * 0.7, x + step, y);
            path.quadraticBezierTo(
              x + step * 1.5,
              y + step * 0.7,
              x + step * 2,
              y,
            );
          }
          c.drawPath(path, line);
        }
      case 'scales':
        var row = 0;
        for (var y = y0; y < y1; y += step * 0.7, row++) {
          for (var x = x0 + (row.isOdd ? step * 0.5 : 0); x < x1; x += step) {
            c.drawArc(
              Rect.fromCircle(center: Offset(x, y), radius: step * 0.5),
              0,
              math.pi,
              false,
              line,
            );
          }
        }
      case 'honeycomb':
        final r = step * 0.6;
        final hx = r * math.sqrt(3), hy = r * 1.5;
        var row = 0;
        for (var y = y0; y < y1; y += hy, row++) {
          for (var x = x0 + (row.isOdd ? hx / 2 : 0); x < x1; x += hx) {
            c.drawPath(_poly(r, 6).shift(Offset(x, y)), line);
          }
        }
      case 'brick':
        var row = 0;
        for (var y = y0; y < y1; y += step, row++) {
          c.drawLine(Offset(x0, y), Offset(x1, y), line);
          for (var x = x0 + (row.isOdd ? step : 0); x < x1; x += step * 2) {
            c.drawLine(Offset(x, y), Offset(x, y + step), line);
          }
        }
      case 'concentric' || 'ripples':
        final center = p.kind == 'ripples'
            ? Offset(s.width * 0.2, s.height * 0.3)
            : Offset(cx, cy);
        for (var r = step; r < big; r += step) {
          c.drawCircle(center, r, line);
          if (p.kind == 'ripples')
            c.drawCircle(Offset(s.width * 0.85, s.height * 0.8), r, line);
        }
      case 'sunburst':
        final n = (36 * p.density).round().clamp(8, 120);
        for (var k = 0; k < n; k += 2) {
          final a1 = k * 2 * math.pi / n, a2 = (k + 1) * 2 * math.pi / n;
          c.drawPath(
            Path()
              ..moveTo(cx, cy)
              ..lineTo(cx + math.cos(a1) * big, cy + math.sin(a1) * big)
              ..lineTo(cx + math.cos(a2) * big, cy + math.sin(a2) * big)
              ..close(),
            fill,
          );
        }
      case 'topographic':
        final peaks = (2 + (s.width * s.height) / (step * step * 60))
            .clamp(2, 5)
            .round();
        for (var i = 0; i < peaks; i++) {
          final ox =
                  (i + 0.5) / peaks * s.width +
                  (rnd.nextDouble() - 0.5) * s.width / peaks,
              oy = rnd.nextDouble() * s.height;
          for (var r = step * 0.5; r < step * 3.2; r += step * 0.55) {
            final path = Path();
            for (var t = 0.0; t <= math.pi * 2 + 0.01; t += 0.2) {
              final wob = 1 + 0.18 * math.sin(t * 3 + i);
              final pt = Offset(
                ox + math.cos(t) * r * wob,
                oy + math.sin(t) * r * wob * 0.8,
              );
              t == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
            }
            c.drawPath(path, line);
          }
        }
      case 'crosshatch':
        c.save();
        c.translate(cx, cy);
        for (final a in [math.pi / 4, -math.pi / 4]) {
          c.save();
          c.rotate(a);
          for (var x = -big; x < big; x += step) {
            c.drawLine(Offset(x, -big), Offset(x, big), line);
          }
          c.restore();
        }
        c.restore();
      case 'triangletile':
        var row = 0;
        for (var y = y0; y < y1; y += step, row++) {
          for (var x = x0; x < x1; x += step) {
            final path = row.isEven
                ? (Path()
                    ..moveTo(x, y + step)
                    ..lineTo(x + step / 2, y)
                    ..lineTo(x + step, y + step)
                    ..close())
                : (Path()
                    ..moveTo(x, y)
                    ..lineTo(x + step / 2, y + step)
                    ..lineTo(x + step, y)
                    ..close());
            if ((x / step).round().isEven) c.drawPath(path, fill);
          }
        }
      case 'argyle':
        for (var y = y0; y < y1; y += step * 2) {
          for (var x = x0; x < x1; x += step * 1.4) {
            c.drawPath(
              Path()
                ..moveTo(x, y - step)
                ..lineTo(x + step * 0.7, y)
                ..lineTo(x, y + step)
                ..lineTo(x - step * 0.7, y)
                ..close(),
              fill,
            );
          }
        }
        c.save();
        c.translate(cx, cy);
        for (final a in [0.96, -0.96]) {
          c.save();
          c.rotate(a);
          for (var x = -big; x < big; x += step * 1.7) {
            c.drawLine(
              Offset(x, -big),
              Offset(x, big),
              line..strokeWidth = p.stroke * 0.6,
            );
          }
          c.restore();
        }
        c.restore();
      case 'lattice' || 'diamondgrid':
        c.save();
        c.translate(cx, cy);
        for (final a in [math.pi / 4, -math.pi / 4]) {
          c.save();
          c.rotate(a);
          for (
            var x = -big;
            x < big;
            x += step * (p.kind == 'lattice' ? 1.6 : 1.0)
          ) {
            c.drawLine(
              Offset(x, -big),
              Offset(x, big),
              line..strokeWidth = p.kind == 'lattice' ? p.stroke * 2 : p.stroke,
            );
          }
          c.restore();
        }
        c.restore();
      case 'fans':
        var row = 0;
        for (var y = y0; y < y1; y += step * 0.9, row++) {
          for (var x = x0 + (row.isOdd ? step : 0); x < x1; x += step * 2) {
            for (var k = 1; k <= 3; k++) {
              c.drawArc(
                Rect.fromCircle(
                  center: Offset(x, y + step),
                  radius: step * k / 3,
                ),
                math.pi,
                math.pi,
                false,
                line,
              );
            }
          }
        }
      case 'constellation':
        final pts = [
          for (var i = 0; i < (30 * p.density).round(); i++)
            Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height),
        ];
        for (var i = 0; i < pts.length; i++) {
          c.drawCircle(pts[i], 1.2 * p.scale + rnd.nextDouble(), fill);
          if (i > 0 && (pts[i] - pts[i - 1]).distance < step * 6)
            c.drawLine(pts[i - 1], pts[i], line..strokeWidth = p.stroke * 0.5);
        }
      case 'speckle':
        for (var i = 0; i < (220 * p.density).round(); i++) {
          c.drawCircle(
            Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height),
            (0.4 + rnd.nextDouble()) * p.scale,
            fill,
          );
        }
      case 'terrazzo':
        for (var i = 0; i < (70 * p.density).round(); i++) {
          final o = Offset(
            rnd.nextDouble() * s.width,
            rnd.nextDouble() * s.height,
          );
          final r = (1.5 + rnd.nextDouble() * 4) * p.scale;
          c.drawPath(
            _poly(r, 3 + rnd.nextInt(4))
                .transform(
                  (Matrix4.identity()..rotateZ(rnd.nextDouble() * math.pi))
                      .storage,
                )
                .shift(o),
            fill,
          );
        }
    }
  }

  @override
  bool shouldRepaint(IntroPatternPainter old) =>
      old.pattern.toJson().toString() != pattern.toJson().toString() ||
      old.defaultColor != defaultColor;
}

/// A small live preview of a pattern.
class IntroPatternSwatch extends StatelessWidget {
  const IntroPatternSwatch({
    super.key,
    required this.pattern,
    required this.bg1,
    required this.bg2,
    required this.ink,
    this.width = 70,
    this.height = 46,
  });
  final IntroPattern pattern;
  final Color bg1, bg2, ink;
  final double width, height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg1, bg2],
        ),
      ),
      child: CustomPaint(
        painter: IntroPatternPainter(
          pattern.copyWith(opacity: (pattern.opacity * 2).clamp(0.25, 1)),
          ink,
        ),
      ),
    ),
  );
}
