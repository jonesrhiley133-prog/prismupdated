import 'package:prism_plurality/features/astro/content/compat.dart';
import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/interpret.dart';
import 'package:prism_plurality/features/astro/content/tarot.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';
import 'package:prism_plurality/features/astro/engine/events.dart';
import 'package:prism_plurality/features/astro/engine/places.dart'
    show foldForSearch;

class AskAnswer {
  const AskAnswer(this.text, {this.suggestions = const []});
  final String text;
  final List<String> suggestions;
}

/// Example questions for the empty state and follow-ups.
List<String> askExamples(bool es) => es
    ? [
        '¿Qué representa mi signo lunar?',
        'Explica mi carta natal',
        '¿Qué significa Venus en Libra?',
        'Dame una lectura para hoy',
        '¿Qué planetas están retrógrados?',
        '¿Qué es la casa 7?',
      ]
    : [
        'What does my Moon sign represent?',
        'Explain my birth chart',
        'What does Venus in Libra mean?',
        'Give me a reflective reading for today',
        'Which planets are retrograde?',
        'What is the 7th house?',
      ];

/// Answers astrology questions on the device, from Prism's interpretation
/// library and the alter's own chart. Nothing is sent anywhere.
///
/// [others] are alters (or people) whose charts this alter may see, for
/// "compare my chart with …".
AskAnswer askAstro(
  String question,
  AstroSubject? me,
  bool es, {
  Map<String, AstroSubject> others = const {},
  String? memberId,
}) {
  final q = foldForSearch(question);
  bool has(List<String> words) => words.any(q.contains);

  int? signIn(String text) {
    for (var i = 0; i < 12; i++) {
      if (text.contains(foldForSearch(signs[i].name.en)) ||
          text.contains(foldForSearch(signs[i].name.es)))
        return i;
    }
    return null;
  }

  Body? bodyIn(String text) {
    for (final b in Body.values) {
      final p = planets[b]!;
      if (RegExp('\\b${foldForSearch(p.name.en)}\\b').hasMatch(text) ||
          RegExp('\\b${foldForSearch(p.name.es)}\\b').hasMatch(text))
        return b;
    }
    return null;
  }

  final noChart = AskAnswer(
    es
        ? 'Para eso necesito al menos el cumpleaños de este alter. Añádelo en su perfil de Astro.'
        : 'I need at least this alter\'s birthday for that. Add it in their Astro profile.',
  );

  // Compare with someone.
  if (has(['compar', 'compat', 'synastry', 'sinastria'])) {
    if (me == null) return noChart;
    for (final e in others.entries) {
      if (q.contains(foldForSearch(e.key))) {
        final r = compareCharts(me, e.value, es);
        final lines = [
          '${r.headline}.',
          r.summary,
          for (final a in r.areas.entries)
            '${a.key.emoji} ${a.key.label.of(es)}: ${a.value.$1.label.of(es)}.',
        ];
        return AskAnswer(
          lines.join('\n'),
          suggestions: [
            es ? 'Explica mi carta natal' : 'Explain my birth chart',
          ],
        );
      }
    }
    return AskAnswer(
      others.isEmpty
          ? (es
                ? 'No hay otras cartas visibles para comparar. Cada alter decide quién puede ver la suya.'
                : 'There are no other visible charts to compare with. Each alter decides who can see theirs.')
          : (es
                ? '¿Con quién? Puedo comparar con: ${others.keys.join(', ')}.'
                : 'With whom? I can compare with: ${others.keys.join(', ')}.'),
      suggestions: [
        for (final n in others.keys.take(3))
          es ? 'Compara mi carta con $n' : 'Compare my chart with $n',
      ],
    );
  }

  // "What does Venus in Libra mean?"
  final body = bodyIn(q);
  final sign = signIn(
    q.replaceAll(RegExp(r'\bsol\b'), ''),
  ); // "sol" isn't a sign
  if (body != null && sign != null) {
    final r = readBody(body, sign, es);
    return AskAnswer(
      '${r.title}\n\n${r.meaning}\n\n${r.inSign}\n\n${Facet.personality.label.of(es)}: ${r.facets[Facet.personality]}',
    );
  }

  final today = DateTime.now();
  if (has(['retrograd'])) {
    final now = today.toUtc();
    final retro = [
      for (final b in Body.values)
        if (positionOf(b, now).retrograde) planets[b]!.name.of(es),
    ];
    return AskAnswer(
      (es
              ? 'Retrógrado significa que, visto desde la Tierra, un planeta parece moverse hacia atrás. Es un efecto óptico; tradicionalmente se lee como un momento para revisar lo que ese planeta representa. '
              : 'Retrograde means a planet appears to move backwards as seen from Earth. It\'s an optical effect; traditionally it\'s read as a time to review whatever that planet represents. ') +
          (retro.isEmpty
              ? (es
                    ? 'Ahora mismo no hay ningún planeta retrógrado.'
                    : 'Right now, no planets are retrograde.')
              : (es
                    ? 'Ahora mismo están retrógrados: ${retro.join(', ')}.'
                    : 'Retrograde right now: ${retro.join(', ')}.')),
    );
  }

  if (has(['moon phase', 'fase lunar', 'fase de la luna', 'phase'])) {
    final p = phaseForDay(today);
    final ms = moonSignForDay(today);
    return AskAnswer(
      '${p.glyph} ${phaseName(p, es)} ${es ? 'en' : 'in'} ${signs[ms.sign].name.of(es)}. ${phaseTraditional(p, es)}',
    );
  }

  final houseMatch = RegExp(
    r'(\d{1,2})\s*(st|nd|rd|th)?\s*(house)|casa\s*(\d{1,2})',
  ).firstMatch(q);
  if (houseMatch != null) {
    final n =
        int.tryParse(houseMatch.group(1) ?? houseMatch.group(4) ?? '') ?? 0;
    if (n >= 1 && n <= 12) {
      final h = houses[n - 1];
      return AskAnswer(
        es
            ? 'La casa ${houseOrdinal(n, true)} se relaciona tradicionalmente con ${h.area.es}.'
            : 'The ${houseOrdinal(n, false)} house is traditionally linked with ${h.area.en}.',
      );
    }
  }

  if (has(['tarot', 'card', 'carta del dia'])) {
    if (memberId == null)
      return AskAnswer(
        es
            ? 'Elige un alter para sacar su carta del día.'
            : 'Pick an alter to draw their card of the day.',
      );
    final d = dailyCard(memberId, today);
    return AskAnswer(
      '${d.card.name.of(es)}${d.reversed ? (es ? ' (invertida)' : ' (reversed)') : ''}\n${d.card.meaningOf(d.reversed, es)}',
    );
  }

  if (has([
    'today',
    'hoy',
    'reading',
    'lectura',
    'horoscop',
    'tomorrow',
    'manana',
  ])) {
    if (me == null) return noChart;
    final tomorrow = has(['tomorrow', 'manana']);
    final r = dailyReading(
      me,
      tomorrow ? today.add(const Duration(days: 1)) : today,
      es,
    );
    return AskAnswer(
      [
        '${r.title} · ${es ? 'Energía' : 'Energy'} ${r.energy}%',
        r.parts[ReadingPart.overall]!,
        '${ReadingPart.focus.label.of(es)}: ${r.parts[ReadingPart.focus]}',
        '${ReadingPart.reflection.label.of(es)}: ${r.parts[ReadingPart.reflection]}',
      ].join('\n\n'),
    );
  }

  if (has([
    'chart',
    'carta natal',
    'birth',
    'nacimiento',
    'explain',
    'explica',
  ])) {
    if (me == null) return noChart;
    final c = me.chart;
    if (c == null) {
      return AskAnswer(
        es
            ? '${me.name} es ${signs[me.sunSign].name.es}. Añade el año, la hora y el lugar de nacimiento para ver la carta completa.'
            : '${me.name} is a ${signs[me.sunSign].name.en}. Add the birth year, time and place to see the full chart.',
      );
    }
    final top = c.aspects
        .take(3)
        .map((a) => '• ${aspectLabel(a, es)}: ${aspectMeaning(a, es)}')
        .join('\n');
    return AskAnswer(
      [
        chartSummary(c, me.name, es),
        if (top.isNotEmpty)
          '${es ? 'Aspectos más cercanos' : 'Tightest aspects'}:\n$top',
        if (c.angles == null)
          es
              ? 'Añade la hora y el lugar de nacimiento para desbloquear el ascendente y las casas.'
              : 'Add the birth time and birthplace to unlock the Rising sign and houses.',
      ].join('\n\n'),
    );
  }

  if (has(['element', 'elemento'])) {
    if (me?.chart == null) return noChart;
    final b = balanceOf(me!.chart!);
    final lines = [
      for (final e in AstroElement.values)
        '${e.emoji} ${e.label.of(es)}: ${b.elements[e]!.round()}',
    ];
    return AskAnswer(
      '${lines.join('\n')}\n\n${es ? 'Más fuerte' : 'Strongest'}: ${b.dominantElement.label.of(es)} — ${b.dominantElement.meaning.of(es)}.',
    );
  }

  if (has([
    'aspect',
    'aspecto',
    'trine',
    'trigono',
    'square',
    'cuadratura',
    'sextil',
    'opposition',
    'oposicion',
    'conjunction',
    'conjuncion',
  ])) {
    return AskAnswer(
      [
        for (final a in aspectNames)
          '${a.glyph} ${a.name.of(es)}: ${a.meaning.of(es)}',
      ].join('\n'),
    );
  }

  // "What does my Moon sign represent?" / "my Venus"
  final point = has(['rising', 'ascend', 'asc '])
      ? 'asc'
      : body?.name ??
            (has([
                  'sun sign',
                  'signo solar',
                  'zodiac',
                  'zodiaco',
                  'my sign',
                  'mi signo',
                ])
                ? 'sun'
                : null);
  if (point != null) {
    if (me == null) return noChart;
    final c = me.chart;
    if (point == 'asc') {
      final r = c?.risingSign;
      if (r == null) {
        return AskAnswer(
          es
              ? 'El ascendente necesita la hora y el lugar exactos de nacimiento. Añádelos para desbloquearlo.'
              : 'The Rising sign needs an exact birth time and birthplace. Add them to unlock it.',
        );
      }
      final reading = readAngle(ChartPoint.ascendant, r, es);
      return AskAnswer(
        '${reading.title}\n\n${reading.meaning}\n\n${reading.inSign}',
      );
    }
    final b = Body.values.byName(point);
    if (c == null && b != Body.sun) {
      return AskAnswer(
        es
            ? 'Añade el año de nacimiento para calcular esa posición.'
            : 'Add the birth year to calculate that placement.',
      );
    }
    final s = c?.positions[b]!.sign ?? me.sunSign;
    final reading = readBody(
      b,
      s,
      es,
      house: c?.houseOf(b),
      retrograde: c?.positions[b]!.retrograde ?? false,
      otherSign: c?.uncertainSigns[b],
    );
    return AskAnswer(
      [
        reading.title,
        reading.meaning,
        reading.inSign,
        ?reading.inHouse,
        ?reading.note,
      ].join('\n\n'),
    );
  }

  return AskAnswer(
    es
        ? 'Puedo explicar signos, planetas, casas y aspectos, leer la carta de este alter, dar la lectura de hoy, la fase lunar o comparar cartas. Prueba con una de estas:'
        : 'I can explain signs, planets, houses and aspects, read this alter\'s chart, give today\'s reading or the moon phase, or compare charts. Try one of these:',
    suggestions: askExamples(es),
  );
}
