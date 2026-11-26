import 'dart:math' as math;

import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';
import 'package:prism_plurality/shared/providers/visual_effects_provider.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

bool astroEs(BuildContext c) =>
    Localizations.maybeLocaleOf(c)?.languageCode == 'es';

String trp(BuildContext c, (String, String) p) => tr(c, p.$1, p.$2);

/// Zodiac, planet and aspect symbols in the bundled symbol font, so they
/// look the same everywhere and never turn into colour emoji.
TextStyle astroGlyphStyle(double size, Color color) => TextStyle(
  fontFamily: 'PrismAstro',
  fontFamilyFallback: const ['PrismAstro2'],
  fontSize: size,
  height: 1.1,
  color: color,
);

class AstroGlyph extends StatelessWidget {
  const AstroGlyph(this.glyph, {super.key, this.size = 18, this.color});
  final String glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    // Angles (AC / MC) are letters, drawn in the app font.
    if (glyph.length > 1 && !glyph.runes.any((r) => r > 0x2000)) {
      return Text(
        glyph,
        style: TextStyle(
          fontSize: size * 0.62,
          fontWeight: FontWeight.w800,
          color: c,
          letterSpacing: 0.5,
        ),
      );
    }
    return Text(glyph, style: astroGlyphStyle(size, c));
  }
}

/// The member's accent colour, else the theme's primary.
Color alterAccent(BuildContext context, AstroAccess a) {
  final hex = a.member.customColorEnabled ? a.member.customColorHex : null;
  if (hex != null && RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(hex.trim())) {
    return Color(int.parse('FF${hex.trim().replaceFirst('#', '')}', radix: 16));
  }
  return Theme.of(context).colorScheme.primary;
}

/// A quiet field of stars drawn from theme colours. Twinkles only when the
/// device allows animation and visual effects are on full.
class StarField extends ConsumerStatefulWidget {
  const StarField({super.key, this.count = 46, this.seed = 7, this.color});
  final int count;
  final int seed;
  final Color? color;

  @override
  ConsumerState<StarField> createState() => _StarFieldState();
}

class _StarFieldState extends ConsumerState<StarField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        VisualEffectsModeX.of(context, ref) == VisualEffectsMode.full;
    if (animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.onSurface;
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _StarPainter(widget.count, widget.seed, color, _c),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.count, this.seed, this.color, this.anim)
    : super(repaint: anim);
  final int count;
  final int seed;
  final Color color;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final p = Paint();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.5 + rng.nextDouble() * 1.3;
      final phase = rng.nextDouble();
      final tw = 0.55 + 0.45 * math.sin((anim.value + phase) * 2 * math.pi);
      p.color = color.withValues(alpha: (0.08 + 0.22 * rng.nextDouble()) * tw);
      canvas.drawCircle(Offset(x, y), r, p);
      if (r > 1.6) {
        p.color = color.withValues(alpha: 0.06 * tw);
        canvas.drawCircle(Offset(x, y), r * 3, p);
      }
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.color != color || old.count != count;
}

/// The Astro hero card: a Prism surface with a starfield behind it.
class AstroHero extends StatelessWidget {
  const AstroHero({
    super.key,
    required this.child,
    this.accent,
    this.onTap,
    this.seed = 7,
  });
  final Widget child;
  final Color? accent;
  final VoidCallback? onTap;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = accent ?? scheme.primary;
    return PrismSurface(
      onTap: onTap,
      padding: EdgeInsets.zero,
      tone: PrismSurfaceTone.strong,
      accentColor: a,
      child: ClipRRect(
        borderRadius: prismCorners(context, PrismTokens.radiusMedium),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      a.withValues(alpha: 0.16),
                      a.withValues(alpha: 0.02),
                      scheme.tertiary.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: StarField(seed: seed)),
            Padding(padding: const EdgeInsets.all(18), child: child),
          ],
        ),
      ),
    );
  }
}

/// A titled card in a section.
class AstroCard extends StatelessWidget {
  const AstroCard({
    super.key,
    required this.child,
    this.title,
    this.emoji,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final String? title;
  final String? emoji;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrismSurface(
      onTap: onTap,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (emoji != null) ...[
                  Text(emoji!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

/// "☉ Aquarius · ☽ Pisces · AC Leo"
class BigThree extends StatelessWidget {
  const BigThree({
    super.key,
    required this.access,
    this.size = 14,
    this.wrap = true,
  });
  final AstroAccess access;
  final double size;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final accent = alterAccent(context, access);
    final c = access.chart;
    final items = <(String, String, bool)>[
      if (access.sunSign != null)
        (
          signs[access.sunSign!].glyph,
          '${signs[access.sunSign!].name.of(es)}${access.cuspWith != null ? '*' : ''}',
          true,
        ),
      if (c != null && c.moonCertain)
        ('☽', '${signs[c.moonSign].name.of(es)} ${es ? 'Luna' : 'Moon'}', true),
      if (c?.risingSign != null)
        (
          'AC',
          '${signs[c!.risingSign!].name.of(es)} ${es ? 'Asc.' : 'Rising'}',
          true,
        ),
    ];
    final children = [
      for (final (i, it) in items.indexed) ...[
        if (i > 0)
          Text(
            ' · ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        AstroGlyph(it.$1, size: size + 2, color: accent),
        const SizedBox(width: 4),
        Text(
          it.$2,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: size - 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ];
    if (!wrap) return Row(mainAxisSize: MainAxisSize.min, children: children);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: children,
    );
  }
}

/// Horizontal bar for a 0–100 energy value.
class EnergyBar extends StatelessWidget {
  const EnergyBar({
    super.key,
    required this.kind,
    required this.value,
    this.compare,
    this.color,
  });
  final EnergyKind kind;
  final int value;

  /// A self-reported value (0–100) drawn as a marker.
  final int? compare;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = astroEs(context);
    final c = color ?? theme.colorScheme.primary;
    return Semantics(
      label: '${kind.label.of(es)} $value%',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(kind.emoji, style: const TextStyle(fontSize: 15)),
            ),
            SizedBox(
              width: 92,
              child: Text(
                kind.label.of(es),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: prismCorners(context, 4),
                      ),
                    ),
                    Container(
                      height: 8,
                      width: box.maxWidth * value / 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.withValues(alpha: 0.55), c],
                        ),
                        borderRadius: prismCorners(context, 4),
                      ),
                    ),
                    if (compare != null)
                      Positioned(
                        left: (box.maxWidth * compare! / 100 - 2).clamp(
                          0,
                          box.maxWidth - 4,
                        ),
                        top: -3,
                        child: Container(
                          width: 4,
                          height: 14,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiary,
                            borderRadius: prismCorners(context, 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 34,
              child: Text(
                '$value%',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The honest-framing line shown under readings.
class AstroDisclaimer extends StatelessWidget {
  const AstroDisclaimer({super.key, this.tarot = false});
  final bool tarot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIcons.info(),
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tarot
                  ? tr(
                      context,
                      'Tarot here is for reflection and fun — it doesn\'t predict what will happen.',
                      'Aquí el tarot es para reflexionar y divertirse: no predice lo que va a pasar.',
                    )
                  : tr(
                      context,
                      'Astrology-inspired interpretations for reflection, not predictions or facts.',
                      'Interpretaciones inspiradas en la astrología para reflexionar, no predicciones ni hechos.',
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small avatar for an alter.
class AstroAvatar extends StatelessWidget {
  const AstroAvatar(this.access, {super.key, this.size = 36});
  final AstroAccess access;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = access.member;
    return MemberAvatar(
      avatarImageData: m.avatarImageData,
      memberName: access.name,
      emoji: m.emoji,
      customColorEnabled: m.customColorEnabled,
      customColorHex: m.customColorHex,
      size: size,
    );
  }
}

/// Glyph + name chip for a sign.
class SignChip extends StatelessWidget {
  const SignChip(this.sign, {super.key, this.prefix, this.color});
  final int sign;
  final String? prefix;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: prismCorners(context, 20),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AstroGlyph(signs[sign].glyph, size: 15, color: c),
          const SizedBox(width: 5),
          Text(
            '${prefix == null ? '' : '$prefix '}${signs[sign].name.of(es)}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String bodyGlyph(Body b) => planets[b]!.glyph;
