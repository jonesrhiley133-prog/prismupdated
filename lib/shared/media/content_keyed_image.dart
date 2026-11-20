import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Like [MemoryImage], but cached by the bytes' content instead of the
/// [Uint8List] instance.
///
/// Database streams hand back a new list for the same image every time a
/// row is re-read (a list row scrolling back into view, a sync re-saving an
/// unchanged avatar). [MemoryImage] treats each new list as a new image and
/// decodes it again; this provider finds the earlier decode in the
/// [ImageCache] instead.
@immutable
class ContentKeyedMemoryImage extends ImageProvider<ContentKeyedMemoryImage> {
  ContentKeyedMemoryImage(this.bytes, {this.scale = 1.0})
    : _hash = _contentHash(bytes);

  final Uint8List bytes;
  final double scale;
  final int _hash;

  static final Expando<int> _hashes = Expando<int>('contentHash');

  /// FNV-1a over a sample of the bytes plus the length: fast for large
  /// images, and collisions would need identical length and sampled bytes.
  static int _contentHash(Uint8List b) {
    final cached = _hashes[b];
    if (cached != null) return cached;
    var h = 0x811c9dc5 ^ b.length;
    final step = b.length <= 4096 ? 1 : b.length ~/ 4096;
    for (var i = 0; i < b.length; i += step) {
      h = ((h ^ b[i]) * 0x01000193) & 0xffffffff;
    }
    // Always include the tail, where encoders put trailers and checksums.
    for (var i = b.length > 64 ? b.length - 64 : 0; i < b.length; i++) {
      h = ((h ^ b[i]) * 0x01000193) & 0xffffffff;
    }
    return _hashes[b] = h;
  }

  @override
  Future<ContentKeyedMemoryImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ContentKeyedMemoryImage>(this);

  @override
  ImageStreamCompleter loadImage(
    ContentKeyedMemoryImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: key.scale,
      debugLabel: 'ContentKeyedMemoryImage(${key.bytes.length} bytes)',
    );
  }

  Future<ui.Codec> _load(
    ContentKeyedMemoryImage key,
    ImageDecoderCallback decode,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(key.bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContentKeyedMemoryImage) return false;
    if (other._hash != _hash || other.scale != scale) return false;
    if (identical(other.bytes, bytes)) return true;
    return other.bytes.length == bytes.length;
  }

  @override
  int get hashCode => Object.hash(_hash, bytes.length, scale);

  @override
  String toString() =>
      'ContentKeyedMemoryImage(${bytes.length} bytes, scale: $scale)';
}
