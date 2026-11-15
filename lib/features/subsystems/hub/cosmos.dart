import 'dart:math' as math;

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Colours for the subsystem screens, taken from the app theme so they
/// match every other page (and follow the user's chosen look).
class SubPalette {
  SubPalette(ThemeData t)
    : bg = t.scaffoldBackgroundColor,
      panel = t.colorScheme.surfaceContainer,
      panelHi = t.colorScheme.surfaceContainerHigh,
      line = t.colorScheme.outlineVariant,
      text = t.colorScheme.onSurface,
      dim = t.colorScheme.onSurfaceVariant,
      faint = t.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      primary = t.colorScheme.primary,
      onPrimary = t.colorScheme.onPrimary,
      secondary = t.colorScheme.secondary,
      tertiary = t.colorScheme.tertiary;
  final Color bg, panel, panelHi, line, text, dim, faint, primary, onPrimary, secondary, tertiary;
}

extension SubPaletteX on BuildContext {
  SubPalette get sp => SubPalette(Theme.of(this));
}

/// Kept for call sites; subsystem screens now use the regular app theme.
class CosmicScope extends StatelessWidget {
  const CosmicScope({super.key, required this.child, this.accent});
  final Widget child;
  final Color? accent;
  @override
  Widget build(BuildContext context) => child;
}

/// Warm default colours for subsystems (dusty rose, salmon, cocoa, cream…).
const subsystemDefaultColor = 0xFFC98B8B;

Color subColor(TrackerRecord s) => Color(SubSettings(s).color);
Color subColor2(TrackerRecord s) => Color(SubSettings(s).color2 ?? SubSettings(s).color);
String subEmoji(TrackerRecord s) => s.str('emoji')?.trim().isNotEmpty == true ? s.str('emoji')! : '✦';

/// All members by id, isolated ones included (subsystem screens only).
final memberIndexProvider = Provider<Map<String, Member>>((ref) {
  final list = ref.watch(allMemberListProvider).value ?? const <Member>[];
  return {for (final m in list) m.id: m};
});

/// Thin orbit rings with a small node on each.
class OrbitPainter extends CustomPainter {
  OrbitPainter({required this.rings, required this.center, required this.color, this.phase = 0});
  final List<double> rings;
  final Offset center;
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.35);
    final node = Paint()..color = color.withValues(alpha: 0.55);
    for (var i = 0; i < rings.length; i++) {
      final r = rings[i];
      canvas.drawOval(Rect.fromCenter(center: center, width: r * 2, height: r * 2 * 0.86), line);
      final a = phase * 2 * math.pi * (i.isEven ? 1 : -0.7) + i * 2.1;
      canvas.drawCircle(Offset(center.dx + r * math.cos(a), center.dy + r * 0.86 * math.sin(a)), 2.5, node);
    }
  }

  @override
  bool shouldRepaint(OrbitPainter old) => old.phase != phase || old.rings != rings || old.center != center || old.color != color;
}

/// The app's standard rounded, subtly bordered card.
class CosmicPanel extends StatelessWidget {
  const CosmicPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.accent, this.onTap, this.radius = PrismTokens.radiusMedium});
  final Widget child;
  final EdgeInsets padding;
  final Color? accent;
  final VoidCallback? onTap;
  final double radius;
  @override
  Widget build(BuildContext context) => PrismSurface(onTap: onTap, padding: padding, borderRadius: radius, child: child);
}

/// Round emoji badge tinted with a subsystem's colour.
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
    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.22), border: Border.all(color: color.withValues(alpha: 0.5))),
    child: Text(emoji, style: TextStyle(fontSize: size * 0.46)),
  );
}

/// Primary action button (the app's filled button).
class GlowButton extends StatelessWidget {
  const GlowButton({super.key, required this.label, required this.onPressed, this.icon, this.large = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool large;
  @override
  Widget build(BuildContext context) => PrismButton(label: label, icon: icon, tone: PrismButtonTone.filled, enabled: onPressed != null, onPressed: onPressed ?? () {});
}

/// Small rounded pill (roles, tags).
class GlowPill extends StatelessWidget {
  const GlowPill(this.label, {super.key, this.color, this.onTap, this.icon});
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.sp.primary;
    return Material(
      color: c.withValues(alpha: 0.14),
      shape: StadiumBorder(side: BorderSide(color: c.withValues(alpha: 0.3))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
              Text(label, style: TextStyle(color: context.sp.text, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section heading styled like the app's other section titles.
class CosmicHeading extends StatelessWidget {
  const CosmicHeading(this.text, {super.key, this.trailing, this.color});
  final String text;
  final Widget? trailing;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontFamily: theme.textTheme.headlineLarge?.fontFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
