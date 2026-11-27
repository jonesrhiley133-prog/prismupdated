import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:prism_plurality/features/scrapbook/scrap_props.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

enum ScrapBrush { pen, marker, highlighter, handwriting, dotted, spray, eraser }

String brushName(BuildContext context, ScrapBrush b) => switch (b) {
  ScrapBrush.pen => tr(context, 'Pen', 'Bolígrafo'),
  ScrapBrush.marker => tr(context, 'Marker', 'Rotulador'),
  ScrapBrush.highlighter => tr(context, 'Highlighter', 'Resaltador'),
  ScrapBrush.handwriting => tr(context, 'Handwriting', 'Caligrafía'),
  ScrapBrush.dotted => tr(context, 'Dotted', 'Punteado'),
  ScrapBrush.spray => tr(context, 'Spray', 'Spray'),
  ScrapBrush.eraser => tr(context, 'Eraser', 'Borrador'),
};

class ScrapStroke {
  ScrapStroke(this.points, this.color, this.width, this.brush);
  final List<Offset> points;
  final Color color;
  final double width;
  final ScrapBrush brush;
}

/// Paints strokes; the eraser really erases (it draws inside its own layer).
void paintScrapStrokes(Canvas canvas, Size size, List<ScrapStroke> strokes) {
  canvas.saveLayer(Offset.zero & size, Paint());
  for (final s in strokes) {
    if (s.points.isEmpty) continue;
    final p = Paint()
      ..color = s.color
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    switch (s.brush) {
      case ScrapBrush.eraser:
        p
          ..blendMode = BlendMode.clear
          ..strokeWidth = s.width * 2.5;
        _smooth(canvas, s.points, p);
      case ScrapBrush.highlighter:
        p
          ..color = s.color.withValues(alpha: 0.35)
          ..strokeWidth = s.width * 3
          ..strokeCap = StrokeCap.square;
        _smooth(canvas, s.points, p);
      case ScrapBrush.marker:
        p..strokeWidth = s.width * 1.6;
        _smooth(canvas, s.points, p);
      case ScrapBrush.handwriting:
        // A broad nib: strokes are thick across the nib angle and thin along it.
        for (var i = 1; i < s.points.length; i++) {
          final a = s.points[i - 1], b = s.points[i];
          final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
          final k = 0.35 + 0.9 * (math.sin(ang + math.pi / 4)).abs();
          canvas.drawLine(a, b, p..strokeWidth = s.width * 1.4 * k);
        }
        if (s.points.length == 1)
          canvas.drawCircle(
            s.points.first,
            s.width * 0.7,
            p..style = PaintingStyle.fill,
          );
      case ScrapBrush.dotted:
        var carry = 0.0;
        final gap = s.width * 2.2;
        for (var i = 1; i < s.points.length; i++) {
          final a = s.points[i - 1], b = s.points[i];
          final d = (b - a).distance;
          var t = carry;
          while (t < d) {
            canvas.drawCircle(
              Offset.lerp(a, b, t / math.max(d, 0.001))!,
              s.width * 0.6,
              p..style = PaintingStyle.fill,
            );
            t += gap;
          }
          carry = t - d;
        }
        if (s.points.length == 1)
          canvas.drawCircle(
            s.points.first,
            s.width * 0.6,
            p..style = PaintingStyle.fill,
          );
      case ScrapBrush.spray:
        final r = math.Random(s.points.length + s.points.first.dx.toInt());
        for (final pt in s.points) {
          for (var i = 0; i < 6; i++) {
            final a = r.nextDouble() * math.pi * 2,
                d = r.nextDouble() * s.width * 2.4;
            canvas.drawCircle(
              pt + Offset(math.cos(a), math.sin(a)) * d,
              0.9,
              p..style = PaintingStyle.fill,
            );
          }
        }
      case ScrapBrush.pen:
        if (s.points.length == 1) {
          canvas.drawCircle(
            s.points.first,
            s.width / 2,
            p..style = PaintingStyle.fill,
          );
        } else {
          _smooth(canvas, s.points, p);
        }
    }
  }
  canvas.restore();
}

void _smooth(Canvas canvas, List<Offset> pts, Paint p) {
  if (pts.length == 1) {
    canvas.drawCircle(
      pts.first,
      p.strokeWidth / 2,
      Paint()
        ..color = p.color
        ..blendMode = p.blendMode,
    );
    return;
  }
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = Offset.lerp(pts[i], pts[i + 1], 0.5)!;
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
  canvas.drawPath(path, p);
}

/// Finger drawing: seven brushes, any colour, undo and redo. Returns a
/// transparent PNG.
class ScrapDrawingPad extends StatefulWidget {
  const ScrapDrawingPad({super.key, this.initialBrush = ScrapBrush.pen});
  final ScrapBrush initialBrush;

  static Future<List<int>?> show(
    BuildContext context, {
    ScrapBrush brush = ScrapBrush.pen,
  }) => PrismSheet.showFullScreen<List<int>>(
    context: context,
    builder: (ctx, scroll) => ScrapDrawingPad(initialBrush: brush),
  );

  @override
  State<ScrapDrawingPad> createState() => _ScrapDrawingPadState();
}

class _ScrapDrawingPadState extends State<ScrapDrawingPad> {
  final List<ScrapStroke> _strokes = [], _redo = [];
  late ScrapBrush _brush = widget.initialBrush;
  Color _color = Colors.black;
  double _width = 4;
  Size _size = const Size(300, 300);
  bool _paper = true;

  Future<void> _done() async {
    final rec = ui.PictureRecorder();
    paintScrapStrokes(Canvas(rec), _size, _strokes);
    final img = await rec.endRecording().toImage(
      _size.width.ceil() * 2,
      _size.height.ceil() * 2,
    );
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (mounted) Navigator.of(context).pop(bytes?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(
            title: tr(context, 'Draw', 'Dibujar'),
            trailing: IconButton(
              tooltip: tr(context, 'Done', 'Listo'),
              icon: const Icon(Icons.check),
              onPressed: _strokes.isEmpty ? null : _done,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final b in ScrapBrush.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                    child: PrismChip(
                      label: brushName(context, b),
                      selected: _brush == b,
                      onTap: () => setState(() => _brush = b),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ScrapColorField(
              label: tr(context, 'Colour', 'Color'),
              value: _color.toARGB32(),
              onChanged: (c) => setState(() => _color = Color(c)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ScrapSlider(
                    label: tr(context, 'Size', 'Tamaño'),
                    value: _width,
                    min: 1,
                    max: 24,
                    onChanged: (v) => setState(() => _width = v),
                    onEnd: () {},
                    display: _width.round().toString(),
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Undo', 'Deshacer'),
                  icon: const Icon(Icons.undo),
                  onPressed: _strokes.isEmpty
                      ? null
                      : () => setState(() => _redo.add(_strokes.removeLast())),
                ),
                IconButton(
                  tooltip: tr(context, 'Redo', 'Rehacer'),
                  icon: const Icon(Icons.redo),
                  onPressed: _redo.isEmpty
                      ? null
                      : () => setState(() => _strokes.add(_redo.removeLast())),
                ),
                IconButton(
                  tooltip: tr(context, 'Clear', 'Borrar todo'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _strokes.isEmpty
                      ? null
                      : () => setState(() {
                          _strokes.clear();
                          _redo.clear();
                        }),
                ),
                IconButton(
                  tooltip: tr(context, 'Show paper', 'Mostrar papel'),
                  icon: Icon(_paper ? Icons.grid_on : Icons.grid_off),
                  onPressed: () => setState(() => _paper = !_paper),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, c) {
                  _size = c.biggest;
                  return ClipRRect(
                    borderRadius: prismCorners(context, 12),
                    child: GestureDetector(
                      onPanStart: (d) => setState(() {
                        _redo.clear();
                        _strokes.add(
                          ScrapStroke(
                            [d.localPosition],
                            _color,
                            _width,
                            _brush,
                          ),
                        );
                      }),
                      onPanUpdate: (d) => setState(
                        () => _strokes.last.points.add(d.localPosition),
                      ),
                      child: CustomPaint(
                        painter: _PadPainter(_strokes, _paper),
                        size: Size.infinite,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.strokes, this.paper);
  final List<ScrapStroke> strokes;
  final bool paper;
  @override
  void paint(Canvas canvas, Size size) {
    if (paper) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFFDFBF6),
      );
      final g = Paint()..color = const Color(0x14000000);
      for (var x = 24.0; x < size.width; x += 24) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), g);
      }
      for (var y = 24.0; y < size.height; y += 24) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
      }
    }
    paintScrapStrokes(canvas, size, strokes);
  }

  @override
  bool shouldRepaint(_PadPainter o) => true;
}
