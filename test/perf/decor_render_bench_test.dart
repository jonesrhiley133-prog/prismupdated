import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decor_painter.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';

/// Rendering benchmark for a heavily decorated screen: several living looks
/// at once, every decoration with a soft shadow and transparency (the most
/// expensive combination the Decoration Studio allows). Each frame is
/// recorded and rasterised, so both drawing and raster work are measured.
///
/// Run on its own: flutter test test/perf/decor_render_bench_test.dart
List<DecorItem> heavyScene() {
  final out = <DecorItem>[];
  for (final c in livingCollections.take(4)) {
    for (final i in arrangementForVariation(c.variations.first)) {
      i.shadow = 0.6;
      i.opacity = 0.8;
      out.add(i);
    }
  }
  return out;
}

void main() {
  testWidgets('decor render benchmark', (tester) async {
    final items = heavyScene();
    final scene = DecorScene(
      items: items,
      layers: const DecoLayerSettings(particleDensity: 1, maxAnimated: 30),
    );
    const size = Size(412, 860);
    await tester.runAsync(() async {
      Future<int> run(Set<DecoLayer> layers, int frames) async {
        final sw = Stopwatch()..start();
        for (var f = 0; f < frames; f++) {
          final rec = ui.PictureRecorder();
          final canvas = Canvas(rec);
          DecorPainter(
            scene: scene,
            t: f / 60,
            layersToDraw: layers,
          ).paint(canvas, size);
          final pic = rec.endRecording();
          final img = await pic.toImage(412, 860);
          img.dispose();
          pic.dispose();
        }
        return sw.elapsedMicroseconds;
      }

      Future<int> runScene(
        DecorScene sc,
        Set<DecoLayer> layers,
        int frames,
      ) async {
        final sw = Stopwatch()..start();
        for (var f = 0; f < frames; f++) {
          final rec = ui.PictureRecorder();
          DecorPainter(
            scene: sc,
            t: f / 60,
            layersToDraw: layers,
          ).paint(Canvas(rec), size);
          final pic = rec.endRecording();
          (await pic.toImage(412, 860)).dispose();
          pic.dispose();
        }
        return sw.elapsedMicroseconds;
      }

      // Warm up glyph caches.
      await run({
        DecoLayer.staticDeco,
        DecoLayer.animated,
        DecoLayer.ambient,
      }, 5);
      final stat = await run({DecoLayer.staticDeco}, 60);
      final anim = await run({DecoLayer.animated}, 120);
      final amb = await run({DecoLayer.ambient}, 120);
      // Each shadow quality level (what the engine picks per preset or
      // as the adaptive level drops).
      for (final lvl in [3, 2, 1, 0]) {
        final sc = DecorScene(
          items: items,
          layers: const DecoLayerSettings(particleDensity: 1, maxAnimated: 30),
          shadowLevel: lvl,
        );
        final us = await runScene(sc, const {DecoLayer.animated}, 120);
        // ignore: avoid_print
        print(
          'BENCH shadowLevel=$lvl animated=${(us / 120 / 1000).toStringAsFixed(2)}ms/frame',
        );
      }
      // Static layer under overlay rebuilds: an equal scene must not repaint.
      final again = DecorScene(
        items: items,
        layers: const DecoLayerSettings(particleDensity: 1, maxAnimated: 30),
      );
      final repaint =
          DecorPainter(
            scene: again,
            t: 0,
            layersToDraw: const {DecoLayer.staticDeco},
          ).shouldRepaint(
            DecorPainter(
              scene: scene,
              t: 0,
              layersToDraw: {DecoLayer.staticDeco},
            ),
          );
      // ignore: avoid_print
      print('BENCH static repaint on unchanged rebuild: $repaint');
      expect(repaint, isFalse);
      // ignore: avoid_print
      print(
        'BENCH items=${items.length} '
        'static=${(stat / 60 / 1000).toStringAsFixed(2)}ms/frame '
        'animated=${(anim / 120 / 1000).toStringAsFixed(2)}ms/frame '
        'ambient=${(amb / 120 / 1000).toStringAsFixed(2)}ms/frame',
      );
    });
  });
}
