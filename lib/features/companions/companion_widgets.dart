import 'dart:math' as math;

import 'package:prism_plurality/features/companions/companion_art.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_mood.dart';
import 'package:prism_plurality/features/companions/custom_art_editor.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart'
    show SocialImage;
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/core/graphics/decor_clock.dart';

/// A companion as stored: picks the custom artwork when there is one.
class CompanionFigure extends ConsumerWidget {
  const CompanionFigure({
    super.key,
    required this.companion,
    this.size = 120,
    this.pose = CompanionPose.sit,
    this.animate = true,
    this.look,
    this.expression,
    this.showParticles = true,
    this.weather,
  });

  /// The habitat's weather; they react to it unless that's switched off.
  final String? weather;
  final Companion companion;
  final double size;
  final CompanionPose pose;
  final bool animate;
  final CompanionLook? look;
  final String? expression;
  final bool showParticles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = companion.customSpeciesId == null
        ? null
        : ref
              .watch(customSpeciesProvider)
              .where((s) => s.r.id == companion.customSpeciesId)
              .firstOrNull;
    final species = custom?.base ?? companion.species;
    final motion = ref.watch(companionMotionProvider);
    final persona = CompanionPersonality.of(companion);
    final weatherNow = motion.environment ? weather : null;
    if (custom?.media != null) {
      return SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedArt(media: custom!.media!, fit: custom.fit, size: size),
            CompanionView(
              species: species,
              look: look ?? companion.look,
              size: size,
              pose: pose,
              animate: animate,
              traits: companion.traits,
              expression: expression,
              accessoriesOnly: true,
              fit: custom.fit,
              showParticles: showParticles,
              intensity: motion.intensity,
              expressiveness: persona.expressiveness,
              energy: persona.energy,
              weather: weatherNow,
              semanticLabel: '${companion.name}, ${custom.name}',
            ),
          ],
        ),
      );
    }
    return CompanionView(
      species: species,
      look: look ?? companion.look,
      size: size,
      pose: pose,
      animate: animate,
      traits: companion.traits,
      expression: expression,
      showParticles: showParticles,
      intensity: motion.intensity,
      expressiveness: persona.expressiveness,
      energy: persona.energy,
      weather: weatherNow,
      semanticLabel: '${companion.name}, ${species.name}',
    );
  }
}

/// Round companion portrait (or the uploaded profile picture).
class CompanionAvatar extends StatelessWidget {
  const CompanionAvatar({
    super.key,
    required this.companion,
    this.size = 48,
    this.animate = false,
  });
  final Companion companion;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: prismRound(context),
        color: Color.lerp(
          companion.look.primaryOf(companion.species),
          theme.colorScheme.surface,
          0.75,
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: companion.avatarMedia != null
          ? SocialImage(id: companion.avatarMedia!, fit: BoxFit.cover)
          : OverflowBox(
              maxWidth: size * 1.5,
              maxHeight: size * 1.5,
              alignment: const Alignment(0, 0.35),
              child: CompanionFigure(
                companion: companion,
                size: size * 1.5,
                animate: animate,
                showParticles: false,
              ),
            ),
    );
  }
}

/// Hour → sky tint for "auto" time of day.
String resolveTimeOfDay(String t, [DateTime? now]) {
  if (t != 'auto') return t;
  final h = (now ?? DateTime.now()).hour;
  if (h >= 5 && h < 10) return 'morning';
  if (h >= 10 && h < 17) return 'day';
  if (h >= 17 && h < 21) return 'evening';
  return 'night';
}

/// A habitat drawn in light layers: sky, scenery, ground, decorations,
/// weather and lighting. No 3D, nothing heavy.
class HabitatScene extends StatefulWidget {
  const HabitatScene({
    super.key,
    required this.env,
    this.time = 'auto',
    this.weather = 'clear',
    this.lighting = 'soft',
    this.items = const [],
    this.children = const [],
    this.animate = true,
    this.borderRadius = 20,
    this.onItemTap,
  });

  final String env;
  final String time;
  final String weather;
  final String lighting;
  final List<HabitatItem> items;

  /// Companions or anything else drawn in the scene (use [Positioned]).
  final List<Widget> children;
  final bool animate;
  final double borderRadius;
  final void Function(HabitatItem)? onItemTap;

  @override
  State<HabitatScene> createState() => _HabitatSceneState();
}

class _HabitatSceneState extends State<HabitatScene> with DecorClockListener {
  final _t = ValueNotifier<double>(0);

  // Weather in the habitat is ambient: low priority on the decor clock.
  @override
  DecorPriority get decorPriority => DecorPriority.low;

  @override
  void onDecorTick(double seconds) =>
      _t.value = ((seconds * 1000).round() % 12000) / 12000;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run =
        widget.animate &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) &&
        widget.weather != 'clear';
    setDecorRunning(run);
  }

  @override
  void didUpdateWidget(HabitatScene old) {
    super.didUpdateWidget(old);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final env = habitatEnvById(widget.env);
    final time = resolveTimeOfDay(widget.time);
    return ClipRRect(
      borderRadius: prismCorners(context, widget.borderRadius),
      child: Semantics(
        label:
            '${env.name}${widget.weather == 'clear' ? '' : ', ${widget.weather}'}',
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(painter: _ScenePainter(env, time)),
              ),
              for (final i in widget.items)
                Positioned(
                  left: i.x * box.maxWidth - 18 * i.scale,
                  top: i.y * box.maxHeight - 18 * i.scale,
                  child: GestureDetector(
                    onTap: widget.onItemTap == null
                        ? null
                        : () => widget.onItemTap!(i),
                    child: Text(
                      habitatDecor[i.type] ?? '✨',
                      style: TextStyle(fontSize: 30 * i.scale),
                      semanticsLabel: i.type,
                    ),
                  ),
                ),
              ...widget.children,
              if (widget.weather != 'clear')
                IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _WeatherPainter(widget.weather, _t),
                    ),
                  ),
                ),
              IgnorePointer(child: _lightingOverlay(widget.lighting, time)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lightingOverlay(String lighting, String time) {
    final night = time == 'night';
    final color = switch (lighting) {
      'warm' => const Color(0x22FFB347),
      'cool' => const Color(0x2266A6FF),
      'fairy' => const Color(0x18FFD6F0),
      'none' => const Color(0x00000000),
      _ => const Color(0x10FFFFFF),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.2,
          colors: [
            color,
            night ? const Color(0x55000022) : const Color(0x00000000),
          ],
        ),
      ),
      child: lighting == 'fairy'
          ? const CustomPaint(painter: _FairyLights())
          : null,
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.env, this.time);
  final HabitatEnv env;
  final String time;

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    var sky = env.sky;
    if (!env.indoor) {
      sky = switch (time) {
        'morning' => [
          Color.lerp(sky[0], const Color(0xFFFFD3B0), 0.35)!,
          sky[1],
        ],
        'evening' => [
          Color.lerp(sky[0], const Color(0xFFFF9E7A), 0.5)!,
          Color.lerp(sky[1], const Color(0xFF8E6BBF), 0.35)!,
        ],
        'night' => [
          Color.lerp(sky[0], const Color(0xFF0E1433), 0.75)!,
          Color.lerp(sky[1], const Color(0xFF283062), 0.7)!,
        ],
        _ => sky,
      };
    }
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: sky,
        ).createShader(r),
    );
    final rnd = math.Random(env.id.hashCode);
    final night =
        time == 'night' ||
        env.id == 'celestial' ||
        env.id == 'space' ||
        env.id == 'crystal';
    if (night && !env.indoor || env.id == 'space') {
      for (var i = 0; i < 40; i++) {
        c.drawCircle(
          Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * 0.6),
          rnd.nextDouble() * 1.4 + 0.3,
          Paint()
            ..color = Colors.white.withValues(
              alpha: 0.4 + rnd.nextDouble() * 0.5,
            ),
        );
      }
    }
    if (!env.indoor && !night && env.id != 'aquarium') {
      // Sun or soft clouds.
      c.drawCircle(
        Offset(s.width * 0.82, s.height * 0.16),
        s.shortestSide * 0.07,
        Paint()..color = const Color(0xCCFFF3B0),
      );
      for (final (x, y) in [(0.18, 0.18), (0.55, 0.1)]) {
        final o = Offset(s.width * x, s.height * y);
        final p = Paint()..color = Colors.white.withValues(alpha: 0.75);
        c.drawCircle(o, 14, p);
        c.drawCircle(o.translate(14, 4), 11, p);
        c.drawCircle(o.translate(-13, 5), 10, p);
      }
    }
    if (env.indoor) {
      // Window and floorboards.
      final win = Rect.fromLTWH(
        s.width * 0.62,
        s.height * 0.12,
        s.width * 0.26,
        s.height * 0.3,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(win, const Radius.circular(8)),
        Paint()
          ..color = time == 'night'
              ? const Color(0xFF2A3166)
              : const Color(0xFFBFE6FF),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(win, const Radius.circular(8)),
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      c.drawLine(
        win.topCenter,
        win.bottomCenter,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3,
      );
      if (env.id == 'library') {
        for (var i = 0; i < 3; i++) {
          final shelf = Rect.fromLTWH(
            s.width * 0.06,
            s.height * (0.14 + i * 0.13),
            s.width * 0.42,
            5,
          );
          c.drawRect(shelf, Paint()..color = const Color(0xFF3E2618));
          for (var b = 0; b < 9; b++) {
            c.drawRect(
              Rect.fromLTWH(
                shelf.left + 4 + b * (shelf.width / 9.5),
                shelf.top - 18 - rnd.nextDouble() * 6,
                shelf.width / 12,
                18 + rnd.nextDouble() * 6,
              ),
              Paint()
                ..color = [
                  const Color(0xFFB85C4A),
                  const Color(0xFF4F7A6E),
                  const Color(0xFFD9A441),
                  const Color(0xFF5B5EA6),
                ][b % 4],
            );
          }
        }
      }
    }
    // Scenery silhouettes.
    final groundTop = s.height * (env.water ? 0.86 : 0.7);
    final far = Paint()..color = Color.lerp(env.ground, sky.last, 0.45)!;
    switch (env.id) {
      case 'clearing' || 'mushroom' || 'flowers' || 'zen' || 'celestial':
        for (var i = 0; i < 6; i++) {
          final x = s.width * (i / 5);
          final h = s.height * (0.18 + rnd.nextDouble() * 0.12);
          if (env.id == 'zen') {
            c.drawOval(
              Rect.fromCenter(
                center: Offset(x, groundTop),
                width: s.width * 0.3,
                height: h,
              ),
              far,
            );
          } else {
            c.drawPath(
              Path()
                ..moveTo(x - 26, groundTop)
                ..lineTo(x, groundTop - h)
                ..lineTo(x + 26, groundTop)
                ..close(),
              far,
            );
          }
        }
      case 'cabin':
        final mtn = Path()
          ..moveTo(0, groundTop)
          ..lineTo(s.width * 0.25, s.height * 0.32)
          ..lineTo(s.width * 0.45, groundTop)
          ..lineTo(s.width * 0.7, s.height * 0.28)
          ..lineTo(s.width, groundTop)
          ..close();
        c.drawPath(mtn, Paint()..color = const Color(0xFFB7C7DD));
      case 'crystal':
        for (var i = 0; i < 7; i++) {
          final x = rnd.nextDouble() * s.width;
          final h = 20 + rnd.nextDouble() * 50;
          c.drawPath(
            Path()
              ..moveTo(x - 10, groundTop)
              ..lineTo(x, groundTop - h)
              ..lineTo(x + 10, groundTop)
              ..close(),
            Paint()
              ..color = [
                const Color(0xAA8FD3FF),
                const Color(0xAAFF9ED8),
                const Color(0xAAB18CFF),
              ][i % 3],
          );
        }
      case 'beach':
        c.drawRect(
          Rect.fromLTWH(0, s.height * 0.55, s.width, s.height * 0.16),
          Paint()..color = const Color(0xFF4FB3E8),
        );
      case 'cloud':
        for (var i = 0; i < 5; i++) {
          c.drawCircle(
            Offset(s.width * (i / 4), groundTop + 6),
            s.width * 0.13,
            Paint()..color = Colors.white,
          );
        }
      case 'aquarium':
        for (var i = 0; i < 6; i++) {
          final x = s.width * (0.1 + i * 0.16);
          final weed = Path()..moveTo(x, s.height);
          for (var k = 1; k <= 4; k++) {
            weed.quadraticBezierTo(
              x + (k.isEven ? 10 : -10),
              s.height - k * 18 + 9,
              x,
              s.height - k * 18,
            );
          }
          c.drawPath(
            weed,
            Paint()
              ..color = const Color(0xFF3FA36B)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round,
          );
        }
      case 'space':
        c.drawCircle(
          Offset(s.width * 0.2, s.height * 0.25),
          s.shortestSide * 0.1,
          Paint()..color = const Color(0xFFE59C6B),
        );
    }
    // Ground.
    final ground = Path()
      ..moveTo(0, groundTop)
      ..quadraticBezierTo(
        s.width / 2,
        groundTop - (env.indoor ? 0 : 12),
        s.width,
        groundTop,
      )
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    c.drawPath(ground, Paint()..color = env.ground);
    if (env.indoor) {
      for (var x = 0.0; x < s.width; x += 40) {
        c.drawLine(
          Offset(x, groundTop),
          Offset(x - 12, s.height),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.06)
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.env != env || old.time != time;
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.weather, this.t) : super(repaint: t);
  final String weather;
  final ValueNotifier<double> t;

  @override
  void paint(Canvas c, Size s) {
    final rnd = math.Random(3);
    for (var i = 0; i < 40; i++) {
      final x0 = rnd.nextDouble(),
          sp = 0.6 + rnd.nextDouble() * 0.8,
          off = rnd.nextDouble();
      final ph = (t.value * sp * 6 + off) % 1;
      final o = Offset(x0 * s.width + math.sin(ph * 6) * 6, ph * s.height);
      switch (weather) {
        case 'rain':
          c.drawLine(
            o,
            o.translate(-2, 9),
            Paint()
              ..color = const Color(0x997FB8FF)
              ..strokeWidth = 1.4,
          );
        case 'snow':
          c.drawCircle(
            o,
            2,
            Paint()..color = Colors.white.withValues(alpha: 0.9),
          );
        case 'leaves':
          if (i.isEven)
            c.drawOval(
              Rect.fromCenter(center: o, width: 7, height: 4),
              Paint()
                ..color = [
                  const Color(0xFFE8893B),
                  const Color(0xFFD9A441),
                  const Color(0xFFB8522E),
                ][i % 3],
            );
        case 'petals':
          if (i.isEven)
            c.drawOval(
              Rect.fromCenter(center: o, width: 6, height: 4),
              Paint()..color = const Color(0xFFFFC2D6),
            );
        case 'stars':
          final a = (math.sin((t.value * 8 + off) * math.pi * 2) + 1) / 2;
          c.drawCircle(
            Offset(x0 * s.width, off * s.height * 0.6),
            1.5,
            Paint()..color = Colors.white.withValues(alpha: a),
          );
        case 'fog':
          if (i < 6)
            c.drawOval(
              Rect.fromCenter(
                center: Offset(
                  (x0 + t.value) % 1 * s.width,
                  s.height * (0.5 + off * 0.4),
                ),
                width: s.width * 0.6,
                height: 40,
              ),
              Paint()..color = Colors.white.withValues(alpha: 0.12),
            );
        case 'bubbles':
          if (i.isEven)
            c.drawCircle(
              Offset(o.dx, s.height - o.dy),
              3,
              Paint()
                ..color = const Color(0x99FFFFFF)
                ..style = PaintingStyle.stroke,
            );
      }
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) => old.weather != weather;
}

class _FairyLights extends CustomPainter {
  const _FairyLights();
  @override
  void paint(Canvas c, Size s) {
    final path = Path()..moveTo(0, 14);
    path.quadraticBezierTo(s.width / 2, 44, s.width, 14);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0x66333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (final m in path.computeMetrics()) {
      for (var d = 10.0; d < m.length; d += 22) {
        final p = m.getTangentForOffset(d)!.position;
        c.drawCircle(
          p,
          3,
          Paint()
            ..color = [
              const Color(0xFFFFE07A),
              const Color(0xFFFF9EC7),
              const Color(0xFF9AD8FF),
            ][(d ~/ 22) % 3],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FairyLights old) => false;
}

/// Egg styles for hatching.
const eggStyles = <String, (String, Color, Color)>{
  'classic': ('Traditional', Color(0xFFFFF6E8), Color(0xFFE8C9A0)),
  'celestial': ('Celestial', Color(0xFF3A3F8F), Color(0xFFFFE08A)),
  'elemental': ('Elemental', Color(0xFFFF8A5C), Color(0xFF5EC8FF)),
  'woodland': ('Woodland', Color(0xFF9CCB7E), Color(0xFF7A5A43)),
  'crystal': ('Crystal', Color(0xFFBDE7FF), Color(0xFFFFB3E6)),
  'aquatic': ('Aquatic', Color(0xFF7FD0F0), Color(0xFFFFFFFF)),
  'seasonal': ('Seasonal', Color(0xFFFFD1DC), Color(0xFF9ED38A)),
};

class EggView extends StatelessWidget {
  const EggView({
    super.key,
    required this.style,
    this.size = 100,
    this.crack = 0,
    this.wobble = 0,
  });
  final String style;
  final double size;

  /// 0 = whole, 1 = fully cracked.
  final double crack;
  final double wobble;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${eggStyles[style]?.$1 ?? 'Egg'} egg',
    image: true,
    child: Transform.rotate(
      angle: wobble,
      alignment: Alignment.bottomCenter,
      child: CustomPaint(
        size: Size.square(size),
        painter: _EggPainter(style, crack),
      ),
    ),
  );
}

class _EggPainter extends CustomPainter {
  _EggPainter(this.style, this.crack);
  final String style;
  final double crack;

  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 100);
    final (_, base, accent) = eggStyles[style] ?? eggStyles['classic']!;
    final egg = Path()
      ..moveTo(50, 8)
      ..cubicTo(78, 8, 86, 62, 82, 74)
      ..cubicTo(78, 92, 22, 92, 18, 74)
      ..cubicTo(14, 62, 22, 8, 50, 8)
      ..close();
    c.drawOval(
      const Rect.fromLTWH(26, 88, 48, 7),
      Paint()..color = const Color(0x22000000),
    );
    c.drawPath(
      egg,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(base, Colors.white, 0.3)!, base],
        ).createShader(egg.getBounds()),
    );
    c.save();
    c.clipPath(egg);
    final p = Paint()..color = accent;
    switch (style) {
      case 'celestial':
        final rnd = math.Random(4);
        for (var i = 0; i < 12; i++) {
          c.drawCircle(
            Offset(20 + rnd.nextDouble() * 60, 14 + rnd.nextDouble() * 70),
            1 + rnd.nextDouble() * 1.6,
            p,
          );
        }
        c.drawPath(
          Path()
            ..addOval(const Rect.fromLTWH(54, 30, 16, 16))
            ..addOval(const Rect.fromLTWH(58, 27, 15, 15))
            ..fillType = PathFillType.evenOdd,
          p,
        );
      case 'elemental':
        c.drawRect(
          const Rect.fromLTWH(0, 52, 100, 50),
          Paint()..color = accent.withValues(alpha: 0.7),
        );
        c.drawPath(
          Path()
            ..moveTo(0, 52)
            ..quadraticBezierTo(25, 42, 50, 52)
            ..quadraticBezierTo(75, 62, 100, 52)
            ..lineTo(100, 60)
            ..lineTo(0, 60),
          Paint()..color = Colors.white.withValues(alpha: 0.4),
        );
      case 'woodland':
        for (final o in const [
          Offset(36, 34),
          Offset(60, 52),
          Offset(42, 70),
        ]) {
          c.drawOval(Rect.fromCenter(center: o, width: 12, height: 7), p);
        }
      case 'crystal':
        for (var i = 0; i < 5; i++) {
          c.drawLine(
            Offset(20.0 + i * 15, 10),
            Offset(10.0 + i * 18, 92),
            Paint()
              ..color = accent.withValues(alpha: 0.6)
              ..strokeWidth = 2,
          );
        }
      case 'aquatic':
        for (final o in const [
          Offset(34, 30),
          Offset(62, 46),
          Offset(44, 66),
          Offset(66, 72),
        ]) {
          c.drawCircle(
            o,
            5,
            Paint()
              ..color = accent.withValues(alpha: 0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
        }
      case 'seasonal':
        for (final o in const [
          Offset(36, 32),
          Offset(64, 40),
          Offset(48, 62),
          Offset(30, 70),
          Offset(68, 72),
        ]) {
          for (var k = 0; k < 5; k++) {
            c.drawCircle(
              o +
                  Offset(
                    math.cos(k / 5 * math.pi * 2) * 3,
                    math.sin(k / 5 * math.pi * 2) * 3,
                  ),
              2.4,
              Paint()..color = k.isEven ? accent : const Color(0xFFFFF3B0),
            );
          }
        }
      default:
        c.drawPath(
          Path()
            ..moveTo(0, 50)
            ..lineTo(15, 42)
            ..lineTo(30, 50)
            ..lineTo(45, 42)
            ..lineTo(60, 50)
            ..lineTo(75, 42)
            ..lineTo(90, 50)
            ..lineTo(100, 44)
            ..lineTo(100, 54)
            ..lineTo(0, 58),
          p,
        );
    }
    c.restore();
    c.drawPath(
      egg,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    c.drawOval(
      const Rect.fromLTWH(32, 20, 9, 16),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    if (crack > 0) {
      final crackPath = Path()..moveTo(30, 46);
      final steps = (crack * 8).ceil();
      for (var i = 1; i <= steps; i++) {
        crackPath.lineTo(30 + i * 5.0, i.isEven ? 46 : 38);
      }
      c.drawPath(
        crackPath,
        Paint()
          ..color = const Color(0xFF5A4636)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_EggPainter old) =>
      old.style != style || old.crack != crack;
}

/// "Owned by …" text for a companion.
String ownersLabel(
  Companion c,
  Map<String, String> memberNames,
  Map<String, String> subsystemNames,
) => switch (c.ownerType) {
  OwnerType.system => 'Whole system',
  OwnerType.none => 'Unassigned',
  OwnerType.subsystem =>
    c.owners.map((id) => subsystemNames[id] ?? 'Subsystem').join(', '),
  _ =>
    c.owners.isEmpty
        ? 'Unassigned'
        : c.owners.map((id) => memberNames[id] ?? '?').join(', '),
};
