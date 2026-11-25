import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show IconData;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

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
  });

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
  );

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
  );
}

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

  switch (spec.center) {
    case IconCenter.prism:
      final img = await _prism();
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
      final bytes = spec.photo;
      if (bytes != null) {
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: size);
        final img = (await codec.getNextFrame()).image;
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

  final img = await rec.endRecording().toImage(size, size);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}
