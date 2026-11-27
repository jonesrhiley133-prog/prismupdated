import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/scrapbook/scrap_texture_painter.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';

void main() {
  test('there are at least 60 textures in 18 categories, 30+ materials', () {
    expect(scrapTextures.length, greaterThanOrEqualTo(60));
    expect(scrapTextures.map((t) => t.category).toSet().length, 18);
    expect(scrapTextureCategories.length, 18);
    for (final t in scrapTextures) {
      expect(scrapTextureCategories, contains(t.category), reason: t.id);
    }
    expect(scrapMaterials.length, greaterThanOrEqualTo(30));
    for (final m in scrapMaterials) {
      expect(scrapMaterialCategories, contains(m.category), reason: m.id);
    }
    final ids = [...scrapTextures, ...scrapMaterials].map((t) => t.id);
    expect(ids.toSet().length, ids.length);
  });

  test('every texture and material paints, and styles round-trip', () {
    for (final t in [...scrapTextures, ...scrapMaterials]) {
      final rec = ui.PictureRecorder();
      paintScrapTexture(
        Canvas(rec),
        const Size(200, 280),
        kind: t.kind,
        c1: t.c1,
        c2: t.c2,
        seed: t.seed,
        scale: t.scale,
      );
      rec.endRecording().dispose();
    }
    const s = ScrapTextureStyle(
      id: 'cl-linen',
      intensity: 1.5,
      scale: 2,
      opacity: 0.5,
      blend: 'multiply',
      color: 0xFF112233,
    );
    final back = ScrapTextureStyle.fromJson(s.toJson());
    expect(back.id, 'cl-linen');
    expect(back.blend, 'multiply');
    expect(back.opacity, 0.5);
    expect(back.color, 0xFF112233);
    expect(ScrapTextureStyle.fromJson('junk').id, 'plain');
  });
}
