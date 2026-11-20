import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/shared/media/content_keyed_image.dart';

void main() {
  Uint8List bytes(int n, [int seed = 0]) =>
      Uint8List.fromList(List.generate(n, (i) => (i * 31 + seed) & 0xff));

  test('equal content in a new list is the same cache key', () {
    final a = ContentKeyedMemoryImage(bytes(50000));
    final b = ContentKeyedMemoryImage(bytes(50000));
    expect(identical(a.bytes, b.bytes), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('different content is a different key', () {
    expect(
      ContentKeyedMemoryImage(bytes(50000)),
      isNot(ContentKeyedMemoryImage(bytes(50000, 7))),
    );
    expect(
      ContentKeyedMemoryImage(bytes(1000)),
      isNot(ContentKeyedMemoryImage(bytes(1001))),
    );
  });

  test('a change in the trailing bytes changes the key', () {
    final a = bytes(80000);
    final b = Uint8List.fromList(a)..[a.length - 3] ^= 0xff;
    expect(ContentKeyedMemoryImage(a), isNot(ContentKeyedMemoryImage(b)));
  });

  test('scale is part of the key', () {
    final b = bytes(2000);
    expect(
      ContentKeyedMemoryImage(b),
      isNot(ContentKeyedMemoryImage(b, scale: 2)),
    );
  });
}
