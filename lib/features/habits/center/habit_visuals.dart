import 'dart:math' as math;

import 'package:prism_plurality/domain/models/habit.dart';
import 'package:prism_plurality/features/habits/center/habit_center_data.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// The habit's own colour, or the theme accent.
Color habitColor(BuildContext context, Habit h) {
  final hex = h.colorHex?.replaceFirst('#', '');
  final v = hex == null ? null : int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
  return v == null ? Theme.of(context).colorScheme.primary : Color(v);
}

/// Gold accent (the theme's caution colour, customisable in Appearance).
Color habitGold(BuildContext context) => LookStatusColors.of(context).warning;

String unitWord(BuildContext context, HabitMeta meta, num n) {
  final label = meta.unitLabel;
  final plural = n == 1 ? '' : 's';
  return switch (meta.unit) {
    HabitUnit.minutes => tr(context, 'min', 'min'),
    HabitUnit.amount => label ?? '',
    HabitUnit.times => label == null || label.isEmpty ? tr(context, 'time$plural', n == 1 ? 'vez' : 'veces') : '$label${n == 1 ? '' : (label.endsWith('s') ? '' : 's')}',
  };
}

String fmtNum(num n) => n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);

String scheduleText(BuildContext context, Habit h, HabitMeta m) {
  if (m.monthDay != null) return tr(context, 'Monthly on day ${m.monthDay}', 'Mensual el día ${m.monthDay}');
  return switch (h.frequency) {
    HabitFrequency.daily => tr(context, 'Daily habit', 'Hábito diario'),
    HabitFrequency.weekly => tr(context, 'Selected weekdays', 'Días seleccionados'),
    HabitFrequency.interval => tr(context, 'Every ${h.intervalDays ?? 1} days', 'Cada ${h.intervalDays ?? 1} días'),
    HabitFrequency.custom => tr(context, 'Flexible habit', 'Hábito flexible'),
  };
}

/// Round icon tinted in the habit colour.
class HabitIconBadge extends StatelessWidget {
  const HabitIconBadge({super.key, required this.habit, this.size = 56});
  final Habit habit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = habitColor(context, habit);
    final icon = habit.icon?.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: prismRound(context),
        color: c.withValues(alpha: 0.16),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: icon == null || icon.isEmpty
          ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: c, size: size * 0.5)
          : Text(icon, style: TextStyle(fontSize: size * 0.46)),
    );
  }
}

/// Progress ring.
class GlowRing extends StatelessWidget {
  const GlowRing({super.key, required this.fraction, required this.color, this.size = 170, this.stroke = 12, this.child});
  final double fraction;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
      duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RingPainter(v, color, track, stroke), child: Center(child: child)),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track, this.stroke);
  final double v;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (math.min(size.width, size.height) - stroke) / 2;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, r, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke);
    if (v <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    final sweep = 2 * math.pi * v;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color || o.track != track;
}

/// Rounded translucent card used across the habit pages.
class HabitCard extends StatelessWidget {
  const HabitCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.accent, this.margin = const EdgeInsets.only(bottom: 12)});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final a = accent ?? s.primary;
    return Padding(
      padding: margin,
      child: Material(
        color: Color.alphaBlend(a.withValues(alpha: 0.06), s.surfaceContainerLow.withValues(alpha: 0.85)),
        shape: RoundedRectangleBorder(borderRadius: prismCorners(context, 22), side: BorderSide(color: a.withValues(alpha: 0.22))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Pill-shaped action with an outline.
class GlowPill extends StatelessWidget {
  const GlowPill({super.key, required this.label, required this.onTap, this.icon, this.color, this.filled = false, this.height = 54});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final fg = filled ? (ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : Colors.black87) : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: height,
        child: Material(
          color: filled ? c : c.withValues(alpha: 0.12),
          shape: StadiumBorder(side: BorderSide(color: c.withValues(alpha: onTap == null ? 0.2 : 0.7), width: 1.4)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, color: filled ? fg : c), const SizedBox(width: 10)],
                  Flexible(
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small square action tile (Log amount / Start timer / Add note).
class HabitActionTile extends StatelessWidget {
  const HabitActionTile({super.key, required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(
      color: active ? s.primary.withValues(alpha: 0.18) : s.surfaceContainerHigh.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: prismCorners(context, 20), side: BorderSide(color: s.primary.withValues(alpha: active ? 0.6 : 0.18))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: s.primary),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, maxLines: 2, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.value, this.size = 16, this.onChanged});
  final int? value;
  final double size;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final gold = habitGold(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(value == i ? null : i),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: onChanged == null ? 0.5 : 3),
              child: Icon(
                i <= (value ?? 0) ? PhosphorIcons.star(PhosphorIconsStyle.fill) : PhosphorIcons.star(),
                size: size,
                color: gold,
                semanticLabel: onChanged == null ? null : '$i',
              ),
            ),
          ),
      ],
    );
  }
}

/// Section title with a thin rule, as in the editorial habit layout.
class HabitSectionTitle extends StatelessWidget {
  const HabitSectionTitle({super.key, required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: t.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: t.colorScheme.outlineVariant.withValues(alpha: 0.5))),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
