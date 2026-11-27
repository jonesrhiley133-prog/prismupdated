import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/scrapbook/scrap_canvas.dart';
import 'package:prism_plurality/features/scrapbook/scrap_custom_texture.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/scrapbook/scrap_texture_painter.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

/// How a page looks apart from what's on it.
class ScrapPageStyle {
  ScrapPageStyle({
    this.color = 0xFFFFF8EC,
    this.color2,
    this.angle = 90,
    this.pattern = 'paper',
    this.texture = const ScrapTextureStyle(),
    this.aspect = scrapPageAspect,
    this.spread = false,
    this.transition = 'slide',
  });

  /// Page colour (and the gradient's start).
  int color;

  /// Gradient end colour; null means a flat colour.
  int? color2;
  double angle;
  String pattern;
  ScrapTextureStyle texture;

  /// One page's width ÷ height.
  double aspect;

  /// A two-page spread: the page is drawn twice as wide with a centre fold.
  bool spread;

  /// How this page arrives when you swipe to it.
  String transition;

  static const minAspect = 0.45, maxAspect = 1.9;

  /// The effective style of [page] in [book]: the page's own settings, then
  /// the book's, then the theme's.
  static ScrapPageStyle of(TrackerRecord book, TrackerRecord page) {
    final theme = themeById(book.str('theme'));
    final f = page.fields;
    double d(String k, double def) =>
        f[k] is num ? (f[k] as num).toDouble() : def;
    return ScrapPageStyle(
      color: page.integer('bg') ?? book.integer('pageColor') ?? theme.$5,
      color2: page.integer('bg2'),
      angle: d('ga', 90),
      pattern: page.str('pattern') ?? book.str('pattern') ?? 'paper',
      texture: ScrapTextureStyle.fromJson(f['tex']),
      aspect: d('asp', scrapPageAspect).clamp(minAspect, maxAspect),
      spread: f['spr'] == true,
      transition: scrapTransitions.containsKey(f['trn'])
          ? f['trn'] as String
          : 'slide',
    );
  }

  /// Fields to merge onto the page record (null removes a key).
  Map<String, Object?> toFields() => {
    'bg': color,
    'bg2': color2,
    'ga': color2 == null ? null : angle,
    'pattern': pattern,
    'tex': texture.id == 'plain' && texture.custom == null
        ? null
        : texture.toJson(),
    'asp': (aspect - scrapPageAspect).abs() < 0.001 ? null : aspect,
    'spr': spread ? true : null,
    'trn': transition == 'slide' ? null : transition,
  };

  Map<String, Object?> toJson() => {
    for (final e in toFields().entries)
      if (e.value != null) e.key: e.value,
  };

  static ScrapPageStyle fromJson(Map<String, Object?> j) {
    double d(String k, double def) =>
        j[k] is num ? (j[k] as num).toDouble() : def;
    return ScrapPageStyle(
      color: (j['bg'] as num?)?.toInt() ?? 0xFFFFF8EC,
      color2: (j['bg2'] as num?)?.toInt(),
      angle: d('ga', 90),
      pattern: j['pattern'] is String ? j['pattern'] as String : 'paper',
      texture: ScrapTextureStyle.fromJson(j['tex']),
      aspect: d('asp', scrapPageAspect).clamp(minAspect, maxAspect),
      spread: j['spr'] == true,
      transition: scrapTransitions.containsKey(j['trn'])
          ? j['trn'] as String
          : 'slide',
    );
  }

  ScrapPageStyle copy() => ScrapPageStyle.fromJson(toJson());

  /// Width ÷ height of what's drawn (a spread is two pages wide).
  double get drawnAspect => aspect * (spread ? 2 : 1);
}

/// How pages arrive when you swipe through a book.
const scrapTransitions = <String, String>{
  'slide': 'Slide',
  'fade': 'Fade',
  'flip': 'Page flip',
  'cube': 'Cube',
  'zoom': 'Zoom',
  'depth': 'Depth',
  'rotate': 'Rotate',
  'swing': 'Swing',
  'drop': 'Drop in',
};

/// Wraps a page in [transition]. [delta] is its distance from the centred
/// page: 0 centred, -1 one page to the left, 1 one page to the right.
Widget scrapPageTransition(String transition, Widget child, double delta) {
  final d = delta.clamp(-1.0, 1.0);
  final a = d.abs();
  switch (transition) {
    case 'fade':
      return Opacity(opacity: (1 - a).clamp(0.0, 1.0), child: child);
    case 'flip':
      return Transform(
        alignment: d > 0 ? Alignment.centerLeft : Alignment.centerRight,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(-d * math.pi / 2.2),
        child: child,
      );
    case 'cube':
      return Transform(
        alignment: d > 0 ? Alignment.centerLeft : Alignment.centerRight,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(-d * math.pi / 3),
        child: child,
      );
    case 'zoom':
      return Opacity(
        opacity: (1 - a * 0.7).clamp(0.0, 1.0),
        child: Transform.scale(scale: 1 - a * 0.25, child: child),
      );
    case 'depth':
      return Transform.scale(
        scale: 1 - a * 0.12,
        child: Opacity(opacity: (1 - a * 0.5).clamp(0.0, 1.0), child: child),
      );
    case 'rotate':
      return Transform.rotate(
        angle: d * 0.35,
        child: Opacity(opacity: (1 - a * 0.6).clamp(0.0, 1.0), child: child),
      );
    case 'swing':
      return Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(a * 0.5)
          ..rotateZ(d * 0.12),
        child: child,
      );
    case 'drop':
      return Transform.translate(
        offset: Offset(0, a * 60),
        child: Opacity(opacity: (1 - a * 0.8).clamp(0.0, 1.0), child: child),
      );
    default:
      return child;
  }
}

/// A page's backdrop (colour or gradient, pattern, texture, centre fold) with
/// [child] on top.
class ScrapPageBackdrop extends StatelessWidget {
  const ScrapPageBackdrop({
    super.key,
    required this.style,
    required this.child,
    this.rounded = true,
  });
  final ScrapPageStyle style;
  final Widget child;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final base = Color(s.color);
    final ink = ThemeData.estimateBrightnessForColor(base) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final tex = scrapTextureById(s.texture.id);
    return AspectRatio(
      aspectRatio: s.drawnAspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final body = Stack(
            fit: StackFit.expand,
            children: [
              if (s.color2 == null)
                ColoredBox(color: base)
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        -math.cos(s.angle * math.pi / 180),
                        -math.sin(s.angle * math.pi / 180),
                      ),
                      end: Alignment(
                        math.cos(s.angle * math.pi / 180),
                        math.sin(s.angle * math.pi / 180),
                      ),
                      colors: [base, Color(s.color2!)],
                    ),
                  ),
                ),
              CustomPaint(
                painter: ScrapBackground(Colors.transparent, s.pattern, ink),
              ),
              if (s.texture.custom != null)
                ScrapCustomTexture(media: s.texture.custom!, style: s.texture)
              else if (tex != null && s.texture.id != 'plain')
                IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: ScrapTexturePainter(
                        kind: tex.kind,
                        c1: s.texture.color == null
                            ? tex.c1
                            : Color(s.texture.color!),
                        c2: s.texture.color2 == null
                            ? tex.c2
                            : Color(s.texture.color2!),
                        seed: tex.seed,
                        scale: tex.scale * s.texture.scale,
                        intensity: s.texture.intensity,
                        opacity: s.texture.opacity,
                        blend:
                            scrapBlendModes[s.texture.blend] ??
                            BlendMode.srcOver,
                      ),
                    ),
                  ),
                ),
              child,
              if (s.spread)
                IgnorePointer(
                  child: Align(
                    child: SizedBox(
                      width: c.maxWidth * 0.06,
                      height: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
          return rounded
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(c.maxWidth * 0.012),
                  child: body,
                )
              : body;
        },
      ),
    );
  }
}

/// A finished page, as it appears in the book. Doesn't take gestures itself.
class ScrapPageView extends StatelessWidget {
  const ScrapPageView({super.key, required this.book, required this.page});
  final TrackerRecord book, page;

  @override
  Widget build(BuildContext context) {
    final style = ScrapPageStyle.of(book, page);
    final els = elementsOf(page);
    return ScrapPageBackdrop(
      style: style,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final e in els)
              Positioned(
                left: e.x * c.maxWidth,
                top: e.y * c.maxHeight,
                width: math.max(e.w * c.maxWidth, 8),
                height: math.max(e.h * c.maxHeight, 8),
                child: Transform.rotate(
                  angle: e.rot,
                  child: ScrapElementView(
                    element: e,
                    pageWidth: c.maxWidth / (style.spread ? 2 : 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Page templates ──────────────────────────────────────────────────────────

class ScrapPageTemplate {
  const ScrapPageTemplate({
    required this.id,
    required this.name,
    required this.build,
    this.builtIn = true,
    this.recordId,
  });
  final String id, name;

  /// Fresh elements and style each time, so a page never shares them.
  final ({List<ScrapElement> els, ScrapPageStyle? style}) Function() build;
  final bool builtIn;
  final String? recordId;
}

List<ScrapElement> _photos(
  List<List<double>> boxes, {
  String fr = 'polaroid',
}) => [
  for (final b in boxes)
    ScrapElement(
      type: ScrapType.photo,
      x: b[0],
      y: b[1],
      w: b[2],
      h: b[3],
      rot: b.length > 4 ? b[4] : 0,
      opts: {if (fr.isNotEmpty) 'fr2': fr},
    ),
];

final List<ScrapPageTemplate> builtInPageTemplates = [
  ScrapPageTemplate(
    id: 'blank',
    name: 'Blank',
    build: () => (els: <ScrapElement>[], style: null),
  ),
  ScrapPageTemplate(
    id: 'collage2',
    name: 'Two photos',
    build: () => (els: layoutTemplate('collage2'), style: null),
  ),
  ScrapPageTemplate(
    id: 'collage4',
    name: 'Four photos',
    build: () => (els: layoutTemplate('collage4'), style: null),
  ),
  ScrapPageTemplate(
    id: 'polaroids',
    name: 'Polaroids',
    build: () => (els: layoutTemplate('polaroids'), style: null),
  ),
  ScrapPageTemplate(
    id: 'journal',
    name: 'Journal',
    build: () => (
      els: layoutTemplate('journal'),
      style: ScrapPageStyle(pattern: 'lines'),
    ),
  ),
  ScrapPageTemplate(
    id: 'memory',
    name: 'Memory',
    build: () => (els: layoutTemplate('memory'), style: null),
  ),
  ScrapPageTemplate(
    id: 'hero',
    name: 'Big photo',
    build: () => (
      els: [
        ..._photos([
          [0.06, 0.05, 0.88, 0.7, 0],
        ], fr: 'rect-mat'),
        ScrapElement(
          type: ScrapType.text,
          text: '',
          x: 0.1,
          y: 0.8,
          w: 0.8,
          h: 0.14,
          font: 'g:Caveat',
          size: 1.6,
          opts: {'ta': 'center'},
        ),
      ],
      style: null,
    ),
  ),
  ScrapPageTemplate(
    id: 'triptych',
    name: 'Three strips',
    build: () => (
      els: _photos([
        [0.05, 0.08, 0.29, 0.84, 0],
        [0.355, 0.08, 0.29, 0.84, 0],
        [0.66, 0.08, 0.29, 0.84, 0],
      ], fr: 'rect-mat'),
      style: null,
    ),
  ),
  ScrapPageTemplate(
    id: 'quote',
    name: 'Big quote',
    build: () => (
      els: [
        ScrapElement(
          type: ScrapType.tape,
          x: 0.3,
          y: 0.04,
          w: 0.4,
          h: 0.05,
          rot: -0.05,
          opts: {'wp': 'stripes-red'},
        ),
        ScrapElement(
          type: ScrapType.text,
          text: '',
          x: 0.1,
          y: 0.3,
          w: 0.8,
          h: 0.4,
          font: 'g:Pacifico',
          size: 2.2,
          opts: {'ta': 'center', 'shrink': true},
        ),
      ],
      style: ScrapPageStyle(pattern: 'paper'),
    ),
  ),
  ScrapPageTemplate(
    id: 'spread',
    name: 'Two-page spread',
    build: () => (
      els: _photos([
        [0.04, 0.1, 0.42, 0.55, -0.03],
        [0.54, 0.1, 0.42, 0.55, 0.03],
      ]),
      style: ScrapPageStyle(spread: true),
    ),
  ),
];

/// Templates people saved themselves.
final savedPageTemplatesProvider = Provider<List<ScrapPageTemplate>>((ref) {
  final recs =
      ref.watch(trackerKindProvider(TrackerKind.scrapTemplate)).value ??
      const <TrackerRecord>[];
  return [
    for (final r in recs)
      ScrapPageTemplate(
        id: 'u:${r.id}',
        name: r.title.isEmpty ? 'My template' : r.title,
        builtIn: false,
        recordId: r.id,
        build: () => (
          els: [
            for (final e
                in (r.fields['els'] is List
                    ? r.fields['els'] as List
                    : const []))
              if (e is Map) ?ScrapElement.fromJson({...e, 'id': null}),
          ],
          style: r.fields['style'] is Map
              ? ScrapPageStyle.fromJson(
                  Map<String, Object?>.from(r.fields['style'] as Map),
                )
              : null,
        ),
      ),
  ];
});
