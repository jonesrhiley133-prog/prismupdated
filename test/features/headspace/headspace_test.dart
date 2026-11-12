import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/headspace/utils/headspace.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

final _t = DateTime(2026);

void main() {
  test('area rects clamp inside the canvas', () {
    final a =
        TrackerRecord(
          id: 'a',
          kind: TrackerKind.headspaceArea,
          createdAt: _t,
          modifiedAt: _t,
        ).withFields({
          HsField.x: 5000.0,
          HsField.y: -10.0,
          HsField.w: 200.0,
          HsField.h: 20.0,
        });
    final r = areaRect(a);
    expect(r, Rect.fromLTWH(headspaceCanvas.width - 200, 0, 200, 50));
    expect(
      clampPosition(const Offset(-5, 9999), const Size(100, 100)),
      Offset(0, headspaceCanvas.height - 100),
    );
  });

  test('grid layout, edge points and link validation', () {
    final g = gridLayout(5);
    expect(g, hasLength(5));
    expect(g.toSet(), hasLength(5));
    final r = const Rect.fromLTWH(0, 0, 100, 50);
    expect(edgePoint(r, const Offset(500, 25)), const Offset(100, 25));
    expect(edgePoint(r, const Offset(50, -500)), const Offset(50, 0));
    TrackerRecord l(String f, String t) => TrackerRecord(
      id: '$f$t',
      kind: TrackerKind.headspaceLink,
      createdAt: _t,
      modifiedAt: _t,
    ).withFields({HsField.from: f, HsField.to: t});
    expect(
      validLinks(
        [l('a', 'b'), l('a', 'x'), l('a', 'a')],
        {'a', 'b'},
      ).map((x) => x.id),
      ['ab'],
    );
  });
}
