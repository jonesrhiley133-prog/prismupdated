import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/engine/chart.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';

/// A point read in the chart: a body, or the Ascendant / Midheaven.
enum ChartPoint { body, ascendant, midheaven }

/// The reading for one placement: planet → sign → house → meaning.
class PlacementReading {
  const PlacementReading({
    required this.title,
    required this.glyph,
    required this.meaning,
    required this.inSign,
    required this.facets,
    required this.focusFacets,
    this.inHouse,
    this.note,
  });

  final String title;
  final String glyph;

  /// What the planet or point represents.
  final String meaning;

  /// What the sign adds.
  final String inSign;

  /// What the house adds (with a birth time and place).
  final String? inHouse;

  /// Retrograde / uncertainty / approximation notes.
  final String? note;

  final Map<Facet, String> facets;

  /// The areas this placement speaks to most.
  final List<Facet> focusFacets;
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

PlacementReading readBody(
  Body body,
  int sign,
  bool es, {
  int? house,
  bool retrograde = false,
  int? otherSign,
}) {
  final p = planets[body]!;
  final s = signs[sign];
  final title = es
      ? '${p.name.es} en ${s.name.es}'
      : '${p.name.en} in ${s.name.en}';
  final inSign = es
      ? 'En ${s.name.es}: esta posición se asocia tradicionalmente con ${s.keywords.es}. ${_cap(p.short.es)} tiende a expresarse ${s.style.es}.'
      : 'In ${s.name.en}: this placement is traditionally associated with ${s.keywords.en}. ${_cap(p.short.en)} tends to be expressed ${s.style.en}.';
  final notes = <String>[
    if (retrograde)
      es
          ? '${p.name.es} estaba retrógrado: tradicionalmente se lee como una energía más interior y reflexiva.'
          : '${p.name.en} was retrograde, traditionally read as a more inward, reflective expression.',
    if (otherSign != null)
      es
          ? 'Sin la hora exacta de nacimiento, podría estar en ${signs[otherSign].name.es}. Añade la hora para confirmarlo.'
          : 'Without an exact birth time this could be ${signs[otherSign].name.en}. Add the birth time to confirm.',
    if (body.approximate)
      es
          ? 'La posición de Quirón es aproximada (±1–2°).'
          : 'Chiron\'s position is approximate (±1–2°).',
  ];
  return PlacementReading(
    title: title,
    glyph: p.glyph,
    meaning: p.meaning.of(es),
    inSign: inSign,
    inHouse: house == null ? null : _houseLine(house, es),
    note: notes.isEmpty ? null : notes.join(' '),
    facets: {for (final f in Facet.values) f: s.facets[f]!.of(es)},
    focusFacets: p.facets,
  );
}

PlacementReading readAngle(ChartPoint point, int sign, bool es) {
  final s = signs[sign];
  final asc = point == ChartPoint.ascendant;
  final name = asc
      ? (es ? 'Ascendente' : 'Rising')
      : (es ? 'Medio Cielo' : 'Midheaven');
  final title = es ? '$name en ${s.name.es}' : '$name in ${s.name.en}';
  final meaning = asc
      ? (es
            ? 'El Ascendente (signo ascendente) representa las primeras impresiones, el estilo exterior y cómo te acercas a lo nuevo.'
            : 'The Rising sign (Ascendant) represents first impressions, outward style and how you approach new situations.')
      : (es
            ? 'El Medio Cielo representa la dirección vital, las metas y cómo te gustaría ser reconocido.'
            : 'The Midheaven represents life direction, goals and how you\'d like to be recognised.');
  final inSign = es
      ? 'En ${s.name.es}: se asocia tradicionalmente con ${s.keywords.es}, y con acercarse al mundo ${s.style.es}.'
      : 'In ${s.name.en}: traditionally associated with ${s.keywords.en}, and with meeting the world ${s.style.en}.';
  return PlacementReading(
    title: title,
    glyph: asc ? 'AC' : 'MC',
    meaning: meaning,
    inSign: inSign,
    facets: {for (final f in Facet.values) f: s.facets[f]!.of(es)},
    focusFacets: asc
        ? const [Facet.personality, Facet.social]
        : const [Facet.motivation, Facet.growth],
  );
}

String _houseLine(int house, bool es) {
  final h = houses[house - 1];
  return es
      ? 'En la casa ${houseOrdinal(house, true)}: esta energía se relaciona tradicionalmente con ${h.area.es}.'
      : 'In the ${houseOrdinal(house, false)} house: this energy is traditionally linked with ${h.area.en}.';
}

/// How the four elements and three modalities are spread across a chart
/// (personal points count double).
class ChartBalance {
  ChartBalance(this.elements, this.modalities);
  final Map<AstroElement, double> elements;
  final Map<Modality, double> modalities;

  AstroElement get dominantElement =>
      elements.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  Modality get dominantModality =>
      modalities.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  AstroElement get weakestElement =>
      elements.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
}

ChartBalance balanceOf(NatalChart chart) {
  final el = {for (final e in AstroElement.values) e: 0.0};
  final mo = {for (final m in Modality.values) m: 0.0};
  void add(int sign, double w) {
    el[signs[sign].element] = el[signs[sign].element]! + w;
    mo[signs[sign].modality] = mo[signs[sign].modality]! + w;
  }

  for (final b in Body.values) {
    if (b == Body.node || b == Body.chiron) continue;
    if (b == Body.moon && !chart.moonCertain) continue;
    final w = b.isLuminary || b.isPersonal ? 2.0 : 1.0;
    add(chart.positions[b]!.sign, w);
  }
  final r = chart.risingSign;
  if (r != null) add(r, 2);
  return ChartBalance(el, mo);
}

/// A few sentences summarising a chart.
String chartSummary(NatalChart chart, String name, bool es) {
  final sun = signs[chart.sunSign];
  final parts = <String>[];
  final moon = chart.moonCertain ? signs[chart.moonSign] : null;
  final rising = chart.risingSign == null ? null : signs[chart.risingSign!];
  if (es) {
    parts.add(
      '$name tiene el Sol en ${sun.name.es}${moon == null ? '' : ', la Luna en ${moon.name.es}'}${rising == null ? '' : ' y ascendente ${rising.name.es}'}.',
    );
    parts.add('El Sol en ${sun.name.es} se asocia con ${sun.keywords.es}.');
    if (moon != null)
      parts.add(
        'La Luna en ${moon.name.es} sugiere necesidades emocionales ligadas a ${moon.keywords.es}.',
      );
    if (rising != null)
      parts.add(
        'Con ascendente ${rising.name.es}, la primera impresión suele ser de alguien que actúa ${rising.style.es}.',
      );
  } else {
    parts.add(
      '$name has the Sun in ${sun.name.en}${moon == null ? '' : ', the Moon in ${moon.name.en}'}${rising == null ? '' : ' and ${rising.name.en} rising'}.',
    );
    parts.add('A ${sun.name.en} Sun is associated with ${sun.keywords.en}.');
    if (moon != null)
      parts.add(
        'A ${moon.name.en} Moon suggests emotional needs tied to ${moon.keywords.en}.',
      );
    if (rising != null)
      parts.add(
        'With ${rising.name.en} rising, first impressions often come across ${rising.style.en}.',
      );
  }
  final bal = balanceOf(chart);
  final de = bal.dominantElement, dm = bal.dominantModality;
  parts.add(
    es
        ? 'El elemento más presente es ${de.label.es} (${de.meaning.es}) y la modalidad ${dm.label.es.toLowerCase()} (${dm.meaning.es}).'
        : 'The strongest element is ${de.label.en} (${de.meaning.en}) and the strongest modality is ${dm.label.en.toLowerCase()} (${dm.meaning.en}).',
  );
  return parts.join(' ');
}

/// "Venus trine Mars" style label for an aspect.
String aspectLabel(Aspect a, bool es) {
  final n = aspectNames[a.type.index].name.of(es);
  final pa = planets[a.a]!.name.of(es), pb = planets[a.b]!.name.of(es);
  return '$pa $n $pb';
}

String aspectMeaning(Aspect a, bool es) {
  final info = aspectNames[a.type.index];
  final pa = planets[a.a]!, pb = planets[a.b]!;
  return es
      ? '${_cap(pa.short.es)} y ${pb.short.es} ${info.meaning.es} (orbe ${a.orb.toStringAsFixed(1)}°).'
      : '${_cap(pa.short.en)} and ${pb.short.en} ${info.meaning.en} (orb ${a.orb.toStringAsFixed(1)}°).';
}
