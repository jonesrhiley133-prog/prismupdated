import 'package:flutter/material.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';

/// One page texture or cover material: a procedural recipe, not an image.
class ScrapTexture {
  const ScrapTexture(
    this.id,
    this.name,
    this.category,
    this.kind,
    this.c1,
    this.c2, {
    this.scale = 1,
    this.seed = 1,
  });
  final String id, name, category, kind;
  final Color c1, c2;
  final double scale;
  final int seed;
}

/// The knobs a person can turn on any texture or material.
class ScrapTextureStyle {
  const ScrapTextureStyle({
    this.id = 'plain',
    this.intensity = 1,
    this.scale = 1,
    this.opacity = 1,
    this.blend = 'normal',
    this.color,
    this.color2,
    this.custom,
  });
  final String id;
  final double intensity, scale, opacity;
  final String blend;
  final int? color, color2;

  /// A media id for an imported picture used as the texture.
  final String? custom;

  Map<String, Object?> toJson() => {
    'id': id,
    if (intensity != 1) 'i': intensity,
    if (scale != 1) 's': scale,
    if (opacity != 1) 'o': opacity,
    if (blend != 'normal') 'b': blend,
    if (color != null) 'c': color,
    if (color2 != null) 'c2': color2,
    if (custom != null) 'cu': custom,
  };

  static ScrapTextureStyle fromJson(Object? j) {
    if (j is! Map) return const ScrapTextureStyle();
    double d(String k, double def) =>
        (j[k] is num) ? (j[k] as num).toDouble().clamp(0.0, 4.0) : def;
    return ScrapTextureStyle(
      id: j['id'] is String ? j['id'] as String : 'plain',
      intensity: d('i', 1),
      scale: d('s', 1).clamp(0.2, 4.0),
      opacity: d('o', 1).clamp(0.0, 1.0),
      blend: j['b'] is String ? j['b'] as String : 'normal',
      color: j['c'] is int ? j['c'] as int : null,
      color2: j['c2'] is int ? j['c2'] as int : null,
      custom: j['cu'] is String ? j['cu'] as String : null,
    );
  }

  ScrapTextureStyle copyWith({
    String? id,
    double? intensity,
    double? scale,
    double? opacity,
    String? blend,
    int? color,
    int? color2,
    bool clearColors = false,
    String? custom,
    bool clearCustom = false,
  }) => ScrapTextureStyle(
    id: id ?? this.id,
    intensity: intensity ?? this.intensity,
    scale: scale ?? this.scale,
    opacity: opacity ?? this.opacity,
    blend: blend ?? this.blend,
    color: clearColors ? null : (color ?? this.color),
    color2: clearColors ? null : (color2 ?? this.color2),
    custom: clearCustom ? null : (custom ?? this.custom),
  );
}

const scrapBlendModes = <String, BlendMode>{
  'normal': BlendMode.srcOver,
  'multiply': BlendMode.multiply,
  'screen': BlendMode.screen,
  'overlay': BlendMode.overlay,
  'soft light': BlendMode.softLight,
  'hard light': BlendMode.hardLight,
  'darken': BlendMode.darken,
  'lighten': BlendMode.lighten,
  'color burn': BlendMode.colorBurn,
  'difference': BlendMode.difference,
};

Color _c(int v) => Color(0xFF000000 | v);

ScrapTexture _t(
  String id,
  String name,
  String cat,
  String kind,
  int c1,
  int c2, {
  double scale = 1,
  int seed = 1,
}) =>
    ScrapTexture(id, name, cat, kind, _c(c1), _c(c2), scale: scale, seed: seed);

/// 18 categories of page textures.
const scrapTextureCategories = <String>[
  'Paper',
  'Aged',
  'Watercolor',
  'Notebook',
  'Graph',
  'Cloth',
  'Woven',
  'Knit & felt',
  'Leather',
  'Wood & craft',
  'Metal & shine',
  'Stone',
  'Floral',
  'Nature',
  'Sky & space',
  'Geometric',
  'Retro & print',
  'Grunge',
];

final List<ScrapTexture> scrapTextures = [
  // Paper
  _t('paper-white', 'Plain white', 'Paper', 'paper', 0xFAF8F2, 0x6B6458),
  _t('paper-cream', 'Cream', 'Paper', 'paper', 0xF3E9D2, 0x6B5A3A, seed: 2),
  _t(
    'paper-fiber',
    'Fibre paper',
    'Paper',
    'fibers',
    0xF4EFE4,
    0x8C7B5A,
    seed: 3,
  ),
  _t(
    'paper-handmade',
    'Handmade',
    'Paper',
    'handmade',
    0xF1EAD8,
    0x8F7C55,
    seed: 4,
  ),
  _t(
    'paper-construction',
    'Construction paper',
    'Paper',
    'construction',
    0xE4572E,
    0x000000,
    seed: 5,
  ),
  // Aged
  _t('aged-sepia', 'Sepia', 'Aged', 'aged', 0xEAD9B0, 0xA9772E, seed: 6),
  _t(
    'aged-parchment',
    'Parchment',
    'Aged',
    'parchment',
    0xE9D8A6,
    0x9A6B22,
    seed: 7,
  ),
  _t(
    'aged-crumple',
    'Crumpled',
    'Aged',
    'crumple',
    0xF2ECDD,
    0x000000,
    seed: 8,
  ),
  _t(
    'aged-newsprint',
    'Newsprint',
    'Aged',
    'newsprint',
    0xE6E0CE,
    0x2C2A24,
    seed: 9,
  ),
  _t(
    'aged-kraft',
    'Kraft paper',
    'Aged',
    'kraft',
    0xC9A06A,
    0x5A3A1E,
    seed: 10,
  ),
  // Watercolor
  _t(
    'wc-rose',
    'Rose wash',
    'Watercolor',
    'watercolor',
    0xFFF6F4,
    0xF08BA0,
    seed: 11,
  ),
  _t(
    'wc-sky',
    'Sky wash',
    'Watercolor',
    'watercolor',
    0xF4FAFF,
    0x6FB4E8,
    seed: 12,
  ),
  _t(
    'wc-sage',
    'Sage wash',
    'Watercolor',
    'watercolor',
    0xF6FAF3,
    0x86B98A,
    seed: 13,
  ),
  _t(
    'wc-lilac',
    'Lilac wash',
    'Watercolor',
    'watercolor',
    0xFAF6FF,
    0xA48CE0,
    seed: 14,
  ),
  _t(
    'wc-rainbow',
    'Rainbow wash',
    'Watercolor',
    'wash2',
    0xFFFFFF,
    0xFFB86B,
    seed: 15,
  ),
  // Notebook
  _t('nb-ruled', 'Ruled', 'Notebook', 'ruled', 0xFFFFFF, 0x6FA2D6),
  _t('nb-wide', 'Wide ruled', 'Notebook', 'ruledWide', 0xFFFEF6, 0x6FA2D6),
  _t(
    'nb-narrow',
    'Narrow ruled',
    'Notebook',
    'ruledNarrow',
    0xFFFFFF,
    0x7AA6D2,
  ),
  _t(
    'nb-college',
    'College ruled',
    'Notebook',
    'ruledCollege',
    0xFFFDF2,
    0x6FA2D6,
  ),
  _t('nb-yellow', 'Legal pad', 'Notebook', 'ruled', 0xFFF3A8, 0x6FA2D6),
  // Graph
  _t('gr-grid', 'Grid', 'Graph', 'grid', 0xFFFFFF, 0x7AA6D2),
  _t('gr-coarse', 'Big grid', 'Graph', 'gridCoarse', 0xFFFEF4, 0x9AB0C8),
  _t('gr-graph', 'Graph paper', 'Graph', 'graphPaper', 0xF6FFF6, 0x58A87A),
  _t('gr-dots', 'Dot grid', 'Graph', 'dotGrid', 0xFFFDF8, 0x6B6458),
  _t('gr-iso', 'Isometric dots', 'Graph', 'isoDots', 0xFFFFFF, 0x6B7A9A),
  // Cloth
  _t('cl-linen', 'Linen', 'Cloth', 'linen', 0xE9E0CC, 0x6B5A3A),
  _t('cl-canvas', 'Canvas', 'Cloth', 'canvas', 0xE8DFC9, 0x6B5A3A),
  _t('cl-denim', 'Denim', 'Cloth', 'denim', 0x3C5F8F, 0x1B2F4F),
  _t('cl-silk', 'Silk', 'Cloth', 'silk', 0xD6A5C9, 0x5A2A52),
  _t('cl-velvet', 'Velvet', 'Cloth', 'velvet', 0x6A1F3C, 0x000000),
  // Woven
  _t('wv-tartan', 'Tartan', 'Woven', 'tartan', 0x2F5D3A, 0xB5192B),
  _t('wv-gingham', 'Gingham', 'Woven', 'gingham', 0xFFFFFF, 0xE35D6A),
  _t('wv-plaid', 'Plaid', 'Woven', 'plaid', 0xF2E6D0, 0x5B7DB1),
  _t('wv-burlap', 'Burlap', 'Woven', 'burlap', 0xC9A877, 0x5A3A1E),
  _t('wv-tweed', 'Tweed', 'Woven', 'tweed', 0x9C8F7A, 0x2C2A24),
  // Knit & felt
  _t('kn-knit', 'Knitted', 'Knit & felt', 'knit', 0xC96B7A, 0x000000),
  _t('kn-knit-blue', 'Knitted blue', 'Knit & felt', 'knit', 0x6B93C9, 0x000000),
  _t('kn-felt', 'Felt', 'Knit & felt', 'felt', 0x7A9E7E, 0x000000),
  _t('kn-corduroy', 'Corduroy', 'Knit & felt', 'corduroy', 0xB58A55, 0x000000),
  _t('kn-suede', 'Suede', 'Knit & felt', 'suede', 0x8A5A3C, 0x000000),
  // Leather
  _t('lt-brown', 'Brown leather', 'Leather', 'leather', 0x7A4A2B, 0x000000),
  _t('lt-black', 'Black leather', 'Leather', 'leather', 0x25221F, 0x000000),
  _t('lt-red', 'Red leather', 'Leather', 'leather', 0x8E1F2A, 0x000000),
  _t('lt-snake', 'Snakeskin', 'Leather', 'snake', 0x7C8A4A, 0x000000),
  _t('lt-croc', 'Crocodile', 'Leather', 'croc', 0x3C5A3F, 0x000000),
  // Wood & craft
  _t('wd-oak', 'Oak', 'Wood & craft', 'wood', 0xC89B62, 0x000000),
  _t(
    'wd-walnut',
    'Walnut',
    'Wood & craft',
    'wood',
    0x5A3A25,
    0x000000,
    seed: 2,
  ),
  _t('wd-bamboo', 'Bamboo', 'Wood & craft', 'bamboo', 0xD2C27A, 0x000000),
  _t('wd-cork', 'Corkboard', 'Wood & craft', 'cork', 0xC48E55, 0x4A2E14),
  _t(
    'wd-cardboard',
    'Cardboard',
    'Wood & craft',
    'cardboard',
    0xBF975F,
    0x000000,
  ),
  // Metal & shine
  _t(
    'mt-silver',
    'Brushed metal',
    'Metal & shine',
    'metal',
    0xB9BEC4,
    0x000000,
  ),
  _t('mt-gold', 'Gold foil', 'Metal & shine', 'foil', 0xD9B24A, 0x000000),
  _t(
    'mt-rose',
    'Rose-gold foil',
    'Metal & shine',
    'foil',
    0xD9967F,
    0x000000,
    seed: 3,
  ),
  _t(
    'mt-carbon',
    'Carbon fibre',
    'Metal & shine',
    'carbon',
    0x2A2D31,
    0x000000,
  ),
  _t('mt-holo', 'Holographic', 'Metal & shine', 'holo', 0xE9E6F5, 0x000000),
  _t('mt-glitter', 'Glitter', 'Metal & shine', 'glitter', 0xE86AA6, 0x000000),
  // Stone
  _t('st-marble', 'White marble', 'Stone', 'marble', 0xF4F4F2, 0x6B7078),
  _t(
    'st-black-marble',
    'Black marble',
    'Stone',
    'marble',
    0x23252A,
    0xD9C27A,
    seed: 3,
  ),
  _t('st-concrete', 'Concrete', 'Stone', 'concrete', 0xA7A9AB, 0x000000),
  _t('st-lace', 'Lace', 'Stone', 'lace', 0x6E5A7A, 0x000000),
  // Floral
  _t('fl-meadow', 'Meadow flowers', 'Floral', 'floral', 0xFFF8EE, 0xF08BA0),
  _t('fl-ditsy', 'Ditsy floral', 'Floral', 'ditsy', 0xFDF3F0, 0xE86A8A),
  _t(
    'fl-blue',
    'Blue blossoms',
    'Floral',
    'floral',
    0xF4F8FF,
    0x6B93D9,
    seed: 3,
  ),
  _t('fl-vines', 'Climbing vines', 'Floral', 'vines', 0xF3F8EE, 0x4E8A58),
  // Nature
  _t('nt-leaves', 'Autumn leaves', 'Nature', 'leaves', 0xFBEFD9, 0xB5532A),
  _t(
    'nt-leaves-green',
    'Green leaves',
    'Nature',
    'leaves',
    0xF1F7EA,
    0x4E8A58,
    seed: 3,
  ),
  _t('nt-snow', 'Snowflakes', 'Nature', 'snowflakes', 0x2F4A78, 0xFFFFFF),
  _t('nt-waves', 'Ocean waves', 'Nature', 'waves', 0xEAF5FA, 0x3C86B5),
  // Sky & space
  _t('sk-stars', 'Starfield', 'Sky & space', 'starfield', 0x120F2E, 0xFFFFFF),
  _t(
    'sk-constellations',
    'Constellations',
    'Sky & space',
    'constellations',
    0x1B2548,
    0xE8E2B0,
  ),
  _t('sk-moons', 'Moons', 'Sky & space', 'moons', 0x22254D, 0xF2E8A8),
  _t('sk-clouds', 'Clouds', 'Sky & space', 'clouds', 0xA9D2F2, 0xFFFFFF),
  // Geometric
  _t('ge-polka', 'Polka dots', 'Geometric', 'polka', 0xFFF1F3, 0xE35D78),
  _t('ge-polka-big', 'Big dots', 'Geometric', 'polkaBig', 0xFFFAEA, 0x4A9BD1),
  _t('ge-stripes', 'Stripes', 'Geometric', 'stripes', 0xFFFFFF, 0x6B7A9A),
  _t('ge-chevron', 'Chevron', 'Geometric', 'chevron', 0xFFF8EE, 0xD9774A),
  _t('ge-diamonds', 'Diamonds', 'Geometric', 'diamonds', 0xF3EEFF, 0x8A6BD9),
  _t('ge-scales', 'Scales', 'Geometric', 'scales', 0xEAF7F4, 0x3C9A8A),
  // Retro & print
  _t('rp-hearts', 'Hearts', 'Retro & print', 'hearts', 0xFFEFF2, 0xE8506E),
  _t('rp-stars', 'Stars', 'Retro & print', 'stars', 0xFFF8DF, 0xE8A21A),
  _t(
    'rp-checker',
    'Checkerboard',
    'Retro & print',
    'checker',
    0xFFFFFF,
    0x2A2A2A,
  ),
  _t(
    'rp-diagonal',
    'Candy stripes',
    'Retro & print',
    'diagonal',
    0xFFFFFF,
    0xE8506E,
  ),
  _t(
    'rp-halftone',
    'Halftone',
    'Retro & print',
    'halftone',
    0xFFF8E6,
    0x2E7DB5,
  ),
  // Grunge
  _t('gn-grunge', 'Grunge', 'Grunge', 'grunge', 0xCFCAC0, 0x3A3630),
  _t('gn-scratch', 'Scratched', 'Grunge', 'scratches', 0x6A6D72, 0x000000),
  _t(
    'gn-dirty',
    'Dirty white',
    'Grunge',
    'grunge',
    0xEFEBE2,
    0x6A5F4A,
    seed: 3,
  ),
];

ScrapTexture? scrapTextureById(String id) {
  if (id.startsWith('seas:')) return seasonalTextureById(id);
  for (final t in scrapTextures) {
    if (t.id == id) return t;
  }
  for (final t in scrapMaterials) {
    if (t.id == id) return t;
  }
  return null;
}

/// Cover materials (36). Same recipes, richer in colour and gloss.
const scrapMaterialCategories = <String>[
  'Leather',
  'Fabric',
  'Paper & card',
  'Wood & natural',
  'Shiny',
  'Stone & lace',
];

final List<ScrapTexture> scrapMaterials = [
  _t(
    'm-leather-brown',
    'Brown leather',
    'Leather',
    'leather',
    0x7A4A2B,
    0x000000,
  ),
  _t(
    'm-leather-black',
    'Black leather',
    'Leather',
    'leather',
    0x25221F,
    0x000000,
  ),
  _t(
    'm-leather-burgundy',
    'Burgundy leather',
    'Leather',
    'leather',
    0x6E1A2C,
    0x000000,
  ),
  _t(
    'm-leather-navy',
    'Navy leather',
    'Leather',
    'leather',
    0x1F2F52,
    0x000000,
  ),
  _t(
    'm-leather-green',
    'Forest leather',
    'Leather',
    'leather',
    0x2F4A35,
    0x000000,
  ),
  _t('m-snake', 'Snakeskin', 'Leather', 'snake', 0x7C8A4A, 0x000000),
  _t('m-croc', 'Crocodile', 'Leather', 'croc', 0x3C5A3F, 0x000000),
  _t('m-denim', 'Denim', 'Fabric', 'denim', 0x3C5F8F, 0x1B2F4F),
  _t('m-denim-dark', 'Dark denim', 'Fabric', 'denim', 0x1F2F4F, 0x0B1424),
  _t('m-velvet-red', 'Red velvet', 'Fabric', 'velvet', 0x7A1B2E, 0x000000),
  _t('m-velvet-blue', 'Blue velvet', 'Fabric', 'velvet', 0x1E3A6E, 0x000000),
  _t(
    'm-velvet-green',
    'Emerald velvet',
    'Fabric',
    'velvet',
    0x1B5A3E,
    0x000000,
  ),
  _t(
    'm-velvet-purple',
    'Purple velvet',
    'Fabric',
    'velvet',
    0x4A2A6E,
    0x000000,
  ),
  _t('m-linen', 'Linen', 'Fabric', 'linen', 0xE3D8BE, 0x6B5A3A),
  _t('m-canvas', 'Canvas', 'Fabric', 'canvas', 0xD9CDB0, 0x6B5A3A),
  _t('m-knit-pink', 'Knitted pink', 'Fabric', 'knit', 0xE88AA2, 0x000000),
  _t('m-knit-cream', 'Knitted cream', 'Fabric', 'knit', 0xE8DCC0, 0x000000),
  _t('m-tweed', 'Tweed', 'Fabric', 'tweed', 0x8C8070, 0x2C2A24),
  _t('m-tartan', 'Tartan', 'Fabric', 'tartan', 0x2F5D3A, 0xB5192B),
  _t('m-gingham', 'Gingham', 'Fabric', 'gingham', 0xFFFFFF, 0xE35D6A),
  _t(
    'm-cardboard',
    'Cardboard',
    'Paper & card',
    'cardboard',
    0xBF975F,
    0x000000,
  ),
  _t('m-kraft', 'Kraft', 'Paper & card', 'kraft', 0xC9A06A, 0x5A3A1E),
  _t(
    'm-construction-red',
    'Red construction paper',
    'Paper & card',
    'construction',
    0xD6402E,
    0x000000,
  ),
  _t(
    'm-construction-blue',
    'Blue construction paper',
    'Paper & card',
    'construction',
    0x2E6FB5,
    0x000000,
  ),
  _t(
    'm-vintage-paper',
    'Vintage paper',
    'Paper & card',
    'aged',
    0xEAD9B0,
    0xA9772E,
  ),
  _t(
    'm-parchment',
    'Parchment',
    'Paper & card',
    'parchment',
    0xE9D8A6,
    0x9A6B22,
  ),
  _t('m-oak', 'Oak', 'Wood & natural', 'wood', 0xC89B62, 0x000000),
  _t('m-walnut', 'Walnut', 'Wood & natural', 'wood', 0x5A3A25, 0x000000),
  _t('m-bamboo', 'Bamboo', 'Wood & natural', 'bamboo', 0xD2C27A, 0x000000),
  _t('m-cork', 'Cork', 'Wood & natural', 'cork', 0xC48E55, 0x4A2E14),
  _t('m-holo', 'Holographic', 'Shiny', 'holo', 0xE9E6F5, 0x000000),
  _t('m-glitter-pink', 'Pink glitter', 'Shiny', 'glitter', 0xE86AA6, 0x000000),
  _t('m-glitter-gold', 'Gold glitter', 'Shiny', 'glitter', 0xD9B24A, 0x000000),
  _t('m-foil-gold', 'Gold foil', 'Shiny', 'foil', 0xD9B24A, 0x000000),
  _t('m-marble', 'Marble', 'Stone & lace', 'marble', 0xF4F4F2, 0x6B7078),
  _t('m-lace', 'Lace', 'Stone & lace', 'lace', 0x6E5A7A, 0x000000),
];

/// A page texture made from one holiday or season look: its palette, with
/// the pattern that matches what falls or floats in that look.
ScrapTexture seasonalTexture(SeasonalVariation v) {
  final kind = switch (v.particle) {
    ParticleKind.snow => 'snowflakes',
    ParticleKind.leaves => 'leaves',
    ParticleKind.petals => 'floral',
    ParticleKind.rain => 'waves',
    ParticleKind.fireflies => 'constellations',
    ParticleKind.stars => 'starfield',
    ParticleKind.confetti => 'polka',
    ParticleKind.hearts => 'hearts',
    ParticleKind.bubbles => 'polkaBig',
    ParticleKind.sparkles => 'stars',
    ParticleKind.embers => 'grunge',
    ParticleKind.clouds => 'clouds',
    ParticleKind.butterflies => 'ditsy',
    ParticleKind.bokeh => 'polkaBig',
    ParticleKind.feathers => 'leaves',
    ParticleKind.glitter => 'glitter',
    ParticleKind.skylanterns => 'constellations',
    ParticleKind.ribbons => 'chevron',
    ParticleKind.none =>
      v.border == DecoBorder.hairline ? 'stripes' : 'diamonds',
  };
  final p = v.palette;
  return ScrapTexture(
    'seas:${v.id}',
    v.name,
    'Holidays & seasons',
    kind,
    Color(p.base),
    Color(p.primary),
    scale: 0.8 + (v.seed % 5) * 0.12,
    seed: v.seed % 97 + 1,
  );
}

ScrapTexture? seasonalTextureById(String id) {
  final v = variationById(id.substring(5));
  return v == null ? null : seasonalTexture(v);
}
