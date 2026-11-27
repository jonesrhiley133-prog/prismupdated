import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_plurality/features/scrapbook/scrap_shapes.dart';

/// A picture frame: the shape the picture is masked to, plus the mat, line
/// and decoration drawn around it. Frames only ever *mask* a picture (it is
/// scaled to cover, never stretched), and the picture can be moved and
/// zoomed inside the frame independently.
class ScrapFrameSpec {
  const ScrapFrameSpec(
    this.id,
    this.name,
    this.category,
    this.shape, {
    this.mat = 0,
    this.matBottom = 0,
    this.matColor = Colors.white,
    this.line = 0,
    this.lineColor = Colors.white,
    this.twin = false,
    this.dashed = false,
    this.glow,
    this.shadow = 0,
    this.deco = '',
  });
  final String id, name, category, shape;

  /// Mat width as a fraction of the shorter side; [matBottom] adds more below.
  final double mat, matBottom;
  final Color matColor;

  /// Outline width as a fraction of the shorter side.
  final double line;
  final Color lineColor;
  final bool twin, dashed;
  final Color? glow;
  final double shadow;

  /// Extra decoration: tape, pin, film, stitch, corners, gold, vintage…
  final String deco;

  Rect inner(Size s) {
    final m = math.min(s.width, s.height) * mat;
    final b = math.min(s.width, s.height) * matBottom;
    return Rect.fromLTRB(m, m, s.width - m, s.height - m - b);
  }
}

const scrapFrameCategories = <String>[
  'Simple',
  'Matted',
  'Outlined',
  'Double line',
  'Classic',
  'Craft',
  'Glow & shine',
];

const _maskShapes = <String>[
  'rect',
  'rrect',
  'squircle',
  'ellipse',
  'heart',
  'star',
  'hex',
  'diamond',
  'arch',
  'cloud',
  'flower',
  'scallop',
  'tombstone',
  'octagon',
  'pill',
  'shield',
  'drop',
  'burst',
  'leaf',
  'ticket',
  'blob',
  'moon',
  'bookmark',
  'house',
];

final List<ScrapFrameSpec> scrapFrames = _build();

List<ScrapFrameSpec> _build() {
  final out = <ScrapFrameSpec>[];
  for (final s in _maskShapes) {
    final n = scrapShapeName(s);
    out.add(ScrapFrameSpec('$s-plain', n, 'Simple', s));
  }
  for (final s in _maskShapes) {
    final n = scrapShapeName(s);
    out.add(
      ScrapFrameSpec(
        '$s-mat',
        '$n mat',
        'Matted',
        s,
        mat: 0.05,
        matColor: Colors.white,
        shadow: 4,
      ),
    );
  }
  for (final s in _maskShapes) {
    final n = scrapShapeName(s);
    out.add(
      ScrapFrameSpec(
        '$s-line',
        '$n outline',
        'Outlined',
        s,
        line: 0.035,
        lineColor: Colors.white,
        shadow: 3,
      ),
    );
  }
  for (final s in _maskShapes) {
    final n = scrapShapeName(s);
    out.add(
      ScrapFrameSpec(
        '$s-double',
        '$n double',
        'Double line',
        s,
        mat: 0.045,
        matColor: const Color(0xFFFFFBF2),
        line: 0.012,
        lineColor: const Color(0xFF8A6B3A),
        twin: true,
      ),
    );
  }
  out.addAll(const [
    ScrapFrameSpec(
      'polaroid',
      'Polaroid',
      'Classic',
      'rect',
      mat: 0.05,
      matBottom: 0.16,
      shadow: 6,
    ),
    ScrapFrameSpec(
      'polaroid-mini',
      'Instant mini',
      'Classic',
      'rect',
      mat: 0.07,
      matBottom: 0.22,
      shadow: 5,
      matColor: Color(0xFFFFFBEF),
    ),
    ScrapFrameSpec(
      'polaroid-black',
      'Black instant',
      'Classic',
      'rect',
      mat: 0.05,
      matBottom: 0.16,
      matColor: Color(0xFF1E1E22),
      shadow: 6,
    ),
    ScrapFrameSpec(
      'film',
      'Film strip',
      'Classic',
      'rect',
      mat: 0.1,
      matColor: Color(0xFF17171B),
      deco: 'film',
    ),
    ScrapFrameSpec(
      'vintage',
      'Vintage photo',
      'Classic',
      'rect',
      mat: 0.06,
      matColor: Color(0xFFF1E6CC),
      line: 0.01,
      lineColor: Color(0xFF9A7A3F),
      twin: true,
      shadow: 4,
      deco: 'vintage',
    ),
    ScrapFrameSpec(
      'gold',
      'Gold frame',
      'Classic',
      'rect',
      mat: 0.045,
      matColor: Color(0xFFD4AF37),
      line: 0.012,
      lineColor: Color(0xFF8A6A12),
      twin: true,
      shadow: 5,
      deco: 'gold',
    ),
    ScrapFrameSpec(
      'gold-oval',
      'Gold oval',
      'Classic',
      'ellipse',
      mat: 0.045,
      matColor: Color(0xFFD4AF37),
      line: 0.012,
      lineColor: Color(0xFF8A6A12),
      twin: true,
      shadow: 5,
      deco: 'gold',
    ),
    ScrapFrameSpec(
      'stamp',
      'Postage stamp',
      'Classic',
      'stamp',
      mat: 0.07,
      matColor: Colors.white,
      shadow: 4,
    ),
    ScrapFrameSpec(
      'ticket-stub',
      'Ticket stub',
      'Classic',
      'ticket',
      mat: 0.04,
      matColor: Color(0xFFF7E9C6),
      shadow: 4,
    ),
    ScrapFrameSpec(
      'torn',
      'Torn photo',
      'Craft',
      'torn',
      mat: 0.03,
      matColor: Colors.white,
      shadow: 4,
    ),
    ScrapFrameSpec(
      'taped',
      'Taped corners',
      'Craft',
      'rect',
      shadow: 4,
      deco: 'tape',
    ),
    ScrapFrameSpec(
      'taped-top',
      'Taped on top',
      'Craft',
      'rect',
      mat: 0.03,
      shadow: 4,
      deco: 'tapeTop',
    ),
    ScrapFrameSpec(
      'pinned',
      'Pinned',
      'Craft',
      'rect',
      mat: 0.04,
      shadow: 5,
      deco: 'pin',
    ),
    ScrapFrameSpec(
      'stitched',
      'Stitched felt',
      'Craft',
      'rrect',
      mat: 0.06,
      matColor: Color(0xFFE08A9C),
      line: 0.012,
      lineColor: Colors.white,
      dashed: true,
      deco: 'stitchInner',
    ),
    ScrapFrameSpec(
      'stitched-denim',
      'Stitched denim',
      'Craft',
      'rrect',
      mat: 0.06,
      matColor: Color(0xFF3C5F8F),
      line: 0.012,
      lineColor: Color(0xFFF0C25A),
      dashed: true,
      deco: 'stitchInner',
    ),
    ScrapFrameSpec(
      'sticker',
      'Die-cut sticker',
      'Craft',
      'blob',
      mat: 0.035,
      matColor: Colors.white,
      shadow: 5,
    ),
    ScrapFrameSpec(
      'sticker-heart',
      'Sticker heart',
      'Craft',
      'heart',
      mat: 0.035,
      matColor: Colors.white,
      shadow: 5,
    ),
    ScrapFrameSpec(
      'cut-dashed',
      'Cut here',
      'Craft',
      'rect',
      line: 0.012,
      lineColor: Color(0xFF444444),
      dashed: true,
      mat: 0.03,
      matColor: Colors.white,
    ),
    ScrapFrameSpec(
      'neon-pink',
      'Neon pink',
      'Glow & shine',
      'rrect',
      line: 0.025,
      lineColor: Color(0xFFFF4FA3),
      glow: Color(0xFFFF4FA3),
    ),
    ScrapFrameSpec(
      'neon-blue',
      'Neon blue',
      'Glow & shine',
      'rrect',
      line: 0.025,
      lineColor: Color(0xFF35D0FF),
      glow: Color(0xFF35D0FF),
    ),
    ScrapFrameSpec(
      'neon-green',
      'Neon green',
      'Glow & shine',
      'rrect',
      line: 0.025,
      lineColor: Color(0xFF5CFF8A),
      glow: Color(0xFF5CFF8A),
    ),
    ScrapFrameSpec(
      'neon-heart',
      'Neon heart',
      'Glow & shine',
      'heart',
      line: 0.025,
      lineColor: Color(0xFFFF4F6E),
      glow: Color(0xFFFF4F6E),
    ),
    ScrapFrameSpec(
      'glow-star',
      'Glowing star',
      'Glow & shine',
      'star',
      line: 0.02,
      lineColor: Color(0xFFFFE066),
      glow: Color(0xFFFFD21F),
    ),
    ScrapFrameSpec(
      'rose-gold',
      'Rose-gold',
      'Glow & shine',
      'rrect',
      mat: 0.03,
      matColor: Color(0xFFD9967F),
      line: 0.01,
      lineColor: Color(0xFFFFE3D6),
      twin: true,
      deco: 'gold',
    ),
  ]);
  return out;
}

ScrapFrameSpec? scrapFrameById(String id) {
  for (final f in scrapFrames) {
    if (f.id == id) return f;
  }
  return null;
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.f, this.front, this.tint);
  final ScrapFrameSpec f;
  final bool front;
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final minSide = math.min(size.width, size.height);
    final lineW = minSide * f.line;
    final mat = f.matColor;
    final lineColor = tint ?? f.lineColor;
    final outerPath = scrapShapePath(f.shape, outer.deflate(lineW / 2));
    if (!front) {
      if (f.shadow > 0)
        canvas.drawShadow(outerPath, Colors.black, f.shadow, false);
      if (f.glow != null) {
        canvas.drawPath(
          outerPath,
          Paint()
            ..color = f.glow!.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = lineW * 2.4
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, minSide * 0.03),
        );
      }
      if (f.mat > 0 || f.matBottom > 0)
        canvas.drawPath(outerPath, Paint()..color = mat);
      if (f.deco == 'gold') {
        canvas.drawPath(
          outerPath,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF6E27A),
                Color(0xFFB8860B),
                Color(0xFFF6E27A),
                Color(0xFF9A7209),
              ],
            ).createShader(outer),
        );
      }
      if (f.deco == 'film') {
        final holes = Paint()..color = const Color(0xFFEDEDED);
        final s = minSide * 0.055;
        for (var x = s; x < size.width - s; x += s * 2.1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, s * 0.55, s, s * 0.8),
              Radius.circular(s * 0.2),
            ),
            holes,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, size.height - s * 1.35, s, s * 0.8),
              Radius.circular(s * 0.2),
            ),
            holes,
          );
        }
      }
      return;
    }
    // Front: lines and decoration drawn over the picture's edge.
    if (lineW > 0) {
      final inner = f.inner(size);
      final linePath = f.mat > 0
          ? scrapShapePath(f.shape, inner.inflate(0))
          : outerPath;
      final p = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineW
        ..strokeJoin = StrokeJoin.round;
      if (f.dashed) {
        _dashed(
          canvas,
          f.deco == 'stitchInner'
              ? scrapShapePath(f.shape, inner.deflate(minSide * 0.01))
              : linePath,
          p,
          lineW * 2.5,
          lineW * 1.6,
        );
      } else {
        canvas.drawPath(linePath, p);
        if (f.twin) {
          canvas.drawPath(outerPath, p..strokeWidth = lineW * 0.7);
        }
      }
    }
    switch (f.deco) {
      case 'tape':
        _tape(
          canvas,
          size,
          Offset(size.width * 0.02, size.height * 0.02),
          -0.7,
        );
        _tape(
          canvas,
          size,
          Offset(size.width * 0.98, size.height * 0.98),
          -0.7,
        );
      case 'tapeTop':
        _tape(canvas, size, Offset(size.width * 0.5, 0), 0);
      case 'pin':
        final c = Offset(size.width / 2, minSide * 0.045);
        canvas.drawCircle(
          c + Offset(minSide * 0.01, minSide * 0.015),
          minSide * 0.04,
          Paint()..color = Colors.black.withValues(alpha: 0.3),
        );
        canvas.drawCircle(
          c,
          minSide * 0.04,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.4),
              colors: const [Color(0xFFFF8A8A), Color(0xFFC62828)],
            ).createShader(Rect.fromCircle(center: c, radius: minSide * 0.04)),
        );
      case 'vintage':
        final corner = Paint()..color = const Color(0xFF9A7A3F);
        final s = minSide * 0.05;
        for (final o in [
          Offset(0, 0),
          Offset(size.width, 0),
          Offset(0, size.height),
          Offset(size.width, size.height),
        ]) {
          canvas.drawCircle(o, s, corner);
        }
    }
  }

  void _tape(Canvas canvas, Size size, Offset at, double angle) {
    final w = math.min(size.width, size.height) * 0.3, h = w * 0.3;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawRect(
      r,
      Paint()..color = const Color(0xFFFFE08A).withValues(alpha: 0.78),
    );
    final z = Path()..moveTo(r.left, r.top);
    final step = h / 3;
    for (var x = r.left, i = 0; x < r.right; x += step, i++) {
      z.lineTo(x, i.isEven ? r.top : r.top + h * 0.12);
    }
    canvas.restore();
  }

  void _dashed(Canvas canvas, Path path, Paint p, double on, double off) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + on, m.length)), p);
        d += on + off;
      }
    }
  }

  @override
  bool shouldRepaint(_FramePainter o) =>
      o.f != f || o.front != front || o.tint != tint;
}

/// How a picture sits inside its frame: 1 = fills the frame; larger zooms in.
/// [dx]/[dy] move the picture, as a fraction of the frame, within the room
/// the zoom leaves (so it can never uncover an empty edge).
class ScrapImageFit {
  const ScrapImageFit({this.zoom = 1, this.dx = 0, this.dy = 0});
  final double zoom, dx, dy;
  ScrapImageFit clamped() => ScrapImageFit(
    zoom: zoom.clamp(1.0, 6.0),
    dx: dx.clamp(-1.0, 1.0),
    dy: dy.clamp(-1.0, 1.0),
  );
  Map<String, Object?> toJson() => {'z': zoom, 'x': dx, 'y': dy};
  static ScrapImageFit fromJson(Object? j) => j is Map
      ? ScrapImageFit(
          zoom: (j['z'] as num?)?.toDouble() ?? 1,
          dx: (j['x'] as num?)?.toDouble() ?? 0,
          dy: (j['y'] as num?)?.toDouble() ?? 0,
        ).clamped()
      : const ScrapImageFit();
}

/// Masks [child] (an image, built to cover) with [frame] and draws the frame.
class ScrapFramedImage extends StatelessWidget {
  const ScrapFramedImage({
    super.key,
    required this.frame,
    required this.child,
    this.fit = const ScrapImageFit(),
    this.tint,
  });
  final ScrapFrameSpec frame;
  final Widget child;
  final ScrapImageFit fit;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(
          c.hasBoundedWidth ? c.maxWidth : 200,
          c.hasBoundedHeight ? c.maxHeight : 200,
        );
        final inner = frame.inner(size);
        final f = fit.clamped();
        // Room to move: half the extra size the zoom adds.
        final extraX = inner.width * (f.zoom - 1) / 2,
            extraY = inner.height * (f.zoom - 1) / 2;
        return SizedBox.fromSize(
          size: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _FramePainter(frame, false, tint)),
              ),
              Positioned.fromRect(
                rect: inner,
                child: ClipPath(
                  clipper: _ShapeClipper(frame.shape),
                  child: Transform.translate(
                    offset: Offset(-f.dx * extraX, -f.dy * extraY),
                    child: Transform.scale(
                      scale: f.zoom,
                      child: SizedBox.expand(child: child),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _FramePainter(frame, true, tint)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShapeClipper extends CustomClipper<Path> {
  _ShapeClipper(this.shape);
  final String shape;
  @override
  Path getClip(Size size) => scrapShapePath(shape, Offset.zero & size);
  @override
  bool shouldReclip(_ShapeClipper o) => o.shape != shape;
}
