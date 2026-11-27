import 'package:flutter/foundation.dart';

import 'package:prism_plurality/core/app_icon/icon_art.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';

/// A named icon design.
@immutable
class IconDesign {
  const IconDesign(this.id, this.en, this.es, this.group, this.art);
  final String id, en, es, group;
  final IconArt art;
}

/// Groups for the 60 permanent designs.
const iconArtGroups = <(String, String, String)>[
  ('essentials', 'Essentials', 'Esenciales'),
  ('celestial', 'Celestial', 'Celestial'),
  ('tech', 'Technology & retro', 'Tecnología y retro'),
  ('nature', 'Cozy & nature', 'Acogedor y naturaleza'),
  ('artistic', 'Artistic', 'Artístico'),
  ('cute', 'Cute & playful', 'Tierno y divertido'),
];

// id|English|Spanish|group|bg|fg|logo|deco|c1|c2|c3
const _rows = '''
original|Original|Original|essentials|radial|prism|color|none|3B2A6E|120B26|C9B6FF
monoBlack|Monochrome Black|Monocromo negro|essentials|solid|prism|white|none|0E0E10|0E0E10|FFFFFF
monoWhite|Monochrome White|Monocromo blanco|essentials|solid|prism|black|none|F6F6F4|F6F6F4|111111
outline|Outline|Contorno|essentials|linear|prism|outline|none|141826|1E2440|9FD4FF
softMinimal|Soft Minimal|Suave minimalista|essentials|linear|prism|tint|none|F3E9E2|E7DCF2|8E7CC3
glass|Glass|Cristal|essentials|glass|prism|glass|none|5B8DEF|9B6BF2|FFFFFF
frosted|Frosted Glass|Cristal esmerilado|essentials|frosted|prism|glass|sparkles|BFD8F2|E6D8F7|FFFFFF
matte|Matte|Mate|essentials|matte|prism|tint|none|3C4A3E|3C4A3E|E9E2C8
chrome|Chrome|Cromo|essentials|chrome|prism|black|none|8A8F99|C9CED6|4A4F59
iridescent|Iridescent|Iridiscente|essentials|iridescent|prism|white|sparkles|FFB8E1|A8E6FF|C7B8FF
galactic|Galactic|Galáctico|celestial|nebula|prism|color|stars|0B0F2E|231651|FF6FD8
nebula2|Nebula|Nebulosa|celestial|nebula|crystal|none|stars|140A2E|3A1C71|4CC9F0
lunar2|Lunar|Lunar|celestial|starfield|moon|white|stars|0A1230|1B2A5A|F4F1DE
solar|Solar|Solar|celestial|radial|sun|white|none|FFB627|E85D04|FFE066
constellation2|Constellation|Constelación|celestial|starfield|constellation|none|none|0D1B3E|1E2F5E|FFFFFF
saturn|Saturn|Saturno|celestial|linear|planet|none|stars|2A1A4A|0B0716|F2C57C
stardust|Stardust|Polvo de estrellas|celestial|bokeh|star|white|sparkles|1D1240|5B2A86|FFD6F5
cosmicCrystal|Cosmic Crystal|Cristal cósmico|celestial|starfield|crystal|none|sparkles|120A2A|2E1A5C|9AE6FF
midnight|Midnight|Medianoche|celestial|linear|moon|white|stars|050814|141B3A|C8D1FF
aurora2|Aurora|Aurora|celestial|aurora|prism|white|stars|071A2B|3DFFB2|B37BFF
cyberpunk|Cyberpunk|Ciberpunk|tech|neon|prism|tint|none|0A0A14|FF2E93|00F0FF
holographic|Holographic|Holográfico|tech|iridescent|crystal|none|sparkles|9CF6F6|F7B2E6|C8B8FF
pixel|Pixel|Píxel|tech|pixel|prism|pixel|none|1B1B2F|3D3D6B|FF4F79
frutigerAero|Frutiger Aero|Frutiger Aero|tech|glass|drop|none|sparkles|48C6EF|7ED957|FFFFFF
y2k|Y2K|Y2K|tech|iridescent|star|black|sparkles|E2E2F0|B6A4FF|7FDBFF
circuit|Circuit|Circuito|tech|circuit|prism|tint|none|0B1F1A|21C08B|7CFFCB
neon|Neon|Neón|tech|neon|bolt|none|none|0B0B1A|B6FF3B|FF2E93
retroComputer|Retro Computer|Computadora retro|tech|scanlines|prism|tint|none|1A2B1A|0E1A0E|7CFF6B
digitalGlass|Digital Glass|Cristal digital|tech|grid|prism|glass|none|1B0B3A|3A1C71|FF6FD8
futuristic|Futuristic|Futurista|tech|chrome|crystal|none|rings|2B3240|9AA5B8|5CE1E6
cottagecore|Cottagecore|Cottagecore|nature|paper|flower|none|dots|F7EFE0|8BAE66|E8A0A9
botanical|Botanical|Botánico|nature|leaves|leaf|none|none|E5EFD9|9CC08A|3E7B48
mushroom|Mushroom|Hongo|nature|mushrooms|mushroom|none|none|7A9E3E|4F6B2A|D7263D
forest|Forest|Bosque|nature|forest|prism|white|stars|1F3B2A|0E2016|2E6B3E
ocean|Ocean|Océano|nature|waves|drop|none|none|0B6E99|073B4C|5FC8E8
cloud|Cloud|Nube|nature|clouds|cloud|color|none|8EC9F2|D6EEFF|FFFFFF
knitted|Knitted|Tejido|nature|knit|heart|none|none|C96F5B|E9D3B8|F2E3C6
wooden|Wooden|Madera|nature|wood|prism|white|none|8B5A2B|5C3A1A|F2D3A0
floral|Floral|Floral|nature|dots|flower|none|sparkles|FFF1F4|F7B7CE|E26D8C
rainyWindow|Rainy Window|Ventana lluviosa|nature|rain|prism|glass|none|3F5E78|1F3347|BFD8EA
watercolor|Watercolor|Acuarela|artistic|watercolor|prism|tint|none|FFF8F0|8EC5E8|E58FA6
sketchbook|Sketchbook|Cuaderno de bocetos|artistic|sketch|pencil|black|none|F8F5EE|6B6B6B|E8B04A
scrapbook|Scrapbook|Álbum|artistic|paper|heart|none|dots|FDF6EC|D9725E|7EA8BE
gothic|Gothic|Gótico|artistic|stained|arch|white|none|4B1D3F|8E1B2E|2E2A5C
grunge|Grunge|Grunge|artistic|grunge|prism|white|none|2B2A28|6B705C|A5494C
punk|Punk|Punk|artistic|plaid|bolt|none|none|B3001B|111111|FFBE0B
artDeco|Art Deco|Art Déco|artistic|deco|fan|white|none|0D0D0D|D4AF37|F5F0E6
victorian|Victorian|Victoriano|artistic|damask|prism|tint|none|5E2129|C9A227|F1E6D6
stainedGlass|Stained Glass|Vitral|artistic|stained|prism|white|none|1F6FB2|E3A42B|7B2D8B
paperCutout|Paper Cutout|Papel recortado|artistic|cutout|prism|white|none|FFE8D6|F4A261|E76F51
kawaii|Kawaii|Kawaii|cute|dots|heart|white|sparkles|FFE3EE|FF7AB6|FF5C8A
pastel|Pastel|Pastel|cute|watercolor|prism|tint|none|FDF7FF|BDE0FE|9B7FD1
plush|Plush|Peluche|cute|knit|prism|white|none|D9A5B3|F6E3E8|C27C8E
candy|Candy|Dulce|cute|stripes|candy|none|none|FFF7FB|FF4F9A|5CE1E6
ribbon|Ribbon|Lazo|cute|linear|bow|none|sparkles|FFE0EC|FFC2D9|E8355E
notebook|Notebook|Cuaderno|cute|notebook|pencil|tint|none|FFFFFF|4A6FA5|E26D5C
music|Music|Música|cute|staff|note|none|none|1D3557|457B9D|F1C453
arcade|Arcade|Arcade|cute|checker|gamepad|none|stars|0D0221|2E1A5C|FF2A6D
dreamcore|Dreamcore|Dreamcore|cute|clouds|prism|tint|sparkles|F9D5E5|A7C7E7|8E6BB0
fairycore|Fairycore|Fairycore|cute|bokeh|flower|none|sparkles|2A2340|6E8B5E|F6C1D6
''';

int _hex(String h) => 0xFF000000 | int.parse(h, radix: 16);

List<IconDesign>? _permanent;

/// The 60 permanent designs, every one a different composition.
List<IconDesign> get permanentIconDesigns => _permanent ??= [
  for (final l in _rows.split('\n'))
    if (l.trim().isNotEmpty)
      () {
        final p = l.split('|');
        return IconDesign(
          p[0],
          p[1],
          p[2],
          p[3],
          IconArt(
            bg: p[4],
            fg: p[5],
            logo: p[6],
            deco: p[7],
            c1: _hex(p[8]),
            c2: _hex(p[9]),
            c3: _hex(p[10]),
          ),
        );
      }(),
];

IconDesign? iconDesignById(String id) {
  for (final d in permanentIconDesigns) {
    if (d.id == id) return d;
  }
  if (id.startsWith('seas.')) {
    final dot = id.lastIndexOf('.');
    final n = int.tryParse(id.substring(dot + 1));
    final list = seasonalIconDesigns(id.substring(5, dot));
    if (n != null && n >= 0 && n < list.length) return list[n];
  }
  return null;
}

/// Backgrounds and finishing details seasonal icons cycle through, so a
/// holiday's 15 icons don't just swap colours.
const _seasonalBgs = [
  'radial',
  'starfield',
  'paper',
  'stained',
  'cutout',
  'glass',
  'watercolor',
  'deco',
  'knit',
  'stripes',
  'dots',
  'frosted',
  'sunburst',
  'bokeh',
  'linear',
];
const _seasonalDeco = ['sparkles', 'none', 'dots', 'stars', 'rings'];

final Map<String, List<IconDesign>> _seasonal = {};

/// Fifteen icons for a holiday or season, each built from one of its looks:
/// that look's colours, one of the collection's own symbols, and its own
/// backdrop. Kept in a separate library from the permanent designs.
List<IconDesign> seasonalIconDesigns(String collectionId) =>
    _seasonal.putIfAbsent(collectionId, () {
      final col = collectionById(collectionId);
      // Holidays and seasons only; living genres aren't seasonal.
      if (col == null || col.kind == SeasonalKind.living) return const [];
      final glyphs = <String>[];
      void add(String g) {
        if (g.trim().isNotEmpty && !glyphs.contains(g)) glyphs.add(g);
      }

      add(col.emoji);
      for (final v in col.variations) {
        v.icons.forEach(add);
      }
      for (final v in col.variations) {
        for (final g in [...v.hangers, ...v.cornerEmoji, ...v.furniture]) {
          add(g);
        }
      }
      final out = <IconDesign>[];
      for (var i = 0; i < 15; i++) {
        final v = col.variations[(i * 5) % col.variations.length];
        final p = v.palette;
        final g = glyphs[i % glyphs.length];
        out.add(
          IconDesign(
            'seas.$collectionId.$i',
            '${col.name} · ${v.name}',
            '${col.name} · ${v.name}',
            collectionId,
            IconArt(
              bg: _seasonalBgs[i],
              fg: 'glyph',
              glyph: g,
              logo: i % 3 == 0 ? 'white' : 'none',
              deco: _seasonalDeco[i % _seasonalDeco.length],
              c1: p.primary,
              c2: p.base,
              c3: p.accent,
            ),
          ),
        );
      }
      return out;
    });
