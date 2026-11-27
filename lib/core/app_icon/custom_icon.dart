import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show IconData;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show StringCharacters;

import 'package:prism_plurality/core/app_icon/icon_art.dart';
import 'package:prism_plurality/features/scrapbook/scrap_texture_painter.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';

/// Aura styles for a custom icon.
enum IconAura { none, glow, halo, rays, stars, nebula }

/// What sits in the middle of a custom icon.
enum IconCenter { prism, symbol, emoji, photo }

/// How the background is painted.
enum IconBackground { linear, radial, solid }

/// Symbols that can replace the Prism pyramid (keys are stored).
const Map<String, IconData> iconSymbols = {
  'usersThree': PhosphorIconsFill.usersThree,
  'intersectThree': PhosphorIconsFill.intersectThree,
  'handHeart': PhosphorIconsFill.handHeart,
  'handshake': PhosphorIconsFill.handshake,
  'houseLine': PhosphorIconsFill.houseLine,
  'door': PhosphorIconsFill.door,
  'moonStars': PhosphorIconsFill.moonStars,
  'star': PhosphorIconsFill.star,
  'sparkle': PhosphorIconsFill.sparkle,
  'heart': PhosphorIconsFill.heart,
  'butterfly': PhosphorIconsFill.butterfly,
  'flowerLotus': PhosphorIconsFill.flowerLotus,
  'flower': PhosphorIconsFill.flower,
  'flowerTulip': PhosphorIconsFill.flowerTulip,
  'eye': PhosphorIconsFill.eye,
  'infinity': PhosphorIconsBold.infinity,
  'fire': PhosphorIconsFill.fire,
  'shootingStar': PhosphorIconsFill.shootingStar,
  'planet': PhosphorIconsFill.planet,
  'snowflake': PhosphorIconsBold.snowflake,
  'lightning': PhosphorIconsFill.lightning,
  'feather': PhosphorIconsFill.feather,
  'yinYang': PhosphorIconsFill.yinYang,
  'crown': PhosphorIconsFill.crown,
  'leaf': PhosphorIconsFill.leaf,
  'tree': PhosphorIconsFill.tree,
  'cactus': PhosphorIconsFill.cactus,
  'sun': PhosphorIconsFill.sun,
  'cloud': PhosphorIconsFill.cloud,
  'rainbow': PhosphorIconsFill.rainbow,
  'drop': PhosphorIconsFill.drop,
  'waves': PhosphorIconsFill.waves,
  'mountains': PhosphorIconsFill.mountains,
  'cat': PhosphorIconsFill.cat,
  'pawPrint': PhosphorIconsFill.pawPrint,
  'bird': PhosphorIconsFill.bird,
  'fish': PhosphorIconsFill.fishSimple,
  'ghost': PhosphorIconsFill.ghost,
  'skull': PhosphorIconsFill.skull,
  'alien': PhosphorIconsFill.alien,
  'rocket': PhosphorIconsFill.rocket,
  'atom': PhosphorIconsFill.atom,
  'musicNotes': PhosphorIconsFill.musicNotes,
  'gameController': PhosphorIconsFill.gameController,
  'paintBrush': PhosphorIconsFill.paintBrush,
  'magicWand': PhosphorIconsFill.magicWand,
  'shieldStar': PhosphorIconsFill.shieldStar,
  'key': PhosphorIconsFill.key,
  'compass': PhosphorIconsFill.compass,
  'peace': PhosphorIconsFill.peace,
  'hand': PhosphorIconsFill.hand,
  'heartbeat': PhosphorIconsFill.heartbeat,
  'spiral': PhosphorIconsBold.spiral,
  'hexagon': PhosphorIconsFill.hexagon,
  'circlesThree': PhosphorIconsFill.circlesThree,
  'diamond': PhosphorIconsFill.diamond,
};

/// A custom app icon, designed in Settings › Appearance › App icon.
class CustomIconSpec {
  const CustomIconSpec({
    this.top = 0xFF2B1B5A,
    this.bottom = 0xFF0B0716,
    this.aura = IconAura.glow,
    this.auraColor = 0xFFB98CFF,
    this.center = IconCenter.prism,
    this.emoji = '✨',
    this.photo,
    this.symbol = 'moonStars',
    this.symbolColor = 0xFFF3ECFF,
    this.background = IconBackground.linear,
    this.art,
    this.texture,
    this.border = 0,
    this.borderColor = 0xFFFFFFFF,
    this.sticker,
    this.text = '',
    this.textColor = 0xFFFFFFFF,
    this.shadow = false,
    this.opacity = 1,
    this.overlay = 'none',
    this.shape = 'squircle',
  });

  /// A patterned backdrop from the icon gallery's painter (stars, knit,
  /// stained glass…), drawn in [top], [bottom] and [auraColor].
  final String? art;

  /// A scrapbook texture laid over the background.
  final String? texture;

  /// Frame thickness (0–1) and colour, drawn inside the launcher safe zone.
  final double border;
  final int borderColor;

  /// An emoji sticker in the lower corner.
  final String? sticker;

  /// A short label (up to 6 characters).
  final String text;
  final int textColor;

  /// A soft shadow under the centre piece.
  final bool shadow;

  /// 0.2–1: how solid the centre piece is.
  final double opacity;

  /// none | gloss | vignette | sparkles
  final String overlay;

  /// The mask used for previews: squircle | circle | rounded | teardrop |
  /// square. (Launchers apply their own; this shows how it may look.)
  final String shape;

  final int top;
  final int bottom;
  final IconAura aura;
  final int auraColor;
  final IconCenter center;
  final String emoji;
  final Uint8List? photo;
  final String symbol;
  final int symbolColor;
  final IconBackground background;

  CustomIconSpec copyWith({
    int? top,
    int? bottom,
    IconAura? aura,
    int? auraColor,
    IconCenter? center,
    String? emoji,
    Uint8List? photo,
    String? symbol,
    int? symbolColor,
    IconBackground? background,
    Object? art = _k,
    Object? texture = _k,
    double? border,
    int? borderColor,
    Object? sticker = _k,
    String? text,
    int? textColor,
    bool? shadow,
    double? opacity,
    String? overlay,
    String? shape,
  }) => CustomIconSpec(
    top: top ?? this.top,
    bottom: bottom ?? this.bottom,
    aura: aura ?? this.aura,
    auraColor: auraColor ?? this.auraColor,
    center: center ?? this.center,
    emoji: emoji ?? this.emoji,
    photo: photo ?? this.photo,
    symbol: symbol ?? this.symbol,
    symbolColor: symbolColor ?? this.symbolColor,
    background: background ?? this.background,
    art: identical(art, _k) ? this.art : art as String?,
    texture: identical(texture, _k) ? this.texture : texture as String?,
    border: border ?? this.border,
    borderColor: borderColor ?? this.borderColor,
    sticker: identical(sticker, _k) ? this.sticker : sticker as String?,
    text: text ?? this.text,
    textColor: textColor ?? this.textColor,
    shadow: shadow ?? this.shadow,
    opacity: opacity ?? this.opacity,
    overlay: overlay ?? this.overlay,
    shape: shape ?? this.shape,
  );

  static const _k = Object();

  Map<String, Object?> toJson() => {
    'top': top,
    'bottom': bottom,
    'aura': aura.name,
    'auraColor': auraColor,
    'center': center.name,
    'emoji': emoji,
    'photo': photo == null ? null : base64Encode(photo!),
    'symbol': symbol,
    'symbolColor': symbolColor,
    'background': background.name,
    'art': ?art,
    'texture': ?texture,
    if (border > 0) 'border': border,
    if (border > 0) 'borderColor': borderColor,
    'sticker': ?sticker,
    if (text.isNotEmpty) 'text': text,
    if (text.isNotEmpty) 'textColor': textColor,
    if (shadow) 'shadow': true,
    if (opacity < 1) 'opacity': opacity,
    if (overlay != 'none') 'overlay': overlay,
    if (shape != 'squircle') 'shape': shape,
  };

  static CustomIconSpec fromJson(Map<String, Object?> j) => CustomIconSpec(
    top: (j['top'] as num?)?.toInt() ?? 0xFF2B1B5A,
    bottom: (j['bottom'] as num?)?.toInt() ?? 0xFF0B0716,
    aura:
        IconAura.values.where((a) => a.name == j['aura']).firstOrNull ??
        IconAura.glow,
    auraColor: (j['auraColor'] as num?)?.toInt() ?? 0xFFB98CFF,
    center:
        IconCenter.values.where((c) => c.name == j['center']).firstOrNull ??
        IconCenter.prism,
    emoji: (j['emoji'] as String?) ?? '✨',
    photo: j['photo'] is String ? base64Decode(j['photo']! as String) : null,
    symbol: iconSymbols.containsKey(j['symbol'])
        ? j['symbol']! as String
        : 'moonStars',
    symbolColor: (j['symbolColor'] as num?)?.toInt() ?? 0xFFF3ECFF,
    background:
        IconBackground.values
            .where((b) => b.name == j['background'])
            .firstOrNull ??
        IconBackground.linear,
    art: iconBackgrounds.contains(j['art']) ? j['art']! as String : null,
    texture: j['texture'] is String ? j['texture']! as String : null,
    border: ((j['border'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
    borderColor: (j['borderColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
    sticker: j['sticker'] is String ? j['sticker']! as String : null,
    text: j['text'] is String
        ? (j['text']! as String).characters.take(6).toString()
        : '',
    textColor: (j['textColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
    shadow: j['shadow'] == true,
    opacity: ((j['opacity'] as num?)?.toDouble() ?? 1).clamp(0.2, 1.0),
    overlay: const {'gloss', 'vignette', 'sparkles'}.contains(j['overlay'])
        ? j['overlay']! as String
        : 'none',
    shape:
        const {'circle', 'rounded', 'teardrop', 'square'}.contains(j['shape'])
        ? j['shape']! as String
        : 'squircle',
  );
}

/// The Prism mark, decoded once, for icon art.
Future<ui.Image> prismLogoImage() => _prism();

ui.Image? _prismCache;

Future<ui.Image> _prism() async {
  if (_prismCache != null) return _prismCache!;
  final data = await rootBundle.load(
    'assets/icon_layers/Prism-Logo-Foreground.png',
  );
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: 512,
  );
  return _prismCache = (await codec.getNextFrame()).image;
}

/// Draws [spec] as a square PNG ([size] px). Launchers apply their own
/// shape mask, so the art fills the whole square.
Future<Uint8List> renderCustomIcon(
  CustomIconSpec spec, {
  int size = 512,
}) async {
  final s = size.toDouble();
  final rect = Rect.fromLTWH(0, 0, s, s);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, rect);
  // Auras centre on the art: the Prism logo's visual centre sits at 49.3%.
  final center = Offset(
    s / 2,
    spec.center == IconCenter.prism ? s * 0.493 : s / 2,
  );
  final aura = Color(spec.auraColor);

  final bg = Paint();
  switch (spec.background) {
    case IconBackground.linear:
      bg.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(spec.top), Color(spec.bottom)],
      ).createShader(rect);
    case IconBackground.radial:
      bg.shader = RadialGradient(
        radius: 0.75,
        colors: [Color(spec.top), Color(spec.bottom)],
      ).createShader(rect);
    case IconBackground.solid:
      bg.color = Color(spec.top);
  }
  c.drawRect(rect, bg);
  if (spec.art != null) {
    paintIconArt(
      c,
      s,
      IconArt(
        bg: spec.art!,
        fg: 'none',
        logo: 'none',
        c1: spec.top,
        c2: spec.bottom,
        c3: spec.auraColor,
      ),
    );
  }
  final tex = spec.texture == null ? null : scrapTextureById(spec.texture!);
  if (tex != null) {
    c.saveLayer(rect, Paint()..color = const Color(0x66FFFFFF));
    paintScrapTexture(
      c,
      rect.size,
      kind: tex.kind,
      c1: Color(spec.top),
      c2: Color(spec.auraColor),
      seed: 11,
    );
    c.restore();
  }

  switch (spec.aura) {
    case IconAura.none:
      break;
    case IconAura.glow:
      c.drawCircle(
        center,
        s * 0.48,
        Paint()
          ..shader = RadialGradient(
            colors: [aura.withValues(alpha: 0.85), aura.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: s * 0.48)),
      );
    case IconAura.halo:
      c.drawCircle(
        center,
        s * 0.34,
        Paint()
          ..color = aura.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.04),
      );
      c.drawCircle(
        center,
        s * 0.34,
        Paint()
          ..color = Color.lerp(aura, const Color(0xFFFFFFFF), 0.6)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.012,
      );
      c.drawCircle(
        center,
        s * 0.3,
        Paint()
          ..shader = RadialGradient(
            colors: [aura.withValues(alpha: 0.35), aura.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: s * 0.3)),
      );
    case IconAura.rays:
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [aura.withValues(alpha: 0.7), aura.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: s * 0.75));
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + math.cos(a - 0.09) * s,
            center.dy + math.sin(a - 0.09) * s,
          )
          ..lineTo(
            center.dx + math.cos(a + 0.09) * s,
            center.dy + math.sin(a + 0.09) * s,
          )
          ..close();
        c.drawPath(path, paint);
      }
      c.drawCircle(
        center,
        s * 0.28,
        Paint()
          ..shader = RadialGradient(
            colors: [aura.withValues(alpha: 0.8), aura.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: s * 0.28)),
      );
    case IconAura.stars:
      final rnd = math.Random(42);
      for (var i = 0; i < 90; i++) {
        final p = Offset(rnd.nextDouble() * s, rnd.nextDouble() * s);
        c.drawCircle(
          p,
          s * (0.002 + rnd.nextDouble() * 0.006),
          Paint()
            ..color = const Color(
              0xFFFFFFFF,
            ).withValues(alpha: 0.4 + rnd.nextDouble() * 0.6),
        );
      }
      c.drawCircle(
        center,
        s * 0.4,
        Paint()
          ..shader = RadialGradient(
            colors: [aura.withValues(alpha: 0.55), aura.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: s * 0.4)),
      );
    case IconAura.nebula:
      final rnd = math.Random(7);
      for (var i = 0; i < 9; i++) {
        final p = Offset(
          s * (0.15 + rnd.nextDouble() * 0.7),
          s * (0.15 + rnd.nextDouble() * 0.7),
        );
        final col = i.isEven
            ? aura
            : Color.lerp(aura, const Color(0xFFFF6FB5), 0.6)!;
        c.drawCircle(
          p,
          s * (0.12 + rnd.nextDouble() * 0.16),
          Paint()
            ..color = col.withValues(alpha: 0.28)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08),
        );
      }
      for (var i = 0; i < 50; i++) {
        c.drawCircle(
          Offset(rnd.nextDouble() * s, rnd.nextDouble() * s),
          s * 0.003,
          Paint()..color = const Color(0xCCFFFFFF),
        );
      }
  }

  // The centre piece, drawn into its own layer so it can be faded and given
  // a shadow.
  final photoImage = spec.center == IconCenter.photo && spec.photo != null
      ? (await (await ui.instantiateImageCodec(
          spec.photo!,
          targetWidth: size,
        )).getNextFrame()).image
      : null;
  final prismImage = spec.center == IconCenter.prism ? await _prism() : null;
  void drawCenter() {
    _drawCenter(c, s, spec, aura, prismImage, photoImage);
  }

  if (spec.shadow) {
    c.save();
    c.translate(s * 0.012, s * 0.02);
    c.saveLayer(
      rect,
      Paint()
        ..colorFilter = const ColorFilter.mode(
          Color(0x66000000),
          BlendMode.srcIn,
        )
        ..imageFilter = ui.ImageFilter.blur(sigmaX: s * 0.02, sigmaY: s * 0.02),
    );
    drawCenter();
    c.restore();
    c.restore();
  }
  if (spec.opacity < 1) {
    c.saveLayer(
      rect,
      Paint()..color = Color.fromRGBO(255, 255, 255, spec.opacity),
    );
  }
  drawCenter();
  if (spec.opacity < 1) c.restore();
  _finish(c, s, spec);

  final img = await rec.endRecording().toImage(size, size);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

void _drawCenter(
  Canvas c,
  double s,
  CustomIconSpec spec,
  Color aura,
  ui.Image? prismImage,
  ui.Image? photoImage,
) {
  switch (spec.center) {
    case IconCenter.prism:
      final img = prismImage;
      if (img == null) return;
      final d = s * 0.78;
      c.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: Offset(s / 2, s / 2), width: d, height: d),
        Paint()..filterQuality = FilterQuality.medium,
      );
    case IconCenter.symbol:
      final icon = iconSymbols[spec.symbol] ?? PhosphorIconsFill.moonStars;
      final col = Color(spec.symbolColor);
      TextPainter glyph(Paint paint) => TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: s * 0.5,
            height: 1,
            foreground: paint,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final glowP = glyph(
        Paint()
          ..color = aura.withValues(
            alpha: spec.aura == IconAura.none ? 0.0 : 0.55,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.035),
      );
      final main = glyph(Paint()..color = col);
      final at = Offset(s / 2 - main.width / 2, s / 2 - main.height / 2);
      glowP.paint(c, at);
      main.paint(c, at);
    case IconCenter.emoji:
      final tp = TextPainter(
        text: TextSpan(
          text: spec.emoji.isEmpty ? '✨' : spec.emoji,
          style: TextStyle(
            fontSize: s * 0.42,
            fontFamilyFallback: const ['NotoColorEmoji', 'Apple Color Emoji'],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(s / 2 - tp.width / 2, s / 2 - tp.height / 2));
    case IconCenter.photo:
      final img = photoImage;
      if (img != null) {
        final r = s * 0.3;
        final circle = Rect.fromCircle(center: Offset(s / 2, s / 2), radius: r);
        c.save();
        c.clipPath(Path()..addOval(circle));
        final side = math.min(img.width, img.height).toDouble();
        c.drawImageRect(
          img,
          Rect.fromLTWH(
            (img.width - side) / 2,
            (img.height - side) / 2,
            side,
            side,
          ),
          circle,
          Paint()..filterQuality = FilterQuality.medium,
        );
        c.restore();
        c.drawCircle(
          Offset(s / 2, s / 2),
          r,
          Paint()
            ..color = aura.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.012,
        );
      }
  }
}

/// Overlays, frame, sticker and label, kept inside the launcher safe zone.
void _finish(Canvas c, double s, CustomIconSpec spec) {
  final rect = Rect.fromLTWH(0, 0, s, s);
  switch (spec.overlay) {
    case 'gloss':
      c.drawRect(
        Rect.fromLTWH(0, 0, s, s * 0.5),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
          ).createShader(Rect.fromLTWH(0, 0, s, s * 0.5)),
      );
    case 'vignette':
      c.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            radius: 0.75,
            colors: [Color(0x00000000), Color(0x77000000)],
          ).createShader(rect),
      );
    case 'sparkles':
      final rnd = math.Random(3);
      for (var i = 0; i < 9; i++) {
        final o = Offset(
          s * (0.2 + rnd.nextDouble() * 0.6),
          s * (0.2 + rnd.nextDouble() * 0.6),
        );
        final r = s * (0.012 + rnd.nextDouble() * 0.02);
        c.drawPath(
          Path()
            ..moveTo(o.dx, o.dy - r)
            ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
            ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
            ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
            ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r),
          Paint()..color = const Color(0xEEFFFFFF),
        );
      }
  }
  if (spec.border > 0) {
    final w = s * 0.01 + spec.border * s * 0.05;
    c.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(s * 0.18 + w / 2),
        Radius.circular(s * 0.14),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = Color(spec.borderColor),
    );
  }
  if (spec.sticker != null && spec.sticker!.isNotEmpty) {
    final tp = TextPainter(
      text: TextSpan(
        text: spec.sticker,
        style: TextStyle(
          fontSize: s * 0.16,
          height: 1,
          fontFamilyFallback: const ['NotoColorEmoji', 'Apple Color Emoji'],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(s * 0.7 - tp.width / 2, s * 0.7 - tp.height / 2));
  }
  if (spec.text.isNotEmpty) {
    final tp = TextPainter(
      text: TextSpan(
        text: spec.text,
        style: TextStyle(
          fontSize: s * 0.11,
          fontWeight: FontWeight.w800,
          height: 1,
          color: Color(spec.textColor),
          shadows: [
            Shadow(color: const Color(0x88000000), blurRadius: s * 0.02),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: s * 0.62);
    tp.paint(c, Offset(s / 2 - tp.width / 2, s * 0.76 - tp.height / 2));
  }
}
