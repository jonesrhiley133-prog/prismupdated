import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_plurality/features/scrapbook/scrap_canvas.dart';
import 'package:prism_plurality/features/scrapbook/scrap_editor_core.dart';
import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';

/// The interactive layer for a [ScrapEditorController]: select, multi-select,
/// drag, pinch, resize and rotate handles, alignment guides. It fills the
/// space it's given (a page, or one side of a cover).
class ScrapEditSurface extends StatefulWidget {
  const ScrapEditSurface({
    super.key,
    required this.controller,
    this.filter,
    this.onEdit,
    this.resolve,
    this.widthDivisor = 1,
  });
  final ScrapEditorController controller;

  /// Only elements this accepts are shown and editable.
  final bool Function(ScrapElement e)? filter;
  final ValueChanged<ScrapElement>? onEdit;

  /// Swaps placeholders (like the book title) before drawing.
  final ScrapElement Function(ScrapElement e)? resolve;

  /// 2 for a two-page spread, so text and decorations keep single-page size.
  final double widthDivisor;

  @override
  State<ScrapEditSurface> createState() => _ScrapEditSurfaceState();
}

class _ScrapEditSurfaceState extends State<ScrapEditSurface> {
  List<double> _v = const [], _h = const [];
  Map<String, Offset> _start = {};
  Rect _startBounds = Rect.zero;
  Offset _startFocal = Offset.zero;
  double _startRot = 0, _startW = 0, _startH = 0;
  ScrapImageFit _startFit = const ScrapImageFit();
  bool _moved = false;

  ScrapEditorController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_on);
  }

  @override
  void didUpdateWidget(ScrapEditSurface old) {
    super.didUpdateWidget(old);
    if (old.controller != c) {
      old.controller.removeListener(_on);
      c.addListener(_on);
    }
  }

  @override
  void dispose() {
    c.removeListener(_on);
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  void _tap(ScrapElement e) => c.select(e.id, additive: c.multi);

  void _begin(ScrapElement e, ScaleStartDetails d, Size size) {
    if (!c.selected.contains(e.id)) c.select(e.id, additive: c.multi);
    _moved = false;
    _startFocal = d.focalPoint;
    _start = {for (final s in c.selection) s.id: Offset(s.x, s.y)};
    final b = c.selectionBounds ?? Rect.zero;
    _startBounds = Rect.fromLTWH(
      b.left * size.width,
      b.top * size.height,
      b.width * size.width,
      b.height * size.height,
    );
    _startRot = e.rot;
    _startW = e.w;
    _startH = e.h;
    _startFit = ScrapImageFit.fromJson(e.opts['fit']);
  }

  void _update(ScrapElement e, ScaleUpdateDetails d, Size size) {
    if (e.locked) return;
    _moved = true;
    if (c.adjustId == e.id) {
      // Moving the picture inside its frame, not the frame itself.
      final z = (_startFit.zoom * d.scale).clamp(1.0, 6.0);
      final room = math.max(8.0, e.w * size.width * (z - 1) / 2);
      final roomY = math.max(8.0, e.h * size.height * (z - 1) / 2);
      final dx = d.focalPoint.dx - _startFocal.dx,
          dy = d.focalPoint.dy - _startFocal.dy;
      e.setOpt(
        'fit',
        ScrapImageFit(
          zoom: z,
          dx: _startFit.dx - dx / room,
          dy: _startFit.dy - dy / roomY,
        ).clamped().toJson(),
      );
      setState(() {});
      return;
    }
    final dx = d.focalPoint.dx - _startFocal.dx,
        dy = d.focalPoint.dy - _startFocal.dy;
    var sx = 0.0, sy = 0.0;
    _v = const [];
    _h = const [];
    if (d.pointerCount == 1 && c.snapEnabled) {
      final others = [
        for (final o in c.els)
          if (!c.selected.contains(o.id) && (widget.filter?.call(o) ?? true))
            Rect.fromLTWH(
              o.x * size.width,
              o.y * size.height,
              o.w * size.width,
              o.h * size.height,
            ),
      ];
      final r = snapMove(_startBounds.shift(Offset(dx, dy)), others, size);
      sx = r.dx;
      sy = r.dy;
      _v = r.vLines;
      _h = r.hLines;
    }
    for (final s in c.selection) {
      if (s.locked) continue;
      final o = _start[s.id];
      if (o == null) continue;
      s.x = o.dx + (dx + sx) / size.width;
      s.y = o.dy + (dy + sy) / size.height;
    }
    if (d.pointerCount > 1 && c.selected.length == 1) {
      e.rot = _startRot + d.rotation;
      e.w = (_startW * d.scale).clamp(0.04, 1.6);
      e.h = (_startH * d.scale).clamp(0.03, 1.6);
    }
    setState(() {});
  }

  void _end() {
    _v = const [];
    _h = const [];
    if (_moved) {
      c.commit();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final W = size.width, H = size.height;
        final visible = [
          for (final e in c.els)
            if (widget.filter?.call(e) ?? true) e,
        ]..sort((a, b) => a.z.compareTo(b.z));
        final sel = c.selection
            .where((e) => widget.filter?.call(e) ?? true)
            .toList();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => c.select(null),
              ),
            ),
            for (final raw in visible)
              Builder(
                builder: (_) {
                  final e = raw;
                  final shown = widget.resolve?.call(e) ?? e;
                  final isSel = c.selected.contains(e.id);
                  return Positioned(
                    left: e.x * W,
                    top: e.y * H,
                    width: math.max(e.w * W, 8),
                    height: math.max(e.h * H, 8),
                    child: Transform.rotate(
                      angle: e.rot,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _tap(e),
                        onDoubleTap: widget.onEdit == null
                            ? null
                            : () => widget.onEdit!(e),
                        onScaleStart: (d) => _begin(e, d, size),
                        onScaleUpdate: (d) => _update(e, d, size),
                        onScaleEnd: (_) => _end(),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: ScrapElementView(
                                element: shown,
                                pageWidth: W,
                              ),
                            ),
                            if (isSel)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: primary,
                                        width: sel.length > 1 ? 1.5 : 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (e.locked && isSel)
                              Positioned(
                                left: 2,
                                top: 2,
                                child: Icon(
                                  Icons.lock,
                                  size: 14,
                                  color: primary,
                                ),
                              ),
                            if (isSel && sel.length == 1 && !e.locked) ...[
                              Positioned(
                                right: -14,
                                bottom: -14,
                                child: _Handle(
                                  icon: Icons.open_in_full,
                                  tip: 'Resize',
                                  color: primary,
                                  onDrag: (d) {
                                    e.w = (e.w + d.dx / W).clamp(0.04, 1.6);
                                    e.h = (e.h + d.dy / H).clamp(0.03, 1.6);
                                    setState(() {});
                                  },
                                  onEnd: c.commit,
                                ),
                              ),
                              Positioned(
                                right: -14,
                                top: -14,
                                child: _Handle(
                                  icon: Icons.rotate_right,
                                  tip: 'Rotate',
                                  color: primary,
                                  onDrag: (d) {
                                    e.rot += d.dx / 60;
                                    setState(() {});
                                  },
                                  onEnd: c.commit,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (sel.length > 1)
              Positioned.fromRect(
                rect: _bounds(sel, size).inflate(3),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: primary.withValues(alpha: 0.7),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            if (_v.isNotEmpty || _h.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _GuidePainter(_v, _h, primary)),
                ),
              ),
          ],
        );
      },
    );
  }

  static Rect _bounds(List<ScrapElement> l, Size s) {
    var r = Rect.fromLTWH(
      l.first.x * s.width,
      l.first.y * s.height,
      l.first.w * s.width,
      l.first.h * s.height,
    );
    for (final e in l.skip(1)) {
      r = r.expandToInclude(
        Rect.fromLTWH(
          e.x * s.width,
          e.y * s.height,
          e.w * s.width,
          e.h * s.height,
        ),
      );
    }
    return r;
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.v, this.h, this.color);
  final List<double> v, h;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final x in v) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (final y in h) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter o) =>
      o.v != v || o.h != h || o.color != color;
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.icon,
    required this.tip,
    required this.color,
    required this.onDrag,
    required this.onEnd,
  });
  final IconData icon;
  final String tip;
  final Color color;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) => Semantics(
    label: tip,
    child: GestureDetector(
      onPanUpdate: (d) => onDrag(d.delta),
      onPanEnd: (_) => onEnd(),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    ),
  );
}
