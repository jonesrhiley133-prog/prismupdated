import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_plurality/features/scrapbook/scrap_canvas.dart';
import 'package:prism_plurality/features/scrapbook/scrap_custom_texture.dart';
import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/scrapbook/scrap_texture_painter.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';

const coverBindings = <String, String>{
  'spine': 'Classic spine',
  'rings': 'Ring binder',
  'spiral': 'Spiral',
  'stitched': 'Stitched',
  'ribbon': 'Ribbon',
  'strap': 'Strap & buckle',
  'hinge': 'Metal hinges',
  'none': 'No binding',
};

/// How the cover opens when you tap it (each book picks its own).
const coverAnimations = <String, String>{
  'none': 'None',
  'swing': 'Swing open',
  'flipUp': 'Flip up',
  'slideUp': 'Slide up',
  'slideLeft': 'Slide aside',
  'fade': 'Fade',
  'zoom': 'Zoom in',
  'spin': 'Spin away',
  'pop': 'Pop',
  'sparkle': 'Sparkle',
  'curtain': 'Curtains',
  'drop': 'Drop',
};

/// One side of a cover.
class CoverFace {
  CoverFace({
    this.base = 'color',
    this.color = 0xFF7A4E2D,
    List<int>? gradient,
    this.angle = 45,
    this.material = 'm-leather-brown',
    this.tint,
    this.matIntensity = 1,
    this.matScale = 1,
    this.image,
    this.fit = const ScrapImageFit(),
    this.overlay = const ScrapTextureStyle(),
    List<ScrapElement>? els,
  }) : gradient = gradient ?? [0xFF7A4E2D, 0xFF2E1B0E],
       els = els ?? [];

  /// color | gradient | material | image
  String base;
  int color;
  List<int> gradient;
  double angle;
  String material;
  int? tint;
  double matIntensity, matScale;
  String? image;
  ScrapImageFit fit;
  ScrapTextureStyle overlay;
  List<ScrapElement> els;

  Map<String, Object?> toJson() => {
    'b': base,
    'c': color,
    'g': gradient,
    'a': angle,
    'm': material,
    'ti': ?tint,
    'mi': matIntensity,
    'ms': matScale,
    'im': ?image,
    'ft': fit.toJson(),
    'ov': overlay.toJson(),
    'e': [for (final e in els) e.toJson()],
  };

  static CoverFace fromJson(Object? o) {
    if (o is! Map) return CoverFace();
    double d(String k, double def) =>
        (o[k] is num ? (o[k] as num).toDouble() : def);
    final g = o['g'] is List
        ? [
            for (final x in o['g'] as List)
              if (x is num) x.toInt(),
          ]
        : <int>[];
    final base =
        o['b'] is String &&
            const {'color', 'gradient', 'material', 'image'}.contains(o['b'])
        ? o['b'] as String
        : 'color';
    return CoverFace(
      base: base,
      color: (o['c'] is num ? (o['c'] as num).toInt() : null) ?? 0xFF7A4E2D,
      gradient: g.length >= 2 ? g.take(5).toList() : null,
      angle: d('a', 45),
      material: o['m'] is String ? o['m'] as String : 'm-leather-brown',
      tint: (o['ti'] is num ? (o['ti'] as num).toInt() : null),
      matIntensity: d('mi', 1).clamp(0.0, 2.0),
      matScale: d('ms', 1).clamp(0.3, 4.0),
      image: o['im'] as String?,
      fit: ScrapImageFit.fromJson(o['ft']),
      overlay: ScrapTextureStyle.fromJson(o['ov']),
      els: [
        for (final e in (o['e'] is List ? o['e'] as List : const []))
          ?ScrapElement.fromJson(e),
      ],
    );
  }

  CoverFace copy() => CoverFace.fromJson(toJson());
}

/// A whole cover: shape, binding and both faces. Stored on the book.
class CoverDesign {
  CoverDesign({
    this.aspect = 0.72,
    this.thickness = 0.3,
    this.corner = 0.06,
    this.spineCorner = 0.015,
    this.binding = 'spine',
    this.spineColor,
    this.anim = 'swing',
    CoverFace? front,
    CoverFace? back,
  }) : front = front ?? CoverFace(),
       back = back ?? CoverFace();

  /// Width ÷ height.
  double aspect;

  /// 0 = thin, 1 = a fat book (shows a block of pages at the edge).
  double thickness;

  /// Outer corner rounding and rounding on the spine side, as fractions of the shorter side.
  double corner, spineCorner;
  String binding;
  int? spineColor;
  String anim;
  CoverFace front, back;

  static const minAspect = 0.4, maxAspect = 1.8;

  Map<String, Object?> toJson() => {
    'v': 1,
    'ar': aspect,
    'th': thickness,
    'co': corner,
    'sc': spineCorner,
    'bi': binding,
    'sp': ?spineColor,
    'an': anim,
    'f': front.toJson(),
    'k': back.toJson(),
  };

  static CoverDesign? fromJson(Object? o) {
    if (o is! Map || o['v'] != 1) return null;
    double d(String k, double def) =>
        (o[k] is num ? (o[k] as num).toDouble() : def);
    return CoverDesign(
      aspect: d('ar', 0.72).clamp(minAspect, maxAspect),
      thickness: d('th', 0.3).clamp(0.0, 1.0),
      corner: d('co', 0.06).clamp(0.0, 0.5),
      spineCorner: d('sc', 0.015).clamp(0.0, 0.5),
      binding: coverBindings.containsKey(o['bi']) ? o['bi'] as String : 'spine',
      spineColor: (o['sp'] is num ? (o['sp'] as num).toInt() : null),
      anim: coverAnimations.containsKey(o['an']) ? o['an'] as String : 'swing',
      front: CoverFace.fromJson(o['f']),
      back: CoverFace.fromJson(o['k']),
    );
  }

  CoverDesign copy() => CoverDesign.fromJson(toJson())!;
}

CoverDesign? coverOf(Map<String, Object?> fields) =>
    CoverDesign.fromJson(fields['cover2']);

// ── Painting ───────────────────────────────────────────────────────────────

Color _spineTone(CoverDesign d) {
  if (d.spineColor != null) return Color(d.spineColor!);
  final f = d.front;
  return switch (f.base) {
    'gradient' => Color(f.gradient.first),
    'material' =>
      f.tint != null
          ? Color(f.tint!)
          : (scrapTextureById(f.material)?.c1 ?? Color(f.color)),
    _ => Color(f.color),
  };
}

class _FaceBase extends StatelessWidget {
  const _FaceBase(this.face);
  final CoverFace face;

  @override
  Widget build(BuildContext context) {
    final Widget base = switch (face.base) {
      'gradient' => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(
              -math.cos(face.angle * math.pi / 180),
              -math.sin(face.angle * math.pi / 180),
            ),
            end: Alignment(
              math.cos(face.angle * math.pi / 180),
              math.sin(face.angle * math.pi / 180),
            ),
            colors: [for (final c in face.gradient) Color(c)],
          ),
        ),
        child: const SizedBox.expand(),
      ),
      'material' => _materialLayer(face),
      'image' =>
        face.image == null
            ? ColoredBox(
                color: Color(face.color),
                child: const SizedBox.expand(),
              )
            : LayoutBuilder(
                builder: (_, c) {
                  final f = face.fit.clamped();
                  final ex = c.maxWidth * (f.zoom - 1) / 2,
                      ey = c.maxHeight * (f.zoom - 1) / 2;
                  return ClipRect(
                    child: Transform.translate(
                      offset: Offset(-f.dx * ex, -f.dy * ey),
                      child: Transform.scale(
                        scale: f.zoom,
                        child: SizedBox.expand(
                          child: PrismMediaView(id: face.image!),
                        ),
                      ),
                    ),
                  );
                },
              ),
      _ => ColoredBox(color: Color(face.color), child: const SizedBox.expand()),
    };
    final ov = scrapTextureById(face.overlay.id);
    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        if (face.overlay.custom != null)
          ScrapCustomTexture(media: face.overlay.custom!, style: face.overlay),
        if (ov != null && face.overlay.id != 'plain')
          IgnorePointer(
            child: CustomPaint(
              painter: ScrapTexturePainter(
                kind: ov.kind,
                c1: face.overlay.color == null
                    ? ov.c1
                    : Color(face.overlay.color!),
                c2: face.overlay.color2 == null
                    ? ov.c2
                    : Color(face.overlay.color2!),
                seed: ov.seed,
                scale: ov.scale * face.overlay.scale,
                intensity: face.overlay.intensity,
                opacity: face.overlay.opacity,
                blend: scrapBlendModes[face.overlay.blend] ?? BlendMode.srcOver,
              ),
            ),
          ),
      ],
    );
  }

  static Widget _materialLayer(CoverFace f) {
    final m = scrapTextureById(f.material) ?? scrapMaterials.first;
    return RepaintBoundary(
      child: CustomPaint(
        painter: ScrapTexturePainter(
          kind: m.kind,
          c1: f.tint == null ? m.c1 : Color(f.tint!),
          c2: m.c2,
          seed: m.seed,
          scale: m.scale * f.matScale,
          intensity: f.matIntensity,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Draws a cover at the size it's given (keeping the design's proportions).
class ScrapCoverView extends StatelessWidget {
  const ScrapCoverView({
    super.key,
    required this.design,
    this.title = '',
    this.subtitle = '',
    this.back = false,
    this.locked = false,
    this.elementsBuilder,
  });
  final CoverDesign design;
  final String title, subtitle;
  final bool back;

  /// Shows a padlock instead of the artwork (private books).
  final bool locked;

  /// Lets the designer put its editable layer in place of the static one.
  final Widget Function(CoverFace face, double w, double h)? elementsBuilder;

  static List<ScrapElement> resolved(
    CoverFace face,
    String title,
    String subtitle,
  ) => [
    for (final e in face.els)
      if (e.type == ScrapType.text &&
          (e.text == '{title}' || e.text == '{subtitle}'))
        (ScrapElement.fromJson({
          ...e.toJson(),
          'tx': e.text == '{title}' ? title : subtitle,
        })!)
      else
        e,
  ];

  @override
  Widget build(BuildContext context) {
    final d = design;
    final face = back ? d.back : d.front;
    return AspectRatio(
      aspectRatio: d.aspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final m = math.min(w, h);
          final depth = d.thickness * m * 0.05;
          final outer = Radius.circular(d.corner * m),
              spine = Radius.circular(d.spineCorner * m);
          // The spine is on the left from the front and on the right from the back.
          final radius = back
              ? BorderRadius.only(
                  topLeft: outer,
                  bottomLeft: outer,
                  topRight: spine,
                  bottomRight: spine,
                )
              : BorderRadius.only(
                  topRight: outer,
                  bottomRight: outer,
                  topLeft: spine,
                  bottomLeft: spine,
                );
          final tone = _spineTone(d);
          final bodyW = w - depth, bodyH = h - depth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (depth > 0.5)
                Positioned(
                  left: back ? 0 : depth,
                  top: depth,
                  width: bodyW,
                  height: bodyH,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      color: const Color(0xFFF1E9D6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: m * 0.04,
                          offset: Offset(m * 0.012, m * 0.02),
                        ),
                      ],
                    ),
                    child: CustomPaint(painter: _PageEdgePainter(back)),
                  ),
                ),
              Positioned(
                left: back ? depth : 0,
                top: 0,
                width: bodyW,
                height: bodyH,
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _FaceBase(face),
                      Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: elementsBuilder != null
                            ? [elementsBuilder!(face, bodyW, bodyH)]
                            : [
                                for (final e in [
                                  ...resolved(face, title, subtitle),
                                ]..sort((a, b) => a.z.compareTo(b.z)))
                                  Positioned(
                                    left: e.x * bodyW,
                                    top: e.y * bodyH,
                                    width: math.max(e.w * bodyW, 8),
                                    height: math.max(e.h * bodyH, 8),
                                    child: IgnorePointer(
                                      child: Transform.rotate(
                                        angle: e.rot,
                                        child: ScrapElementView(
                                          element: e,
                                          pageWidth: bodyW,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                      ),
                      if (locked)
                        const Center(
                          child: Icon(
                            Icons.lock,
                            color: Colors.white70,
                            size: 36,
                          ),
                        ),
                      if (!back && d.binding != 'none')
                        _Binding(d.binding, tone, bodyW, bodyH, front: true),
                      if (back && d.binding != 'none')
                        _Binding(d.binding, tone, bodyW, bodyH, front: false),
                      // Edge light so even a flat colour reads as an object.
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            gradient: LinearGradient(
                              begin: back
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              end: back
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.22),
                                Colors.white.withValues(alpha: 0.07),
                                Colors.transparent,
                              ],
                              stops: const [0, 0.07, 0.3],
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PageEdgePainter extends CustomPainter {
  _PageEdgePainter(this.back);
  final bool back;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(size.width * 0.6, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_PageEdgePainter o) => o.back != back;
}

class _Binding extends StatelessWidget {
  const _Binding(this.kind, this.tone, this.w, this.h, {required this.front});
  final String kind;
  final Color tone;
  final double w, h;
  final bool front;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _BindingPainter(kind, tone, front),
      size: Size(w, h),
    ),
  );
}

class _BindingPainter extends CustomPainter {
  _BindingPainter(this.kind, this.tone, this.front);
  final String kind;
  final Color tone;
  final bool front;

  @override
  void paint(Canvas canvas, Size size) {
    if (!front) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final w = size.width, h = size.height;
    final strip = w * 0.075;
    final dark = Paint()
      ..color = Color.lerp(tone, Colors.black, 0.35)!.withValues(alpha: 0.8);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.14);
    switch (kind) {
      case 'spine':
        canvas.drawRect(
          Rect.fromLTWH(0, 0, strip, h),
          Paint()
            ..color = Color.lerp(
              tone,
              Colors.black,
              0.22,
            )!.withValues(alpha: 0.9),
        );
        canvas.drawRect(Rect.fromLTWH(strip, 0, w * 0.012, h), dark);
        canvas.drawRect(
          Rect.fromLTWH(strip + w * 0.012, 0, w * 0.006, h),
          light,
        );
      case 'stitched':
        canvas.drawRect(
          Rect.fromLTWH(0, 0, strip * 0.9, h),
          Paint()
            ..color = Color.lerp(
              tone,
              Colors.black,
              0.2,
            )!.withValues(alpha: 0.85),
        );
        final p = Paint()
          ..color = const Color(0xFFF3E7C9)
          ..strokeWidth = w * 0.008
          ..strokeCap = StrokeCap.round;
        for (var y = h * 0.04; y < h * 0.97; y += h * 0.035) {
          canvas.drawLine(
            Offset(strip * 1.1, y),
            Offset(strip * 1.1, y + h * 0.02),
            p,
          );
        }
      case 'rings':
        canvas.drawRect(
          Rect.fromLTWH(0, 0, strip * 0.7, h),
          Paint()..color = Colors.black.withValues(alpha: 0.18),
        );
        final n = 5;
        for (var i = 0; i < n; i++) {
          final cy = h * (0.12 + i * (0.76 / (n - 1)));
          final c = Offset(strip * 0.55, cy);
          canvas.drawCircle(
            c,
            w * 0.03,
            Paint()..color = Colors.black.withValues(alpha: 0.4),
          );
          canvas.drawCircle(
            c,
            w * 0.026,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.011
              ..shader = const LinearGradient(
                colors: [Color(0xFFEFEFEF), Color(0xFF8A8F96)],
              ).createShader(Rect.fromCircle(center: c, radius: w * 0.03)),
          );
        }
      case 'spiral':
        final n = (h / (w * 0.07)).floor().clamp(8, 30);
        for (var i = 0; i < n; i++) {
          final cy = h * (i + 0.5) / n;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(strip * 0.2, cy),
              width: strip * 1.1,
              height: h / n * 0.55,
            ),
            Paint()..color = Colors.black.withValues(alpha: 0.35),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(strip * 0.2, cy),
              width: strip * 1.05,
              height: h / n * 0.4,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.012
              ..color = const Color(0xFFC9CED6),
          );
          canvas.drawCircle(
            Offset(strip * 0.9, cy),
            w * 0.009,
            Paint()..color = Colors.black.withValues(alpha: 0.5),
          );
        }
      case 'ribbon':
        canvas.drawRect(
          Rect.fromLTWH(0, 0, strip * 0.5, h),
          Paint()..color = Colors.black.withValues(alpha: 0.2),
        );
        final rib = Rect.fromLTWH(w * 0.12, 0, w * 0.06, h * 1.05);
        canvas.drawRect(rib, Paint()..color = const Color(0xFFB5192B));
        canvas.drawRect(
          Rect.fromLTWH(rib.left + rib.width * 0.15, 0, rib.width * 0.12, h),
          light,
        );
        canvas.drawPath(
          Path()
            ..moveTo(rib.left, h)
            ..lineTo(rib.right, h)
            ..lineTo(rib.center.dx, h - w * 0.04)
            ..close(),
          Paint()..color = tone,
        );
      case 'strap':
        canvas.drawRect(
          Rect.fromLTWH(0, 0, strip * 0.7, h),
          Paint()..color = Colors.black.withValues(alpha: 0.18),
        );
        final s = Rect.fromLTWH(w * 0.55, h * 0.45, w * 0.5, h * 0.07);
        canvas.drawRect(
          s,
          Paint()..color = Color.lerp(tone, Colors.black, 0.4)!,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            s.left,
            s.top + s.height * 0.1,
            s.width,
            s.height * 0.08,
          ),
          light,
        );
        final b = Rect.fromCenter(
          center: Offset(w * 0.62, s.center.dy),
          width: w * 0.06,
          height: s.height * 1.35,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(b, Radius.circular(w * 0.008)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.012
            ..color = const Color(0xFFD4AF37),
        );
      case 'hinge':
        canvas.drawRect(
          Rect.fromLTWH(0, 0, strip * 0.6, h),
          Paint()..color = Colors.black.withValues(alpha: 0.18),
        );
        for (final y in [h * 0.1, h * 0.5, h * 0.9]) {
          final r = Rect.fromLTWH(0, y - h * 0.045, w * 0.13, h * 0.09);
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(w * 0.01)),
            Paint()
              ..shader = const LinearGradient(
                colors: [Color(0xFFE8D48A), Color(0xFF9A7A22)],
              ).createShader(r),
          );
          for (final dx in [0.03, 0.09]) {
            canvas.drawCircle(
              Offset(w * dx, y),
              w * 0.008,
              Paint()..color = Colors.black.withValues(alpha: 0.5),
            );
          }
        }
    }
  }

  @override
  bool shouldRepaint(_BindingPainter o) =>
      o.kind != kind || o.tone != tone || o.front != front;
}

// ── Opening animation ──────────────────────────────────────────────────────

/// Plays [design]'s opening animation over whatever is behind, then calls [onDone].
class ScrapCoverOpening extends StatefulWidget {
  const ScrapCoverOpening({
    super.key,
    required this.design,
    required this.title,
    required this.subtitle,
    required this.onDone,
    this.width = 220,
  });
  final CoverDesign design;
  final String title, subtitle;
  final VoidCallback onDone;
  final double width;

  @override
  State<ScrapCoverOpening> createState() => _ScrapCoverOpeningState();
}

class _ScrapCoverOpeningState extends State<ScrapCoverOpening>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 820),
        )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cover = SizedBox(
      width: widget.width,
      child: ScrapCoverView(
        design: widget.design,
        title: widget.title,
        subtitle: widget.subtitle,
      ),
    );
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_c.value);
          final raw = _c.value;
          switch (widget.design.anim) {
            case 'swing':
              return Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateY(-t * math.pi * 0.62),
                child: Opacity(
                  opacity: (1 - math.max(0.0, raw - 0.7) * 3.3).clamp(0.0, 1.0),
                  child: cover,
                ),
              );
            case 'flipUp':
              return Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateX(t * math.pi * 0.6),
                child: Opacity(
                  opacity: (1 - math.max(0.0, raw - 0.7) * 3.3).clamp(0.0, 1.0),
                  child: cover,
                ),
              );
            case 'slideUp':
              return Transform.translate(
                offset: Offset(0, -t * MediaQuery.sizeOf(context).height),
                child: cover,
              );
            case 'slideLeft':
              return Transform.translate(
                offset: Offset(-t * MediaQuery.sizeOf(context).width, 0),
                child: cover,
              );
            case 'fade':
              return Opacity(opacity: 1 - t, child: cover);
            case 'zoom':
              return Opacity(
                opacity: (1 - math.max(0.0, raw - 0.5) * 2).clamp(0.0, 1.0),
                child: Transform.scale(scale: 1 + t * 2.4, child: cover),
              );
            case 'spin':
              return Opacity(
                opacity: 1 - t,
                child: Transform.rotate(
                  angle: t * math.pi * 2,
                  child: Transform.scale(scale: 1 - t * 0.7, child: cover),
                ),
              );
            case 'pop':
              return Opacity(
                opacity: (1 - math.max(0.0, raw - 0.55) * 2.2).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: raw < 0.3 ? 1 - raw * 0.5 : 0.85 + (raw - 0.3) * 2.2,
                  child: cover,
                ),
              );
            case 'sparkle':
              return Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 1 - t,
                    child: Transform.scale(scale: 1 + t * 0.15, child: cover),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size.square(widget.width * 2),
                      painter: _SparklePainter(raw),
                    ),
                  ),
                ],
              );
            case 'curtain':
              final half = widget.width / 2;
              return SizedBox(
                width: widget.width,
                child: Stack(
                  children: [
                    Transform.translate(
                      offset: Offset(-t * half * 1.3, 0),
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.5,
                          child: cover,
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(half + t * half * 1.3, 0),
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerRight,
                          widthFactor: 0.5,
                          child: cover,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            case 'drop':
              return Transform.translate(
                offset: Offset(0, t * t * MediaQuery.sizeOf(context).height),
                child: Transform.rotate(angle: t * 0.25, child: cover),
              );
            default:
              return cover;
          }
        },
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(4);
    final c = size.center(Offset.zero);
    for (var i = 0; i < 26; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final r = (0.15 + rnd.nextDouble() * 0.85) * size.width * 0.5 * t;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      final s = (1 - t) * (4 + rnd.nextDouble() * 6);
      final path = Path()
        ..moveTo(p.dx, p.dy - s)
        ..lineTo(p.dx + s * 0.3, p.dy)
        ..lineTo(p.dx, p.dy + s)
        ..lineTo(p.dx - s * 0.3, p.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(
            0xFFFFF3B0,
          ).withValues(alpha: (1 - t).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter o) => o.t != t;
}

/// Opens a book with its cover animation (or straight away when the cover has
/// none, or when the device asks for reduced motion).
Future<void> openWithCoverAnimation(
  BuildContext context, {
  required CoverDesign? design,
  required String title,
  required String subtitle,
  required VoidCallback open,
}) async {
  if (design == null ||
      design.anim == 'none' ||
      MediaQuery.disableAnimationsOf(context)) {
    open();
    return;
  }
  var opened = false;
  void go() {
    if (opened) return;
    opened = true;
    open();
  }

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black26,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, _) => ScrapCoverOpening(
      design: design,
      title: title,
      subtitle: subtitle,
      onDone: () {
        go();
        if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
      },
    ),
  );
  go();
}
