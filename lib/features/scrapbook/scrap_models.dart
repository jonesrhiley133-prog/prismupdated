import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import 'package:prism_plurality/shared/ui_kit.dart';

const _uuid = Uuid();

/// Page aspect ratio (width / height), like a portrait album page.
const scrapPageAspect = 1000 / 1400;

enum ScrapType {
  photo,
  video,
  audio,
  text,
  note,
  sticker,
  drawing,
  tape,
  shape,
}

enum ScrapFrame { none, polaroid, tape, round, shadow, border }

/// One element on a page. Positions and sizes are fractions of the page.
class ScrapElement {
  ScrapElement({
    String? id,
    required this.type,
    this.x = 0.3,
    this.y = 0.3,
    this.w = 0.4,
    this.h = 0.3,
    this.rot = 0,
    this.z = 0,
    this.media,
    this.text,
    this.color,
    this.font,
    this.size = 1,
    this.frame = ScrapFrame.none,
    this.by,
    this.opacity = 1,
    this.locked = false,
    this.group,
    Map<String, Object?>? opts,
  }) : id = id ?? _uuid.v4(),
       opts = opts ?? {};

  final String id;
  ScrapType type;
  double x, y, w, h, rot;
  int z;
  String? media;
  String? text;
  int? color;
  String? font;
  double size;
  ScrapFrame frame;
  String? by;

  /// 0..1 element transparency.
  double opacity;

  /// Locked elements can't be moved, resized or deleted by accident.
  bool locked;

  /// Elements sharing a group id move and select together.
  String? group;

  /// Per-element options (video loop/volume/thumbnail, shadow, outline,
  /// frame style, texture…). Every element owns its own map, so changing
  /// one element can never touch another.
  Map<String, Object?> opts;

  T opt<T>(String k, T def) {
    final v = opts[k];
    if (v is T) return v;
    if (v is num && def is double) return v.toDouble() as T;
    return def;
  }

  void setOpt(String k, Object? v) {
    if (v == null) {
      opts.remove(k);
    } else {
      opts[k] = v;
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    't': type.name,
    'x': _r(x),
    'y': _r(y),
    'w': _r(w),
    'h': _r(h),
    if (rot != 0) 'r': _r(rot),
    'z': z,
    'm': ?media,
    'tx': ?text,
    'c': ?color,
    'f': ?font,
    if (size != 1) 's': _r(size),
    if (frame != ScrapFrame.none) 'fr': frame.name,
    'by': ?by,
    if (opacity != 1) 'op': _r(opacity),
    if (locked) 'lk': true,
    'g': ?group,
    if (opts.isNotEmpty) 'o': Map<String, Object?>.of(opts),
  };

  static double _r(double v) => (v * 10000).round() / 10000;

  static ScrapElement? fromJson(Object? o) {
    if (o is! Map) return null;
    final t = ScrapType.values.where((x) => x.name == o['t']).firstOrNull;
    if (t == null) return null;
    double d(String k, double def) => (o[k] as num?)?.toDouble() ?? def;
    return ScrapElement(
      id: o['id'] as String?,
      type: t,
      x: d('x', 0.3),
      y: d('y', 0.3),
      w: d('w', 0.4),
      h: d('h', 0.3),
      rot: d('r', 0),
      z: (o['z'] as num?)?.toInt() ?? 0,
      media: o['m'] as String?,
      text: o['tx'] as String?,
      color: (o['c'] as num?)?.toInt(),
      font: o['f'] as String?,
      size: d('s', 1),
      frame:
          ScrapFrame.values.where((x) => x.name == o['fr']).firstOrNull ??
          ScrapFrame.none,
      by: o['by'] as String?,
      opacity: d('op', 1),
      locked: o['lk'] == true,
      group: o['g'] as String?,
      opts: o['o'] is Map ? Map<String, Object?>.from(o['o'] as Map) : null,
    );
  }

  ScrapElement copy({bool newId = true}) =>
      ScrapElement.fromJson({...toJson(), if (newId) 'id': null})!
        ..x = math.min(x + 0.04, 0.9)
        ..y = math.min(y + 0.04, 0.9);
}

List<ScrapElement> elementsOf(TrackerRecord page) {
  final raw = page.fields['els'];
  if (raw is! List) return [];
  return [for (final o in raw) ?ScrapElement.fromJson(o)]
    ..sort((a, b) => a.z.compareTo(b.z));
}

/// Background patterns for pages.
const scrapPatterns = [
  'paper',
  'dots',
  'grid',
  'lines',
  'none',
  'kraft',
  'stars',
];

/// Book themes: (id, en, es, cover colour, page colour, accent).
const scrapThemes = [
  ('classic', 'Classic', 'Clásico', 0xFF7A4E2D, 0xFFFFF8EC, 0xFFC0392B),
  ('pastel', 'Pastel', 'Pastel', 0xFFF6C6D8, 0xFFFFF5FA, 0xFF8E7CC3),
  ('night', 'Night sky', 'Cielo nocturno', 0xFF1E2140, 0xFF2A2E57, 0xFFF1C40F),
  ('garden', 'Garden', 'Jardín', 0xFF4E7A4F, 0xFFF4F9EF, 0xFFE67E22),
  ('ocean', 'Ocean', 'Océano', 0xFF1F5F8B, 0xFFEFF7FC, 0xFF1ABC9C),
  ('kraft', 'Kraft', 'Kraft', 0xFFB08D57, 0xFFE9D8B4, 0xFF5B3A1E),
];

(String, String, String, int, int, int) themeById(String? id) =>
    scrapThemes.firstWhere((t) => t.$1 == id, orElse: () => scrapThemes.first);

const scrapStickers = [
  '⭐',
  '💖',
  '🌸',
  '🌈',
  '✨',
  '🦋',
  '🌙',
  '☀️',
  '🍀',
  '🎀',
  '🎈',
  '🎨',
  '📸',
  '🎵',
  '🐾',
  '🍓',
  '🌻',
  '🔥',
  '💫',
  '🫶',
  '🪐',
  '🧸',
  '🍰',
  '🌊',
];

const scrapFonts = [
  ('hand', 'Handwritten'),
  ('serif', 'Serif'),
  ('display', 'Display'),
  ('mono', 'Typewriter'),
  ('standard', 'Clean'),
];

TextStyle scrapFont(String? f, TextStyle base) => switch (f) {
  'hand' => base.copyWith(
    fontFamily: 'Segoe Print',
    fontFamilyFallback: const ['Bradley Hand', 'Comic Sans MS', 'cursive'],
    fontStyle: FontStyle.italic,
  ),
  'serif' => base.copyWith(
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['Times New Roman', 'serif'],
  ),
  'display' => base.copyWith(
    fontFamily: 'Unbounded',
    fontWeight: FontWeight.w700,
  ),
  'mono' => base.copyWith(
    fontFamily: 'Courier New',
    fontFamilyFallback: const ['Menlo', 'monospace'],
  ),
  _ => base,
};

/// Starting layouts for new pages.
List<ScrapElement> layoutTemplate(String id) => switch (id) {
  'collage2' => [
    ScrapElement(
      type: ScrapType.photo,
      x: 0.06,
      y: 0.08,
      w: 0.88,
      h: 0.40,
      frame: ScrapFrame.shadow,
    ),
    ScrapElement(
      type: ScrapType.photo,
      x: 0.06,
      y: 0.52,
      w: 0.88,
      h: 0.40,
      frame: ScrapFrame.shadow,
    ),
  ],
  'collage4' => [
    for (var i = 0; i < 4; i++)
      ScrapElement(
        type: ScrapType.photo,
        x: 0.05 + (i % 2) * 0.46,
        y: 0.08 + (i ~/ 2) * 0.44,
        w: 0.44,
        h: 0.40,
        frame: ScrapFrame.border,
      ),
  ],
  'polaroids' => [
    ScrapElement(
      type: ScrapType.photo,
      x: 0.08,
      y: 0.08,
      w: 0.5,
      h: 0.36,
      rot: -0.12,
      frame: ScrapFrame.polaroid,
    ),
    ScrapElement(
      type: ScrapType.photo,
      x: 0.42,
      y: 0.32,
      w: 0.5,
      h: 0.36,
      rot: 0.1,
      z: 1,
      frame: ScrapFrame.polaroid,
    ),
    ScrapElement(
      type: ScrapType.photo,
      x: 0.12,
      y: 0.58,
      w: 0.5,
      h: 0.36,
      rot: -0.05,
      z: 2,
      frame: ScrapFrame.polaroid,
    ),
  ],
  'journal' => [
    ScrapElement(
      type: ScrapType.photo,
      x: 0.08,
      y: 0.06,
      w: 0.84,
      h: 0.38,
      frame: ScrapFrame.tape,
    ),
    ScrapElement(
      type: ScrapType.text,
      x: 0.08,
      y: 0.48,
      w: 0.84,
      h: 0.44,
      text: '',
      font: 'hand',
    ),
  ],
  'memory' => [
    ScrapElement(
      type: ScrapType.text,
      x: 0.08,
      y: 0.05,
      w: 0.84,
      h: 0.1,
      text: '',
      font: 'display',
      size: 1.5,
    ),
    ScrapElement(
      type: ScrapType.photo,
      x: 0.1,
      y: 0.18,
      w: 0.8,
      h: 0.45,
      frame: ScrapFrame.round,
    ),
    ScrapElement(
      type: ScrapType.note,
      x: 0.15,
      y: 0.68,
      w: 0.7,
      h: 0.24,
      text: '',
      color: 0xFFFFF3A3,
      rot: 0.03,
    ),
  ],
  _ => [],
};
