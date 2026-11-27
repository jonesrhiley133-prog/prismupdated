import 'package:flutter/painting.dart';
import 'package:prism_plurality/features/seasonal/living_data.dart';
import 'package:prism_plurality/features/seasonal/seasonal_data.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_vocab.dart';

/// Every holiday and season Prism ships, each with 25+ looks. Built once
/// from [seasonalSource]; new collections only need a new block there.
List<SeasonalCollection> get seasonalCollections =>
    _cache ??= _parse(seasonalSource);

List<SeasonalCollection>? _cache;

/// Permanent, year-round aesthetics (80 genres, 25+ looks each). Kept apart
/// from [seasonalCollections] so nothing ever schedules them.
List<SeasonalCollection> get livingCollections =>
    _living ??= _parse(livingSource);

List<SeasonalCollection>? _living;

Map<String, SeasonalCollection>? _byId;

/// A holiday, season or living genre by id.
SeasonalCollection? collectionById(String id) => (_byId ??= {
  for (final c in seasonalCollections) c.id: c,
  for (final c in livingCollections) c.id: c,
})[id];

/// The genres in one living family, in catalog order.
List<SeasonalCollection> livingInGroup(String group) => [
  for (final c in livingCollections)
    if (c.group == group) c,
];

SeasonalVariation? variationById(String id) {
  final i = id.indexOf('.');
  if (i < 0) return null;
  final c = collectionById(id.substring(0, i));
  if (c == null) return null;
  for (final v in c.variations) {
    if (v.id == id) return v;
  }
  return null;
}

/// Picks [n] items starting at [offset], wrapping, so neighbouring looks
/// use different parts of a collection's emoji pool.
List<String> _take(List<String> pool, int offset, int n) => [
  for (var i = 0; i < n && pool.isNotEmpty; i++)
    pool[(offset + i) % pool.length],
];

List<SeasonalCollection> _parse(String src) {
  final out = <SeasonalCollection>[];
  for (final block in src.split(RegExp(r'^@', multiLine: true))) {
    final lines = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;
    final head = lines.first.split('|');
    final id = head[0];
    final kind = SeasonalKind.values.firstWhere((k) => k.name == head[3]);
    final living = kind == SeasonalKind.living;
    String field(String k) =>
        lines
            .where((l) => l.startsWith('$k:'))
            .map((l) => l.substring(k.length + 1).trim())
            .firstOrNull ??
        '';
    List<String> list(String k, [String sep = ',']) => field(k).isEmpty
        ? <String>[]
        : field(
            k,
          ).split(sep).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final garlandPool = list('garland'),
        cornerPool = list('corner'),
        hangerPool = list('hangers'),
        furniturePool = list('furniture');
    final icons = list('icons'), acc = list('acc'), amb = list('amb');
    final d = list('defaults').isEmpty
        ? const ['vine', 'fairy', 'hairline', 'none', 'cluster']
        : list('defaults');
    final defGarland = garlandOf(d[0]),
        defLights = lightsOf(d[1]),
        defBorder = borderOf(d[2]),
        defParticle = particleOf(d[3]),
        defCorner = cornerOf(d[4]);
    if (defGarland == null ||
        defLights == null ||
        defBorder == null ||
        defParticle == null ||
        defCorner == null) {
      throw StateError('Bad defaults for $id: ${d.join(",")}');
    }

    // Traditional colours: every look is redrawn in these, so a holiday
    // never picks up colours that don't belong to it.
    final colors = [
      for (final h in list('colors')) 0xFF000000 | int.parse(h, radix: 16),
    ];
    // Signature styles mixed through the looks so a holiday looks like
    // itself, and its looks don't all share the same defaults.
    final motifs = list('motifs');
    for (final m in motifs) {
      if (decoStyles[m] == null) throw StateError('Unknown motif "$m" in $id');
    }

    final looks = lines.where((l) => l.startsWith('- ')).toList();
    // Living genres list their looks by name and get their parts from the
    // genre's moods and styles, stepping so no two looks pick the same mix.
    final named = list('looks');
    if (named.isNotEmpty) {
      final moods = list('mood').isEmpty
          ? const ['classic', 'midnight', 'pastel', 'bold', 'neon', 'elegant']
          : list('mood');
      final styles = list('styles');
      if (styles.isEmpty) throw StateError('No styles for $id');
      final n = styles.length;
      for (var i = 0; i < named.length; i++) {
        final picks = <String>{
          styles[i % n],
          styles[(i * 3 + 1) % n],
          styles[(i * 5 + 2) % n],
          styles[(i * 7 + 4) % n],
        };
        looks.add(
          '- ${named[i]}|${moods[i % moods.length]},${picks.join(',')}',
        );
      }
    }
    final variations = <SeasonalVariation>[];
    for (var i = 0; i < looks.length; i++) {
      final parts = looks[i].substring(2).split('|');
      final name = parts[0].trim();
      final tags = parts[1].split(',').map((e) => e.trim()).toList();
      DecoPalette? palette;
      GarlandStyle? garland;
      LightsStyle? lights;
      DecoBorder? border;
      ParticleKind? particle;
      CornerStyle? corner;
      for (final t in tags) {
        final pal = decoPalettes[t];
        final sty = decoStyles[t];
        if (pal == null && sty == null)
          throw StateError('Unknown tag "$t" in $id / $name');
        palette ??= pal;
        if (sty != null) {
          garland ??= sty[0] == '-' ? null : garlandOf(sty[0]);
          lights ??= sty[1] == '-' ? null : lightsOf(sty[1]);
          border ??= sty[2] == '-' ? null : borderOf(sty[2]);
          particle ??= sty[3] == '-' ? null : particleOf(sty[3]);
          corner ??= sty[4] == '-' ? null : cornerOf(sty[4]);
        }
      }
      if (palette == null) throw StateError('No palette for $id / $name');
      if (colors.length >= 2) palette = recolorPalette(palette, colors, i, id);
      // Fill slots the look didn't choose from the collection's motifs,
      // rotating so neighbouring looks differ; every third look also lets a
      // motif replace one of its own choices.
      if (motifs.isNotEmpty) {
        for (var k = 0; k < motifs.length; k++) {
          final sty = decoStyles[motifs[(i + k * 3) % motifs.length]]!;
          final force = k == 0 && i % 3 == 1;
          GarlandStyle? g(String x) => x == '-' ? null : garlandOf(x);
          if (sty[0] != '-' && (garland == null || force)) garland = g(sty[0]);
          if (sty[1] != '-' && (lights == null || force))
            lights = lightsOf(sty[1]);
          if (sty[2] != '-' && (border == null || force))
            border = borderOf(sty[2]);
          if (sty[3] != '-' && (particle == null || force))
            particle = particleOf(sty[3]);
          if (sty[4] != '-' && (corner == null || force))
            corner = cornerOf(sty[4]);
        }
      }
      final v = SeasonalVariation(
        id: '$id.$i',
        collectionId: id,
        index: i,
        name: name,
        palette: palette,
        garland: garland ?? defGarland,
        lights: lights ?? defLights,
        border: border ?? defBorder,
        corner: corner ?? defCorner,
        particle: particle ?? defParticle,
        garlandEmoji: _take(garlandPool, i, 3),
        cornerEmoji: _take(cornerPool, i * 2, 3),
        hangers: _take(hangerPool, i, 3),
        furniture: _take(furniturePool, i + 1, 3),
        icons: icons,
        accessory: acc.isEmpty ? '✨' : acc[i % acc.length],
        ambience: amb.isEmpty ? null : amb[i % amb.length],
        seed: id.hashCode ^ (i * 7919),
        tags: tags,
      );
      variations.add(v);
    }
    final blurb = field('blurb');
    out.add(
      SeasonalCollection(
        id: id,
        name: head[1],
        emoji: head[2],
        kind: kind,
        blurb: blurb,
        note: field('note').isEmpty ? null : field('note'),
        variations: variations,
        greetings: list('greet', '|'),
        greetingsEs: list('greetEs', '|'),
        approximateDates: !living && head[4] == 'true',
        group: living ? head[4] : null,
      ),
    );
  }
  return out;
}

/// Redraws [o] using only a holiday's [colors], keeping the look's mood: a
/// dark look stays dark, a soft (pastel) look stays soft, a bright one stays
/// bright. Neighbouring looks rotate which colour leads.
DecoPalette recolorPalette(DecoPalette o, List<int> colors, int i, String id) {
  double lum(int c) => Color(c).computeLuminance();
  int mix(int a, int b, double t) =>
      Color.lerp(Color(a), Color(b), t)!.toARGB32();
  const white = 0xFFFFFFFF, black = 0xFF000000;
  final n = colors.length;
  int pick(int k) => colors[(i + k) % n];
  final dark = lum(o.base) < 0.2;
  final soft = lum(o.primary) > 0.55 && !dark;
  final inky = [
    for (final c in colors)
      if (lum(c) < 0.03) c,
  ];
  final base = dark
      ? (inky.isNotEmpty
            ? mix(inky.first, pick(0), 0.1)
            : mix(pick(0), black, 0.8))
      : mix(
          pick(lum(pick(0)) < 0.03 && n > 1 ? 1 : 0),
          white,
          lum(o.base) > 0.9 ? 0.93 : 0.82,
        );
  // Colours that show up against the base, in rotating order.
  final usable = <int>[
    for (var k = 0; k < n; k++)
      if (!(dark && lum(pick(k)) < 0.03)) pick(k),
  ];
  int at(int k) => usable[k % usable.length];
  var p = at(0),
      s = at(1),
      a = usable.length > 2
          ? at(2)
          : (dark ? mix(at(0), white, 0.45) : mix(at(1), black, 0.25));
  if (soft) {
    p = mix(p, white, 0.38);
    s = mix(s, white, 0.38);
  }
  // Each time the rotation comes round again, shift the shades so two looks
  // with the same mood never end up identical.
  final turn = (i ~/ n) % 4;
  if (turn == 1) {
    p = mix(p, white, 0.18);
    a = mix(a, black, 0.15);
  } else if (turn == 2) {
    p = mix(p, black, 0.18);
    s = mix(s, white, 0.2);
  } else if (turn == 3) {
    s = mix(s, black, 0.2);
    a = mix(a, white, 0.2);
  }
  return DecoPalette('${o.id}~$id.$i', base, p, s, a);
}
