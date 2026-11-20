import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/health/body_atlas.dart';

/// Renders each Body Map sheet to a PNG for visual review (set
/// PRISM_RENDER_DIR to write them).
void main() {
  final dir = Platform.environment['PRISM_RENDER_DIR'];
  test('render sheets', () async {
    if (dir == null) return;
    for (final (v, side) in [
      (BodyView.front, BodySide.right),
      (BodyView.back, BodySide.right),
      (BodyView.face, BodySide.right),
      (BodyView.handPalm, BodySide.left),
      (BodyView.handBack, BodySide.left),
      (BodyView.footTop, BodySide.right),
      (BodyView.footSole, BodySide.right),
    ]) {
      final s = sheetFor(v, side: side);
      const scale = 3.0;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.scale(scale);
      c.drawRect(Offset.zero & s.size, Paint()..color = const Color(0xFF1E1B22));
      c.drawPath(s.outline, Paint()..color = const Color(0xFF2E2A33));
      for (final sh in s.shapes) {
        c.drawPath(sh.path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = Colors.purpleAccent.withValues(alpha: 0.5));
      }
      for (final d in s.details) {
        c.drawPath(d, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white38);
      }
      c.drawPath(s.outline, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white70);
      final img = await rec.endRecording().toImage((s.size.width * scale).round(), (s.size.height * scale).round());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/${v.name}.png').writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
}
