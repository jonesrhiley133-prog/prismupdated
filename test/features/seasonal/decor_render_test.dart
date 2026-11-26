import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decor_painter.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';

DecorScene _scene(
  List<DecorItem> items, {
  DeviceClass device = DeviceClass.mobile,
  DecoLayerSettings? layers,
}) => DecorScene(
  items: items,
  layers: layers ?? const DecoLayerSettings(maxAnimated: 40),
  device: device,
  safe: const EdgeInsets.only(top: 24, bottom: 16),
);

Widget _phone(
  DecorScene scene,
  double t, {
  double w = 180,
  double h = 320,
  Color bg = const Color(0xFFF6F1FA),
}) => SizedBox(
  width: w,
  height: h,
  child: ClipRect(
    child: ColoredBox(
      color: bg,
      child: Stack(
        children: [
          // A stand-in for Prism's own UI underneath.
          for (var i = 0; i < 4; i++)
            Positioned(
              left: 12,
              right: 12,
              top: 70.0 + i * 52,
              height: 42,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 52,
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.9)),
          ),
          for (final layers in [
            {DecoLayer.staticDeco},
            {DecoLayer.animated},
            {DecoLayer.ambient},
          ])
            Positioned.fill(
              child: CustomPaint(
                painter: DecorPainter(scene: scene, t: t, layersToDraw: layers),
              ),
            ),
        ],
      ),
    ),
  ),
);

void main() {
  test(
    'every look builds scene items and a first frame paints without errors',
    () {
      for (final c in seasonalCollections) {
        for (final v in c.variations) {
          final scene = _scene(arrangementForVariation(v));
          final rec = ui.PictureRecorder();
          final canvas = Canvas(rec);
          for (final layers in [
            {DecoLayer.staticDeco},
            {DecoLayer.animated},
            {DecoLayer.ambient},
          ]) {
            DecorPainter(
              scene: scene,
              t: 3.7,
              layersToDraw: layers,
            ).paint(canvas, const Size(390, 780));
          }
          rec.endRecording().dispose();
        }
      }
    },
  );

  test(
    'off, minimal and reduced layer settings draw nothing they should not',
    () {
      final v = variationById('christmas.0')!;
      int count(DecoLayerSettings l) {
        final scene = _scene(arrangementForVariation(v), layers: l);
        return [
          for (final i in scene.items)
            if (i.enabled && l.on(i.layer) && i.kind != DecoKind.interactive) i,
        ].length;
      }

      expect(count(const DecoLayerSettings(enabled: {})), 0);
      expect(
        count(const DecoLayerSettings().forMode(DecoPerformance.minimal)),
        lessThan(
          count(const DecoLayerSettings().forMode(DecoPerformance.immersive)),
        ),
      );
    },
  );

  testWidgets('contact sheet of looks', (tester) async {
    final out = Platform.environment['SEASON_SHEET'];
    final emoji = File('assets/fonts/NotoColorEmoji.ttf');
    if (emoji.existsSync()) {
      final loader = FontLoader('NotoColorEmoji')
        ..addFont(Future.value(ByteData.sublistView(emoji.readAsBytesSync())));
      await tester.runAsync(loader.load);
    }
    final picks = [
      'christmas.0',
      'christmas.7',
      'christmas.17',
      'halloween.1',
      'halloween.8',
      'valentine.3',
      'cherryblossom.0',
      'diwali.0',
      'ramadan.1',
      'autumn.0',
      'winter.0',
      'summer.0',
      'rainy.0',
      'easter.2',
      'hanukkah.1',
      'pride.0',
      'monsoon.0',
      'lunarnewyear.0',
    ];
    final key = GlobalKey();
    const cols = 6;
    tester.view.physicalSize = Size(
      cols * 190 + 10,
      (picks.length / cols).ceil() * 330 + 10,
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF333333),
          body: RepaintBoundary(
            key: key,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final id in picks)
                  () {
                    final v = variationById(id)!;
                    final dark =
                        id.startsWith('halloween') ||
                        id.contains('7') ||
                        v.palette.id == 'midnight';
                    return _phone(
                      _scene(arrangementForVariation(v)),
                      2.4,
                      bg: dark
                          ? const Color(0xFF241B33)
                          : const Color(0xFFF6F1FA),
                    );
                  }(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    if (out != null) {
      await tester.runAsync(() async {
        final b =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File(out).writeAsBytesSync(Uint8List.view(data!.buffer));
      });
    }
  });
}
