import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Common flag proportions (height : width).
const flagRatios = <String, double>{
  '2:3': 3 / 2,
  '3:5': 5 / 3,
  '1:2': 2,
  '1:1': 1,
  '4:7': 7 / 4,
  '10:19': 1.9,
  '5:8': 8 / 5,
};

/// Outline shapes a flag can be cut to.
const flagShapes = <String, String>{
  'rect': 'Rectangle',
  'rounded': 'Rounded',
  'swallowtail': 'Swallowtail',
  'pennant': 'Pennant',
  'banner': 'Banner',
  'circle': 'Circle',
};

/// Ready-made backgrounds.
const flagLayouts = <String, String>{
  'hstripes': 'Horizontal stripes',
  'vstripes': 'Vertical stripes',
  'diagonal': 'Diagonal split',
  'nordic': 'Nordic cross',
  'cross': 'Centred cross',
  'saltire': 'Saltire (X)',
  'canton': 'Canton',
  'chevron': 'Hoist chevron',
  'border': 'Border',
  'quartered': 'Quartered',
  'circle': 'Centre circle',
  'triangle': 'Hoist triangle',
};

/// Shapes for the shape tool.
const flagShapeKinds = [
  'rect',
  'ellipse',
  'triangle',
  'star',
  'heart',
  'diamond',
  'moon',
  'hexagon',
  'ring',
];

/// One layer. Geometry is 0–1 across the flag (x to the right, y down).
@immutable
class FlagLayer {
  const FlagLayer({
    required this.id,
    required this.kind,
    this.name = '',
    this.visible = true,
    this.locked = false,
    this.opacity = 1,
    this.colors = const [0xFFE40303],
    this.layout = 'hstripes',
    this.shape = 'star',
    this.x = 0.5,
    this.y = 0.5,
    this.w = 0.3,
    this.h = 0.3,
    this.rotation = 0,
    this.text = '',
    this.stroke = 0,
    this.points = const [],
    this.paths = const [],
    this.media,
  });

  final String id;

  /// fill, layout, shape, symbol, text, draw, vector, image
  final String kind;
  final String name;
  final bool visible, locked;
  final double opacity;
  final List<int> colors;
  final String layout, shape;
  final double x, y, w, h, rotation;
  final String text;

  /// Stroke width for draw/line layers (0–0.1 of flag height).
  final double stroke;

  /// Freehand points for draw layers.
  final List<Offset> points;

  /// Imported vector paths: (svg-ish commands in 0–1 space, fill colour).
  final List<(String, int)> paths;
  final String? media;

  int get color => colors.isEmpty ? 0xFF000000 : colors.first;

  FlagLayer copyWith({
    String? id,
    String? name,
    bool? visible,
    bool? locked,
    double? opacity,
    List<int>? colors,
    String? layout,
    String? shape,
    double? x,
    double? y,
    double? w,
    double? h,
    double? rotation,
    String? text,
    double? stroke,
    List<Offset>? points,
    List<(String, int)>? paths,
    String? media,
  }) => FlagLayer(
    id: id ?? this.id,
    kind: kind,
    name: name ?? this.name,
    visible: visible ?? this.visible,
    locked: locked ?? this.locked,
    opacity: opacity ?? this.opacity,
    colors: colors ?? this.colors,
    layout: layout ?? this.layout,
    shape: shape ?? this.shape,
    x: x ?? this.x,
    y: y ?? this.y,
    w: w ?? this.w,
    h: h ?? this.h,
    rotation: rotation ?? this.rotation,
    text: text ?? this.text,
    stroke: stroke ?? this.stroke,
    points: points ?? this.points,
    paths: paths ?? this.paths,
    media: media ?? this.media,
  );

  String get label => name.isNotEmpty
      ? name
      : switch (kind) {
          'fill' => 'Background',
          'layout' => flagLayouts[layout] ?? 'Layout',
          'shape' => 'Shape: $shape',
          'symbol' => 'Symbol $text',
          'text' => 'Text: $text',
          'draw' => 'Drawing',
          'vector' => 'Imported vector',
          'image' => 'Image',
          _ => kind,
        };

  Map<String, Object?> toJson() => {
    'id': id,
    'k': kind,
    if (name.isNotEmpty) 'n': name,
    'v': visible,
    'l': locked,
    'o': opacity,
    'c': colors,
    'lay': layout,
    'sh': shape,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'r': rotation,
    if (text.isNotEmpty) 't': text,
    if (stroke != 0) 's': stroke,
    if (points.isNotEmpty)
      'p': [
        for (final p in points)
          [
            double.parse(p.dx.toStringAsFixed(4)),
            double.parse(p.dy.toStringAsFixed(4)),
          ],
      ],
    if (paths.isNotEmpty)
      'vp': [
        for (final (d, c) in paths) [d, c],
      ],
    'm': ?media,
  };

  static FlagLayer fromJson(Map j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    return FlagLayer(
      id: '${j['id']}',
      kind: '${j['k'] ?? 'fill'}',
      name: '${j['n'] ?? ''}',
      visible: j['v'] != false,
      locked: j['l'] == true,
      opacity: d('o', 1).clamp(0, 1),
      colors: [
        for (final c in (j['c'] as List? ?? const [0xFFE40303]))
          (c as num).toInt(),
      ],
      layout: '${j['lay'] ?? 'hstripes'}',
      shape: '${j['sh'] ?? 'star'}',
      x: d('x', 0.5),
      y: d('y', 0.5),
      w: d('w', 0.3),
      h: d('h', 0.3),
      rotation: d('r', 0),
      text: '${j['t'] ?? ''}',
      stroke: d('s', 0),
      points: [
        for (final p in (j['p'] as List? ?? const []))
          if (p is List && p.length == 2)
            Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
      paths: [
        for (final p in (j['vp'] as List? ?? const []))
          if (p is List && p.length == 2) ('${p[0]}', (p[1] as num).toInt()),
      ],
      media: j['m'] as String?,
    );
  }
}

@immutable
class FlagDesign {
  const FlagDesign({
    this.ratio = '3:5',
    this.shape = 'rect',
    this.layers = const [],
  });
  final String ratio;
  final String shape;
  final List<FlagLayer> layers;

  double get aspect => flagRatios[ratio] ?? 5 / 3;

  FlagDesign copyWith({
    String? ratio,
    String? shape,
    List<FlagLayer>? layers,
  }) => FlagDesign(
    ratio: ratio ?? this.ratio,
    shape: shape ?? this.shape,
    layers: layers ?? this.layers,
  );
  Map<String, Object?> toJson() => {
    'ratio': ratio,
    'shape': shape,
    'layers': [for (final l in layers) l.toJson()],
  };
  static FlagDesign fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    return FlagDesign(
      ratio: flagRatios.containsKey(j['ratio']) ? j['ratio'] as String : '3:5',
      shape: flagShapes.containsKey(j['shape']) ? j['shape'] as String : 'rect',
      layers: [
        for (final l in (j['layers'] as List? ?? const []))
          if (l is Map) FlagLayer.fromJson(l),
      ],
    );
  }

  /// Every colour used (for the info page).
  List<int> get palette => {
    for (final l in layers)
      if (l.visible && l.kind != 'image') ...l.colors,
  }.toList();
}

String newLayerId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(9999)}';

/// Starter designs (public pride and identity flags, plus plain layouts).
final flagTemplates = <String, FlagDesign>{
  'Blank': FlagDesign(
    layers: [
      FlagLayer(id: 'bg', kind: 'fill', colors: const [0xFFFFFFFF]),
    ],
  ),
  'Rainbow': _stripes([
    0xFFE40303,
    0xFFFF8C00,
    0xFFFFED00,
    0xFF008026,
    0xFF24408E,
    0xFF732982,
  ]),
  'Transgender': _stripes([
    0xFF5BCEFA,
    0xFFF5A9B8,
    0xFFFFFFFF,
    0xFFF5A9B8,
    0xFF5BCEFA,
  ]),
  'Bisexual': FlagDesign(
    layers: [
      FlagLayer(
        id: 'l',
        kind: 'layout',
        layout: 'hstripes',
        colors: const [
          0xFFD60270,
          0xFFD60270,
          0xFF9B4F96,
          0xFF0038A8,
          0xFF0038A8,
        ],
      ),
    ],
  ),
  'Pansexual': _stripes([0xFFFF218C, 0xFFFFD800, 0xFF21B1FF]),
  'Asexual': _stripes([0xFF000000, 0xFFA3A3A3, 0xFFFFFFFF, 0xFF800080]),
  'Aromantic': _stripes([
    0xFF3DA542,
    0xFFA7D379,
    0xFFFFFFFF,
    0xFFA9A9A9,
    0xFF000000,
  ]),
  'Lesbian': _stripes([
    0xFFD52D00,
    0xFFFF9A56,
    0xFFFFFFFF,
    0xFFD362A4,
    0xFFA30262,
  ]),
  'Nonbinary': _stripes([0xFFFCF434, 0xFFFFFFFF, 0xFF9C59D1, 0xFF2C2C2C]),
  'Genderfluid': _stripes([
    0xFFFF76A4,
    0xFFFFFFFF,
    0xFFC011D7,
    0xFF000000,
    0xFF2F3CBE,
  ]),
  'Agender': _stripes([
    0xFF000000,
    0xFFBCC4C7,
    0xFFFFFFFF,
    0xFFB7F684,
    0xFFFFFFFF,
    0xFFBCC4C7,
    0xFF000000,
  ]),
  'Intersex': FlagDesign(
    layers: [
      FlagLayer(id: 'bg', kind: 'fill', colors: const [0xFFFFD800]),
      FlagLayer(
        id: 'r',
        kind: 'shape',
        shape: 'ring',
        x: 0.5,
        y: 0.5,
        w: 0.28,
        h: 0.46,
        colors: const [0xFF7902AA],
      ),
    ],
  ),
  'Nordic cross': FlagDesign(
    layers: [
      FlagLayer(
        id: 'l',
        kind: 'layout',
        layout: 'nordic',
        colors: const [0xFF1F5BA8, 0xFFFFD34E],
      ),
    ],
  ),
  'Starry canton': FlagDesign(
    layers: [
      FlagLayer(
        id: 'l',
        kind: 'layout',
        layout: 'hstripes',
        colors: const [
          0xFF7FA6F2,
          0xFFFFFFFF,
          0xFF7FA6F2,
          0xFFFFFFFF,
          0xFF7FA6F2,
        ],
      ),
      FlagLayer(
        id: 'c',
        kind: 'layout',
        layout: 'canton',
        colors: const [0xFF2B2D5C],
      ),
      FlagLayer(
        id: 's',
        kind: 'symbol',
        text: '✦',
        x: 0.2,
        y: 0.28,
        w: 0.2,
        colors: const [0xFFFFD866],
      ),
    ],
  ),
};

FlagDesign _stripes(List<int> c) => FlagDesign(
  layers: [FlagLayer(id: 'l', kind: 'layout', layout: 'hstripes', colors: c)],
);

/// Unicode symbols for flags, grouped.
const flagSymbols = <String, List<String>>{
  'Stars': [
    '★',
    '☆',
    '✦',
    '✧',
    '✩',
    '✪',
    '✫',
    '✬',
    '✭',
    '✮',
    '✯',
    '✰',
    '⁂',
    '✷',
    '✸',
    '✹',
    '✺',
    '❂',
    '⋆',
    '✵',
  ],
  'Hearts': [
    '♥',
    '♡',
    '❤',
    '❥',
    '❦',
    '❧',
    '💕',
    '💖',
    '💜',
    '💙',
    '💚',
    '💛',
    '🧡',
    '🤍',
    '🖤',
  ],
  'Sky': [
    '☀',
    '☼',
    '☾',
    '☽',
    '🌙',
    '🌕',
    '🌑',
    '☁',
    '⚡',
    '❄',
    '🌈',
    '☄',
    '🪐',
    '🌟',
    '🌌',
  ],
  'Nature': [
    '❀',
    '✿',
    '❁',
    '✾',
    '❃',
    '🌸',
    '🌿',
    '🍃',
    '🌻',
    '🌹',
    '🍄',
    '🌊',
    '🔥',
    '🌲',
    '🦋',
  ],
  'Shapes': [
    '●',
    '○',
    '■',
    '□',
    '▲',
    '△',
    '◆',
    '◇',
    '⬟',
    '⬢',
    '⬡',
    '◯',
    '▼',
    '◐',
    '◑',
  ],
  'Signs': [
    '∞',
    '☯',
    '☮',
    '⚥',
    '⚧',
    '⚢',
    '⚣',
    '♀',
    '♂',
    '⚪',
    '✚',
    '✕',
    '☘',
    '⚜',
    '♾',
  ],
  'Arrows': [
    '➜',
    '➤',
    '⇨',
    '↻',
    '⟳',
    '↯',
    '⇆',
    '⤴',
    '⤵',
    '⬆',
    '⬇',
    '⬅',
    '➡',
    '↕',
    '↔',
  ],
};
