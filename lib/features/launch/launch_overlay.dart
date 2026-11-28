import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/launch/launch_settings.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/shared/widgets/prism_logo_tile.dart';

// The Prism mark on a 108×108 grid (from the launcher's vector icon): an
// outline A-B-C-D with a centre edge A-C, i.e. two triangular faces.
const _a = Offset(54.62, 35.09);
const _b = Offset(34.98, 67.40);
const _c = Offset(60.79, 72.16);
const _d = Offset(73.02, 64.12);
const _centre = Offset(55.85, 59.69);

double _seg(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// Paints the logo for progress [t] (0 → pieces apart, 1 → assembled).
class PrismMarkPainter extends CustomPainter {
  PrismMarkPainter({
    required this.t,
    required this.color,
    required this.accent,
    required this.style,
    required this.logo,
  });
  final double t;
  final Color color;
  final Color accent;
  final LaunchStyle style;
  final LaunchLogo logo;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 52; // the mark spans ~40 of the 108 grid
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.translate(-_centre.dx, -_centre.dy);

    final assemble = style == LaunchStyle.assemble;
    final move = assemble
        ? Curves.easeOutCubic.transform(_seg(t, 0, 0.55))
        : 1.0;
    final fade = style == LaunchStyle.minimal
        ? _seg(t, 0, 0.6)
        : _seg(t, 0, assemble ? 0.35 : 0.7);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: fade);

    void face(List<Offset> pts, Offset from, double rot, Color fill) {
      canvas.save();
      final k = 1 - move;
      canvas.translate(from.dx * k, from.dy * k);
      canvas.translate(_centre.dx, _centre.dy);
      canvas.rotate(rot * k);
      canvas.translate(-_centre.dx, -_centre.dy);
      final path = Path()..addPolygon(pts, true);
      if (logo != LaunchLogo.outline) {
        canvas.drawPath(
          path,
          Paint()
            ..color = fill.withValues(
              alpha: fill.a * fade * _seg(t, 0.25, 0.65),
            ),
        );
      }
      canvas.drawPath(path, stroke);
      canvas.restore();
    }

    // Front face slides in from the lower left, side face from the upper right.
    face(
      [_a, _b, _c],
      const Offset(-26, 18),
      -0.5,
      accent.withValues(alpha: 0.55),
    );
    face(
      [_a, _c, _d],
      const Offset(24, -20),
      0.45,
      accent.withValues(alpha: 0.30),
    );

    // A soft shine sweeps across once the pieces lock together.
    if (assemble && t > 0.5 && t < 0.85) {
      final p = _seg(t, 0.5, 0.85);
      final glow = Paint()
        ..shader = ui.Gradient.linear(
          Offset(30 + 50 * p, 30),
          Offset(40 + 50 * p, 75),
          [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.35 * (1 - (p - 0.5).abs() * 2)),
            color.withValues(alpha: 0),
          ],
          [0, 0.5, 1],
        );
      canvas.drawPath(Path()..addPolygon([_a, _b, _c, _d], true), glow);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PrismMarkPainter old) =>
      old.t != t ||
      old.color != color ||
      old.accent != accent ||
      old.logo != logo ||
      old.style != style;
}

/// The animated mark, wordmark and greeting. Progress is tied to the time
/// since launch, so it continues smoothly from the database screen into
/// the app overlay without restarting.
class LaunchMark extends ConsumerStatefulWidget {
  const LaunchMark({
    super.key,
    this.showText = true,
    this.onDone,
    this.liveData = true,
  });
  final bool showText;
  final VoidCallback? onDone;

  /// False before the database is open: use only the cached system name.
  final bool liveData;
  @override
  ConsumerState<LaunchMark> createState() => _LaunchMarkState();
}

class _LaunchMarkState extends ConsumerState<LaunchMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final dur = LaunchBoot.settings.duration;
    _c = AnimationController(vsync: this, duration: dur);
    // The timeline starts on the first visible frame and carries on if the
    // mark moves from the database screen to the app overlay.
    if (!LaunchBoot.clock.isRunning) LaunchBoot.clock.start();
    final already = LaunchBoot.clock.elapsedMilliseconds / dur.inMilliseconds;
    _c.value = already.clamp(0.0, 1.0);
    _c.forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(launchSettingsProvider);
    final theme = Theme.of(context);
    final reduced =
        settings.reducedMotion || MediaQuery.of(context).disableAnimations;
    final style = reduced ? LaunchStyle.fade : settings.style;
    final onPrism = settings.background == LaunchBackground.prism;
    final ink = onPrism ? Colors.white : theme.colorScheme.onSurface;
    final accent = onPrism ? Colors.white : theme.colorScheme.primary;
    final sys = widget.liveData
        ? ref.watch(systemSettingsProvider).value
        : null;
    final name = sys?.systemName?.trim().isNotEmpty == true
        ? sys!.systemName!.trim()
        : LaunchBoot.cachedSystemName;
    if (sys?.systemName != null)
      LaunchBoot.rememberSystemName(sys!.systemName!.trim());
    final fronter = widget.liveData
        ? ref.watch(currentFronterProvider).value
        : null;
    final es = Localizations.localeOf(context).languageCode == 'es';
    final greeting = buildGreeting(
      preset: settings.greeting,
      custom: settings.customGreeting,
      systemName: name,
      primaryFronter: fronter == null
          ? null
          : (fronter.displayName?.trim().isNotEmpty == true
                ? fronter.displayName!
                : fronter.name),
      es: es,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    final avatar = settings.showAvatar ? sys?.systemAvatarData : null;
    final showText = widget.showText && style != LaunchStyle.minimal;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final word = showText
            ? _seg(
                t,
                style == LaunchStyle.assemble ? 0.5 : 0.25,
                style == LaunchStyle.assemble ? 0.72 : 0.6,
              )
            : 0.0;
        final hello = showText
            ? _seg(
                t,
                style == LaunchStyle.assemble ? 0.66 : 0.4,
                style == LaunchStyle.assemble ? 0.92 : 0.8,
              )
            : 0.0;
        final markSize = math.min(
          140.0,
          MediaQuery.sizeOf(context).shortestSide * 0.34,
        );
        Widget mark = CustomPaint(
          size: Size.square(markSize),
          painter: PrismMarkPainter(
            t: t,
            color: ink,
            accent: accent,
            style: style,
            logo: settings.logo == LaunchLogo.tile
                ? LaunchLogo.filled
                : settings.logo,
          ),
        );
        if (settings.logo == LaunchLogo.tile) {
          mark = Opacity(
            opacity: _seg(t, 0, 0.3),
            child: Container(
              width: markSize * 1.15,
              height: markSize * 1.15,
              decoration: BoxDecoration(
                gradient: PrismLogoTile.gradient,
                borderRadius: prismCorners(context, markSize * 0.28),
              ),
              child: CustomPaint(
                painter: PrismMarkPainter(
                  t: t,
                  color: Colors.white,
                  accent: Colors.white,
                  style: style,
                  logo: LaunchLogo.filled,
                ),
              ),
            ),
          );
        }
        if (!reduced && style == LaunchStyle.assemble) {
          mark = Transform.scale(
            scale: 0.86 + 0.14 * Curves.easeOutBack.transform(_seg(t, 0, 0.6)),
            child: mark,
          );
        }
        return Semantics(
          label: greeting.isEmpty ? 'Prism' : 'Prism. $greeting',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              if (showText) ...[
                const SizedBox(height: 18),
                Opacity(
                  opacity: word,
                  child: Transform.translate(
                    offset: Offset(0, reduced ? 0 : 10 * (1 - word)),
                    child: Text(
                      'Prism',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Opacity(
                  opacity: hello,
                  child: Transform.translate(
                    offset: Offset(0, reduced ? 0 : 8 * (1 - hello)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (avatar != null && avatar.isNotEmpty) ...[
                          PrismClipRound(
                            child: Image.memory(
                              avatar,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              cacheWidth: 132,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (greeting.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              greeting,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: ink.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Background for the launch screens.
class LaunchBackdrop extends ConsumerWidget {
  const LaunchBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(launchSettingsProvider);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: settings.background == LaunchBackground.prism
          ? const BoxDecoration(gradient: PrismLogoTile.gradient)
          : BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: Center(child: child),
    );
  }
}

/// Sits above the app on cold start: plays the mark, then zooms and fades
/// into the app. The app builds underneath at the same time, so nothing
/// waits on the animation longer than it lasts.
class LaunchOverlay extends StatefulWidget {
  const LaunchOverlay({super.key, required this.child});
  final Widget child;
  @override
  State<LaunchOverlay> createState() => _LaunchOverlayState();
}

class _LaunchOverlayState extends State<LaunchOverlay>
    with SingleTickerProviderStateMixin {
  Timer? _doneTimer;
  // Set once the hand-off finishes. If this widget is rebuilt from scratch
  // mid-animation, the new one carries on (the timeline is time-based).
  static bool _playedThisRun = false;
  late bool _visible = LaunchBoot.shouldPlay && !_playedThisRun;
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    _exit.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _playedThisRun = true;
        if (mounted) setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;
    final reduced =
        LaunchBoot.settings.reducedMotion ||
        MediaQuery.of(context).disableAnimations;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _exit,
          builder: (context, child) {
            final e = Curves.easeInCubic.transform(_exit.value);
            return IgnorePointer(
              ignoring: _exit.value > 0.3,
              child: Opacity(
                opacity: 1 - e,
                child: Transform.scale(
                  scale: reduced ? 1 : 1 + 0.12 * e,
                  child: child,
                ),
              ),
            );
          },
          child: Material(
            type: MaterialType.transparency,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // A tap skips straight to the app.
              onTap: () => _exit.forward(),
              child: LaunchBackdrop(
                child: LaunchMark(
                  onDone: () {
                    _doneTimer?.cancel();
                    _doneTimer = Timer(
                      const Duration(milliseconds: 120),
                      () => mounted ? _exit.forward() : null,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
