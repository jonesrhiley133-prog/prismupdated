import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/scrapbook/scrap_shapes.dart';

void main() {
  test('75+ unique shapes, each with a name and a real outline', () {
    expect(scrapShapeIds.length, greaterThanOrEqualTo(75));
    expect(scrapShapeIds.toSet().length, scrapShapeIds.length);
    const r = Rect.fromLTWH(0, 0, 100, 80);
    for (final id in scrapShapeIds) {
      expect(scrapShapeName(id), isNot(id.isEmpty ? 'x' : ''), reason: id);
      final b = scrapShapePath(id, r).getBounds();
      expect(b.isEmpty, isFalse, reason: id);
      expect(b.width, greaterThan(5), reason: id);
      final rec = ui.PictureRecorder();
      const ScrapShapePainter(shape: 'x', fill: Colors.red);
      ScrapShapePainter(
        shape: id,
        fill: Colors.red,
        fill2: Colors.blue,
        border: Colors.black,
        borderWidth: 3,
        shadow: 4,
      ).paint(Canvas(rec), const Size(100, 80));
      rec.endRecording().dispose();
    }
  });
}
