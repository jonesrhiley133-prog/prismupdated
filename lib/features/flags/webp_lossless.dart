import 'dart:typed_data';

/// A tiny lossless WebP (VP8L) encoder, enough for flag exports.
///
/// It writes every pixel as literal ARGB with fixed 8-bit prefix codes and
/// no transforms. Files are larger than a full encoder would make, but they
/// are valid, exact and need no native code.
Uint8List encodeWebpLossless(int width, int height, Uint8List rgba) {
  assert(width > 0 && width <= 16384 && height > 0 && height <= 16384);
  assert(rgba.length >= width * height * 4);
  final w = _BitWriter();
  w.bits(0x2f, 8); // signature
  w.bits(width - 1, 14);
  w.bits(height - 1, 14);
  var alpha = false;
  for (var i = 3; i < width * height * 4; i += 4) {
    if (rgba[i] != 255) {
      alpha = true;
      break;
    }
  }
  w.bits(alpha ? 1 : 0, 1);
  w.bits(0, 3); // version
  w.bits(0, 1); // no transforms
  w.bits(0, 1); // no colour cache
  w.bits(0, 1); // no meta prefix codes
  // Green (280 symbols), red, blue, alpha (256 each): all literals length 8.
  _fixedCode(w, 280);
  _fixedCode(w, 256);
  _fixedCode(w, 256);
  _fixedCode(w, 256);
  // Distance: a simple code with one symbol (never used).
  w.bits(1, 1); // simple
  w.bits(0, 1); // one symbol
  w.bits(0, 1); // 1-bit symbol
  w.bits(0, 1); // symbol 0
  final n = width * height;
  for (var p = 0; p < n; p++) {
    final o = p * 4;
    w.code8(rgba[o + 1]); // green
    w.code8(rgba[o]); // red
    w.code8(rgba[o + 2]); // blue
    w.code8(rgba[o + 3]); // alpha
  }
  final data = w.finish();
  final chunk = data.length + (data.length.isOdd ? 1 : 0);
  final out = BytesBuilder();
  void u32(int v) =>
      out.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
  out.add('RIFF'.codeUnits);
  u32(4 + 8 + chunk);
  out.add('WEBP'.codeUnits);
  out.add('VP8L'.codeUnits);
  u32(data.length);
  out.add(data);
  if (data.length.isOdd) out.addByte(0);
  return out.toBytes();
}

/// A normal prefix code where symbols 0–255 have length 8 and the rest 0.
void _fixedCode(_BitWriter w, int alphabet) {
  w.bits(0, 1); // normal code
  // Code-length code: lengths for symbols 0 and 8 are 1, the rest 0.
  // Order: 17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8 → 12 entries.
  w.bits(12 - 4, 4);
  const order = [17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8];
  for (final s in order) {
    w.bits(s == 0 || s == 8 ? 1 : 0, 3);
  }
  w.bits(0, 1); // max_symbol = alphabet size
  // Canonical codes: symbol 0 → '0', symbol 8 → '1'.
  for (var i = 0; i < alphabet; i++) {
    w.bits(i < 256 ? 1 : 0, 1);
  }
}

class _BitWriter {
  final _buf = BytesBuilder(copy: false);
  final _chunk = Uint8List(1 << 16);
  int _pos = 0;
  int _acc = 0;
  int _n = 0;

  void bits(int value, int count) {
    for (var i = 0; i < count; i++) {
      _acc |= ((value >> i) & 1) << _n;
      if (++_n == 8) _flush();
    }
  }

  /// An 8-bit canonical code: most significant bit first.
  void code8(int v) {
    for (var i = 7; i >= 0; i--) {
      _acc |= ((v >> i) & 1) << _n;
      if (++_n == 8) _flush();
    }
  }

  void _flush() {
    _chunk[_pos++] = _acc;
    _acc = 0;
    _n = 0;
    if (_pos == _chunk.length) {
      _buf.add(Uint8List.fromList(_chunk));
      _pos = 0;
    }
  }

  Uint8List finish() {
    if (_n > 0) _flush();
    if (_pos > 0) _buf.add(Uint8List.sublistView(_chunk, 0, _pos));
    return _buf.toBytes();
  }
}
