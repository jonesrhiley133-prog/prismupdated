import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:prism_plurality/features/appearance/models/look.dart';

/// Carries the active appearance preset through the widget tree so Prism's
/// own components (cards, buttons, bars) can style themselves from it.
@immutable
class LookTheme extends ThemeExtension<LookTheme> {
  const LookTheme({required this.look, this.reduceTransparency = false, this.reduceEffects = false, this.backgroundDir});

  final PrismLook look;

  /// Accessibility: draw translucent surfaces solid.
  final bool reduceTransparency;

  /// Accessibility: no blur, overlays or shadows.
  final bool reduceEffects;

  /// Folder holding uploaded background images.
  final String? backgroundDir;

  static LookTheme? of(BuildContext context) => Theme.of(context).extension<LookTheme>();

  ElementStyle style(String element) => look.element(element);

  double alpha(ElementStyle s, [double fallback = 1]) => reduceTransparency ? 1 : (s.opacity ?? fallback);

  /// Fill colour of an element, or null to keep the theme's own.
  Color? fill(String element) {
    final s = style(element);
    if (s.color == null) return null;
    return Color(s.color!).withValues(alpha: alpha(s));
  }

  Gradient? gradient(String element) {
    final s = style(element);
    if (s.color == null || s.color2 == null) return null;
    final a = alpha(s);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(s.color!).withValues(alpha: a), Color(s.color2!).withValues(alpha: a)],
    );
  }

  Border? border(String element) {
    final s = style(element);
    if (s.borderWidth == null && s.borderColor == null) return null;
    final w = s.borderWidth ?? 1;
    if (w <= 0) return const Border();
    return Border.all(width: w, color: Color(s.borderColor ?? 0x33888888));
  }

  List<BoxShadow>? shadow(String element) {
    final v = style(element).shadow;
    if (v == null || v <= 0 || reduceEffects) return null;
    return [BoxShadow(color: Colors.black.withValues(alpha: 0.35 * v), blurRadius: 4 + 20 * v, offset: Offset(0, 1 + 6 * v))];
  }

  @override
  LookTheme copyWith({PrismLook? look}) => LookTheme(
    look: look ?? this.look,
    reduceTransparency: reduceTransparency,
    reduceEffects: reduceEffects,
    backgroundDir: backgroundDir,
  );

  @override
  LookTheme lerp(ThemeExtension<LookTheme>? other, double t) => other is LookTheme && t >= 0.5 ? other : this;

  @override
  bool operator ==(Object other) =>
      other is LookTheme &&
      identical(other.look, look) &&
      other.reduceTransparency == reduceTransparency &&
      other.reduceEffects == reduceEffects &&
      other.backgroundDir == backgroundDir;

  @override
  int get hashCode => Object.hash(look, reduceTransparency, reduceEffects, backgroundDir);
}

Color _on(Color c) => ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : const Color(0xFF16131A);

/// The colour a background is "mostly", used behind bars and fades.
Color? backgroundBaseColor(BgSpec bg) => switch (bg.kind) {
  BgKind.theme || BgKind.image => null,
  BgKind.color => Color(bg.color),
  BgKind.gradient => bg.intensity < 0.5 ? null : Color(bg.colors.first),
  BgKind.builtin => builtInBackgrounds[bg.builtin]?.base,
};

/// Applies [look] on top of a base Prism theme.
ThemeData applyLook(
  ThemeData base,
  PrismLook look, {
  bool reduceTransparency = false,
  bool reduceEffects = false,
  String? backgroundDir,
}) {
  final ext = LookTheme(look: look, reduceTransparency: reduceTransparency, reduceEffects: reduceEffects, backgroundDir: backgroundDir);
  if (look.isPlain) {
    return base.copyWith(extensions: [...base.extensions.values.where((e) => e is! LookTheme), ext]);
  }
  var scheme = base.colorScheme;
  var text = base.textTheme;
  var t = base;

  final scaffold = backgroundBaseColor(look.background) ?? base.scaffoldBackgroundColor;

  final textStyle = look.element(LookElement.text);
  if (textStyle.color != null) {
    final c = Color(textStyle.color!);
    scheme = scheme.copyWith(onSurface: c, onSurfaceVariant: c.withValues(alpha: 0.74));
    text = text.apply(bodyColor: c, displayColor: c);
  }

  final button = look.element(LookElement.button);
  if (button.color != null) {
    final c = Color(button.color!);
    scheme = scheme.copyWith(primary: c, onPrimary: _on(c));
  }

  final divider = look.element(LookElement.divider);
  if (divider.color != null) {
    final c = Color(divider.color!).withValues(alpha: ext.alpha(divider));
    scheme = scheme.copyWith(outlineVariant: c);
    t = t.copyWith(dividerColor: c, dividerTheme: t.dividerTheme.copyWith(color: c, thickness: divider.borderWidth));
  }

  final badge = look.element(LookElement.badge);
  if (badge.color != null) {
    final c = Color(badge.color!);
    scheme = scheme.copyWith(tertiary: c, onTertiary: _on(c));
    t = t.copyWith(badgeTheme: t.badgeTheme.copyWith(backgroundColor: c, textColor: _on(c)));
  }

  final icon = look.element(LookElement.icon);
  final card = look.element(LookElement.card);
  final input = look.element(LookElement.input);
  final dialog = look.element(LookElement.dialog);

  InputBorder? shaped(InputBorder? b) {
    if (b is! OutlineInputBorder) return b;
    return b.copyWith(
      borderRadius: input.radius == null ? null : BorderRadius.circular(input.radius!),
      borderSide: input.borderWidth == null && input.borderColor == null
          ? null
          : (input.borderWidth == 0
                ? BorderSide.none
                : b.borderSide.copyWith(width: input.borderWidth, color: input.borderColor == null ? null : Color(input.borderColor!))),
    );
  }

  final idt = t.inputDecorationTheme;
  final dialogColor = ext.fill(LookElement.dialog);
  return t.copyWith(
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: scaffold,
    cardColor: ext.fill(LookElement.card) ?? t.cardColor,
    cardTheme: t.cardTheme.copyWith(
      color: ext.fill(LookElement.card),
      shape: card.radius == null ? null : RoundedRectangleBorder(borderRadius: BorderRadius.circular(card.radius!)),
    ),
    iconTheme: icon.color == null ? null : t.iconTheme.copyWith(color: Color(icon.color!)),
    inputDecorationTheme: idt.copyWith(
      fillColor: ext.fill(LookElement.input),
      border: shaped(idt.border),
      enabledBorder: shaped(idt.enabledBorder),
      disabledBorder: shaped(idt.disabledBorder),
      focusedBorder: input.radius == null || idt.focusedBorder is! OutlineInputBorder
          ? null
          : (idt.focusedBorder! as OutlineInputBorder).copyWith(borderRadius: BorderRadius.circular(input.radius!)),
    ),
    dialogTheme: dialogColor == null && dialog.radius == null
        ? null
        : t.dialogTheme.copyWith(
            backgroundColor: dialogColor,
            shape: dialog.radius == null ? null : RoundedRectangleBorder(borderRadius: BorderRadius.circular(dialog.radius!)),
          ),
    bottomSheetTheme: dialogColor == null && dialog.radius == null
        ? null
        : t.bottomSheetTheme.copyWith(
            backgroundColor: dialogColor,
            shape: dialog.radius == null
                ? null
                : RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(dialog.radius!))),
          ),
    popupMenuTheme: dialogColor == null ? null : t.popupMenuTheme.copyWith(color: dialogColor),
    extensions: [...t.extensions.values.where((e) => e is! LookTheme), ext],
  );
}

// ------------------------------------------------------------ backgrounds

typedef _Blob = ({double x, double y, double r, int color});

@immutable
class BuiltInBackground {
  const BuiltInBackground(this.name, this.base, this._top, this._bottom, this._blobs, {this.stars = false});

  final String name;
  final Color base;
  final int _top;
  final int _bottom;
  final List<_Blob> _blobs;
  final bool stars;

  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(_top), Color(_bottom)]).createShader(rect),
    );
    for (final b in _blobs) {
      final c = Offset(b.x * size.width, b.y * size.height);
      final r = b.r * size.longestSide;
      canvas.drawCircle(
        c,
        r,
        Paint()..shader = RadialGradient(colors: [Color(b.color), Color(b.color).withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    if (stars) {
      final rnd = math.Random(7);
      final p = Paint();
      for (var i = 0; i < 140; i++) {
        p.color = Colors.white.withValues(alpha: 0.25 + rnd.nextDouble() * 0.6);
        canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height), 0.4 + rnd.nextDouble() * 1.2, p);
      }
    }
  }
}

/// The built-in background collection (drawn, so it costs no storage and
/// stays sharp at any size).
const builtInBackgrounds = <String, BuiltInBackground>{
  'aurora': BuiltInBackground('Aurora', Color(0xFF14102B), 0xFF0E0B24, 0xFF1B1440, [
    (x: 0.15, y: 0.2, r: 0.55, color: 0xAA7C4DFF),
    (x: 0.9, y: 0.35, r: 0.5, color: 0x9918FFFF),
    (x: 0.5, y: 0.95, r: 0.6, color: 0x88FF4F9A),
  ]),
  'dusk': BuiltInBackground('Dusk', Color(0xFF2A1638), 0xFF1A1030, 0xFF3A1B3F, [
    (x: 0.5, y: 1.05, r: 0.7, color: 0xCCFF8A65),
    (x: 0.1, y: 0.1, r: 0.5, color: 0x886A4CFF),
    (x: 0.95, y: 0.55, r: 0.4, color: 0x77FF5FA2),
  ]),
  'ocean': BuiltInBackground('Ocean', Color(0xFF07263A), 0xFF051A2B, 0xFF0A3550, [
    (x: 0.2, y: 0.85, r: 0.6, color: 0x9926C6DA),
    (x: 0.85, y: 0.15, r: 0.5, color: 0x883F8CFF),
  ]),
  'forest': BuiltInBackground('Forest', Color(0xFF0D1F17), 0xFF0A1711, 0xFF14301F, [
    (x: 0.8, y: 0.9, r: 0.6, color: 0x8866BB6A),
    (x: 0.1, y: 0.25, r: 0.45, color: 0x66C0CA33),
  ]),
  'night': BuiltInBackground('Night sky', Color(0xFF080B1C), 0xFF05060F, 0xFF10163A, [
    (x: 0.75, y: 0.2, r: 0.5, color: 0x553F51B5),
    (x: 0.2, y: 0.9, r: 0.5, color: 0x447E57C2),
  ], stars: true),
  'peach': BuiltInBackground('Peach', Color(0xFFFFEDE2), 0xFFFFF4EA, 0xFFFFDCD2, [
    (x: 0.85, y: 0.1, r: 0.55, color: 0x99FFB199),
    (x: 0.1, y: 0.9, r: 0.55, color: 0x88E1BEE7),
  ]),
  'mint': BuiltInBackground('Mint', Color(0xFFE8F6F0), 0xFFF2FBF7, 0xFFD9F0E6, [
    (x: 0.15, y: 0.15, r: 0.5, color: 0x8880CBC4),
    (x: 0.9, y: 0.85, r: 0.55, color: 0x88B3E5FC),
  ]),
  'lilac': BuiltInBackground('Lilac', Color(0xFFF1EAFB), 0xFFF7F2FD, 0xFFE4D7F7, [
    (x: 0.8, y: 0.2, r: 0.5, color: 0x88CE93D8),
    (x: 0.15, y: 0.8, r: 0.55, color: 0x889FA8DA),
  ]),
};

class _BuiltInPainter extends CustomPainter {
  const _BuiltInPainter(this.bg);
  final BuiltInBackground bg;

  @override
  void paint(Canvas canvas, Size size) => bg.paint(canvas, size);

  @override
  bool shouldRepaint(_BuiltInPainter old) => old.bg != bg;
}

/// 5×4 colour matrix for brightness, contrast and saturation.
List<double> adjustMatrix({double brightness = 0, double contrast = 1, double saturation = 1}) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final s = saturation, c = contrast;
  final o = (0.5 * (1 - c) + brightness) * 255;
  double m(double lum, bool same) => c * (lum * (1 - s) + (same ? s : 0));
  return [
    m(lr, true), m(lg, false), m(lb, false), 0, o,
    m(lr, false), m(lg, true), m(lb, false), 0, o,
    m(lr, false), m(lg, false), m(lb, true), 0, o,
    0, 0, 0, 1, 0,
  ];
}

Gradient gradientFor(BgSpec bg) {
  final colors = [for (final c in bg.colors) Color(c)];
  switch (bg.gradient) {
    case GradientKind.radial:
      return RadialGradient(colors: colors, radius: 0.95);
    case GradientKind.diagonal:
      return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors);
    case GradientKind.linear:
      final a = bg.angle * math.pi / 180;
      return LinearGradient(
        begin: Alignment(-math.cos(a), -math.sin(a)),
        end: Alignment(math.cos(a), math.sin(a)),
        colors: colors,
      );
  }
}

/// Paints a [BgSpec]. Static content sits in its own repaint boundary so
/// scrolling a page never repaints (or re-blurs) the background.
class LookBackground extends StatelessWidget {
  const LookBackground({super.key, required this.spec, this.dir, this.reduceEffects = false, this.reduceTransparency = false});

  final BgSpec spec;
  final String? dir;
  final bool reduceEffects;
  final bool reduceTransparency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget? layer;
    switch (spec.kind) {
      case BgKind.theme:
        return const SizedBox.shrink();
      case BgKind.color:
        layer = ColoredBox(color: Color(spec.color));
      case BgKind.gradient:
        layer = Opacity(
          opacity: spec.intensity,
          child: DecoratedBox(decoration: BoxDecoration(gradient: gradientFor(spec))),
        );
      case BgKind.builtin:
        final b = builtInBackgrounds[spec.builtin] ?? builtInBackgrounds.values.first;
        layer = CustomPaint(painter: _BuiltInPainter(b));
      case BgKind.image:
        final path = dir == null || spec.image == null ? null : '$dir/${spec.image}';
        if (path == null) return const SizedBox.shrink();
        final width = (MediaQuery.sizeOf(context).longestSide * MediaQuery.devicePixelRatioOf(context)).round().clamp(480, 2400);
        layer = Image.file(
          File(path),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // Decode at screen size, not the photo's full resolution.
          cacheWidth: spec.blur > 0 ? (width / 3).round() : width,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
    }
    final adjusted = spec.brightness != 0 || spec.contrast != 1 || spec.saturation != 1;
    if (adjusted) {
      layer = ColorFiltered(
        colorFilter: ColorFilter.matrix(adjustMatrix(brightness: spec.brightness, contrast: spec.contrast, saturation: spec.saturation)),
        child: layer,
      );
    }
    if (spec.blur > 0 && !reduceEffects) {
      layer = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: spec.blur, sigmaY: spec.blur, tileMode: TileMode.clamp),
        child: layer,
      );
    }
    final opacity = reduceTransparency ? 1.0 : spec.opacity;
    final overlay = reduceEffects ? BgOverlay.none : spec.overlay;
    final oc = Color(spec.overlayColor);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: theme.scaffoldBackgroundColor),
            if (opacity >= 1) layer else Opacity(opacity: opacity, child: layer),
            if (overlay == BgOverlay.scrim) ColoredBox(color: oc.withValues(alpha: spec.overlayStrength)),
            if (overlay == BgOverlay.vignette)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(radius: 1.0, colors: [oc.withValues(alpha: 0), oc.withValues(alpha: spec.overlayStrength)], stops: const [0.45, 1]),
                ),
              ),
            if (overlay == BgOverlay.glow)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [oc.withValues(alpha: spec.overlayStrength), oc.withValues(alpha: 0), oc.withValues(alpha: spec.overlayStrength * 0.6)],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
