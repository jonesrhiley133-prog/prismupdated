import 'dart:math' as math;

import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';

import 'package:prism_plurality/features/flags/flag_model.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart'
    show SocialImage;

/// The outline a flag is cut to.
Path flagOutline(Size s, String shape) {
  final w = s.width, h = s.height;
  switch (shape) {
    case 'rounded':
      return Path()..addRRect(
        RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(h * 0.08)),
      );
    case 'swallowtail':
      return Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(w * 0.78, h / 2)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    case 'pennant':
      return Path()
        ..moveTo(0, 0)
        ..lineTo(w, h / 2)
        ..lineTo(0, h)
        ..close();
    case 'banner':
      return Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h)
        ..lineTo(w / 2, h * 0.8)
        ..lineTo(0, h)
        ..close();
    case 'circle':
      return Path()..addOval(
        Rect.fromCenter(
          center: s.center(Offset.zero),
          width: math.min(w, h),
          height: math.min(w, h),
        ),
      );
    default:
      return Path()..addRect(Offset.zero & s);
  }
}

Path shapePath(String kind, Rect r) {
  final c = r.center;
  switch (kind) {
    case 'ellipse':
      return Path()..addOval(r);
    case 'ring':
      return Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(r)
        ..addOval(r.deflate(math.min(r.width, r.height) * 0.16));
    case 'triangle':
      return Path()
        ..moveTo(c.dx, r.top)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.left, r.bottom)
        ..close();
    case 'diamond':
      return Path()
        ..moveTo(c.dx, r.top)
        ..lineTo(r.right, c.dy)
        ..lineTo(c.dx, r.bottom)
        ..lineTo(r.left, c.dy)
        ..close();
    case 'hexagon':
      final p = Path();
      for (var i = 0; i < 6; i++) {
        final a = math.pi / 3 * i;
        final pt =
            c + Offset(math.cos(a) * r.width / 2, math.sin(a) * r.height / 2);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    case 'star':
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + math.pi / 5 * i;
        final k = i.isEven ? 1.0 : 0.42;
        final pt =
            c +
            Offset(
              math.cos(a) * r.width / 2 * k,
              math.sin(a) * r.height / 2 * k,
            );
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    case 'heart':
      final w = r.width, h = r.height;
      return Path()
        ..moveTo(c.dx, r.top + h * 0.3)
        ..cubicTo(c.dx, r.top, r.left, r.top, r.left, r.top + h * 0.32)
        ..cubicTo(
          r.left,
          r.top + h * 0.6,
          c.dx - w * 0.1,
          r.top + h * 0.75,
          c.dx,
          r.bottom,
        )
        ..cubicTo(
          c.dx + w * 0.1,
          r.top + h * 0.75,
          r.right,
          r.top + h * 0.6,
          r.right,
          r.top + h * 0.32,
        )
        ..cubicTo(r.right, r.top, c.dx, r.top, c.dx, r.top + h * 0.3)
        ..close();
    case 'moon':
      return Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(r)
        ..addOval(r.shift(Offset(r.width * 0.28, -r.height * 0.08)));
    default:
      return Path()..addRect(r);
  }
}

/// Paints one non-image layer.
void paintFlagLayer(Canvas c, Size s, FlagLayer l) {
  if (!l.visible) return;
  final w = s.width, h = s.height;
  Paint fill(int color) => Paint()
    ..color = Color(color).withValues(alpha: Color(color).a * l.opacity)
    ..isAntiAlias = true;
  final cols = l.colors.isEmpty ? const [0xFF000000] : l.colors;
  int col(int i) => cols[i % cols.length];
  switch (l.kind) {
    case 'fill':
      c.drawRect(Offset.zero & s, fill(l.color));
    case 'layout':
      switch (l.layout) {
        case 'hstripes':
          for (var i = 0; i < cols.length; i++) {
            c.drawRect(
              Rect.fromLTWH(0, h * i / cols.length, w, h / cols.length + 0.5),
              fill(cols[i]),
            );
          }
        case 'vstripes':
          for (var i = 0; i < cols.length; i++) {
            c.drawRect(
              Rect.fromLTWH(w * i / cols.length, 0, w / cols.length + 0.5, h),
              fill(cols[i]),
            );
          }
        case 'diagonal':
          c.drawRect(Offset.zero & s, fill(col(0)));
          c.drawPath(
            Path()
              ..moveTo(w, 0)
              ..lineTo(w, h)
              ..lineTo(0, h)
              ..close(),
            fill(col(1)),
          );
        case 'nordic':
          c.drawRect(Offset.zero & s, fill(col(0)));
          final t = h * 0.2;
          c.drawRect(Rect.fromLTWH(w * 0.3, 0, t, h), fill(col(1)));
          c.drawRect(Rect.fromLTWH(0, h / 2 - t / 2, w, t), fill(col(1)));
        case 'cross':
          c.drawRect(Offset.zero & s, fill(col(0)));
          final t = h * 0.2;
          c.drawRect(Rect.fromLTWH(w / 2 - t / 2, 0, t, h), fill(col(1)));
          c.drawRect(Rect.fromLTWH(0, h / 2 - t / 2, w, t), fill(col(1)));
        case 'saltire':
          c.drawRect(Offset.zero & s, fill(col(0)));
          final p = Paint()
            ..color = Color(col(1)).withValues(alpha: l.opacity)
            ..strokeWidth = h * 0.18;
          c.drawLine(Offset.zero, Offset(w, h), p);
          c.drawLine(Offset(w, 0), Offset(0, h), p);
        case 'canton':
          c.drawRect(Rect.fromLTWH(0, 0, w * 0.4, h * 0.54), fill(col(0)));
        case 'chevron':
          c.drawPath(
            Path()
              ..moveTo(0, 0)
              ..lineTo(w * 0.42, h / 2)
              ..lineTo(0, h)
              ..close(),
            fill(col(0)),
          );
        case 'triangle':
          c.drawPath(
            Path()
              ..moveTo(0, 0)
              ..lineTo(w * 0.3, h / 2)
              ..lineTo(0, h)
              ..close(),
            fill(col(0)),
          );
        case 'border':
          final t = h * 0.1;
          c.drawPath(
            Path()
              ..fillType = PathFillType.evenOdd
              ..addRect(Offset.zero & s)
              ..addRect(Rect.fromLTWH(t, t, w - 2 * t, h - 2 * t)),
            fill(col(0)),
          );
        case 'quartered':
          c.drawRect(Rect.fromLTWH(0, 0, w / 2, h / 2), fill(col(0)));
          c.drawRect(Rect.fromLTWH(w / 2, 0, w / 2, h / 2), fill(col(1)));
          c.drawRect(Rect.fromLTWH(0, h / 2, w / 2, h / 2), fill(col(1)));
          c.drawRect(Rect.fromLTWH(w / 2, h / 2, w / 2, h / 2), fill(col(0)));
        case 'circle':
          c.drawCircle(Offset(w / 2, h / 2), h * 0.3, fill(col(0)));
      }
    case 'shape':
      c.save();
      final r = Rect.fromCenter(
        center: Offset(l.x * w, l.y * h),
        width: l.w * w,
        height: l.h * h,
      );
      c.translate(r.center.dx, r.center.dy);
      c.rotate(l.rotation * math.pi / 180);
      c.translate(-r.center.dx, -r.center.dy);
      c.drawPath(shapePath(l.shape, r), fill(l.color));
      c.restore();
    case 'symbol' || 'text':
      final tp = TextPainter(
        text: TextSpan(
          text: l.text,
          style: TextStyle(
            color: Color(l.color).withValues(alpha: l.opacity),
            fontSize: l.w * h,
            fontWeight: l.kind == 'text' ? FontWeight.w800 : FontWeight.w400,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      c.save();
      c.translate(l.x * w, l.y * h);
      c.rotate(l.rotation * math.pi / 180);
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
    case 'draw':
      if (l.points.length < 2) return;
      final p = Path()..moveTo(l.points.first.dx * w, l.points.first.dy * h);
      for (final pt in l.points.skip(1)) {
        p.lineTo(pt.dx * w, pt.dy * h);
      }
      c.drawPath(
        p,
        Paint()
          ..color = Color(l.color).withValues(alpha: l.opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, l.stroke * h)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    case 'vector':
      c.save();
      c.translate(l.x * w - l.w * w / 2, l.y * h - l.h * h / 2);
      final box = Size(l.w * w, l.h * h);
      for (final (d, color) in l.paths) {
        c.drawPath(parseNormalizedPath(d, box), fill(color));
      }
      c.restore();
  }
}

/// A flag drawn at [width]; images become their own positioned layers.
class FlagView extends StatelessWidget {
  const FlagView({
    super.key,
    required this.design,
    this.width = 240,
    this.border = true,
  });
  final FlagDesign design;
  final double width;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final h = width / design.aspect;
    final size = Size(width, h);
    final children = <Widget>[];
    var batch = <FlagLayer>[];
    void flush() {
      if (batch.isEmpty) return;
      final b = batch;
      children.add(
        Positioned.fill(child: CustomPaint(painter: _LayersPainter(b))),
      );
      batch = [];
    }

    for (final l in design.layers) {
      if (l.kind == 'image') {
        flush();
        if (l.visible && l.media != null) {
          children.add(
            Positioned(
              left: l.x * width - l.w * width / 2,
              top: l.y * h - l.h * h / 2,
              width: l.w * width,
              height: l.h * h,
              child: Opacity(
                opacity: l.opacity,
                child: Transform.rotate(
                  angle: l.rotation * math.pi / 180,
                  child: SocialImage(id: l.media!, fit: BoxFit.contain),
                ),
              ),
            ),
          );
        }
      } else {
        batch.add(l);
      }
    }
    flush();
    return SizedBox(
      width: width,
      height: h,
      child: CustomPaint(
        foregroundPainter: border ? _OutlinePainter(design.shape) : null,
        child: ClipPath(
          clipper: _ShapeClipper(design.shape),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(child: Container(color: Colors.white)),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _LayersPainter extends CustomPainter {
  _LayersPainter(this.layers);
  final List<FlagLayer> layers;
  @override
  void paint(Canvas c, Size s) {
    for (final l in layers) {
      paintFlagLayer(c, s, l);
    }
  }

  @override
  bool shouldRepaint(_LayersPainter o) => !identical(o.layers, layers);
}

class _ShapeClipper extends CustomClipper<Path> {
  _ShapeClipper(this.shape);
  final String shape;
  @override
  Path getClip(Size size) => flagOutline(size, shape);
  @override
  bool shouldReclip(_ShapeClipper o) => o.shape != shape;
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.shape);
  final String shape;
  @override
  void paint(Canvas c, Size s) => c.drawPath(
    flagOutline(s, shape),
    Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  @override
  bool shouldRepaint(_OutlinePainter o) => o.shape != shape;
}

/// A flag gently waving on a pole, for previews.
class WavingFlag extends StatefulWidget {
  const WavingFlag({super.key, required this.design, this.width = 220});
  final FlagDesign design;
  final double width;
  @override
  State<WavingFlag> createState() => _WavingFlagState();
}

class _WavingFlagState extends State<WavingFlag>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const slices = 24;
    final w = widget.width;
    final h = w / widget.design.aspect;
    final flag = FlagView(design: widget.design, width: w, border: false);
    return SizedBox(
      width: w + 10,
      height: h * 1.6,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF8C8C8C),
                borderRadius: prismCorners(context, 2),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(
              children: [
                for (var i = 0; i < slices; i++)
                  Positioned(
                    left: 4 + w * i / slices,
                    top:
                        6 +
                        math.sin(
                              _c.value * 2 * math.pi - i / slices * 2 * math.pi,
                            ) *
                            h *
                            0.06 *
                            (i / slices),
                    width: w / slices + 0.6,
                    height: h,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        maxWidth: w,
                        minWidth: w,
                        child: Transform.translate(
                          offset: Offset(-w * i / slices, 0),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(
                                alpha:
                                    (math.cos(
                                              _c.value * 2 * math.pi -
                                                  i / slices * 2 * math.pi,
                                            ) *
                                            0.08)
                                        .clamp(0, 1),
                              ),
                              BlendMode.srcATop,
                            ),
                            child: flag,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SVG ──────────────────────────────────────────────────────────────────

/// Parses commands written in 0–1 space (M L H V C Q Z, absolute) to a path.
Path parseNormalizedPath(String d, Size s) {
  final p = Path();
  final tokens = RegExp(
    r'[MLHVCQZ]|-?\d*\.?\d+(?:e-?\d+)?',
    caseSensitive: false,
  ).allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = 'M';
  var cx = 0.0, cy = 0.0;
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp('[A-Za-z]').hasMatch(tokens[i])) cmd = tokens[i++].toUpperCase();
    switch (cmd) {
      case 'M':
        cx = n();
        cy = n();
        p.moveTo(cx * s.width, cy * s.height);
        cmd = 'L';
      case 'L':
        cx = n();
        cy = n();
        p.lineTo(cx * s.width, cy * s.height);
      case 'H':
        cx = n();
        p.lineTo(cx * s.width, cy * s.height);
      case 'V':
        cy = n();
        p.lineTo(cx * s.width, cy * s.height);
      case 'C':
        final a = [n(), n(), n(), n(), n(), n()];
        cx = a[4];
        cy = a[5];
        p.cubicTo(
          a[0] * s.width,
          a[1] * s.height,
          a[2] * s.width,
          a[3] * s.height,
          cx * s.width,
          cy * s.height,
        );
      case 'Q':
        final a = [n(), n(), n(), n()];
        cx = a[2];
        cy = a[3];
        p.quadraticBezierTo(
          a[0] * s.width,
          a[1] * s.height,
          cx * s.width,
          cy * s.height,
        );
      case 'Z':
        p.close();
      default:
        i++;
    }
  }
  return p;
}

int? _svgColor(String? v) {
  if (v == null) return null;
  v = v.trim().toLowerCase();
  if (v == 'none' || v == 'transparent') return 0;
  const named = {
    'black': 0xFF000000,
    'white': 0xFFFFFFFF,
    'red': 0xFFFF0000,
    'green': 0xFF008000,
    'blue': 0xFF0000FF,
    'yellow': 0xFFFFFF00,
    'purple': 0xFF800080,
    'orange': 0xFFFFA500,
    'pink': 0xFFFFC0CB,
    'gray': 0xFF808080,
    'grey': 0xFF808080,
  };
  if (named.containsKey(v)) return named[v];
  final hex = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6})$').firstMatch(v);
  if (hex != null) {
    var s = hex.group(1)!;
    if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
    return 0xFF000000 | int.parse(s, radix: 16);
  }
  final rgb = RegExp(r'rgb\(\s*(\d+)\D+(\d+)\D+(\d+)').firstMatch(v);
  if (rgb != null)
    return 0xFF000000 |
        (int.parse(rgb.group(1)!) << 16) |
        (int.parse(rgb.group(2)!) << 8) |
        int.parse(rgb.group(3)!);
  return null;
}

/// Reads simple SVG shapes into normalised vector paths. Only plain shapes
/// (rect, circle, ellipse, polygon, polyline, path with M/L/H/V/C/Q/Z) are
/// read; scripts, links, styles, images and anything else are ignored, so
/// nothing in the file can run or load.
List<(String, int)> importSvg(String svg) {
  final clean = svg
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(
        RegExp(r'<foreignObject[\s\S]*?</foreignObject>', caseSensitive: false),
        '',
      );
  final vb = RegExp(r'viewBox\s*=\s*"([^"]+)"')
      .firstMatch(clean)
      ?.group(1)
      ?.trim()
      .split(RegExp(r'[\s,]+'))
      .map(double.tryParse)
      .toList();
  double vx = 0, vy = 0, vw = 100, vh = 100;
  if (vb != null && vb.length == 4 && vb.every((x) => x != null)) {
    vx = vb[0]!;
    vy = vb[1]!;
    vw = vb[2]!;
    vh = vb[3]!;
  } else {
    final w = double.tryParse(
      RegExp(r'\swidth\s*=\s*"([\d.]+)').firstMatch(clean)?.group(1) ?? '',
    );
    final h = double.tryParse(
      RegExp(r'\sheight\s*=\s*"([\d.]+)').firstMatch(clean)?.group(1) ?? '',
    );
    if (w != null && h != null) {
      vw = w;
      vh = h;
    }
  }
  String fx(double x) => ((x - vx) / vw).toStringAsFixed(4);
  String fy(double y) => ((y - vy) / vh).toStringAsFixed(4);
  final out = <(String, int)>[];
  for (final m in RegExp(
    r'<(rect|circle|ellipse|polygon|polyline|path)\b([^>]*)/?>',
    caseSensitive: false,
  ).allMatches(clean)) {
    final tag = m.group(1)!.toLowerCase();
    final attrs = m.group(2)!;
    String? a(String k) =>
        RegExp('(?:^|\\s)$k\\s*=\\s*"([^"]*)"').firstMatch(attrs)?.group(1);
    double d(String k) => double.tryParse(a(k) ?? '') ?? 0;
    final style = a('style') ?? '';
    final fill =
        _svgColor(
          RegExp(r'fill\s*:\s*([^;]+)').firstMatch(style)?.group(1) ??
              a('fill'),
        ) ??
        0xFF000000;
    if (fill == 0) continue;
    String path;
    switch (tag) {
      case 'rect':
        final x = d('x'), y = d('y'), w = d('width'), h = d('height');
        path =
            'M${fx(x)} ${fy(y)} L${fx(x + w)} ${fy(y)} L${fx(x + w)} ${fy(y + h)} L${fx(x)} ${fy(y + h)} Z';
      case 'circle' || 'ellipse':
        final cx = d('cx'), cy = d('cy');
        final rx = tag == 'circle' ? d('r') : d('rx'),
            ry = tag == 'circle' ? d('r') : d('ry');
        const k = 0.5523;
        path =
            'M${fx(cx - rx)} ${fy(cy)} '
            'C${fx(cx - rx)} ${fy(cy - ry * k)} ${fx(cx - rx * k)} ${fy(cy - ry)} ${fx(cx)} ${fy(cy - ry)} '
            'C${fx(cx + rx * k)} ${fy(cy - ry)} ${fx(cx + rx)} ${fy(cy - ry * k)} ${fx(cx + rx)} ${fy(cy)} '
            'C${fx(cx + rx)} ${fy(cy + ry * k)} ${fx(cx + rx * k)} ${fy(cy + ry)} ${fx(cx)} ${fy(cy + ry)} '
            'C${fx(cx - rx * k)} ${fy(cy + ry)} ${fx(cx - rx)} ${fy(cy + ry * k)} ${fx(cx - rx)} ${fy(cy)} Z';
      case 'polygon' || 'polyline':
        final nums = RegExp(r'-?\d*\.?\d+')
            .allMatches(a('points') ?? '')
            .map((x) => double.parse(x.group(0)!))
            .toList();
        if (nums.length < 4) continue;
        final b = StringBuffer('M${fx(nums[0])} ${fy(nums[1])}');
        for (var i = 2; i + 1 < nums.length; i += 2) {
          b.write(' L${fx(nums[i])} ${fy(nums[i + 1])}');
        }
        if (tag == 'polygon') b.write(' Z');
        path = b.toString();
      default:
        final converted = _normalizeSvgPath(a('d') ?? '', fx, fy);
        if (converted == null) continue;
        path = converted;
    }
    out.add((path, fill));
    if (out.length >= 400) break;
  }
  return out;
}

/// Converts an SVG path (absolute or relative M L H V C Q Z) to normalised
/// absolute commands. Unsupported commands (arcs…) become straight lines.
String? _normalizeSvgPath(
  String d,
  String Function(double) fx,
  String Function(double) fy,
) {
  final tokens = RegExp(
    r'[MmLlHhVvCcSsQqTtAaZz]|-?\d*\.?\d+(?:e-?\d+)?',
  ).allMatches(d).map((m) => m.group(0)!).toList();
  if (tokens.isEmpty) return null;
  final b = StringBuffer();
  var i = 0;
  var cmd = 'M';
  var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
  bool isCmd(String t) => RegExp('[A-Za-z]').hasMatch(t);
  double n() =>
      i < tokens.length && !isCmd(tokens[i]) ? double.parse(tokens[i++]) : 0;
  var guard = 0;
  while (i < tokens.length && guard++ < 20000) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        x = n() + (rel ? x : 0);
        y = n() + (rel ? y : 0);
        sx = x;
        sy = y;
        b.write('M${fx(x)} ${fy(y)} ');
        cmd = rel ? 'l' : 'L';
      case 'L' || 'T':
        x = n() + (rel ? x : 0);
        y = n() + (rel ? y : 0);
        b.write('L${fx(x)} ${fy(y)} ');
      case 'H':
        x = n() + (rel ? x : 0);
        b.write('L${fx(x)} ${fy(y)} ');
      case 'V':
        y = n() + (rel ? y : 0);
        b.write('L${fx(x)} ${fy(y)} ');
      case 'C':
        final a = [
          for (var k = 0; k < 6; k++) n() + (rel ? (k.isEven ? x : y) : 0),
        ];
        b.write(
          'C${fx(a[0])} ${fy(a[1])} ${fx(a[2])} ${fy(a[3])} ${fx(a[4])} ${fy(a[5])} ',
        );
        x = a[4];
        y = a[5];
      case 'S' || 'Q':
        final a = [
          for (var k = 0; k < 4; k++) n() + (rel ? (k.isEven ? x : y) : 0),
        ];
        b.write('Q${fx(a[0])} ${fy(a[1])} ${fx(a[2])} ${fy(a[3])} ');
        x = a[2];
        y = a[3];
      case 'A':
        for (var k = 0; k < 5; k++) {
          n();
        }
        x = n() + (rel ? x : 0);
        y = n() + (rel ? y : 0);
        b.write('L${fx(x)} ${fy(y)} ');
      case 'Z':
        b.write('Z ');
        x = sx;
        y = sy;
        if (i < tokens.length && !isCmd(tokens[i])) i++;
      default:
        i++;
    }
  }
  final s = b.toString().trim();
  return s.isEmpty ? null : s;
}

String _hex(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Writes the flag as SVG. Image layers are left out (noted in a comment).
String exportFlagSvg(FlagDesign d, {String title = 'Flag'}) {
  const w = 600.0;
  final h = w / d.aspect;
  final s = Size(w, h);
  final b = StringBuffer(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w ${h.toStringAsFixed(1)}" width="$w" height="${h.toStringAsFixed(1)}">\n<title>${title.replaceAll('<', '').replaceAll('&', 'and')}</title>\n',
  );
  b.write(
    '<clipPath id="o"><path d="${_pathToSvg(flagOutline(s, d.shape))}"/></clipPath>\n<g clip-path="url(#o)">\n<rect width="$w" height="${h.toStringAsFixed(1)}" fill="#ffffff"/>\n',
  );
  for (final l in d.layers.where((l) => l.visible)) {
    final op = l.opacity < 1
        ? ' opacity="${l.opacity.toStringAsFixed(2)}"'
        : '';
    if (l.kind == 'image') {
      b.write('<!-- image layer not included in SVG -->\n');
      continue;
    }
    if (l.kind == 'symbol' || l.kind == 'text') {
      final t = l.text.replaceAll('&', '&amp;').replaceAll('<', '&lt;');
      b.write(
        '<text x="${(l.x * w).toStringAsFixed(1)}" y="${(l.y * h).toStringAsFixed(1)}" font-size="${(l.w * h).toStringAsFixed(1)}" text-anchor="middle" dominant-baseline="central" fill="${_hex(l.color)}"$op${l.kind == 'text' ? ' font-weight="800"' : ''} transform="rotate(${l.rotation} ${(l.x * w).toStringAsFixed(1)} ${(l.y * h).toStringAsFixed(1)})">$t</text>\n',
      );
      continue;
    }
    if (l.kind == 'draw' && l.points.length > 1) {
      final pts = l.points
          .map(
            (p) =>
                '${(p.dx * w).toStringAsFixed(1)},${(p.dy * h).toStringAsFixed(1)}',
          )
          .join(' ');
      b.write(
        '<polyline points="$pts" fill="none" stroke="${_hex(l.color)}" stroke-width="${math.max(1, l.stroke * h).toStringAsFixed(1)}" stroke-linecap="round" stroke-linejoin="round"$op/>\n',
      );
      continue;
    }
    // Everything else: record the painted geometry as filled paths.
    for (final (path, color) in _layerPaths(l, s)) {
      b.write(
        '<path d="${_pathToSvg(path)}" fill="${_hex(color)}"${path.fillType == PathFillType.evenOdd ? ' fill-rule="evenodd"' : ''}$op/>\n',
      );
    }
  }
  b.write('</g>\n</svg>\n');
  return b.toString();
}

List<(Path, int)> _layerPaths(FlagLayer l, Size s) {
  final w = s.width, h = s.height;
  final cols = l.colors.isEmpty ? const [0xFF000000] : l.colors;
  int col(int i) => cols[i % cols.length];
  Path r(Rect x) => Path()..addRect(x);
  switch (l.kind) {
    case 'fill':
      return [(r(Offset.zero & s), l.color)];
    case 'layout':
      switch (l.layout) {
        case 'hstripes':
          return [
            for (var i = 0; i < cols.length; i++)
              (
                r(
                  Rect.fromLTWH(
                    0,
                    h * i / cols.length,
                    w,
                    h / cols.length + 0.5,
                  ),
                ),
                cols[i],
              ),
          ];
        case 'vstripes':
          return [
            for (var i = 0; i < cols.length; i++)
              (
                r(
                  Rect.fromLTWH(
                    w * i / cols.length,
                    0,
                    w / cols.length + 0.5,
                    h,
                  ),
                ),
                cols[i],
              ),
          ];
        case 'diagonal':
          return [
            (r(Offset.zero & s), col(0)),
            (
              Path()
                ..moveTo(w, 0)
                ..lineTo(w, h)
                ..lineTo(0, h)
                ..close(),
              col(1),
            ),
          ];
        case 'nordic' || 'cross':
          final t = h * 0.2;
          final vx = l.layout == 'nordic' ? w * 0.3 : w / 2 - t / 2;
          return [
            (r(Offset.zero & s), col(0)),
            (r(Rect.fromLTWH(vx, 0, t, h)), col(1)),
            (r(Rect.fromLTWH(0, h / 2 - t / 2, w, t)), col(1)),
          ];
        case 'saltire':
          final t = h * 0.09;
          return [
            (r(Offset.zero & s), col(0)),
            (
              Path()
                ..moveTo(0, -t)
                ..lineTo(w, h - t)
                ..lineTo(w, h + t)
                ..lineTo(0, t)
                ..close(),
              col(1),
            ),
            (
              Path()
                ..moveTo(w, -t)
                ..lineTo(0, h - t)
                ..lineTo(0, h + t)
                ..lineTo(w, t)
                ..close(),
              col(1),
            ),
          ];
        case 'canton':
          return [(r(Rect.fromLTWH(0, 0, w * 0.4, h * 0.54)), col(0))];
        case 'chevron':
          return [
            (
              Path()
                ..moveTo(0, 0)
                ..lineTo(w * 0.42, h / 2)
                ..lineTo(0, h)
                ..close(),
              col(0),
            ),
          ];
        case 'triangle':
          return [
            (
              Path()
                ..moveTo(0, 0)
                ..lineTo(w * 0.3, h / 2)
                ..lineTo(0, h)
                ..close(),
              col(0),
            ),
          ];
        case 'border':
          final t = h * 0.1;
          return [
            (
              Path()
                ..fillType = PathFillType.evenOdd
                ..addRect(Offset.zero & s)
                ..addRect(Rect.fromLTWH(t, t, w - 2 * t, h - 2 * t)),
              col(0),
            ),
          ];
        case 'quartered':
          return [
            (r(Rect.fromLTWH(0, 0, w / 2, h / 2)), col(0)),
            (r(Rect.fromLTWH(w / 2, 0, w / 2, h / 2)), col(1)),
            (r(Rect.fromLTWH(0, h / 2, w / 2, h / 2)), col(1)),
            (r(Rect.fromLTWH(w / 2, h / 2, w / 2, h / 2)), col(0)),
          ];
        case 'circle':
          return [
            (
              Path()..addOval(
                Rect.fromCircle(center: Offset(w / 2, h / 2), radius: h * 0.3),
              ),
              col(0),
            ),
          ];
      }
      return const [];
    case 'shape':
      final rect = Rect.fromCenter(
        center: Offset(l.x * w, l.y * h),
        width: l.w * w,
        height: l.h * h,
      );
      final m = Matrix4.identity()
        ..translateByDouble(rect.center.dx, rect.center.dy, 0, 1)
        ..rotateZ(l.rotation * math.pi / 180)
        ..translateByDouble(-rect.center.dx, -rect.center.dy, 0, 1);
      return [(shapePath(l.shape, rect).transform(m.storage), l.color)];
    case 'vector':
      final box = Size(l.w * w, l.h * h);
      final off = Offset(l.x * w - box.width / 2, l.y * h - box.height / 2);
      return [
        for (final (d, c) in l.paths)
          (parseNormalizedPath(d, box).shift(off), c),
      ];
  }
  return const [];
}

String _pathToSvg(Path p) {
  final b = StringBuffer();
  for (final m in p.computeMetrics()) {
    final len = m.length;
    final steps = math.max(8, (len / 3).ceil()).clamp(8, 600);
    for (var i = 0; i <= steps; i++) {
      final t = m.getTangentForOffset(len * i / steps);
      if (t == null) continue;
      b.write(
        '${i == 0 ? 'M' : 'L'}${t.position.dx.toStringAsFixed(1)} ${t.position.dy.toStringAsFixed(1)} ',
      );
    }
    if (m.isClosed) b.write('Z ');
  }
  return b.toString().trim();
}
