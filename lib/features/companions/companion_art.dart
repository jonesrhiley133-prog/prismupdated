import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:prism_plurality/features/companions/companion_mood.dart';
import 'package:prism_plurality/features/companions/companion_species.dart';
import 'package:prism_plurality/core/graphics/decor_clock.dart';
import 'package:prism_plurality/core/graphics/graphics_engine.dart';

/// Everything about how a companion looks. Stored as plain JSON (versioned
/// via the record's `v` field) so outfits and photos can keep copies.
@immutable
class CompanionLook {
  const CompanionLook({
    this.primary,
    this.secondary,
    this.belly,
    this.eye = 0xFF2B2B33,
    this.pattern = 'none',
    this.ear,
    this.tail,
    this.wings,
    this.horns = 'none',
    this.expression = 'content',
    this.marking = 'cheeks',
    this.hat = 'none',
    this.glasses = 'none',
    this.neck = 'none',
    this.body = 'none',
    this.floating = 'none',
    this.particles = 'none',
    this.background = 'none',
    this.frame = 'none',
    this.accent = 0xFFE86A92,
    this.adjust = const {},
  });

  final int? primary, secondary, belly;
  final int eye;
  final String pattern;
  final String? ear, tail;
  final bool? wings;
  final String horns,
      expression,
      marking,
      hat,
      glasses,
      neck,
      body,
      floating,
      particles,
      background,
      frame;

  /// Colour of accessories (scarf, bow, sweater…).
  final int accent;

  /// Per-slot fine-tuning (body, neck, glasses, hat, floating).
  final Map<String, AccessoryAdjust> adjust;
  AccessoryAdjust adjustOf(String slot) =>
      adjust[slot] ?? const AccessoryAdjust();
  static const accessorySlots = ['hat', 'glasses', 'neck', 'body', 'floating'];

  static const patterns = [
    'none',
    'spots',
    'stripes',
    'patches',
    'socks',
    'stars',
    'gradient',
  ];
  static const hornsList = ['none', 'nubs', 'curved', 'unicorn', 'antennae'];
  static const expressions = [
    'happy',
    'content',
    'sleepy',
    'surprised',
    'wink',
    'smug',
    'excited',
    'blush',
    'sad',
    'grumpy',
    'scared',
    'loving',
    'curious',
    'proud',
    'bored',
    'silly',
  ];
  static const markings = [
    'none',
    'cheeks',
    'freckles',
    'star',
    'heart',
    'gem',
  ];
  static const hats = [
    'none',
    'beanie',
    'witch',
    'crown',
    'flowers',
    'party',
    'tophat',
    'santa',
    'pumpkin',
    'bunny',
    'beret',
    'halo',
  ];
  static const glassesList = [
    'none',
    'round',
    'star',
    'heart',
    'shades',
    'monocle',
  ];
  static const necks = ['none', 'scarf', 'bow', 'collar', 'bandana', 'pearls'];
  static const bodies = [
    'none',
    'sweater',
    'cape',
    'hoodie',
    'raincoat',
    'overalls',
  ];
  static const floatings = [
    'none',
    'star',
    'heart',
    'moon',
    'leaf',
    'bubble',
    'note',
    'sun',
  ];
  static const particleList = [
    'none',
    'sparkles',
    'hearts',
    'petals',
    'snow',
    'fireflies',
    'bubbles',
  ];
  static const frames = [
    'none',
    'round',
    'stars',
    'flowers',
    'polaroid',
    'gold',
    'hearts',
  ];

  Color primaryOf(Species s) => primary == null ? s.primary : Color(primary!);
  Color secondaryOf(Species s) =>
      secondary == null ? s.secondary : Color(secondary!);
  Color bellyOf(Species s) =>
      belly == null ? (s.belly ?? secondaryOf(s)) : Color(belly!);
  EarKind earOf(Species s) =>
      EarKind.values.where((e) => e.name == ear).firstOrNull ?? s.ear;
  TailKind tailOf(Species s) =>
      TailKind.values.where((e) => e.name == tail).firstOrNull ?? s.tail;
  bool wingsOf(Species s) => wings ?? s.wings;

  Map<String, Object?> toJson() => {
    'primary': primary,
    'secondary': secondary,
    'belly': belly,
    'eye': eye,
    'pattern': pattern,
    'ear': ear,
    'tail': tail,
    'wings': wings,
    'horns': horns,
    'expression': expression,
    'marking': marking,
    'hat': hat,
    'glasses': glasses,
    'neck': neck,
    'body': body,
    'floating': floating,
    'particles': particles,
    'background': background,
    'frame': frame,
    'accent': accent,
    'adjust': {
      for (final e in adjust.entries)
        if (!e.value.isIdentity) e.key: e.value.toJson(),
    },
  };

  static CompanionLook fromJson(Object? raw) {
    final j = raw is Map
        ? raw.cast<String, Object?>()
        : const <String, Object?>{};
    int? i(String k) => (j[k] as num?)?.toInt();
    String s(String k, String d, List<String> allowed) {
      final v = j[k];
      return v is String && allowed.contains(v) ? v : d;
    }

    return CompanionLook(
      primary: i('primary'),
      secondary: i('secondary'),
      belly: i('belly'),
      eye: i('eye') ?? 0xFF2B2B33,
      pattern: s('pattern', 'none', patterns),
      ear: j['ear'] as String?,
      tail: j['tail'] as String?,
      wings: j['wings'] as bool?,
      horns: s('horns', 'none', hornsList),
      expression: s('expression', 'content', expressions),
      marking: s('marking', 'cheeks', markings),
      hat: s('hat', 'none', hats),
      glasses: s('glasses', 'none', glassesList),
      neck: s('neck', 'none', necks),
      body: s('body', 'none', bodies),
      floating: s('floating', 'none', floatings),
      particles: s('particles', 'none', particleList),
      background: '${j['background'] ?? 'none'}',
      frame: s('frame', 'none', frames),
      accent: i('accent') ?? 0xFFE86A92,
      adjust: {
        for (final e in ((j['adjust'] as Map?) ?? const {}).entries)
          if (accessorySlots.contains(e.key))
            '${e.key}': AccessoryAdjust.fromJson(e.value),
      },
    );
  }

  CompanionLook copyWith(Map<String, Object?> changes) =>
      fromJson({...toJson(), ...changes});
}

/// How an uploaded picture sits in a companion's frame, and where
/// accessories attach to it (coordinates are 0–100 across the frame).
@immutable
class ArtFit {
  const ArtFit({
    this.x = 0,
    this.y = 0,
    this.scale = 1,
    this.rotation = 0,
    this.mirror = false,
    this.crop = 'none',
    this.background = 'none',
    this.bgColor = 0xFFFFF4E0,
    this.headX = 50,
    this.headY = 40,
    this.headR = 26,
    this.neckY = 62,
  });
  final double x, y, scale, rotation;
  final bool mirror;

  /// none, circle, rounded
  final String crop;

  /// none, soft, circle, color
  final String background;
  final int bgColor;
  final double headX, headY, headR, neckY;

  ArtFit copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
    bool? mirror,
    String? crop,
    String? background,
    int? bgColor,
    double? headX,
    double? headY,
    double? headR,
    double? neckY,
  }) => ArtFit(
    x: x ?? this.x,
    y: y ?? this.y,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    mirror: mirror ?? this.mirror,
    crop: crop ?? this.crop,
    background: background ?? this.background,
    bgColor: bgColor ?? this.bgColor,
    headX: headX ?? this.headX,
    headY: headY ?? this.headY,
    headR: headR ?? this.headR,
    neckY: neckY ?? this.neckY,
  );

  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    's': scale,
    'r': rotation,
    'm': mirror,
    'crop': crop,
    'bg': background,
    'bgc': bgColor,
    'hx': headX,
    'hy': headY,
    'hr': headR,
    'ny': neckY,
  };
  static ArtFit fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    double d(String k, double def, double lo, double hi) =>
        ((j[k] as num?)?.toDouble() ?? def).clamp(lo, hi);
    return ArtFit(
      x: d('x', 0, -0.6, 0.6),
      y: d('y', 0, -0.6, 0.6),
      scale: d('s', 1, 0.3, 3),
      rotation: d('r', 0, -180, 180),
      mirror: j['m'] == true,
      crop: const ['none', 'circle', 'rounded'].contains(j['crop'])
          ? j['crop'] as String
          : 'none',
      background: const ['none', 'soft', 'circle', 'color'].contains(j['bg'])
          ? j['bg'] as String
          : 'none',
      bgColor: (j['bgc'] as num?)?.toInt() ?? 0xFFFFF4E0,
      headX: d('hx', 50, 0, 100),
      headY: d('hy', 40, 0, 100),
      headR: d('hr', 26, 8, 50),
      neckY: d('ny', 62, 0, 100),
    );
  }
}

/// Where an accessory sits relative to its anchor on the species.
@immutable
class AccessoryAdjust {
  const AccessoryAdjust({
    this.dx = 0,
    this.dy = 0,
    this.scale = 1,
    this.rotation = 0,
    this.mirror = false,
    this.opacity = 1,
    this.layer = 0,
  });
  final double dx, dy, scale, rotation, opacity;
  final bool mirror;

  /// Draw order among accessories: lower is further back.
  final int layer;

  bool get isIdentity =>
      dx == 0 &&
      dy == 0 &&
      scale == 1 &&
      rotation == 0 &&
      !mirror &&
      opacity == 1 &&
      layer == 0;

  AccessoryAdjust copyWith({
    double? dx,
    double? dy,
    double? scale,
    double? rotation,
    bool? mirror,
    double? opacity,
    int? layer,
  }) => AccessoryAdjust(
    dx: dx ?? this.dx,
    dy: dy ?? this.dy,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    mirror: mirror ?? this.mirror,
    opacity: opacity ?? this.opacity,
    layer: layer ?? this.layer,
  );

  Map<String, Object?> toJson() => {
    'dx': dx,
    'dy': dy,
    's': scale,
    'r': rotation,
    'm': mirror,
    'o': opacity,
    'l': layer,
  };
  static AccessoryAdjust fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    double d(String k, double def, double lo, double hi) =>
        ((j[k] as num?)?.toDouble() ?? def).clamp(lo, hi);
    return AccessoryAdjust(
      dx: d('dx', 0, -40, 40),
      dy: d('dy', 0, -40, 40),
      scale: d('s', 1, 0.3, 2.5),
      rotation: d('r', 0, -180, 180),
      mirror: j['m'] == true,
      opacity: d('o', 1, 0.05, 1),
      layer: ((j['l'] as num?)?.toInt() ?? 0).clamp(-5, 5),
    );
  }
}

/// Poses for interactions and photos.
enum CompanionPose {
  sit,
  wave,
  sleep,
  play,
  hop,
  read,
  music,
  eat,
  cuddle,
  dance,
  stretch,
  spin,
  peek,
  nod,
  shiver,
  celebrate,
}

/// A companion, drawn live. Animates gently unless reduced motion is on,
/// [animate] is false, or it's offscreen (TickerMode).
class CompanionView extends StatefulWidget {
  const CompanionView({
    super.key,
    required this.species,
    required this.look,
    this.size = 120,
    this.pose = CompanionPose.sit,
    this.animate = true,
    this.traits = const [],
    this.expression,
    this.accessoriesOnly = false,
    this.semanticLabel,
    this.showParticles = true,
    this.fit,
    this.intensity = 1,
    this.expressiveness = 0.6,
    this.energy = 0.5,
    this.weather,
  });

  /// App-wide animation strength, the companion's expressiveness and energy
  /// (energy sets how quick their breathing is), and the habitat's weather
  /// when they should react to it.
  final double intensity, expressiveness, energy;
  final String? weather;

  /// Accessory anchors for uploaded artwork.
  final ArtFit? fit;

  final Species species;
  final CompanionLook look;
  final double size;
  final CompanionPose pose;
  final bool animate;
  final List<String> traits;
  final String? expression;

  /// Draw only accessories and effects (over custom species artwork).
  final bool accessoriesOnly;
  final String? semanticLabel;
  final bool showParticles;

  @override
  State<CompanionView> createState() => _CompanionViewState();
}

class _CompanionViewState extends State<CompanionView> with DecorClockListener {
  final _t = ValueNotifier<double>(0.25);
  Duration _period = const Duration(milliseconds: 3200);

  // Idle life (breathing, blinking, bobbing) runs on the shared decor
  // clock: decorative rate, paused when the page is hidden.
  @override
  void onDecorTick(double seconds) {
    final us = (seconds * 1e6).round();
    _t.value = (us % _period.inMicroseconds) / _period.inMicroseconds;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CompanionView old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final energetic =
        widget.traits.contains('energetic') ||
        widget.traits.contains('playful');
    final sleepy =
        widget.traits.contains('sleepy') || widget.traits.contains('calm');
    final speed = emotionById(
      widget.expression ?? widget.look.expression,
    ).motion.speed;
    // Energy from the personality, nudged by old trait tags.
    final e = (widget.energy + (energetic ? 0.2 : 0) - (sleepy ? 0.2 : 0))
        .clamp(0.0, 1.0);
    final ms = (4600 - e * 2600) / speed.clamp(0.5, 1.4);
    _period = Duration(milliseconds: ms.round().clamp(1400, 7000));
    // Animation quality "Off" (Graphics & Performance) keeps companions
    // still, like reduced motion.
    final run =
        widget.animate &&
        !reduced &&
        widget.intensity > 0.01 &&
        GraphicsScope.of(context).animationDetail > 0;
    setDecorRunning(run);
    if (!run) _t.value = 0.25;
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.semanticLabel ?? widget.species.name,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: CustomPaint(
              painter: CreaturePainter(
                species: widget.species,
                look: widget.look,
                pose: widget.pose,
                t: _t,
                expression: widget.expression,
                particles: widget.showParticles,
                accessoriesOnly: widget.accessoriesOnly,
                fit: widget.fit,
                intensity: widget.intensity,
                expressiveness: widget.expressiveness,
                weather: widget.weather,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Anchor {
  const _Anchor(this.head, this.headR, this.neckY, this.bodyRect);
  final Offset head;
  final double headR;
  final double neckY;
  final Rect bodyRect;
}

class CreaturePainter extends CustomPainter {
  CreaturePainter({
    required this.species,
    required this.look,
    required this.pose,
    required ValueNotifier<double> t,
    this.expression,
    this.accessoriesOnly = false,
    this.particles = true,
    this.fit,
    this.intensity = 1,
    this.expressiveness = 0.6,
    this.weather,
  }) : _t = t,
       super(repaint: t);

  /// App-wide animation strength (0 still – 1 full).
  final double intensity;

  /// From the companion's personality: how big their moods look.
  final double expressiveness;

  /// The habitat's weather when they react to it (null: they don't).
  final String? weather;

  /// The emotion showing right now.
  String get _expr =>
      expression ??
      switch (pose) {
        CompanionPose.sleep => 'sleepy',
        CompanionPose.play ||
        CompanionPose.hop ||
        CompanionPose.dance ||
        CompanionPose.celebrate => 'excited',
        CompanionPose.shiver => 'scared',
        CompanionPose.peek => 'curious',
        _ => look.expression,
      };

  final Species species;
  final CompanionLook look;
  final CompanionPose pose;
  final ValueNotifier<double> _t;
  final String? expression;
  final bool accessoriesOnly;
  final bool particles;
  final ArtFit? fit;

  static const _tau = math.pi * 2;

  /// Where the eyes were actually drawn this frame, so glasses sit on them
  /// whatever the body plan.
  Offset? _eyeCenter;
  double? _eyeGapPx;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _t.value;
    _eyeCenter = null;
    _eyeGapPx = null;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final emo = emotionById(_expr);
    final mo = emo.motion;
    final k = (intensity * (0.4 + expressiveness)).clamp(0.0, 1.6);
    final n = mo.speed >= 1.4 ? 2 : 1;
    final floats = species.floats || pose == CompanionPose.hop;
    final bob =
        math.sin(t * _tau * n) *
            (floats ? 3.5 : 1.2) *
            (0.4 + 0.6 * mo.bob * k) -
        (pose == CompanionPose.hop || pose == CompanionPose.celebrate
            ? (math.sin(t * _tau * n).abs() *
                  (pose == CompanionPose.celebrate ? 9 : 6) *
                  k)
            : 0) -
        math.sin(t * _tau * n).abs() * 5 * mo.bounce * k;
    if (particles) _particles(canvas, t, behind: true);
    // Ground shadow.
    if (!accessoriesOnly) {
      final double sw = 34 - (floats ? bob.abs() * 1.5 : 0.0);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(50, 95), width: sw, height: 5),
        Paint()..color = const Color(0x22000000),
      );
    }
    canvas.save();
    canvas.translate(0, bob);
    if (pose == CompanionPose.play) {
      canvas.translate(50, 70);
      canvas.rotate(math.sin(t * _tau) * 0.12);
      canvas.translate(-50, -70);
    }
    _motion(canvas, t, mo, k);
    final f = fit;
    final anchor = accessoriesOnly
        ? (f == null
              ? const _Anchor(
                  Offset(50, 40),
                  26,
                  62,
                  Rect.fromLTWH(26, 56, 48, 36),
                )
              : _Anchor(
                  Offset(f.headX, f.headY),
                  f.headR,
                  f.neckY,
                  Rect.fromLTWH(
                    f.headX - f.headR * 0.95,
                    f.neckY - 4,
                    f.headR * 1.9,
                    math.max(12, 94 - f.neckY),
                  ),
                ))
        : _body(canvas, t);
    _accessories(canvas, anchor, t);
    if (!accessoriesOnly || fit != null) {
      if (weather != null) _weatherProps(canvas, anchor.head, anchor.headR, t);
      if (particles) _emote(canvas, emo.emote, anchor.head, anchor.headR, t);
    }
    canvas.restore();
    if (particles) _particles(canvas, t, behind: false);
    if (pose == CompanionPose.sleep || (particles && emo.emote == Emote.zzz))
      _zzz(canvas, t);
    if (pose == CompanionPose.music) _notes(canvas, t);
    canvas.restore();
  }

  // ── Bodies ─────────────────────────────────────────────────────────────

  Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;
  Paint get _line => Paint()
    ..color = const Color(0x55000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..strokeJoin = StrokeJoin.round;

  _Anchor _body(Canvas c, double t) {
    final p = look.primaryOf(species), s = look.secondaryOf(species);
    switch (species.body) {
      case BodyKind.critter:
        return _critter(c, t, p, s);
      case BodyKind.bird:
        return _bird(c, t, p, s);
      case BodyKind.fish:
        return _fish(c, t, p, s);
      case BodyKind.turtle:
        return _turtle(c, t, p, s);
      case BodyKind.slime:
        return _blob(c, t, p, s, slime: true);
      case BodyKind.spirit:
        return _blob(c, t, p, s, slime: false);
      case BodyKind.cloud:
        return _cloud(c, t, p, s);
      case BodyKind.star:
        return _star(c, t, p, s);
      case BodyKind.mushroom:
        return _mushroom(c, t, p, s);
      case BodyKind.crystal:
        return _crystal(c, t, p, s);
      case BodyKind.flame:
        return _flame(c, t, p, s);
      case BodyKind.serpent:
        return _serpent(c, t, p, s);
      case BodyKind.lizard:
        return _lizard(c, t, p, s);
      case BodyKind.frog:
        return _frog(c, t, p, s);
      case BodyKind.jelly:
        return _jelly(c, t, p, s);
      case BodyKind.octopus:
        return _octopus(c, t, p, s);
      case BodyKind.seahorse:
        return _seahorse(c, t, p, s);
      case BodyKind.constellation:
        return _constellation(c, t, p, s);
    }
  }

  // ── More body plans ───────────────────────────────────────────────────

  _Anchor _serpent(Canvas c, double t, Color p, Color s) {
    // A coiled snake: stacked coils, head raised on the top coil.
    final sway = math.sin(t * _tau) * 2;
    for (final (y, w) in const [(84.0, 66.0), (72.0, 54.0)]) {
      final r = Rect.fromCenter(center: Offset(50, y), width: w, height: 18);
      final coil = Path()
        ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(9)));
      c.drawPath(coil, _patternPaint(p, s, r));
      _pattern(c, coil, r, p, s);
      c.drawPath(coil, _line);
      for (var i = 0; i < 5; i++) {
        c.drawCircle(
          Offset(r.left + 10 + i * (w - 20) / 4, y),
          2,
          _fill(s.withValues(alpha: 0.7)),
        );
      }
    }
    final neck = Path()
      ..moveTo(58, 66)
      ..quadraticBezierTo(66 + sway, 52, 54 + sway, 40)
      ..lineTo(46 + sway, 44)
      ..quadraticBezierTo(56 + sway, 54, 46, 66)
      ..close();
    c.drawPath(neck, _fill(p));
    c.drawPath(neck, _line);
    final head = Offset(50 + sway, 34);
    final hr = 15.0;
    final hp = Path()
      ..addOval(
        Rect.fromCenter(center: head, width: hr * 2.3, height: hr * 1.6),
      );
    c.drawPath(hp, _fill(p));
    c.drawPath(hp, _line);
    // Little forked tongue.
    final tongue = Paint()
      ..color = const Color(0xFFE5383B)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    if (math.sin(t * _tau * 3) > 0.6) {
      c.drawLine(
        head.translate(0, hr * 0.7),
        head.translate(0, hr * 1.2),
        tongue,
      );
      c.drawLine(
        head.translate(0, hr * 1.2),
        head.translate(-2, hr * 1.45),
        tongue,
      );
      c.drawLine(
        head.translate(0, hr * 1.2),
        head.translate(2, hr * 1.45),
        tongue,
      );
    }
    _face(c, t, head, hr, eyeY: -1, eyeGap: 9);
    return _Anchor(head, hr, 48, const Rect.fromLTWH(20, 64, 60, 28));
  }

  _Anchor _lizard(Canvas c, double t, Color p, Color s) {
    final ex = species.extras;
    final sh = species.shape;
    // Long low body seen from the front-ish, with splayed legs and a tail.
    final body = Rect.fromCenter(
      center: Offset(50, sh.bodyY == 72 ? 76 : sh.bodyY),
      width: sh.bodyW == 46 ? 56 : sh.bodyW,
      height: sh.bodyH == 36 ? 26 : sh.bodyH,
    );
    final sway = math.sin(t * _tau) * 0.2;
    c.save();
    c.translate(body.right - 6, body.center.dy + 4);
    c.rotate(sway);
    final tail = Path()
      ..moveTo(0, -6)
      ..quadraticBezierTo(22 * sh.tailScale, -4, 30 * sh.tailScale, 12)
      ..quadraticBezierTo(18 * sh.tailScale, 4, 0, 6)
      ..close();
    c.drawPath(tail, _fill(p));
    c.drawPath(tail, _line);
    c.restore();
    for (final side in [-1.0, 1.0]) {
      for (final dy in [-4.0, 8.0]) {
        final leg = Path()
          ..moveTo(50 + side * body.width * 0.35, body.center.dy + dy)
          ..lineTo(
            50 + side * (body.width * 0.5 + 10),
            body.center.dy + dy + 10,
          )
          ..lineTo(50 + side * (body.width * 0.5 + 4), body.center.dy + dy + 14)
          ..close();
        c.drawPath(leg, _fill(Color.lerp(p, Colors.black, 0.1)!));
        c.drawPath(leg, _line);
        for (final f in [-3.0, 0.0, 3.0]) {
          c.drawCircle(
            Offset(
              50 + side * (body.width * 0.5 + 9) + f,
              body.center.dy + dy + 13,
            ),
            1.8,
            _fill(Color.lerp(p, Colors.black, 0.1)!),
          );
        }
      }
    }
    final bp = Path()
      ..addRRect(
        RRect.fromRectAndRadius(body, Radius.circular(body.height / 2)),
      );
    c.drawPath(bp, _patternPaint(p, s, body));
    _pattern(c, bp, body, p, s);
    if (species.spots) {
      for (final o in const [
        Offset(-16, -4),
        Offset(-4, 4),
        Offset(10, -5),
        Offset(20, 3),
      ]) {
        c.drawCircle(body.center + o, 2.6, _fill(s));
      }
    }
    c.drawPath(bp, _line);
    final head = Offset(50, body.top - 6);
    final hr = 18.0;
    if (ex.contains('gills')) {
      for (final side in [-1.0, 1.0]) {
        for (final a in [-0.5, 0.0, 0.5]) {
          c.save();
          c.translate(head.dx + side * hr * 1.05, head.dy - 2);
          c.rotate(
            side * (math.pi / 2 + a) -
                math.pi / 2 +
                math.sin(t * _tau + a) * 0.08,
          );
          final g = Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(-4, -8, 0, -15)
            ..quadraticBezierTo(4, -8, 0, 0);
          c.drawPath(g, _fill(s));
          c.drawPath(g, _line);
          c.restore();
        }
      }
    }
    if (ex.contains('beard')) {
      final b = Path()..moveTo(head.dx - hr, head.dy + 4);
      for (var i = 0; i <= 8; i++) {
        final x = head.dx - hr + i * hr / 4;
        b.lineTo(x, head.dy + (i.isEven ? 16 : 11));
      }
      b
        ..lineTo(head.dx + hr, head.dy + 4)
        ..close();
      c.drawPath(b, _fill(Color.lerp(p, Colors.black, 0.2)!));
      c.drawPath(b, _line);
    }
    final hp = Path()
      ..addOval(
        Rect.fromCenter(center: head, width: hr * 2.5, height: hr * 1.55),
      );
    c.drawPath(
      hp,
      _patternPaint(p, s, Rect.fromCircle(center: head, radius: hr)),
    );
    c.drawPath(hp, _line);
    _face(c, t, head, hr, eyeY: -2, eyeGap: 12);
    return _Anchor(head, hr, head.dy + hr * 0.8, body);
  }

  _Anchor _frog(Canvas c, double t, Color p, Color s) {
    final squat = pose == CompanionPose.hop
        ? -math.sin(t * _tau).abs() * 4
        : 0.0;
    final body = Rect.fromCenter(
      center: Offset(50, 72 + squat),
      width: 60,
      height: 38,
    );
    // Back legs folded at the sides.
    for (final side in [-1.0, 1.0]) {
      final leg = Rect.fromCenter(
        center: Offset(50 + side * 28, 82),
        width: 24,
        height: 18,
      );
      c.drawOval(leg, _fill(Color.lerp(p, Colors.black, 0.1)!));
      c.drawOval(leg, _line);
      final foot = Rect.fromCenter(
        center: Offset(50 + side * 34, 91),
        width: 18,
        height: 6,
      );
      c.drawOval(foot, _fill(Color.lerp(p, Colors.black, 0.1)!));
    }
    final bp = Path()..addOval(body);
    c.drawPath(bp, _patternPaint(p, s, body));
    _pattern(c, bp, body, p, s);
    c.drawOval(
      Rect.fromCenter(
        center: body.center.translate(0, 6),
        width: 36,
        height: 22,
      ),
      _fill(look.bellyOf(species)),
    );
    c.drawPath(bp, _line);
    // Wide flat head with big eye bumps on top.
    final head = Offset(50, 50 + squat);
    final hr = 20.0;
    for (final side in [-1.0, 1.0]) {
      final bump = Offset(head.dx + side * 13, head.dy - 12);
      c.drawCircle(bump, 9, _fill(p));
      c.drawCircle(bump, 9, _line);
    }
    final hp = Path()
      ..addOval(
        Rect.fromCenter(center: head, width: hr * 2.9, height: hr * 1.5),
      );
    c.drawPath(hp, _fill(p));
    c.drawPath(hp, _line);
    c.drawArc(
      Rect.fromCenter(
        center: head.translate(0, 3),
        width: hr * 1.8,
        height: 10,
      ),
      0.2,
      math.pi - 0.4,
      false,
      _line,
    );
    _face(c, t, head.translate(0, -12), hr, eyeY: 0, eyeGap: 13);
    return _Anchor(head.translate(0, -6), hr, head.dy + 12, body);
  }

  _Anchor _jelly(Canvas c, double t, Color p, Color s) {
    final pulse = math.sin(t * _tau) * 2;
    final bell = Rect.fromCenter(
      center: Offset(50, 40 - pulse),
      width: 56 + pulse * 2,
      height: 40,
    );
    _glow(c, bell.center, 50, p);
    // Tentacles.
    final tp = Paint()
      ..color = s.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final x = bell.left + 8 + i * (bell.width - 16) / 5;
      final path = Path()..moveTo(x, bell.bottom - 6);
      for (var k = 1; k <= 4; k++) {
        path.quadraticBezierTo(
          x + (k.isEven ? 5 : -5) + math.sin(t * _tau + i) * 2,
          bell.bottom - 6 + k * 9 - 4,
          x,
          bell.bottom - 6 + k * 9,
        );
      }
      c.drawPath(path, tp);
    }
    final bp = Path()
      ..addArc(bell, math.pi, math.pi)
      ..quadraticBezierTo(
        bell.right - 6,
        bell.center.dy + 8,
        bell.center.dx,
        bell.center.dy + 6,
      )
      ..quadraticBezierTo(
        bell.left + 6,
        bell.center.dy + 8,
        bell.left,
        bell.center.dy,
      )
      ..close();
    c.drawPath(bp, _fill(p.withValues(alpha: 0.85)));
    c.drawPath(bp, _line);
    c.drawOval(
      Rect.fromCenter(
        center: bell.center.translate(-10, -10),
        width: 12,
        height: 7,
      ),
      _fill(Colors.white.withValues(alpha: 0.4)),
    );
    final head = bell.center.translate(0, -2);
    _face(c, t, head, 18, eyeY: 0, eyeGap: 9);
    return _Anchor(head, 22, bell.bottom, bell);
  }

  _Anchor _octopus(Canvas c, double t, Color p, Color s) {
    final head = const Offset(50, 42);
    final hr = 24.0;
    // Eight curling arms.
    for (var i = 0; i < 8; i++) {
      final x = 22.0 + i * 8;
      final dir = i < 4 ? -1.0 : 1.0;
      final wig = math.sin(t * _tau + i) * 3;
      final arm = Path()
        ..moveTo(x - 4, 58)
        ..quadraticBezierTo(x + dir * 4 + wig, 76, x + dir * 10, 86)
        ..quadraticBezierTo(x + dir * 16, 92, x + dir * 12 + wig, 82)
        ..quadraticBezierTo(x + dir * 6, 78, x + 4, 58)
        ..close();
      c.drawPath(
        arm,
        _fill(Color.lerp(p, Colors.black, i.isEven ? 0.0 : 0.08)!),
      );
      c.drawPath(arm, _line);
      c.drawCircle(Offset(x + dir * 9, 84), 1.4, _fill(s));
    }
    final hp = Path()
      ..addOval(
        Rect.fromCenter(center: head, width: hr * 2.1, height: hr * 2.2),
      );
    c.drawPath(
      hp,
      _patternPaint(p, s, Rect.fromCircle(center: head, radius: hr)),
    );
    _pattern(c, hp, Rect.fromCircle(center: head, radius: hr), p, s);
    for (final o in const [Offset(-10, -14), Offset(8, -18), Offset(14, -6)]) {
      c.drawCircle(head + o, 2.4, _fill(s.withValues(alpha: 0.8)));
    }
    c.drawPath(hp, _line);
    _face(c, t, head.translate(0, 8), hr, eyeY: 0, eyeGap: 9);
    return _Anchor(head, hr, 62, const Rect.fromLTWH(22, 58, 56, 30));
  }

  _Anchor _seahorse(Canvas c, double t, Color p, Color s) {
    final bob = math.sin(t * _tau) * 1.5;
    // S-shaped body: head with snout, belly, curled tail.
    final body = Path()
      ..moveTo(46, 30 + bob)
      ..cubicTo(64, 34 + bob, 66, 56 + bob, 56, 66 + bob)
      ..cubicTo(50, 74, 56, 84, 62, 84)
      ..cubicTo(68, 84, 68, 76, 62, 76)
      ..cubicTo(58, 76, 58, 80, 60, 80)
      ..cubicTo(50, 80, 44, 70, 42, 62)
      ..cubicTo(38, 50, 40, 36, 46, 30 + bob)
      ..close();
    final rect = Rect.fromLTWH(38, 28, 30, 58);
    c.drawPath(body, _patternPaint(p, s, rect));
    _pattern(c, body, rect, p, s);
    c.drawPath(body, _line);
    for (var i = 0; i < 6; i++) {
      c.drawLine(
        Offset(45 + i * 1.5, 42.0 + i * 5 + bob),
        Offset(52 + i * 1.5, 42.0 + i * 5 + bob),
        _line,
      );
    }
    // Dorsal fin flutters.
    final fin = Path()
      ..moveTo(58, 46 + bob)
      ..quadraticBezierTo(
        70 + math.sin(t * _tau * 4) * 2,
        50 + bob,
        60,
        58 + bob,
      )
      ..close();
    c.drawPath(fin, _fill(s.withValues(alpha: 0.8)));
    // Head and snout.
    final head = Offset(46, 28 + bob);
    final hp = Path()
      ..addOval(Rect.fromCenter(center: head, width: 22, height: 18));
    c.drawPath(hp, _fill(p));
    c.drawPath(hp, _line);
    final snout = RRect.fromRectAndRadius(
      Rect.fromLTWH(26, head.dy - 1, 14, 6),
      const Radius.circular(3),
    );
    c.drawRRect(snout, _fill(p));
    c.drawRRect(snout, _line);
    for (final o in const [Offset(-2, -10), Offset(3, -11), Offset(7, -9)]) {
      c.drawCircle(head + o, 2, _fill(s));
    }
    _face(c, t, head.translate(2, 0), 13, eyeY: -1, eyeGap: 5);
    return _Anchor(head, 13, 40 + bob, rect);
  }

  _Anchor _constellation(Canvas c, double t, Color p, Color s) {
    // A creature drawn as stars joined by faint lines (a little bear).
    const pts = [
      Offset(40, 28),
      Offset(60, 28),
      Offset(50, 40),
      Offset(36, 46),
      Offset(64, 46),
      Offset(30, 64),
      Offset(70, 64),
      Offset(42, 72),
      Offset(58, 72),
      Offset(36, 90),
      Offset(64, 90),
      Offset(80, 74),
    ];
    const links = [
      (0, 2),
      (1, 2),
      (2, 3),
      (2, 4),
      (3, 5),
      (4, 6),
      (5, 7),
      (6, 8),
      (7, 8),
      (7, 9),
      (8, 10),
      (6, 11),
    ];
    _glow(c, const Offset(50, 56), 54, p);
    final line = Paint()
      ..color = s.withValues(alpha: 0.55)
      ..strokeWidth = 1.4;
    for (final (a, b) in links) {
      c.drawLine(pts[a], pts[b], line);
    }
    // Soft body haze so it reads as one creature.
    c.drawOval(
      Rect.fromCenter(center: const Offset(50, 66), width: 42, height: 34),
      _fill(p.withValues(alpha: 0.22)),
    );
    c.drawCircle(const Offset(50, 38), 16, _fill(p.withValues(alpha: 0.22)));
    for (final (i, o) in pts.indexed) {
      _tinyStar(
        c,
        o,
        3.2 + math.sin(t * _tau * 2 + i) * 0.9,
        _fill(i.isEven ? s : Colors.white),
      );
    }
    _face(c, t, const Offset(50, 38), 14, eyeY: 0, eyeGap: 6);
    return const _Anchor(Offset(50, 38), 16, 50, Rect.fromLTWH(30, 50, 40, 36));
  }

  void _glow(Canvas c, Offset center, double r, Color color) {
    if (!species.glow) return;
    c.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  _Anchor _critter(Canvas c, double t, Color p, Color s) {
    final sh = species.shape;
    final ex = species.extras;
    final head = Offset(50, sh.headY);
    final hr = sh.headR;
    final body = Rect.fromCenter(
      center: Offset(50, sh.bodyY),
      width: sh.bodyW,
      height: sh.bodyH,
    );
    final feetY = math.min(92.0, body.bottom + 3 + sh.legs);
    _glow(c, const Offset(50, 60), 48, p);
    if (look.wingsOf(species)) {
      if (ex.contains('membrane')) {
        _batWings(c, t, Offset(50, body.top + 6), p, s);
      } else {
        _wings(c, t, Offset(50, body.top + 8), p, s, 26);
      }
    }
    final tailBase = Offset(body.right - 4, body.bottom - 6);
    final tp = ex.contains('bareTail') ? const Color(0xFFF2B5C4) : p;
    if (ex.contains('multiTail')) {
      for (final a in const [-0.55, 0.0, 0.55]) {
        c.save();
        c.translate(tailBase.dx, tailBase.dy);
        c.rotate(a);
        c.translate(-tailBase.dx, -tailBase.dy);
        _tail(c, t, tailBase, tp, s);
        c.restore();
      }
    } else {
      c.save();
      final k = species.shape.tailScale;
      c.translate(tailBase.dx, tailBase.dy);
      c.scale(k);
      c.translate(-tailBase.dx, -tailBase.dy);
      _tail(c, t, tailBase, tp, s);
      c.restore();
    }
    // Legs: long-legged species stand on visible legs.
    if (sh.legs > 3) {
      final legPaint = _fill(Color.lerp(p, Colors.black, 0.06)!);
      for (final x in [
        body.left + body.width * 0.2,
        body.left + body.width * 0.4,
        body.left + body.width * 0.6,
        body.left + body.width * 0.8,
      ]) {
        final leg = RRect.fromRectAndRadius(
          Rect.fromLTRB(x - 3.2, body.center.dy, x + 3.2, feetY),
          const Radius.circular(3),
        );
        c.drawRRect(leg, legPaint);
        c.drawRRect(leg, _line);
      }
    }
    if (species.spines) {
      final sp = Path();
      for (var i = 0; i < 11; i++) {
        final a = math.pi + i / 10 * math.pi;
        final base = Offset(50 + math.cos(a) * 30, 60 + math.sin(a) * 34);
        final tip = Offset(50 + math.cos(a) * 40, 58 + math.sin(a) * 44);
        final side = Offset(
          50 + math.cos(a + 0.18) * 30,
          60 + math.sin(a + 0.18) * 34,
        );
        sp
          ..moveTo(base.dx, base.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(side.dx, side.dy)
          ..close();
      }
      c.drawPath(sp, _fill(Color.lerp(p, Colors.black, 0.25)!));
    }
    // Body and belly.
    final bodyPaint = _patternPaint(p, s, body);
    final bodyPath = Path()
      ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(sh.bodyRound)));
    c.drawPath(bodyPath, bodyPaint);
    _pattern(c, bodyPath, body, p, s);
    _extrasOnBody(c, bodyPath, body, p, s);
    c.drawOval(
      Rect.fromCenter(
        center: body.center.translate(0, body.height * 0.1),
        width: body.width * 0.56,
        height: body.height * 0.6,
      ),
      _fill(look.bellyOf(species)),
    );
    c.drawPath(bodyPath, _line);
    // Feet.
    final foot = look.pattern == 'socks'
        ? Colors.white
        : Color.lerp(p, Colors.black, 0.08)!;
    for (final x in [50 - body.width * 0.24, 50 + body.width * 0.24]) {
      final r = Rect.fromCenter(
        center: Offset(x, feetY - 3),
        width: 13,
        height: 8,
      );
      c.drawOval(r, _fill(foot));
      c.drawOval(r, _line);
    }
    // Front paws (one waves).
    final wave = pose == CompanionPose.wave ? math.sin(t * _tau * 2) * 6 : 0.0;
    final hug =
        pose == CompanionPose.cuddle ||
        pose == CompanionPose.read ||
        pose == CompanionPose.eat;
    for (final (i, x) in [
      (0, 50 - body.width * 0.22),
      (1, 50 + body.width * 0.22),
    ]) {
      var center = Offset(x, body.center.dy + (hug ? -2 : 4));
      if (i == 0 && pose == CompanionPose.wave) center = Offset(28, 58 + wave);
      final r = Rect.fromCenter(center: center, width: 10, height: 9);
      c.drawOval(r, _fill(foot));
      c.drawOval(r, _line);
    }
    if (pose == CompanionPose.read) _book(c);
    if (pose == CompanionPose.eat) _treat(c);
    if (ex.contains('mane')) _mane(c, head, hr, Color.lerp(p, s, 0.35)!);
    // Ears behind head.
    _scaledEars(c, t, head, hr, p, s, behind: true);
    // Head.
    final headRect = Rect.fromCenter(
      center: head,
      width: hr * sh.headW,
      height: hr * sh.headH,
    );
    if (ex.contains('cheeks')) {
      for (final side in [-1.0, 1.0]) {
        c.drawCircle(
          head + Offset(side * hr * 0.82, hr * 0.32),
          hr * 0.42,
          _fill(Color.lerp(p, s, 0.4)!),
        );
        c.drawCircle(
          head + Offset(side * hr * 0.82, hr * 0.32),
          hr * 0.42,
          _line,
        );
      }
    }
    final headPath = Path()..addOval(headRect);
    c.drawPath(headPath, _patternPaint(p, s, headRect));
    if (species.mask) {
      c.save();
      c.clipPath(headPath);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: head.translate(0, 0),
            width: hr * 2.2,
            height: 11,
          ),
          const Radius.circular(6),
        ),
        _fill(Color.lerp(p, Colors.black, 0.55)!),
      );
      c.restore();
    }
    if (species.spots || look.pattern == 'spots') {
      for (final o in const [
        Offset(-14, -10),
        Offset(13, -12),
        Offset(-4, -17),
      ]) {
        c.drawCircle(head + o, 2.2, _fill(s.withValues(alpha: 0.85)));
      }
    }
    if (ex.contains('facemask')) {
      for (final side in [-1.0, 1.0]) {
        c.drawOval(
          Rect.fromCenter(
            center: head + Offset(side * hr * 0.42, -hr * 0.28),
            width: hr * 0.5,
            height: hr * 0.34,
          ),
          _fill(Colors.white.withValues(alpha: 0.9)),
        );
      }
      c.drawOval(
        Rect.fromCenter(
          center: head.translate(0, hr * 0.42),
          width: hr * 0.9,
          height: hr * 0.5,
        ),
        _fill(Colors.white.withValues(alpha: 0.9)),
      );
    }
    if (species.muzzle && sh.snout == 0)
      c.drawOval(
        Rect.fromCenter(center: head.translate(0, 9), width: 21, height: 14),
        _fill(s),
      );
    c.drawPath(headPath, _line);
    if (sh.snout > 0)
      _snout(
        c,
        head,
        hr,
        sh.snout,
        sh.snoutW,
        p,
        species.muzzle ? s : Color.lerp(p, s, 0.55)!,
      );
    if (ex.contains('pigNose')) {
      final n = Rect.fromCenter(
        center: head.translate(0, hr * 0.38),
        width: hr * 0.75,
        height: hr * 0.5,
      );
      c.drawOval(n, _fill(Color.lerp(p, const Color(0xFFFF8FAB), 0.5)!));
      c.drawOval(n, _line);
      for (final side in [-1.0, 1.0]) {
        c.drawOval(
          Rect.fromCenter(
            center: n.center.translate(side * hr * 0.14, 0),
            width: 2.6,
            height: 3.6,
          ),
          _fill(const Color(0x88000000)),
        );
      }
    }
    if (ex.contains('whiskers')) {
      final w = Paint()
        ..color = const Color(0x66000000)
        ..strokeWidth = 0.7;
      for (final side in [-1.0, 1.0]) {
        for (final dy in [-1.5, 1.5]) {
          final o = head + Offset(side * hr * 0.35, hr * 0.38);
          c.drawLine(o, o + Offset(side * hr * 0.75, dy * 2), w);
        }
      }
    }
    if (ex.contains('horn')) {
      final h = Path()
        ..moveTo(head.dx - 3.5, head.dy - hr * 0.8)
        ..lineTo(head.dx, head.dy - hr * 1.65)
        ..lineTo(head.dx + 3.5, head.dy - hr * 0.8)
        ..close();
      c.drawPath(h, _fill(const Color(0xFFFFE08A)));
      c.drawPath(h, _line);
    }
    if (ex.contains('leaf')) {
      final l = Path()
        ..moveTo(head.dx, head.dy - hr * 0.9)
        ..quadraticBezierTo(
          head.dx + 12,
          head.dy - hr * 1.7,
          head.dx + 2,
          head.dy - hr * 1.8,
        )
        ..quadraticBezierTo(
          head.dx - 6,
          head.dy - hr * 1.3,
          head.dx,
          head.dy - hr * 0.9,
        );
      c.drawPath(l, _fill(const Color(0xFF7BC96F)));
      c.drawPath(l, _line);
    }
    _scaledEars(c, t, head, hr, p, s, behind: false);
    if (species.crescent) {
      final m = Path()
        ..addOval(Rect.fromCircle(center: head.translate(0, -14), radius: 5))
        ..addOval(
          Rect.fromCircle(center: head.translate(2.5, -15.5), radius: 4.4),
        )
        ..fillType = PathFillType.evenOdd;
      c.drawPath(m, _fill(const Color(0xFFFFD866)));
    }
    if (look.horns != 'none' || species.horns)
      _horns(c, head, hr, look.horns == 'none' ? 'curved' : look.horns, s);
    _face(c, t, head, hr, beak: species.beak, eyeY: 1, eyeGap: sh.eyeGap);
    if (ex.contains('wrinkles')) {
      for (final dy in [-0.55, -0.42]) {
        c.drawArc(
          Rect.fromCenter(
            center: head.translate(0, hr * dy + 4),
            width: hr * 0.7,
            height: 6,
          ),
          math.pi + 0.4,
          math.pi - 0.8,
          false,
          _line,
        );
      }
    }
    if (ex.contains('tufts')) {
      final tuft = _fill(Color.lerp(p, s, 0.5)!);
      for (final side in [-1.0, 1.0]) {
        final b = head + Offset(side * hr * sh.headW * 0.48, hr * 0.2);
        final path = Path()
          ..moveTo(b.dx, b.dy - 5)
          ..lineTo(b.dx + side * 6, b.dy - 2)
          ..lineTo(b.dx, b.dy)
          ..lineTo(b.dx + side * 6, b.dy + 3)
          ..lineTo(b.dx, b.dy + 5)
          ..close();
        c.drawPath(path, tuft);
      }
    }
    if (ex.contains('sparkles')) {
      final sp = _fill(const Color(0xFFFFF3B0));
      for (final o in const [
        Offset(-30, -20),
        Offset(28, -26),
        Offset(32, 10),
      ]) {
        _tinyStar(c, head + o, 2.6 + math.sin(t * _tau + o.dx) * 0.8, sp);
      }
    }
    return _Anchor(head, hr, head.dy + hr * sh.headH / 2, body);
  }

  void _extrasOnBody(Canvas c, Path clip, Rect r, Color p, Color s) {
    final ex = species.extras;
    if (ex.contains('stripes')) {
      c.save();
      c.clipPath(clip);
      final dark = _fill(
        Color.lerp(p, Colors.black, 0.35)!.withValues(alpha: 0.7),
      );
      for (var i = 1; i <= 3; i++) {
        final x = r.left + r.width * i / 4;
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, r.top + r.height * 0.3),
              width: 4,
              height: r.height * 0.6,
            ),
            const Radius.circular(2),
          ),
          dark,
        );
      }
      c.restore();
    }
    if (ex.contains('gem')) {
      c.save();
      c.clipPath(clip);
      final facet = Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1;
      c.drawLine(r.topLeft, r.center, facet);
      c.drawLine(r.topRight, r.center, facet);
      c.drawLine(r.center, r.bottomCenter, facet);
      c.drawLine(r.centerLeft, r.center, facet);
      c.drawLine(r.centerRight, r.center, facet);
      c.restore();
    }
  }

  /// Ears scaled per species around the top of the head.
  void _scaledEars(
    Canvas c,
    double t,
    Offset head,
    double hr,
    Color p,
    Color s, {
    required bool behind,
  }) {
    final k = species.shape.earScale;
    if (species.extras.contains('lop')) {
      if (!behind) return;
      for (final side in [-1.0, 1.0]) {
        final e = Path()
          ..moveTo(head.dx + side * hr * 0.4, head.dy - hr * 0.7)
          ..quadraticBezierTo(
            head.dx + side * hr * 1.5,
            head.dy - hr * 0.6,
            head.dx + side * hr * 1.25,
            head.dy + hr * 0.9,
          )
          ..quadraticBezierTo(
            head.dx + side * hr * 0.9,
            head.dy + hr * 0.2,
            head.dx + side * hr * 0.4,
            head.dy - hr * 0.7,
          );
        c.drawPath(e, _fill(Color.lerp(p, Colors.black, 0.08)!));
        c.drawPath(e, _line);
      }
      return;
    }
    if (k == 1) return _ears(c, t, head, hr, p, s, behind: behind);
    final pivot = head.translate(0, -hr * 0.6);
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.scale(k);
    c.translate(-pivot.dx, -pivot.dy);
    _ears(c, t, head, hr, p, s, behind: behind);
    c.restore();
  }

  /// A muzzle that sticks out below the eyes, ending in a nose.
  void _snout(
    Canvas c,
    Offset head,
    double hr,
    double len,
    double w,
    Color p,
    Color s,
  ) {
    final top = head.translate(0, hr * 0.05);
    final tip = head.translate(0, hr * (0.55 + len * 0.55));
    final half = hr * 0.42 * w;
    final m = Path()
      ..moveTo(top.dx - half, top.dy)
      ..quadraticBezierTo(
        top.dx - half * 0.9,
        tip.dy - hr * 0.1,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        top.dx + half * 0.9,
        tip.dy - hr * 0.1,
        top.dx + half,
        top.dy,
      )
      ..close();
    c.drawPath(m, _fill(s));
    c.drawPath(m, _line);
    c.drawOval(
      Rect.fromCenter(
        center: tip.translate(0, -2.5),
        width: 6 * w.clamp(0.8, 1.4),
        height: 4,
      ),
      _fill(const Color(0xFF2B2B33)),
    );
  }

  /// A fluffy ruff around the head (wolves, lions, unicorn manes).
  void _mane(Canvas c, Offset head, double hr, Color color) {
    final path = Path();
    const n = 14;
    for (var i = 0; i <= n; i++) {
      final a = math.pi * 0.85 + i / n * math.pi * 1.3;
      final r = hr * (i.isEven ? 1.32 : 1.12);
      final pt = head + Offset(math.cos(a) * r, math.sin(a) * r + hr * 0.2);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    c.drawPath(path, _fill(color));
    c.drawPath(path, _line);
  }

  /// Leathery wings with finger struts (bats).
  void _batWings(Canvas c, double t, Offset base, Color p, Color s) {
    final flap = math.sin(t * _tau * 2) * 0.15;
    final paint = _fill(Color.lerp(p, Colors.black, 0.25)!);
    for (final side in [-1.0, 1.0]) {
      c.save();
      c.translate(base.dx, base.dy);
      c.rotate(side * flap);
      final w = Path()
        ..moveTo(0, 0)
        ..lineTo(side * 44, -18)
        ..quadraticBezierTo(side * 38, -2, side * 42, 8)
        ..quadraticBezierTo(side * 30, 2, side * 28, 14)
        ..quadraticBezierTo(side * 18, 6, side * 14, 18)
        ..close();
      c.drawPath(w, paint);
      c.drawPath(w, _line);
      c.restore();
    }
  }

  _Anchor _bird(Canvas c, double t, Color p, Color s) {
    final sh = species.shape;
    final ex = species.extras;
    final custom = sh.bodyW != 46;
    final center = Offset(50, custom ? sh.bodyY : 62);
    final r = Rect.fromCenter(
      center: center,
      width: custom ? sh.bodyW : 54,
      height: custom ? sh.bodyH : 60,
    );
    _glow(c, center, 50, p);
    if (ex.contains('longTail')) {
      for (final a in const [-0.18, 0.0, 0.18]) {
        final f = Path()
          ..moveTo(50, r.bottom - 8)
          ..quadraticBezierTo(
            50 + a * 60,
            r.bottom + 10 * sh.tailScale,
            50 + a * 40,
            math.min(98, r.bottom + 18 * sh.tailScale),
          )
          ..quadraticBezierTo(50 + a * 20, r.bottom + 4, 50, r.bottom - 8);
        c.drawPath(f, _fill(a == 0 ? s : Color.lerp(p, s, 0.5)!));
        c.drawPath(f, _line);
      }
    } else {
      _tail(c, t, Offset(50, r.bottom - 2), p, s);
    }
    if (species.wings) _wings(c, t, const Offset(50, 60), p, s, 32);
    final body = Path()..addOval(r);
    c.drawPath(body, _patternPaint(p, s, r));
    _pattern(c, body, r, p, s);
    _extrasOnBody(c, body, r, p, s);
    c.drawOval(
      Rect.fromCenter(
        center: center.translate(0, r.height * 0.17),
        width: r.width * 0.6,
        height: r.height * 0.53,
      ),
      _fill(look.bellyOf(species)),
    );
    c.drawPath(body, _line);
    // Side wings.
    final flap = pose == CompanionPose.wave || pose == CompanionPose.play
        ? math.sin(t * _tau * 3) * 0.4
        : math.sin(t * _tau) * 0.06;
    for (final side in [-1.0, 1.0]) {
      c.save();
      c.translate(50 + side * (r.width / 2 - 2), center.dy + 2);
      c.rotate(side * (0.25 + flap));
      final w = Rect.fromCenter(
        center: Offset(side * 2, 4),
        width: 13,
        height: 26,
      );
      c.drawOval(w, _fill(Color.lerp(p, Colors.black, 0.12)!));
      c.drawOval(w, _line);
      c.restore();
    }
    // Feet.
    for (final x in [42.0, 58.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, math.min(94, r.bottom + 3)),
            width: 9,
            height: 4,
          ),
          const Radius.circular(2),
        ),
        _fill(const Color(0xFFFF9F43)),
      );
    }
    final head = Offset(50, custom ? sh.headY : 48);
    final hr = custom ? sh.headR : 22.0;
    if (ex.contains('crest')) {
      for (final a in const [-0.35, -0.1, 0.15]) {
        final f = Path()
          ..moveTo(head.dx, head.dy - hr * 0.7)
          ..quadraticBezierTo(
            head.dx + a * 30,
            head.dy - hr * 1.6,
            head.dx + a * 30 + 6,
            head.dy - hr * 1.9,
          )
          ..quadraticBezierTo(
            head.dx + a * 10,
            head.dy - hr * 1.2,
            head.dx + 4,
            head.dy - hr * 0.7,
          );
        c.drawPath(f, _fill(s));
        c.drawPath(f, _line);
      }
    }
    if (ex.contains('comb')) {
      final f = Path()..moveTo(head.dx - 8, head.dy - hr * 0.75);
      for (var i = 0; i < 3; i++) {
        f.quadraticBezierTo(
          head.dx - 8 + i * 6 + 3,
          head.dy - hr * 1.35,
          head.dx - 8 + (i + 1) * 6,
          head.dy - hr * 0.8,
        );
      }
      f.close();
      c.drawPath(f, _fill(const Color(0xFFE5383B)));
      c.drawPath(f, _line);
      final w = Rect.fromCenter(
        center: head.translate(0, hr * 0.6),
        width: 6,
        height: 9,
      );
      c.drawOval(w, _fill(const Color(0xFFE5383B)));
    }
    _scaledEars(c, t, head, hr, p, s, behind: false);
    if (ex.contains('cheeks')) {
      for (final side in [-1.0, 1.0]) {
        c.drawCircle(
          head + Offset(side * hr * 0.62, hr * 0.28),
          hr * 0.22,
          _fill(const Color(0xFFF28C38)),
        );
      }
    }
    if (ex.contains('bill')) {
      final bill = Rect.fromCenter(
        center: head.translate(0, hr * 0.42),
        width: hr * 1.05,
        height: hr * 0.42,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(bill, Radius.circular(hr * 0.2)),
        _fill(const Color(0xFFFFB347)),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(bill, Radius.circular(hr * 0.2)),
        _line,
      );
    }
    _face(
      c,
      t,
      head,
      hr,
      beak: !ex.contains('bill'),
      eyeY: 0,
      eyeGap: 9,
      owl: species.id == 'owl',
    );
    return _Anchor(head, hr, head.dy + hr * 0.9, r);
  }

  _Anchor _fish(Canvas c, double t, Color p, Color s) {
    const center = Offset(46, 56);
    final custom = species.shape.bodyW != 46;
    final r = Rect.fromCenter(
      center: center,
      width: custom ? species.shape.bodyW : 58,
      height: custom ? species.shape.bodyH : 44,
    );
    if (species.extras.contains('dorsal')) {
      final d = Path()
        ..moveTo(40, r.top + 4)
        ..lineTo(52, r.top - 18)
        ..quadraticBezierTo(56, r.top - 4, 62, r.top + 4)
        ..close();
      c.drawPath(d, _fill(Color.lerp(p, Colors.black, 0.1)!));
      c.drawPath(d, _line);
    }
    final sway = math.sin(t * _tau * 2) * 0.25;
    // Tail fan.
    c.save();
    c.translate(73, 56);
    c.rotate(sway);
    final tail = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(18, -22, 24, -16)
      ..quadraticBezierTo(16, 0, 24, 16)
      ..quadraticBezierTo(18, 22, 0, 0);
    c.drawPath(tail, _fill(s));
    c.drawPath(tail, _line);
    c.restore();
    // Fins.
    final fin = Path()
      ..moveTo(36, 36)
      ..quadraticBezierTo(46, 20, 58, 36)
      ..close();
    c.drawPath(fin, _fill(s));
    final body = Path()..addOval(r);
    c.drawPath(body, _patternPaint(p, s, r));
    _pattern(c, body, r, p, s);
    // Scales.
    for (var i = 0; i < 3; i++) {
      c.drawArc(
        Rect.fromCenter(center: Offset(52.0 + i * 6, 56), width: 8, height: 10),
        -math.pi / 2,
        math.pi,
        false,
        _line,
      );
    }
    c.drawPath(body, _line);
    const head = Offset(38, 54);
    if (species.extras.contains('barbels')) {
      final b = Paint()
        ..color = Color.lerp(p, Colors.black, 0.3)!
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      for (final side in [-1.0, 1.0]) {
        c.drawPath(
          Path()
            ..moveTo(r.left + 6, 60)
            ..quadraticBezierTo(
              r.left - 2,
              62 + side * 4,
              r.left - 6,
              70 + side * 3,
            ),
          b,
        );
      }
    }
    if (species.extras.contains('dorsal')) {
      for (final o in const [-3.0, 0.0, 3.0]) {
        c.drawLine(
          Offset(r.left + 14 + o, 62),
          Offset(r.left + 15 + o, 66),
          _line,
        );
      }
    }
    _face(c, t, head, 18, eyeY: -2, eyeGap: 7);
    return _Anchor(head, 18, 70, r);
  }

  _Anchor _turtle(Canvas c, double t, Color p, Color s) {
    final shell = Rect.fromCenter(
      center: const Offset(50, 70),
      width: 66,
      height: 44,
    );
    // Legs.
    for (final o in const [Offset(26, 86), Offset(74, 86)]) {
      c.drawOval(Rect.fromCenter(center: o, width: 14, height: 10), _fill(p));
    }
    final sp = Path()
      ..addArc(shell, math.pi, math.pi)
      ..close();
    final shellPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          shell,
          topLeft: const Radius.circular(33),
          topRight: const Radius.circular(33),
          bottomLeft: const Radius.circular(10),
          bottomRight: const Radius.circular(10),
        ),
      );
    c.drawPath(shellPath, _fill(s));
    // Hex plates.
    final plate = _fill(Color.lerp(s, Colors.white, 0.2)!);
    for (final o in const [
      Offset(50, 62),
      Offset(36, 72),
      Offset(64, 72),
      Offset(50, 80),
    ]) {
      final h = Path();
      for (var i = 0; i < 6; i++) {
        final a = i / 6 * _tau + math.pi / 6;
        final pt = o + Offset(math.cos(a) * 7, math.sin(a) * 6);
        i == 0 ? h.moveTo(pt.dx, pt.dy) : h.lineTo(pt.dx, pt.dy);
      }
      c.drawPath(h..close(), plate);
    }
    c.drawPath(shellPath, _line);
    sp.reset();
    const head = Offset(50, 46);
    c.drawCircle(head, 17, _fill(p));
    c.drawCircle(head, 17, _line);
    _face(c, t, head, 17, eyeY: 0, eyeGap: 7);
    return _Anchor(head, 17, 60, shell);
  }

  _Anchor _blob(Canvas c, double t, Color p, Color s, {required bool slime}) {
    final squish = math.sin(t * _tau) * (slime ? 2.5 : 1);
    final ex = species.extras;
    final path = Path();
    if (ex.contains('sheet')) {
      // A classic little sheet ghost: tall dome, wavy hem, stubby arms.
      path
        ..moveTo(32, 60)
        ..cubicTo(30, 16, 70, 16, 68, 60)
        ..quadraticBezierTo(80, 58 + squish, 76, 66)
        ..quadraticBezierTo(70, 66, 68, 64)
        ..lineTo(68, 86);
      for (var i = 0; i < 3; i++) {
        final x0 = 68 - i * 12.0;
        path
          ..quadraticBezierTo(
            x0 - 3,
            94 + (i.isEven ? squish : -squish) * 2,
            x0 - 6,
            86,
          )
          ..quadraticBezierTo(x0 - 9, 80, x0 - 12, 86);
      }
      path
        ..lineTo(32, 64)
        ..quadraticBezierTo(30, 66, 24, 66)
        ..quadraticBezierTo(20, 58 - squish, 32, 60)
        ..close();
    } else if (ex.contains('leaf')) {
      // A round moss puff with a crown of leaves and twig arms.
      final twig = Paint()
        ..color = const Color(0xFF8C6A4F)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      for (final side in [-1.0, 1.0]) {
        c.drawLine(
          Offset(50 + side * 24, 66),
          Offset(50 + side * 38, 56 + squish * 2),
          twig,
        );
        c.drawLine(
          Offset(50 + side * 33, 59),
          Offset(50 + side * 36, 52),
          twig,
        );
      }
      for (final a in const [-0.6, 0.0, 0.6]) {
        c.save();
        c.translate(50, 42);
        c.rotate(a + math.sin(t * _tau) * 0.05);
        final l = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(10, -12, 0, -24)
          ..quadraticBezierTo(-10, -12, 0, 0);
        c.drawPath(l, _fill(s));
        c.drawPath(l, _line);
        c.restore();
      }
      path.addOval(
        Rect.fromCircle(center: Offset(50, 66 + squish), radius: 24),
      );
    } else if (ex.contains('wisps')) {
      // A shadowy wisp: flickering flame-like top, soft base.
      path.moveTo(24, 84);
      const n = 7;
      for (var i = 0; i <= n; i++) {
        final x = 24 + i * 52 / n;
        final top = 30 + (i - n / 2).abs() * 5 + math.sin(t * _tau * 2 + i) * 3;
        path.lineTo(x, i.isEven ? top : top + 12);
      }
      path
        ..lineTo(76, 84)
        ..quadraticBezierTo(50, 94, 24, 84)
        ..close();
    } else if (slime) {
      path
        ..moveTo(50, 28 + squish)
        ..cubicTo(64, 30 + squish, 82, 60, 80, 78)
        ..cubicTo(78, 92, 22, 92, 20, 78)
        ..cubicTo(18, 60, 36, 30 + squish, 50, 28 + squish);
    } else {
      path
        ..moveTo(22, 54)
        ..cubicTo(22, 20, 78, 20, 78, 54)
        ..lineTo(78, 82);
      for (var i = 0; i < 4; i++) {
        final x0 = 78 - i * 14.0;
        path.quadraticBezierTo(
          x0 - 3.5,
          90 + (i.isEven ? squish : -squish) * 2,
          x0 - 7,
          82,
        );
        path.quadraticBezierTo(x0 - 10.5, 74, x0 - 14, 82);
      }
      path.close();
    }
    _glow(c, const Offset(50, 60), 50, p);
    final r = path.getBounds();
    c.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(p, Colors.white, 0.25)!,
            p,
            Color.lerp(p, s, 0.5)!,
          ],
        ).createShader(r),
    );
    _pattern(c, path, r, p, s);
    c.drawPath(path, _line);
    // Shine.
    c.drawOval(
      Rect.fromCenter(center: const Offset(36, 46), width: 9, height: 13),
      _fill(Colors.white.withValues(alpha: 0.55)),
    );
    if (ex.contains('wisps')) {
      // Tall glowing eyes instead of a face.
      for (final side in [-1.0, 1.0]) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(50 + side * 9, 58),
            width: 7,
            height: 13,
          ),
          _fill(s),
        );
      }
      _eyeCenter = const Offset(50, 58);
      _eyeGapPx = 9;
      return _Anchor(const Offset(50, 54), 22, 70, r);
    }
    final head = Offset(
      50,
      ex.contains('sheet') ? 46 : (ex.contains('leaf') ? 64 : 58),
    );
    _face(c, t, head, 22, eyeY: 2, eyeGap: 10);
    return _Anchor(
      Offset(50, slime ? 52 : (ex.contains('leaf') ? 60 : 48)),
      24,
      68,
      r,
    );
  }

  _Anchor _cloud(Canvas c, double t, Color p, Color s) {
    final puff = Path();
    for (final (o, r) in const [
      (Offset(32, 62), 16.0),
      (Offset(50, 50), 21.0),
      (Offset(68, 60), 17.0),
      (Offset(42, 72), 15.0),
      (Offset(60, 73), 15.0),
    ]) {
      puff.addOval(Rect.fromCircle(center: o, radius: r));
    }
    c.drawPath(puff, _fill(Color.lerp(p, s, 0.35)!));
    c.save();
    c.translate(0, -2);
    c.drawPath(puff, _fill(p));
    c.restore();
    _pattern(c, puff, puff.getBounds(), p, s);
    if (pose == CompanionPose.sleep || look.particles == 'none') {
      // Gentle rain only while sleeping.
      if (pose == CompanionPose.sleep) {
        for (var i = 0; i < 4; i++) {
          final y = 86 + ((t * 20 + i * 5) % 10);
          c.drawLine(
            Offset(38.0 + i * 8, y),
            Offset(37.0 + i * 8, y + 3),
            Paint()
              ..color = s
              ..strokeWidth = 1.4,
          );
        }
      }
    }
    const head = Offset(50, 60);
    _face(c, t, head, 22, eyeY: 0, eyeGap: 10);
    return _Anchor(const Offset(50, 50), 24, 74, puff.getBounds());
  }

  _Anchor _star(Canvas c, double t, Color p, Color s) {
    const center = Offset(50, 60);
    _glow(c, center, 50, p);
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? 36.0 : 17.0;
      final pt = center + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    final rounded = Paint()
      ..shader = RadialGradient(
        colors: [s, p],
      ).createShader(Rect.fromCircle(center: center, radius: 36))
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 8
      ..style = PaintingStyle.fill;
    c.drawPath(path, rounded);
    c.drawPath(
      path,
      Paint()
        ..color = p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round,
    );
    _face(c, t, const Offset(50, 62), 16, eyeY: -1, eyeGap: 7);
    return _Anchor(const Offset(50, 52), 18, 72, path.getBounds());
  }

  _Anchor _mushroom(Canvas c, double t, Color p, Color s) {
    final stem = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(50, 72), width: 36, height: 36),
      const Radius.circular(14),
    );
    c.drawRRect(stem, _fill(s));
    c.drawRRect(stem, _line);
    for (final x in [41.0, 59.0]) {
      c.drawOval(
        Rect.fromCenter(center: Offset(x, 90), width: 11, height: 7),
        _fill(Color.lerp(s, Colors.black, 0.1)!),
      );
    }
    final tilt = math.sin(t * _tau) * 0.04;
    c.save();
    c.translate(50, 48);
    c.rotate(tilt);
    final cap = Path()
      ..moveTo(-34, 6)
      ..cubicTo(-34, -30, 34, -30, 34, 6)
      ..quadraticBezierTo(0, 12, -34, 6)
      ..close();
    c.drawPath(cap, _fill(p));
    for (final o in const [
      Offset(-16, -8),
      Offset(10, -14),
      Offset(20, -2),
      Offset(-4, -2),
      Offset(-24, 0),
    ]) {
      c.drawCircle(o, 4, _fill(Colors.white.withValues(alpha: 0.9)));
    }
    c.drawPath(cap, _line);
    c.restore();
    const head = Offset(50, 72);
    _face(c, t, head, 15, eyeY: -2, eyeGap: 7);
    return const _Anchor(Offset(50, 34), 26, 60, Rect.fromLTWH(32, 54, 36, 36));
  }

  _Anchor _crystal(Canvas c, double t, Color p, Color s) {
    const center = Offset(50, 62);
    _glow(c, center, 50, p);
    final pts = const [
      Offset(50, 26),
      Offset(74, 46),
      Offset(68, 86),
      Offset(32, 86),
      Offset(26, 46),
    ];
    final gem = Path()..addPolygon(pts, true);
    c.drawPath(
      gem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s, p, Color.lerp(p, Colors.black, 0.15)!],
        ).createShader(gem.getBounds()),
    );
    final facet = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    c.drawLine(const Offset(50, 26), const Offset(50, 86), facet);
    c.drawLine(const Offset(26, 46), const Offset(74, 46), facet);
    c.drawLine(const Offset(50, 46), const Offset(32, 86), facet);
    c.drawLine(const Offset(50, 46), const Offset(68, 86), facet);
    final shimmer = (t * 2) % 1;
    c.drawCircle(
      Offset(30 + shimmer * 40, 40 + shimmer * 30),
      3,
      _fill(Colors.white.withValues(alpha: 0.6 * (1 - shimmer))),
    );
    c.drawPath(gem, _line);
    _face(c, t, const Offset(50, 62), 16, eyeY: 0, eyeGap: 8);
    return _Anchor(const Offset(50, 44), 20, 70, gem.getBounds());
  }

  _Anchor _flame(Canvas c, double t, Color p, Color s) {
    final flick = math.sin(t * _tau * 3) * 2.5;
    Path flame(double scale, double dy) => Path()
      ..moveTo(50 + flick * scale, 22 * scale + 6 + dy)
      ..cubicTo(74, 46 + dy, 80, 64 + dy, 72, 80 + dy)
      ..cubicTo(64, 94 + dy, 36, 94 + dy, 28, 80 + dy)
      ..cubicTo(20, 64 + dy, 30, 50 + dy, 40, 40 + dy)
      ..quadraticBezierTo(42, 52 + dy, 50 + flick * scale, 22 * scale + 6 + dy)
      ..close();
    _glow(c, const Offset(50, 64), 50, p);
    final outer = flame(1, 0);
    c.drawPath(outer, _fill(p));
    final inner = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(50, 72), width: 30, height: 30),
      );
    c.drawPath(inner, _fill(s));
    _face(c, t, const Offset(50, 68), 16, eyeY: 0, eyeGap: 8);
    return _Anchor(const Offset(50, 54), 20, 76, outer.getBounds());
  }

  // ── Parts ──────────────────────────────────────────────────────────────

  Paint _patternPaint(Color p, Color s, Rect r) {
    if (look.pattern == 'gradient') {
      return Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p, Color.lerp(p, s, 0.6)!],
        ).createShader(r);
    }
    return _fill(p);
  }

  void _pattern(Canvas c, Path clip, Rect r, Color p, Color s) {
    if (look.pattern == 'none' ||
        look.pattern == 'gradient' ||
        look.pattern == 'socks')
      return;
    c.save();
    c.clipPath(clip);
    final ink = _fill(
      Color.lerp(p, Colors.black, 0.28)!.withValues(alpha: 0.55),
    );
    switch (look.pattern) {
      case 'stripes':
        for (var x = r.left - 10; x < r.right; x += 9) {
          c.drawRect(Rect.fromLTWH(x, r.top, 3.5, r.height), ink);
        }
      case 'spots':
        final rnd = math.Random(species.id.hashCode);
        for (var i = 0; i < 9; i++) {
          c.drawCircle(
            Offset(
              r.left + rnd.nextDouble() * r.width,
              r.top + rnd.nextDouble() * r.height,
            ),
            2 + rnd.nextDouble() * 2.5,
            ink,
          );
        }
      case 'patches':
        c.drawOval(
          Rect.fromLTWH(
            r.left - 6,
            r.top + r.height * 0.1,
            r.width * 0.45,
            r.height * 0.55,
          ),
          _fill(s.withValues(alpha: 0.9)),
        );
        c.drawOval(
          Rect.fromLTWH(
            r.right - r.width * 0.35,
            r.bottom - r.height * 0.45,
            r.width * 0.4,
            r.height * 0.5,
          ),
          _fill(s.withValues(alpha: 0.9)),
        );
      case 'stars':
        final rnd = math.Random(7);
        for (var i = 0; i < 7; i++) {
          _tinyStar(
            c,
            Offset(
              r.left + rnd.nextDouble() * r.width,
              r.top + rnd.nextDouble() * r.height,
            ),
            2.4,
            _fill(const Color(0xFFFFF2B3)),
          );
        }
    }
    c.restore();
  }

  void _tinyStar(Canvas c, Offset o, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = o + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(path..close(), paint);
  }

  void _ears(
    Canvas c,
    double t,
    Offset head,
    double hr,
    Color p,
    Color s, {
    required bool behind,
  }) {
    final kind = look.earOf(species);
    final twitch = math.sin(t * _tau * 2 + 1) > 0.97 ? 0.15 : 0.0;
    final inner = _fill(Color.lerp(s, const Color(0xFFFFB3C7), 0.4)!);
    for (final side in [-1.0, 1.0]) {
      final base = head + Offset(side * hr * 0.6, -hr * 0.62);
      switch (kind) {
        case EarKind.pointy || EarKind.tall when behind:
          final h = kind == EarKind.tall ? 22.0 : 16.0;
          c.save();
          c.translate(base.dx, base.dy);
          c.rotate(side * (0.32 + (side > 0 ? twitch : 0)));
          final ear = Path()
            ..moveTo(-8, 6)
            ..quadraticBezierTo(-2, -h, 0, -h)
            ..quadraticBezierTo(2, -h, 8, 6)
            ..close();
          c.drawPath(ear, _fill(p));
          c.drawPath(
            Path()
              ..moveTo(-4.5, 4)
              ..lineTo(0, -h + 7)
              ..lineTo(4.5, 4)
              ..close(),
            inner,
          );
          c.drawPath(ear, _line);
          c.restore();
        case EarKind.long when behind:
          c.save();
          c.translate(base.dx - side * 3, base.dy);
          c.rotate(side * (0.18 + math.sin(t * _tau) * 0.04));
          final ear = RRect.fromRectAndRadius(
            const Rect.fromLTWH(-6, -30, 12, 34),
            const Radius.circular(6),
          );
          c.drawRRect(ear, _fill(p));
          c.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-3, -26, 6, 26),
              const Radius.circular(3),
            ),
            inner,
          );
          c.drawRRect(ear, _line);
          c.restore();
        case EarKind.round when behind:
          c.drawCircle(base, 8, _fill(p));
          c.drawCircle(base, 4.5, inner);
          c.drawCircle(base, 8, _line);
        case EarKind.tiny when behind:
          c.drawCircle(base + Offset(side * 2, 3), 5, _fill(p));
          c.drawCircle(base + Offset(side * 2, 3), 5, _line);
        case EarKind.floppy when !behind:
          c.save();
          c.translate(head.dx + side * hr * 0.85, head.dy - hr * 0.45);
          c.rotate(side * (0.25 + math.sin(t * _tau) * 0.05));
          final ear = RRect.fromRectAndRadius(
            const Rect.fromLTWH(-6, -2, 12, 24),
            const Radius.circular(7),
          );
          c.drawRRect(ear, _fill(Color.lerp(p, Colors.black, 0.18)!));
          c.drawRRect(ear, _line);
          c.restore();
        case EarKind.antler when behind:
          final paint = Paint()
            ..color = const Color(0xFF8A6A4A)
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          final top = base + Offset(side * 6, -16);
          c.drawLine(base, top, paint);
          c.drawLine(
            base + Offset(side * 3, -8),
            base + Offset(side * 11, -11),
            paint,
          );
          c.drawLine(top, top + Offset(side * 5, -3), paint);
          c.drawOval(
            Rect.fromCenter(
              center: base + Offset(side * 8, 4),
              width: 10,
              height: 6,
            ),
            _fill(p),
          );
        case EarKind.tuft when !behind:
          final tuft = Path()
            ..moveTo(base.dx - side * 2, base.dy + 6)
            ..lineTo(base.dx + side * 7, base.dy - 8)
            ..lineTo(base.dx + side * 5, base.dy + 6)
            ..close();
          c.drawPath(tuft, _fill(Color.lerp(p, Colors.black, 0.15)!));
        case EarKind.fin when behind:
          final fin = Path()
            ..moveTo(base.dx, base.dy + 6)
            ..lineTo(base.dx + side * 12, base.dy - 4)
            ..lineTo(base.dx + side * 4, base.dy + 10)
            ..close();
          c.drawPath(fin, _fill(s));
          c.drawPath(fin, _line);
        default:
          break;
      }
    }
  }

  void _tail(Canvas c, double t, Offset base, Color p, Color s) {
    final kind = look.tailOf(species);
    final wag =
        math.sin(t * _tau * 2) *
        (pose == CompanionPose.play || pose == CompanionPose.hop ? 0.45 : 0.18);
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(wag);
    switch (kind) {
      case TailKind.fluffy || TailKind.bushy:
        final big = kind == TailKind.bushy;
        final tail = Path()
          ..moveTo(0, 0)
          ..cubicTo(
            big ? 22 : 14,
            -4,
            big ? 26 : 18,
            big ? -34 : -22,
            big ? 12 : 8,
            big ? -40 : -28,
          )
          ..cubicTo(big ? 4 : 2, big ? -26 : -18, -2, -10, 0, 0);
        c.drawPath(tail, _fill(p));
        final tip = Path()
          ..moveTo(big ? 8 : 5, big ? -30 : -20)
          ..quadraticBezierTo(
            big ? 18 : 12,
            big ? -36 : -24,
            big ? 12 : 8,
            big ? -40 : -28,
          )
          ..quadraticBezierTo(
            big ? 4 : 3,
            big ? -38 : -26,
            big ? 8 : 5,
            big ? -30 : -20,
          );
        c.drawPath(tip, _fill(s));
        c.drawPath(tail, _line);
      case TailKind.thin:
        final tail = Path()
          ..moveTo(0, 0)
          ..cubicTo(16, 2, 22, -18, 14, -26);
        c.drawPath(
          tail,
          Paint()
            ..color = p
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      case TailKind.curl:
        c.drawArc(
          const Rect.fromLTWH(-2, -18, 16, 16),
          math.pi * 0.6,
          math.pi * 1.6,
          false,
          Paint()
            ..color = p
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      case TailKind.ringed:
        final tail = Path()
          ..moveTo(0, 0)
          ..cubicTo(18, -2, 22, -24, 12, -34)
          ..cubicTo(4, -26, -2, -10, 0, 0);
        c.drawPath(tail, _fill(p));
        c.save();
        c.clipPath(tail);
        for (var y = -30.0; y < 0; y += 8) {
          c.drawRect(
            Rect.fromLTWH(-5, y, 30, 3.5),
            _fill(Color.lerp(p, Colors.black, 0.45)!),
          );
        }
        c.restore();
        c.drawPath(tail, _line);
      case TailKind.puff:
        c.drawCircle(const Offset(4, -2), 7, _fill(Colors.white));
        c.drawCircle(const Offset(4, -2), 7, _line);
      case TailKind.flat:
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2, -6, 26, 9),
            const Radius.circular(5),
          ),
          _fill(Color.lerp(p, Colors.black, 0.15)!),
        );
      case TailKind.feather:
        for (final (a, col) in [
          (-0.3, p),
          (0.0, s),
          (0.3, look.bellyOf(species)),
        ]) {
          c.save();
          c.rotate(a);
          c.drawOval(const Rect.fromLTWH(-4, -2, 8, 20), _fill(col));
          c.restore();
        }
      case TailKind.flame:
        for (final (i, col) in [(0, p), (1, s)]) {
          final f = Path()
            ..moveTo(-6.0 + i * 3, 0)
            ..quadraticBezierTo(
              -10,
              18 - i * 4,
              0,
              24 - i * 6 + math.sin(t * _tau * 3) * 2,
            )
            ..quadraticBezierTo(10, 18 - i * 4, 6.0 - i * 3, 0)
            ..close();
          c.drawPath(f, _fill(col));
        }
      case TailKind.stub:
        c.drawCircle(const Offset(2, -2), 4.5, _fill(p));
      case TailKind.fish || TailKind.none:
        break;
    }
    c.restore();
  }

  void _wings(
    Canvas c,
    double t,
    Offset center,
    Color p,
    Color s,
    double span,
  ) {
    final flap =
        math.sin(t * _tau * (pose == CompanionPose.play ? 3 : 1)) * 0.15;
    for (final side in [-1.0, 1.0]) {
      c.save();
      c.translate(center.dx + side * 14, center.dy - 8);
      c.rotate(side * (0.5 + flap));
      final wing = Path()
        ..moveTo(0, 0)
        ..cubicTo(
          side * span * 0.5,
          -span * 0.7,
          side * span,
          -span * 0.2,
          side * span * 0.9,
          span * 0.25,
        )
        ..quadraticBezierTo(
          side * span * 0.55,
          span * 0.05,
          side * span * 0.45,
          span * 0.35,
        )
        ..quadraticBezierTo(side * span * 0.25, span * 0.05, 0, 0)
        ..close();
      c.drawPath(wing, _fill(Color.lerp(s, p, 0.3)!.withValues(alpha: 0.95)));
      c.drawPath(wing, _line);
      c.restore();
    }
  }

  void _horns(Canvas c, Offset head, double hr, String kind, Color s) {
    final horn = _fill(Color.lerp(s, const Color(0xFFF5E6C8), 0.5)!);
    switch (kind) {
      case 'nubs':
        for (final side in [-1.0, 1.0]) {
          c.drawCircle(head + Offset(side * 8, -hr * 0.85), 3.6, horn);
        }
      case 'unicorn':
        final h = Path()
          ..moveTo(head.dx - 4, head.dy - hr * 0.8)
          ..lineTo(head.dx, head.dy - hr * 0.8 - 18)
          ..lineTo(head.dx + 4, head.dy - hr * 0.8)
          ..close();
        c.drawPath(h, _fill(const Color(0xFFFFE08A)));
        c.drawPath(h, _line);
      case 'antennae':
        final paint = Paint()
          ..color = const Color(0xFF3A3A44)
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke;
        for (final side in [-1.0, 1.0]) {
          final tip = head + Offset(side * 12, -hr - 14);
          c.drawLine(head + Offset(side * 5, -hr * 0.8), tip, paint);
          c.drawCircle(tip, 3, _fill(Color(look.accent)));
        }
      default:
        for (final side in [-1.0, 1.0]) {
          final h = Path()
            ..moveTo(head.dx + side * 5, head.dy - hr * 0.75)
            ..quadraticBezierTo(
              head.dx + side * 10,
              head.dy - hr - 14,
              head.dx + side * 17,
              head.dy - hr - 10,
            )
            ..quadraticBezierTo(
              head.dx + side * 12,
              head.dy - hr - 4,
              head.dx + side * 12,
              head.dy - hr * 0.7,
            )
            ..close();
          c.drawPath(h, horn);
          c.drawPath(h, _line);
        }
    }
  }

  void _face(
    Canvas c,
    double t,
    Offset head,
    double hr, {
    bool beak = false,
    double eyeY = 0,
    double eyeGap = 9,
    bool owl = false,
  }) {
    final expr = _expr;
    final blink = t > 0.9 && t < 0.935;
    final eyeColor = Color(look.eye);
    final ink = Paint()
      ..color = eyeColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final scale = hr / 23;
    _eyeCenter = head + Offset(0, eyeY * scale);
    _eyeGapPx = eyeGap * scale;
    for (final side in [-1.0, 1.0]) {
      final e = head + Offset(side * eyeGap * scale, eyeY * scale);
      if (!blink && _customEye(c, expr, e, side, scale, eyeColor, ink))
        continue;
      if (owl)
        c.drawCircle(e, 7 * scale, _fill(Colors.white.withValues(alpha: 0.9)));
      final closed = blink || expr == 'sleepy' || (expr == 'wink' && side > 0);
      if (closed) {
        c.drawArc(
          Rect.fromCenter(center: e, width: 7 * scale, height: 5 * scale),
          0.15,
          math.pi - 0.3,
          false,
          ink,
        );
      } else if (expr == 'happy' || expr == 'excited') {
        c.drawArc(
          Rect.fromCenter(
            center: e.translate(0, 1.5 * scale),
            width: 7 * scale,
            height: 6 * scale,
          ),
          math.pi + 0.2,
          math.pi - 0.4,
          false,
          ink,
        );
      } else if (expr == 'smug') {
        c.drawLine(e.translate(-3 * scale, 0), e.translate(3 * scale, 0), ink);
      } else {
        final r = (expr == 'surprised' ? 4.2 : 3.4) * scale;
        if (species.mask) c.drawCircle(e, r + 1.6 * scale, _fill(Colors.white));
        c.drawCircle(e, r, _fill(eyeColor));
        c.drawCircle(
          e.translate(-1.1 * scale, -1.2 * scale),
          r * 0.38,
          _fill(Colors.white),
        );
        if (expr == 'blush' || expr == 'content')
          c.drawCircle(
            e.translate(1 * scale, 1 * scale),
            r * 0.18,
            _fill(Colors.white),
          );
      }
    }
    // Markings.
    final m = look.marking;
    final cheek = _fill(
      const Color(0xFFFF8FAB).withValues(alpha: expr == 'blush' ? 0.75 : 0.45),
    );
    if (m == 'cheeks' || expr == 'blush') {
      for (final side in [-1.0, 1.0]) {
        c.drawOval(
          Rect.fromCenter(
            center:
                head + Offset(side * (eyeGap + 5) * scale, (eyeY + 6) * scale),
            width: 6 * scale,
            height: 3.6 * scale,
          ),
          cheek,
        );
      }
    } else if (m == 'freckles') {
      for (final side in [-1.0, 1.0]) {
        for (final o in const [Offset(0, 0), Offset(2.5, 1.5), Offset(-2, 2)]) {
          c.drawCircle(
            head +
                Offset(side * (eyeGap + 4) * scale, (eyeY + 6) * scale) +
                o * scale,
            0.7 * scale,
            _fill(const Color(0x88553322)),
          );
        }
      }
    } else if (m == 'star') {
      _tinyStar(
        c,
        head + Offset(0, -hr * 0.55),
        3.5 * scale,
        _fill(const Color(0xFFFFD866)),
      );
    } else if (m == 'heart') {
      _heart(
        c,
        head + Offset(0, -hr * 0.55),
        3.2 * scale,
        _fill(const Color(0xFFFF7FA0)),
      );
    } else if (m == 'gem') {
      c.drawPath(
        Path()..addPolygon([
          head + Offset(0, -hr * 0.68),
          head + Offset(3, -hr * 0.52),
          head + Offset(0, -hr * 0.38),
          head + Offset(-3, -hr * 0.52),
        ], true),
        _fill(Color(look.accent)),
      );
    }
    // Nose / beak / mouth.
    final mouthY = (eyeY + 6.5) * scale;
    if (beak) {
      final b = Path()
        ..moveTo(head.dx - 3.5 * scale, head.dy + mouthY - 2.5 * scale)
        ..lineTo(head.dx + 3.5 * scale, head.dy + mouthY - 2.5 * scale)
        ..lineTo(head.dx, head.dy + mouthY + 3 * scale)
        ..close();
      c.drawPath(b, _fill(const Color(0xFFFFA94D)));
    } else {
      c.drawOval(
        Rect.fromCenter(
          center: head + Offset(0, mouthY - 2 * scale),
          width: 3.4 * scale,
          height: 2.4 * scale,
        ),
        _fill(const Color(0xFF4A3A3A)),
      );
      final mouth = Paint()
        ..color = const Color(0xFF4A3A3A)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (_customMouth(c, expr, head, mouthY, scale, mouth)) return;
      if (expr == 'surprised' || expr == 'excited') {
        c.drawOval(
          Rect.fromCenter(
            center: head + Offset(0, mouthY + 2 * scale),
            width: 3.5 * scale,
            height: 4 * scale,
          ),
          _fill(const Color(0xFF7A3A44)),
        );
      } else {
        c.drawArc(
          Rect.fromCenter(
            center: head + Offset(-1.6 * scale, mouthY),
            width: 3.2 * scale,
            height: 2.8 * scale,
          ),
          0,
          math.pi,
          false,
          mouth,
        );
        c.drawArc(
          Rect.fromCenter(
            center: head + Offset(1.6 * scale, mouthY),
            width: 3.2 * scale,
            height: 2.8 * scale,
          ),
          0,
          math.pi,
          false,
          mouth,
        );
      }
    }
  }

  /// Moves the whole companion (body, face and accessories together) for
  /// the current emotion and pose, so worn things stay put.
  void _motion(Canvas c, double t, EmotionMotion mo, double k) {
    final a = t * _tau;
    void around(Offset o, void Function() f) {
      c.translate(o.dx, o.dy);
      f();
      c.translate(-o.dx, -o.dy);
    }

    // Emotion.
    final shake =
        math.sin(a * 12) * 1.4 * mo.shake * k +
        (pose == CompanionPose.shiver ? math.sin(a * 16) * 1.6 * k : 0);
    if (shake != 0) c.translate(shake, 0);
    if (mo.droop > 0) {
      c.translate(0, 4 * mo.droop * k);
      around(const Offset(50, 94), () => c.scale(1, 1 - 0.05 * mo.droop * k));
    }
    final tilt = mo.tilt * k + math.sin(a) * 0.07 * mo.sway * k;
    if (tilt != 0) around(const Offset(50, 80), () => c.rotate(tilt));
    if (mo.stretch > 0) {
      final st = 0.06 * mo.stretch * k * math.sin(a * 2);
      around(const Offset(50, 94), () => c.scale(1 - st * 0.6, 1 + st));
    }
    // Pose.
    switch (pose) {
      case CompanionPose.dance:
        around(
          const Offset(50, 90),
          () => c.rotate(math.sin(a * 2) * 0.22 * k),
        );
      case CompanionPose.stretch:
        final st = (0.5 - 0.5 * math.cos(a)) * 0.12 * k;
        around(const Offset(50, 94), () => c.scale(1 - st * 0.4, 1 + st));
      case CompanionPose.spin:
        final sx = math.cos(a);
        around(
          const Offset(50, 60),
          () => c.scale(sx.abs() < 0.08 ? 0.08 * sx.sign : sx, 1),
        );
      case CompanionPose.peek:
        c.translate(0, (0.5 + 0.5 * math.cos(a)) * 22 * k);
      case CompanionPose.nod:
        around(
          const Offset(50, 70),
          () => c.rotate(math.sin(a * 3).clamp(0.0, 1.0) * 0.1 * k),
        );
      case CompanionPose.celebrate:
        around(const Offset(50, 90), () => c.rotate(math.sin(a * 2) * 0.1 * k));
      default:
        break;
    }
  }

  // ── Extra emotions ─────────────────────────────────────────────────────

  void _brow(
    Canvas c,
    Offset e,
    double side,
    double scale,
    double angle, {
    double lift = 0,
  }) {
    final p = Paint()
      ..color = const Color(0xFF4A3A3A)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final mid = e.translate(0, (-5.6 - lift) * scale);
    final d = Offset(math.cos(angle), math.sin(angle) * side) * 2.8 * scale;
    c.drawLine(mid - d, mid + d, p);
  }

  /// Eyes for the emotions the original faces don't cover. Returns true
  /// when it drew this eye.
  bool _customEye(
    Canvas c,
    String expr,
    Offset e,
    double side,
    double scale,
    Color eyeColor,
    Paint ink,
  ) {
    switch (expr) {
      case 'sad':
        c.drawCircle(e.translate(0, 0.6 * scale), 3.1 * scale, _fill(eyeColor));
        c.drawCircle(
          e.translate(-0.9 * scale, -0.6 * scale),
          1.1 * scale,
          _fill(Colors.white),
        );
        _brow(c, e, side, scale, 0.45 * side * -1);
        return true;
      case 'grumpy':
        c.drawCircle(e, 3.2 * scale, _fill(eyeColor));
        // Heavy lid across the top half.
        c.drawRect(
          Rect.fromCenter(
            center: e.translate(0, -1.9 * scale),
            width: 8 * scale,
            height: 3.8 * scale,
          ),
          _fill(look.primaryOf(species)),
        );
        _brow(c, e, side, scale, -0.55 * side * -1, lift: -1.5);
        return true;
      case 'scared':
        c.drawCircle(e, 4.6 * scale, _fill(Colors.white));
        c.drawCircle(e, 4.6 * scale, ink..strokeWidth = 1);
        c.drawCircle(e, 1.5 * scale, _fill(eyeColor));
        _brow(c, e, side, scale, 0.35 * side * -1, lift: 1.5);
        return true;
      case 'loving':
        _heart(
          c,
          e.translate(0, 0.8 * scale),
          2.6 * scale,
          _fill(const Color(0xFFFF4F7B)),
        );
        return true;
      case 'curious':
        final big = side > 0;
        c.drawCircle(e, (big ? 4.2 : 3.0) * scale, _fill(eyeColor));
        c.drawCircle(
          e.translate(-1 * scale, -1.1 * scale),
          (big ? 1.6 : 1.1) * scale,
          _fill(Colors.white),
        );
        if (big) _brow(c, e, side, scale, -0.25, lift: 2);
        return true;
      case 'proud':
        c.drawArc(
          Rect.fromCenter(
            center: e.translate(0, 1.4 * scale),
            width: 7 * scale,
            height: 5.4 * scale,
          ),
          math.pi + 0.25,
          math.pi - 0.5,
          false,
          ink,
        );
        return true;
      case 'bored':
        c.drawCircle(e.translate(0, 0.8 * scale), 2.8 * scale, _fill(eyeColor));
        c.drawRect(
          Rect.fromCenter(
            center: e.translate(0, -1.4 * scale),
            width: 7.4 * scale,
            height: 3.6 * scale,
          ),
          _fill(look.primaryOf(species)),
        );
        c.drawLine(
          e.translate(-3.4 * scale, 0.4 * scale),
          e.translate(3.4 * scale, 0.4 * scale),
          ink..strokeWidth = 1.2,
        );
        return true;
      case 'silly':
        if (side < 0) {
          c.drawLine(
            e.translate(-3 * scale, -1.5 * scale),
            e.translate(2.5 * scale, 0),
            ink,
          );
          c.drawLine(
            e.translate(-3 * scale, 1.5 * scale),
            e.translate(2.5 * scale, 0),
            ink,
          );
        } else {
          c.drawCircle(e, 4 * scale, _fill(eyeColor));
          c.drawCircle(
            e.translate(1.2 * scale, -1.2 * scale),
            1.5 * scale,
            _fill(Colors.white),
          );
        }
        return true;
    }
    return false;
  }

  /// Mouths for the extra emotions. Returns true when it drew one.
  bool _customMouth(
    Canvas c,
    String expr,
    Offset head,
    double mouthY,
    double scale,
    Paint mouth,
  ) {
    Rect at(double w, double h, [double dy = 0]) => Rect.fromCenter(
      center: head + Offset(0, mouthY + dy * scale),
      width: w * scale,
      height: h * scale,
    );
    switch (expr) {
      case 'sad' || 'grumpy':
        c.drawArc(at(6, 4, 2), math.pi + 0.3, math.pi - 0.6, false, mouth);
        return true;
      case 'scared':
        final p = Path()
          ..moveTo(head.dx - 3.5 * scale, head.dy + mouthY + 1.5 * scale);
        for (var k = 1; k <= 4; k++) {
          p.lineTo(
            head.dx - 3.5 * scale + k * 1.75 * scale,
            head.dy + mouthY + (k.isOdd ? 0.4 : 1.6) * scale,
          );
        }
        c.drawPath(p, mouth);
        return true;
      case 'loving' || 'proud':
        c.drawArc(
          at(7, 5),
          0.15,
          math.pi - 0.3,
          false,
          mouth..strokeWidth = 1.4,
        );
        return true;
      case 'curious':
        c.drawOval(at(2.4, 2.4, 1.2), _fill(const Color(0xFF7A3A44)));
        return true;
      case 'bored':
        c.drawLine(
          head + Offset(-2.6 * scale, mouthY + 1 * scale),
          head + Offset(2.6 * scale, mouthY + 1 * scale),
          mouth,
        );
        return true;
      case 'silly':
        c.drawArc(at(7, 5), 0.1, math.pi - 0.2, false, mouth);
        c.drawOval(at(3, 3.6, 2.6), _fill(const Color(0xFFFF7A95)));
        return true;
    }
    return false;
  }

  /// Small effects that go with an emotion, drawn in the same moving frame
  /// as the body so they stay attached.
  void _emote(Canvas c, Emote e, Offset head, double hr, double t) {
    final s = hr / 23;
    switch (e) {
      case Emote.none || Emote.zzz:
        break;
      case Emote.tears:
        final eyes = _eyeCenter ?? head;
        final gap = _eyeGapPx ?? 9 * s;
        for (final side in [-1.0, 1.0]) {
          final ph = (t * 2 + (side > 0 ? 0.5 : 0)) % 1;
          final p = eyes + Offset(side * gap, 3 * s + ph * 9 * s);
          final drop = Path()
            ..moveTo(p.dx, p.dy - 2.2 * s)
            ..quadraticBezierTo(
              p.dx + 1.8 * s,
              p.dy + 0.6 * s,
              p.dx,
              p.dy + 1.6 * s,
            )
            ..quadraticBezierTo(
              p.dx - 1.8 * s,
              p.dy + 0.6 * s,
              p.dx,
              p.dy - 2.2 * s,
            );
          c.drawPath(
            drop,
            _fill(const Color(0xFF7CC4F2).withValues(alpha: 1 - ph * 0.7)),
          );
        }
      case Emote.sweat:
        final p = head + Offset(hr * 0.75, -hr * 0.45 + math.sin(t * _tau) * s);
        final drop = Path()
          ..moveTo(p.dx, p.dy - 3.5 * s)
          ..quadraticBezierTo(
            p.dx + 2.6 * s,
            p.dy + 0.8 * s,
            p.dx,
            p.dy + 2.2 * s,
          )
          ..quadraticBezierTo(
            p.dx - 2.6 * s,
            p.dy + 0.8 * s,
            p.dx,
            p.dy - 3.5 * s,
          );
        c.drawPath(drop, _fill(const Color(0xFF9AD8FF)));
      case Emote.steam:
        for (var i = 0; i < 2; i++) {
          final ph = (t * 1.5 + i * 0.5) % 1;
          final side = i.isEven ? -1.0 : 1.0;
          c.drawCircle(
            head + Offset(side * hr * 0.55, -hr * 1.0 - ph * 10 * s),
            (2 + ph * 3) * s,
            _fill(const Color(0xFFB8B8C0).withValues(alpha: (1 - ph) * 0.8)),
          );
        }
      case Emote.hearts:
        for (var i = 0; i < 3; i++) {
          final ph = (t + i / 3) % 1;
          _heart(
            c,
            head +
                Offset(
                  (i - 1) * hr * 0.6 + math.sin(ph * _tau) * 2,
                  -hr * 0.9 - ph * 14 * s,
                ),
            (1.8 + ph) * s,
            _fill(const Color(0xFFFF6B95).withValues(alpha: 1 - ph)),
          );
        }
      case Emote.question || Emote.exclaim:
        final tp = TextPainter(
          text: TextSpan(
            text: e == Emote.question ? '?' : '!',
            style: TextStyle(
              fontSize: 13 * s,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF5A5A7A),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          c,
          head +
              Offset(hr * 0.75, -hr * 1.25 + math.sin(t * _tau * 2) * 1.5 * s),
        );
      case Emote.sparkles:
        for (var i = 0; i < 4; i++) {
          final a = i * _tau / 4 + t * _tau * 0.5;
          final tw = 0.5 + 0.5 * math.sin(t * _tau * 2 + i);
          _tinyStar(
            c,
            head +
                Offset(
                  math.cos(a) * hr * 1.25,
                  math.sin(a) * hr * 0.9 - hr * 0.3,
                ),
            (1.2 + tw * 1.6) * s,
            _fill(const Color(0xFFFFE066).withValues(alpha: tw)),
          );
        }
      case Emote.swirl:
        final ctr = head + Offset(0, -hr * 1.15);
        final p = Path();
        for (var k = 0; k <= 24; k++) {
          final a = k / 24 * _tau * 1.6 + t * _tau;
          final r = k / 24 * 4 * s;
          final pt = ctr + Offset(math.cos(a) * r, math.sin(a) * r);
          k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        c.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFFB58CFF),
        );
    }
  }

  /// How the habitat's weather touches the companion: an umbrella in the
  /// rain, misty breath in the snow. Drawn in the body's frame.
  void _weatherProps(Canvas c, Offset head, double hr, double t) {
    final s = hr / 23;
    switch (weather) {
      case 'rain':
        final top = head + Offset(hr * 0.15, -hr * 1.35);
        final canopy = Path()
          ..moveTo(top.dx - hr * 1.3, top.dy + hr * 0.35)
          ..quadraticBezierTo(
            top.dx,
            top.dy - hr * 0.75,
            top.dx + hr * 1.3,
            top.dy + hr * 0.35,
          );
        for (var k = 4; k >= 0; k--) {
          canopy.quadraticBezierTo(
            top.dx - hr * 1.3 + hr * 2.6 * (k + 0.5) / 5,
            top.dy + hr * 0.15,
            top.dx - hr * 1.3 + hr * 2.6 * k / 5,
            top.dy + hr * 0.35,
          );
        }
        canopy.close();
        c.drawPath(canopy, _fill(Color(look.accent)));
        c.drawLine(
          top,
          top + Offset(0, hr * 1.5),
          Paint()
            ..color = const Color(0xFF4A3A3A)
            ..strokeWidth = 1.2 * s,
        );
      case 'snow':
        final ph = t % 1;
        c.drawCircle(
          head + Offset(hr * 0.35 + ph * 4 * s, hr * 0.35 - ph * 3 * s),
          (1.5 + ph * 2.2) * s,
          _fill(Colors.white.withValues(alpha: (1 - ph) * 0.8)),
        );
    }
  }

  void _heart(Canvas c, Offset o, double r, Paint paint) {
    final p = Path()
      ..moveTo(o.dx, o.dy + r)
      ..cubicTo(
        o.dx - r * 2,
        o.dy - r * 0.2,
        o.dx - r * 0.8,
        o.dy - r * 1.6,
        o.dx,
        o.dy - r * 0.5,
      )
      ..cubicTo(
        o.dx + r * 0.8,
        o.dy - r * 1.6,
        o.dx + r * 2,
        o.dy - r * 0.2,
        o.dx,
        o.dy + r,
      )
      ..close();
    c.drawPath(p, paint);
  }

  void _book(Canvas c) {
    final b = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(50, 74), width: 26, height: 16),
      const Radius.circular(2),
    );
    c.drawRRect(b, _fill(Color(look.accent)));
    c.drawLine(
      const Offset(50, 66),
      const Offset(50, 82),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.2,
    );
  }

  void _treat(Canvas c) {
    c.drawCircle(const Offset(50, 72), 6, _fill(const Color(0xFFE8B270)));
    c.drawCircle(const Offset(48, 70), 1.4, _fill(const Color(0xFF6B3E22)));
    c.drawCircle(const Offset(52.5, 73), 1.2, _fill(const Color(0xFF6B3E22)));
  }

  void _zzz(Canvas c, double t) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 3; i++) {
      final ph = (t + i / 3) % 1;
      tp.text = TextSpan(
        text: 'z',
        style: TextStyle(
          fontSize: 7 + i * 2.5,
          color: const Color(0xFF8A8FB0).withValues(alpha: 1 - ph),
          fontWeight: FontWeight.w700,
        ),
      );
      tp.layout();
      tp.paint(c, Offset(70 + ph * 10, 22 - ph * 16 - i * 2));
    }
  }

  void _notes(Canvas c, double t) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 2; i++) {
      final ph = (t + i / 2) % 1;
      tp.text = TextSpan(
        text: i.isEven ? '♪' : '♫',
        style: TextStyle(
          fontSize: 10,
          color: Color(look.accent).withValues(alpha: 1 - ph),
        ),
      );
      tp.layout();
      tp.paint(c, Offset(18 + i * 60 + math.sin(ph * _tau) * 4, 30 - ph * 20));
    }
  }

  // ── Accessories ────────────────────────────────────────────────────────

  void _accessories(Canvas c, _Anchor a, double t) {
    final accent = Color(look.accent);
    final dark = Color.lerp(accent, Colors.black, 0.25)!;
    final top = a.head.translate(0, -a.headR * 0.78);
    final ny = a.neckY;
    // Glasses.
    final eyes = _eyeCenter ?? a.head.translate(0, a.headR * 0.05);
    final gap = _eyeGapPx ?? 9 * a.headR / 23;
    final frame = Paint()
      ..color = const Color(0xFF2E2E36)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final slots = <String, void Function()>{
      'body': () {
        // Body wear first (under the neck piece).
        switch (look.body) {
          case 'sweater' || 'hoodie' || 'raincoat' || 'overalls':
            final r = a.bodyRect.deflate(2);
            final rr = RRect.fromRectAndRadius(
              Rect.fromLTRB(r.left, a.neckY, r.right, r.bottom - 4),
              const Radius.circular(14),
            );
            final col = look.body == 'raincoat'
                ? const Color(0xFFFFD34E)
                : (look.body == 'overalls' ? const Color(0xFF5A7FBF) : accent);
            c.drawRRect(rr, _fill(col));
            if (look.body == 'sweater') {
              for (var y = rr.top + 6; y < rr.bottom - 2; y += 6) {
                c.drawLine(
                  Offset(rr.left + 4, y),
                  Offset(rr.right - 4, y),
                  Paint()
                    ..color = dark.withValues(alpha: 0.5)
                    ..strokeWidth = 1,
                );
              }
            } else if (look.body == 'hoodie') {
              c.drawArc(
                Rect.fromCenter(
                  center: Offset(a.head.dx, a.neckY + 2),
                  width: 30,
                  height: 12,
                ),
                0,
                math.pi,
                false,
                Paint()
                  ..color = dark
                  ..strokeWidth = 2
                  ..style = PaintingStyle.stroke,
              );
            } else if (look.body == 'overalls') {
              c.drawCircle(
                Offset(rr.left + 9, rr.top + 6),
                1.6,
                _fill(const Color(0xFFFFD34E)),
              );
              c.drawCircle(
                Offset(rr.right - 9, rr.top + 6),
                1.6,
                _fill(const Color(0xFFFFD34E)),
              );
            }
            c.drawRRect(rr, _line);
          case 'cape':
            final cape = Path()
              ..moveTo(a.head.dx - 14, a.neckY)
              ..quadraticBezierTo(
                a.head.dx - 30,
                a.bodyRect.bottom,
                a.head.dx - 22,
                a.bodyRect.bottom + 2,
              )
              ..lineTo(a.head.dx + 22, a.bodyRect.bottom + 2)
              ..quadraticBezierTo(
                a.head.dx + 30,
                a.bodyRect.bottom,
                a.head.dx + 14,
                a.neckY,
              )
              ..close();
            c.drawPath(cape, _fill(accent.withValues(alpha: 0.9)));
        }
      },
      'neck': () {
        switch (look.neck) {
          case 'scarf':
            final s = RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(a.head.dx, ny),
                width: a.headR * 1.7,
                height: 7,
              ),
              const Radius.circular(4),
            );
            c.drawRRect(s, _fill(accent));
            final tail = RRect.fromRectAndRadius(
              Rect.fromLTWH(
                a.head.dx + 6,
                ny,
                6,
                14 + math.sin(t * _tau) * 1.5,
              ),
              const Radius.circular(3),
            );
            c.drawRRect(tail, _fill(dark));
          case 'bow':
            final o = Offset(a.head.dx, ny);
            for (final side in [-1.0, 1.0]) {
              c.drawPath(
                Path()
                  ..moveTo(o.dx, o.dy)
                  ..lineTo(o.dx + side * 9, o.dy - 5)
                  ..lineTo(o.dx + side * 9, o.dy + 5)
                  ..close(),
                _fill(accent),
              );
            }
            c.drawCircle(o, 2.6, _fill(dark));
          case 'collar':
            c.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset(a.head.dx, ny),
                  width: a.headR * 1.5,
                  height: 4.5,
                ),
                const Radius.circular(3),
              ),
              _fill(accent),
            );
            c.drawCircle(
              Offset(a.head.dx, ny + 4),
              3,
              _fill(const Color(0xFFFFD34E)),
            );
            c.drawCircle(Offset(a.head.dx, ny + 4), 3, _line);
          case 'bandana':
            c.drawPath(
              Path()
                ..moveTo(a.head.dx - a.headR * 0.8, ny - 2)
                ..lineTo(a.head.dx + a.headR * 0.8, ny - 2)
                ..lineTo(a.head.dx, ny + 10)
                ..close(),
              _fill(accent),
            );
            for (final o in const [Offset(-4, 1), Offset(3, 2), Offset(0, 5)]) {
              c.drawCircle(Offset(a.head.dx, ny) + o, 0.9, _fill(Colors.white));
            }
          case 'pearls':
            for (var i = -3; i <= 3; i++) {
              c.drawCircle(
                Offset(a.head.dx + i * 4.2, ny + (i.abs() < 2 ? 1.5 : 0)),
                2,
                _fill(const Color(0xFFFFF8F0)),
              );
            }
        }
      },
      'glasses': () {
        switch (look.glasses) {
          case 'round':
            for (final side in [-1.0, 1.0]) {
              c.drawCircle(eyes + Offset(side * gap, 0), 5.5, frame);
            }
            c.drawLine(
              eyes + Offset(-gap + 5.5, 0),
              eyes + Offset(gap - 5.5, 0),
              frame,
            );
          case 'star':
            for (final side in [-1.0, 1.0]) {
              _tinyStar(
                c,
                eyes + Offset(side * gap, 0),
                7,
                _fill(accent.withValues(alpha: 0.75)),
              );
            }
          case 'heart':
            for (final side in [-1.0, 1.0]) {
              _heart(
                c,
                eyes + Offset(side * gap, 0.5),
                4,
                _fill(const Color(0xFFFF6B8F).withValues(alpha: 0.8)),
              );
            }
          case 'shades':
            for (final side in [-1.0, 1.0]) {
              c.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromCenter(
                    center: eyes + Offset(side * gap, 0),
                    width: 11,
                    height: 7,
                  ),
                  const Radius.circular(3),
                ),
                _fill(const Color(0xEE1E1E26)),
              );
            }
            c.drawLine(
              eyes + Offset(-gap + 5, -1),
              eyes + Offset(gap - 5, -1),
              frame,
            );
          case 'monocle':
            c.drawCircle(
              eyes + Offset(gap, 0),
              5.5,
              frame..color = const Color(0xFFC9A44A),
            );
            c.drawLine(
              eyes + Offset(gap + 4, 4),
              eyes + Offset(gap + 6, 16),
              Paint()
                ..color = const Color(0xFFC9A44A)
                ..strokeWidth = 0.8,
            );
        }
      },
      'hat': () {
        // Hats.
        switch (look.hat) {
          case 'beanie':
            final r = Rect.fromCenter(
              center: top.translate(0, -2),
              width: a.headR * 1.7,
              height: a.headR * 0.9,
            );
            c.drawArc(r, math.pi, math.pi, true, _fill(accent));
            c.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: top.translate(0, 1),
                  width: a.headR * 1.8,
                  height: 6,
                ),
                const Radius.circular(3),
              ),
              _fill(dark),
            );
            c.drawCircle(
              top.translate(0, -a.headR * 0.48),
              4,
              _fill(Colors.white),
            );
          case 'witch':
            c.drawOval(
              Rect.fromCenter(
                center: top.translate(0, 1),
                width: a.headR * 2.3,
                height: 7,
              ),
              _fill(const Color(0xFF3B2F5C)),
            );
            c.drawPath(
              Path()
                ..moveTo(top.dx - a.headR * 0.6, top.dy)
                ..quadraticBezierTo(
                  top.dx,
                  top.dy - 20,
                  top.dx + a.headR * 0.4,
                  top.dy - 30,
                )
                ..lineTo(top.dx + a.headR * 0.6, top.dy)
                ..close(),
              _fill(const Color(0xFF3B2F5C)),
            );
            c.drawRect(
              Rect.fromCenter(
                center: top.translate(0, -3),
                width: a.headR * 1.15,
                height: 3,
              ),
              _fill(accent),
            );
          case 'crown':
            final w = a.headR * 1.1;
            final path = Path()
              ..moveTo(top.dx - w / 2, top.dy)
              ..lineTo(top.dx - w / 2, top.dy - 10)
              ..lineTo(top.dx - w / 4, top.dy - 4)
              ..lineTo(top.dx, top.dy - 13)
              ..lineTo(top.dx + w / 4, top.dy - 4)
              ..lineTo(top.dx + w / 2, top.dy - 10)
              ..lineTo(top.dx + w / 2, top.dy)
              ..close();
            c.drawPath(path, _fill(const Color(0xFFFFCF4D)));
            c.drawPath(path, _line);
            c.drawCircle(top.translate(0, -5), 1.8, _fill(accent));
          case 'flowers':
            for (var i = -2; i <= 2; i++) {
              final o = top + Offset(i * a.headR * 0.32, (i.abs() * 1.5) + 1);
              final col = [
                accent,
                const Color(0xFFFFE07A),
                const Color(0xFFB8E0FF),
              ][(i + 2) % 3];
              for (var k = 0; k < 5; k++) {
                c.drawCircle(
                  o +
                      Offset(
                        math.cos(k / 5 * _tau) * 2.4,
                        math.sin(k / 5 * _tau) * 2.4,
                      ),
                  2,
                  _fill(col),
                );
              }
              c.drawCircle(o, 1.4, _fill(const Color(0xFFFFF3B0)));
            }
          case 'party':
            c.drawPath(
              Path()
                ..moveTo(top.dx - 8, top.dy)
                ..lineTo(top.dx, top.dy - 22)
                ..lineTo(top.dx + 8, top.dy)
                ..close(),
              _fill(accent),
            );
            c.drawCircle(
              top.translate(0, -23),
              3,
              _fill(const Color(0xFFFFE07A)),
            );
            c.drawLine(
              top.translate(-5, -7),
              top.translate(5, -10),
              Paint()
                ..color = Colors.white
                ..strokeWidth = 1.5,
            );
          case 'tophat':
            c.drawOval(
              Rect.fromCenter(center: top, width: a.headR * 1.7, height: 6),
              _fill(const Color(0xFF26262E)),
            );
            c.drawRect(
              Rect.fromCenter(
                center: top.translate(0, -9),
                width: a.headR * 1.05,
                height: 18,
              ),
              _fill(const Color(0xFF26262E)),
            );
            c.drawRect(
              Rect.fromCenter(
                center: top.translate(0, -3),
                width: a.headR * 1.05,
                height: 3.5,
              ),
              _fill(accent),
            );
          case 'santa':
            c.drawPath(
              Path()
                ..moveTo(top.dx - a.headR * 0.8, top.dy + 1)
                ..quadraticBezierTo(
                  top.dx,
                  top.dy - 24,
                  top.dx + a.headR * 0.9,
                  top.dy - 10,
                )
                ..lineTo(top.dx + a.headR * 0.8, top.dy + 1)
                ..close(),
              _fill(const Color(0xFFE53E3E)),
            );
            c.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: top.translate(0, 1),
                  width: a.headR * 1.8,
                  height: 6,
                ),
                const Radius.circular(3),
              ),
              _fill(Colors.white),
            );
            c.drawCircle(
              top + Offset(a.headR * 0.9, -10),
              3.5,
              _fill(Colors.white),
            );
          case 'pumpkin':
            c.drawOval(
              Rect.fromCenter(
                center: top.translate(0, -4),
                width: a.headR * 1.1,
                height: 11,
              ),
              _fill(const Color(0xFFFF8A3D)),
            );
            c.drawRect(
              Rect.fromCenter(
                center: top.translate(0, -11),
                width: 2.5,
                height: 5,
              ),
              _fill(const Color(0xFF4F7A3A)),
            );
          case 'bunny':
            for (final side in [-1.0, 1.0]) {
              c.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromCenter(
                    center: top + Offset(side * 7, -11),
                    width: 7,
                    height: 20,
                  ),
                  const Radius.circular(4),
                ),
                _fill(Colors.white),
              );
              c.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromCenter(
                    center: top + Offset(side * 7, -11),
                    width: 3.5,
                    height: 14,
                  ),
                  const Radius.circular(2),
                ),
                _fill(const Color(0xFFFFC2D4)),
              );
            }
            c.drawArc(
              Rect.fromCenter(
                center: top.translate(0, 4),
                width: a.headR * 1.8,
                height: 10,
              ),
              math.pi,
              math.pi,
              false,
              Paint()
                ..color = accent
                ..strokeWidth = 2.5
                ..style = PaintingStyle.stroke,
            );
          case 'beret':
            c.drawOval(
              Rect.fromCenter(
                center: top.translate(-2, -2),
                width: a.headR * 1.6,
                height: 10,
              ),
              _fill(accent),
            );
            c.drawCircle(top.translate(-2, -7), 1.6, _fill(dark));
          case 'halo':
            c.drawOval(
              Rect.fromCenter(
                center: top.translate(0, -8 + math.sin(t * _tau) * 1.2),
                width: a.headR * 1.2,
                height: 5,
              ),
              Paint()
                ..color = const Color(0xFFFFE07A)
                ..strokeWidth = 2.2
                ..style = PaintingStyle.stroke,
            );
        }
      },
      'floating': () {
        // Floating accessory orbits slowly.
        if (look.floating != 'none') {
          final a2 = t * _tau;
          final o =
              a.head +
              Offset(
                math.cos(a2) * (a.headR + 12),
                -a.headR * 0.4 + math.sin(a2) * 6,
              );
          switch (look.floating) {
            case 'star':
              _tinyStar(c, o, 5, _fill(const Color(0xFFFFD866)));
            case 'heart':
              _heart(c, o, 3.6, _fill(const Color(0xFFFF7FA0)));
            case 'moon':
              c.drawPath(
                Path()
                  ..addOval(Rect.fromCircle(center: o, radius: 5))
                  ..addOval(
                    Rect.fromCircle(
                      center: o.translate(2.5, -1.5),
                      radius: 4.4,
                    ),
                  )
                  ..fillType = PathFillType.evenOdd,
                _fill(const Color(0xFFFFE9A6)),
              );
            case 'leaf':
              c.save();
              c.translate(o.dx, o.dy);
              c.rotate(a2);
              c.drawOval(
                const Rect.fromLTWH(-2.5, -5, 5, 10),
                _fill(const Color(0xFF7BC96F)),
              );
              c.restore();
            case 'bubble':
              c.drawCircle(
                o,
                4.5,
                Paint()
                  ..color = const Color(0xAA9AD8FF)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.2,
              );
              c.drawCircle(o.translate(-1.5, -1.5), 1, _fill(Colors.white));
            case 'note':
              final tp = TextPainter(
                text: TextSpan(
                  text: '♪',
                  style: TextStyle(fontSize: 11, color: accent),
                ),
                textDirection: TextDirection.ltr,
              )..layout();
              tp.paint(c, o.translate(-3, -6));
            case 'sun':
              c.drawCircle(o, 3.6, _fill(const Color(0xFFFFC94D)));
              for (var k = 0; k < 8; k++) {
                final d = Offset(
                  math.cos(k / 8 * _tau),
                  math.sin(k / 8 * _tau),
                );
                c.drawLine(
                  o + d * 5,
                  o + d * 7,
                  Paint()
                    ..color = const Color(0xFFFFC94D)
                    ..strokeWidth = 1.2,
                );
              }
          }
        }
      },
    };
    final pivots = <String, Offset>{
      'body': a.bodyRect.center,
      'neck': Offset(a.head.dx, ny),
      'glasses': eyes,
      'hat': top,
      'floating': a.head,
    };
    final order = slots.keys.toList();
    final base = {for (final (i, k) in order.indexed) k: i};
    order.sort((x, y) {
      final d = look.adjustOf(x).layer.compareTo(look.adjustOf(y).layer);
      return d != 0 ? d : base[x]!.compareTo(base[y]!);
    });
    for (final k in order) {
      final adj = look.adjustOf(k);
      if (adj.isIdentity) {
        slots[k]!();
        continue;
      }
      final pv = pivots[k]!;
      if (adj.opacity < 1) {
        c.saveLayer(
          null,
          Paint()..color = Color.fromRGBO(0, 0, 0, adj.opacity.clamp(0.05, 1)),
        );
      } else {
        c.save();
      }
      c.translate(pv.dx + adj.dx, pv.dy + adj.dy);
      c.rotate(adj.rotation * math.pi / 180);
      c.scale(adj.mirror ? -adj.scale : adj.scale, adj.scale);
      c.translate(-pv.dx, -pv.dy);
      slots[k]!();
      c.restore();
    }
  }

  void _particles(Canvas c, double t, {required bool behind}) {
    final kind = look.particles;
    if (kind == 'none') return;
    final rnd = math.Random(kind.hashCode);
    for (var i = 0; i < 10; i++) {
      final front = i.isOdd;
      if (front == behind) {
        rnd.nextDouble();
        rnd.nextDouble();
        rnd.nextDouble();
        continue;
      }
      final x0 = rnd.nextDouble() * 100,
          y0 = rnd.nextDouble() * 100,
          sp = 0.5 + rnd.nextDouble();
      final ph = (t * sp + i / 10) % 1;
      switch (kind) {
        case 'sparkles':
          final a = math.sin(ph * math.pi);
          _tinyStar(
            c,
            Offset(x0, y0),
            1.5 + a * 2,
            _fill(const Color(0xFFFFF0A0).withValues(alpha: a)),
          );
        case 'hearts':
          _heart(
            c,
            Offset(x0, 100 - ph * 100),
            2.4,
            _fill(const Color(0xFFFF8FB1).withValues(alpha: 1 - ph)),
          );
        case 'petals':
          c.save();
          c.translate(x0 + math.sin(ph * _tau) * 6, ph * 100);
          c.rotate(ph * _tau);
          c.drawOval(
            const Rect.fromLTWH(-2, -1.2, 4, 2.4),
            _fill(const Color(0xFFFFC2D6)),
          );
          c.restore();
        case 'snow':
          c.drawCircle(
            Offset(x0 + math.sin(ph * _tau) * 3, ph * 100),
            1.4,
            _fill(Colors.white.withValues(alpha: 0.9)),
          );
        case 'fireflies':
          final a = (math.sin(ph * _tau * 2) + 1) / 2;
          c.drawCircle(
            Offset(x0 + math.sin(ph * _tau) * 5, y0 + math.cos(ph * _tau) * 4),
            1.3,
            _fill(const Color(0xFFE6FF7A).withValues(alpha: a)),
          );
        case 'bubbles':
          c.drawCircle(
            Offset(x0, 100 - ph * 100),
            2.2,
            Paint()
              ..color = const Color(0x889AD8FF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
      }
    }
  }

  @override
  bool shouldRepaint(CreaturePainter old) =>
      old.species != species ||
      old.look != look ||
      old.pose != pose ||
      old.expression != expression ||
      old.intensity != intensity ||
      old.expressiveness != expressiveness ||
      old.weather != weather ||
      old.accessoriesOnly != accessoriesOnly;
}
