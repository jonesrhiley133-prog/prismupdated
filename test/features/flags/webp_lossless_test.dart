import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:prism_plurality/features/flags/webp_lossless.dart';

void main() {
  test('round-trips exactly through a WebP decoder', () {
    for (final (w, h, alpha) in [(1, 1, false), (37, 19, true), (120, 80, false)]) {
      final px = Uint8List(w * h * 4);
      for (var i = 0; i < w * h; i++) {
        px[i * 4] = (i * 7) & 255;
        px[i * 4 + 1] = (i * 13) & 255;
        px[i * 4 + 2] = (i * 29) & 255;
        px[i * 4 + 3] = alpha ? (i * 3) & 255 : 255;
      }
      final webp = encodeWebpLossless(w, h, px);
      final back = img.decodeWebP(webp);
      expect(back, isNotNull, reason: '${w}x$h');
      expect([back!.width, back.height], [w, h]);
      for (var i = 0; i < w * h; i++) {
        final p = back.getPixel(i % w, i ~/ w);
        expect([p.r, p.g, p.b, if (alpha) p.a], [px[i * 4], px[i * 4 + 1], px[i * 4 + 2], if (alpha) px[i * 4 + 3]], reason: 'pixel $i of ${w}x$h');
      }
    }
  });
}
