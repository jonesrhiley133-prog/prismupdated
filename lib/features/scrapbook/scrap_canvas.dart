import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:prism_plurality/features/scrapbook/scrap_sticker_picker.dart';
import 'package:prism_plurality/features/scrapbook/scrap_video.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Paints a page background.
class ScrapBackground extends CustomPainter {
  ScrapBackground(this.color, this.pattern, this.ink);
  final Color color;
  final String pattern;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final p = Paint()
      ..color = ink.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final step = size.width / 20;
    switch (pattern) {
      case 'dots':
        for (double x = step; x < size.width; x += step) {
          for (double y = step; y < size.height; y += step) {
            canvas.drawCircle(Offset(x, y), 1.2, p);
          }
        }
      case 'grid':
        for (double x = step; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (double y = step; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      case 'lines':
        for (double y = step * 2; y < size.height; y += step) {
          canvas.drawLine(Offset(step, y), Offset(size.width - step, y), p);
        }
        canvas.drawLine(
          Offset(step * 2.4, 0),
          Offset(step * 2.4, size.height),
          Paint()..color = const Color(0x55E74C3C),
        );
      case 'paper':
        final rnd = math.Random(3);
        for (var i = 0; i < 300; i++) {
          canvas.drawCircle(
            Offset(
              rnd.nextDouble() * size.width,
              rnd.nextDouble() * size.height,
            ),
            0.6,
            p,
          );
        }
      case 'kraft':
        final rnd = math.Random(9);
        final k = Paint()..color = const Color(0x22000000);
        for (var i = 0; i < 500; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              rnd.nextDouble() * size.width,
              rnd.nextDouble() * size.height,
              1.5,
              0.6,
            ),
            k,
          );
        }
      case 'stars':
        final rnd = math.Random(5);
        for (var i = 0; i < 40; i++) {
          canvas.drawCircle(
            Offset(
              rnd.nextDouble() * size.width,
              rnd.nextDouble() * size.height,
            ),
            rnd.nextDouble() * 1.8 + 0.4,
            Paint()..color = ink.withValues(alpha: 0.3),
          );
        }
    }
  }

  @override
  bool shouldRepaint(ScrapBackground old) =>
      old.color != color || old.pattern != pattern || old.ink != ink;
}

/// A page rendered at any size; editable when [onChanged] is given.
class ScrapPageCanvas extends StatefulWidget {
  const ScrapPageCanvas({
    super.key,
    required this.elements,
    required this.background,
    required this.pattern,
    this.onChanged,
    this.selectedId,
    this.onSelect,
    this.onEditElement,
  });

  final List<ScrapElement> elements;
  final Color background;
  final String pattern;
  final VoidCallback? onChanged;
  final String? selectedId;
  final ValueChanged<String?>? onSelect;
  final ValueChanged<ScrapElement>? onEditElement;

  @override
  State<ScrapPageCanvas> createState() => _ScrapPageCanvasState();
}

class _ScrapPageCanvasState extends State<ScrapPageCanvas> {
  double _startRot = 0;
  double _startW = 0, _startH = 0;

  bool get _editable => widget.onChanged != null;

  @override
  Widget build(BuildContext context) {
    final ink =
        ThemeData.estimateBrightnessForColor(widget.background) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
    return AspectRatio(
      aspectRatio: scrapPageAspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final W = c.maxWidth, H = c.maxHeight;
          final sorted = [...widget.elements]
            ..sort((a, b) => a.z.compareTo(b.z));
          return ClipRRect(
            borderRadius: prismCorners(context, W * 0.02),
            child: GestureDetector(
              onTap: _editable ? () => widget.onSelect?.call(null) : null,
              child: CustomPaint(
                painter: ScrapBackground(
                  widget.background,
                  widget.pattern,
                  ink,
                ),
                child: Stack(
                  children: [
                    for (final e in sorted)
                      Positioned(
                        left: e.x * W,
                        top: e.y * H,
                        width: math.max(e.w * W, 8),
                        height: math.max(e.h * H, 8),
                        child: Transform.rotate(
                          angle: e.rot,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _editable
                                ? () => widget.onSelect?.call(e.id)
                                : null,
                            onDoubleTap: _editable
                                ? () => widget.onEditElement?.call(e)
                                : null,
                            onScaleStart: !_editable
                                ? null
                                : (d) {
                                    widget.onSelect?.call(e.id);
                                    _startRot = e.rot;
                                    _startW = e.w;
                                    _startH = e.h;
                                  },
                            onScaleUpdate: !_editable
                                ? null
                                : (d) => setState(() {
                                    e.x = (e.x + d.focalPointDelta.dx / W)
                                        .clamp(-e.w * 0.8, 1 - e.w * 0.2);
                                    e.y = (e.y + d.focalPointDelta.dy / H)
                                        .clamp(-e.h * 0.8, 1 - e.h * 0.2);
                                    if (d.pointerCount > 1) {
                                      e.rot = _startRot + d.rotation;
                                      e.w = (_startW * d.scale).clamp(
                                        0.05,
                                        1.5,
                                      );
                                      e.h = (_startH * d.scale).clamp(
                                        0.03,
                                        1.5,
                                      );
                                    }
                                  }),
                            onScaleEnd: !_editable
                                ? null
                                : (_) => widget.onChanged!(),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: ScrapElementView(
                                    element: e,
                                    pageWidth: W,
                                  ),
                                ),
                                if (_editable && widget.selectedId == e.id) ...[
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Resize handle.
                                  Positioned(
                                    right: -14,
                                    bottom: -14,
                                    child: _Handle(
                                      icon: PhosphorIcons.arrowsOutSimple(),
                                      onDrag: (dd) => setState(() {
                                        e.w = (e.w + dd.dx / W).clamp(
                                          0.05,
                                          1.5,
                                        );
                                        e.h = (e.h + dd.dy / H).clamp(
                                          0.03,
                                          1.5,
                                        );
                                      }),
                                      onEnd: widget.onChanged!,
                                    ),
                                  ),
                                  // Rotate handle.
                                  Positioned(
                                    right: -14,
                                    top: -14,
                                    child: _Handle(
                                      icon: PhosphorIcons.arrowClockwise(),
                                      onDrag: (dd) =>
                                          setState(() => e.rot += dd.dx / 60),
                                      onEnd: widget.onChanged!,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.icon,
    required this.onDrag,
    required this.onEnd,
  });
  final IconData icon;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onPanUpdate: (d) => onDrag(d.delta),
    onPanEnd: (_) => onEnd(),
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: prismRound(context),
      ),
      child: Icon(
        icon,
        size: 14,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    ),
  );
}

/// Draws a single element.
class ScrapElementView extends StatelessWidget {
  const ScrapElementView({
    super.key,
    required this.element,
    required this.pageWidth,
  });
  final ScrapElement element;
  final double pageWidth;

  @override
  Widget build(BuildContext context) {
    final e = element;
    final scale = pageWidth / 360;
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 14 * scale * e.size,
      color: e.color == null ? Colors.black87 : Color(e.color!),
    );
    Widget mediaOrPlaceholder() => e.media == null
        ? ColoredBox(
            color: Colors.black.withValues(alpha: 0.06),
            child: Center(
              child: Icon(
                PhosphorIcons.imageSquare(),
                color: Colors.black26,
                size: 28 * scale,
              ),
            ),
          )
        : (e.media!.startsWith('audio:')
              ? Center(child: AudioClip(id: e.media!))
              : PrismMediaView(id: e.media!));
    final content = switch (e.type) {
      ScrapType.video =>
        e.media == null
            ? mediaOrPlaceholder()
            : ScrapVideoView(key: ValueKey('vid-${e.id}'), element: e),
      ScrapType.photo || ScrapType.drawing => mediaOrPlaceholder(),
      ScrapType.audio => Center(
        child: e.media == null
            ? Icon(PhosphorIcons.microphone())
            : AudioClip(id: e.media!, label: e.text),
      ),
      ScrapType.text => Align(
        alignment: Alignment.topLeft,
        child: Text(
          (e.text?.isEmpty ?? true)
              ? tr(
                  context,
                  'Double-tap to write…',
                  'Doble toque para escribir…',
                )
              : e.text!,
          style: scrapFont(e.font, base).copyWith(
            color: (e.text?.isEmpty ?? true)
                ? base.color!.withValues(alpha: 0.4)
                : null,
          ),
          overflow: TextOverflow.fade,
        ),
      ),
      ScrapType.note => Container(
        padding: EdgeInsets.all(8 * scale),
        decoration: BoxDecoration(
          color: Color(e.color ?? 0xFFFFF3A3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6 * scale,
              offset: Offset(2 * scale, 3 * scale),
            ),
          ],
        ),
        child: Text(
          (e.text?.isEmpty ?? true) ? tr(context, 'Note…', 'Nota…') : e.text!,
          style: scrapFont(
            e.font ?? 'hand',
            base.copyWith(color: Colors.black87),
          ),
          overflow: TextOverflow.fade,
        ),
      ),
      ScrapType.sticker => ScrapStickerContent(
        id: e.text ?? '⭐',
        media: e.media,
        tint: e.color == null ? null : Color(e.color!),
      ),
      ScrapType.tape => Opacity(
        opacity: 0.75,
        child: CustomPaint(painter: _TapePainter(Color(e.color ?? 0xFFF8B6C9))),
      ),
      ScrapType.shape => CustomPaint(
        painter: _ShapePainter(e.text ?? 'heart', Color(e.color ?? 0xFFE74C3C)),
      ),
    };
    final framed = switch (e.frame) {
      ScrapFrame.none => content,
      ScrapFrame.polaroid => Container(
        padding: EdgeInsets.fromLTRB(
          6 * scale,
          6 * scale,
          6 * scale,
          22 * scale,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6 * scale,
              offset: Offset(0, 3 * scale),
            ),
          ],
        ),
        child: content,
      ),
      ScrapFrame.round => PrismClipRound(child: content),
      ScrapFrame.shadow => DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10 * scale,
              offset: Offset(0, 4 * scale),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: prismCorners(context, 6 * scale),
          child: content,
        ),
      ),
      ScrapFrame.border => Container(
        padding: EdgeInsets.all(3 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black26),
        ),
        child: content,
      ),
      ScrapFrame.tape => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: content),
          Positioned(
            top: -8 * scale,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: -0.08,
                child: SizedBox(
                  width: 60 * scale,
                  height: 18 * scale,
                  child: Opacity(
                    opacity: 0.8,
                    child: CustomPaint(
                      painter: _TapePainter(const Color(0xFFF7E3A1)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    };
    return e.opacity < 1
        ? Opacity(opacity: e.opacity.clamp(0.0, 1.0), child: framed)
        : framed;
  }
}

class _TapePainter extends CustomPainter {
  _TapePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const teeth = 6;
    path.moveTo(0, 0);
    for (var i = 0; i <= teeth; i++) {
      path.lineTo(0 + (i.isEven ? 0 : 3), size.height * i / teeth);
    }
    path.lineTo(size.width, size.height);
    for (var i = teeth; i >= 0; i--) {
      path.lineTo(size.width - (i.isEven ? 0 : 3), size.height * i / teeth);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 3;
    for (double x = -size.height; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(_TapePainter old) => old.color != color;
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.color);
  final String shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width, h = size.height;
    switch (shape) {
      case 'circle':
        canvas.drawOval(Offset.zero & size, p);
      case 'star':
        final path = Path();
        for (var k = 0; k < 10; k++) {
          final r = (k.isEven ? 0.5 : 0.22) * math.min(w, h);
          final a = -math.pi / 2 + k * math.pi / 5;
          final pt = Offset(w / 2 + math.cos(a) * r, h / 2 + math.sin(a) * r);
          k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path..close(), p);
      case 'banner':
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(w, 0)
            ..lineTo(w * 0.92, h / 2)
            ..lineTo(w, h)
            ..lineTo(0, h)
            ..lineTo(w * 0.08, h / 2)
            ..close(),
          p,
        );
      default: // heart
        final path = Path()
          ..moveTo(w / 2, h * 0.9)
          ..cubicTo(-w * 0.2, h * 0.45, w * 0.2, -h * 0.1, w / 2, h * 0.25)
          ..cubicTo(w * 0.8, -h * 0.1, w * 1.2, h * 0.45, w / 2, h * 0.9);
        canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) =>
      old.shape != shape || old.color != color;
}

/// Finger drawing pad; returns PNG bytes.
class DrawingPad extends StatefulWidget {
  const DrawingPad({super.key});

  static Future<List<int>?> show(BuildContext context) =>
      PrismSheet.showFullScreen<List<int>>(
        context: context,
        builder: (ctx, scroll) => const DrawingPad(),
      );

  @override
  State<DrawingPad> createState() => _DrawingPadState();
}

class _DrawingPadState extends State<DrawingPad> {
  final List<(List<Offset>, Color, double)> _strokes = [];
  Color _color = Colors.black;
  double _width = 4;
  Size _size = const Size(300, 300);

  Future<void> _done() async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    _paint(canvas, _strokes);
    final img = await rec.endRecording().toImage(
      _size.width.ceil(),
      _size.height.ceil(),
    );
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (mounted) Navigator.of(context).pop(bytes?.buffer.asUint8List());
  }

  static void _paint(
    Canvas canvas,
    List<(List<Offset>, Color, double)> strokes,
  ) {
    for (final (pts, color, w) in strokes) {
      final p = Paint()
        ..color = color
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, w / 2, p..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final pt in pts.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, p);
    }
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
              icon: Icon(AppIcons.check),
              onPressed: _strokes.isEmpty ? null : _done,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ColorChoiceRow(
                    value: _color.toARGB32(),
                    colors: const [
                      0xFF000000,
                      0xFFFFFFFF,
                      0xFFE74C3C,
                      0xFFF39C12,
                      0xFFF1C40F,
                      0xFF2ECC71,
                      0xFF3498DB,
                      0xFF9B59B6,
                      0xFFEB459E,
                    ],
                    onChanged: (c) => setState(() => _color = Color(c)),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final w in const [2.0, 4.0, 8.0, 16.0])
                IconButton(
                  tooltip: '${w.round()}',
                  isSelected: _width == w,
                  icon: Container(
                    width: w + 4,
                    height: w + 4,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: prismRound(context),
                    ),
                  ),
                  onPressed: () => setState(() => _width = w),
                ),
              IconButton(
                tooltip: tr(context, 'Undo', 'Deshacer'),
                icon: Icon(PhosphorIcons.arrowCounterClockwise()),
                onPressed: _strokes.isEmpty
                    ? null
                    : () => setState(_strokes.removeLast),
              ),
              IconButton(
                tooltip: tr(context, 'Clear', 'Borrar'),
                icon: Icon(AppIcons.deleteOutline),
                onPressed: () => setState(_strokes.clear),
              ),
            ],
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
                      onPanStart: (d) => setState(
                        () => _strokes.add(([d.localPosition], _color, _width)),
                      ),
                      onPanUpdate: (d) =>
                          setState(() => _strokes.last.$1.add(d.localPosition)),
                      child: CustomPaint(
                        painter: _StrokesPainter(_strokes),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.02),
                          width: double.infinity,
                          height: double.infinity,
                        ),
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

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.strokes);
  final List<(List<Offset>, Color, double)> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFDFBF6),
    );
    _DrawingPadState._paint(canvas, strokes);
  }

  @override
  bool shouldRepaint(_StrokesPainter old) => true;
}
