import 'package:flutter/foundation.dart';

enum BgKind { theme, color, gradient, image, builtin }

enum GradientKind { linear, radial, diagonal }

enum BgOverlay { none, scrim, vignette, glow }

double _d(Object? v, double d, double lo, double hi) => (v is num ? v.toDouble() : d).clamp(lo, hi).toDouble();
T _e<T extends Enum>(List<T> values, Object? name, T d) => values.firstWhere((x) => x.name == name, orElse: () => d);
int? _i(Object? v) => v is int ? v : null;

/// A page background: colour, gradient, picture or built-in artwork, plus
/// image adjustments and an optional overlay.
@immutable
class BgSpec {
  const BgSpec({
    this.kind = BgKind.theme,
    this.color = 0xFF1E1A24,
    this.colors = const [0xFF5C6BC0, 0xFFEC407A],
    this.gradient = GradientKind.linear,
    this.angle = 135,
    this.intensity = 1,
    this.image,
    this.builtin = 'aurora',
    this.opacity = 1,
    this.blur = 0,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.overlay = BgOverlay.none,
    this.overlayColor = 0xFF000000,
    this.overlayStrength = 0.3,
  });

  final BgKind kind;
  final int color;

  /// Two to five gradient colours.
  final List<int> colors;
  final GradientKind gradient;
  final double angle;

  /// 0 keeps the theme's own background, 1 shows the gradient fully.
  final double intensity;

  /// File name inside the backgrounds folder (device-local).
  final String? image;
  final String builtin;
  final double opacity;
  final double blur;

  /// −1 (black) … 0 (unchanged) … 1 (white).
  final double brightness;
  final double contrast;
  final double saturation;
  final BgOverlay overlay;
  final int overlayColor;
  final double overlayStrength;

  bool get isCustom => kind != BgKind.theme;

  BgSpec copyWith({
    BgKind? kind,
    int? color,
    List<int>? colors,
    GradientKind? gradient,
    double? angle,
    double? intensity,
    String? image,
    bool clearImage = false,
    String? builtin,
    double? opacity,
    double? blur,
    double? brightness,
    double? contrast,
    double? saturation,
    BgOverlay? overlay,
    int? overlayColor,
    double? overlayStrength,
  }) => BgSpec(
    kind: kind ?? this.kind,
    color: color ?? this.color,
    colors: colors ?? this.colors,
    gradient: gradient ?? this.gradient,
    angle: angle ?? this.angle,
    intensity: intensity ?? this.intensity,
    image: clearImage ? null : (image ?? this.image),
    builtin: builtin ?? this.builtin,
    opacity: opacity ?? this.opacity,
    blur: blur ?? this.blur,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    overlay: overlay ?? this.overlay,
    overlayColor: overlayColor ?? this.overlayColor,
    overlayStrength: overlayStrength ?? this.overlayStrength,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'color': color,
    'colors': colors,
    'gradient': gradient.name,
    'angle': angle,
    'intensity': intensity,
    'image': image,
    'builtin': builtin,
    'opacity': opacity,
    'blur': blur,
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    'overlay': overlay.name,
    'overlayColor': overlayColor,
    'overlayStrength': overlayStrength,
  };

  static BgSpec fromJson(Object? j) {
    if (j is! Map) return const BgSpec();
    final colors = [
      if (j['colors'] is List)
        for (final c in j['colors'] as List)
          if (c is int) c,
    ];
    return BgSpec(
      kind: _e(BgKind.values, j['kind'], BgKind.theme),
      color: _i(j['color']) ?? 0xFF1E1A24,
      colors: colors.length >= 2 ? colors.take(5).toList() : const [0xFF5C6BC0, 0xFFEC407A],
      gradient: _e(GradientKind.values, j['gradient'], GradientKind.linear),
      angle: _d(j['angle'], 135, 0, 360),
      intensity: _d(j['intensity'], 1, 0, 1),
      image: j['image'] is String ? j['image'] as String : null,
      builtin: j['builtin'] is String ? j['builtin'] as String : 'aurora',
      opacity: _d(j['opacity'], 1, 0, 1),
      blur: _d(j['blur'], 0, 0, 30),
      brightness: _d(j['brightness'], 0, -1, 1),
      contrast: _d(j['contrast'], 1, 0, 2),
      saturation: _d(j['saturation'], 1, 0, 2),
      overlay: _e(BgOverlay.values, j['overlay'], BgOverlay.none),
      overlayColor: _i(j['overlayColor']) ?? 0xFF000000,
      overlayStrength: _d(j['overlayStrength'], 0.3, 0, 1),
    );
  }
}

/// Interface parts that can be styled individually.
abstract final class LookElement {
  static const button = 'button';
  static const card = 'card';
  static const nav = 'nav';
  static const header = 'header';
  static const input = 'input';
  static const dialog = 'dialog';
  static const divider = 'divider';
  static const icon = 'icon';
  static const badge = 'badge';
  static const text = 'text';

  static const all = [button, card, nav, header, input, dialog, divider, icon, badge, text];
}

/// Colour roles every theme can set. Together they recolour the whole app:
/// Prism's components read these through the Material colour scheme and
/// component themes, so a theme no longer only changes the accent.
abstract final class LookColor {
  static const accent = 'accent';
  static const secondary = 'secondary';
  static const highlight = 'highlight';
  static const background = 'background';
  static const surface = 'surface';
  static const raised = 'raised';
  static const text = 'text';
  static const mutedText = 'mutedText';
  static const outline = 'outline';
  static const error = 'error';
  static const success = 'success';
  static const warning = 'warning';
  static const chip = 'chip';
  static const toggle = 'toggle';
  static const progress = 'progress';
  static const link = 'link';

  static const all = [accent, secondary, highlight, background, surface, raised, text, mutedText, outline, error, success, warning, chip, toggle, progress, link];
}

/// Style overrides for one kind of element. Null means "leave as the
/// theme has it".
@immutable
class ElementStyle {
  const ElementStyle({this.color, this.color2, this.opacity, this.radius, this.borderWidth, this.borderColor, this.shadow, this.padding});

  final int? color;

  /// Second colour: turns the fill into a gradient.
  final int? color2;
  final double? opacity;
  final double? radius;
  final double? borderWidth;
  final int? borderColor;

  /// Shadow strength 0–1.
  final double? shadow;

  /// Inner spacing multiplier.
  final double? padding;

  bool get isEmpty =>
      color == null && color2 == null && opacity == null && radius == null && borderWidth == null && borderColor == null && shadow == null && padding == null;

  /// Returns a copy with [key] set to [value] (null clears it).
  ElementStyle set(String key, Object? value) {
    final j = Map<String, Object?>.of(toJson())..[key] = value;
    return ElementStyle.fromJson(j);
  }

  Map<String, Object?> toJson() => {
    'color': color,
    'color2': color2,
    'opacity': opacity,
    'radius': radius,
    'borderWidth': borderWidth,
    'borderColor': borderColor,
    'shadow': shadow,
    'padding': padding,
  };

  static ElementStyle fromJson(Object? j) {
    if (j is! Map) return const ElementStyle();
    double? d(String k, double lo, double hi) => j[k] is num ? (j[k] as num).toDouble().clamp(lo, hi).toDouble() : null;
    return ElementStyle(
      color: _i(j['color']),
      color2: _i(j['color2']),
      opacity: d('opacity', 0, 1),
      radius: d('radius', 0, 40),
      borderWidth: d('borderWidth', 0, 6),
      borderColor: _i(j['borderColor']),
      shadow: d('shadow', 0, 1),
      padding: d('padding', 0.5, 2),
    );
  }
}

/// A complete appearance configuration ("theme preset").
@immutable
class PrismLook {
  const PrismLook({
    required this.id,
    required this.name,
    this.background = const BgSpec(),
    this.pageBackgrounds = const {},
    this.elements = const {},
    this.builtIn = false,
    this.dark,
    this.colors = const {},
  });

  /// Colour palette (role → ARGB), see [LookColor]. Missing roles keep the
  /// base theme's colour.
  final Map<String, int> colors;

  final String id;
  final String name;
  final BgSpec background;

  /// Backgrounds for individual pages, keyed by page id (e.g. "journal").
  final Map<String, BgSpec> pageBackgrounds;
  final Map<String, ElementStyle> elements;
  final bool builtIn;

  /// Whether the preset was designed for dark (true) or light (false)
  /// mode; null works with both.
  final bool? dark;

  ElementStyle element(String key) => elements[key] ?? const ElementStyle();

  BgSpec backgroundFor(String? page) => (page == null ? null : pageBackgrounds[page]) ?? background;

  /// True when the look changes nothing (the plain Prism theme).
  bool get isPlain => !background.isCustom && pageBackgrounds.isEmpty && colors.isEmpty && elements.values.every((e) => e.isEmpty);

  int? color(String role) => colors[role];

  PrismLook withColor(String role, int? value) {
    final next = Map<String, int>.of(colors);
    value == null ? next.remove(role) : next[role] = value;
    return copyWith(colors: next);
  }

  PrismLook copyWith({
    String? id,
    String? name,
    BgSpec? background,
    Map<String, BgSpec>? pageBackgrounds,
    Map<String, ElementStyle>? elements,
    bool? builtIn,
    Map<String, int>? colors,
    Object? dark = _keep,
  }) => PrismLook(
    id: id ?? this.id,
    name: name ?? this.name,
    background: background ?? this.background,
    pageBackgrounds: pageBackgrounds ?? this.pageBackgrounds,
    elements: elements ?? this.elements,
    builtIn: builtIn ?? this.builtIn,
    dark: identical(dark, _keep) ? this.dark : dark as bool?,
    colors: colors ?? this.colors,
  );

  PrismLook withElement(String key, ElementStyle style) {
    final next = Map<String, ElementStyle>.of(elements);
    style.isEmpty ? next.remove(key) : next[key] = style;
    return copyWith(elements: next);
  }

  PrismLook withPageBackground(String page, BgSpec? bg) {
    final next = Map<String, BgSpec>.of(pageBackgrounds);
    bg == null ? next.remove(page) : next[page] = bg;
    return copyWith(pageBackgrounds: next);
  }

  Map<String, Object?> toJson() => {
    'prismTheme': 1,
    'id': id,
    'name': name,
    'dark': dark,
    'colors': colors,
    'background': background.toJson(),
    'pageBackgrounds': {for (final e in pageBackgrounds.entries) e.key: e.value.toJson()},
    'elements': {for (final e in elements.entries) e.key: e.value.toJson()},
  };

  static PrismLook? fromJson(Object? j) {
    if (j is! Map || j['name'] is! String) return null;
    return PrismLook(
      id: j['id'] is String ? j['id'] as String : 'imported',
      name: (j['name'] as String).trim().isEmpty ? 'Theme' : (j['name'] as String).trim(),
      dark: j['dark'] is bool ? j['dark'] as bool : null,
      colors: {
        if (j['colors'] is Map)
          for (final e in (j['colors'] as Map).entries)
            if (e.key is String && LookColor.all.contains(e.key) && e.value is int) e.key as String: e.value as int,
      },
      background: BgSpec.fromJson(j['background']),
      pageBackgrounds: {
        if (j['pageBackgrounds'] is Map)
          for (final e in (j['pageBackgrounds'] as Map).entries)
            if (e.key is String) e.key as String: BgSpec.fromJson(e.value),
      },
      elements: {
        if (j['elements'] is Map)
          for (final e in (j['elements'] as Map).entries)
            if (e.key is String && LookElement.all.contains(e.key)) e.key as String: ElementStyle.fromJson(e.value),
      },
    );
  }
}

const _keep = Object();

const plainLook = PrismLook(id: 'prism', name: 'Prism', builtIn: true);

/// Designed presets that ship with Prism.
const builtInLooks = <PrismLook>[
  plainLook,
  PrismLook(
    id: 'aurora',
    name: 'Aurora glass',
    builtIn: true,
    dark: true,
    colors: {'accent': 0xFFB388FF, 'secondary': 0xFF18FFFF, 'background': 0xFF151226, 'surface': 0xFF1D1933, 'raised': 0xFF29234A, 'text': 0xFFF3F0FF, 'mutedText': 0xFFBDB6E0, 'outline': 0x55FFFFFF},
    background: BgSpec(kind: BgKind.builtin, builtin: 'aurora', overlay: BgOverlay.scrim, overlayStrength: 0.25),
    elements: {
      'card': ElementStyle(color: 0xFFFFFFFF, opacity: 0.10, radius: 22, borderWidth: 1, borderColor: 0x33FFFFFF),
      'nav': ElementStyle(color: 0xFF151226, opacity: 0.72, borderWidth: 1, borderColor: 0x33FFFFFF),
      'header': ElementStyle(color: 0xFF151226, opacity: 0.35),
      'input': ElementStyle(color: 0xFFFFFFFF, opacity: 0.10, radius: 16),
      'button': ElementStyle(color: 0xFF7C4DFF, color2: 0xFF18FFFF, radius: 22),
      'dialog': ElementStyle(color: 0xFF1D1933, radius: 26),
      'text': ElementStyle(color: 0xFFF4F1FF),
      'icon': ElementStyle(color: 0xFFD6CCFF),
    },
  ),
  PrismLook(
    id: 'sunrise',
    name: 'Sunrise',
    builtIn: true,
    dark: false,
    colors: {'accent': 0xFFE8613C, 'secondary': 0xFF8E5BA8, 'background': 0xFFFFF3EA, 'surface': 0xFFFFFFFF, 'raised': 0xFFFFE9DC, 'text': 0xFF3A2320, 'mutedText': 0xFF7A5A55, 'outline': 0xFFE9C8BD},
    background: BgSpec(kind: BgKind.gradient, colors: [0xFFFFE9D6, 0xFFFFC7C2, 0xFFE3D4FF], gradient: GradientKind.diagonal),
    elements: {
      'card': ElementStyle(color: 0xFFFFFFFF, opacity: 0.72, radius: 20, shadow: 0.25),
      'button': ElementStyle(color: 0xFFFF7A59, color2: 0xFFFF4F8B, radius: 20),
      'nav': ElementStyle(color: 0xFFFFFFFF, opacity: 0.85, shadow: 0.3),
      'input': ElementStyle(color: 0xFFFFFFFF, opacity: 0.8, radius: 14),
      'text': ElementStyle(color: 0xFF3B2A33),
      'icon': ElementStyle(color: 0xFFB5475F),
    },
  ),
  PrismLook(
    id: 'midnight',
    name: 'Midnight neon',
    builtIn: true,
    dark: true,
    colors: {'accent': 0xFF00E5FF, 'secondary': 0xFFFF4081, 'background': 0xFF000000, 'surface': 0xFF0B0B10, 'raised': 0xFF15151E, 'text': 0xFFEFFFFF, 'mutedText': 0xFF8FA7B0, 'outline': 0xFF1F2A33},
    background: BgSpec(kind: BgKind.color, color: 0xFF000000),
    elements: {
      'card': ElementStyle(color: 0xFF0B0B10, radius: 14, borderWidth: 1, borderColor: 0xFF2A2A3A),
      'button': ElementStyle(color: 0xFF00E5FF, radius: 10),
      'nav': ElementStyle(color: 0xFF000000, borderWidth: 1, borderColor: 0xFF00E5FF),
      'input': ElementStyle(color: 0xFF0B0B10, radius: 10, borderWidth: 1, borderColor: 0xFF2A2A3A),
      'dialog': ElementStyle(color: 0xFF0B0B10, radius: 16, borderWidth: 1, borderColor: 0xFF00E5FF),
      'divider': ElementStyle(color: 0xFF2A2A3A),
      'icon': ElementStyle(color: 0xFF00E5FF),
      'text': ElementStyle(color: 0xFFF2F2F7),
    },
  ),
  PrismLook(
    id: 'forest',
    name: 'Forest',
    builtIn: true,
    dark: true,
    colors: {'accent': 0xFF8BC34A, 'secondary': 0xFFE3C26B, 'background': 0xFF0F1F17, 'surface': 0xFF16291E, 'raised': 0xFF1E3628, 'text': 0xFFEAF4E4, 'mutedText': 0xFFA7C2A0, 'outline': 0xFF2E4A39},
    background: BgSpec(kind: BgKind.builtin, builtin: 'forest'),
    elements: {
      'card': ElementStyle(color: 0xFF12261D, opacity: 0.82, radius: 18),
      'button': ElementStyle(color: 0xFF7BC47F, radius: 18),
      'nav': ElementStyle(color: 0xFF0C1A14, opacity: 0.9),
      'input': ElementStyle(color: 0xFF12261D, opacity: 0.9),
      'icon': ElementStyle(color: 0xFFA8D5AA),
      'text': ElementStyle(color: 0xFFEAF4EA),
    },
  ),
  PrismLook(
    id: 'ocean',
    name: 'Ocean',
    builtIn: true,
    dark: true,
    colors: {'accent': 0xFF4FC3F7, 'secondary': 0xFF80CBC4, 'background': 0xFF06182B, 'surface': 0xFF0C2440, 'raised': 0xFF123154, 'text': 0xFFE6F4FF, 'mutedText': 0xFF9CB8D0, 'outline': 0xFF1E4266},
    background: BgSpec(kind: BgKind.builtin, builtin: 'ocean'),
    elements: {
      'card': ElementStyle(color: 0xFF0E2A3F, opacity: 0.78, radius: 24),
      'button': ElementStyle(color: 0xFF4FC3F7, color2: 0xFF4DD0E1, radius: 24),
      'nav': ElementStyle(color: 0xFF081B2A, opacity: 0.88),
      'icon': ElementStyle(color: 0xFF9BE0F7),
      'text': ElementStyle(color: 0xFFEAF6FB),
    },
  ),
  PrismLook(
    id: 'paper',
    name: 'Paper',
    builtIn: true,
    dark: false,
    colors: {'accent': 0xFF8D6E63, 'secondary': 0xFF5E7D6A, 'background': 0xFFFAF6EE, 'surface': 0xFFFFFDF8, 'raised': 0xFFF2EBDD, 'text': 0xFF33291F, 'mutedText': 0xFF7B6C5C, 'outline': 0xFFE0D4C0},
    background: BgSpec(kind: BgKind.color, color: 0xFFFAF6EE),
    elements: {
      'card': ElementStyle(color: 0xFFFFFFFF, radius: 4, borderWidth: 1, borderColor: 0xFFD9D0C0),
      'button': ElementStyle(color: 0xFF2F3E46, radius: 4),
      'nav': ElementStyle(color: 0xFFFFFFFF, borderWidth: 1, borderColor: 0xFFD9D0C0),
      'input': ElementStyle(color: 0xFFFFFFFF, radius: 4, borderWidth: 1, borderColor: 0xFFBDB29E),
      'dialog': ElementStyle(color: 0xFFFFFFFF, radius: 6),
      'divider': ElementStyle(color: 0xFFD9D0C0),
      'text': ElementStyle(color: 0xFF22262A),
      'icon': ElementStyle(color: 0xFF2F3E46),
    },
  ),
  PrismLook(
    id: 'dusk',
    name: 'Dusk',
    builtIn: true,
    dark: true,
    colors: {'accent': 0xFFFF8A65, 'secondary': 0xFFBA68C8, 'background': 0xFF1E1528, 'surface': 0xFF281C36, 'raised': 0xFF332446, 'text': 0xFFF8ECF4, 'mutedText': 0xFFC9AFC4, 'outline': 0xFF4A3660},
    background: BgSpec(kind: BgKind.builtin, builtin: 'dusk', overlay: BgOverlay.vignette, overlayStrength: 0.35),
    elements: {
      'card': ElementStyle(color: 0xFF2B1B3D, opacity: 0.7, radius: 20, borderWidth: 1, borderColor: 0x22FFFFFF),
      'button': ElementStyle(color: 0xFFFFB199, color2: 0xFFFF6FA5, radius: 20),
      'nav': ElementStyle(color: 0xFF1B1029, opacity: 0.85),
      'icon': ElementStyle(color: 0xFFFFC6B3),
      'text': ElementStyle(color: 0xFFFFF3EE),
    },
  ),
];

/// Pages that can have their own background or theme.
const lookPages = [
  'home', 'members', 'chat', 'boards', 'stories', 'journal', 'notes', 'mood', 'calendar', 'sleep', 'cycle',
  'fitness', 'school', 'finance', 'relationships', 'subsystems', 'headspace', 'achievements', 'dictionary',
  'polls', 'habits', 'music', 'statistics', 'nutrition', 'scrapbook', 'connections', 'analytics',
  'availability', 'introductions', 'social', 'locations', 'reminders', 'settings',
];

/// Everything the appearance system remembers.
@immutable
class AppearanceState {
  const AppearanceState({
    this.looks = const [],
    this.activeId = 'prism',
    this.auto = false,
    this.lightId = 'prism',
    this.darkId = 'prism',
    this.pageLooks = const {},
    this.modifiedAt = 0,
    this.showMemberBanners = false,
    this.bannerPositions = const {},
  });

  /// Banner crop per member id: focal point (−1…1) and zoom (1…3).
  final Map<String, ({double x, double y, double zoom})> bannerPositions;

  /// Show each alter's profile banner on Headmates cards.
  final bool showMemberBanners;

  /// The user's own presets.
  final List<PrismLook> looks;
  final String activeId;

  /// Switch between [lightId] and [darkId] with the app's light/dark mode.
  final bool auto;
  final String lightId;
  final String darkId;

  /// A different preset for individual pages (page id → preset id).
  final Map<String, String> pageLooks;
  final int modifiedAt;

  List<PrismLook> get all => [...builtInLooks, ...looks];

  PrismLook look(String id) => all.firstWhere((l) => l.id == id, orElse: () => plainLook);

  PrismLook active({required bool dark}) => look(auto ? (dark ? darkId : lightId) : activeId);

  PrismLook? pageLook(String? page) {
    final id = page == null ? null : pageLooks[page];
    return id == null ? null : look(id);
  }

  AppearanceState copyWith({
    List<PrismLook>? looks,
    String? activeId,
    bool? auto,
    String? lightId,
    String? darkId,
    Map<String, String>? pageLooks,
    int? modifiedAt,
    bool? showMemberBanners,
    Map<String, ({double x, double y, double zoom})>? bannerPositions,
  }) => AppearanceState(
    showMemberBanners: showMemberBanners ?? this.showMemberBanners,
    bannerPositions: bannerPositions ?? this.bannerPositions,
    looks: looks ?? this.looks,
    activeId: activeId ?? this.activeId,
    auto: auto ?? this.auto,
    lightId: lightId ?? this.lightId,
    darkId: darkId ?? this.darkId,
    pageLooks: pageLooks ?? this.pageLooks,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );

  Map<String, Object?> toJson() => {
    'looks': [for (final l in looks) l.toJson()],
    'activeId': activeId,
    'auto': auto,
    'lightId': lightId,
    'darkId': darkId,
    'pageLooks': pageLooks,
    'modifiedAt': modifiedAt,
    'showMemberBanners': showMemberBanners,
    'bannerPositions': {for (final e in bannerPositions.entries) e.key: [e.value.x, e.value.y, e.value.zoom]},
  };

  static AppearanceState fromJson(Object? j) {
    if (j is! Map) return const AppearanceState();
    String s(String k) => j[k] is String ? j[k] as String : 'prism';
    return AppearanceState(
      looks: [
        if (j['looks'] is List)
          for (final l in j['looks'] as List) ?PrismLook.fromJson(l),
      ],
      activeId: s('activeId'),
      auto: j['auto'] == true,
      lightId: s('lightId'),
      darkId: s('darkId'),
      pageLooks: {
        if (j['pageLooks'] is Map)
          for (final e in (j['pageLooks'] as Map).entries)
            if (e.key is String && e.value is String) e.key as String: e.value as String,
      },
      modifiedAt: j['modifiedAt'] is int ? j['modifiedAt'] as int : 0,
      showMemberBanners: j['showMemberBanners'] == true,
      bannerPositions: {
        if (j['bannerPositions'] is Map)
          for (final e in (j['bannerPositions'] as Map).entries)
            if (e.key is String && e.value is List && (e.value as List).length == 3 && (e.value as List).every((v) => v is num))
              e.key as String: (
                x: ((e.value as List)[0] as num).toDouble().clamp(-1, 1).toDouble(),
                y: ((e.value as List)[1] as num).toDouble().clamp(-1, 1).toDouble(),
                zoom: ((e.value as List)[2] as num).toDouble().clamp(1, 3).toDouble(),
              ),
      },
    );
  }
}
