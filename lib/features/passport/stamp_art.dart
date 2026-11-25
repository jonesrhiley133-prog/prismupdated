import 'dart:math' as math;

import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';

/// How a stamp looks. Plain JSON so templates and instances can share it.
@immutable
class StampDesign {
  const StampDesign({
    this.shape = 'circle',
    this.icon = '⭐',
    this.image,
    this.text = 'MEMORY',
    this.subtext = '',
    this.date = '',
    this.color = 0xFFC2410C,
    this.color2 = 0xFFFFF7ED,
    this.border = 'double',
    this.texture = 'ink',
    this.rotation = -6,
    this.opacity = 0.92,
    this.size = 1,
    this.effect = 'none',
  });

  final String shape;
  final String icon;

  /// Media id of an uploaded picture (shown instead of the icon).
  final String? image;
  final String text, subtext, date;
  final int color, color2;
  final String border, texture;

  /// Degrees.
  final double rotation;
  final double opacity;
  final double size;
  final String effect;

  static const shapes = [
    'circle',
    'rectangle',
    'star',
    'heart',
    'shield',
    'ticket',
    'ribbon',
    'flower',
    'hexagon',
    'oval',
    'custom',
  ];
  static const borders = [
    'none',
    'solid',
    'double',
    'dashed',
    'dotted',
    'perforated',
  ];
  static const textures = ['none', 'ink', 'grain', 'vintage'];
  static const effects = ['none', 'shine', 'glow', 'worn', 'embossed'];

  Map<String, Object?> toJson() => {
    'shape': shape,
    'icon': icon,
    'image': image,
    'text': text,
    'subtext': subtext,
    'date': date,
    'color': color,
    'color2': color2,
    'border': border,
    'texture': texture,
    'rotation': rotation,
    'opacity': opacity,
    'size': size,
    'effect': effect,
  };

  static StampDesign fromJson(Object? raw) {
    final j = raw is Map
        ? raw.cast<String, Object?>()
        : const <String, Object?>{};
    String pick(String k, String d, List<String> allowed) =>
        allowed.contains(j[k]) ? j[k]! as String : d;
    double dbl(String k, double d, double lo, double hi) =>
        ((j[k] as num?)?.toDouble() ?? d).clamp(lo, hi);
    return StampDesign(
      shape: pick('shape', 'circle', shapes),
      icon: '${j['icon'] ?? '⭐'}',
      image: j['image'] as String?,
      text: '${j['text'] ?? ''}',
      subtext: '${j['subtext'] ?? ''}',
      date: '${j['date'] ?? ''}',
      color: (j['color'] as num?)?.toInt() ?? 0xFFC2410C,
      color2: (j['color2'] as num?)?.toInt() ?? 0xFFFFF7ED,
      border: pick('border', 'double', borders),
      texture: pick('texture', 'ink', textures),
      rotation: dbl('rotation', -6, -45, 45),
      opacity: dbl('opacity', 0.92, 0.2, 1),
      size: dbl('size', 1, 0.5, 2),
      effect: pick('effect', 'none', effects),
    );
  }

  StampDesign copyWith(Map<String, Object?> c) => fromJson({...toJson(), ...c});
}

Path stampShape(String shape, Size s) {
  final w = s.width, h = s.height, c = Offset(w / 2, h / 2);
  final r = math.min(w, h) / 2;
  switch (shape) {
    case 'rectangle':
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.04, h * 0.14, w * 0.92, h * 0.72),
          Radius.circular(r * 0.08),
        ),
      );
    case 'oval':
      return Path()
        ..addOval(Rect.fromLTWH(w * 0.03, h * 0.16, w * 0.94, h * 0.68));
    case 'star':
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5;
        final rr = i.isEven ? r * 0.98 : r * 0.55;
        final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    case 'heart':
      return Path()
        ..moveTo(w / 2, h * 0.92)
        ..cubicTo(-w * 0.1, h * 0.5, w * 0.12, h * 0.02, w / 2, h * 0.26)
        ..cubicTo(w * 0.88, h * 0.02, w * 1.1, h * 0.5, w / 2, h * 0.92)
        ..close();
    case 'shield':
      return Path()
        ..moveTo(w * 0.1, h * 0.08)
        ..lineTo(w * 0.9, h * 0.08)
        ..lineTo(w * 0.9, h * 0.5)
        ..quadraticBezierTo(w * 0.88, h * 0.82, w / 2, h * 0.96)
        ..quadraticBezierTo(w * 0.12, h * 0.82, w * 0.1, h * 0.5)
        ..close();
    case 'ticket':
      final rect = Rect.fromLTWH(w * 0.02, h * 0.2, w * 0.96, h * 0.6);
      return Path.combine(
        PathOperation.difference,
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * 0.06))),
        Path()
          ..addOval(
            Rect.fromCircle(center: Offset(rect.left, c.dy), radius: r * 0.12),
          )
          ..addOval(
            Rect.fromCircle(center: Offset(rect.right, c.dy), radius: r * 0.12),
          ),
      );
    case 'ribbon':
      return Path()
        ..moveTo(0, h * 0.28)
        ..lineTo(w, h * 0.28)
        ..lineTo(w * 0.9, h * 0.5)
        ..lineTo(w, h * 0.72)
        ..lineTo(0, h * 0.72)
        ..lineTo(w * 0.1, h * 0.5)
        ..close();
    case 'flower':
      var p = Path();
      for (var i = 0; i < 8; i++) {
        final a = i / 8 * math.pi * 2;
        p = Path.combine(
          PathOperation.union,
          p,
          Path()..addOval(
            Rect.fromCircle(
              center: c + Offset(math.cos(a) * r * 0.5, math.sin(a) * r * 0.5),
              radius: r * 0.46,
            ),
          ),
        );
      }
      return p;
    case 'hexagon':
      final p = Path();
      for (var i = 0; i < 6; i++) {
        final a = i / 6 * math.pi * 2 - math.pi / 2;
        final pt = c + Offset(math.cos(a) * r * 0.98, math.sin(a) * r * 0.98);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    default:
      return Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.97));
  }
}

/// A stamp, drawn. [imageWidget] supplies an uploaded picture when the
/// design uses one (passport code passes a media view).
class StampView extends StatelessWidget {
  const StampView({
    super.key,
    required this.design,
    this.size = 110,
    this.imageWidget,
    this.hideText = false,
    this.hideDate = false,
    this.semanticLabel,
  });
  final StampDesign design;
  final double size;
  final Widget? imageWidget;
  final bool hideText;
  final bool hideDate;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final d = design;
    final s = size * d.size;
    final ink = Color(d.color);
    final label =
        semanticLabel ??
        [
          if (!hideText) d.text,
          if (!hideText && d.subtext.isNotEmpty) d.subtext,
          if (!hideDate && d.date.isNotEmpty) d.date,
        ].where((x) => x.isNotEmpty).join(', ');
    final custom = d.shape == 'custom' && imageWidget != null;
    return Semantics(
      image: true,
      label: label.isEmpty ? 'Stamp' : 'Stamp: $label',
      child: ExcludeSemantics(
        child: Opacity(
          opacity: d.opacity,
          child: Transform.rotate(
            angle: d.rotation * math.pi / 180,
            child: SizedBox.square(
              dimension: s,
              child: custom
                  ? ClipRRect(
                      borderRadius: prismCorners(context, s * 0.08),
                      child: imageWidget,
                    )
                  : CustomPaint(
                      painter: _StampPainter(d),
                      child: Padding(
                        padding: EdgeInsets.all(
                          s *
                              (d.shape == 'star'
                                  ? 0.3
                                  : (d.shape == 'heart' ? 0.24 : 0.2)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (d.image != null && imageWidget != null)
                              Flexible(
                                child: ClipOval(
                                  child: SizedBox.square(
                                    dimension: s * 0.34,
                                    child: imageWidget,
                                  ),
                                ),
                              )
                            else if (d.icon.isNotEmpty)
                              Text(
                                d.icon,
                                style: TextStyle(
                                  fontSize:
                                      s *
                                      (d.shape == 'ribbon' ||
                                              d.shape == 'ticket'
                                          ? 0.14
                                          : 0.22),
                                ),
                              ),
                            if (!hideText && d.text.isNotEmpty)
                              Text(
                                d.text.toUpperCase(),
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: s * 0.085,
                                  letterSpacing: 1.2,
                                  height: 1.05,
                                ),
                              ),
                            if (!hideText && d.subtext.isNotEmpty)
                              Text(
                                d.subtext,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ink,
                                  fontSize: s * 0.065,
                                ),
                              ),
                            if (!hideDate && d.date.isNotEmpty)
                              Text(
                                d.date,
                                maxLines: 1,
                                style: TextStyle(
                                  color: ink,
                                  fontSize: s * 0.06,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter(this.d);
  final StampDesign d;

  @override
  void paint(Canvas c, Size s) {
    final path = stampShape(d.shape, s);
    final ink = Color(d.color);
    if (d.effect == 'glow')
      c.drawPath(
        path,
        Paint()
          ..color = ink.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    if (d.effect == 'embossed') {
      c.save();
      c.translate(1.5, 2);
      c.drawPath(path, Paint()..color = const Color(0x33000000));
      c.restore();
    }
    c.drawPath(path, Paint()..color = Color(d.color2));
    final sw = s.shortestSide * 0.028;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    switch (d.border) {
      case 'solid':
        c.drawPath(path, stroke);
      case 'double':
        c.drawPath(path, stroke);
        c.save();
        c.translate(s.width / 2, s.height / 2);
        c.scale(0.86);
        c.translate(-s.width / 2, -s.height / 2);
        c.drawPath(path, stroke..strokeWidth = sw * 0.6);
        c.restore();
      case 'dashed' || 'dotted' || 'perforated':
        for (final m in path.computeMetrics()) {
          final dash = d.border == 'dashed' ? sw * 3 : sw * 0.9;
          final gap = d.border == 'perforated' ? sw * 1.6 : sw * 2;
          for (var x = 0.0; x < m.length; x += dash + gap) {
            if (d.border == 'perforated') {
              c.drawCircle(
                m.getTangentForOffset(x)!.position,
                sw * 0.9,
                Paint()..color = ink,
              );
            } else {
              c.drawPath(
                m.extractPath(x, math.min(x + dash, m.length)),
                stroke
                  ..strokeCap = d.border == 'dotted'
                      ? StrokeCap.round
                      : StrokeCap.butt,
              );
            }
          }
        }
    }
    // Texture: speckles of missing ink, shaped by a fixed seed so the
    // stamp looks the same every time.
    if (d.texture != 'none' || d.effect == 'worn') {
      c.save();
      c.clipPath(path);
      final rnd = math.Random(d.text.hashCode ^ d.shape.hashCode);
      final n = d.texture == 'grain'
          ? 140
          : (d.texture == 'vintage' || d.effect == 'worn' ? 90 : 50);
      for (var i = 0; i < n; i++) {
        c.drawCircle(
          Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height),
          rnd.nextDouble() * (d.texture == 'grain' ? 0.9 : 1.8),
          Paint()..color = Color(d.color2).withValues(alpha: 0.75),
        );
      }
      if (d.texture == 'vintage')
        c.drawPath(path, Paint()..color = const Color(0x22A0742E));
      c.restore();
    }
    if (d.effect == 'shine') {
      c.save();
      c.clipPath(path);
      c.drawPath(
        Path()
          ..moveTo(s.width * 0.1, 0)
          ..lineTo(s.width * 0.35, 0)
          ..lineTo(s.width * 0.05, s.height)
          ..lineTo(-s.width * 0.2, s.height)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.3),
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_StampPainter old) => old.d != d;
}

/// Ready-made stamp looks by category.
const stampCategories = <String, (String, String, int)>{
  'personal': ('Personal', '🎂', 0xFFDB2777),
  'entertainment': ('Entertainment', '🎮', 0xFF7C3AED),
  'system': ('System', '💞', 0xFF0EA5E9),
  'companion': ('Companions', '🐾', 0xFF16A34A),
  'places': ('Places & events', '📍', 0xFFC2410C),
  'creative': ('Creativity', '🎨', 0xFFCA8A04),
  'custom': ('Custom', '✨', 0xFF475569),
};

StampDesign defaultStampFor(
  String category, {
  String text = '',
  String icon = '',
  String date = '',
}) {
  final (_, emoji, color) =
      stampCategories[category] ?? stampCategories['custom']!;
  final shapes = {
    'personal': 'heart',
    'entertainment': 'ticket',
    'system': 'flower',
    'companion': 'circle',
    'places': 'rectangle',
    'creative': 'star',
    'custom': 'circle',
  };
  return StampDesign(
    shape: shapes[category] ?? 'circle',
    icon: icon.isEmpty ? emoji : icon,
    text: text,
    date: date,
    color: color,
    color2: Color.lerp(Color(color), Colors.white, 0.92)!.toARGB32(),
    rotation: (text.hashCode % 14 - 7).toDouble(),
  );
}
