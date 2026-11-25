import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/intro_cards/intro_pattern_editor.dart';
import 'package:prism_plurality/features/intro_cards/intro_patterns.dart';

Future<void> _paintAll(List<IntroPattern> patterns, {String? out}) async {
  const w = 160.0, h = 100.0, cols = 8;
  final rows = (patterns.length / cols).ceil();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  for (var i = 0; i < patterns.length; i++) {
    canvas.save();
    canvas.translate((i % cols) * (w + 4), (i ~/ cols) * (h + 4));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFFFF7EC),
    );
    IntroPatternPainter(
      patterns[i],
      const Color(0xFF6B4FA0),
    ).paint(canvas, const Size(w, h));
    canvas.restore();
  }
  final img = await rec.endRecording().toImage(
    (cols * (w + 4)).toInt(),
    (rows * (h + 4)).toInt(),
  );
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  expect(bytes, isNotNull);
  if (out != null) File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  editorTests();
  test('pattern library is large', () {
    expect(introMotifs.length, greaterThanOrEqualTo(40));
    expect(introTiles.length, greaterThanOrEqualTo(25));
  });

  test('json round-trips every field, including the second layer', () {
    const p = IntroPattern(
      kind: 'plaid',
      color: 0xFF112233,
      opacity: .4,
      scale: 1.5,
      density: .7,
      rotation: 30,
      jitter: .2,
      variety: .1,
      stroke: 2.5,
      filled: false,
      placement: 'corners',
      fade: 'edges',
      seed: 7,
      layer2: IntroPattern(kind: 'sparkles', opacity: .3),
    );
    final back = IntroPattern.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
    expect(back.layer2!.kind, 'sparkles');
    expect(IntroPattern.fromJson(null, fallbackKind: 'moons').kind, 'moons');
  });

  test('every motif, tile, placement, fade and preset paints', () async {
    final out = Platform.environment['PATTERN_SHEET'];
    await _paintAll([
      for (final k in introPatternNames.keys)
        IntroPattern(kind: k, opacity: .5),
      for (final p in introPlacements.keys)
        IntroPattern(kind: 'hearts', placement: p, opacity: .6),
      for (final f in introFades.keys)
        IntroPattern(kind: 'checker', fade: f, opacity: .5),
      ...introPatternPresets.values,
    ], out: out);
  });
}

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  IntroPattern p = const IntroPattern();
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: IntroPatternEditor(
      value: p,
      onChanged: (v) => setState(() => p = v),
      bg1: const Color(0xFFFFF7EC),
      bg2: const Color(0xFFFCE7F3),
      ink: const Color(0xFF6B4FA0),
    ),
  );
}

void editorTests() {
  testWidgets('editor builds, adds a second layer and switches tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: _Host()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final state = tester.state<_HostState>(find.byType(_Host));
    await tester.tap(find.textContaining('Second layer'));
    await tester.pumpAndSettle();
    expect(state.p.layer2, isNotNull);
    await tester.tap(find.textContaining('Tiled ('));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
