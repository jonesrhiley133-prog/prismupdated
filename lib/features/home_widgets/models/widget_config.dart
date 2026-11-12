import 'package:flutter/foundation.dart';

enum WidgetTheme { system, light, dark, amoled }

enum WidgetFont { sans, serif, mono, condensed }

enum AvatarShape { circle, rounded, square }

/// Visual settings for one widget.
@immutable
class WidgetStyle {
  const WidgetStyle({
    this.theme = WidgetTheme.system,
    this.bg1,
    this.bg2,
    this.textColor,
    this.accentColor,
    this.gradientAngle = 135,
    this.opacity = 0.92,
    this.radius = 24,
    this.borderWidth = 0,
    this.borderColor,
    this.font = WidgetFont.sans,
    this.textScale = 1.0,
    this.avatarShape = AvatarShape.circle,
    this.centered = false,
    this.compact = false,
    this.showAvatars = true,
    this.showRefresh = true,
    this.bgImage,
    this.imageDim = 0.35,
  });

  final WidgetTheme theme;

  /// Overrides for the theme's background gradient and colours (ARGB).
  final int? bg1;
  final int? bg2;
  final int? textColor;
  final int? accentColor;
  final double gradientAngle;

  /// 0 (transparent) … 1 (opaque); lower values give the glass look.
  final double opacity;
  final double radius;
  final double borderWidth;
  final int? borderColor;
  final WidgetFont font;
  final double textScale;
  final AvatarShape avatarShape;
  final bool centered;
  final bool compact;
  final bool showAvatars;
  final bool showRefresh;

  /// Base64 JPEG (already resized and optionally blurred by Prism).
  final String? bgImage;
  final double imageDim;

  WidgetStyle copyWith({
    WidgetTheme? theme,
    int? bg1,
    int? bg2,
    int? textColor,
    int? accentColor,
    bool clearColors = false,
    double? gradientAngle,
    double? opacity,
    double? radius,
    double? borderWidth,
    int? borderColor,
    bool clearBorderColor = false,
    WidgetFont? font,
    double? textScale,
    AvatarShape? avatarShape,
    bool? centered,
    bool? compact,
    bool? showAvatars,
    bool? showRefresh,
    String? bgImage,
    bool clearImage = false,
    double? imageDim,
  }) => WidgetStyle(
    theme: theme ?? this.theme,
    bg1: clearColors ? null : (bg1 ?? this.bg1),
    bg2: clearColors ? null : (bg2 ?? this.bg2),
    textColor: clearColors ? null : (textColor ?? this.textColor),
    accentColor: clearColors ? null : (accentColor ?? this.accentColor),
    gradientAngle: gradientAngle ?? this.gradientAngle,
    opacity: opacity ?? this.opacity,
    radius: radius ?? this.radius,
    borderWidth: borderWidth ?? this.borderWidth,
    borderColor: clearBorderColor ? null : (borderColor ?? this.borderColor),
    font: font ?? this.font,
    textScale: textScale ?? this.textScale,
    avatarShape: avatarShape ?? this.avatarShape,
    centered: centered ?? this.centered,
    compact: compact ?? this.compact,
    showAvatars: showAvatars ?? this.showAvatars,
    showRefresh: showRefresh ?? this.showRefresh,
    bgImage: clearImage ? null : (bgImage ?? this.bgImage),
    imageDim: imageDim ?? this.imageDim,
  );

  Map<String, Object?> toJson() => {
    'theme': theme.name,
    'bg1': bg1,
    'bg2': bg2,
    'textColor': textColor,
    'accentColor': accentColor,
    'gradientAngle': gradientAngle,
    'opacity': opacity,
    'radius': radius,
    'borderWidth': borderWidth,
    'borderColor': borderColor,
    'font': font.name,
    'textScale': textScale,
    'avatarShape': avatarShape.name,
    'centered': centered,
    'compact': compact,
    'showAvatars': showAvatars,
    'showRefresh': showRefresh,
    'bgImage': bgImage,
    'imageDim': imageDim,
  };

  static T _e<T extends Enum>(List<T> v, Object? n, T d) => v.firstWhere((x) => x.name == n, orElse: () => d);
  static double _d(Object? v, double d, double lo, double hi) => (v is num ? v.toDouble() : d).clamp(lo, hi).toDouble();

  static WidgetStyle fromJson(Map<String, dynamic> j) => WidgetStyle(
    theme: _e(WidgetTheme.values, j['theme'], WidgetTheme.system),
    bg1: j['bg1'] as int?,
    bg2: j['bg2'] as int?,
    textColor: j['textColor'] as int?,
    accentColor: j['accentColor'] as int?,
    gradientAngle: _d(j['gradientAngle'], 135, 0, 360),
    opacity: _d(j['opacity'], 0.92, 0, 1),
    radius: _d(j['radius'], 24, 0, 40),
    borderWidth: _d(j['borderWidth'], 0, 0, 6),
    borderColor: j['borderColor'] as int?,
    font: _e(WidgetFont.values, j['font'], WidgetFont.sans),
    textScale: _d(j['textScale'], 1, 0.7, 1.6),
    avatarShape: _e(AvatarShape.values, j['avatarShape'], AvatarShape.circle),
    centered: j['centered'] == true,
    compact: j['compact'] == true,
    showAvatars: j['showAvatars'] != false,
    showRefresh: j['showRefresh'] != false,
    bgImage: j['bgImage'] as String?,
    imageDim: _d(j['imageDim'], 0.35, 0, 1),
  );
}

/// What a widget is allowed to reveal on the home screen.
@immutable
class WidgetPrivacy {
  const WidgetPrivacy({this.hideSensitive = true, this.hideNames = false, this.maskNumbers = false});

  /// Hide journal text, private entries and other sensitive details.
  final bool hideSensitive;

  /// Show initials instead of member/person names.
  final bool hideNames;

  /// Replace money and grades with dots.
  final bool maskNumbers;

  WidgetPrivacy copyWith({bool? hideSensitive, bool? hideNames, bool? maskNumbers}) => WidgetPrivacy(
    hideSensitive: hideSensitive ?? this.hideSensitive,
    hideNames: hideNames ?? this.hideNames,
    maskNumbers: maskNumbers ?? this.maskNumbers,
  );

  Map<String, Object?> toJson() => {'hideSensitive': hideSensitive, 'hideNames': hideNames, 'maskNumbers': maskNumbers};

  static WidgetPrivacy fromJson(Map<String, dynamic> j) => WidgetPrivacy(
    hideSensitive: j['hideSensitive'] != false,
    hideNames: j['hideNames'] == true,
    maskNumbers: j['maskNumbers'] == true,
  );
}

/// One widget's full configuration (also used for saved presets).
@immutable
class WidgetConfig {
  const WidgetConfig({
    required this.type,
    this.name = '',
    this.style = const WidgetStyle(),
    this.privacy = const WidgetPrivacy(),
    this.options = const {},
  });

  final String type;

  /// User label for presets and the widget list.
  final String name;
  final WidgetStyle style;
  final WidgetPrivacy privacy;

  /// Type-specific choices (selected members, map, countdown dates …).
  final Map<String, Object?> options;

  WidgetConfig copyWith({String? type, String? name, WidgetStyle? style, WidgetPrivacy? privacy, Map<String, Object?>? options}) =>
      WidgetConfig(
        type: type ?? this.type,
        name: name ?? this.name,
        style: style ?? this.style,
        privacy: privacy ?? this.privacy,
        options: options ?? this.options,
      );

  WidgetConfig withOption(String key, Object? value) {
    final o = Map<String, Object?>.of(options);
    value == null ? o.remove(key) : o[key] = value;
    return copyWith(options: o);
  }

  List<String> stringList(String key) {
    final v = options[key];
    return v is List ? [for (final x in v) if (x is String) x] : const [];
  }

  int intOption(String key, int fallback) => options[key] is int ? options[key] as int : fallback;
  bool boolOption(String key, bool fallback) => options[key] is bool ? options[key] as bool : fallback;
  String? stringOption(String key) => options[key] is String ? options[key] as String : null;

  Map<String, Object?> toJson() => {
    'type': type,
    'name': name,
    'style': style.toJson(),
    'privacy': privacy.toJson(),
    'options': options,
  };

  static WidgetConfig fromJson(Map<String, dynamic> j) => WidgetConfig(
    type: j['type'] is String ? j['type'] as String : 'current_fronter',
    name: j['name'] is String ? j['name'] as String : '',
    style: j['style'] is Map<String, dynamic> ? WidgetStyle.fromJson(j['style'] as Map<String, dynamic>) : const WidgetStyle(),
    privacy: j['privacy'] is Map<String, dynamic> ? WidgetPrivacy.fromJson(j['privacy'] as Map<String, dynamic>) : const WidgetPrivacy(),
    options: j['options'] is Map<String, dynamic> ? Map<String, Object?>.of(j['options'] as Map<String, dynamic>) : const {},
  );

  static WidgetConfig defaultFor(String type) => WidgetConfig(type: type);
}

/// Resolved colours for a theme (what the native side draws with).
@immutable
class WidgetPalette {
  const WidgetPalette(this.bg1, this.bg2, this.text, this.text2, this.accent, this.border);

  final int bg1, bg2, text, text2, accent, border;

  Map<String, Object?> toJson() => {'bg1': bg1, 'bg2': bg2, 'text': text, 'text2': text2, 'accent': accent, 'border': border};
}

WidgetPalette paletteFor(WidgetStyle s, {required bool dark}) {
  final amoled = s.theme == WidgetTheme.amoled;
  final base = amoled
      ? const WidgetPalette(0xFF000000, 0xFF000000, 0xFFFFFFFF, 0xB3FFFFFF, 0xFFB39DDB, 0x33FFFFFF)
      : dark
      ? const WidgetPalette(0xFF2A2235, 0xFF1A1622, 0xFFF5F0FA, 0xB3F5F0FA, 0xFFB39DDB, 0x33FFFFFF)
      : const WidgetPalette(0xFFFBF7F1, 0xFFEDE4F5, 0xFF2B2530, 0x992B2530, 0xFF7E57C2, 0x22000000);
  int text2(int t) => (t & 0x00FFFFFF) | 0xB3000000;
  return WidgetPalette(
    s.bg1 ?? base.bg1,
    s.bg2 ?? s.bg1 ?? base.bg2,
    s.textColor ?? base.text,
    s.textColor == null ? base.text2 : text2(s.textColor!),
    s.accentColor ?? base.accent,
    s.borderColor ?? base.border,
  );
}

/// The style block sent to the native renderer.
Map<String, Object?> nativeStyle(WidgetStyle s) => {
  'theme': s.theme.name,
  'light': paletteFor(s, dark: false).toJson(),
  'dark': paletteFor(s, dark: true).toJson(),
  'gradientAngle': s.gradientAngle,
  'opacity': s.opacity,
  'radius': s.radius,
  'borderWidth': s.borderWidth,
  'font': s.font.name,
  'textScale': s.textScale,
  'avatarShape': s.avatarShape.name,
  'align': s.centered ? 'center' : 'start',
  'compact': s.compact,
  'showAvatars': s.showAvatars,
  'showRefresh': s.showRefresh,
  'bgImage': s.bgImage,
  'imageDim': s.imageDim,
};
