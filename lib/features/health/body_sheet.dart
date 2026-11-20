import 'package:flutter/material.dart';

/// A neutral anatomical sheet. All geometry uses the same normalized coordinate
/// space as body_regions.dart and persisted Health markers; zoom never rewrites it.
class HealthBodySheet extends StatelessWidget {
  const HealthBodySheet({super.key, required this.view});
  final String view;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: BodySheetPainter(
        view: view,
        outline: colors.onSurfaceVariant,
        detail: colors.outline,
        fill: colors.surfaceContainerHighest,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class BodySheetPainter extends CustomPainter {
  const BodySheetPainter({
    required this.view,
    required this.outline,
    required this.detail,
    required this.fill,
  });
  final String view;
  final Color outline, detail, fill;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw in a 360 × 600 logical space for consistent line weights.
    canvas.save();
    canvas.scale(size.width / 360, size.height / 600);
    final border = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fine = Paint()
      ..color = detail.withValues(alpha: .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .85
      ..strokeCap = StrokeCap.round;
    final shade = Paint()..color = fill;
    void line(List<Offset> points, [bool strong = false]) {
      final p = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        p.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(p, strong ? border : fine);
    }

    void shape(Path path) {
      canvas.drawPath(path, shade);
      canvas.drawPath(path, border);
    }

    // Head, ears, jaw and neck, distinct from the torso silhouette.
    shape(
      Path()
        ..moveTo(165, 91)
        ..cubicTo(151, 84, 145, 67, 145, 46)
        ..cubicTo(144, 23, 158, 14, 180, 14)
        ..cubicTo(202, 14, 216, 23, 215, 46)
        ..cubicTo(215, 67, 209, 84, 195, 91)
        ..quadraticBezierTo(180, 99, 165, 91)
        ..close(),
    );
    for (final mirror in [false, true]) {
      canvas.save();
      if (mirror) {
        canvas.translate(360, 0);
        canvas.scale(-1, 1);
      }
      shape(
        Path()
          ..moveTo(146, 49)
          ..cubicTo(137, 44, 138, 66, 148, 70)
          ..lineTo(146, 49)
          ..close(),
      );
      line([const Offset(144, 54), const Offset(144, 61)]);
      canvas.restore();
    }
    // Smooth, symmetric outline; individual fingers and toes remain discernible.
    final half = Path()
      ..moveTo(165, 91)
      ..lineTo(165, 108)
      ..cubicTo(158, 117, 132, 117, 122, 127)
      ..cubicTo(112, 139, 110, 156, 104, 176)
      ..lineTo(94, 209)
      ..quadraticBezierTo(91, 216, 90, 224)
      ..lineTo(80, 252)
      ..lineTo(76, 276)
      ..lineTo(67, 289)
      ..lineTo(61, 307)
      // Little, ring, middle and index fingers follow the persisted anchors.
      ..lineTo(54, 329)
      ..quadraticBezierTo(53, 336, 57, 335)
      ..lineTo(63, 319)
      ..lineTo(60, 336)
      ..quadraticBezierTo(60, 343, 64, 340)
      ..lineTo(70, 320)
      ..lineTo(67, 338)
      ..quadraticBezierTo(68, 346, 72, 341)
      ..lineTo(77, 319)
      ..lineTo(76, 334)
      ..quadraticBezierTo(77, 340, 81, 335)
      ..lineTo(87, 314)
      ..lineTo(90, 305)
      // Thumb faces the body's midline in a neutral palms-forward stance.
      ..lineTo(97, 312)
      ..quadraticBezierTo(103, 315, 102, 308)
      ..lineTo(95, 296)
      ..lineTo(91, 281)
      ..lineTo(111, 264)
      ..lineTo(121, 235)
      ..lineTo(130, 208)
      ..lineTo(133, 193)
      ..quadraticBezierTo(138, 211, 137, 225)
      ..cubicTo(136, 242, 124, 268, 126, 290)
      ..cubicTo(127, 322, 130, 356, 133, 384)
      ..quadraticBezierTo(136, 406, 135, 421)
      ..cubicTo(129, 449, 137, 488, 137, 520)
      ..lineTo(136, 538)
      ..quadraticBezierTo(135, 548, 131, 560)
      ..lineTo(125, 575)
      ..quadraticBezierTo(125, 581, 132, 582)
      ..lineTo(135, 584)
      ..lineTo(142, 584)
      ..lineTo(148, 585)
      ..lineTo(154, 584)
      ..lineTo(161, 584)
      ..quadraticBezierTo(168, 583, 166, 576)
      ..lineTo(165, 552)
      ..lineTo(165, 528)
      ..cubicTo(165, 491, 170, 458, 168, 426)
      ..quadraticBezierTo(166, 412, 167, 399)
      ..lineTo(171, 365)
      ..lineTo(175, 337)
      ..quadraticBezierTo(177, 324, 180, 318);
    for (final mirror in [false, true]) {
      canvas.save();
      if (mirror) {
        canvas.translate(360, 0);
        canvas.scale(-1, 1);
      }
      // Fill each half to the midline without painting an artificial centre seam.
      final filled = Path.from(half)
        ..lineTo(180, 108)
        ..close();
      canvas.drawPath(filled, shade);
      canvas.drawPath(half, border);
      // Elbow, wrist, ankle and finger joints.
      line([const Offset(92, 218), const Offset(100, 222)]);
      line([const Offset(78, 277), const Offset(91, 281)]);
      line([
        const Offset(139, 531),
        const Offset(149, 535),
        const Offset(162, 533),
      ]);
      line([
        const Offset(73, 300),
        const Offset(80, 292),
        const Offset(89, 298),
      ]);
      for (var i = 0; i < 4; i++) {
        final x = 57.0 + i * 6;
        line([Offset(x, 316), Offset(x + 3, 317)]);
      }
      for (var i = 0; i < 4; i++) {
        final x = 135.0 + i * 7;
        line([Offset(x, 574), Offset(x + 1, 582)]);
      }
      if (view == 'front') {
        // Collarbone, rib arc, shoulder, palm and knee landmarks.
        line([
          const Offset(132, 128),
          const Offset(153, 126),
          const Offset(176, 133),
        ]);
        line([
          const Offset(124, 143),
          const Offset(133, 153),
          const Offset(134, 176),
        ]);
        line([
          const Offset(142, 176),
          const Offset(150, 191),
          const Offset(173, 197),
        ]);
        line([
          const Offset(140, 253),
          const Offset(156, 266),
          const Offset(175, 285),
        ]);
        canvas.drawOval(const Rect.fromLTWH(141, 408, 18, 18), fine);
        line([
          const Offset(143, 444),
          const Offset(149, 483),
          const Offset(147, 516),
        ]);
        line([
          const Offset(82, 288),
          const Offset(83, 297),
          const Offset(79, 307),
        ]);
      } else {
        // Scapula, back muscles, gluteal fold, knee crease and heel.
        line([
          const Offset(151, 134),
          const Offset(137, 145),
          const Offset(149, 180),
          const Offset(163, 157),
          const Offset(151, 134),
        ]);
        line([
          const Offset(140, 195),
          const Offset(155, 214),
          const Offset(163, 244),
        ]);
        line([
          const Offset(135, 291),
          const Offset(153, 297),
          const Offset(174, 291),
        ]);
        line([
          const Offset(139, 420),
          const Offset(150, 416),
          const Offset(164, 420),
        ]);
        line([
          const Offset(149, 439),
          const Offset(143, 466),
          const Offset(149, 499),
        ]);
        canvas.drawArc(
          const Rect.fromLTWH(139, 541, 23, 24),
          0,
          3.14,
          false,
          fine,
        );
      }
      canvas.restore();
    }
    if (view == 'front') {
      // Eyebrows, eyes, nose and mouth are restrained landmarks, not an expression.
      line([
        const Offset(156, 45),
        const Offset(165, 43),
        const Offset(172, 45),
      ]);
      line([
        const Offset(188, 45),
        const Offset(195, 43),
        const Offset(204, 45),
      ]);
      for (final x in [164.0, 196.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, 52), width: 13, height: 4),
          fine,
        );
      }
      line([
        const Offset(180, 53),
        const Offset(176, 65),
        const Offset(183, 65),
      ]);
      line([
        const Offset(170, 74),
        const Offset(180, 76),
        const Offset(190, 74),
      ]);
      line([const Offset(169, 99), const Offset(176, 119)]);
      line([const Offset(191, 99), const Offset(184, 119)]);
      line([const Offset(180, 141), const Offset(180, 178)]);
      canvas.drawOval(const Rect.fromLTWH(178, 224, 4, 6), fine);
    } else {
      line([const Offset(166, 94), const Offset(175, 117)]);
      line([const Offset(194, 94), const Offset(185, 117)]);
      line([const Offset(180, 122), const Offset(180, 268)]);
      for (var y = 142.0; y < 264; y += 12) {
        line([Offset(178, y), Offset(182, y)]);
      }
      line([const Offset(180, 273), const Offset(180, 303)]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BodySheetPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.outline != outline ||
      oldDelegate.detail != detail ||
      oldDelegate.fill != fill;
}
