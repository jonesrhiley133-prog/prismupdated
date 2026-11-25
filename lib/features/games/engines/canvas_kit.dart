import 'dart:math' as math;

import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// One freehand stroke. Points are stored normalised (0–1) so drawings
/// scale with the screen and save compactly.
class Stroke {
  Stroke({
    required this.points,
    required this.color,
    required this.width,
    this.eraser = false,
    this.author,
    this.layer = 0,
    this.brush = 'pen',
  });
  final List<Offset> points;
  final int color;
  final double width;
  final bool eraser;
  final String? author;
  final int layer;

  /// 'pen' or 'rake' (three parallel lines, for the zen garden).
  final String brush;

  Map<String, Object?> toJson() => {
    'p': [
      for (final o in points) ...[(o.dx * 1000).round(), (o.dy * 1000).round()],
    ],
    'c': color,
    'w': width,
    if (eraser) 'e': 1,
    if (author != null) 'a': author,
    if (layer != 0) 'l': layer,
    if (brush != 'pen') 'b': brush,
  };

  static Stroke fromJson(Map m) {
    final raw = [
      for (final v in (m['p'] as List? ?? const []))
        (v as num).toDouble() / 1000,
    ];
    return Stroke(
      points: [
        for (var i = 0; i + 1 < raw.length; i += 2) Offset(raw[i], raw[i + 1]),
      ],
      color: (m['c'] as num?)?.toInt() ?? 0xFF000000,
      width: (m['w'] as num?)?.toDouble() ?? 4,
      eraser: m['e'] == 1,
      author: m['a'] as String?,
      layer: (m['l'] as num?)?.toInt() ?? 0,
      brush: m['b'] as String? ?? 'pen',
    );
  }
}

/// State for a drawing: strokes, undo/redo and the current tool.
class DrawingController extends ChangeNotifier {
  DrawingController({
    List<Stroke>? strokes,
    this.symmetry = 1,
    this.author,
    Color? color,
  }) : strokes = strokes ?? [],
       color = color ?? const Color(0xFF3B3B58);
  final List<Stroke> strokes;
  final List<Stroke> _redo = [];
  int symmetry;
  String? author;
  Color color;
  double width = 5;
  bool eraser = false;
  int layer = 0;
  String brush = 'pen';
  Set<int> hiddenLayers = {};
  Stroke? _live;

  bool get canUndo => strokes.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void start(Offset p) {
    _live = Stroke(
      points: [p],
      color: color.toARGB32(),
      width: width,
      eraser: eraser,
      author: author,
      layer: layer,
      brush: brush,
    );
    strokes.add(_live!);
    _redo.clear();
    notifyListeners();
  }

  void extend(Offset p) {
    _live?.points.add(p);
    notifyListeners();
  }

  void end() => _live = null;

  void undo() {
    if (strokes.isEmpty) return;
    _redo.add(strokes.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    strokes.add(_redo.removeLast());
    notifyListeners();
  }

  void clear() {
    _redo
      ..clear()
      ..addAll(strokes.reversed);
    strokes.clear();
    notifyListeners();
  }

  void set({
    Color? color,
    double? width,
    bool? eraser,
    int? layer,
    String? brush,
  }) {
    if (color != null) {
      this.color = color;
      this.eraser = false;
    }
    if (width != null) this.width = width;
    if (eraser != null) this.eraser = eraser;
    if (layer != null) this.layer = layer;
    if (brush != null) this.brush = brush;
    notifyListeners();
  }

  void toggleLayer(int l) {
    hiddenLayers.contains(l) ? hiddenLayers.remove(l) : hiddenLayers.add(l);
    notifyListeners();
  }

  List<Object?> toJson() => [for (final s in strokes) s.toJson()];
  static List<Stroke> parse(Object? raw) => [
    for (final m in (raw as List?) ?? const [])
      if (m is Map) Stroke.fromJson(m),
  ];
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.c, this.background) : super(repaint: c);
  final DrawingController c;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final layers = c.strokes.map((s) => s.layer).toSet().toList()..sort();
    for (final l in layers) {
      if (c.hiddenLayers.contains(l)) continue;
      canvas.saveLayer(Offset.zero & size, Paint());
      for (final s in c.strokes.where((s) => s.layer == l)) {
        _draw(canvas, size, s);
      }
      canvas.restore();
    }
  }

  void _draw(Canvas canvas, Size size, Stroke s) {
    final paint = Paint()
      ..color = Color(s.color)
      ..strokeWidth = s.width * size.width / 360
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (s.eraser) paint.blendMode = BlendMode.clear;
    final n = c.symmetry;
    final center = size.center(Offset.zero);
    for (var k = 0; k < n; k++) {
      canvas.save();
      if (n > 1) {
        canvas.translate(center.dx, center.dy);
        canvas.rotate(2 * math.pi * k / n);
        canvas.translate(-center.dx, -center.dy);
      }
      final offsets = s.brush == 'rake' ? const [-1.0, 0.0, 1.0] : const [0.0];
      for (final off in offsets) {
        final path = Path();
        for (var i = 0; i < s.points.length; i++) {
          final p = Offset(
            s.points[i].dx * size.width,
            s.points[i].dy * size.height,
          );
          var q = p;
          if (off != 0 && s.points.length > 1) {
            final a = s.points[math.max(0, i - 1)],
                b = s.points[math.min(s.points.length - 1, i + 1)];
            final d = Offset(b.dx - a.dx, b.dy - a.dy);
            final len = d.distance == 0 ? 1 : d.distance;
            q =
                p +
                Offset(-d.dy / len, d.dx / len) *
                    (off * paint.strokeWidth * 1.6);
          }
          i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
        }
        if (s.points.length == 1) {
          canvas.drawCircle(
            Offset(s.points[0].dx * size.width, s.points[0].dy * size.height),
            paint.strokeWidth / 2,
            paint..style = PaintingStyle.fill,
          );
        } else {
          canvas.drawPath(path, paint);
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) =>
      old.background != background;
}

/// A square drawing surface.
class DrawingBoard extends StatelessWidget {
  const DrawingBoard({
    super.key,
    required this.controller,
    this.background,
    this.onChanged,
    this.child,
    this.aspectRatio = 1,
  });
  final DrawingController controller;
  final Color? background;
  final VoidCallback? onChanged;

  /// Painted on top (e.g. stickers that sit above the sand).
  final Widget? child;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? Colors.white;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: prismCorners(context, 14),
        child: LayoutBuilder(
          builder: (context, box) {
            Offset norm(Offset p) => Offset(
              (p.dx / box.maxWidth).clamp(0, 1),
              (p.dy / box.maxHeight).clamp(0, 1),
            );
            return Semantics(
              label: tr(context, 'Drawing canvas', 'Lienzo de dibujo'),
              child: GestureDetector(
                onPanStart: (d) => controller.start(norm(d.localPosition)),
                onPanUpdate: (d) => controller.extend(norm(d.localPosition)),
                onPanEnd: (_) {
                  controller.end();
                  onChanged?.call();
                },
                onTapDown: (d) {
                  controller.start(norm(d.localPosition));
                  controller.end();
                  onChanged?.call();
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _StrokePainter(controller, bg),
                        ),
                      ),
                    ),
                    if (child != null) Positioned.fill(child: child!),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Soft palette that works on white canvases.
const drawingPalette = <Color>[
  Color(0xFF3B3B58),
  Color(0xFFE76F51),
  Color(0xFFF4A261),
  Color(0xFFE9C46A),
  Color(0xFF8AB17D),
  Color(0xFF2A9D8F),
  Color(0xFF5B8DEF),
  Color(0xFF9B72CF),
  Color(0xFFE5989B),
  Color(0xFF8D6E63),
  Color(0xFFFFFFFF),
  Color(0xFF111111),
];

/// Colour swatches, brush size, eraser, undo/redo, clear.
class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({
    super.key,
    required this.controller,
    this.palette = drawingPalette,
    this.onChanged,
    this.showEraser = true,
    this.layers = 0,
  });
  final DrawingController controller;
  final List<Color> palette;
  final VoidCallback? onChanged;
  final bool showEraser;

  /// When >1, shows layer buttons (with hide/show).
  final int layers;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final c in palette)
                Semantics(
                  button: true,
                  selected: !controller.eraser && controller.color == c,
                  label: '#${c.toARGB32().toRadixString(16).substring(2)}',
                  child: GestureDetector(
                    onTap: () => controller.set(color: c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: prismRound(context),
                        border: Border.all(
                          color: !controller.eraser && controller.color == c
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: !controller.eraser && controller.color == c
                              ? 3
                              : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(PhosphorIcons.pencilSimple(), size: 18),
              Expanded(
                child: Slider(
                  value: controller.width,
                  min: 1,
                  max: 30,
                  onChanged: (v) => controller.set(width: v),
                  label: controller.width.round().toString(),
                ),
              ),
              if (showEraser)
                PrismIconButton(
                  icon: PhosphorIcons.eraser(PhosphorIconsStyle.fill),
                  tooltip: tr(context, 'Eraser', 'Borrador'),
                  color: controller.eraser ? scheme.primary : null,
                  onPressed: () => controller.set(eraser: !controller.eraser),
                ),
              PrismIconButton(
                icon: PhosphorIcons.arrowCounterClockwise(),
                tooltip: tr(context, 'Undo', 'Deshacer'),
                onPressed: controller.canUndo
                    ? () {
                        controller.undo();
                        onChanged?.call();
                      }
                    : () {},
              ),
              PrismIconButton(
                icon: PhosphorIcons.arrowClockwise(),
                tooltip: tr(context, 'Redo', 'Rehacer'),
                onPressed: controller.canRedo
                    ? () {
                        controller.redo();
                        onChanged?.call();
                      }
                    : () {},
              ),
              PrismIconButton(
                icon: PhosphorIcons.trash(),
                tooltip: tr(context, 'Clear', 'Borrar todo'),
                onPressed: () {
                  controller.clear();
                  onChanged?.call();
                },
              ),
            ],
          ),
          if (layers > 1)
            Wrap(
              spacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  tr(context, 'Layer', 'Capa'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                for (var l = 0; l < layers; l++)
                  PrismChip(
                    label:
                        '${l + 1}${controller.hiddenLayers.contains(l) ? ' (hidden)' : ''}',
                    selected: controller.layer == l,
                    onTap: () => controller.layer == l
                        ? controller.toggleLayer(l)
                        : controller.set(layer: l),
                  ),
                Text(
                  tr(
                    context,
                    'Tap the active layer to hide it',
                    'Toca la capa activa para ocultarla',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stickers: draggable, resizable emoji on a scene
// ---------------------------------------------------------------------------

class Sticker {
  Sticker(this.emoji, this.x, this.y, {this.size = 0.12, this.author});
  final String emoji;
  double x, y, size;
  final String? author;

  Map<String, Object?> toJson() => {
    'e': emoji,
    'x': (x * 1000).round(),
    'y': (y * 1000).round(),
    's': (size * 1000).round(),
    if (author != null) 'a': author,
  };
  static Sticker fromJson(Map m) => Sticker(
    '${m['e']}',
    ((m['x'] as num?) ?? 500) / 1000,
    ((m['y'] as num?) ?? 500) / 1000,
    size: ((m['s'] as num?) ?? 120) / 1000,
    author: m['a'] as String?,
  );
  static List<Sticker> parse(Object? raw) => [
    for (final m in (raw as List?) ?? const [])
      if (m is Map) Sticker.fromJson(m),
  ];
}

/// Lays out stickers; tap to select, drag to move, pinch or buttons to resize.
class StickerLayer extends StatelessWidget {
  const StickerLayer({
    super.key,
    required this.stickers,
    required this.selected,
    required this.onSelect,
    required this.onChanged,
  });
  final List<Sticker> stickers;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          children: [
            for (var i = 0; i < stickers.length; i++)
              Builder(
                builder: (context) {
                  final s = stickers[i];
                  final px = s.size * box.maxWidth;
                  return Positioned(
                    left: s.x * box.maxWidth - px / 2,
                    top: s.y * box.maxHeight - px / 2,
                    width: px,
                    height: px,
                    child: Semantics(
                      label: s.emoji,
                      selected: selected == i,
                      child: GestureDetector(
                        onTap: () => onSelect(selected == i ? null : i),
                        onScaleStart: (_) => onSelect(i),
                        onScaleUpdate: (d) {
                          s.x = (s.x + d.focalPointDelta.dx / box.maxWidth)
                              .clamp(0.0, 1.0);
                          s.y = (s.y + d.focalPointDelta.dy / box.maxHeight)
                              .clamp(0.0, 1.0);
                          if (d.scale != 1)
                            s.size = (s.size * (1 + (d.scale - 1) * 0.06))
                                .clamp(0.05, 0.5);
                          (context as Element).markNeedsBuild();
                          onSelect(i);
                        },
                        onScaleEnd: (_) => onChanged(),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: selected == i
                                ? Border.all(color: scheme.primary, width: 2)
                                : null,
                            borderRadius: prismCorners(context, 8),
                          ),
                          child: FittedBox(child: Text(s.emoji)),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// Size/remove controls for the selected sticker.
class StickerControls extends StatelessWidget {
  const StickerControls({
    super.key,
    required this.stickers,
    required this.selected,
    required this.onChanged,
    required this.onDeselect,
  });
  final List<Sticker> stickers;
  final int? selected;
  final VoidCallback onChanged;
  final VoidCallback onDeselect;
  @override
  Widget build(BuildContext context) {
    final i = selected;
    if (i == null || i >= stickers.length) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PrismIconButton(
          icon: PhosphorIcons.minus(),
          tooltip: tr(context, 'Smaller', 'Más pequeño'),
          onPressed: () {
            stickers[i].size = math.max(0.05, stickers[i].size * 0.85);
            onChanged();
          },
        ),
        PrismIconButton(
          icon: PhosphorIcons.plus(),
          tooltip: tr(context, 'Bigger', 'Más grande'),
          onPressed: () {
            stickers[i].size = math.min(0.5, stickers[i].size * 1.18);
            onChanged();
          },
        ),
        PrismIconButton(
          icon: PhosphorIcons.stack(),
          tooltip: tr(context, 'Bring to front', 'Traer al frente'),
          onPressed: () {
            stickers.add(stickers.removeAt(i));
            onDeselect();
            onChanged();
          },
        ),
        PrismIconButton(
          icon: PhosphorIcons.trash(),
          tooltip: tr(context, 'Remove', 'Quitar'),
          onPressed: () {
            stickers.removeAt(i);
            onDeselect();
            onChanged();
          },
        ),
      ],
    );
  }
}

/// A horizontal tray of emoji to add.
class StickerTray extends StatelessWidget {
  const StickerTray({super.key, required this.emoji, required this.onPick});
  final List<String> emoji;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    alignment: WrapAlignment.center,
    children: [
      for (final e in emoji)
        Semantics(
          button: true,
          label: tr(context, 'Add $e', 'Añadir $e'),
          child: InkWell(
            borderRadius: prismCorners(context, 10),
            onTap: () => onPick(e),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(e, style: const TextStyle(fontSize: 26)),
            ),
          ),
        ),
    ],
  );
}

/// Helper so engines can keep a seeded random around.
math.Random seededRandom(GameSession s, int salt) => s.rng(salt);
