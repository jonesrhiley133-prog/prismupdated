import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/companions/companion_art.dart';
import 'package:prism_plurality/features/companions/companion_species.dart';

const _px = 64;

/// Coverage mask of a species drawn in its default look (no accessories).
Future<Uint8List> _mask(Species s) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  CreaturePainter(
    species: s,
    look: const CompanionLook(),
    pose: CompanionPose.sit,
    t: ValueNotifier(0.3),
    particles: false,
  ).paint(canvas, const ui.Size(100.0 * _px / 100, 100.0 * _px / 100));
  final img = await rec.endRecording().toImage(_px, _px);
  final data = (await img.toByteData())!.buffer.asUint8List();
  final out = Uint8List(_px * _px);
  for (var i = 0; i < out.length; i++) {
    out[i] = data[i * 4 + 3] > 96 ? 1 : 0;
  }
  return out;
}

double _diff(Uint8List a, Uint8List b) {
  var x = 0, u = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) x++;
    if (a[i] == 1 || b[i] == 1) u++;
  }
  return u == 0 ? 0 : x / u;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every species has a clearly different silhouette', () async {
    final masks = {for (final s in speciesCatalog) s.id: await _mask(s)};
    final pairs = <(double, String, String)>[];
    final ids = masks.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        pairs.add((_diff(masks[ids[i]]!, masks[ids[j]]!), ids[i], ids[j]));
      }
    }
    pairs.sort((a, b) => a.$1.compareTo(b.$1));
    // ignore: avoid_print
    print(
      'closest: ${pairs.take(15).map((p) => '${p.$2}/${p.$3} ${(p.$1 * 100).round()}%').join(', ')}',
    );
    final tooClose = pairs.where((p) => p.$1 < 0.12).toList();
    expect(
      tooClose.map((p) => '${p.$2}/${p.$3}'),
      isEmpty,
      reason: 'These pairs look nearly identical',
    );
  });

  test('accessory adjustments and picture fit survive saving', () {
    const look = CompanionLook(hat: 'beanie', adjust: {'hat': AccessoryAdjust(dx: 4, dy: -3, scale: 1.4, rotation: 15, mirror: true, opacity: 0.6, layer: 2)});
    final back = CompanionLook.fromJson(look.toJson());
    final a = back.adjustOf('hat');
    expect([a.dx, a.dy, a.scale, a.rotation, a.mirror, a.opacity, a.layer], [4, -3, 1.4, 15, true, 0.6, 2]);
    expect(back.adjustOf('neck').isIdentity, isTrue);
    const fit = ArtFit(x: 0.1, scale: 1.5, crop: 'circle', background: 'soft', headX: 40, neckY: 70);
    final f = ArtFit.fromJson(fit.toJson());
    expect([f.x, f.scale, f.crop, f.background, f.headX, f.neckY], [0.1, 1.5, 'circle', 'soft', 40, 70]);
  });
}
