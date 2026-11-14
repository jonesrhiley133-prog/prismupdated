import 'dart:math' as math;

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// The dark, AMOLED "space" look used across the subsystem area.
abstract final class Cosmos {
  static const black = Color(0xFF000000);
  static const lavender = Color(0xFFB9A6FF);
  static const pink = Color(0xFFFF8FD8);
  static const blue = Color(0xFF7FB6FF);
  static const panel = Color(0xFF0A0912);
  static const panelHi = Color(0xFF14121F);
  static const line = Color(0x33B9A6FF);
  static const dim = Color(0xB3FFFFFF);
  static const faint = Color(0x66FFFFFF);

  static const glow = LinearGradient(colors: [lavender, pink, blue]);
}

/// Theme for subsystem screens: black surfaces with lavender, pink and blue
/// light; [accent] (a subsystem's colour) leads when given.
ThemeData cosmicTheme(BuildContext context, {Color? accent}) {
  final base = Theme.of(context);
  final primary = accent ?? Cosmos.lavender;
  final scheme = ColorScheme.dark(
    primary: primary,
    onPrimary: Colors.black,
    primaryContainer: Color.alphaBlend(primary.withValues(alpha: 0.22), Cosmos.panel),
    onPrimaryContainer: Colors.white,
    secondary: Cosmos.pink,
    onSecondary: Colors.black,
    secondaryContainer: Color.alphaBlend(Cosmos.pink.withValues(alpha: 0.18), Cosmos.panel),
    onSecondaryContainer: Colors.white,
    tertiary: Cosmos.blue,
    onTertiary: Colors.black,
    surface: Cosmos.black,
    onSurface: Colors.white,
    onSurfaceVariant: Cosmos.dim,
    surfaceContainerLowest: Cosmos.black,
    surfaceContainerLow: const Color(0xFF07060C),
    surfaceContainer: Cosmos.panel,
    surfaceContainerHigh: Cosmos.panelHi,
    surfaceContainerHighest: const Color(0xFF1C1929),
    outline: const Color(0x55B9A6FF),
    outlineVariant: Cosmos.line,
    error: const Color(0xFFFF7A90),
  );
  return base.copyWith(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Cosmos.black,
    canvasColor: Cosmos.black,
    cardColor: Cosmos.panel,
    dividerColor: Cosmos.line,
    textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    iconTheme: base.iconTheme.copyWith(color: Colors.white),
  );
}

/// Wraps [child] in the cosmic theme.
class CosmicScope extends StatelessWidget {
  const CosmicScope({super.key, required this.child, this.accent});
  final Widget child;
  final Color? accent;
  @override
  Widget build(BuildContext context) => Theme(data: cosmicTheme(context, accent: accent), child: child);
}

Color subColor(TrackerRecord s) => Color(SubSettings(s).color);
Color subColor2(TrackerRecord s) => Color(SubSettings(s).color2 ?? Cosmos.pink.toARGB32());
String subEmoji(TrackerRecord s) => s.str('emoji')?.trim().isNotEmpty == true ? s.str('emoji')! : '✦';

/// All members by id, isolated ones included (subsystem screens only).
final memberIndexProvider = Provider<Map<String, Member>>((ref) {
  final list = ref.watch(allMemberListProvider).value ?? const <Member>[];
  return {for (final m in list) m.id: m};
});

/// Star field with soft nebula light and orbital rings.
class CosmosPainter extends CustomPainter {
  CosmosPainter({this.rings = const [], this.center, this.phase = 0, this.ringColor = Cosmos.lavender});
  final List<double> rings;
  final Offset? center;
  final double phase;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    void glow(Offset c, double r, Color color, double a) {
      canvas.drawRect(rect, Paint()..shader = RadialGradient(colors: [color.withValues(alpha: a), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)));
    }

    glow(Offset(size.width * 0.5, size.height * 0.45), size.width * 0.7, Cosmos.lavender, 0.22);
    glow(Offset(size.width * 0.95, size.height * 0.05), size.width * 0.6, Cosmos.pink, 0.16);
    glow(Offset(size.width * 0.02, size.height * 0.95), size.width * 0.65, Cosmos.blue, 0.16);

    final rnd = math.Random(7);
    final star = Paint();
    for (var i = 0; i < 90; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi + i));
      star.color = Colors.white.withValues(alpha: (0.15 + rnd.nextDouble() * 0.5) * tw);
      canvas.drawCircle(p, 0.4 + rnd.nextDouble() * 1.1, star);
    }

    final c = center;
    if (c == null) return;
    for (var i = 0; i < rings.length; i++) {
      final r = rings[i];
      final oval = Rect.fromCenter(center: c, width: r * 2, height: r * 2 * 0.86);
      canvas.drawOval(
        oval,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = SweepGradient(
            colors: [ringColor.withValues(alpha: 0.05), ringColor.withValues(alpha: 0.5), Cosmos.pink.withValues(alpha: 0.35), Cosmos.blue.withValues(alpha: 0.4), ringColor.withValues(alpha: 0.05)],
            transform: GradientRotation(phase * 2 * math.pi * (i.isEven ? 1 : -1)),
          ).createShader(oval),
      );
      // A small moon on each ring.
      final a = phase * 2 * math.pi * (i.isEven ? 1 : -0.7) + i * 2.1;
      canvas.drawCircle(Offset(c.dx + r * math.cos(a), c.dy + r * 0.86 * math.sin(a)), 2.2, Paint()..color = [Cosmos.lavender, Cosmos.pink, Cosmos.blue][i % 3]);
    }
  }

  @override
  bool shouldRepaint(CosmosPainter old) => old.phase != phase || old.rings != rings || old.center != center;
}

/// A soft glowing panel used for cards.
class CosmicPanel extends StatelessWidget {
  const CosmicPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.accent, this.onTap, this.radius = 20});
  final Widget child;
  final EdgeInsets padding;
  final Color? accent;
  final VoidCallback? onTap;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final a = accent ?? Cosmos.lavender;
    final br = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.alphaBlend(a.withValues(alpha: 0.10), Cosmos.panel), Cosmos.panel]),
        border: Border.all(color: a.withValues(alpha: 0.28)),
        boxShadow: [BoxShadow(color: a.withValues(alpha: 0.10), blurRadius: 24, spreadRadius: -6)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: br, onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Glowing emoji orb for a subsystem.
class SubOrb extends StatelessWidget {
  const SubOrb({super.key, required this.emoji, required this.color, this.color2, this.size = 44});
  final String emoji;
  final Color color;
  final Color? color2;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(center: const Alignment(-0.35, -0.4), colors: [Color.lerp(color, Colors.white, 0.35)!, color, color2 ?? color.withValues(alpha: 0.6)]),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: size * 0.45), BoxShadow(color: (color2 ?? color).withValues(alpha: 0.3), blurRadius: size * 0.9)],
    ),
    child: Text(emoji, style: TextStyle(fontSize: size * 0.46)),
  );
}

/// Gradient pill button for primary actions in the cosmic area.
class GlowButton extends StatelessWidget {
  const GlowButton({super.key, required this.label, required this.onPressed, this.icon, this.large = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(999);
    return Semantics(
      button: true,
      label: label,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: br,
            gradient: Cosmos.glow,
            boxShadow: [BoxShadow(color: Cosmos.pink.withValues(alpha: 0.35), blurRadius: 22, spreadRadius: -4), BoxShadow(color: Cosmos.blue.withValues(alpha: 0.25), blurRadius: 30, spreadRadius: -8)],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: br,
              onTap: onPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: large ? 28 : 18, vertical: large ? 16 : 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: large ? 20 : 17, color: Colors.black), const SizedBox(width: 8)],
                    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: large ? 16 : 14))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded pill (roles, tags).
class GlowPill extends StatelessWidget {
  const GlowPill(this.label, {super.key, this.color = Cosmos.lavender, this.onTap, this.icon});
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.14),
    shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: 0.45))),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
            Text(label, style: TextStyle(color: Color.lerp(color, Colors.white, 0.45), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}

/// Section heading in the cosmic area.
class CosmicHeading extends StatelessWidget {
  const CosmicHeading(this.text, {super.key, this.trailing, this.color = Cosmos.lavender});
  final String text;
  final Widget? trailing;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 8)])),
        const SizedBox(width: 10),
        Expanded(child: Text(text.toUpperCase(), style: const TextStyle(letterSpacing: 1.6, fontSize: 12, fontWeight: FontWeight.w700, color: Cosmos.dim))),
        ?trailing,
      ],
    ),
  );
}
