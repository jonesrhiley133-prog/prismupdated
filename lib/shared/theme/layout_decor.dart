import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The parts of the interface a layout arrangement can decorate. Each one
/// is switched on or off on its own.
abstract final class LayoutPart {
  static const header = 'header';
  static const cards = 'cards';
  static const dividers = 'dividers';
  static const profile = 'profile';
  static const nav = 'nav';
  static const hanging = 'hanging';

  static const all = [header, cards, dividers, profile, nav, hanging];
}

/// What the active layout arrangement looks like: a few colours, two
/// symbols and a line style. Plain data, so shared widgets can draw it
/// without knowing about the decoration catalog. It only ever adds small
/// ornaments; it never changes colours, fonts, spacing or backgrounds.
@immutable
class LayoutDecorData {
  const LayoutDecorData({
    required this.parts,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.motif,
    required this.corner,
    required this.line,
  });

  final Set<String> parts;
  final Color primary, secondary, accent;

  /// Shown at the end of dividers and beside headers.
  final String motif;

  /// Tucked into card corners and avatar frames.
  final String corner;

  /// dotted | scallop | zigzag | double | stitched | vine | lace | ornate |
  /// hairline | mkeka | frost
  final String line;

  bool on(String part) => parts.contains(part);

  @override
  bool operator ==(Object o) =>
      o is LayoutDecorData &&
      o.primary == primary &&
      o.secondary == secondary &&
      o.accent == accent &&
      o.motif == motif &&
      o.corner == corner &&
      o.line == line &&
      o.parts.length == parts.length &&
      o.parts.containsAll(parts);

  @override
  int get hashCode => Object.hash(
    primary,
    secondary,
    accent,
    motif,
    corner,
    line,
    parts.length,
  );
}

/// Makes the active layout arrangement available to shared widgets.
class LayoutDecor extends InheritedWidget {
  const LayoutDecor({super.key, required this.data, required super.child});
  final LayoutDecorData? data;

  static LayoutDecorData? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LayoutDecor>()?.data;

  /// The arrangement, only if [part] is switched on.
  static LayoutDecorData? part(BuildContext context, String part) {
    final d = of(context);
    return d != null && d.on(part) ? d : null;
  }

  @override
  bool updateShouldNotify(LayoutDecor old) => old.data != data;
}

const _emojiFonts = ['NotoColorEmoji', 'Apple Color Emoji', 'Segoe UI Emoji'];

/// A small emoji ornament that ignores touches and reading aids.
class LayoutGlyph extends StatelessWidget {
  const LayoutGlyph(this.glyph, {super.key, this.size = 14});
  final String glyph;
  final double size;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Text(
        glyph,
        style: TextStyle(
          fontSize: size,
          height: 1,
          fontFamilyFallback: _emojiFonts,
        ),
      ),
    ),
  );
}

/// A decorative horizontal line in one of the layout line styles.
class LayoutLinePainter extends CustomPainter {
  const LayoutLinePainter(this.d);
  final LayoutDecorData d;

  @override
  void paint(Canvas c, Size s) {
    if (s.width <= 0) return;
    final y = s.height / 2;
    final p = Paint()
      ..color = d.primary.withValues(alpha: 0.75)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (d.line) {
      case 'dotted':
        for (var x = 2.0; x < s.width; x += 7) {
          c.drawCircle(Offset(x, y), 1.4, p..style = PaintingStyle.fill);
        }
      case 'scallop' || 'lace':
        final path = Path()..moveTo(0, y - 2);
        for (var x = 0.0; x < s.width; x += 8) {
          path.quadraticBezierTo(x + 4, y + 5, x + 8, y - 2);
        }
        c.drawPath(path, p);
        if (d.line == 'lace') {
          for (var x = 4.0; x < s.width; x += 8) {
            c.drawCircle(
              Offset(x, y + 4),
              1,
              Paint()..color = d.secondary.withValues(alpha: 0.8),
            );
          }
        }
      case 'zigzag' || 'mkeka':
        final path = Path()..moveTo(0, y);
        var up = true;
        for (var x = 0.0; x < s.width; x += 5) {
          path.lineTo(x + 5, up ? y - 3 : y + 3);
          up = !up;
        }
        c.drawPath(path, p..color = d.primary.withValues(alpha: 0.8));
        if (d.line == 'mkeka') {
          c.drawLine(
            Offset(0, y + 5),
            Offset(s.width, y + 5),
            Paint()
              ..color = d.secondary
              ..strokeWidth = 1,
          );
        }
      case 'double':
        c.drawLine(Offset(0, y - 2), Offset(s.width, y - 2), p);
        c.drawLine(
          Offset(0, y + 2),
          Offset(s.width, y + 2),
          p..color = d.secondary.withValues(alpha: 0.7),
        );
      case 'stitched':
        for (var x = 0.0; x < s.width; x += 8) {
          c.drawLine(Offset(x, y), Offset(x + 4, y), p);
        }
      case 'vine':
        final path = Path()..moveTo(0, y);
        for (var x = 0.0; x < s.width; x += 14) {
          path.cubicTo(x + 4, y - 4, x + 10, y + 4, x + 14, y);
        }
        c.drawPath(path, p..color = d.secondary.withValues(alpha: 0.85));
        for (var x = 7.0; x < s.width; x += 28) {
          c.drawOval(
            Rect.fromCenter(center: Offset(x, y - 3), width: 5, height: 3),
            Paint()..color = d.primary.withValues(alpha: 0.8),
          );
        }
      case 'ornate':
        c.drawLine(Offset(0, y), Offset(s.width, y), p);
        for (var x = 10.0; x < s.width; x += 22) {
          final r = Rect.fromCenter(center: Offset(x, y), width: 6, height: 6);
          c.save();
          c.translate(r.center.dx, r.center.dy);
          c.rotate(math.pi / 4);
          c.drawRect(
            Rect.fromCenter(center: Offset.zero, width: 4, height: 4),
            Paint()..color = d.accent.withValues(alpha: 0.9),
          );
          c.restore();
        }
      case 'frost':
        for (var x = 4.0; x < s.width; x += 12) {
          for (var k = 0; k < 3; k++) {
            final a = k * math.pi / 3;
            c.drawLine(
              Offset(x - math.cos(a) * 3, y - math.sin(a) * 3),
              Offset(x + math.cos(a) * 3, y + math.sin(a) * 3),
              p..strokeWidth = 1,
            );
          }
        }
      default:
        c.drawLine(Offset(0, y), Offset(s.width, y), p..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(LayoutLinePainter o) => o.d != d;
}

/// A decorative ring drawn just outside a profile picture.
class LayoutRingPainter extends CustomPainter {
  const LayoutRingPainter(this.d, {this.square = false});
  final LayoutDecorData d;
  final bool square;

  @override
  void paint(Canvas c, Size s) {
    final r = (Offset.zero & s).inflate(3);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = d.primary.withValues(alpha: 0.85);
    final path = square
        ? (Path()..addRRect(
            RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.2)),
          ))
        : (Path()..addOval(r));
    switch (d.line) {
      case 'dotted' || 'stitched' || 'frost':
        for (final m in path.computeMetrics()) {
          for (var t = 0.0; t < m.length; t += 7) {
            final pos = m.getTangentForOffset(t)!.position;
            c.drawCircle(pos, 1.6, Paint()..color = d.primary);
          }
        }
      case 'double' || 'ornate':
        c.drawPath(path, p);
        c.drawPath(
          square
              ? (Path()..addRRect(
                  RRect.fromRectAndRadius(
                    r.inflate(4),
                    Radius.circular(r.width * 0.24),
                  ),
                ))
              : (Path()..addOval(r.inflate(4))),
          p
            ..color = d.secondary.withValues(alpha: 0.7)
            ..strokeWidth = 1.2,
        );
      default:
        c.drawPath(
          path,
          p
            ..shader = SweepGradient(
              colors: [d.primary, d.secondary, d.accent, d.primary],
            ).createShader(r),
        );
    }
  }

  @override
  bool shouldRepaint(LayoutRingPainter o) => o.d != d || o.square != square;
}
