import 'package:flutter/foundation.dart';

import 'package:prism_plurality/features/seasonal/living_environment.dart';
import 'package:prism_plurality/features/seasonal/seasonal_calendar.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';

/// The eight appearance layers. Only 4–8 belong to Seasonal Living; 1–3 are
/// the person's own theme, background and UI styling, which seasonal
/// decorations never touch.
enum DecoLayer {
  staticDeco('Static decorations', 'Decoraciones fijas'),
  animated('Animated decorations', 'Decoraciones animadas'),
  ambient('Ambient particles', 'Partículas ambientales'),
  interactive('Interactive objects', 'Objetos interactivos'),
  companion('Companion accessories', 'Accesorios de compañeros');

  const DecoLayer(this.en, this.es);
  final String en, es;
}

/// How much Seasonal Living is allowed to do.
enum DecoPerformance {
  off(
    'Off',
    'Apagado',
    'No seasonal decorations.',
    'Sin decoraciones de temporada.',
  ),
  minimal(
    'Minimal',
    'Mínimo',
    'Static decorations only.',
    'Solo decoraciones fijas.',
  ),
  balanced(
    'Balanced',
    'Equilibrado',
    'Static decorations and gentle animation.',
    'Decoraciones fijas y animación suave.',
  ),
  immersive(
    'Immersive',
    'Inmersivo',
    'Everything, including ambient effects and interactions.',
    'Todo, con efectos ambientales e interacciones.',
  ),
  custom(
    'Custom',
    'Personalizado',
    'You choose every effect.',
    'Tú eliges cada efecto.',
  );

  const DecoPerformance(this.en, this.es, this.descEn, this.descEs);
  final String en, es, descEn, descEs;
}

/// What a kind of decoration is, for the editor and the painter.
enum DecoKind {
  garland('Garland', DecoLayer.staticDeco),
  fairyLights('Fairy lights', DecoLayer.animated),
  ribbon('Ribbon', DecoLayer.staticDeco),
  bow('Bow', DecoLayer.staticDeco),
  lantern('Lantern', DecoLayer.animated),
  wreath('Wreath', DecoLayer.staticDeco),
  ornament('Hanging ornament', DecoLayer.animated),
  window('Window', DecoLayer.staticDeco),
  flower('Flowers', DecoLayer.staticDeco),
  candle('Candle', DecoLayer.animated),
  foliage('Foliage', DecoLayer.staticDeco),
  corner('Corner piece', DecoLayer.staticDeco),
  border('Border', DecoLayer.staticDeco),
  illustration('Illustration', DecoLayer.staticDeco),
  furniture('Furniture', DecoLayer.staticDeco),
  sticker('Imported image', DecoLayer.staticDeco),
  particles('Falling things', DecoLayer.ambient),
  interactive('Interactive object', DecoLayer.interactive),

  /// Time-of-day light, fog, sunshine and other weather washes. Purely
  /// decorative and drawn faintly behind everything else.
  environment('Environment', DecoLayer.staticDeco);

  const DecoKind(this.label, this.layer);
  final String label;
  final DecoLayer layer;
}

/// Where a decoration is attached. The screen edges always exist; the UI
/// ones follow real parts of Prism (a profile picture, a widget…) when they
/// are on screen.
enum DecoAnchor {
  screen('Whole screen'),
  top('Top navigation / header'),
  bottom('Bottom navigation'),
  sidebar('Sidebar'),
  topLeft('Top-left corner'),
  topRight('Top-right corner'),
  bottomLeft('Bottom-left corner'),
  bottomRight('Bottom-right corner'),
  pageHeader('Page header'),
  dashboardEdge('Dashboard edge'),
  profilePicture('Profile picture'),
  banner('Banner'),
  widget('Widget border'),
  card('Card'),
  divider('Divider'),
  empty('Empty space'),
  floating('Floating overlay'),
  loading('Loading screen'),
  companionArea('Companion area'),
  calendarHeader('Calendar header');

  const DecoAnchor(this.label);
  final String label;

  /// Anchors that follow a real widget rather than a screen region.
  bool get followsWidget => const {
    profilePicture,
    banner,
    widget,
    card,
    divider,
    companionArea,
    calendarHeader,
    pageHeader,
  }.contains(this);
}

enum DeviceClass { mobile, tablet, desktop }

DeviceClass deviceClassFor(double width) => width < 600
    ? DeviceClass.mobile
    : (width < 1024 ? DeviceClass.tablet : DeviceClass.desktop);

/// Per-device nudge to an item's position and size.
@immutable
class DeviceTweak {
  const DeviceTweak({
    this.dx = 0,
    this.dy = 0,
    this.scale = 1,
    this.hidden = false,
  });
  final double dx, dy, scale;
  final bool hidden;

  bool get isDefault => dx == 0 && dy == 0 && scale == 1 && !hidden;

  Map<String, Object?> toJson() => {
    if (dx != 0) 'dx': dx,
    if (dy != 0) 'dy': dy,
    if (scale != 1) 's': scale,
    if (hidden) 'h': true,
  };

  static DeviceTweak fromJson(Object? o) {
    if (o is! Map) return const DeviceTweak();
    double d(String k, double def) => (o[k] as num?)?.toDouble() ?? def;
    return DeviceTweak(
      dx: d('dx', 0).clamp(-1.0, 1.0),
      dy: d('dy', 0).clamp(-1.0, 1.0),
      scale: d('s', 1).clamp(0.2, 4.0),
      hidden: o['h'] == true,
    );
  }
}

/// One thing placed on screen. Positions and sizes are fractions of the
/// anchor's frame, so the same arrangement fits phones, tablets and desktops.
class DecorItem {
  DecorItem({
    required this.id,
    required this.kind,
    this.variationId,
    this.glyph,
    this.image,
    this.anchor = DecoAnchor.screen,
    this.x = 0.5,
    this.y = 0.5,
    this.w = 0.2,
    this.rot = 0,
    this.opacity = 1,
    this.color,
    this.color2,
    this.flipX = false,
    this.flipY = false,
    this.z = 0,
    this.locked = false,
    this.group,
    this.speed = 1,
    this.frequency = 1,
    this.enabled = true,
    this.pages = const [],
    Map<String, DeviceTweak>? tweaks,
    this.behavior,
    this.range = 0.15,
    this.direction = 0,
    this.sensitivity = 0.5,
    this.sound = false,
    this.tap = false,
    this.phases = const [],
    this.idle = 'none',
    this.companion = false,
    this.still = 'still',
    this.animate = true,
  }) : tweaks = tweaks ?? {};

  // ── Living behaviour ────────────────────────────────────────────────

  /// How it moves: an [AssetBehavior] name ('sway', 'walk', 'orbit'…), or
  /// null / 'none' to stay put.
  String? behavior;

  /// 0–1: how far it may wander, as a share of the screen.
  double range;

  /// Degrees: which way it walks, drifts or swims (0 = right).
  double direction;

  /// 0–1: how strongly it reacts when tapped.
  double sensitivity;

  /// Plays a soft sound when tapped.
  bool sound;

  /// Tappable (a lamp switches, a book opens). Off by default so nothing
  /// ever sits on top of buttons unless the person asks.
  bool tap;

  /// Time phases it shows in ('morning', 'evening'…); empty = always.
  List<String> phases;

  /// What it does while nothing else is happening: 'none' | 'breathe' | 'peek'.
  String idle;

  /// Companions notice and react to it.
  bool companion;

  /// With reduced motion: 'still' (frozen in place) or 'hide'.
  String still;

  /// False keeps the object on screen but stops it moving.
  bool animate;

  /// Whether this item moves at all.
  bool get moves =>
      animate && behavior != null && behavior != 'none' && behavior!.isNotEmpty;

  final String id;
  DecoKind kind;

  /// The look this item takes its palette and styles from. Items from
  /// different collections can sit side by side.
  String? variationId;

  /// An emoji / symbol, for kinds that draw one.
  String? glyph;

  /// An imported picture (media id) for [DecoKind.sticker].
  String? image;
  DecoAnchor anchor;
  double x, y, w, rot, opacity;
  int? color, color2;
  bool flipX, flipY;
  int z;
  bool locked;
  String? group;

  /// 0.2–3: how fast it moves. 0–1: how often it happens.
  double speed, frequency;
  bool enabled;

  /// Route prefixes where it shows ('/home', '/calendar'…); empty = everywhere.
  List<String> pages;

  /// Per device class: 'mobile' | 'tablet' | 'desktop'.
  Map<String, DeviceTweak> tweaks;

  DecoLayer get layer => kind.layer;

  DeviceTweak tweakFor(DeviceClass c) => tweaks[c.name] ?? const DeviceTweak();

  bool showsOn(String? route) =>
      pages.isEmpty ||
      route == null ||
      pages.any(
        (p) =>
            route == p || route.startsWith('$p/') || (p == '/' && route == '/'),
      );

  DecorItem copy({String? newId}) =>
      DecorItem.fromJson({
          ...toJson(),
          'id':
              newId ??
              '${id}c${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
        })!
        ..x = (x + 0.04).clamp(0.0, 1.0)
        ..y = (y + 0.04).clamp(0.0, 1.0);

  static double _r(double v) => (v * 10000).round() / 10000;

  Map<String, Object?> toJson() => {
    'id': id,
    'k': kind.name,
    'v': ?variationId,
    'g': ?glyph,
    'im': ?image,
    if (anchor != DecoAnchor.screen) 'an': anchor.name,
    'x': _r(x),
    'y': _r(y),
    'w': _r(w),
    if (rot != 0) 'r': _r(rot),
    if (opacity != 1) 'o': _r(opacity),
    'c': ?color,
    'c2': ?color2,
    if (flipX) 'fx': true,
    if (flipY) 'fy': true,
    if (z != 0) 'z': z,
    if (locked) 'lk': true,
    'gr': ?group,
    if (speed != 1) 'sp': _r(speed),
    if (frequency != 1) 'fq': _r(frequency),
    if (!enabled) 'off': true,
    if (pages.isNotEmpty) 'pg': pages,
    if (tweaks.values.any((t) => !t.isDefault))
      'tw': {
        for (final e in tweaks.entries)
          if (!e.value.isDefault) e.key: e.value.toJson(),
      },
    'bh': ?behavior,
    if (range != 0.15) 'rg': _r(range),
    if (direction != 0) 'dr': _r(direction),
    if (sensitivity != 0.5) 'se': _r(sensitivity),
    if (sound) 'snd': true,
    if (tap) 'tap': true,
    if (phases.isNotEmpty) 'phs': phases,
    if (idle != 'none') 'idl': idle,
    if (companion) 'cmp': true,
    if (still != 'still') 'rms': still,
    if (!animate) 'na': true,
  };

  static DecorItem? fromJson(Object? o) {
    if (o is! Map) return null;
    final kind = DecoKind.values.where((k) => k.name == o['k']).firstOrNull;
    if (kind == null) return null;
    double d(String k, double def) => (o[k] as num?)?.toDouble() ?? def;
    final tw = <String, DeviceTweak>{};
    if (o['tw'] is Map) {
      for (final e in (o['tw'] as Map).entries) {
        if (e.key is String && DeviceClass.values.any((c) => c.name == e.key))
          tw[e.key as String] = DeviceTweak.fromJson(e.value);
      }
    }
    return DecorItem(
      id: '${o['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      variationId: o['v'] as String?,
      glyph: o['g'] as String?,
      image: o['im'] as String?,
      anchor:
          DecoAnchor.values.where((a) => a.name == o['an']).firstOrNull ??
          DecoAnchor.screen,
      x: d('x', 0.5).clamp(-0.5, 1.5),
      y: d('y', 0.5).clamp(-0.5, 1.5),
      w: d('w', 0.2).clamp(0.01, 3.0),
      rot: d('r', 0),
      opacity: d('o', 1).clamp(0.0, 1.0),
      color: (o['c'] as num?)?.toInt(),
      color2: (o['c2'] as num?)?.toInt(),
      flipX: o['fx'] == true,
      flipY: o['fy'] == true,
      z: (o['z'] as num?)?.toInt() ?? 0,
      locked: o['lk'] == true,
      group: o['gr'] as String?,
      speed: d('sp', 1).clamp(0.2, 3.0),
      frequency: d('fq', 1).clamp(0.0, 1.0),
      enabled: o['off'] != true,
      pages: [
        if (o['pg'] is List)
          for (final p in o['pg'] as List)
            if (p is String) p,
      ],
      tweaks: tw,
      behavior: o['bh'] is String ? o['bh'] as String : null,
      range: d('rg', 0.15).clamp(0.0, 1.0),
      direction: d('dr', 0) % 360,
      sensitivity: d('se', 0.5).clamp(0.0, 1.0),
      sound: o['snd'] == true,
      tap: o['tap'] == true,
      phases: [
        if (o['phs'] is List)
          for (final p in o['phs'] as List)
            if (p is String) p,
      ],
      idle: const {'breathe', 'peek'}.contains(o['idl'])
          ? o['idl'] as String
          : 'none',
      companion: o['cmp'] == true,
      still: o['rms'] == 'hide' ? 'hide' : 'still',
      animate: o['na'] != true,
    );
  }
}

/// Which seasonal layers are on, and how heavy they may be.
@immutable
class DecoLayerSettings {
  const DecoLayerSettings({
    this.enabled = const {
      DecoLayer.staticDeco,
      DecoLayer.animated,
      DecoLayer.ambient,
      DecoLayer.interactive,
      DecoLayer.companion,
    },
    this.particleDensity = 0.6,
    this.animationSpeed = 1,
    this.maxAnimated = 12,
  });

  final Set<DecoLayer> enabled;

  /// 0–1.
  final double particleDensity;

  /// 0.2–2.
  final double animationSpeed;

  /// Most animated items drawn at once.
  final int maxAnimated;

  bool on(DecoLayer l) => enabled.contains(l);

  DecoLayerSettings copyWith({
    Set<DecoLayer>? enabled,
    double? particleDensity,
    double? animationSpeed,
    int? maxAnimated,
  }) => DecoLayerSettings(
    enabled: enabled ?? this.enabled,
    particleDensity: particleDensity ?? this.particleDensity,
    animationSpeed: animationSpeed ?? this.animationSpeed,
    maxAnimated: maxAnimated ?? this.maxAnimated,
  );

  Map<String, Object?> toJson() => {
    'on': [for (final l in enabled) l.name],
    'pd': particleDensity,
    'as': animationSpeed,
    'ma': maxAnimated,
  };

  static DecoLayerSettings fromJson(Object? o) {
    if (o is! Map) return const DecoLayerSettings();
    final on = <DecoLayer>{
      if (o['on'] is List)
        for (final n in o['on'] as List)
          ...DecoLayer.values.where((l) => l.name == n),
    };
    return DecoLayerSettings(
      enabled: o['on'] is List ? on : const DecoLayerSettings().enabled,
      particleDensity: ((o['pd'] as num?)?.toDouble() ?? 0.6).clamp(0.0, 1.0),
      animationSpeed: ((o['as'] as num?)?.toDouble() ?? 1).clamp(0.2, 2.0),
      maxAnimated: ((o['ma'] as num?)?.toInt() ?? 12).clamp(0, 60),
    );
  }

  /// What a performance mode lets through.
  DecoLayerSettings forMode(DecoPerformance m) => switch (m) {
    DecoPerformance.off => const DecoLayerSettings(enabled: {}),
    DecoPerformance.minimal => const DecoLayerSettings(
      enabled: {DecoLayer.staticDeco, DecoLayer.companion},
      particleDensity: 0,
      maxAnimated: 0,
    ),
    DecoPerformance.balanced => DecoLayerSettings(
      enabled: {
        DecoLayer.staticDeco,
        DecoLayer.animated,
        DecoLayer.ambient,
        DecoLayer.companion,
      },
      particleDensity: 0.4,
      animationSpeed: animationSpeed.clamp(0.2, 1.2),
      maxAnimated: 8,
    ),
    DecoPerformance.immersive => const DecoLayerSettings(
      particleDensity: 0.9,
      animationSpeed: 1,
      maxAnimated: 24,
    ),
    DecoPerformance.custom => this,
  };
}

/// A saved arrangement.
class DecorPreset {
  DecorPreset({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'My presets',
    List<DecorItem>? items,
    this.layers = const DecoLayerSettings(),
    this.thumbnail,
    this.pages = const [],
  }) : items = items ?? [];

  final String id;
  String name, description, category;
  List<DecorItem> items;
  DecoLayerSettings layers;

  /// Small PNG preview (base64) rendered when the preset is saved.
  String? thumbnail;

  /// If set, this preset only applies on these pages.
  List<String> pages;

  Map<String, Object?> toJson() => {
    'v': 1,
    'id': id,
    'n': name,
    if (description.isNotEmpty) 'd': description,
    'ct': category,
    'it': [for (final i in items) i.toJson()],
    'ly': layers.toJson(),
    'th': ?thumbnail,
    if (pages.isNotEmpty) 'pg': pages,
  };

  static DecorPreset? fromJson(Object? o) {
    if (o is! Map) return null;
    return DecorPreset(
      id: '${o['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      name: '${o['n'] ?? 'Preset'}',
      description: '${o['d'] ?? ''}',
      category: '${o['ct'] ?? 'My presets'}',
      items: [
        if (o['it'] is List)
          for (final i in o['it'] as List) ?DecorItem.fromJson(i),
      ],
      layers: DecoLayerSettings.fromJson(o['ly']),
      thumbnail: o['th'] as String?,
      pages: [
        if (o['pg'] is List)
          for (final p in o['pg'] as List)
            if (p is String) p,
      ],
    );
  }
}

/// A celebration the person made up themselves.
class CustomCelebration {
  CustomCelebration({
    required this.id,
    required this.name,
    this.emoji = '🎉',
    required this.month,
    required this.day,
    this.year,
    this.leadDays = 3,
    this.extendDays = 1,
    this.variationId,
    this.presetId,
    this.greeting = '',
    this.yearly = true,
    this.memberId,
    this.kind = 'custom',
  });

  final String id;
  String name, emoji, greeting;
  int month, day;

  /// Set for one-off events (a graduation); null for yearly ones.
  int? year;
  int leadDays, extendDays;
  String? variationId, presetId;
  bool yearly;

  /// An alter this celebration belongs to (their birthday).
  String? memberId;

  /// custom | anniversary | birthday | milestone | fictional | tradition
  String kind;

  DayRange? rangeIn(int y) {
    if (!yearly && (year ?? y) != y) return null;
    final base = DateTime(y, month, day);
    if (base.month != month) return null;
    return DayRange(
      base.subtract(Duration(days: leadDays)),
      base.add(Duration(days: extendDays)),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'n': name,
    'e': emoji,
    'm': month,
    'd': day,
    'y': ?year,
    'ld': leadDays,
    'ed': extendDays,
    'vr': ?variationId,
    'ps': ?presetId,
    if (greeting.isNotEmpty) 'gr': greeting,
    'yr': yearly,
    'mb': ?memberId,
    'kd': kind,
  };

  static CustomCelebration? fromJson(Object? o) {
    if (o is! Map || o['m'] is! num || o['d'] is! num) return null;
    return CustomCelebration(
      id: '${o['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      name: '${o['n'] ?? 'Celebration'}',
      emoji: '${o['e'] ?? '🎉'}',
      month: (o['m'] as num).toInt().clamp(1, 12),
      day: (o['d'] as num).toInt().clamp(1, 31),
      year: (o['y'] as num?)?.toInt(),
      leadDays: ((o['ld'] as num?)?.toInt() ?? 3).clamp(0, 60),
      extendDays: ((o['ed'] as num?)?.toInt() ?? 1).clamp(0, 60),
      variationId: o['vr'] as String?,
      presetId: o['ps'] as String?,
      greeting: '${o['gr'] ?? ''}',
      yearly: o['yr'] != false,
      memberId: o['mb'] as String?,
      kind: '${o['kd'] ?? 'custom'}',
    );
  }
}

/// Everything someone chooses about Seasonal Living.
@immutable
class SeasonalPrefs {
  const SeasonalPrefs({
    this.performance = DecoPerformance.off,
    this.layers = const DecoLayerSettings(),
    this.region = SeasonalRegion.global,
    this.hemisphere = Hemisphere.auto,
    this.celebrated = const {},
    this.hidden = const {},
    this.autoSchedule = false,
    this.manualVariation,
    this.manualUntil,
    this.permanentVariation,
    this.variationFor = const {},
    this.extendDays = const {},
    this.customDates = const {},
    this.celebrations = const [],
    this.alterPresets = const {},
    this.pagePresets = const {},
    this.activePresetId,
    this.reducedMotion = false,
    this.greetingsOn = true,
    this.audioOn = false,
    this.audioId,
    this.audioVolume = 0.35,
    this.integrations = const {},
    this.livingVariation,
    this.env = const EnvSettings(),
    this.layoutVariation,
    this.layoutParts,
    this.version = 1,
  });

  /// A look whose layout arrangement decorates headers, cards, dividers,
  /// profile pictures, the navigation bar and hanging trims. Separate from
  /// [livingVariation]: either can be on without the other.
  final String? layoutVariation;

  /// Which parts of the arrangement are on; null = all of them.
  final Set<String>? layoutParts;

  /// Time of day, weather and music reactions.
  final EnvSettings env;

  /// Off until the person turns it on.
  final DecoPerformance performance;
  final DecoLayerSettings layers;
  final SeasonalRegion region;
  final Hemisphere hemisphere;

  /// Collections the person celebrates / hides.
  final Set<String> celebrated, hidden;

  /// Automatic scheduling is opt-in.
  final bool autoSchedule;

  /// Manually activated look (`collection.index`) and optional end date.
  final String? manualVariation;
  final DateTime? manualUntil;

  /// A look kept on all year round.
  final String? permanentVariation;

  /// The look chosen for each collection (`collection` → `collection.index`).
  final Map<String, String> variationFor;

  /// Extra days to keep a collection going after it ends.
  final Map<String, int> extendDays;

  /// Custom start/end for a collection: `id` → `yyyy-MM-dd/yyyy-MM-dd`.
  final Map<String, String> customDates;
  final List<CustomCelebration> celebrations;

  /// Alter id → preset id.
  final Map<String, String> alterPresets;

  /// Page (route prefix) → preset id, for per-page arrangements.
  final Map<String, String> pagePresets;

  /// The person's own arrangement (a preset id), shown with or without a season.
  final String? activePresetId;
  final bool reducedMotion;
  final bool greetingsOn, audioOn;
  final String? audioId;
  final double audioVolume;

  /// Per-feature switches ('home', 'profiles', 'calendar'…); missing = on.
  final Map<String, bool> integrations;
  final int version;

  bool integrationOn(String key) => integrations[key] ?? true;

  /// A permanent living look (`genre.index`), its own layer: shown all year,
  /// alongside (never instead of) seasonal looks and the person's presets.
  final String? livingVariation;

  SeasonalPrefs copyWith({
    DecoPerformance? performance,
    DecoLayerSettings? layers,
    SeasonalRegion? region,
    Hemisphere? hemisphere,
    Set<String>? celebrated,
    Set<String>? hidden,
    bool? autoSchedule,
    Object? manualVariation = _k,
    Object? manualUntil = _k,
    Object? permanentVariation = _k,
    Map<String, String>? variationFor,
    Map<String, int>? extendDays,
    Map<String, String>? customDates,
    List<CustomCelebration>? celebrations,
    Map<String, String>? alterPresets,
    Map<String, String>? pagePresets,
    Object? activePresetId = _k,
    bool? reducedMotion,
    bool? greetingsOn,
    bool? audioOn,
    Object? audioId = _k,
    double? audioVolume,
    Map<String, bool>? integrations,
    Object? livingVariation = _k,
    EnvSettings? env,
    Object? layoutVariation = _k,
    Object? layoutParts = _k,
  }) => SeasonalPrefs(
    performance: performance ?? this.performance,
    layers: layers ?? this.layers,
    region: region ?? this.region,
    hemisphere: hemisphere ?? this.hemisphere,
    celebrated: celebrated ?? this.celebrated,
    hidden: hidden ?? this.hidden,
    autoSchedule: autoSchedule ?? this.autoSchedule,
    manualVariation: identical(manualVariation, _k)
        ? this.manualVariation
        : manualVariation as String?,
    manualUntil: identical(manualUntil, _k)
        ? this.manualUntil
        : manualUntil as DateTime?,
    permanentVariation: identical(permanentVariation, _k)
        ? this.permanentVariation
        : permanentVariation as String?,
    variationFor: variationFor ?? this.variationFor,
    extendDays: extendDays ?? this.extendDays,
    customDates: customDates ?? this.customDates,
    celebrations: celebrations ?? this.celebrations,
    alterPresets: alterPresets ?? this.alterPresets,
    pagePresets: pagePresets ?? this.pagePresets,
    activePresetId: identical(activePresetId, _k)
        ? this.activePresetId
        : activePresetId as String?,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    greetingsOn: greetingsOn ?? this.greetingsOn,
    audioOn: audioOn ?? this.audioOn,
    audioId: identical(audioId, _k) ? this.audioId : audioId as String?,
    audioVolume: audioVolume ?? this.audioVolume,
    integrations: integrations ?? this.integrations,
    livingVariation: identical(livingVariation, _k)
        ? this.livingVariation
        : livingVariation as String?,
    env: env ?? this.env,
    layoutVariation: identical(layoutVariation, _k)
        ? this.layoutVariation
        : layoutVariation as String?,
    layoutParts: identical(layoutParts, _k)
        ? this.layoutParts
        : layoutParts as Set<String>?,
    version: version,
  );

  static const _k = Object();

  Map<String, Object?> toJson() => {
    'v': 1,
    'pf': performance.name,
    'ly': layers.toJson(),
    'rg': region.name,
    'hm': hemisphere.name,
    'cel': celebrated.toList(),
    'hid': hidden.toList(),
    'auto': autoSchedule,
    'mv': ?manualVariation,
    'mu': ?manualUntil?.toIso8601String(),
    'pv': ?permanentVariation,
    if (variationFor.isNotEmpty) 'vf': variationFor,
    if (extendDays.isNotEmpty) 'ex': extendDays,
    if (customDates.isNotEmpty) 'cd': customDates,
    if (celebrations.isNotEmpty)
      'cb': [for (final c in celebrations) c.toJson()],
    if (alterPresets.isNotEmpty) 'ap': alterPresets,
    if (pagePresets.isNotEmpty) 'pp': pagePresets,
    'ap0': ?activePresetId,
    if (reducedMotion) 'rm': true,
    'gr': greetingsOn,
    'au': audioOn,
    'ai': ?audioId,
    'av': audioVolume,
    if (integrations.isNotEmpty) 'in': integrations,
    'lv': ?livingVariation,
    if (env.toJson().isNotEmpty) 'env': env.toJson(),
    'lo': ?layoutVariation,
    if (layoutParts != null) 'lp': layoutParts!.toList(),
  };

  static Set<String> _strSet(Object? o) => {
    if (o is List)
      for (final x in o)
        if (x is String) x,
  };

  static Map<String, String> _strMap(Object? o) => {
    if (o is Map)
      for (final e in o.entries)
        if (e.key is String && e.value != null) e.key as String: '${e.value}',
  };

  static SeasonalPrefs fromJson(Object? o) {
    if (o is! Map) return const SeasonalPrefs();
    return SeasonalPrefs(
      performance:
          DecoPerformance.values.where((p) => p.name == o['pf']).firstOrNull ??
          DecoPerformance.off,
      layers: DecoLayerSettings.fromJson(o['ly']),
      region:
          SeasonalRegion.values.where((r) => r.name == o['rg']).firstOrNull ??
          SeasonalRegion.global,
      hemisphere:
          Hemisphere.values.where((h) => h.name == o['hm']).firstOrNull ??
          Hemisphere.auto,
      celebrated: _strSet(o['cel']),
      hidden: _strSet(o['hid']),
      autoSchedule: o['auto'] == true,
      manualVariation: o['mv'] as String?,
      manualUntil: DateTime.tryParse('${o['mu'] ?? ''}'),
      permanentVariation: o['pv'] as String?,
      variationFor: _strMap(o['vf']),
      extendDays: {
        if (o['ex'] is Map)
          for (final e in (o['ex'] as Map).entries)
            if (e.key is String && e.value is num)
              e.key as String: (e.value as num).toInt().clamp(0, 60),
      },
      customDates: _strMap(o['cd']),
      celebrations: [
        if (o['cb'] is List)
          for (final c in o['cb'] as List) ?CustomCelebration.fromJson(c),
      ],
      alterPresets: _strMap(o['ap']),
      pagePresets: _strMap(o['pp']),
      activePresetId: o['ap0'] as String?,
      reducedMotion: o['rm'] == true,
      greetingsOn: o['gr'] != false,
      audioOn: o['au'] == true,
      audioId: o['ai'] as String?,
      audioVolume: ((o['av'] as num?)?.toDouble() ?? 0.35).clamp(0.0, 1.0),
      integrations: {
        if (o['in'] is Map)
          for (final e in (o['in'] as Map).entries)
            if (e.key is String && e.value is bool)
              e.key as String: e.value as bool,
      },
      livingVariation: o['lv'] is String ? o['lv'] as String : null,
      env: EnvSettings.fromJson(o['env']),
      layoutVariation: o['lo'] is String ? o['lo'] as String : null,
      layoutParts: o['lp'] is List ? _strSet(o['lp']) : null,
    );
  }
}

/// Why a look is showing.
enum ActiveReason { manual, celebration, scheduled, permanent }

@immutable
class ActiveSeason {
  const ActiveSeason({
    required this.variation,
    required this.reason,
    this.celebration,
    this.range,
  });
  final SeasonalVariation? variation;
  final ActiveReason reason;
  final CustomCelebration? celebration;
  final DayRange? range;
}

/// Works out which look (if any) should be showing on [now]. Pure and
/// predictable: nothing changes unless the person opted in.
///
/// Order: a look they switched on by hand, then their own celebrations, then
/// scheduled holidays (only if automatic scheduling is on), then a look they
/// keep all year.
ActiveSeason? resolveActiveSeason(DateTime now, SeasonalPrefs p) {
  if (p.performance == DecoPerformance.off) return null;
  final today = DateTime(now.year, now.month, now.day);

  if (p.manualVariation != null) {
    final until = p.manualUntil;
    if (until == null ||
        !today.isAfter(DateTime(until.year, until.month, until.day))) {
      final v = variationById(p.manualVariation!);
      if (v != null)
        return ActiveSeason(variation: v, reason: ActiveReason.manual);
    }
  }

  for (final c in p.celebrations) {
    final r = c.rangeIn(today.year) ?? c.rangeIn(today.year - 1);
    if (r != null && r.contains(today)) {
      final v = c.variationId == null ? null : variationById(c.variationId!);
      return ActiveSeason(
        variation: v,
        reason: ActiveReason.celebration,
        celebration: c,
        range: r,
      );
    }
  }

  if (p.autoSchedule) {
    ActiveSeason? best;
    int bestScore = 1 << 30;
    for (final col in seasonalCollections) {
      if (p.hidden.contains(col.id)) continue;
      // Only things the person said they celebrate are ever scheduled.
      final wanted = p.celebrated.contains(col.id);
      if (!wanted) continue;
      DayRange? hit;
      final custom = p.customDates[col.id];
      if (custom != null) {
        final parts = custom.split('/');
        final a = DateTime.tryParse(parts.first),
            b = parts.length > 1 ? DateTime.tryParse(parts[1]) : null;
        if (a != null && b != null) {
          final r = DayRange(a, b);
          if (r.contains(today)) hit = r;
        }
      } else {
        for (final r in SeasonalWindows.candidates(
          col.id,
          today.year,
          region: p.region,
          hemisphere: p.hemisphere,
        )) {
          final ext = r.shifted(after: p.extendDays[col.id] ?? 0);
          if (ext.contains(today)) {
            hit = ext;
            break;
          }
        }
      }
      if (hit == null) continue;
      // Prefer the shortest, most specific window (a holiday over a season).
      final score = hit.days;
      if (score < bestScore) {
        bestScore = score;
        final vid = p.variationFor[col.id];
        final v =
            (vid == null ? null : variationById(vid)) ??
            col.variations[(col.id.hashCode ^ today.year).abs() %
                col.variations.length];
        best = ActiveSeason(
          variation: v,
          reason: ActiveReason.scheduled,
          range: hit,
        );
      }
    }
    if (best != null) return best;
  }

  if (p.permanentVariation != null) {
    final v = variationById(p.permanentVariation!);
    if (v != null)
      return ActiveSeason(variation: v, reason: ActiveReason.permanent);
  }
  return null;
}

/// Builds the starting decorations for a look. Each item keeps the look's
/// id, so mixing looks later is just placing more items.
List<DecorItem> arrangementForVariation(SeasonalVariation v) {
  var n = 0;
  String id() => '${v.id}-${n++}';
  final r = v.seed;
  double jitter(int k, double span) =>
      (((r >> (k * 3)) & 0xff) / 255 - 0.5) * span;

  final items = <DecorItem>[
    DecorItem(
      id: id(),
      kind: DecoKind.garland,
      variationId: v.id,
      anchor: DecoAnchor.top,
      x: 0.5,
      y: 0.0,
      w: 1.0,
      z: 2,
    ),
    if (v.lights != LightsStyle.none)
      DecorItem(
        id: id(),
        kind: DecoKind.fairyLights,
        variationId: v.id,
        anchor: DecoAnchor.top,
        x: 0.5,
        y: 0.5,
        w: 1.0,
        z: 3,
        speed: 1,
      ),
    DecorItem(
      id: id(),
      kind: DecoKind.corner,
      variationId: v.id,
      anchor: DecoAnchor.topLeft,
      x: 0.0,
      y: 0.0,
      w: 0.24,
      z: 4,
    ),
    DecorItem(
      id: id(),
      kind: DecoKind.corner,
      variationId: v.id,
      anchor: DecoAnchor.topRight,
      x: 1.0,
      y: 0.0,
      w: 0.24,
      z: 4,
      flipX: true,
    ),
    if (v.border != DecoBorder.none)
      DecorItem(
        id: id(),
        kind: DecoKind.border,
        variationId: v.id,
        anchor: DecoAnchor.screen,
        w: 1.0,
        z: 1,
        opacity: 0.9,
      ),
    for (var i = 0; i < 3; i++)
      DecorItem(
        id: id(),
        kind: DecoKind.ornament,
        variationId: v.id,
        glyph: v.hangers[i % v.hangers.length],
        anchor: DecoAnchor.top,
        x: (0.22 + i * 0.28 + jitter(i, 0.08)).clamp(0.1, 0.9),
        y: 0.1,
        w: 0.08,
        z: 5,
        speed: 0.8 + i * 0.2,
      ),
    DecorItem(
      id: id(),
      kind: DecoKind.furniture,
      variationId: v.id,
      glyph: v.furniture.first,
      anchor: DecoAnchor.bottomLeft,
      x: 0.1,
      y: 1.0,
      w: 0.1,
      z: 3,
    ),
    DecorItem(
      id: id(),
      kind: DecoKind.furniture,
      variationId: v.id,
      glyph: v.furniture.last,
      anchor: DecoAnchor.bottomRight,
      x: 0.9,
      y: 1.0,
      w: 0.1,
      z: 3,
    ),
    if (v.particle != ParticleKind.none)
      DecorItem(
        id: id(),
        kind: DecoKind.particles,
        variationId: v.id,
        anchor: DecoAnchor.screen,
        w: 1.0,
        z: 6,
        frequency: 0.8,
      ),
    DecorItem(
      id: id(),
      kind: DecoKind.interactive,
      variationId: v.id,
      glyph: v.hangers.first,
      anchor: DecoAnchor.topRight,
      x: 0.78,
      y: 0.9,
      w: 0.1,
      z: 7,
    ),
  ];
  return items;
}
