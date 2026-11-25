import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/features/companions/companion_art.dart';
import 'package:prism_plurality/features/companions/companion_species.dart';

/// Renders every species (and a dressed-up one) so the art can be checked
/// by eye. Writes the image only when PRISM_SHEET_OUT is set.
void main() {
  testWidgets('every species draws without errors', (tester) async {
    final key = GlobalKey();
    final out = Platform.environment['PRISM_SHEET_OUT'];
    await tester.binding.setSurfaceSize(const Size(900, 760));
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFFF6F2EE),
          child: Wrap(children: [
            for (final s in speciesCatalog)
              SizedBox(width: 112, height: 124, child: Column(children: [CompanionView(species: s, look: const CompanionLook(), size: 100, animate: false), Text(s.name, style: const TextStyle(fontSize: 10))])),
            SizedBox(width: 112, height: 124, child: CompanionView(species: speciesById('cat'), look: const CompanionLook(hat: 'witch', neck: 'scarf', glasses: 'round', body: 'sweater', floating: 'star', particles: 'sparkles', pattern: 'stripes'), size: 100, animate: false)),
            SizedBox(width: 112, height: 124, child: CompanionView(species: speciesById('dog'), look: const CompanionLook(hat: 'crown', neck: 'bow', expression: 'wink'), pose: CompanionPose.wave, size: 100, animate: false)),
            SizedBox(width: 112, height: 124, child: CompanionView(species: speciesById('fox'), look: const CompanionLook(hat: 'santa', body: 'hoodie'), pose: CompanionPose.sleep, size: 100, animate: false)),
          ]),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    if (out != null) {
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
