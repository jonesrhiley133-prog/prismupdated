import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:prism_plurality/features/companions/companion_species.dart';

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
    );
  }

  CompanionLook copyWith(Map<String, Object?> changes) =>
      fromJson({...toJson(), ...changes});
}

/// Poses for interactions and photos.
enum CompanionPose { sit, wave, sleep, play, hop, read, music, eat, cuddle }

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
  });

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

class _CompanionViewState extends State<CompanionView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _t = ValueNotifier<double>(0.25);
  Duration _period = const Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _t.value =
          (elapsed.inMicroseconds % _period.inMicroseconds) /
          _period.inMicroseconds;
    });
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
    _period = Duration(milliseconds: energetic ? 2200 : (sleepy ? 4600 : 3200));
    final run = widget.animate && !reduced;
    if (run && !_ticker.isActive) _ticker.start();
    if (!run && _ticker.isActive) {
      _ticker.stop();
      _t.value = 0.25;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
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
  }) : _t = t,
       super(repaint: t);

  final Species species;
  final CompanionLook look;
  final CompanionPose pose;
  final ValueNotifier<double> _t;
  final String? expression;
  final bool accessoriesOnly;
  final bool particles;

  static const _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _t.value;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final floats = species.floats || pose == CompanionPose.hop;
    final bob =
        math.sin(t * _tau) * (floats ? 3.5 : 1.2) -
        (pose == CompanionPose.hop ? (math.sin(t * _tau).abs() * 6) : 0);
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
    final anchor = accessoriesOnly
        ? const _Anchor(Offset(50, 40), 26, 62, Rect.fromLTWH(26, 56, 48, 36))
        : _body(canvas, t);
    _accessories(canvas, anchor, t);
    canvas.restore();
    if (particles) _particles(canvas, t, behind: false);
    if (pose == CompanionPose.sleep) _zzz(canvas, t);
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
    }
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
    const head = Offset(50, 42);
    const hr = 23.0;
    final body = Rect.fromCenter(
      center: const Offset(50, 72),
      width: 46,
      height: 36,
    );
    _glow(c, const Offset(50, 60), 48, p);
    if (look.wingsOf(species)) _wings(c, t, const Offset(50, 64), p, s, 26);
    _tail(c, t, const Offset(68, 80), p, s);
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
      ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(20)));
    c.drawPath(bodyPath, bodyPaint);
    _pattern(c, bodyPath, body, p, s);
    c.drawOval(
      Rect.fromCenter(center: const Offset(50, 76), width: 26, height: 22),
      _fill(look.bellyOf(species)),
    );
    c.drawPath(bodyPath, _line);
    // Feet.
    final foot = look.pattern == 'socks'
        ? Colors.white
        : Color.lerp(p, Colors.black, 0.08)!;
    for (final x in [39.0, 61.0]) {
      final r = Rect.fromCenter(center: Offset(x, 89), width: 13, height: 8);
      c.drawOval(r, _fill(foot));
      c.drawOval(r, _line);
    }
    // Front paws (one waves).
    final wave = pose == CompanionPose.wave ? math.sin(t * _tau * 2) * 6 : 0.0;
    final hug =
        pose == CompanionPose.cuddle ||
        pose == CompanionPose.read ||
        pose == CompanionPose.eat;
    for (final (i, x) in [(0, 40.0), (1, 60.0)]) {
      var center = Offset(x, hug ? 70 : 76);
      if (i == 0 && pose == CompanionPose.wave) center = Offset(28, 58 + wave);
      final r = Rect.fromCenter(center: center, width: 10, height: 9);
      c.drawOval(r, _fill(foot));
      c.drawOval(r, _line);
    }
    if (pose == CompanionPose.read) _book(c);
    if (pose == CompanionPose.eat) _treat(c);
    // Ears behind head.
    _ears(c, t, head, hr, p, s, behind: true);
    // Head.
    final headRect = Rect.fromCenter(
      center: head,
      width: hr * 2.15,
      height: hr * 1.9,
    );
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
    if (species.muzzle)
      c.drawOval(
        Rect.fromCenter(center: head.translate(0, 9), width: 21, height: 14),
        _fill(s),
      );
    c.drawPath(headPath, _line);
    _ears(c, t, head, hr, p, s, behind: false);
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
    _face(c, t, head, hr, beak: species.beak, eyeY: 1, eyeGap: 9);
    return _Anchor(head, hr, 58, body);
  }

  _Anchor _bird(Canvas c, double t, Color p, Color s) {
    const center = Offset(50, 62);
    final r = Rect.fromCenter(center: center, width: 54, height: 60);
    _glow(c, center, 50, p);
    _tail(c, t, const Offset(50, 88), p, s);
    if (species.wings) _wings(c, t, const Offset(50, 60), p, s, 32);
    final body = Path()..addOval(r);
    c.drawPath(body, _patternPaint(p, s, r));
    _pattern(c, body, r, p, s);
    c.drawOval(
      Rect.fromCenter(center: const Offset(50, 72), width: 32, height: 32),
      _fill(look.bellyOf(species)),
    );
    c.drawPath(body, _line);
    // Side wings.
    final flap = pose == CompanionPose.wave || pose == CompanionPose.play
        ? math.sin(t * _tau * 3) * 0.4
        : math.sin(t * _tau) * 0.06;
    for (final side in [-1.0, 1.0]) {
      c.save();
      c.translate(50 + side * 25, 64);
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
          Rect.fromCenter(center: Offset(x, 92), width: 9, height: 4),
          const Radius.circular(2),
        ),
        _fill(const Color(0xFFFF9F43)),
      );
    }
    const head = Offset(50, 48);
    _ears(c, t, head, 22, p, s, behind: false);
    _face(
      c,
      t,
      head,
      22,
      beak: true,
      eyeY: 0,
      eyeGap: 9,
      owl: species.id == 'owl',
    );
    return _Anchor(head, 22, 66, r);
  }

  _Anchor _fish(Canvas c, double t, Color p, Color s) {
    const center = Offset(46, 56);
    final r = Rect.fromCenter(center: center, width: 58, height: 44);
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
    final path = Path();
    if (slime) {
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
    const head = Offset(50, 58);
    _face(c, t, head, 22, eyeY: 2, eyeGap: 10);
    return _Anchor(Offset(50, slime ? 52 : 48), 24, 68, r);
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
    final expr =
        expression ??
        (pose == CompanionPose.sleep
            ? 'sleepy'
            : (pose == CompanionPose.play || pose == CompanionPose.hop
                  ? 'excited'
                  : look.expression));
    final blink = t > 0.9 && t < 0.935;
    final eyeColor = Color(look.eye);
    final ink = Paint()
      ..color = eyeColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final scale = hr / 23;
    for (final side in [-1.0, 1.0]) {
      final e = head + Offset(side * eyeGap * scale, eyeY * scale);
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
    final ny = a.neckY;
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
          Rect.fromLTWH(a.head.dx + 6, ny, 6, 14 + math.sin(t * _tau) * 1.5),
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
    // Glasses.
    final eyes = a.head.translate(0, a.headR * 0.05);
    final gap = 9 * a.headR / 23;
    final frame = Paint()
      ..color = const Color(0xFF2E2E36)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
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
        c.drawCircle(top.translate(0, -a.headR * 0.48), 4, _fill(Colors.white));
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
        c.drawCircle(top.translate(0, -23), 3, _fill(const Color(0xFFFFE07A)));
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
          Rect.fromCenter(center: top.translate(0, -11), width: 2.5, height: 5),
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
                Rect.fromCircle(center: o.translate(2.5, -1.5), radius: 4.4),
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
            final d = Offset(math.cos(k / 8 * _tau), math.sin(k / 8 * _tau));
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
      old.accessoriesOnly != accessoriesOnly;
}
