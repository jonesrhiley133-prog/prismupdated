import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// scrypt (RFC 7914) written for speed when compiled to JavaScript: the
/// Salsa20/8 core works on local variables and typed arrays only. Produces
/// exactly the same keys as pointycastle's `Scrypt`, several times faster
/// in browsers, where the import runs on the page's only thread.
Uint8List fastScrypt(
  Uint8List password,
  Uint8List salt, {
  required int n,
  required int r,
  required int p,
  required int dkLen,
}) {
  final blockWords = 32 * r;
  final b = _pbkdf2(password, salt, p * 128 * r);
  final bWords = Uint32List(p * blockWords);
  final bd = ByteData.sublistView(b);
  for (var i = 0; i < bWords.length; i++) {
    bWords[i] = bd.getUint32(i * 4, Endian.little);
  }
  final x = Uint32List(blockWords);
  final y = Uint32List(blockWords);
  final v = Uint32List(blockWords * n);
  final t = Uint32List(16);
  for (var k = 0; k < p; k++) {
    final off = k * blockWords;
    for (var i = 0; i < blockWords; i++) {
      x[i] = bWords[off + i];
    }
    for (var i = 0; i < n; i++) {
      v.setRange(i * blockWords, (i + 1) * blockWords, x);
      _blockMix(x, y, t, r);
    }
    for (var i = 0; i < n; i++) {
      final j = x[(2 * r - 1) * 16] & (n - 1);
      final vo = j * blockWords;
      for (var w = 0; w < blockWords; w++) {
        x[w] ^= v[vo + w];
      }
      _blockMix(x, y, t, r);
    }
    for (var i = 0; i < blockWords; i++) {
      bWords[off + i] = x[i];
    }
  }
  final out = Uint8List(bWords.length * 4);
  final od = ByteData.sublistView(out);
  for (var i = 0; i < bWords.length; i++) {
    od.setUint32(i * 4, bWords[i], Endian.little);
  }
  return _pbkdf2(password, out, dkLen);
}

Uint8List _pbkdf2(Uint8List password, Uint8List salt, int len) {
  final d = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, 1, len));
  return d.process(password);
}

/// BlockMix with Salsa20/8; result written back into [b], using [y] as
/// scratch.
void _blockMix(Uint32List b, Uint32List y, Uint32List t, int r) {
  final last = (2 * r - 1) * 16;
  for (var i = 0; i < 16; i++) {
    t[i] = b[last + i];
  }
  for (var i = 0; i < 2 * r; i++) {
    final o = i * 16;
    for (var k = 0; k < 16; k++) {
      t[k] ^= b[o + k];
    }
    _salsa8(t);
    // Even blocks go to the first half, odd to the second.
    final dst = (i.isEven ? (i ~/ 2) : (r + i ~/ 2)) * 16;
    for (var k = 0; k < 16; k++) {
      y[dst + k] = t[k];
    }
  }
  b.setAll(0, y);
}

const _m = 0xffffffff;
int _rotl(int v, int c) => ((v << c) | (v >> (32 - c))) & _m;

void _salsa8(Uint32List s) {
  var x0 = s[0],
      x1 = s[1],
      x2 = s[2],
      x3 = s[3],
      x4 = s[4],
      x5 = s[5],
      x6 = s[6],
      x7 = s[7];
  var x8 = s[8],
      x9 = s[9],
      x10 = s[10],
      x11 = s[11],
      x12 = s[12],
      x13 = s[13],
      x14 = s[14],
      x15 = s[15];
  for (var i = 0; i < 8; i += 2) {
    x4 ^= _rotl((x0 + x12) & _m, 7);
    x8 ^= _rotl((x4 + x0) & _m, 9);
    x12 ^= _rotl((x8 + x4) & _m, 13);
    x0 ^= _rotl((x12 + x8) & _m, 18);
    x9 ^= _rotl((x5 + x1) & _m, 7);
    x13 ^= _rotl((x9 + x5) & _m, 9);
    x1 ^= _rotl((x13 + x9) & _m, 13);
    x5 ^= _rotl((x1 + x13) & _m, 18);
    x14 ^= _rotl((x10 + x6) & _m, 7);
    x2 ^= _rotl((x14 + x10) & _m, 9);
    x6 ^= _rotl((x2 + x14) & _m, 13);
    x10 ^= _rotl((x6 + x2) & _m, 18);
    x3 ^= _rotl((x15 + x11) & _m, 7);
    x7 ^= _rotl((x3 + x15) & _m, 9);
    x11 ^= _rotl((x7 + x3) & _m, 13);
    x15 ^= _rotl((x11 + x7) & _m, 18);
    x1 ^= _rotl((x0 + x3) & _m, 7);
    x2 ^= _rotl((x1 + x0) & _m, 9);
    x3 ^= _rotl((x2 + x1) & _m, 13);
    x0 ^= _rotl((x3 + x2) & _m, 18);
    x6 ^= _rotl((x5 + x4) & _m, 7);
    x7 ^= _rotl((x6 + x5) & _m, 9);
    x4 ^= _rotl((x7 + x6) & _m, 13);
    x5 ^= _rotl((x4 + x7) & _m, 18);
    x11 ^= _rotl((x10 + x9) & _m, 7);
    x8 ^= _rotl((x11 + x10) & _m, 9);
    x9 ^= _rotl((x8 + x11) & _m, 13);
    x10 ^= _rotl((x9 + x8) & _m, 18);
    x12 ^= _rotl((x15 + x14) & _m, 7);
    x13 ^= _rotl((x12 + x15) & _m, 9);
    x14 ^= _rotl((x13 + x12) & _m, 13);
    x15 ^= _rotl((x14 + x13) & _m, 18);
  }
  s[0] = (s[0] + x0) & _m;
  s[1] = (s[1] + x1) & _m;
  s[2] = (s[2] + x2) & _m;
  s[3] = (s[3] + x3) & _m;
  s[4] = (s[4] + x4) & _m;
  s[5] = (s[5] + x5) & _m;
  s[6] = (s[6] + x6) & _m;
  s[7] = (s[7] + x7) & _m;
  s[8] = (s[8] + x8) & _m;
  s[9] = (s[9] + x9) & _m;
  s[10] = (s[10] + x10) & _m;
  s[11] = (s[11] + x11) & _m;
  s[12] = (s[12] + x12) & _m;
  s[13] = (s[13] + x13) & _m;
  s[14] = (s[14] + x14) & _m;
  s[15] = (s[15] + x15) & _m;
}
