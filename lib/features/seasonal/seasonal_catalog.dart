import 'package:prism_plurality/features/seasonal/seasonal_data.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_vocab.dart';

/// Every holiday and season Prism ships, each with 25+ looks. Built once
/// from [seasonalSource]; new collections only need a new block there.
List<SeasonalCollection> get seasonalCollections =>
    _cache ??= _parse(seasonalSource);

List<SeasonalCollection>? _cache;

SeasonalCollection? collectionById(String id) {
  for (final c in seasonalCollections) {
    if (c.id == id) return c;
  }
  return null;
}

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
    final d = list('defaults');
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

    final looks = lines.where((l) => l.startsWith('- ')).toList();
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
        approximateDates: head[4] == 'true',
      ),
    );
  }
  return out;
}
