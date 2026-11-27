import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_plurality/features/scrapbook/scrap_shapes.dart';
import 'package:prism_plurality/features/scrapbook/scrap_stickers.dart';
import 'package:prism_plurality/shared/fonts/prism_fonts.dart';

Color _hex(String h) => Color(0xFF000000 | int.parse(h, radix: 16));

/// Draws any built-in sticker to fill its box.
class ScrapStickerView extends StatelessWidget {
  const ScrapStickerView(this.sticker, {super.key, this.tint});
  final ScrapSticker sticker;

  /// Recolours shape and lettering stickers (emoji and pixel art keep theirs).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    switch (sticker.kind) {
      case StickerKind.emoji:
        return FittedBox(
          child: Text(sticker.data, style: const TextStyle(fontSize: 100)),
        );
      case StickerKind.pixel:
        return CustomPaint(
          painter: PixelStickerPainter(sticker.data),
          size: Size.infinite,
        );
      case StickerKind.shape:
        final p = sticker.data.split('|');
        return CustomPaint(
          painter: ScrapShapePainter(
            shape: p[0],
            fill: tint ?? _hex(p[1]),
            fill2: tint == null ? _hex(p[2]) : null,
            shadow: 2,
          ),
          size: Size.infinite,
        );
      case StickerKind.text:
        final p = sticker.data.split('|');
        return _Lettering(
          word: p[0],
          color: tint ?? _hex(p[1]),
          font: p[2],
          style: p[3],
        );
    }
  }
}

class PixelStickerPainter extends CustomPainter {
  PixelStickerPainter(this.rows);
  final String rows;

  @override
  void paint(Canvas canvas, Size size) {
    final lines = rows.split('|');
    final w = lines.map((l) => l.length).reduce(math.max);
    final h = lines.length;
    final px = math.min(size.width / w, size.height / h);
    final ox = (size.width - px * w) / 2, oy = (size.height - px * h) / 2;
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.18);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < lines[y].length; x++) {
        final c = pixelColor(lines[y][x]);
        if (c == 0) continue;
        final r = Rect.fromLTWH(ox + x * px, oy + y * px, px + 0.5, px + 0.5);
        canvas.drawRect(r, Paint()..color = Color(c));
        canvas.drawRect(
          Rect.fromLTWH(r.left, r.bottom - px * 0.18, r.width, px * 0.18),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PixelStickerPainter o) => o.rows != rows;
}

class _Lettering extends StatelessWidget {
  const _Lettering({
    required this.word,
    required this.color,
    required this.font,
    required this.style,
  });
  final String word, font, style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final key = 'g:$font';
    return ValueListenableBuilder<int>(
      valueListenable: PrismFonts.loadTick,
      builder: (context, _, _) {
        PrismFonts.ensureLoaded(key);
        final base = PrismFonts.style(
          key,
          const TextStyle(fontSize: 100, height: 1.1),
        );
        Widget t(TextStyle s) =>
            Text(word, style: s, maxLines: 1, softWrap: false);
        final fill = base.copyWith(color: color);
        final outline = base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        );
        final child = switch (style) {
          'bubble' => Stack(
            children: [
              t(
                outline.copyWith(
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(3, 5),
                    ),
                  ],
                ),
              ),
              t(fill),
            ],
          ),
          'neon' => t(
            fill.copyWith(
              color: Colors.white,
              shadows: [
                Shadow(color: color, blurRadius: 12),
                Shadow(color: color, blurRadius: 28),
                Shadow(color: color, blurRadius: 48),
              ],
            ),
          ),
          'retro' => t(
            fill.copyWith(
              shadows: [
                Shadow(color: Colors.black87, offset: const Offset(6, 6)),
                Shadow(
                  color: color.withValues(alpha: 0.5),
                  offset: const Offset(10, 10),
                ),
              ],
            ),
          ),
          'stamp' => DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
              child: t(fill),
            ),
          ),
          _ => t(
            fill.copyWith(
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(2, 3),
                ),
              ],
            ),
          ),
        };
        return FittedBox(
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        );
      },
    );
  }
}
