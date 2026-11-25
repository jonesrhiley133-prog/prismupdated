import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:prism_plurality/features/appearance/models/look.dart';

/// Carries the active appearance preset through the widget tree so Prism's
/// own components (cards, buttons, bars) can style themselves from it.
///
/// It also keeps the light and dark base themes (before any preset), so a
/// page with its own preset — or an alter profile with its own accent — is
/// built from a clean base instead of stacking on top of the app preset.
@immutable
class LookTheme extends ThemeExtension<LookTheme> {
  const LookTheme({
    required this.look,
    this.reduceTransparency = false,
    this.reduceEffects = false,
    this.backgroundDir,
    this.lightBase,
    this.darkBase,
  });

  final PrismLook look;

  /// Accessibility: draw translucent surfaces solid.
  final bool reduceTransparency;

  /// Accessibility: no blur, overlays or shadows.
  final bool reduceEffects;

  /// Folder holding uploaded background images.
  final String? backgroundDir;

  /// Base themes without any preset (accessibility already applied).
  final ThemeData? lightBase;
  final ThemeData? darkBase;

  static LookTheme? of(BuildContext context) =>
      Theme.of(context).extension<LookTheme>();

  ElementStyle style(String element) => look.element(element);

  double alpha(ElementStyle s, [double fallback = 1]) =>
      reduceTransparency ? 1 : (s.opacity ?? fallback);

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
      colors: [
        Color(s.color!).withValues(alpha: a),
        Color(s.color2!).withValues(alpha: a),
      ],
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
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.35 * v),
        blurRadius: 4 + 20 * v,
        offset: Offset(0, 1 + 6 * v),
      ),
    ];
  }

  /// A complete theme for [other] (e.g. a page preset), built from the base
  /// that matches its colours rather than layered on the current preset.
  ThemeData themeFor(PrismLook other, Brightness current) {
    final base =
        (current == Brightness.dark ? darkBase : lightBase) ??
        (current == Brightness.dark ? lightBase : darkBase);
    if (base == null) return ThemeData(brightness: current);
    return applyLook(
      base,
      other,
      opposite: current == Brightness.dark ? lightBase : darkBase,
      reduceTransparency: reduceTransparency,
      reduceEffects: reduceEffects,
      backgroundDir: backgroundDir,
    );
  }

  @override
  LookTheme copyWith({PrismLook? look}) => LookTheme(
    look: look ?? this.look,
    reduceTransparency: reduceTransparency,
    reduceEffects: reduceEffects,
    backgroundDir: backgroundDir,
    lightBase: lightBase,
    darkBase: darkBase,
  );

  // No cross-fade: themes switch in one frame so every part changes at once.
  @override
  LookTheme lerp(ThemeExtension<LookTheme>? other, double t) =>
      other is LookTheme && t > 0 ? other : this;

  @override
  bool operator ==(Object other) =>
      other is LookTheme &&
      identical(other.look, look) &&
      other.reduceTransparency == reduceTransparency &&
      other.reduceEffects == reduceEffects &&
      other.backgroundDir == backgroundDir &&
      identical(other.lightBase, lightBase) &&
      identical(other.darkBase, darkBase);

  @override
  int get hashCode =>
      Object.hash(look, reduceTransparency, reduceEffects, backgroundDir);
}

Color _on(Color c) => ThemeData.estimateBrightnessForColor(c) == Brightness.dark
    ? Colors.white
    : const Color(0xFF16131A);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [preferred] if it is readable on [bg], otherwise black or white.
Color _readable(Color preferred, Color bg, {double min = 4.5}) =>
    _contrast(preferred, bg) >= min ? preferred : _on(bg);

/// The colour a background is "mostly", used behind bars and fades.
Color? backgroundBaseColor(BgSpec bg) => switch (bg.kind) {
  BgKind.theme || BgKind.image => null,
  BgKind.color => Color(bg.color),
  BgKind.gradient => bg.intensity < 0.5 ? null : Color(bg.colors.first),
  BgKind.builtin => builtInBackgrounds[bg.builtin]?.base,
};

/// The brightness [look] is designed for, judged from its colours.
Brightness? lookBrightness(PrismLook look) {
  if (look.dark != null) return look.dark! ? Brightness.dark : Brightness.light;
  final c = look.color(LookColor.background) ?? look.color(LookColor.surface);
  final bg = c != null ? Color(c) : backgroundBaseColor(look.background);
  return bg == null ? null : ThemeData.estimateBrightnessForColor(bg);
}

/// Applies [look] on top of a base Prism theme.
///
/// When the look is designed for the other brightness (a dark preset while
/// the app is light, or the reverse) and [opposite] is given, that base is
/// used instead so text, icons and controls stay readable. Every colour
/// role in [PrismLook.colors] is mapped onto the colour scheme and the
/// component themes, then element styles are layered on top.
ThemeData applyLook(
  ThemeData base,
  PrismLook look, {
  ThemeData? opposite,
  bool reduceTransparency = false,
  bool reduceEffects = false,
  String? backgroundDir,
}) {
  final lightBase = base.brightness == Brightness.light ? base : opposite;
  final darkBase = base.brightness == Brightness.dark ? base : opposite;
  final ext = LookTheme(
    look: look,
    reduceTransparency: reduceTransparency,
    reduceEffects: reduceEffects,
    backgroundDir: backgroundDir,
    lightBase: lightBase,
    darkBase: darkBase,
  );
  List<ThemeExtension<dynamic>> exts(ThemeData t) => [
    ...t.extensions.values.where((e) => e is! LookTheme),
    ext,
  ];
  if (look.isPlain) return base.copyWith(extensions: exts(base));

  final wanted = lookBrightness(look);
  var t = wanted != null && wanted != base.brightness && opposite != null
      ? opposite
      : base;
  var scheme = t.colorScheme;
  var text = t.textTheme;
  Color? c(String role) =>
      look.color(role) == null ? null : Color(look.color(role)!);

  // ---- palette
  final background =
      c(LookColor.background) ?? backgroundBaseColor(look.background);
  final surface = c(LookColor.surface);
  final raised = c(LookColor.raised);
  if (surface != null) {
    final towards = scheme.brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    Color step(double f) => Color.lerp(surface, towards, f)!;
    scheme = scheme.copyWith(
      surface: surface,
      surfaceDim: step(-0.0),
      surfaceBright: step(0.06),
      surfaceContainerLowest: Color.lerp(surface, background ?? surface, 0.5),
      surfaceContainerLow: step(0.02),
      surfaceContainer: step(0.04),
      surfaceContainerHigh: raised ?? step(0.07),
      surfaceContainerHighest: raised == null
          ? step(0.10)
          : Color.lerp(raised, towards, 0.04),
    );
  } else if (raised != null) {
    scheme = scheme.copyWith(
      surfaceContainerHigh: raised,
      surfaceContainerHighest: raised,
    );
  }
  final surfaceColor = scheme.surface;
  final accent = c(LookColor.accent);
  if (accent != null) {
    scheme = scheme.copyWith(
      primary: accent,
      onPrimary: _on(accent),
      primaryContainer: Color.alphaBlend(
        accent.withValues(alpha: 0.24),
        surfaceColor,
      ),
      onPrimaryContainer: _readable(
        accent,
        Color.alphaBlend(accent.withValues(alpha: 0.24), surfaceColor),
      ),
      surfaceTint: accent,
      inversePrimary: accent,
    );
  }
  final secondary = c(LookColor.secondary);
  if (secondary != null) {
    scheme = scheme.copyWith(
      secondary: secondary,
      onSecondary: _on(secondary),
      secondaryContainer: Color.alphaBlend(
        secondary.withValues(alpha: 0.24),
        surfaceColor,
      ),
      onSecondaryContainer: _readable(
        secondary,
        Color.alphaBlend(secondary.withValues(alpha: 0.24), surfaceColor),
      ),
    );
  }
  final highlight = c(LookColor.highlight);
  if (highlight != null) {
    scheme = scheme.copyWith(
      tertiary: highlight,
      onTertiary: _on(highlight),
      tertiaryContainer: Color.alphaBlend(
        highlight.withValues(alpha: 0.24),
        surfaceColor,
      ),
      onTertiaryContainer: _readable(
        highlight,
        Color.alphaBlend(highlight.withValues(alpha: 0.24), surfaceColor),
      ),
    );
  }
  final error = c(LookColor.error);
  if (error != null) {
    scheme = scheme.copyWith(
      error: error,
      onError: _on(error),
      errorContainer: Color.alphaBlend(
        error.withValues(alpha: 0.2),
        surfaceColor,
      ),
    );
  }
  final outline = c(LookColor.outline);
  if (outline != null)
    scheme = scheme.copyWith(
      outline: outline,
      outlineVariant: outline.withValues(alpha: outline.a * 0.6),
    );

  // Text: the chosen colour, kept readable on the surface; without one,
  // make sure the base text still reads on a custom surface/background.
  final textColor =
      c(LookColor.text) ??
      (look.element(LookElement.text).color == null
          ? null
          : Color(look.element(LookElement.text).color!));
  final readOn = surface ?? background ?? scheme.surface;
  final onSurface = _readable(textColor ?? scheme.onSurface, readOn);
  final muted = c(LookColor.mutedText) ?? onSurface.withValues(alpha: 0.72);
  scheme = scheme.copyWith(
    onSurface: onSurface,
    onSurfaceVariant: _readable(muted, readOn, min: 3),
    inverseSurface: onSurface,
    onInverseSurface: readOn,
  );
  if (onSurface != t.colorScheme.onSurface)
    text = text.apply(bodyColor: onSurface, displayColor: onSurface);

  // ---- element styles (on top of the palette)
  final button = look.element(LookElement.button);
  if (button.color != null && accent == null) {
    final bc = Color(button.color!);
    scheme = scheme.copyWith(primary: bc, onPrimary: _on(bc));
  }
  final divider = look.element(LookElement.divider);
  Color? dividerColor;
  if (divider.color != null) {
    dividerColor = Color(divider.color!).withValues(alpha: ext.alpha(divider));
    scheme = scheme.copyWith(outlineVariant: dividerColor);
  }
  final badge = look.element(LookElement.badge);
  final badgeColor = badge.color != null ? Color(badge.color!) : highlight;
  if (badge.color != null)
    scheme = scheme.copyWith(
      tertiary: badgeColor,
      onTertiary: _on(badgeColor!),
    );

  final scaffold =
      background ??
      (surface != null
          ? Color.lerp(
              surface,
              Colors.black,
              scheme.brightness == Brightness.dark ? 0.25 : 0.03,
            )!
          : t.scaffoldBackgroundColor);
  final icon = look.element(LookElement.icon);
  final card = look.element(LookElement.card);
  final input = look.element(LookElement.input);
  final dialog = look.element(LookElement.dialog);
  final chip = c(LookColor.chip);
  final toggle = c(LookColor.toggle);
  final progress = c(LookColor.progress);
  final link = c(LookColor.link);

  InputBorder? shaped(InputBorder? b) {
    if (b is! OutlineInputBorder) return b;
    return b.copyWith(
      borderRadius: input.radius == null
          ? null
          : BorderRadius.circular(input.radius!),
      borderSide: input.borderWidth == null && input.borderColor == null
          ? null
          : (input.borderWidth == 0
                ? BorderSide.none
                : b.borderSide.copyWith(
                    width: input.borderWidth,
                    color: input.borderColor == null
                        ? null
                        : Color(input.borderColor!),
                  )),
    );
  }

  final idt = t.inputDecorationTheme;
  final dialogColor =
      ext.fill(LookElement.dialog) ??
      (surface == null ? null : scheme.surfaceContainerHigh);
  final cardColor =
      ext.fill(LookElement.card) ??
      (surface == null ? null : scheme.surfaceContainerLow);
  final iconColor = icon.color != null
      ? Color(icon.color!)
      : (textColor != null ? onSurface : null);
  return t.copyWith(
    colorScheme: scheme,
    textTheme: text,
    primaryColor: scheme.primary,
    scaffoldBackgroundColor: scaffold,
    canvasColor: surface ?? t.canvasColor,
    dividerColor:
        dividerColor ?? (outline == null ? null : scheme.outlineVariant),
    dividerTheme: dividerColor == null && outline == null
        ? null
        : t.dividerTheme.copyWith(
            color: dividerColor ?? scheme.outlineVariant,
            thickness: divider.borderWidth,
          ),
    cardColor: cardColor ?? t.cardColor,
    cardTheme: t.cardTheme.copyWith(
      color: cardColor,
      shape: card.radius == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(card.radius!),
            ),
    ),
    iconTheme: iconColor == null
        ? null
        : t.iconTheme.copyWith(color: iconColor),
    badgeTheme: badgeColor == null
        ? null
        : t.badgeTheme.copyWith(
            backgroundColor: badgeColor,
            textColor: _on(badgeColor),
          ),
    appBarTheme: t.appBarTheme.copyWith(
      backgroundColor: surface == null ? null : scaffold,
      foregroundColor: textColor == null ? null : onSurface,
      iconTheme: iconColor == null ? null : IconThemeData(color: iconColor),
    ),
    inputDecorationTheme: idt.copyWith(
      fillColor:
          ext.fill(LookElement.input) ??
          (surface == null ? null : scheme.surfaceContainerHighest),
      border: shaped(idt.border),
      enabledBorder: shaped(idt.enabledBorder),
      disabledBorder: shaped(idt.disabledBorder),
      focusedBorder:
          input.radius == null || idt.focusedBorder is! OutlineInputBorder
          ? null
          : (idt.focusedBorder! as OutlineInputBorder).copyWith(
              borderRadius: BorderRadius.circular(input.radius!),
            ),
      hintStyle: textColor == null
          ? null
          : TextStyle(color: scheme.onSurfaceVariant),
      labelStyle: textColor == null
          ? null
          : TextStyle(color: scheme.onSurfaceVariant),
    ),
    dialogTheme: dialogColor == null && dialog.radius == null
        ? null
        : t.dialogTheme.copyWith(
            backgroundColor: dialogColor,
            shape: dialog.radius == null
                ? null
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(dialog.radius!),
                  ),
          ),
    bottomSheetTheme: dialogColor == null && dialog.radius == null
        ? null
        : t.bottomSheetTheme.copyWith(
            backgroundColor: dialogColor,
            modalBackgroundColor: dialogColor,
            shape: dialog.radius == null
                ? null
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(dialog.radius!),
                    ),
                  ),
          ),
    popupMenuTheme: dialogColor == null
        ? null
        : t.popupMenuTheme.copyWith(color: dialogColor),
    chipTheme: chip == null
        ? null
        : t.chipTheme.copyWith(
            selectedColor: chip,
            secondarySelectedColor: chip,
            checkmarkColor: _on(chip),
            secondaryLabelStyle: TextStyle(color: _on(chip)),
          ),
    switchTheme: toggle == null
        ? null
        : t.switchTheme.copyWith(
            thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? _on(toggle) : null,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? toggle : null,
            ),
          ),
    checkboxTheme: toggle == null
        ? null
        : t.checkboxTheme.copyWith(
            fillColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? toggle : null,
            ),
            checkColor: WidgetStatePropertyAll(_on(toggle)),
          ),
    radioTheme: toggle == null
        ? null
        : t.radioTheme.copyWith(
            fillColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? toggle : null,
            ),
          ),
    progressIndicatorTheme: progress == null
        ? null
        : t.progressIndicatorTheme.copyWith(
            color: progress,
            linearTrackColor: progress.withValues(alpha: 0.2),
            circularTrackColor: progress.withValues(alpha: 0.2),
          ),
    sliderTheme: progress == null
        ? null
        : t.sliderTheme.copyWith(
            activeTrackColor: progress,
            thumbColor: progress,
            inactiveTrackColor: progress.withValues(alpha: 0.25),
          ),
    textSelectionTheme: link == null && accent == null
        ? null
        : t.textSelectionTheme.copyWith(
            cursorColor: link ?? accent,
            selectionHandleColor: link ?? accent,
            selectionColor: (link ?? accent)!.withValues(alpha: 0.35),
          ),
    floatingActionButtonTheme: accent == null
        ? null
        : t.floatingActionButtonTheme.copyWith(
            backgroundColor: accent,
            foregroundColor: _on(accent),
          ),
    extensions: [
      ...exts(t).where((e) => e is! LookStatusColors),
      LookStatusColors(
        success: c(LookColor.success) ?? const Color(0xFF3BA55C),
        warning: c(LookColor.warning) ?? const Color(0xFFFAA61A),
        link: link ?? scheme.primary,
      ),
    ],
  );
}

/// Extra colour roles that Material has no slot for.
@immutable
class LookStatusColors extends ThemeExtension<LookStatusColors> {
  const LookStatusColors({
    required this.success,
    required this.warning,
    required this.link,
  });
  final Color success;
  final Color warning;
  final Color link;

  static LookStatusColors of(BuildContext context) =>
      Theme.of(context).extension<LookStatusColors>() ??
      LookStatusColors(
        success: const Color(0xFF3BA55C),
        warning: const Color(0xFFFAA61A),
        link: Theme.of(context).colorScheme.primary,
      );

  @override
  LookStatusColors copyWith({Color? success, Color? warning, Color? link}) =>
      LookStatusColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        link: link ?? this.link,
      );

  @override
  LookStatusColors lerp(ThemeExtension<LookStatusColors>? other, double t) =>
      other is LookStatusColors && t > 0 ? other : this;
}

/// Re-themes [base] around an accent colour (alter profiles) while keeping
/// the active appearance preset: backgrounds, surfaces, text and element
/// styles still apply, the accent just takes the member's colour.
ThemeData withAccent(ThemeData base, Color accent, {ThemeData? palette}) {
  final look = base.extension<LookTheme>();
  // In palette mode the accent is the palette's own tone of the colour.
  accent = palette?.colorScheme.primary ?? accent;
  var t = palette ?? base;
  // Palette themes are rebuilt from scratch; carry the extensions over.
  if (palette != null) t = t.copyWith(extensions: base.extensions.values);
  if (look != null && !look.look.isPlain) {
    final b = t.brightness == Brightness.dark ? look.darkBase : look.lightBase;
    final seeded = palette == null || b == null
        ? (b ?? t)
        : palette.copyWith(
            extensions: b.extensions.values,
            textTheme: b.textTheme,
          );
    t = applyLook(
      seeded,
      look.look.withColor(LookColor.accent, accent.toARGB32()),
      opposite: t.brightness == Brightness.dark
          ? look.lightBase
          : look.darkBase,
      reduceTransparency: look.reduceTransparency,
      reduceEffects: look.reduceEffects,
      backgroundDir: look.backgroundDir,
    );
    return t;
  }
  if (palette != null) return t;
  return t.copyWith(colorScheme: t.colorScheme.copyWith(primary: accent));
}

/// Theme switches (light/dark, presets) happen in one frame. Implicit
/// animations read this to skip their tween for that frame, so no part of
/// the app lags behind the rest.
abstract final class ThemeSwitch {
  static DateTime _at = DateTime.fromMillisecondsSinceEpoch(0);
  static Object? _lastKey;

  /// Call with a value identifying the current theme; a change marks a switch.
  static void observe(Object key) {
    if (_lastKey != null && _lastKey != key) _at = DateTime.now();
    _lastKey = key;
  }

  static bool get active =>
      DateTime.now().difference(_at) < const Duration(milliseconds: 450);
}

/// [d], or zero right after a theme switch.
Duration themeAware(Duration d) => ThemeSwitch.active ? Duration.zero : d;

// ------------------------------------------------------------ backgrounds

typedef _Blob = ({double x, double y, double r, int color});

@immutable
class BuiltInBackground {
  const BuiltInBackground(
    this.name,
    this.base,
    this._top,
    this._bottom,
    this._blobs, {
    this.stars = false,
  });

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
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(_top), Color(_bottom)],
        ).createShader(rect),
    );
    for (final b in _blobs) {
      final c = Offset(b.x * size.width, b.y * size.height);
      final r = b.r * size.longestSide;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [Color(b.color), Color(b.color).withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    if (stars) {
      final rnd = math.Random(7);
      final p = Paint();
      for (var i = 0; i < 140; i++) {
        p.color = Colors.white.withValues(alpha: 0.25 + rnd.nextDouble() * 0.6);
        canvas.drawCircle(
          Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
          0.4 + rnd.nextDouble() * 1.2,
          p,
        );
      }
    }
  }
}

/// The built-in background collection (drawn, so it costs no storage and
/// stays sharp at any size).
const builtInBackgrounds = <String, BuiltInBackground>{
  'aurora':
      BuiltInBackground('Aurora', Color(0xFF14102B), 0xFF0E0B24, 0xFF1B1440, [
        (x: 0.15, y: 0.2, r: 0.55, color: 0xAA7C4DFF),
        (x: 0.9, y: 0.35, r: 0.5, color: 0x9918FFFF),
        (x: 0.5, y: 0.95, r: 0.6, color: 0x88FF4F9A),
      ]),
  'dusk': BuiltInBackground('Dusk', Color(0xFF2A1638), 0xFF1A1030, 0xFF3A1B3F, [
    (x: 0.5, y: 1.05, r: 0.7, color: 0xCCFF8A65),
    (x: 0.1, y: 0.1, r: 0.5, color: 0x886A4CFF),
    (x: 0.95, y: 0.55, r: 0.4, color: 0x77FF5FA2),
  ]),
  'ocean': BuiltInBackground(
    'Ocean',
    Color(0xFF07263A),
    0xFF051A2B,
    0xFF0A3550,
    [
      (x: 0.2, y: 0.85, r: 0.6, color: 0x9926C6DA),
      (x: 0.85, y: 0.15, r: 0.5, color: 0x883F8CFF),
    ],
  ),
  'forest': BuiltInBackground(
    'Forest',
    Color(0xFF0D1F17),
    0xFF0A1711,
    0xFF14301F,
    [
      (x: 0.8, y: 0.9, r: 0.6, color: 0x8866BB6A),
      (x: 0.1, y: 0.25, r: 0.45, color: 0x66C0CA33),
    ],
  ),
  'night': BuiltInBackground(
    'Night sky',
    Color(0xFF080B1C),
    0xFF05060F,
    0xFF10163A,
    [
      (x: 0.75, y: 0.2, r: 0.5, color: 0x553F51B5),
      (x: 0.2, y: 0.9, r: 0.5, color: 0x447E57C2),
    ],
    stars: true,
  ),
  'peach': BuiltInBackground(
    'Peach',
    Color(0xFFFFEDE2),
    0xFFFFF4EA,
    0xFFFFDCD2,
    [
      (x: 0.85, y: 0.1, r: 0.55, color: 0x99FFB199),
      (x: 0.1, y: 0.9, r: 0.55, color: 0x88E1BEE7),
    ],
  ),
  'mint': BuiltInBackground('Mint', Color(0xFFE8F6F0), 0xFFF2FBF7, 0xFFD9F0E6, [
    (x: 0.15, y: 0.15, r: 0.5, color: 0x8880CBC4),
    (x: 0.9, y: 0.85, r: 0.55, color: 0x88B3E5FC),
  ]),
  'lilac': BuiltInBackground(
    'Lilac',
    Color(0xFFF1EAFB),
    0xFFF7F2FD,
    0xFFE4D7F7,
    [
      (x: 0.8, y: 0.2, r: 0.5, color: 0x88CE93D8),
      (x: 0.15, y: 0.8, r: 0.55, color: 0x889FA8DA),
    ],
  ),
};

/// 5×4 colour matrix for brightness, contrast and saturation.
List<double> adjustMatrix({
  double brightness = 0,
  double contrast = 1,
  double saturation = 1,
}) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final s = saturation, c = contrast;
  final o = (0.5 * (1 - c) + brightness) * 255;
  double m(double lum, bool same) => c * (lum * (1 - s) + (same ? s : 0));
  return [
    m(lr, true),
    m(lg, false),
    m(lb, false),
    0,
    o,
    m(lr, false),
    m(lg, true),
    m(lb, false),
    0,
    o,
    m(lr, false),
    m(lg, false),
    m(lb, true),
    0,
    o,
    0,
    0,
    0,
    1,
    0,
  ];
}

Gradient gradientFor(BgSpec bg) {
  final colors = [for (final c in bg.colors) Color(c)];
  switch (bg.gradient) {
    case GradientKind.radial:
      return RadialGradient(colors: colors, radius: 0.95);
    case GradientKind.diagonal:
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      );
    case GradientKind.linear:
      final a = bg.angle * math.pi / 180;
      return LinearGradient(
        begin: Alignment(-math.cos(a), -math.sin(a)),
        end: Alignment(math.cos(a), math.sin(a)),
        colors: colors,
      );
  }
}

/// Paints a [BgSpec].
///
/// Blur, colour adjustments, opacity and overlays are baked once into a
/// single cached image (see [bakeBackground]); drawing it afterwards is a
/// plain texture copy. Flutter's Android renderer does not cache layers
/// between frames, so applying the filters live would redo a full-screen
/// blur on every frame and make scrolling and page changes stutter.
class LookBackground extends StatefulWidget {
  const LookBackground({
    super.key,
    required this.spec,
    this.dir,
    this.reduceEffects = false,
    this.reduceTransparency = false,
  });

  final BgSpec spec;
  final String? dir;
  final bool reduceEffects;
  final bool reduceTransparency;

  @override
  State<LookBackground> createState() => _LookBackgroundState();
}

class _LookBackgroundState extends State<LookBackground> {
  ui.Image? _image;
  String? _key;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _request();
  }

  @override
  void didUpdateWidget(LookBackground old) {
    super.didUpdateWidget(old);
    _request();
  }

  void _request() {
    if (widget.spec.kind == BgKind.theme || widget.spec.kind == BgKind.color)
      return;
    final mq = MediaQuery.maybeOf(context);
    final size = mq?.size ?? const Size(400, 800);
    final dpr = mq?.devicePixelRatio ?? 2;
    final base = Theme.of(context).scaffoldBackgroundColor;
    final req = BakeRequest(
      spec: widget.spec,
      dir: widget.dir,
      // Orientation matters, small size changes (keyboard, insets) don't.
      portrait: size.height >= size.width,
      longestPx: (size.longestSide * dpr).clamp(320, 1600).round(),
      base: base.toARGB32(),
      reduceEffects: widget.reduceEffects,
      reduceTransparency: widget.reduceTransparency,
    );
    if (req.key == _key) return;
    _key = req.key;
    final cached = backgroundCache[req.key];
    if (cached != null) {
      _image = cached;
      return;
    }
    // Keep showing the previous image until the new one is ready, so a
    // theme switch never flashes a placeholder.
    bakeBackground(req).then((img) {
      if (!mounted || _key != req.key) return;
      setState(() => _image = img);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final theme = Theme.of(context);
    if (spec.kind == BgKind.theme) return const SizedBox.shrink();
    if (spec.kind == BgKind.color) {
      return ColoredBox(
        color: Color(
          spec.color,
        ).withValues(alpha: widget.reduceTransparency ? 1 : spec.opacity),
      );
    }
    final img = _image;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: img == null
            // Cheap placeholder in the background's main colour while the
            // baked image is prepared (usually one frame, then cached).
            ? ColoredBox(
                color:
                    backgroundBaseColor(spec) ?? theme.scaffoldBackgroundColor,
              )
            : RawImage(
                image: img,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
              ),
      ),
    );
  }
}

/// What to bake; [key] identifies the result in [backgroundCache].
@immutable
class BakeRequest {
  const BakeRequest({
    required this.spec,
    required this.dir,
    required this.portrait,
    required this.longestPx,
    required this.base,
    required this.reduceEffects,
    required this.reduceTransparency,
  });

  final BgSpec spec;
  final String? dir;
  final bool portrait;
  final int longestPx;
  final int base;
  final bool reduceEffects;
  final bool reduceTransparency;

  /// Blurred backgrounds are baked smaller: the blur hides it and it is
  /// much cheaper to keep in memory.
  int get targetLongest => spec.blur > 0 && !reduceEffects
      ? (longestPx / 2).round().clamp(320, 900)
      : longestPx;

  String get key =>
      '${spec.toJson()}|$dir|$portrait|$targetLongest|$base|$reduceEffects|$reduceTransparency';
}

/// Baked backgrounds, newest last; small so memory stays bounded.
final backgroundCache = _LruImages(4);

class _LruImages {
  _LruImages(this.capacity);
  final int capacity;
  final _map = <String, ui.Image>{};
  final _pending = <String, Future<ui.Image?>>{};

  ui.Image? operator [](String key) {
    final v = _map.remove(key);
    if (v != null) _map[key] = v;
    return v;
  }

  void put(String key, ui.Image img) {
    _map.remove(key)?.dispose();
    _map[key] = img;
    while (_map.length > capacity) {
      final oldest = _map.keys.first;
      // Not disposed: a page may still be showing it; the GC frees it.
      _map.remove(oldest);
    }
  }
}

Future<ui.Image?> bakeBackground(BakeRequest r) {
  final hit = backgroundCache[r.key];
  if (hit != null) return Future.value(hit);
  // Block body: returning the removed Future from whenComplete would make
  // the bake wait on itself forever.
  return backgroundCache._pending[r.key] ??= _bake(r).whenComplete(() {
    backgroundCache._pending.remove(r.key);
  });
}

Future<ui.Image?> _bake(BakeRequest r) async {
  try {
    final spec = r.spec;
    final longest = r.targetLongest.toDouble();
    // Phone-shaped canvas (9:19.5) in the current orientation.
    final short = (longest * 9 / 19.5).roundToDouble();
    final w = r.portrait ? short : longest;
    final h = r.portrait ? longest : short;
    final rect = Rect.fromLTWH(0, 0, w, h);
    ui.Image? photo;
    if (spec.kind == BgKind.image) {
      final path = r.dir == null || spec.image == null
          ? null
          : '${r.dir}/${spec.image}';
      if (path == null || !File(path).existsSync()) return null;
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
        targetWidth: (r.portrait ? w : h).round().clamp(64, 1600),
      );
      photo = (await codec.getNextFrame()).image;
    }
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, rect);
    canvas.drawRect(rect, Paint()..color = Color(r.base));
    final adjusted =
        spec.brightness != 0 || spec.contrast != 1 || spec.saturation != 1;
    final blur = r.reduceEffects ? 0.0 : spec.blur * (w / 400);
    final layerPaint = Paint()
      ..color = Color.fromRGBO(
        0,
        0,
        0,
        r.reduceTransparency ? 1 : spec.opacity,
      );
    if (adjusted) {
      layerPaint.colorFilter = ColorFilter.matrix(
        adjustMatrix(
          brightness: spec.brightness,
          contrast: spec.contrast,
          saturation: spec.saturation,
        ),
      );
    }
    if (blur > 0)
      layerPaint.imageFilter = ui.ImageFilter.blur(
        sigmaX: blur,
        sigmaY: blur,
        tileMode: TileMode.clamp,
      );
    canvas.saveLayer(rect, layerPaint);
    switch (spec.kind) {
      case BgKind.gradient:
        canvas.drawRect(rect, Paint()..color = Color(r.base));
        canvas.drawRect(
          rect,
          Paint()
            ..shader = gradientFor(spec).createShader(rect)
            ..color = Color.fromRGBO(0, 0, 0, spec.intensity),
        );
      case BgKind.builtin:
        (builtInBackgrounds[spec.builtin] ?? builtInBackgrounds.values.first)
            .paint(canvas, rect.size);
      case BgKind.image:
        final p = photo!;
        final scale = (w / p.width) > (h / p.height)
            ? w / p.width
            : h / p.height;
        final dw = p.width * scale, dh = p.height * scale;
        canvas.drawImageRect(
          p,
          Rect.fromLTWH(0, 0, p.width.toDouble(), p.height.toDouble()),
          Rect.fromLTWH((w - dw) / 2, (h - dh) / 2, dw, dh),
          Paint()..filterQuality = FilterQuality.medium,
        );
      case BgKind.color || BgKind.theme:
        break;
    }
    canvas.restore();
    final overlay = r.reduceEffects ? BgOverlay.none : spec.overlay;
    final oc = Color(spec.overlayColor);
    switch (overlay) {
      case BgOverlay.scrim:
        canvas.drawRect(
          rect,
          Paint()..color = oc.withValues(alpha: spec.overlayStrength),
        );
      case BgOverlay.vignette:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              radius: 1.0,
              colors: [
                oc.withValues(alpha: 0),
                oc.withValues(alpha: spec.overlayStrength),
              ],
              stops: const [0.45, 1],
            ).createShader(rect),
        );
      case BgOverlay.glow:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                oc.withValues(alpha: spec.overlayStrength),
                oc.withValues(alpha: 0),
                oc.withValues(alpha: spec.overlayStrength * 0.6),
              ],
              stops: const [0, 0.5, 1],
            ).createShader(rect),
        );
      case BgOverlay.none:
        break;
    }
    // GPU-side image; rasterised once off the UI thread.
    final img = rec.endRecording().toImageSync(w.round(), h.round());
    photo?.dispose();
    backgroundCache.put(r.key, img);
    return img;
  } catch (_) {
    return null;
  }
}
