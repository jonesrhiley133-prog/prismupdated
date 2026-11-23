import 'dart:math' as math;

import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/features/games/engines/canvas_kit.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

// ---------------------------------------------------------------------------
// Free drawing with optional symmetry (Mandala) or rake brush (Zen garden)
// ---------------------------------------------------------------------------

class DrawGame extends StatefulWidget {
  const DrawGame({super.key, required this.session, this.symmetry = 1, this.background, this.prompt, this.zen = false});
  final GameSession session;
  final int symmetry;
  final Color? background;
  final String? prompt;

  /// Sand + rake brush + stones.
  final bool zen;
  @override
  State<DrawGame> createState() => _DrawGameState();
}

class _DrawGameState extends State<DrawGame> {
  late final DrawingController _c = DrawingController(
    strokes: DrawingController.parse(widget.session.saved?['strokes']),
    symmetry: widget.symmetry,
    author: widget.session.player,
    color: widget.zen ? const Color(0xFFC9B48A) : null,
  )..brush = widget.zen ? 'rake' : 'pen';
  late final List<Sticker> _stones = Sticker.parse(widget.session.saved?['stickers']);
  int? _sel;
  late int _sym = widget.symmetry;

  void _save() => widget.session.save({'strokes': _c.toJson(), 'stickers': [for (final s in _stones) s.toJson()]});

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sand = widget.zen ? const Color(0xFFEADBB8) : (widget.background ?? Colors.white);
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.prompt != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: GamePrompt(widget.prompt!, size: 16)),
          DrawingBoard(
            controller: _c,
            background: sand,
            onChanged: _save,
            child: widget.zen ? StickerLayer(stickers: _stones, selected: _sel, onSelect: (i) => setState(() => _sel = i), onChanged: () => setState(_save)) : null,
          ),
          const SizedBox(height: 8),
          if (widget.zen) ...[
            StickerTray(emoji: const ['🪨', '🌿', '🎋', '🌸', '🍂', '🕯️', '🐚', '🪷', '⛩️', '🌱'], onPick: (e) => setState(() {
              _stones.add(Sticker(e, 0.5, 0.5, size: 0.14, author: widget.session.player));
              _sel = _stones.length - 1;
              _save();
            })),
            StickerControls(stickers: _stones, selected: _sel, onChanged: () => setState(_save), onDeselect: () => setState(() => _sel = null)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              PrismIconButton(icon: PhosphorIcons.arrowCounterClockwise(), tooltip: tr(context, 'Undo rake', 'Deshacer rastrillo'), onPressed: () {
                _c.undo();
                _save();
              }),
              PrismButton(label: tr(context, 'Smooth the sand', 'Alisar la arena'), onPressed: () {
                _c.clear();
                _save();
              }),
            ]),
          ] else ...[
            DrawingToolbar(controller: _c, onChanged: _save),
            if (widget.symmetry > 1)
              Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
                for (final n in const [4, 6, 8, 12]) PrismChip(label: tr(context, '$n-fold', '$n ejes'), selected: _sym == n, onTap: () => setState(() => _c.symmetry = _sym = n)),
              ]),
          ],
          GameActions(children: [
            PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Finish', 'Terminar'), onPressed: () => widget.session.finish(GameOutcome(summary: tr(context, '${_c.strokes.length} strokes', '${_c.strokes.length} trazos'), details: {'strokes': _c.toJson()}))),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Digital Coloring Book: tap-to-fill regions
// ---------------------------------------------------------------------------

typedef _Shape = Path Function(Size s);

class ColoringPicture {
  const ColoringPicture(this.name, this.regions);
  final String name;
  final List<_Shape> regions;
}

Path _circle(double x, double y, double r, Size s) => Path()..addOval(Rect.fromCircle(center: Offset(x * s.width, y * s.height), radius: r * s.width));
Path _rect(double l, double t, double r, double b, Size s) => Path()..addRect(Rect.fromLTRB(l * s.width, t * s.height, r * s.width, b * s.height));
Path _poly(List<double> pts, Size s) {
  final p = Path()..moveTo(pts[0] * s.width, pts[1] * s.height);
  for (var i = 2; i + 1 < pts.length; i += 2) {
    p.lineTo(pts[i] * s.width, pts[i + 1] * s.height);
  }
  return p..close();
}

final coloringPictures = <ColoringPicture>[
  ColoringPicture('Flower', [
    (s) => _rect(0, 0, 1, 1, s),
    (s) => _rect(0.48, 0.55, 0.52, 0.98, s),
    (s) => Path()..addOval(Rect.fromLTWH(0.52 * s.width, 0.7 * s.height, 0.22 * s.width, 0.08 * s.height)),
    for (var k = 0; k < 6; k++) (s) => _circle(0.5 + 0.17 * math.cos(k * math.pi / 3), 0.38 + 0.17 * math.sin(k * math.pi / 3), 0.11, s),
    (s) => _circle(0.5, 0.38, 0.1, s),
  ]),
  ColoringPicture('House', [
    (s) => _rect(0, 0, 1, 1, s),
    (s) => _rect(0, 0.85, 1, 1, s),
    (s) => _rect(0.2, 0.45, 0.8, 0.85, s),
    (s) => _poly([0.12, 0.47, 0.5, 0.15, 0.88, 0.47], s),
    (s) => _rect(0.44, 0.62, 0.56, 0.85, s),
    (s) => _rect(0.26, 0.52, 0.38, 0.64, s),
    (s) => _rect(0.62, 0.52, 0.74, 0.64, s),
    (s) => _circle(0.85, 0.15, 0.08, s),
  ]),
  ColoringPicture('Fish', [
    (s) => _rect(0, 0, 1, 1, s),
    (s) => Path()..addOval(Rect.fromLTRB(0.18 * s.width, 0.3 * s.height, 0.72 * s.width, 0.7 * s.height)),
    (s) => _poly([0.7, 0.5, 0.92, 0.3, 0.92, 0.7], s),
    (s) => _poly([0.38, 0.32, 0.5, 0.15, 0.58, 0.33], s),
    (s) => _circle(0.3, 0.46, 0.035, s),
    for (var k = 0; k < 3; k++) (s) => _circle(0.15 + k * 0.08, 0.2 - k * 0.05, 0.025, s),
    (s) => _rect(0, 0.9, 1, 1, s),
  ]),
  ColoringPicture('Mug', [
    (s) => _rect(0, 0, 1, 1, s),
    (s) => _rect(0.25, 0.35, 0.65, 0.85, s),
    (s) => Path()
      ..addOval(Rect.fromLTRB(0.6 * s.width, 0.45 * s.height, 0.82 * s.width, 0.72 * s.height))
      ..addOval(Rect.fromLTRB(0.65 * s.width, 0.51 * s.height, 0.77 * s.width, 0.66 * s.height))
      ..fillType = PathFillType.evenOdd,
    (s) => Path()..addOval(Rect.fromLTRB(0.15 * s.width, 0.82 * s.height, 0.75 * s.width, 0.92 * s.height)),
    (s) => _circle(0.45, 0.6, 0.08, s),
    for (var k = 0; k < 3; k++) (s) => Path()..addOval(Rect.fromLTWH((0.32 + k * 0.1) * s.width, 0.12 * s.height, 0.05 * s.width, 0.16 * s.height)),
  ]),
  ColoringPicture('Mountains', [
    (s) => _rect(0, 0, 1, 1, s),
    (s) => _circle(0.78, 0.2, 0.09, s),
    (s) => _poly([0, 0.85, 0.32, 0.3, 0.62, 0.85], s),
    (s) => _poly([0.38, 0.85, 0.68, 0.4, 1, 0.85], s),
    (s) => _poly([0.25, 0.43, 0.32, 0.3, 0.39, 0.43], s),
    (s) => _rect(0, 0.85, 1, 1, s),
    (s) => Path()..addOval(Rect.fromLTWH(0.08 * s.width, 0.12 * s.height, 0.25 * s.width, 0.08 * s.height)),
  ]),
  ColoringPicture('Butterfly', [
    (s) => _rect(0, 0, 1, 1, s),
    (s) => Path()..addOval(Rect.fromLTRB(0.12 * s.width, 0.18 * s.height, 0.48 * s.width, 0.52 * s.height)),
    (s) => Path()..addOval(Rect.fromLTRB(0.52 * s.width, 0.18 * s.height, 0.88 * s.width, 0.52 * s.height)),
    (s) => Path()..addOval(Rect.fromLTRB(0.2 * s.width, 0.5 * s.height, 0.48 * s.width, 0.8 * s.height)),
    (s) => Path()..addOval(Rect.fromLTRB(0.52 * s.width, 0.5 * s.height, 0.8 * s.width, 0.8 * s.height)),
    (s) => _circle(0.3, 0.35, 0.06, s),
    (s) => _circle(0.7, 0.35, 0.06, s),
    (s) => Path()..addOval(Rect.fromLTRB(0.46 * s.width, 0.2 * s.height, 0.54 * s.width, 0.82 * s.height)),
  ]),
];

class _ColoringPainter extends CustomPainter {
  _ColoringPainter(this.pic, this.fills, this.line);
  final ColoringPicture pic;
  final Map<int, int> fills;
  final Color line;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < pic.regions.length; i++) {
      final p = pic.regions[i](size);
      canvas.drawPath(p, Paint()..color = Color(fills[i] ?? 0xFFFFFFFF));
      canvas.drawPath(p, Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _ColoringPainter old) => true;
}

class ColoringGame extends StatefulWidget {
  const ColoringGame({super.key, required this.session});
  final GameSession session;
  @override
  State<ColoringGame> createState() => _ColoringGameState();
}

class _ColoringGameState extends State<ColoringGame> {
  late int _pic = (widget.session.saved?['pic'] as num?)?.toInt() ?? 0;
  late final Map<int, int> _fills = {for (final e in ((widget.session.saved?['fills'] as Map?) ?? const {}).entries) int.parse('${e.key}'): (e.value as num).toInt()};
  Color _color = drawingPalette[1];

  void _save() => widget.session.save({'pic': _pic, 'fills': {for (final e in _fills.entries) '${e.key}': e.value}});

  @override
  Widget build(BuildContext context) {
    final pic = coloringPictures[_pic];
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < coloringPictures.length; i++) PrismChip(label: coloringPictures[i].name, selected: _pic == i, onTap: () => setState(() {
              _pic = i;
              _fills.clear();
              _save();
            })),
          ]),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);
              return Semantics(
                label: tr(context, 'Coloring picture: ${pic.name}. Tap a shape to fill it.', 'Dibujo para colorear: ${pic.name}. Toca una forma para rellenarla.'),
                child: GestureDetector(
                  onTapDown: (d) {
                    for (var i = pic.regions.length - 1; i >= 0; i--) {
                      if (pic.regions[i](size).contains(d.localPosition)) {
                        setState(() => _fills[i] = _color.toARGB32());
                        _save();
                        return;
                      }
                    }
                  },
                  child: ClipRRect(borderRadius: BorderRadius.circular(12), child: CustomPaint(size: size, painter: _ColoringPainter(pic, _fills, const Color(0xFF3B3B58)))),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
            for (final c in [...drawingPalette, const Color(0xFFB5E2FA), const Color(0xFFF7D6E0), const Color(0xFFD8F3DC), const Color(0xFFFFF1C1)])
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(width: 30, height: 30, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _color == c ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant, width: _color == c ? 3 : 1))),
              ),
          ]),
          GameActions(children: [
            PrismButton(label: tr(context, 'Start over', 'Empezar de nuevo'), onPressed: () => setState(() {
              _fills.clear();
              _save();
            })),
            PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Finish', 'Terminar'), onPressed: () => widget.session.finish(GameOutcome(summary: tr(context, 'Colored the ${pic.name}', 'Coloreaste: ${pic.name}')))),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pixel Art Studio
// ---------------------------------------------------------------------------

class PixelArtGame extends StatefulWidget {
  const PixelArtGame({super.key, required this.session, this.size = 16});
  final GameSession session;
  final int size;
  @override
  State<PixelArtGame> createState() => _PixelArtGameState();
}

class _PixelArtGameState extends State<PixelArtGame> {
  late final int n = widget.size;
  late final List<int> _px = [for (final v in (widget.session.saved?['px'] as List?) ?? List.filled(n * n, 0)) (v as num).toInt()];
  final List<List<int>> _undo = [];
  Color _color = drawingPalette[0];
  bool _erase = false;

  void _paint(Offset p, double cell) {
    final c = (p.dx / cell).floor(), r = (p.dy / cell).floor();
    if (c < 0 || r < 0 || c >= n || r >= n) return;
    final v = _erase ? 0 : _color.toARGB32();
    if (_px[r * n + c] == v) return;
    setState(() => _px[r * n + c] = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, box) {
              final cell = box.maxWidth / n;
              return GestureDetector(
                onPanStart: (d) {
                  _undo.add([..._px]);
                  _paint(d.localPosition, cell);
                },
                onPanUpdate: (d) => _paint(d.localPosition, cell),
                onPanEnd: (_) => widget.session.save({'px': _px}),
                onTapDown: (d) {
                  _undo.add([..._px]);
                  _paint(d.localPosition, cell);
                  widget.session.save({'px': _px});
                },
                child: CustomPaint(
                  size: Size.square(box.maxWidth),
                  painter: _PixelPainter(_px, n, scheme.outlineVariant),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
            for (final c in drawingPalette)
              GestureDetector(
                onTap: () => setState(() {
                  _color = c;
                  _erase = false;
                }),
                child: Container(width: 28, height: 28, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6), border: Border.all(color: !_erase && _color == c ? scheme.primary : scheme.outlineVariant, width: !_erase && _color == c ? 3 : 1))),
              ),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            PrismIconButton(icon: PhosphorIcons.eraser(), tooltip: tr(context, 'Eraser', 'Borrador'), color: _erase ? scheme.primary : null, onPressed: () => setState(() => _erase = !_erase)),
            PrismIconButton(icon: PhosphorIcons.arrowCounterClockwise(), tooltip: tr(context, 'Undo', 'Deshacer'), onPressed: () {
              if (_undo.isEmpty) return;
              setState(() => _px.setAll(0, _undo.removeLast()));
              widget.session.save({'px': _px});
            }),
            PrismIconButton(icon: PhosphorIcons.trash(), tooltip: tr(context, 'Clear', 'Borrar'), onPressed: () {
              _undo.add([..._px]);
              setState(() => _px.fillRange(0, _px.length, 0));
              widget.session.save({'px': _px});
            }),
          ]),
          GameActions(children: [
            PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Finish', 'Terminar'), onPressed: () => widget.session.finish(GameOutcome(summary: tr(context, '${_px.where((v) => v != 0).length} pixels placed', '${_px.where((v) => v != 0).length} píxeles'), details: {'px': _px}))),
          ]),
        ],
      ),
    );
  }
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.px, this.n, this.grid);
  final List<int> px;
  final int n;
  final Color grid;
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / n;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    for (var i = 0; i < px.length; i++) {
      if (px[i] == 0) continue;
      canvas.drawRect(Rect.fromLTWH((i % n) * cell, (i ~/ n) * cell, cell, cell), Paint()..color = Color(px[i]));
    }
    final g = Paint()
      ..color = grid.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (var k = 0; k <= n; k++) {
      canvas.drawLine(Offset(k * cell, 0), Offset(k * cell, size.height), g);
      canvas.drawLine(Offset(0, k * cell), Offset(size.width, k * cell), g);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelPainter old) => true;
}

// ---------------------------------------------------------------------------
// Sticker scenes: aquarium, bouquet, tea set, room, terrarium, bakery…
// ---------------------------------------------------------------------------

class SceneConfig {
  const SceneConfig({required this.backgrounds, required this.stickers, this.base, this.title = ''});

  /// Gradient pairs (top, bottom).
  final List<(Color, Color)> backgrounds;
  final List<String> stickers;

  /// Optional fixed decoration drawn behind stickers (e.g. a vase, a jar).
  final String? base;
  final String title;
}

class StickerSceneGame extends StatefulWidget {
  const StickerSceneGame({super.key, required this.session, required this.config});
  final GameSession session;
  final SceneConfig config;
  @override
  State<StickerSceneGame> createState() => _StickerSceneGameState();
}

class _StickerSceneGameState extends State<StickerSceneGame> {
  late final List<Sticker> _stickers = Sticker.parse(widget.session.saved?['stickers']);
  late int _bg = (widget.session.saved?['bg'] as num?)?.toInt() ?? 0;
  int? _sel;
  final _rng = math.Random();

  void _save() => widget.session.save({'stickers': [for (final s in _stickers) s.toJson()], 'bg': _bg});

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = widget.config.backgrounds[_bg % widget.config.backgrounds.length];
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom])),
                child: Stack(children: [
                  if (widget.config.base != null) Positioned.fill(child: Align(alignment: const Alignment(0, 0.7), child: FractionallySizedBox(widthFactor: 0.55, heightFactor: 0.55, child: FittedBox(child: Opacity(opacity: 0.9, child: Text(widget.config.base!)))))),
                  Positioned.fill(child: GestureDetector(onTap: () => setState(() => _sel = null))),
                  Positioned.fill(child: StickerLayer(stickers: _stickers, selected: _sel, onSelect: (i) => setState(() => _sel = i), onChanged: () => setState(_save))),
                ]),
              ),
            ),
          ),
          StickerControls(stickers: _stickers, selected: _sel, onChanged: () => setState(_save), onDeselect: () => setState(() => _sel = null)),
          if (widget.config.backgrounds.length > 1)
            Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
              for (var i = 0; i < widget.config.backgrounds.length; i++)
                GestureDetector(
                  onTap: () => setState(() {
                    _bg = i;
                    _save();
                  }),
                  child: Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [widget.config.backgrounds[i].$1, widget.config.backgrounds[i].$2]), border: Border.all(color: _bg == i ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant, width: _bg == i ? 3 : 1))),
                ),
            ]),
          const SizedBox(height: 6),
          StickerTray(emoji: widget.config.stickers, onPick: (e) => setState(() {
            _stickers.add(Sticker(e, 0.3 + _rng.nextDouble() * 0.4, 0.3 + _rng.nextDouble() * 0.4, author: widget.session.player));
            _sel = _stickers.length - 1;
            _save();
          })),
          GameActions(children: [
            PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Finish', 'Terminar'), onPressed: () => widget.session.finish(GameOutcome(summary: tr(context, '${_stickers.length} pieces arranged', '${_stickers.length} piezas colocadas'), memorable: _stickers.map((s) => s.emoji).join(), details: {'stickers': [for (final s in _stickers) s.toJson()]}))),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Friendship Bracelet
// ---------------------------------------------------------------------------

class BraceletGame extends StatefulWidget {
  const BraceletGame({super.key, required this.session});
  final GameSession session;
  @override
  State<BraceletGame> createState() => _BraceletGameState();
}

class _BraceletGameState extends State<BraceletGame> {
  static const beads = ['🔴', '🟠', '🟡', '🟢', '🔵', '🟣', '⚪', '🟤', '💖', '⭐', '🌸', '🍀', '🌙', '💎'];
  late final List<String> _beads = [for (final v in (widget.session.saved?['beads'] as List?) ?? const []) '$v'];
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.4,
            child: LayoutBuilder(builder: (context, box) {
              final n = math.max(_beads.length, 1);
              final r = math.min(box.maxWidth, box.maxHeight) * 0.38;
              final c = Offset(box.maxWidth / 2, box.maxHeight / 2);
              final bead = math.min(36.0, 2 * math.pi * r / n * 0.95);
              return Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _RingPainter(r, Theme.of(context).colorScheme.outlineVariant))),
                for (var i = 0; i < _beads.length; i++)
                  Positioned(
                    left: c.dx + r * math.cos(2 * math.pi * i / n - math.pi / 2) - bead / 2,
                    top: c.dy + r * math.sin(2 * math.pi * i / n - math.pi / 2) - bead / 2,
                    width: bead,
                    height: bead,
                    child: GestureDetector(onTap: () => setState(() {
                      _beads.removeAt(i);
                      widget.session.save({'beads': _beads});
                    }), child: FittedBox(child: Text(_beads[i]))),
                  ),
                if (_beads.isEmpty) Center(child: Text(tr(context, 'Add beads below', 'Añade cuentas abajo'), style: Theme.of(context).textTheme.bodySmall)),
              ]);
            }),
          ),
          Text(tr(context, '${_beads.length} beads · tap a bead to remove it', '${_beads.length} cuentas · toca una para quitarla'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          StickerTray(emoji: beads, onPick: (b) => setState(() {
            if (_beads.length < 40) _beads.add(b);
            widget.session.save({'beads': _beads});
          })),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            PrismButton(density: PrismControlDensity.compact, label: tr(context, 'Repeat pattern', 'Repetir patrón'), onPressed: () => setState(() {
              final copy = [..._beads];
              for (final b in copy) {
                if (_beads.length < 40) _beads.add(b);
              }
              widget.session.save({'beads': _beads});
            })),
          ]),
          const SizedBox(height: 8),
          PrismTextField(controller: _name, hintText: tr(context, 'Who is it for? (optional)', '¿Para quién es? (opcional)')),
          GameActions(children: [
            PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Finish bracelet', 'Terminar pulsera'), onPressed: () => widget.session.finish(GameOutcome(summary: _name.text.trim().isEmpty ? tr(context, 'A new bracelet', 'Una pulsera nueva') : tr(context, 'A bracelet for ${_name.text.trim()}', 'Una pulsera para ${_name.text.trim()}'), memorable: _beads.join()))),
          ]),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.r, this.color);
  final double r;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(size.center(Offset.zero), r, Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2);
  @override
  bool shouldRepaint(covariant _RingPainter old) => old.r != r;
}

// ---------------------------------------------------------------------------
// Mood Palette
// ---------------------------------------------------------------------------

class MoodPaletteGame extends StatefulWidget {
  const MoodPaletteGame({super.key, required this.session});
  final GameSession session;
  @override
  State<MoodPaletteGame> createState() => _MoodPaletteGameState();
}

class _MoodPaletteGameState extends State<MoodPaletteGame> {
  late final math.Random _rng = widget.session.rng(70);
  late final List<HSVColor> _swatches = List.generate(5, (_) => HSVColor.fromAHSV(1, _rng.nextDouble() * 360, 0.35 + _rng.nextDouble() * 0.4, 0.7 + _rng.nextDouble() * 0.3));
  int _sel = 0;
  final _name = TextEditingController();
  final Set<int> _locked = {};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _hex(HSVColor c) => '#${c.toColor().toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final s = _swatches[_sel];
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _sel = i),
                  onLongPress: () => setState(() => _locked.contains(i) ? _locked.remove(i) : _locked.add(i)),
                  child: Container(
                    height: 110,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: _swatches[i].toColor(), borderRadius: BorderRadius.circular(10), border: Border.all(color: _sel == i ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3)),
                    child: Text('${_locked.contains(i) ? '🔒 ' : ''}${_hex(_swatches[i])}', style: TextStyle(fontSize: 9, color: _swatches[i].value > 0.6 && _swatches[i].saturation < 0.6 ? Colors.black87 : Colors.white)),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          Text(tr(context, 'Tap a swatch to adjust it. Long-press to lock.', 'Toca un color para ajustarlo. Mantén pulsado para fijarlo.'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          for (final (label, value, max, set) in [
            (tr(context, 'Hue', 'Tono'), s.hue, 360.0, (double v) => s.withHue(v)),
            (tr(context, 'Softness', 'Saturación'), s.saturation, 1.0, (double v) => s.withSaturation(v)),
            (tr(context, 'Brightness', 'Brillo'), s.value, 1.0, (double v) => s.withValue(v)),
          ])
            Row(children: [
              SizedBox(width: 82, child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
              Expanded(child: Slider(value: value, max: max, onChanged: (v) => setState(() => _swatches[_sel] = set(v)))),
            ]),
          PrismTextField(controller: _name, hintText: tr(context, 'Name this palette (e.g. "Rainy library")', 'Nombra esta paleta (p. ej. "Biblioteca lluviosa")')),
          GameActions(children: [
            PrismButton(label: tr(context, 'Shuffle unlocked', 'Mezclar no fijados'), icon: PhosphorIcons.shuffle(), onPressed: () => setState(() {
              final base = _rng.nextDouble() * 360;
              for (var i = 0; i < 5; i++) {
                if (_locked.contains(i)) continue;
                _swatches[i] = HSVColor.fromAHSV(1, (base + i * (20 + _rng.nextDouble() * 30)) % 360, 0.3 + _rng.nextDouble() * 0.45, 0.65 + _rng.nextDouble() * 0.35);
              }
            })),
            PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Keep palette', 'Guardar paleta'), onPressed: () => widget.session.finish(GameOutcome(summary: _name.text.trim().isEmpty ? tr(context, 'A new palette', 'Una paleta nueva') : _name.text.trim(), memorable: _swatches.map(_hex).join(' '), details: {'colors': _swatches.map(_hex).toList()}))),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Star Connect
// ---------------------------------------------------------------------------

class StarConnectGame extends StatefulWidget {
  const StarConnectGame({super.key, required this.session});
  final GameSession session;
  @override
  State<StarConnectGame> createState() => _StarConnectGameState();
}

class _StarConnectGameState extends State<StarConnectGame> {
  late final math.Random _rng = widget.session.rng(71);
  late final List<Offset> _stars = List.generate(22, (_) => Offset(0.06 + _rng.nextDouble() * 0.88, 0.06 + _rng.nextDouble() * 0.88));
  late final List<double> _mag = List.generate(22, (_) => 0.5 + _rng.nextDouble());
  final List<(int, int)> _lines = [];
  int? _from;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(context, 'Tap one star, then another, to draw a line. Make a constellation and name it.', 'Toca una estrella y luego otra para unirlas. Crea una constelación y ponle nombre.'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth;
                return Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _SkyPainter(_stars, _mag, _lines, _from))),
                  for (var i = 0; i < _stars.length; i++)
                    Positioned(
                      left: _stars[i].dx * w - 18,
                      top: _stars[i].dy * w - 18,
                      width: 36,
                      height: 36,
                      child: Semantics(
                        button: true,
                        label: tr(context, 'Star ${i + 1}', 'Estrella ${i + 1}'),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() {
                            if (_from == null) {
                              _from = i;
                            } else if (_from != i) {
                              final a = math.min(_from!, i), b = math.max(_from!, i);
                              _lines.contains((a, b)) ? _lines.remove((a, b)) : _lines.add((a, b));
                              _from = i;
                            } else {
                              _from = null;
                            }
                          }),
                        ),
                      ),
                    ),
                ]);
              }),
            ),
          ),
          const SizedBox(height: 8),
          PrismTextField(controller: _name, hintText: tr(context, 'Name your constellation', 'Nombra tu constelación')),
          GameActions(children: [
            PrismButton(label: tr(context, 'Undo line', 'Deshacer línea'), onPressed: () => setState(() {
              if (_lines.isNotEmpty) _lines.removeLast();
              _from = null;
            })),
            PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Finish', 'Terminar'), onPressed: () => widget.session.finish(GameOutcome(summary: _name.text.trim().isEmpty ? tr(context, 'A new constellation', 'Una nueva constelación') : _name.text.trim(), memorable: tr(context, '${_lines.length} lines between the stars', '${_lines.length} líneas entre estrellas')))),
          ]),
        ],
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.stars, this.mag, this.lines, this.from);
  final List<Offset> stars;
  final List<double> mag;
  final List<(int, int)> lines;
  final int? from;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF141B33), Color(0xFF2B2550)]).createShader(Offset.zero & size));
    final lp = Paint()
      ..color = const Color(0xCCBFD7FF)
      ..strokeWidth = 1.6;
    for (final (a, b) in lines) {
      canvas.drawLine(Offset(stars[a].dx * size.width, stars[a].dy * size.height), Offset(stars[b].dx * size.width, stars[b].dy * size.height), lp);
    }
    for (var i = 0; i < stars.length; i++) {
      final c = Offset(stars[i].dx * size.width, stars[i].dy * size.height);
      if (i == from) canvas.drawCircle(c, 10, Paint()..color = const Color(0x55FFE9A8));
      canvas.drawCircle(c, 2.2 * mag[i], Paint()..color = const Color(0xFFFFF6D8));
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => true;
}

// ---------------------------------------------------------------------------
// Cloud Watching
// ---------------------------------------------------------------------------

class CloudsGame extends StatefulWidget {
  const CloudsGame({super.key, required this.session});
  final GameSession session;
  @override
  State<CloudsGame> createState() => _CloudsGameState();
}

class _CloudsGameState extends State<CloudsGame> {
  late final math.Random _rng = widget.session.rng(72);
  late int _cloudSeed = _rng.nextInt(1 << 20);
  final _ctl = TextEditingController();
  final List<String> _seen = [];
  static const ideas = ['a sleeping cat', 'a dragon', 'a teacup', 'a rabbit', 'a whale', 'a sheep', 'a castle', 'a bird', 'a boot', 'a heart', 'a turtle', 'a ship', 'a dog', 'a flower', 'a bear'];

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.5,
            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: TweenAnimationBuilder<double>(
              key: ValueKey(_cloudSeed),
              tween: Tween(begin: -0.04, end: 0.04),
              duration: const Duration(seconds: 12),
              builder: (context, drift, _) => CustomPaint(painter: _CloudPainter(_cloudSeed, drift)),
            )),
          ),
          const SizedBox(height: 10),
          Text(tr(context, 'What do you see? There are no wrong answers.', '¿Qué ves? No hay respuestas incorrectas.'), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          PrismTextField(controller: _ctl, hintText: tr(context, 'Maybe ${ideas[_cloudSeed % ideas.length]}…', 'Quizá ${ideas[_cloudSeed % ideas.length]}…')),
          if (_seen.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('☁️ ${_seen.join(' · ')}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)),
          GameActions(children: [
            PrismButton(label: tr(context, 'Next cloud', 'Otra nube'), icon: PhosphorIcons.cloud(), onPressed: () => setState(() {
              if (_ctl.text.trim().isNotEmpty) _seen.add(_ctl.text.trim());
              _ctl.clear();
              _cloudSeed = _rng.nextInt(1 << 20);
            })),
            PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Finish', 'Terminar'), onPressed: () {
              if (_ctl.text.trim().isNotEmpty) _seen.add(_ctl.text.trim());
              widget.session.finish(GameOutcome(summary: tr(context, '${_seen.length} clouds named', '${_seen.length} nubes'), memorable: _seen.isEmpty ? null : _seen.join(', ')));
            }),
          ]),
        ],
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  _CloudPainter(this.seed, this.drift);
  final int seed;
  final double drift;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8EC5FC), Color(0xFFD6ECFF)]).createShader(Offset.zero & size));
    final rng = math.Random(seed);
    final puffs = 7 + rng.nextInt(7);
    final cx = size.width * (0.5 + drift), cy = size.height * 0.5;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    final shade = Paint()..color = const Color(0xFFE3ECF7);
    var x = cx - size.width * 0.25, y = cy;
    final blobs = <(Offset, double)>[];
    for (var i = 0; i < puffs; i++) {
      final r = size.height * (0.1 + rng.nextDouble() * 0.14);
      blobs.add((Offset(x, y), r));
      x += size.width * (0.03 + rng.nextDouble() * 0.08) * (rng.nextBool() ? 1 : 0.6);
      y += size.height * (rng.nextDouble() - 0.5) * 0.22;
      if (x > cx + size.width * 0.28) x = cx - size.width * 0.15 + rng.nextDouble() * 0.2 * size.width;
    }
    for (final (o, r) in blobs) {
      canvas.drawCircle(o + Offset(0, r * 0.15), r, shade);
    }
    for (final (o, r) in blobs) {
      canvas.drawCircle(o, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CloudPainter old) => old.seed != seed || old.drift != drift;
}

// ---------------------------------------------------------------------------
// Postcard Maker (sends to the Cozy mailbox)
// ---------------------------------------------------------------------------

class PostcardGame extends ConsumerStatefulWidget {
  const PostcardGame({super.key, required this.session});
  final GameSession session;
  @override
  ConsumerState<PostcardGame> createState() => _PostcardGameState();
}

class _PostcardGameState extends ConsumerState<PostcardGame> {
  static const scenes = ['🏔️', '🌊', '🌅', '🌸', '🏡', '🌌', '🍂', '❄️', '🏝️', '🌻'];
  static const stamps = ['🦋', '🐝', '🌙', '⭐', '🍄', '🐚', '🕊️', '🌈'];
  static const backs = [(Color(0xFFFFE5D9), Color(0xFFFFCAD4)), (Color(0xFFD8F3DC), Color(0xFFB7E4C7)), (Color(0xFFCDE7FF), Color(0xFFA9D6E5)), (Color(0xFFFFF1C1), Color(0xFFFFD6A5)), (Color(0xFFE0D7FF), Color(0xFFC8B6FF))];
  late final math.Random _rng = widget.session.rng(73);
  late String _scene = scenes[_rng.nextInt(scenes.length)];
  late String _stamp = stamps[_rng.nextInt(stamps.length)];
  int _back = 0;
  final _msg = TextEditingController();
  List<String> _to = [];

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (a, b) = backs[_back];
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.55,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(colors: [a, b]), boxShadow: const [BoxShadow(blurRadius: 6, color: Color(0x22000000), offset: Offset(0, 2))]),
              child: Row(children: [
                Expanded(flex: 5, child: FittedBox(child: Text(_scene))),
                const VerticalDivider(color: Color(0x55000000)),
                Expanded(
                  flex: 6,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Align(alignment: Alignment.topRight, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: const Color(0x66000000), width: 1.5)), child: Text(_stamp, style: const TextStyle(fontSize: 22)))),
                    const SizedBox(height: 6),
                    Expanded(child: Text(_msg.text.isEmpty ? '…' : _msg.text, style: const TextStyle(color: Color(0xFF3B3B58), fontStyle: FontStyle.italic, fontSize: 12), overflow: TextOverflow.fade)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.center, children: [for (final s in scenes) PrismChip(label: s, selected: _scene == s, onTap: () => setState(() => _scene = s))]),
          Wrap(alignment: WrapAlignment.center, children: [for (final s in stamps) PrismChip(label: s, selected: _stamp == s, onTap: () => setState(() => _stamp = s))]),
          Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < backs.length; i++)
              GestureDetector(onTap: () => setState(() => _back = i), child: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [backs[i].$1, backs[i].$2]), border: Border.all(color: _back == i ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant, width: _back == i ? 3 : 1)))),
          ]),
          const SizedBox(height: 8),
          PrismTextField(controller: _msg, maxLines: 3, hintText: tr(context, 'Write your message', 'Escribe tu mensaje'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          AlterChips(ids: _to, emptyLabel: tr(context, 'Send to… (optional)', 'Enviar a… (opcional)'), onTap: () async {
            final r = await pickAlters(context, ref, selected: _to, title: tr(context, 'Send to', 'Enviar a'));
            if (r != null) setState(() => _to = r);
          }),
          GameActions(children: [
            PrismButton(tone: PrismButtonTone.filled, label: _to.isEmpty ? tr(context, 'Keep postcard', 'Guardar postal') : tr(context, 'Send postcard', 'Enviar postal'), onPressed: () async {
              if (_to.isNotEmpty) {
                await ref.read(trackerNotifierProvider.notifier).create(
                  kind: TrackerKind.cozyLetter,
                  title: tr(context, 'A postcard', 'Una postal'),
                  body: _msg.text.trim(),
                  memberId: widget.session.player,
                  fields: {'to': _to, 'stationery': 'postcard', 'scene': _scene, 'stamp': _stamp, 'back': _back},
                );
              }
              widget.session.finish(GameOutcome(summary: _to.isEmpty ? tr(context, 'Made a postcard', 'Hiciste una postal') : tr(context, 'Sent a postcard', 'Enviaste una postal'), memorable: '$_scene $_stamp ${_msg.text.trim()}'));
            }),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cozy Outfit Creator (paper doll with layered slots)
// ---------------------------------------------------------------------------

class OutfitGame extends StatefulWidget {
  const OutfitGame({super.key, required this.session});
  final GameSession session;
  @override
  State<OutfitGame> createState() => _OutfitGameState();
}

class _OutfitGameState extends State<OutfitGame> {
  static const slots = <String, List<String>>{
    'Head': ['—', '🎩', '👒', '🧢', '👑', '🎀', '⛑️', '🪖', '🌼'],
    'Face': ['😊', '😌', '🙂', '😎', '🤓', '🥰', '😴', '🤠'],
    'Top': ['👕', '👚', '🧥', '🥼', '👘', '🦺', '👗', '🎽'],
    'Bottom': ['👖', '🩳', '🩱', '—'],
    'Feet': ['👟', '👞', '🥾', '👡', '🩴', '🧦', '👢'],
    'Extra': ['—', '🧣', '🧤', '👜', '🎒', '☂️', '🌂', '💍', '🧸'],
  };
  late final Map<String, int> _pick = {for (final k in slots.keys) k: ((widget.session.saved?[k] as num?)?.toInt() ?? 0)};

  String _of(String k) => slots[k]![_pick[k]! % slots[k]!.length];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: scheme.secondaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              for (final k in slots.keys)
                if (_of(k) != '—') Text(_of(k), style: TextStyle(fontSize: k == 'Face' ? 54 : 40, height: 1.05)),
            ]),
          ),
          const SizedBox(height: 10),
          for (final k in slots.keys)
            Row(children: [
              SizedBox(width: 64, child: Text(k, style: Theme.of(context).textTheme.labelMedium)),
              PrismIconButton(icon: PhosphorIcons.caretLeft(), tooltip: tr(context, 'Previous', 'Anterior'), onPressed: () => setState(() {
                _pick[k] = (_pick[k]! - 1 + slots[k]!.length) % slots[k]!.length;
                widget.session.save(_pick);
              })),
              Expanded(child: Text(_of(k), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24))),
              PrismIconButton(icon: PhosphorIcons.caretRight(), tooltip: tr(context, 'Next', 'Siguiente'), onPressed: () => setState(() {
                _pick[k] = (_pick[k]! + 1) % slots[k]!.length;
                widget.session.save(_pick);
              })),
            ]),
          GameActions(children: [
            PrismButton(label: tr(context, 'Surprise me', 'Sorpréndeme'), icon: PhosphorIcons.shuffle(), onPressed: () => setState(() {
              final r = math.Random();
              for (final k in slots.keys) {
                _pick[k] = r.nextInt(slots[k]!.length);
              }
              widget.session.save(_pick);
            })),
            PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Finish outfit', 'Terminar atuendo'), onPressed: () => widget.session.finish(GameOutcome(summary: tr(context, 'A cozy outfit', 'Un atuendo acogedor'), memorable: slots.keys.map(_of).where((e) => e != '—').join(' ')))),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini Comic Maker (three panels)
// ---------------------------------------------------------------------------

class ComicGame extends StatefulWidget {
  const ComicGame({super.key, required this.session});
  final GameSession session;
  @override
  State<ComicGame> createState() => _ComicGameState();
}

class _ComicGameState extends State<ComicGame> {
  static const cast = ['🐱', '🐶', '🦊', '🐻', '🐸', '🐰', '🦉', '🐧', '🧙', '🤖', '👻', '🦄', '🧑‍🚀', '🧑‍🍳'];
  static const props = ['—', '☕', '🌧️', '🌙', '🎂', '📚', '🌳', '🏠', '🚀', '🍕', '💡', '🎈'];
  late final List<Map<String, Object?>> _panels = [
    for (var i = 0; i < 3; i++) {
      'a': ((widget.session.saved?['p$i'] as Map?)?['a'] as String?) ?? cast[i],
      'b': ((widget.session.saved?['p$i'] as Map?)?['b'] as String?) ?? cast[i + 3],
      'prop': ((widget.session.saved?['p$i'] as Map?)?['prop'] as String?) ?? props[i + 1],
      'say': ((widget.session.saved?['p$i'] as Map?)?['say'] as String?) ?? '',
    },
  ];
  late final List<TextEditingController> _ctl = [for (final p in _panels) TextEditingController(text: '${p['say']}')];
  int _sel = 0;

  @override
  void dispose() {
    for (final c in _ctl) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() => widget.session.save({for (var i = 0; i < 3; i++) 'p$i': _panels[i]});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = _panels[_sel];
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _sel = i),
                  child: AspectRatio(
                    aspectRatio: 0.8,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _sel == i ? scheme.primary : const Color(0xFF3B3B58), width: _sel == i ? 3 : 2), borderRadius: BorderRadius.circular(6)),
                      child: Column(children: [
                        if ('${_panels[i]['say']}'.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF3B3B58)), borderRadius: BorderRadius.circular(10)),
                            child: Text('${_panels[i]['say']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Color(0xFF3B3B58))),
                          ),
                        const Spacer(),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          Text('${_panels[i]['a']}', style: const TextStyle(fontSize: 26)),
                          if (_panels[i]['prop'] != '—') Text('${_panels[i]['prop']}', style: const TextStyle(fontSize: 16)),
                          Text('${_panels[i]['b']}', style: const TextStyle(fontSize: 26)),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Text(tr(context, 'Panel ${_sel + 1}', 'Viñeta ${_sel + 1}'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
          for (final (key, list, label) in [('a', cast, tr(context, 'Left', 'Izquierda')), ('prop', props, tr(context, 'Prop', 'Objeto')), ('b', cast, tr(context, 'Right', 'Derecha'))])
            SizedBox(
              height: 44,
              child: Row(children: [
                SizedBox(width: 70, child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
                Expanded(child: ListView(scrollDirection: Axis.horizontal, children: [for (final e in list) PrismChip(label: e, selected: p[key] == e, onTap: () => setState(() {
                  p[key] = e;
                  _save();
                }))])),
              ]),
            ),
          PrismTextField(controller: _ctl[_sel], hintText: tr(context, 'Speech bubble', 'Bocadillo'), onChanged: (v) => setState(() {
            p['say'] = v;
            _save();
          })),
          GameActions(children: [
            PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Finish comic', 'Terminar cómic'), onPressed: () => widget.session.finish(GameOutcome(summary: tr(context, 'A three-panel comic', 'Un cómic de tres viñetas'), memorable: [for (final x in _panels) '${x['a']}${x['b']} "${x['say']}"'].join(' / ')))),
          ]),
        ],
      ),
    );
  }
}
