import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/engine/chart.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';

/// How two charts meet in one area. Deliberately words, not a score:
/// relationships aren't stats.
enum CompatTone {
  flowing(Bi('Flowing', 'Fluido'), '🌊'),
  complementary(Bi('Complementary', 'Complementario'), '🧩'),
  mixed(Bi('Mixed', 'Mixto'), '🌗'),
  growing(Bi('Growing edge', 'Por trabajar'), '🌱'),
  unknown(Bi('Not enough birth data', 'Faltan datos de nacimiento'), '❔');

  const CompatTone(this.label, this.emoji);
  final Bi label;
  final String emoji;
}

enum CompatArea {
  emotional('❤️', Bi('Emotional connection', 'Conexión emocional')),
  communication('🗣️', Bi('Communication', 'Comunicación')),
  friendship('🤝', Bi('Friendship', 'Amistad')),
  creativity('🎨', Bi('Creativity', 'Creatividad')),
  energy('🔥', Bi('Energy', 'Energía')),
  understanding('🧠', Bi('Understanding', 'Comprensión')),
  moon('🌙', Bi('Emotional compatibility', 'Compatibilidad emocional'));

  const CompatArea(this.emoji, this.label);
  final String emoji;
  final Bi label;
}

class SynastryAspect {
  const SynastryAspect(this.a, this.b, this.type, this.orb);
  final String a;
  final String b;
  final AspectType type;
  final double orb;
}

class CompatReading {
  CompatReading({
    required this.headline,
    required this.summary,
    required this.basics,
    required this.areas,
    required this.aspects,
    required this.advanced,
  });

  final String headline;
  final String summary;

  /// Sun ↔ Sun, Moon ↔ Moon, Rising ↔ Rising, element and modality.
  final List<(String, String)> basics;
  final Map<CompatArea, (CompatTone, String)> areas;
  final List<SynastryAspect> aspects;

  /// Both full charts were available.
  final bool advanced;
}

/// Same element flows; fire–air and earth–water complement; the rest mix
/// or ask for effort.
CompatTone elementTone(AstroElement a, AstroElement b) {
  if (a == b) return CompatTone.flowing;
  final pair = {a, b};
  if (pair.containsAll([AstroElement.fire, AstroElement.air]) ||
      pair.containsAll([AstroElement.earth, AstroElement.water])) {
    return CompatTone.complementary;
  }
  if (pair.containsAll([AstroElement.fire, AstroElement.earth]) ||
      pair.containsAll([AstroElement.air, AstroElement.water])) {
    return CompatTone.mixed;
  }
  return CompatTone.growing;
}

String _toneLine(CompatTone t, Bi area, bool es) => switch (t) {
  CompatTone.flowing =>
    es
        ? 'En ${area.es.toLowerCase()} las cosas tienden a fluir con naturalidad.'
        : 'Things tend to flow naturally in ${area.en.toLowerCase()}.',
  CompatTone.complementary =>
    es
        ? 'En ${area.es.toLowerCase()} os completáis: cada uno aporta lo que al otro le falta.'
        : 'You complement each other in ${area.en.toLowerCase()} — each brings what the other lacks.',
  CompatTone.mixed =>
    es
        ? 'En ${area.es.toLowerCase()} hay puntos fáciles y otros que piden paciencia.'
        : '${area.en} has easy spots and others that need patience.',
  CompatTone.growing =>
    es
        ? 'En ${area.es.toLowerCase()} quizá necesitéis más paciencia y conversaciones claras.'
        : '${area.en} may need more patience and clear conversations.',
  CompatTone.unknown =>
    es
        ? 'Añade más datos de nacimiento para leer esta área.'
        : 'Add more birth data to read this area.',
};

Map<String, double> _points(AstroSubject s) {
  final c = s.chart;
  if (c == null) return {'sun': s.sunSign * 30.0 + 15};
  return {
    for (final b in const [
      Body.sun,
      Body.moon,
      Body.mercury,
      Body.venus,
      Body.mars,
      Body.jupiter,
      Body.saturn,
    ])
      if (b != Body.moon || c.moonCertain) b.name: c.positions[b]!.longitude,
    if (c.angles != null) 'asc': c.angles!.ascendant,
  };
}

CompatReading compareCharts(AstroSubject a, AstroSubject b, bool es) {
  final pa = _points(a), pb = _points(b);
  final advanced = a.chart != null && b.chart != null;
  final aspects = <SynastryAspect>[];
  if (advanced) {
    for (final x in pa.entries) {
      for (final y in pb.entries) {
        final bx =
            Body.values.where((v) => v.name == x.key).firstOrNull ?? Body.sun;
        final by =
            Body.values.where((v) => v.name == y.key).firstOrNull ?? Body.sun;
        final hit = aspectBetween(x.value, y.value, bx, by, scale: 0.75);
        if (hit != null)
          aspects.add(SynastryAspect(x.key, y.key, hit.$1, hit.$2));
      }
    }
    aspects.sort((m, n) => m.orb.compareTo(n.orb));
  }

  double weight(SynastryAspect s) {
    final str = (1 - s.orb / 8).clamp(0.2, 1.0);
    return switch (s.type.harmonious) {
      true => str,
      false => -0.8 * str,
      null =>
        (s.a == 'saturn' || s.b == 'saturn' || s.a == 'mars' && s.b == 'mars')
            ? -0.3 * str
            : 0.6 * str,
    };
  }

  CompatTone toneFrom(double score, {CompatTone fallback = CompatTone.mixed}) {
    if (score > 1.0) return CompatTone.flowing;
    if (score > 0.3) return CompatTone.complementary;
    if (score < -0.3) return CompatTone.growing;
    return score == 0 ? fallback : CompatTone.mixed;
  }

  double sumWhere(bool Function(SynastryAspect) f) =>
      aspects.where(f).fold(0.0, (t, s) => t + weight(s));
  bool has(SynastryAspect s, String k) => s.a == k || s.b == k;

  final sunEl = elementTone(signs[a.sunSign].element, signs[b.sunSign].element);
  final moonA = a.chart != null && a.chart!.moonCertain
      ? a.chart!.moonSign
      : null;
  final moonB = b.chart != null && b.chart!.moonCertain
      ? b.chart!.moonSign
      : null;
  final moonEl = moonA != null && moonB != null
      ? elementTone(signs[moonA].element, signs[moonB].element)
      : null;

  final areas = <CompatArea, (CompatTone, String)>{};
  void set(CompatArea area, CompatTone t, [String? extra]) =>
      areas[area] = (t, [_toneLine(t, area.label, es), ?extra].join(' '));

  if (advanced) {
    set(
      CompatArea.emotional,
      toneFrom(
        sumWhere(
          (s) =>
              has(s, 'moon') ||
              (has(s, 'venus') && (has(s, 'sun') || has(s, 'moon'))),
        ),
        fallback: moonEl ?? sunEl,
      ),
    );
    set(
      CompatArea.communication,
      toneFrom(sumWhere((s) => has(s, 'mercury')), fallback: sunEl),
    );
    set(
      CompatArea.friendship,
      toneFrom(
        sumWhere(
          (s) =>
              (has(s, 'sun') && (has(s, 'jupiter') || has(s, 'venus'))) ||
              (s.a == 'sun' && s.b == 'sun'),
        ),
        fallback: sunEl,
      ),
    );
    set(
      CompatArea.creativity,
      toneFrom(sumWhere((s) => has(s, 'venus')), fallback: sunEl),
    );
    set(
      CompatArea.energy,
      toneFrom(sumWhere((s) => has(s, 'mars')), fallback: sunEl),
    );
    set(
      CompatArea.understanding,
      toneFrom(
        sumWhere(
          (s) =>
              has(s, 'saturn') ||
              (has(s, 'mercury') && has(s, 'moon')) ||
              (has(s, 'sun') && has(s, 'moon')),
        ),
        fallback: sunEl,
      ),
    );
  } else {
    for (final area in [
      CompatArea.emotional,
      CompatArea.communication,
      CompatArea.friendship,
      CompatArea.creativity,
      CompatArea.energy,
      CompatArea.understanding,
    ]) {
      set(area, sunEl);
    }
  }
  if (moonEl != null) {
    set(
      CompatArea.moon,
      moonEl,
      es
          ? 'Luna en ${signs[moonA!].name.es} y Luna en ${signs[moonB!].name.es}.'
          : 'A ${signs[moonA!].name.en} Moon and a ${signs[moonB!].name.en} Moon.',
    );
  } else {
    set(CompatArea.moon, CompatTone.unknown);
  }

  final basics = <(String, String)>[
    (
      es ? 'Sol ↔ Sol' : 'Sun ↔ Sun',
      '${signs[a.sunSign].glyph} ${signs[a.sunSign].name.of(es)} · ${signs[b.sunSign].glyph} ${signs[b.sunSign].name.of(es)} — ${sunEl.label.of(es)}',
    ),
    if (moonA != null && moonB != null)
      (
        es ? 'Luna ↔ Luna' : 'Moon ↔ Moon',
        '${signs[moonA].name.of(es)} · ${signs[moonB].name.of(es)} — ${moonEl!.label.of(es)}',
      ),
    if (a.chart?.risingSign != null && b.chart?.risingSign != null)
      (
        es ? 'Ascendente ↔ Ascendente' : 'Rising ↔ Rising',
        '${signs[a.chart!.risingSign!].name.of(es)} · ${signs[b.chart!.risingSign!].name.of(es)} — ${elementTone(signs[a.chart!.risingSign!].element, signs[b.chart!.risingSign!].element).label.of(es)}',
      ),
    (
      es ? 'Elementos' : 'Elements',
      '${signs[a.sunSign].element.label.of(es)} + ${signs[b.sunSign].element.label.of(es)}',
    ),
    (
      es ? 'Modalidades' : 'Modalities',
      signs[a.sunSign].modality == signs[b.sunSign].modality
          ? (es
                ? 'Ambos ${signs[a.sunSign].modality.label.es.toLowerCase()}: ritmo parecido; ojo con chocar.'
                : 'Both ${signs[a.sunSign].modality.label.en.toLowerCase()}: a similar pace — watch for clashes.')
          : (es
                ? '${signs[a.sunSign].modality.label.es} + ${signs[b.sunSign].modality.label.es}: ritmos que se complementan.'
                : '${signs[a.sunSign].modality.label.en} + ${signs[b.sunSign].modality.label.en}: paces that complement each other.'),
    ),
  ];

  final tones = areas.values
      .map((v) => v.$1)
      .where((t) => t != CompatTone.unknown)
      .toList();
  final flowing = tones
      .where((t) => t == CompatTone.flowing || t == CompatTone.complementary)
      .length;
  final growing = tones.where((t) => t == CompatTone.growing).length;
  final headline = flowing >= tones.length * 0.7
      ? (es ? 'Dinámica fuerte' : 'Strong dynamic')
      : flowing > growing
      ? (es ? 'Dinámica complementaria' : 'Complementary dynamic')
      : growing > flowing
      ? (es ? 'Dinámica de aprendizaje' : 'A learning dynamic')
      : (es ? 'Dinámica equilibrada' : 'Balanced dynamic');
  final summary = es
      ? '${advanced ? 'Vuestras cartas comparten varias posiciones complementarias' : 'Vuestros signos solares se combinan de forma ${sunEl.label.es.toLowerCase()}'}${growing > 0 ? ', con algunas áreas donde la comunicación puede pedir más paciencia' : ''}. Es una lectura astrológica para reflexionar, no un veredicto sobre la relación.'
      : '${advanced ? 'Your charts share several complementary placements' : 'Your Sun signs combine in a ${sunEl.label.en.toLowerCase()} way'}${growing > 0 ? ', with some areas where communication may need more patience' : ''}. This is an astrological reflection, not a verdict on the relationship.';

  return CompatReading(
    headline: headline,
    summary: summary,
    basics: basics,
    areas: areas,
    aspects: aspects,
    advanced: advanced,
  );
}
