import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/scrapbook/scrap_editor_core.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';

ScrapElement _e(
  String id,
  double x,
  double y, {
  double w = 0.2,
  double h = 0.2,
}) => ScrapElement(id: id, type: ScrapType.shape, x: x, y: y, w: w, h: h);

void main() {
  test('undo and redo walk through every step, including page settings', () {
    final c = ScrapEditorController(elements: [], meta: {'bg': 1});
    c.add(_e('a', 0.1, 0.1));
    c.meta['bg'] = 2;
    c.commit();
    c.add(_e('b', 0.5, 0.5));
    expect(c.els.length, 2);
    c.undo();
    expect(c.els.length, 1);
    expect(c.meta['bg'], 2);
    c.undo();
    expect(c.meta['bg'], 1);
    c.undo();
    expect(c.els, isEmpty);
    expect(c.canUndo, isFalse);
    c.redo();
    c.redo();
    c.redo();
    expect(c.els.length, 2);
    expect(c.canRedo, isFalse);
    // A new edit after undo drops the redo branch.
    c.undo();
    c.add(_e('c', 0.2, 0.2));
    expect(c.canRedo, isFalse);
  });

  test('history is capped', () {
    final c = ScrapEditorController(elements: []);
    for (var i = 0; i < 150; i++) {
      c.add(_e('e$i', 0.1, 0.1));
    }
    var steps = 0;
    while (c.canUndo) {
      c.undo();
      steps++;
    }
    expect(steps, lessThanOrEqualTo(ScrapEditorController.maxHistory));
  });

  test(
    'group selects together, ungroup releases, lock protects from delete and move',
    () {
      final c = ScrapEditorController(
        elements: [_e('a', 0, 0), _e('b', 0.3, 0.3), _e('c', 0.6, 0.6)],
      );
      c.select('a');
      c.select('b', additive: true);
      c.group();
      c.select(null);
      c.select('a');
      expect(c.selected, {'a', 'b'});
      c.ungroup();
      c.select('a');
      expect(c.selected, {'a'});

      c.select('c');
      c.toggleLock();
      expect(c.byId('c')!.locked, isTrue);
      expect(c.deleteSelected(), 0);
      c.moveSelection(0.1, 0.1);
      expect(c.byId('c')!.x, 0.6);
      c.toggleLock();
      expect(c.deleteSelected(), 1);
    },
  );

  test('duplicate and copy/paste give new ids and keep groups together', () {
    final c = ScrapEditorController(
      elements: [_e('a', 0, 0), _e('b', 0.3, 0.3)],
    );
    c.selectAll();
    c.group();
    c.duplicateSelected();
    expect(c.els.length, 4);
    final groups = c.els.map((e) => e.group).toSet();
    expect(groups.length, 2);
    expect(c.els.map((e) => e.id).toSet().length, 4);
    c.select('a');
    c.copySelected();
    final other = ScrapEditorController(elements: []);
    other.paste();
    expect(other.els.length, 2);
    expect(other.els.first.id, isNot('a'));
  });

  test('layer order: front, back, forward, backward, reorder', () {
    final c = ScrapEditorController(
      elements: [
        _e('a', 0, 0)..z = 0,
        _e('b', 0, 0)..z = 1,
        _e('c', 0, 0)..z = 2,
      ],
    );
    List<String> order() => ([
      ...c.els,
    ]..sort((a, b) => a.z.compareTo(b.z))).map((e) => e.id).toList();
    c.select('a');
    c.toFront();
    expect(order(), ['b', 'c', 'a']);
    c.toBack();
    expect(order(), ['a', 'b', 'c']);
    c.forward();
    expect(order(), ['b', 'a', 'c']);
    c.backward();
    expect(order(), ['a', 'b', 'c']);
    c.reorderLayer(0, 2); // top-first list: move c to the bottom
    expect(order().first, 'c');
  });

  test('align and distribute', () {
    final c = ScrapEditorController(
      elements: [
        _e('a', 0.1, 0.1),
        _e('b', 0.4, 0.5, w: 0.1),
        _e('c', 0.8, 0.2),
      ],
    );
    c.selectAll();
    c.align(ScrapAlign.left);
    expect(c.els.map((e) => e.x), everyElement(closeTo(0.1, 1e-9)));
    c.align(ScrapAlign.top);
    expect(c.els.map((e) => e.y), everyElement(closeTo(0.1, 1e-9)));
    c.els[0].x = 0.1;
    c.els[1].x = 0.2;
    c.els[2].x = 0.7;
    c.distribute(horizontal: true);
    final gaps = [
      c.els[1].x - (c.els[0].x + c.els[0].w),
      c.els[2].x - (c.els[1].x + c.els[1].w),
    ];
    expect(gaps[0], closeTo(gaps[1], 1e-9));
    // A single element aligns to the page.
    c.select('a');
    c.align(ScrapAlign.hCenter);
    expect(c.byId('a')!.x, closeTo(0.4, 1e-9));
  });

  test('snapping finds page edges, centres and other elements', () {
    const page = Size(300, 400);
    final r = snapMove(const Rect.fromLTWH(97, 10, 100, 50), const [], page);
    expect(r.dx, 3); // centre 147 → 150
    expect(r.vLines, [150]);
    expect(
      snapMove(const Rect.fromLTWH(60, 60, 20, 20), const [], page).vLines,
      isEmpty,
    );
    final far = snapMove(const Rect.fromLTWH(60, 60, 20, 20), const [
      Rect.fromLTWH(100, 100, 30, 30),
    ], page);
    expect(far.dx, 0);
    final edge = snapMove(const Rect.fromLTWH(3, 3, 20, 20), const [], page);
    expect((edge.dx, edge.dy), (-3.0, -3.0));
  });
}
