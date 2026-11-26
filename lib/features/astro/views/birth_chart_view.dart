import 'dart:math' as math;

import 'package:prism_plurality/features/astro/content/interpret.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/engine/chart.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';
import 'package:prism_plurality/features/astro/views/astro_widgets.dart';
import 'package:prism_plurality/features/astro/views/birth_details_sheet.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Opens the reading for one placement.
Future<void> showPlacement(
  BuildContext context,
  PlacementReading r,
  Color accent,
) => PrismSheet.show(
  context: context,
  title: r.title,
  maxHeightFactor: 0.9,
  builder: (context) {
    final theme = Theme.of(context);
    final es = astroEs(context);
    final ordered = [
      ...r.focusFacets,
      ...Facet.values.where((f) => !r.focusFacets.contains(f)),
    ];
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: prismRound(context),
                color: accent.withValues(alpha: 0.14),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: AstroGlyph(r.glyph, size: 26, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                r.meaning,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AstroCard(child: Text(r.inSign, style: const TextStyle(height: 1.45))),
        if (r.inHouse != null) ...[
          const SizedBox(height: 10),
          AstroCard(
            child: Text(r.inHouse!, style: const TextStyle(height: 1.45)),
          ),
        ],
        if (r.note != null) ...[
          const SizedBox(height: 10),
          Text(
            r.note!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        PrismSectionHeader(
          title: tr(context, 'INTERPRETATIONS', 'INTERPRETACIONES'),
        ),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, f) in ordered.indexed) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          f.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  f.label.of(es),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (r.focusFacets.contains(f)) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    PhosphorIcons.star(PhosphorIconsStyle.fill),
                                    size: 12,
                                    color: accent,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.facets[f]!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const AstroDisclaimer(),
      ],
    );
  },
);

PlacementReading readingFor(NatalChart chart, Body b, bool es) => readBody(
  b,
  chart.positions[b]!.sign,
  es,
  house: chart.houseOf(b),
  retrograde: chart.positions[b]!.retrograde,
  otherSign: chart.uncertainSigns[b],
);

class BirthChartSection extends StatelessWidget {
  const BirthChartSection({super.key, required this.access});
  final AstroAccess access;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final accent = alterAccent(context, access);
    final chart = access.chart;
    if (chart == null) {
      final s = access.sunSign!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Unlock(access: access, needsYear: true),
          const SizedBox(height: 12),
          AstroCard(
            onTap: () =>
                showPlacement(context, readBody(Body.sun, s, es), accent),
            child: Row(
              children: [
                AstroGlyph(signs[s].glyph, size: 30, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        es
                            ? 'Sol en ${signs[s].name.es}'
                            : 'Sun in ${signs[s].name.en}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${signs[s].dates.of(es)} · ${signs[s].element.label.of(es)} · ${signs[s].modality.label.of(es)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (access.cuspWith != null)
                        Text(
                          es
                              ? 'Nacimiento en la cúspide con ${signs[access.cuspWith!].name.es}: el año confirmará el signo.'
                              : 'Born on the cusp with ${signs[access.cuspWith!].name.en} — the year will confirm the sign.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(PhosphorIcons.caretRight(), size: 16),
              ],
            ),
          ),
        ],
      );
    }
    final points = [for (final b in Body.values) (b, chart.positions[b]!)];
    final balance = balanceOf(chart);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!chart.birth.isComplete) ...[
          _Unlock(access: access, needsYear: false),
          const SizedBox(height: 12),
        ],
        AstroCard(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: 1,
            child: _ChartWheel(
              chart: chart,
              accent: accent,
              onTapBody: (b) =>
                  showPlacement(context, readingFor(chart, b, es), accent),
              onTapAngle: (p) {
                final a = chart.angles!;
                showPlacement(
                  context,
                  readAngle(
                    p,
                    signOf(
                      p == ChartPoint.ascendant ? a.ascendant : a.midheaven,
                    ),
                    es,
                  ),
                  accent,
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            tr(
              context,
              'Tap a planet to read it.',
              'Toca un planeta para leerlo.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        PrismSectionHeader(title: tr(context, 'OVERVIEW', 'RESUMEN')),
        AstroCard(
          child: Text(
            chartSummary(chart, access.name, es),
            style: const TextStyle(height: 1.5),
          ),
        ),
        PrismSectionHeader(title: tr(context, 'PLACEMENTS', 'POSICIONES')),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (chart.angles != null)
                for (final p in [ChartPoint.ascendant, ChartPoint.midheaven])
                  PrismListRow(
                    dense: true,
                    leading: SizedBox(
                      width: 30,
                      child: Center(
                        child: AstroGlyph(
                          p == ChartPoint.ascendant ? 'AC' : 'MC',
                          size: 20,
                          color: accent,
                        ),
                      ),
                    ),
                    title: Text(
                      p == ChartPoint.ascendant
                          ? tr(context, 'Rising', 'Ascendente')
                          : tr(context, 'Midheaven', 'Medio Cielo'),
                    ),
                    subtitle: Text(
                      formatPosition(
                        p == ChartPoint.ascendant
                            ? chart.angles!.ascendant
                            : chart.angles!.midheaven,
                        es,
                      ),
                    ),
                    showChevron: true,
                    onTap: () => showPlacement(
                      context,
                      readAngle(
                        p,
                        signOf(
                          p == ChartPoint.ascendant
                              ? chart.angles!.ascendant
                              : chart.angles!.midheaven,
                        ),
                        es,
                      ),
                      accent,
                    ),
                  ),
              for (final (b, pos) in points)
                PrismListRow(
                  dense: true,
                  leading: SizedBox(
                    width: 30,
                    child: Center(
                      child: AstroGlyph(bodyGlyph(b), size: 20, color: accent),
                    ),
                  ),
                  title: Text(planets[b]!.name.of(es)),
                  subtitle: Text(
                    [
                      formatPosition(pos.longitude, es),
                      if (chart.houseOf(b) != null)
                        es
                            ? 'casa ${houseOrdinal(chart.houseOf(b)!, true)}'
                            : '${houseOrdinal(chart.houseOf(b)!, false)} house',
                      if (pos.retrograde) '℞',
                      if (chart.uncertainSigns.containsKey(b))
                        es
                            ? 'o ${signs[chart.uncertainSigns[b]!].name.es}'
                            : 'or ${signs[chart.uncertainSigns[b]!].name.en}',
                      if (b.approximate) '≈',
                    ].join(' · '),
                  ),
                  showChevron: true,
                  onTap: () =>
                      showPlacement(context, readingFor(chart, b, es), accent),
                ),
            ],
          ),
        ),
        if (chart.angles != null) ...[
          PrismSectionHeader(title: tr(context, 'HOUSES', 'CASAS')),
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var h = 1; h <= 12; h++)
                  PrismListRow(
                    dense: true,
                    leading: SizedBox(
                      width: 30,
                      child: Center(
                        child: Text(
                          '$h',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      '${formatPosition(chart.angles!.cusps[h - 1], es)} · ${houses[h - 1].theme.of(es)}',
                    ),
                    subtitle: Text(houses[h - 1].area.of(es)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              switch (chart.angles!.system) {
                HouseSystem.placidus => 'Placidus',
                HouseSystem.wholeSign => tr(
                  context,
                  'Whole sign houses',
                  'Casas de signo completo',
                ),
                HouseSystem.equal =>
                  access.profile.houseSystem == HouseSystem.placidus
                      ? tr(
                          context,
                          'Equal houses (Placidus can\'t be drawn this close to the poles)',
                          'Casas iguales (Placidus no se puede trazar tan cerca de los polos)',
                        )
                      : tr(context, 'Equal houses', 'Casas iguales'),
              },
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        PrismSectionHeader(
          title: tr(context, 'MAJOR ASPECTS', 'ASPECTOS PRINCIPALES'),
        ),
        if (chart.aspects.isEmpty)
          AstroCard(
            child: Text(
              tr(
                context,
                'No major aspects within orb.',
                'No hay aspectos principales dentro del orbe.',
              ),
            ),
          )
        else
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final a in chart.aspects.take(16))
                  PrismListRow(
                    dense: true,
                    leading: SizedBox(
                      width: 30,
                      child: Center(
                        child: AstroGlyph(
                          aspectNames[a.type.index].glyph,
                          size: 18,
                          color: a.type.harmonious == false
                              ? theme.colorScheme.tertiary
                              : accent,
                        ),
                      ),
                    ),
                    title: Text(aspectLabel(a, es)),
                    subtitle: Text(aspectMeaning(a, es)),
                  ),
              ],
            ),
          ),
        PrismSectionHeader(
          title: tr(
            context,
            'ELEMENTS & MODALITIES',
            'ELEMENTOS Y MODALIDADES',
          ),
        ),
        AstroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in AstroElement.values)
                _BalanceBar(
                  label: '${e.emoji} ${e.label.of(es)}',
                  value: balance.elements[e]!,
                  max: balance.elements.values.reduce(math.max),
                  color: accent,
                ),
              const SizedBox(height: 8),
              for (final m in Modality.values)
                _BalanceBar(
                  label: m.label.of(es),
                  value: balance.modalities[m]!,
                  max: balance.modalities.values.reduce(math.max),
                  color: theme.colorScheme.tertiary,
                ),
              const SizedBox(height: 8),
              Text(
                es
                    ? 'Más presente: ${balance.dominantElement.label.es} (${balance.dominantElement.meaning.es}). Menos presente: ${balance.weakestElement.label.es}.'
                    : 'Strongest: ${balance.dominantElement.label.en} (${balance.dominantElement.meaning.en}). Least present: ${balance.weakestElement.label.en}.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
        const AstroDisclaimer(),
      ],
    );
  }
}

class _BalanceBar extends StatelessWidget {
  const _BalanceBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });
  final String label;
  final double value;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: prismCorners(context, 4),
              ),
              child: FractionallySizedBox(
                widthFactor: max == 0 ? 0 : (value / max).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: prismCorners(context, 4),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              value.round().toString(),
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Unlock extends StatelessWidget {
  const _Unlock({required this.access, required this.needsYear});
  final AstroAccess access;
  final bool needsYear;

  @override
  Widget build(BuildContext context) {
    final b = access.birth!;
    final missing = [
      if (!b.hasYear) tr(context, 'birth year', 'año de nacimiento'),
      if (!b.hasTime) tr(context, 'birth time', 'hora de nacimiento'),
      if (!b.hasPlace) tr(context, 'birthplace', 'lugar de nacimiento'),
    ];
    return PrismSurface(
      tone: PrismSurfaceTone.accent,
      accentColor: alterAccent(context, access),
      onTap: access.isOwner
          ? () => showBirthDetails(context, access.member.id)
          : null,
      child: Row(
        children: [
          Icon(
            PhosphorIcons.lockKeyOpen(),
            color: alterAccent(context, access),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              needsYear
                  ? tr(
                      context,
                      'Add the ${missing.join(', ')} to unlock the full birth chart. Nothing is guessed.',
                      'Añade ${missing.join(', ')} para desbloquear la carta completa. No se adivina nada.',
                    )
                  : tr(
                      context,
                      'Add your ${missing.join(' and ')} to unlock your Rising sign and complete birth chart.',
                      'Añade ${missing.join(' y ')} para desbloquear tu ascendente y la carta natal completa.',
                    ),
            ),
          ),
          if (access.isOwner) Icon(PhosphorIcons.caretRight(), size: 16),
        ],
      ),
    );
  }
}

/// The interactive natal wheel: signs around the edge, houses, planets and
/// aspect lines, with the Ascendant on the left as is traditional.
class _ChartWheel extends StatelessWidget {
  const _ChartWheel({
    required this.chart,
    required this.accent,
    required this.onTapBody,
    required this.onTapAngle,
  });
  final NatalChart chart;
  final Color accent;
  final ValueChanged<Body> onTapBody;
  final ValueChanged<ChartPoint> onTapAngle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final es = astroEs(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(box.maxWidth, box.maxHeight);
        final layout = _WheelLayout(chart, size);
        return Semantics(
          label: tr(context, 'Birth chart wheel', 'Rueda de la carta natal'),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final hit = layout.hitTest(d.localPosition);
              if (hit is Body) onTapBody(hit);
              if (hit is ChartPoint) onTapAngle(hit);
            },
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.square(size),
                  painter: _WheelPainter(layout, scheme, accent),
                ),
                // Invisible buttons for screen readers.
                for (final e in layout.bodyPos.entries)
                  Positioned(
                    left: e.value.dx - 16,
                    top: e.value.dy - 16,
                    width: 32,
                    height: 32,
                    child: Semantics(
                      button: true,
                      label:
                          '${planets[e.key]!.name.of(es)} ${formatPosition(chart.positions[e.key]!.longitude, es)}',
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WheelLayout {
  _WheelLayout(this.chart, this.size) {
    center = Offset(size / 2, size / 2);
    outer = size / 2 - 2;
    signInner = outer - size * 0.11;
    planetR = signInner - size * 0.09;
    aspectR = planetR - size * 0.08;
    rotation = chart.angles?.ascendant ?? 0;
    // Spread planets that sit close together so their glyphs don't overlap.
    final sorted = [
      for (final b in Body.values) (b, chart.positions[b]!.longitude),
    ]..sort((x, y) => x.$2.compareTo(y.$2));
    final minGap = 360 * 0.034 * (380 / size).clamp(0.8, 1.6);
    final display = {for (final s in sorted) s.$1: s.$2};
    for (var pass = 0; pass < 6; pass++) {
      for (var i = 0; i < sorted.length; i++) {
        final a = sorted[i].$1, b = sorted[(i + 1) % sorted.length].$1;
        final gap = norm360(display[b]! - display[a]!);
        if (gap < minGap) {
          final push = (minGap - gap) / 2;
          display[a] = display[a]! - push;
          display[b] = display[b]! + push;
        }
      }
    }
    for (final e in display.entries) {
      bodyPos[e.key] = point(e.value, planetR);
    }
  }

  final NatalChart chart;
  final double size;
  late final Offset center;
  late final double outer, signInner, planetR, aspectR, rotation;
  final Map<Body, Offset> bodyPos = {};

  Offset point(double longitude, double r) {
    final t = (180 + longitude - rotation) * math.pi / 180;
    return Offset(center.dx + r * math.cos(t), center.dy - r * math.sin(t));
  }

  Object? hitTest(Offset p) {
    Object? best;
    var bestD = size * 0.07;
    for (final e in bodyPos.entries) {
      final d = (e.value - p).distance;
      if (d < bestD) {
        bestD = d;
        best = e.key;
      }
    }
    final a = chart.angles;
    if (a != null) {
      for (final (pt, lon) in [
        (ChartPoint.ascendant, a.ascendant),
        (ChartPoint.midheaven, a.midheaven),
      ]) {
        final d = (point(lon, outer + 4 - size * 0.05) - p).distance;
        if (d < bestD) {
          bestD = d;
          best = pt;
        }
      }
    }
    return best;
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.l, this.scheme, this.accent);
  final _WheelLayout l;
  final ColorScheme scheme;
  final Color accent;

  void _text(Canvas c, String s, Offset at, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = scheme.outlineVariant;
    final c = l.center;
    // Sign ring, tinted by element.
    for (var s = 0; s < 12; s++) {
      final el = signs[s].element;
      final tint = switch (el) {
        AstroElement.fire => scheme.primary,
        AstroElement.earth => scheme.tertiary,
        AstroElement.air => scheme.secondary,
        AstroElement.water => accent,
      };
      final start = (180 + s * 30 - l.rotation) * math.pi / 180;
      final path = Path()
        ..arcTo(
          Rect.fromCircle(center: c, radius: l.outer),
          -start,
          -30 * math.pi / 180,
          true,
        )
        ..arcTo(
          Rect.fromCircle(center: c, radius: l.signInner),
          -start - 30 * math.pi / 180,
          30 * math.pi / 180,
          false,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = tint.withValues(alpha: 0.10));
      canvas.drawLine(
        l.point(s * 30.0, l.signInner),
        l.point(s * 30.0, l.outer),
        line,
      );
      _text(
        canvas,
        signs[s].glyph,
        l.point(s * 30.0 + 15, (l.outer + l.signInner) / 2),
        astroGlyphStyle(l.size * 0.05, tint),
      );
    }
    canvas.drawCircle(c, l.outer, line);
    canvas.drawCircle(c, l.signInner, line);
    canvas.drawCircle(
      c,
      l.aspectR,
      line..color = scheme.outlineVariant.withValues(alpha: 0.6),
    );

    // Houses.
    final a = l.chart.angles;
    if (a != null) {
      for (var h = 0; h < 12; h++) {
        final cusp = a.cusps[h];
        final angular = h % 3 == 0;
        canvas.drawLine(
          l.point(cusp, l.aspectR),
          l.point(cusp, l.signInner),
          Paint()
            ..strokeWidth = angular ? 1.8 : 0.8
            ..color = angular
                ? accent.withValues(alpha: 0.75)
                : scheme.outlineVariant,
        );
        final next = a.cusps[(h + 1) % 12];
        final mid = cusp + norm360(next - cusp) / 2;
        _text(
          canvas,
          '${h + 1}',
          l.point(mid, l.aspectR + l.size * 0.03),
          TextStyle(fontSize: l.size * 0.026, color: scheme.onSurfaceVariant),
        );
      }
      for (final (label, lon) in [('AC', a.ascendant), ('MC', a.midheaven)]) {
        _text(
          canvas,
          label,
          l.point(lon, l.signInner - l.size * 0.035),
          TextStyle(
            fontSize: l.size * 0.03,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        );
      }
    }

    // Aspect lines.
    for (final asp in l.chart.aspects) {
      if (asp.type == AspectType.conjunction) continue;
      final p1 = l.point(l.chart.positions[asp.a]!.longitude, l.aspectR);
      final p2 = l.point(l.chart.positions[asp.b]!.longitude, l.aspectR);
      final tense = asp.type.harmonious == false;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = 1.2
          ..color = (tense ? scheme.error : scheme.primary).withValues(
            alpha: (0.25 + 0.5 * (1 - asp.orb / 8)).clamp(0.2, 0.75),
          ),
      );
    }

    // Planets: a tick at the true degree, the glyph at its spread position.
    for (final b in Body.values) {
      final pos = l.chart.positions[b]!;
      canvas.drawLine(
        l.point(pos.longitude, l.signInner),
        l.point(pos.longitude, l.signInner - l.size * 0.02),
        Paint()
          ..color = scheme.onSurface
          ..strokeWidth = 1.2,
      );
      final at = l.bodyPos[b]!;
      canvas.drawCircle(
        at,
        l.size * 0.032,
        Paint()..color = scheme.surfaceContainerHigh,
      );
      final uncertain = l.chart.uncertainSigns.containsKey(b);
      _text(
        canvas,
        planets[b]!.glyph,
        at,
        astroGlyphStyle(
          l.size * 0.045,
          uncertain ? scheme.onSurfaceVariant : scheme.onSurface,
        ),
      );
      if (pos.retrograde) {
        _text(
          canvas,
          'R',
          at + Offset(l.size * 0.03, l.size * 0.025),
          TextStyle(
            fontSize: l.size * 0.022,
            color: scheme.error,
            fontWeight: FontWeight.w700,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.l.chart != l.chart ||
      old.l.size != l.size ||
      old.scheme != scheme ||
      old.accent != accent;
}
