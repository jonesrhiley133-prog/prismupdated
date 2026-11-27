import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';
import 'package:prism_plurality/features/social/services/social_media.dart';

/// An imported picture used as a tiling texture, with the same scale,
/// opacity and blend controls as the built-in ones.
class ScrapCustomTexture extends ConsumerStatefulWidget {
  const ScrapCustomTexture({
    super.key,
    required this.media,
    required this.style,
  });
  final String media;
  final ScrapTextureStyle style;

  @override
  ConsumerState<ScrapCustomTexture> createState() => _ScrapCustomTextureState();
}

class _ScrapCustomTextureState extends ConsumerState<ScrapCustomTexture> {
  ui.Image? _image;
  String? _loaded;

  Future<void> _decode(String id, List<int> bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        targetWidth: 512,
      );
      final f = await codec.getNextFrame();
      if (!mounted || widget.media != id) return;
      setState(() => _image = f.image);
    } catch (_) {
      // An unreadable picture just draws nothing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = ref.watch(socialImageProvider(widget.media));
    if (bytes != null && _loaded != widget.media) {
      _loaded = widget.media;
      _image = null;
      unawaited(_decode(widget.media, bytes));
    }
    final img = _image;
    if (img == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _TilePainter(
          img,
          widget.style.scale,
          widget.style.opacity,
          scrapBlendModes[widget.style.blend] ?? BlendMode.srcOver,
        ),
      ),
    );
  }
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.image, this.scale, this.opacity, this.blend);
  final ui.Image image;
  final double scale, opacity;
  final BlendMode blend;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // One tile is about a third of the width at scale 1.
    final tile = size.width / 3 * scale.clamp(0.2, 4.0);
    final k = tile / image.width;
    final m = Matrix4.identity()..scale(k, k);
    final paint = Paint()
      ..shader = ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        m.storage,
        filterQuality: FilterQuality.medium,
      )
      ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..blendMode = blend;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_TilePainter o) =>
      o.image != image ||
      o.scale != scale ||
      o.opacity != opacity ||
      o.blend != blend;
}
