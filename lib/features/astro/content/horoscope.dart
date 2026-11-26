import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/engine/chart.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';
import 'package:prism_plurality/features/astro/engine/events.dart';

/// Who a reading is for: a chart when the birth year is known, otherwise
/// just the Sun sign (readings then use solar houses, counted from the Sun
/// sign — the traditional approach for Sun-sign horoscopes).
class AstroSubject {
  AstroSubject({
    required this.name,
    required this.sunSign,
    this.chart,
    this.seed = 0,
  });

  final String name;
  final int sunSign;
  final NatalChart? chart;

  /// Varies wording between alters on the same day.
  final int seed;

  bool get hasHouses => chart?.angles != null;

  int houseOf(double longitude) =>
      chart?.angles?.houseOf(longitude) ??
      ((signOf(longitude) - sunSign) % 12 + 1);

  /// Natal points transits are measured against.
  Map<String, double> get points {
    final c = chart;
    if (c == null) return {'sun': sunSign * 30.0 + 15};
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
      if (c.angles != null) 'mc': c.angles!.midheaven,
    };
  }
}

String pointName(String key, bool es) => switch (key) {
  'asc' => es ? 'Ascendente' : 'Ascendant',
  'mc' => es ? 'Medio Cielo' : 'Midheaven',
  _ => planets[Body.values.byName(key)]!.name.of(es),
};

String pointShort(String key, bool es) => switch (key) {
  'asc' => es ? 'tu forma de presentarte' : 'how you show up',
  'mc' => es ? 'tus metas' : 'your goals',
  _ => planets[Body.values.byName(key)]!.short.of(es),
};

/// The six reflection energies. Astrology-themed prompts for noticing how a
/// day feels — not a measurement of anything.
enum EnergyKind {
  mental(
    '🧠',
    Bi('Mental', 'Mental'),
    Bi(
      'Focus, thoughtfulness, mental activity',
      'Concentración, reflexión, actividad mental',
    ),
  ),
  emotional(
    '❤️',
    Bi('Emotional', 'Emocional'),
    Bi(
      'Emotional intensity and sensitivity',
      'Intensidad y sensibilidad emocional',
    ),
  ),
  social(
    '🗣️',
    Bi('Social', 'Social'),
    Bi('Desire for interaction', 'Ganas de interactuar'),
  ),
  creative(
    '🎨',
    Bi('Creative', 'Creativa'),
    Bi('Creativity and inspiration', 'Creatividad e inspiración'),
  ),
  physical(
    '🏃',
    Bi('Physical', 'Física'),
    Bi('General activity and energy', 'Actividad y energía general'),
  ),
  reflective(
    '🔮',
    Bi('Reflective', 'Reflexiva'),
    Bi('Introspection and self-reflection', 'Introspección y autorreflexión'),
  );

  const EnergyKind(this.emoji, this.label, this.description);
  final String emoji;
  final Bi label;
  final Bi description;
}

enum ReadingPart {
  overall('☀️', Bi('Today\'s energy', 'Energía del día')),
  emotions('💭', Bi('Emotions', 'Emociones')),
  relationships('❤️', Bi('Relationships', 'Relaciones')),
  social('🗣️', Bi('Social energy', 'Energía social')),
  creativity('🎨', Bi('Creativity', 'Creatividad')),
  productivity('📋', Bi('Productivity', 'Productividad')),
  challenge('🌧️', Bi('Challenge', 'Desafío')),
  opportunity('🌈', Bi('Opportunity', 'Oportunidad')),
  reflection('🧠', Bi('Reflection prompt', 'Pregunta para reflexionar')),
  focus('🎯', Bi('Focus for the day', 'Enfoque del día')),
  activity('🌱', Bi('Suggested activity', 'Actividad sugerida')),
  message('✨', Bi('Cosmic message', 'Mensaje cósmico'));

  const ReadingPart(this.emoji, this.label);
  final String emoji;
  final Bi label;
}

class TransitHit {
  const TransitHit(this.transit, this.natal, this.type, this.orb);
  final Body transit;
  final String natal;
  final AspectType type;
  final double orb;

  bool get harmonious =>
      type.harmonious ??
      !(transit == Body.saturn ||
          transit == Body.pluto ||
          transit == Body.mars);

  String label(bool es) =>
      '${planets[transit]!.name.of(es)} ${aspectNames[type.index].name.of(es).toLowerCase()} ${es ? '' : 'natal '}${pointName(natal, es)}${es ? ' natal' : ''}';

  String meaning(bool es) => _cap(_meaning(es));

  String _meaning(bool es) {
    final t = planets[transit]!.short.of(es), n = pointShort(natal, es);
    return switch (type) {
      AspectType.conjunction =>
        es
            ? 'Hoy $t se une a $n y lo intensifica.'
            : 'Today $t meets $n and turns up the volume.',
      AspectType.trine || AspectType.sextile =>
        es
            ? 'Un buen momento para que $n reciba el apoyo de $t.'
            : 'A good moment for $n to get support from $t.',
      AspectType.square =>
        es
            ? '$t puede presionar a $n: ve con calma y date margen.'
            : '$t may press on $n — go gently and leave yourself some room.',
      AspectType.opposition =>
        es
            ? '$t y $n tiran en direcciones distintas; busca un punto medio.'
            : '$t and $n pull in different directions; look for a middle ground.',
    };
  }
}

class DayReading {
  DayReading({
    required this.day,
    required this.title,
    required this.scores,
    required this.moonSign,
    required this.moonNextSign,
    required this.moonChange,
    required this.phase,
    required this.sunSign,
    required this.moonHouse,
    required this.transits,
    required this.parts,
    required this.emotionalFocus,
  });

  final DateTime day;
  final String title;
  final Map<EnergyKind, int> scores;
  final int moonSign;
  final int? moonNextSign;
  final DateTime? moonChange;
  final MoonPhase phase;
  final int sunSign;
  final int moonHouse;
  final List<TransitHit> transits;
  final Map<ReadingPart, String> parts;
  final String emotionalFocus;

  /// Overall energy, 0–100: the average of the six.
  int get energy =>
      (scores.values.reduce((a, b) => a + b) / scores.length).round();
}

int _hash(int a, int b) {
  var h = a * 31 + b;
  h = (h ^ (h >> 15)) * 2246822519;
  h = h ^ (h >> 13);
  return h.abs();
}

T _pick<T>(List<T> list, int seed) => list[seed % list.length];

/// Transits to [subject]'s chart at [utc] (orbs tightened for moving days).
List<TransitHit> transitsAt(AstroSubject subject, DateTime utc) {
  final hits = <TransitHit>[];
  final pts = subject.points;
  for (final t in const [
    Body.moon,
    Body.sun,
    Body.mercury,
    Body.venus,
    Body.mars,
    Body.jupiter,
    Body.saturn,
    Body.uranus,
    Body.neptune,
    Body.pluto,
  ]) {
    final lon = longitudeOf(t, utc);
    final scale = switch (t) {
      Body.moon => 0.6,
      Body.sun || Body.mercury || Body.venus || Body.mars => 0.3,
      _ => 0.18,
    };
    for (final e in pts.entries) {
      final natalBody =
          Body.values.where((b) => b.name == e.key).firstOrNull ?? Body.sun;
      final hit = aspectBetween(lon, e.value, t, natalBody, scale: scale);
      if (hit != null) hits.add(TransitHit(t, e.key, hit.$1, hit.$2));
    }
  }
  hits.sort((a, b) => a.orb.compareTo(b.orb));
  return hits;
}

DayReading dailyReading(AstroSubject subject, DateTime localDay, bool es) {
  final day = DateTime(localDay.year, localDay.month, localDay.day);
  final noon = day.add(const Duration(hours: 12)).toUtc();
  final moon = moonSignForDay(day);
  final moonLon = longitudeOf(Body.moon, noon);
  final moonSign = signOf(moonLon);
  final phase = phaseForDay(day);
  final sunSign = signOf(longitudeOf(Body.sun, noon));
  final house = subject.houseOf(moonLon);
  final hits = transitsAt(subject, noon);
  final seed = _hash(subject.seed, day.year * 400 + day.month * 32 + day.day);
  final moonEl = signs[moonSign].element;

  // Scores: a calm baseline nudged by the Moon and the day's transits.
  final s = {for (final k in EnergyKind.values) k: 50.0};
  void add(EnergyKind k, double v) => s[k] = s[k]! + v;
  switch (moonEl) {
    case AstroElement.fire:
      add(EnergyKind.physical, 14);
      add(EnergyKind.creative, 8);
    case AstroElement.earth:
      add(EnergyKind.physical, 6);
      add(EnergyKind.mental, 6);
      add(EnergyKind.reflective, 4);
    case AstroElement.air:
      add(EnergyKind.mental, 12);
      add(EnergyKind.social, 12);
    case AstroElement.water:
      add(EnergyKind.emotional, 14);
      add(EnergyKind.reflective, 8);
      add(EnergyKind.creative, 6);
  }
  switch (house) {
    case 1:
      add(EnergyKind.physical, 8);
    case 3:
      add(EnergyKind.mental, 8);
      add(EnergyKind.social, 4);
    case 5:
      add(EnergyKind.creative, 12);
    case 6 || 10:
      add(EnergyKind.mental, 6);
      add(EnergyKind.physical, 4);
    case 7 || 11:
      add(EnergyKind.social, 12);
    case 8:
      add(EnergyKind.emotional, 10);
    case 4 || 12:
      add(EnergyKind.reflective, 12);
      add(EnergyKind.social, -8);
    case 9:
      add(EnergyKind.mental, 6);
      add(EnergyKind.creative, 4);
  }
  // Waxing builds outward energy; waning turns inward.
  final waxing = phase.index > 0 && phase.index < 4;
  final waning = phase.index > 4;
  if (waxing) add(EnergyKind.physical, 4);
  if (waning) add(EnergyKind.reflective, 6);
  if (phase == MoonPhase.fullMoon) add(EnergyKind.emotional, 10);
  if (phase == MoonPhase.newMoon) add(EnergyKind.reflective, 8);
  for (final h in hits.take(8)) {
    final w =
        (h.harmonious ? 1 : -1) *
        (h.transit == Body.moon ? 5.0 : 7.0) *
        (1 - h.orb / 6).clamp(0.3, 1);
    final kinds = switch (h.transit) {
      Body.sun => [EnergyKind.physical],
      Body.moon => [EnergyKind.emotional],
      Body.mercury => [EnergyKind.mental, EnergyKind.social],
      Body.venus => [EnergyKind.social, EnergyKind.creative],
      Body.mars => [EnergyKind.physical],
      Body.jupiter => [
        EnergyKind.creative,
        EnergyKind.social,
        EnergyKind.mental,
      ],
      Body.saturn => [EnergyKind.physical],
      Body.uranus => [EnergyKind.mental],
      Body.neptune => [EnergyKind.creative],
      _ => [EnergyKind.emotional],
    };
    for (final k in kinds) {
      add(k, w);
    }
    // Tense days often turn thoughts inward.
    if (!h.harmonious) add(EnergyKind.reflective, 4);
  }
  final scores = {
    for (final e in s.entries) e.key: e.value.round().clamp(12, 96),
  };

  final h = houses[house - 1];
  final title = _pick(h.titles, seed).of(es);
  final top = scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final second =
      (scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))[1]
          .key;
  final emotionalFocus = '${_focusWord(top, es)} + ${_focusWord(second, es)}';

  final good =
      hits.where((x) => x.harmonious && x.transit != Body.moon).firstOrNull ??
      hits.where((x) => x.harmonious).firstOrNull;
  final hard =
      hits.where((x) => !x.harmonious && x.transit != Body.moon).firstOrNull ??
      hits.where((x) => !x.harmonious).firstOrNull;
  final venus = hits
      .where((x) => x.transit == Body.venus || x.natal == 'venus')
      .firstOrNull;
  final mercuryRetro = positionOf(Body.mercury, noon).retrograde;

  final ms = signs[moonSign];
  final parts = <ReadingPart, String>{
    ReadingPart.overall: [
      _moonMood[moonSign].of(es),
      es
          ? 'La Luna pasa por tu casa ${houseOrdinal(house, true)}${subject.hasHouses ? '' : ' solar'}, que se relaciona con ${h.area.es}.'
          : 'The Moon moves through your ${houseOrdinal(house, false)}${subject.hasHouses ? '' : ' solar'} house, linked with ${h.area.en}.',
      _phaseMeaning[phase.index].of(es),
    ].join(' '),
    ReadingPart.emotions: _emotionLine(moonEl, house, es),
    ReadingPart.relationships: venus != null
        ? '${venus.meaning(es)} ${_relLine(moonEl, es)}'
        : _relLine(moonEl, es),
    ReadingPart.social: _socialLine(house, es),
    ReadingPart.creativity: _creativeLine(
      moonEl,
      hits.any((x) => x.transit == Body.neptune || x.transit == Body.venus),
      es,
    ),
    ReadingPart.productivity: [
      _productivityLine(ms.modality, es),
      if (mercuryRetro)
        es
            ? 'Mercurio está retrógrado: buen momento para repasar y revisar antes de enviar.'
            : 'Mercury is retrograde — a good time to review and double-check before sending.',
    ].join(' '),
    ReadingPart.challenge: hard != null
        ? '${hard.label(es)}. ${hard.meaning(es)}'
        : (es
              ? 'No hay tensiones fuertes hoy: aprovecha la calma.'
              : 'No strong tensions today — enjoy the calm.'),
    ReadingPart.opportunity: good != null
        ? '${good.label(es)}. ${good.meaning(es)}'
        : _pick(_opportunities, seed).of(es),
    ReadingPart.reflection: _pick(_reflections[house - 1], seed >> 3).of(es),
    ReadingPart.focus: _focus[house - 1].of(es),
    ReadingPart.activity: _pick(_activities[house - 1], seed >> 5).of(es),
    ReadingPart.message: _pick(_messages, seed >> 7).of(es),
  };

  return DayReading(
    day: day,
    title: title,
    scores: scores,
    moonSign: moon.sign,
    moonNextSign: moon.nextSign,
    moonChange: moon.changeAt,
    phase: phase,
    sunSign: sunSign,
    moonHouse: house,
    transits: hits,
    parts: parts,
    emotionalFocus: emotionalFocus,
  );
}

String _focusWord(EnergyKind k, bool es) => switch (k) {
  EnergyKind.mental => es ? 'claridad' : 'clarity',
  EnergyKind.emotional => es ? 'sensibilidad' : 'sensitivity',
  EnergyKind.social => es ? 'conexión' : 'connection',
  EnergyKind.creative => es ? 'creatividad' : 'creativity',
  EnergyKind.physical => es ? 'movimiento' : 'movement',
  EnergyKind.reflective => es ? 'introspección' : 'introspection',
};

// ---------------------------------------------------------------------------
// Sky events and longer readings
// ---------------------------------------------------------------------------

enum SkyEventKind { lunation, eclipse, ingress, station, transit, birthday }

class SkyEvent {
  const SkyEvent(
    this.kind,
    this.utc,
    this.glyph,
    this.title,
    this.detail, {
    this.personal = false,
    this.body,
  });
  final SkyEventKind kind;

  /// The moving planet, for ingresses, stations and transits.
  final Body? body;
  final DateTime utc;
  final String glyph;
  final String title;
  final String detail;

  /// About this subject's chart (not the whole sky).
  final bool personal;
}

String phaseName(MoonPhase p, bool es) => switch (p) {
  MoonPhase.newMoon => es ? 'Luna nueva' : 'New Moon',
  MoonPhase.waxingCrescent => es ? 'Luna creciente' : 'Waxing Crescent',
  MoonPhase.firstQuarter => es ? 'Cuarto creciente' : 'First Quarter',
  MoonPhase.waxingGibbous => es ? 'Gibosa creciente' : 'Waxing Gibbous',
  MoonPhase.fullMoon => es ? 'Luna llena' : 'Full Moon',
  MoonPhase.waningGibbous => es ? 'Gibosa menguante' : 'Waning Gibbous',
  MoonPhase.lastQuarter => es ? 'Cuarto menguante' : 'Third Quarter',
  MoonPhase.waningCrescent => es ? 'Luna menguante' : 'Waning Crescent',
};

String phaseThemeTitle(MoonPhase p, bool es) => _phaseThemes[p.index].of(es);

String phaseTraditional(MoonPhase p, bool es) => _phaseMeaning[p.index].of(es);

/// Every notable sky event between [from] and [to]; with [subject], also
/// the exact transits to their chart.
List<SkyEvent> skyEvents(
  DateTime from,
  DateTime to,
  bool es, {
  AstroSubject? subject,
  bool includeMoonSigns = false,
}) {
  final out = <SkyEvent>[];
  for (final l in lunations(from, to)) {
    final s = signs[l.sign];
    final name = l.eclipse == Eclipse.solar
        ? (es ? 'Eclipse solar' : 'Solar eclipse')
        : l.eclipse == Eclipse.lunar
        ? (es ? 'Eclipse lunar' : 'Lunar eclipse')
        : phaseName(l.phase, es);
    final house = subject?.houseOf(l.longitude);
    out.add(
      SkyEvent(
        l.eclipse == Eclipse.none
            ? SkyEventKind.lunation
            : SkyEventKind.eclipse,
        l.utc,
        l.phase.glyph,
        es ? '$name en ${s.name.es}' : '$name in ${s.name.en}',
        [
          _phaseMeaning[l.phase.index].of(es),
          if (l.eclipse != Eclipse.none)
            es
                ? 'Los eclipses se leen tradicionalmente como puntos de inflexión.'
                : 'Eclipses are traditionally read as turning points.',
          if (house != null)
            es
                ? 'Para ${subject!.name}: activa la casa ${houseOrdinal(house, true)}, ${houses[house - 1].theme.es}.'
                : 'For ${subject!.name}: lights up the ${houseOrdinal(house, false)} house, ${houses[house - 1].theme.en}.',
        ].join(' '),
      ),
    );
  }
  for (final b in [
    if (includeMoonSigns) Body.moon,
    Body.sun,
    Body.mercury,
    Body.venus,
    Body.mars,
    Body.jupiter,
    Body.saturn,
    Body.uranus,
    Body.neptune,
    Body.pluto,
  ]) {
    for (final i in ingresses(b, from, to)) {
      final p = planets[b]!, s = signs[i.sign];
      out.add(
        SkyEvent(
          SkyEventKind.ingress,
          i.utc,
          p.glyph,
          es
              ? '${p.name.es} entra en ${s.name.es}'
              : '${p.name.en} enters ${s.name.en}',
          es
              ? '${_cap(p.short.es)} se tiñe de ${s.keywords.es}.'
              : '${_cap(p.short.en)} takes on ${s.keywords.en}.',
          body: b,
        ),
      );
    }
  }
  for (final b in [
    Body.mercury,
    Body.venus,
    Body.mars,
    Body.jupiter,
    Body.saturn,
    Body.uranus,
    Body.neptune,
    Body.pluto,
  ]) {
    for (final st in stations(b, from, to)) {
      final p = planets[b]!;
      out.add(
        SkyEvent(
          SkyEventKind.station,
          st.utc,
          p.glyph,
          st.toRetrograde
              ? (es
                    ? '${p.name.es} retrógrado'
                    : '${p.name.en} turns retrograde')
              : (es ? '${p.name.es} directo' : '${p.name.en} turns direct'),
          st.toRetrograde
              ? (es
                    ? 'Tradicionalmente, un tiempo para revisar ${p.short.es}.'
                    : 'Traditionally a time to review ${p.short.en}.')
              : (es
                    ? '${_cap(p.short.es)} vuelve a avanzar.'
                    : '${_cap(p.short.en)} moves forward again.'),
          body: b,
        ),
      );
    }
  }
  if (subject != null) out.addAll(exactTransits(subject, from, to, es));
  out.sort((a, b) => a.utc.compareTo(b.utc));
  return out;
}

/// Days a transiting planet makes an exact aspect to a natal point.
List<SkyEvent> exactTransits(
  AstroSubject subject,
  DateTime from,
  DateTime to,
  bool es, {
  List<Body>? bodies,
}) {
  final out = <SkyEvent>[];
  final pts = subject.points;
  final list =
      bodies ??
      const [
        Body.sun,
        Body.mercury,
        Body.venus,
        Body.mars,
        Body.jupiter,
        Body.saturn,
      ];
  for (final t in list) {
    var day = from.toUtc();
    final prev = <String, double>{};
    while (day.isBefore(to)) {
      final lon = longitudeOf(t, day);
      for (final e in pts.entries) {
        for (final a in AspectType.values) {
          final key = '${e.key}/${a.index}';
          final sep = angleDiff(lon, e.value).abs();
          final off = sep - a.angle;
          final p = prev[key];
          if (p != null && (p < 0) != (off < 0) && (p - off).abs() < 5) {
            final hit = TransitHit(t, e.key, a, 0);
            out.add(
              SkyEvent(
                SkyEventKind.transit,
                day,
                planets[t]!.glyph,
                hit.label(es),
                hit.meaning(es),
                personal: true,
                body: t,
              ),
            );
          }
          prev[key] = off;
        }
      }
      day = day.add(const Duration(days: 1));
    }
  }
  return out;
}

class WeekReading {
  WeekReading(
    this.days,
    this.events,
    this.emotional,
    this.relationships,
    this.summary,
  );
  final List<DayReading> days;
  final List<SkyEvent> events;
  final String emotional;
  final String relationships;
  final String summary;

  List<SkyEvent> get important => [
    for (final e in events)
      if (e.kind == SkyEventKind.lunation ||
          e.kind == SkyEventKind.eclipse ||
          e.personal ||
          e.kind == SkyEventKind.station)
        e,
  ];
}

WeekReading weeklyReading(AstroSubject subject, DateTime weekStart, bool es) {
  final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final days = [
    for (var i = 0; i < 7; i++)
      dailyReading(subject, start.add(Duration(days: i)), es),
  ];
  final events = skyEvents(
    start.toUtc(),
    start.add(const Duration(days: 7)).toUtc(),
    es,
    subject: subject,
  );
  final avg = {
    for (final k in EnergyKind.values)
      k: days.map((d) => d.scores[k]!).reduce((a, b) => a + b) / 7,
  };
  final top = avg.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final best = days.reduce(
    (a, b) =>
        a.scores[EnergyKind.social]! >= b.scores[EnergyKind.social]! ? a : b,
  );
  final calm = days.reduce(
    (a, b) =>
        a.scores[EnergyKind.reflective]! >= b.scores[EnergyKind.reflective]!
        ? a
        : b,
  );
  final waterDays = days
      .where((d) => signs[d.moonSign].element == AstroElement.water)
      .length;
  String dayName(DateTime d) => es
      ? const [
          'lunes',
          'martes',
          'miércoles',
          'jueves',
          'viernes',
          'sábado',
          'domingo',
        ][d.weekday - 1]
      : const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ][d.weekday - 1];
  final emotional = es
      ? 'La Luna pasa $waterDays ${waterDays == 1 ? 'día' : 'días'} en signos de agua esta semana. El día más introspectivo parece el ${dayName(calm.day)}; date espacio entonces.'
      : 'The Moon spends $waterDays ${waterDays == 1 ? 'day' : 'days'} in water signs this week. ${dayName(calm.day)} looks the most inward — leave room for quiet then.';
  final relationships = es
      ? 'El ${dayName(best.day)} parece el día más sociable: buen momento para quedar o escribir a alguien.'
      : '${dayName(best.day)} looks the most sociable — a good day to reach out or make plans.';
  final summary = es
      ? 'Una semana con tono de ${_focusWord(top, true)}. ${events.where((e) => e.kind == SkyEventKind.lunation || e.kind == SkyEventKind.eclipse).map((e) => e.title).join(', ')}'
      : 'A week with a tone of ${_focusWord(top, false)}. ${events.where((e) => e.kind == SkyEventKind.lunation || e.kind == SkyEventKind.eclipse).map((e) => e.title).join(', ')}';
  return WeekReading(days, events, emotional, relationships, summary.trim());
}

class MonthReading {
  MonthReading(
    this.month,
    this.theme,
    this.events,
    this.areas,
    this.retrogrades,
  );
  final DateTime month;
  final String theme;
  final List<SkyEvent> events;
  final Map<String, String> areas;

  /// Planets retrograde at some point this month.
  final List<Body> retrogrades;
}

MonthReading monthlyReading(AstroSubject subject, DateTime month, bool es) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  final mid = start.add(const Duration(days: 15)).toUtc();
  final events = skyEvents(start.toUtc(), end.toUtc(), es, subject: subject);
  final sunHouse = subject.houseOf(longitudeOf(Body.sun, mid));
  final venusHouse = subject.houseOf(longitudeOf(Body.venus, mid));
  final marsHouse = subject.houseOf(longitudeOf(Body.mars, mid));
  final mercuryHouse = subject.houseOf(longitudeOf(Body.mercury, mid));
  final jupiterHouse = subject.houseOf(longitudeOf(Body.jupiter, mid));
  final retro = [
    for (final b in [
      Body.mercury,
      Body.venus,
      Body.mars,
      Body.jupiter,
      Body.saturn,
      Body.uranus,
      Body.neptune,
      Body.pluto,
    ])
      if (positionOf(b, start.toUtc()).retrograde ||
          positionOf(b, mid).retrograde ||
          positionOf(b, end.toUtc()).retrograde)
        b,
  ];
  String area(int h) => houses[h - 1].theme.of(es);
  final theme = es
      ? 'Este mes el Sol ilumina tu casa ${houseOrdinal(sunHouse, true)}: ${area(sunHouse)}. Es un buen periodo para prestar atención a ${houses[sunHouse - 1].area.es}.'
      : 'This month the Sun lights up your ${houseOrdinal(sunHouse, false)} house: ${area(sunHouse)}. A good stretch for paying attention to ${houses[sunHouse - 1].area.en}.';
  final areas = <String, String>{
    es ? 'Relaciones' : 'Relationships': es
        ? 'Venus pasa por tu casa ${houseOrdinal(venusHouse, true)} (${area(venusHouse)}): el cariño y el disfrute se encuentran ahí.'
        : 'Venus moves through your ${houseOrdinal(venusHouse, false)} house (${area(venusHouse)}) — affection and enjoyment gather there.',
    es ? 'Creatividad' : 'Creativity': es
        ? 'La inspiración llega a través de ${area(venusHouse)} y ${area(sunHouse)}.'
        : 'Inspiration comes through ${area(venusHouse)} and ${area(sunHouse)}.',
    es ? 'Estudios y trabajo' : 'School & work': es
        ? 'Marte impulsa tu casa ${houseOrdinal(marsHouse, true)} (${area(marsHouse)}) y Mercurio la ${houseOrdinal(mercuryHouse, true)} (${area(mercuryHouse)}): ahí va la energía y la atención.'
        : 'Mars drives your ${houseOrdinal(marsHouse, false)} house (${area(marsHouse)}) and Mercury your ${houseOrdinal(mercuryHouse, false)} (${area(mercuryHouse)}) — that\'s where effort and attention flow.',
    es ? 'Crecimiento personal' : 'Personal growth': es
        ? 'Júpiter sigue en tu casa ${houseOrdinal(jupiterHouse, true)}: ${area(jupiterHouse)} es un terreno para crecer.'
        : 'Jupiter is in your ${houseOrdinal(jupiterHouse, false)} house: ${area(jupiterHouse)} is fertile ground for growth.',
  };
  return MonthReading(start, theme, events, areas, retro);
}

class YearReading {
  YearReading(
    this.year,
    this.themes,
    this.events,
    this.growth,
    this.reflection,
    this.birthday,
  );
  final int year;
  final List<String> themes;
  final List<SkyEvent> events;

  /// Supportive stretches (Jupiter harmonious transits).
  final List<SkyEvent> growth;

  /// Slower, reflective stretches (Saturn tense transits, retrogrades).
  final List<SkyEvent> reflection;

  /// The solar return: when the Sun comes back to the natal Sun.
  final DateTime? birthday;
}

YearReading yearlyReading(AstroSubject subject, int year, bool es) {
  final start = DateTime.utc(year), end = DateTime.utc(year + 1);
  final all = skyEvents(start, end, es);
  // The year's big picture: eclipses, every station (Mercury retrogrades
  // included) and slow-planet sign changes.
  const fast = {Body.sun, Body.mercury, Body.venus, Body.moon};
  final events = [
    for (final e in all)
      if (e.kind == SkyEventKind.eclipse ||
          e.kind == SkyEventKind.station ||
          (e.kind == SkyEventKind.ingress && !fast.contains(e.body)))
        e,
  ];
  final slow = exactTransits(
    subject,
    start,
    end,
    es,
    bodies: const [
      Body.jupiter,
      Body.saturn,
      Body.uranus,
      Body.neptune,
      Body.pluto,
    ],
  );
  events
    ..addAll(slow)
    ..sort((a, b) => a.utc.compareTo(b.utc));
  final growth = [
    for (final e in slow)
      if (e.body == Body.jupiter) e,
  ];
  final reflection = [
    for (final e in slow)
      if (e.body == Body.saturn) e,
    for (final e in all)
      if (e.kind == SkyEventKind.station && e.body == Body.mercury) e,
  ]..sort((a, b) => a.utc.compareTo(b.utc));

  final jStart = subject.houseOf(longitudeOf(Body.jupiter, start));
  final jEnd = subject.houseOf(longitudeOf(Body.jupiter, end));
  final sStart = subject.houseOf(longitudeOf(Body.saturn, start));
  final sEnd = subject.houseOf(longitudeOf(Body.saturn, end));
  String hs(int a, int b) => a == b
      ? houseOrdinal(a, es)
      : '${houseOrdinal(a, es)} → ${houseOrdinal(b, es)}';
  String th(int h) => houses[h - 1].theme.of(es);
  final themes = <String>[
    es
        ? 'Crecimiento: Júpiter recorre tu casa ${hs(jStart, jEnd)}, así que ${th(jStart)}${jStart == jEnd ? '' : ' y luego ${th(jEnd)}'} son terreno de expansión este año.'
        : 'Growth: Jupiter moves through your ${hs(jStart, jEnd)} house, so ${th(jStart)}${jStart == jEnd ? '' : ' and then ${th(jEnd)}'} are areas of expansion this year.',
    es
        ? 'Lecciones: Saturno está en tu casa ${hs(sStart, sEnd)}; ${th(sStart)} pide paciencia, estructura y constancia.'
        : 'Lessons: Saturn sits in your ${hs(sStart, sEnd)} house; ${th(sStart)} asks for patience, structure and steady effort.',
    es
        ? 'Relaciones: las lunas nuevas y llenas que caen en tus casas 5, 7 y 11 marcan los momentos clave para los vínculos.'
        : 'Relationships: new and full moons falling in your 5th, 7th and 11th houses mark key moments for connection.',
  ];
  DateTime? birthday;
  final c = subject.chart;
  if (c != null && c.birth.hasYear) {
    final natal = c.positions[Body.sun]!.longitude;
    var t = DateTime.utc(
      year,
      c.birth.month,
      c.birth.day,
    ).subtract(const Duration(days: 3));
    var prev = angleDiff(longitudeOf(Body.sun, t), natal);
    for (var i = 0; i < 8 * 24; i++) {
      final n = t.add(const Duration(hours: 1));
      final cur = angleDiff(longitudeOf(Body.sun, n), natal);
      if (prev < 0 && cur >= 0) {
        birthday = n;
        break;
      }
      prev = cur;
      t = n;
    }
  }
  return YearReading(year, themes, events, growth, reflection, birthday);
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ---------------------------------------------------------------------------
// Text pools
// ---------------------------------------------------------------------------

const _moonMood = [
  Bi(
    'With the Moon in Aries, feelings run quick and bold — a day for honest, direct moves.',
    'Con la Luna en Aries, los sentimientos van rápidos y audaces: un día para movimientos sinceros y directos.',
  ),
  Bi(
    'With the Moon in Taurus, the mood slows down and craves comfort, good food and steady ground.',
    'Con la Luna en Tauro, el ánimo se calma y pide comodidad, buena comida y suelo firme.',
  ),
  Bi(
    'With the Moon in Gemini, curiosity is up and conversations come easily.',
    'Con la Luna en Géminis, la curiosidad sube y las conversaciones fluyen.',
  ),
  Bi(
    'With the Moon in Cancer, feelings run deep and home feels extra important.',
    'Con la Luna en Cáncer, los sentimientos son profundos y el hogar se siente especialmente importante.',
  ),
  Bi(
    'With the Moon in Leo, there\'s warmth in the air and a wish to be seen and to play.',
    'Con la Luna en Leo, hay calidez en el ambiente y ganas de ser visto y de jugar.',
  ),
  Bi(
    'With the Moon in Virgo, small tasks and tidying up can feel surprisingly soothing.',
    'Con la Luna en Virgo, las tareas pequeñas y ordenar pueden resultar sorprendentemente calmantes.',
  ),
  Bi(
    'With the Moon in Libra, harmony matters — company, beauty and fairness lift the mood.',
    'Con la Luna en Libra, importa la armonía: la compañía, la belleza y la justicia levantan el ánimo.',
  ),
  Bi(
    'With the Moon in Scorpio, emotions go deep and honesty feels essential.',
    'Con la Luna en Escorpio, las emociones van hondo y la sinceridad se vuelve esencial.',
  ),
  Bi(
    'With the Moon in Sagittarius, restlessness and optimism call for something new.',
    'Con la Luna en Sagitario, la inquietud y el optimismo piden algo nuevo.',
  ),
  Bi(
    'With the Moon in Capricorn, the mood is practical and focused on getting things done.',
    'Con la Luna en Capricornio, el ánimo es práctico y centrado en hacer las cosas.',
  ),
  Bi(
    'With the Moon in Aquarius, there\'s a pull toward friends, ideas and a little space.',
    'Con la Luna en Acuario, apetecen los amigos, las ideas y un poco de espacio.',
  ),
  Bi(
    'With the Moon in Pisces, sensitivity and imagination are heightened — be gentle with yourself.',
    'Con la Luna en Piscis, la sensibilidad y la imaginación aumentan: trátate con suavidad.',
  ),
];

const _phaseThemes = [
  Bi('Intentions + fresh starts', 'Intenciones y comienzos'),
  Bi('Building momentum', 'Tomar impulso'),
  Bi('Action + decisions', 'Acción y decisiones'),
  Bi('Refining + adjusting', 'Pulir y ajustar'),
  Bi('Release + self-expression', 'Soltar y expresarse'),
  Bi('Gratitude + sharing', 'Gratitud y compartir'),
  Bi('Letting go + reassessing', 'Soltar y reevaluar'),
  Bi('Rest + reflection', 'Descanso y reflexión'),
];

const _phaseMeaning = [
  Bi(
    'The New Moon is traditionally a time for setting intentions and planting seeds.',
    'La Luna nueva es tradicionalmente un momento para fijar intenciones y sembrar.',
  ),
  Bi(
    'The waxing crescent traditionally brings momentum to new beginnings.',
    'La Luna creciente tradicionalmente da impulso a los comienzos.',
  ),
  Bi(
    'The first quarter is traditionally a time for action and decisions.',
    'El cuarto creciente es tradicionalmente un momento de acción y decisiones.',
  ),
  Bi(
    'The waxing gibbous is traditionally a time for refining and adjusting.',
    'La gibosa creciente es tradicionalmente un momento para pulir y ajustar.',
  ),
  Bi(
    'The Full Moon is traditionally a time of culmination, release and heightened feeling.',
    'La Luna llena es tradicionalmente un momento de culminación, liberación y emociones intensas.',
  ),
  Bi(
    'The waning gibbous is traditionally a time for gratitude and sharing what you\'ve learned.',
    'La gibosa menguante es tradicionalmente un momento de gratitud y de compartir lo aprendido.',
  ),
  Bi(
    'The third quarter is traditionally a time for letting go and reassessing.',
    'El cuarto menguante es tradicionalmente un momento para soltar y reevaluar.',
  ),
  Bi(
    'The waning crescent is traditionally a time for rest, reflection and closure.',
    'La Luna menguante es tradicionalmente un momento de descanso, reflexión y cierre.',
  ),
];

String _emotionLine(AstroElement e, int house, bool es) {
  final base = switch (e) {
    AstroElement.fire => const Bi(
      'Feelings come out fast; name them before acting on them.',
      'Los sentimientos salen rápido; nómbralos antes de actuar.',
    ),
    AstroElement.earth => const Bi(
      'Emotions feel steadier when your body is cared for.',
      'Las emociones se estabilizan cuando cuidas tu cuerpo.',
    ),
    AstroElement.air => const Bi(
      'Talking or writing things out may help you process.',
      'Hablar o escribir puede ayudarte a procesar.',
    ),
    AstroElement.water => const Bi(
      'Sensitivity is up; notice what you\'re absorbing from others.',
      'La sensibilidad sube; fíjate en lo que absorbes de los demás.',
    ),
  };
  final extra = house == 4 || house == 12
      ? const Bi(
          ' Quiet time will do you good.',
          ' El tiempo tranquilo te sentará bien.',
        )
      : house == 8
      ? const Bi(
          ' Something deeper may surface — be kind to it.',
          ' Puede aflorar algo más profundo: trátalo con cariño.',
        )
      : const Bi('', '');
  return base.of(es) + extra.of(es);
}

String _relLine(AstroElement e, bool es) => switch (e) {
  AstroElement.fire => const Bi(
    'Give yourself room to be direct and warm.',
    'Date espacio para ser directo y cálido.',
  ),
  AstroElement.earth => const Bi(
    'Show care through small, practical gestures.',
    'Muestra cariño con gestos pequeños y prácticos.',
  ),
  AstroElement.air => const Bi(
    'Give yourself room to communicate honestly.',
    'Date espacio para comunicarte con sinceridad.',
  ),
  AstroElement.water => const Bi(
    'Closeness and listening matter more than words today.',
    'Hoy la cercanía y la escucha importan más que las palabras.',
  ),
}.of(es);

String _socialLine(int house, bool es) => switch (house) {
  7 || 11 => const Bi(
    'Social energy is higher than usual — connection could recharge you.',
    'La energía social está más alta de lo normal: conectar podría recargarte.',
  ),
  4 || 12 => const Bi(
    'Your social battery may run low; it\'s fine to keep plans small.',
    'Tu batería social puede estar baja; está bien hacer planes pequeños.',
  ),
  3 => const Bi(
    'Messages, chats and quick catch-ups suit the day.',
    'Mensajes, charlas y ponerse al día encajan con el día.',
  ),
  5 => const Bi(
    'Fun and playful company would lift the mood.',
    'La compañía divertida levantaría el ánimo.',
  ),
  _ => const Bi(
    'A balanced social day: follow what feels right.',
    'Un día social equilibrado: sigue lo que te parezca bien.',
  ),
}.of(es);

String _creativeLine(AstroElement e, bool boosted, bool es) {
  final base = switch (e) {
    AstroElement.fire => const Bi(
      'Start something bold — a first draft, a sketch, a song idea.',
      'Empieza algo audaz: un borrador, un boceto, una idea de canción.',
    ),
    AstroElement.earth => const Bi(
      'Hands-on making works best: cooking, crafting, building.',
      'Lo manual funciona mejor: cocinar, hacer manualidades, construir.',
    ),
    AstroElement.air => const Bi(
      'Ideas flow; jot them down before they fly away.',
      'Las ideas fluyen; apúntalas antes de que se escapen.',
    ),
    AstroElement.water => const Bi(
      'Music, poetry and daydreams carry extra inspiration.',
      'La música, la poesía y los sueños despiertos traen inspiración extra.',
    ),
  }.of(es);
  return boosted
      ? base +
            (es
                ? ' Venus o Neptuno añaden un toque artístico.'
                : ' Venus or Neptune add an artistic touch.')
      : base;
}

String _productivityLine(Modality m, bool es) => switch (m) {
  Modality.cardinal => const Bi(
    'Good for starting tasks and making the first move.',
    'Bueno para empezar tareas y dar el primer paso.',
  ),
  Modality.fixed => const Bi(
    'Good for steady work and finishing what\'s in progress.',
    'Bueno para el trabajo constante y terminar lo pendiente.',
  ),
  Modality.mutable => const Bi(
    'Good for adjusting plans, sorting and multitasking.',
    'Bueno para ajustar planes, organizar y hacer varias cosas.',
  ),
}.of(es);

const _focus = [
  Bi('Taking care of yourself first.', 'Cuidarte primero.'),
  Bi('What truly matters to you.', 'Lo que de verdad te importa.'),
  Bi('Clear, kind communication.', 'Comunicación clara y amable.'),
  Bi('Home, rest and feeling safe.', 'Hogar, descanso y sentirte a salvo.'),
  Bi('Joy and creative play.', 'Alegría y juego creativo.'),
  Bi('Gentle routines and wellbeing.', 'Rutinas suaves y bienestar.'),
  Bi(
    'Listening and meeting halfway.',
    'Escuchar y encontrarse a medio camino.',
  ),
  Bi('Honesty and trust.', 'Sinceridad y confianza.'),
  Bi('Learning something new.', 'Aprender algo nuevo.'),
  Bi(
    'One meaningful step toward a goal.',
    'Un paso con sentido hacia una meta.',
  ),
  Bi('Friends and community.', 'Amistades y comunidad.'),
  Bi(
    'Quiet recharge and inner listening.',
    'Recarga tranquila y escucha interior.',
  ),
];

const _activities = [
  [
    Bi(
      'Try a small change in your look or routine.',
      'Prueba un pequeño cambio de imagen o de rutina.',
    ),
    Bi('Go for a short walk on your own.', 'Sal a dar un paseo corto a solas.'),
  ],
  [
    Bi(
      'Make yourself something comforting to eat or drink.',
      'Prepárate algo reconfortante para comer o beber.',
    ),
    Bi(
      'Tidy one small space you use every day.',
      'Ordena un pequeño espacio que uses cada día.',
    ),
  ],
  [
    Bi(
      'Message someone you haven\'t talked to in a while.',
      'Escribe a alguien con quien no hablas desde hace tiempo.',
    ),
    Bi('Read or listen to something new.', 'Lee o escucha algo nuevo.'),
  ],
  [
    Bi(
      'Make your space cosier — a blanket, a candle, a playlist.',
      'Haz tu espacio más acogedor: una manta, una vela, una lista de música.',
    ),
    Bi(
      'Look through old photos or memories.',
      'Mira fotos o recuerdos antiguos.',
    ),
  ],
  [
    Bi(
      'Spend twenty minutes on a creative hobby.',
      'Dedica veinte minutos a una afición creativa.',
    ),
    Bi(
      'Play a game or do something just for fun.',
      'Juega a algo o haz algo solo por diversión.',
    ),
  ],
  [
    Bi(
      'Sort out one small task you\'ve been putting off.',
      'Resuelve una tarea pequeña que llevas tiempo aplazando.',
    ),
    Bi(
      'Stretch, drink water and take a proper break.',
      'Estírate, bebe agua y tómate un descanso de verdad.',
    ),
  ],
  [
    Bi(
      'Have a one-to-one chat with someone you trust.',
      'Ten una charla a solas con alguien de confianza.',
    ),
    Bi(
      'Ask someone how they\'re really doing.',
      'Pregúntale a alguien cómo está de verdad.',
    ),
  ],
  [
    Bi(
      'Write about something you\'re ready to let go of.',
      'Escribe sobre algo que estás listo para soltar.',
    ),
    Bi(
      'Have an honest conversation you\'ve been saving.',
      'Ten una conversación sincera que llevas tiempo guardando.',
    ),
  ],
  [
    Bi(
      'Watch a documentary or explore a new topic.',
      'Mira un documental o explora un tema nuevo.',
    ),
    Bi(
      'Plan a small outing or adventure.',
      'Planea una pequeña salida o aventura.',
    ),
  ],
  [
    Bi(
      'Break a goal into three small steps and do the first.',
      'Divide una meta en tres pasos pequeños y haz el primero.',
    ),
    Bi(
      'Update a to-do list or plan your week.',
      'Actualiza una lista de tareas o planifica tu semana.',
    ),
  ],
  [
    Bi(
      'Join a group chat, club or community space.',
      'Únete a un chat de grupo, club o comunidad.',
    ),
    Bi(
      'Share something you\'re excited about with a friend.',
      'Comparte con un amigo algo que te ilusione.',
    ),
  ],
  [
    Bi(
      'Journal, meditate or simply sit quietly for a while.',
      'Escribe en tu diario, medita o simplemente quédate en calma un rato.',
    ),
    Bi(
      'Go to bed a little earlier tonight.',
      'Acuéstate un poco antes esta noche.',
    ),
  ],
];

const _reflections = [
  [
    Bi('How do I want to show up today?', '¿Cómo quiero presentarme hoy?'),
    Bi(
      'What would a fresh start look like right now?',
      '¿Cómo sería un nuevo comienzo ahora mismo?',
    ),
  ],
  [
    Bi('What makes me feel secure?', '¿Qué me hace sentir seguro?'),
    Bi(
      'What do I value that I don\'t say out loud?',
      '¿Qué valoro que no digo en voz alta?',
    ),
  ],
  [
    Bi(
      'What conversation have I been meaning to have?',
      '¿Qué conversación tengo pendiente?',
    ),
    Bi(
      'What am I curious about lately?',
      '¿Qué me causa curiosidad últimamente?',
    ),
  ],
  [
    Bi('Where do I feel most at home?', '¿Dónde me siento más en casa?'),
    Bi(
      'What does rest really look like for me?',
      '¿Cómo es para mí descansar de verdad?',
    ),
  ],
  [
    Bi(
      'When did I last do something just for joy?',
      '¿Cuándo hice algo solo por alegría por última vez?',
    ),
    Bi(
      'What would I create if no one was watching?',
      '¿Qué crearía si nadie me viera?',
    ),
  ],
  [
    Bi(
      'Which small habit is helping me most?',
      '¿Qué pequeño hábito me está ayudando más?',
    ),
    Bi('How is my body feeling today?', '¿Cómo se siente hoy mi cuerpo?'),
  ],
  [
    Bi(
      'What do I need from the people closest to me?',
      '¿Qué necesito de las personas más cercanas?',
    ),
    Bi(
      'Where could I meet someone halfway?',
      '¿Dónde podría encontrarme con alguien a medio camino?',
    ),
  ],
  [
    Bi('What am I ready to let go of?', '¿Qué estoy listo para soltar?'),
    Bi('Who do I trust, and why?', '¿En quién confío y por qué?'),
  ],
  [
    Bi(
      'What gives my life meaning right now?',
      '¿Qué da sentido a mi vida ahora?',
    ),
    Bi(
      'What belief of mine has changed recently?',
      '¿Qué creencia mía ha cambiado últimamente?',
    ),
  ],
  [
    Bi(
      'What is one step toward something I want?',
      '¿Cuál es un paso hacia algo que quiero?',
    ),
    Bi(
      'What am I proud of building?',
      '¿De qué me siento orgulloso de haber construido?',
    ),
  ],
  [
    Bi(
      'Who makes me feel like I belong?',
      '¿Quién me hace sentir que pertenezco?',
    ),
    Bi('What do I hope for in the future?', '¿Qué espero del futuro?'),
  ],
  [
    Bi(
      'What is my inner voice saying today?',
      '¿Qué dice hoy mi voz interior?',
    ),
    Bi('What do I need to forgive myself for?', '¿Qué necesito perdonarme?'),
  ],
];

const _opportunities = [
  Bi(
    'A quiet sky leaves room for your own plans.',
    'Un cielo tranquilo deja espacio para tus propios planes.',
  ),
  Bi(
    'Small, steady steps go further than usual today.',
    'Hoy los pasos pequeños y constantes llegan más lejos.',
  ),
  Bi(
    'A good day to follow your curiosity.',
    'Un buen día para seguir tu curiosidad.',
  ),
];

const _messages = [
  Bi(
    'You don\'t have to have it all figured out to move forward.',
    'No necesitas tenerlo todo claro para avanzar.',
  ),
  Bi(
    'Rest is part of the rhythm, not a break from it.',
    'El descanso es parte del ritmo, no una pausa en él.',
  ),
  Bi(
    'Every part of you deserves patience.',
    'Cada parte de ti merece paciencia.',
  ),
  Bi(
    'Small kindnesses ripple further than you think.',
    'Los pequeños gestos de bondad llegan más lejos de lo que crees.',
  ),
  Bi(
    'Let curiosity lead where certainty can\'t.',
    'Deja que la curiosidad guíe donde la certeza no llega.',
  ),
  Bi(
    'Your feelings are information, not instructions.',
    'Tus sentimientos son información, no órdenes.',
  ),
  Bi(
    'Like the Moon, you\'re allowed to have phases.',
    'Como la Luna, puedes tener fases.',
  ),
  Bi(
    'What grows slowly often grows strong.',
    'Lo que crece despacio suele crecer fuerte.',
  ),
  Bi('You are allowed to take up space.', 'Tienes derecho a ocupar espacio.'),
  Bi(
    'Today asks for honesty, starting with yourself.',
    'Hoy se pide sinceridad, empezando por ti.',
  ),
  Bi(
    'The stars set a mood; you choose what to do with it.',
    'Las estrellas marcan un ambiente; tú decides qué hacer con él.',
  ),
  Bi(
    'Be as gentle with yourself as you would be with a friend.',
    'Sé tan amable contigo como lo serías con un amigo.',
  ),
  Bi(
    'Not every day has to be productive to be worthwhile.',
    'No todos los días tienen que ser productivos para valer la pena.',
  ),
  Bi(
    'Listen for what your quietest part needs.',
    'Escucha lo que necesita tu parte más callada.',
  ),
  Bi(
    'You can begin again at any moment.',
    'Puedes empezar de nuevo en cualquier momento.',
  ),
  Bi(
    'Connection starts with a single honest sentence.',
    'La conexión empieza con una sola frase sincera.',
  ),
];
