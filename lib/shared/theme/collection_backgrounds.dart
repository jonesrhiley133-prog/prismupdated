import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// One of the 120 collection backgrounds: a painting [style] in four
/// colours. Drawn in code so they cost no storage, stay sharp at any size,
/// and work offline.
@immutable
class CollectionBackground {
  const CollectionBackground(
    this.id,
    this.name,
    this.collection,
    this.style,
    this.colors, {
    this.seed = 1,
  });
  final String id, name, collection, style;
  final List<int> colors;
  final int seed;

  /// The colour behind everything (for placeholders and contrast).
  Color get base => Color(colors.first);

  /// Whether text over it should be light.
  bool get dark => base.computeLuminance() < 0.35;

  void paint(Canvas canvas, Size size) =>
      paintCollectionBackground(canvas, size, this);
}

const backgroundCollections = <(String, String, String)>[
  ('celestial', 'Celestial', 'Celestial'),
  ('environmental', 'Environmental', 'Naturaleza'),
  ('cozy', 'Cozy Living', 'Hogar acogedor'),
  ('futuristic', 'Futuristic', 'Futurista'),
  ('retro', 'Frutiger & Retro', 'Frutiger y retro'),
  ('academic', 'Academic', 'Académico'),
  ('artistic', 'Artistic', 'Artístico'),
  ('gothic', 'Gothic & Alternative', 'Gótico y alternativo'),
  ('cute', 'Cute & Whimsical', 'Tierno y fantasioso'),
  ('cultural', 'Cultural & Architectural', 'Cultural y arquitectónico'),
  ('minimal', 'Minimal & Material', 'Minimalista y material'),
  ('music', 'Music & Entertainment', 'Música y entretenimiento'),
];

// id|Name|collection|style|c1,c2,c3,c4
const _rows = '''
cosmicDawn|Cosmic Dawn|celestial|nebula|0D0B26,3B1C6E,FF7AB6,4CC9F0
milkyWay|Milky Way|celestial|galaxy|05060F,1B1F4B,C9B6FF,FFFFFF
moonlitSky|Moonlit Sky|celestial|moonlit|0A1230,1B2A5A,F4F1DE,9FB4E8
auroraNight|Aurora Night|celestial|aurora|071A2B,0B2E3F,3DFFB2,B37BFF
starNursery|Star Nursery|celestial|starfield|120A2A,2E1A5C,FFD6F5,9AE6FF
ringedHorizon|Ringed Horizon|celestial|planets|0F1530,2A1A4A,F2C57C,E07A5F
constellationMap|Constellation Map|celestial|constellations|0D1B3E,14254F,F4D35E,FFFFFF
eclipse|Eclipse|celestial|eclipse|050505,1A1A2E,FFB627,FF5E5B
cometTrail|Comet Trail|celestial|comets|0B0F2E,231651,7FDBFF,FFFFFF
zodiacWheel|Zodiac Wheel|celestial|zodiac|1C1633,2E2550,D9B65C,8E7CC3
misty Mountains|Misty Mountains|environmental|mountains|DDE6EE,9FB3C8,5D7389,334A5E
rainforestCanopy|Rainforest Canopy|environmental|forest|0F3D2E,1E5B43,7CC576,2E8B57
desertDunes|Desert Dunes|environmental|dunes|F6E3C5,E7BE8A,D98E4A,B5523B
oceanDepths|Ocean Depths|environmental|waves|04293A,0B6E99,5FC8E8,9DE3F5
springMeadow|Spring Meadow|environmental|meadow|EAF6D9,BFE3A5,F7B7CE,FFE27A
rainyDay|Rainy Day|environmental|rain|5D7389,3F5E78,BFD8EA,E3EEF6
coralReef|Coral Reef|environmental|bubbles|0FA3B1,48C6EF,FF6B6B,FFD166
autumnWoods|Autumn Woods|environmental|leaves|F2E3C6,E07A1F,B5523B,8E9B5A
snowyPines|Snowy Pines|environmental|snowforest|E8F0F7,B9CFE3,4E6B7A,FFFFFF
bambooGrove|Bamboo Grove|environmental|bamboo|EEF5E9,A6C48A,4C8C4A,2F3E2F
firesideGlow|Fireside Glow|cozy|candle|2A1208,5C2A12,F6A623,E8591A
knitBlanket|Knit Blanket|cozy|knit|E9D3B8,C96F5B,F2E3C6,8C5A3C
plaidThrow|Plaid Throw|cozy|plaid|7A2E2E,B3443A,E9D8A6,2F4F3A
woodenCabin|Wooden Cabin|cozy|wood|8B5A2B,6B4226,A9764B,5C3A1A
patchworkQuilt|Patchwork Quilt|cozy|quilt|F5EEE6,C27C8E,7A9C8C,D9B88F
teaTime|Tea Time|cozy|polka|FFF6EE,E9A0B5,C9A978,FFFFFF
rainyWindowSeat|Rainy Window Seat|cozy|windowRain|3F5E78,6E8BA6,F2C57C,BFD8EA
sunlitKitchen|Sunlit Kitchen|cozy|gingham|FFF8E6,F4C95D,E87A5D,FFFFFF
bookNook|Book Nook|cozy|books|3B2F2F,7B3F2A,2E5E4E,C9A227
fairyLightWall|Fairy Light Wall|cozy|bokeh|2B1B12,4A3020,FFD27A,FFB38A
neonCity|Neon City|futuristic|skyline|0A0A14,1B1240,FF2E93,00F0FF
synthwave|Synthwave|futuristic|synthgrid|1B0B3A,3A1C71,FF6FD8,FFD166
circuitBoard|Circuit Board|futuristic|circuit|0B1F1A,10352B,21C08B,7CFFCB
hexMatrix|Hex Matrix|futuristic|hex|0E1525,16233D,5CE1E6,9B5CFF
hologram|Hologram|futuristic|holo|E9F3FF,C8B8FF,9CF6F6,F7B2E6
spaceStation|Space Station|futuristic|panels|1C232E,2B3442,5FA8D3,F2A541
dataStream|Data Stream|futuristic|datarain|04110A,0B2A16,39FF14,B6FF3B
chromeWave|Chrome Wave|futuristic|chrome|8A8F99,C9CED6,FFFFFF,4A4F59
solarpunkCity|Solarpunk City|futuristic|solarcity|F5F1DC,BFE3A5,4CAF50,F4B400
laserGrid|Laser Grid|futuristic|lasers|050510,151530,FF2E63,08D9D6
frutigerSky|Frutiger Sky|retro|aeroSky|48C6EF,9AE6FF,7ED957,FFFFFF
glossyBubbles|Glossy Bubbles|retro|bubbles|1E9BE9,7FDBFF,FFFFFF,7ED957
y2kChrome|Y2K Chrome|retro|holo|E2E2F0,B6A4FF,7FDBFF,FF8AD8
pixelPlains|Pixel Plains|retro|pixel|5FC8E8,7ED957,F4D35E,3A6B35
crtGlow|CRT Glow|retro|crt|0E1A0E,1A2B1A,7CFF6B,3AFF9A
vaporwave|Vaporwave|retro|vapor|FF71CE,01CDFE,B967FF,FFFB96
retroSunset|Retro Sunset|retro|sunset|2B1055,D53A9D,FFB627,FF5E5B
windowsGreen|Grassy Hills|retro|hills|7EC8F0,BDE8FF,7ED957,3E9B3E
arcadeCarpet|Arcade Carpet|retro|memphis|1A1033,FF2A6D,05D9E8,FFE66D
mallFountain|Mall Fountain|retro|terrazzo|F2EDE4,E8A0A9,7FB8C6,F2C57C
chalkboard|Chalkboard|academic|chalk|2F4F3A,284433,F5F5F5,F4D35E
notebookPaper|Notebook Paper|academic|notebook|FFFFFF,F7F7F2,9DB7D9,E26D5C
graphPaper|Graph Paper|academic|graph|FAFAF5,FFFFFF,B8D4E8,7CA7C9
oldLibrary|Old Library|academic|books|2A1F1A,5C3D2E,8B6F47,C9B79C
parchment|Parchment|academic|parchment|EFE2C2,E3CFA0,B08D57,7A5C3A
ivyLeague|Ivy League|academic|ivybrick|8C3B2E,A04A3A,3E7B48,E9D8C4
blueprint|Blueprint|academic|blueprint|1F4E8C,1A4277,FFFFFF,9CC7F0
sketchMargins|Sketch Margins|academic|sketch|F8F5EE,EFEAE0,6B6B6B,E8B04A
cornellNotes|Cornell Notes|academic|cornell|FFFDF7,F4F0E6,D9725E,7EA8BE
astronomyChart|Astronomy Chart|academic|starchart|E9DFC8,D8CCB0,3A3226,8B6F47
watercolorWash|Watercolor Wash|artistic|watercolor|FFF8F0,8EC5E8,F4A6B8,A8D8B0
inkSplatter|Ink Splatter|artistic|splatter|F7F4EE,FFFFFF,1A1A1A,D7263D
marbleVeins|Marble Veins|artistic|marble|F4F1EC,E8E3DA,B8B0A2,8C8577
terrazzoFloor|Terrazzo Floor|artistic|terrazzo|F2EDE4,E9C46A,E76F51,2A9D8F
artDecoFans|Art Deco Fans|artistic|deco|0D0D0D,1F1A12,D4AF37,F5F0E6
bauhaus|Bauhaus|artistic|bauhaus|F2EBDC,E63946,1D3557,F4A261
abstractShapes|Abstract Shapes|artistic|geometric|1D2D44,3E5C76,F0EBD8,748CAB
paperCollage|Paper Collage|artistic|collage|FDF6EC,D9725E,7EA8BE,E8C547
halftonePop|Halftone Pop|artistic|halftone|FFE066,FF5E5B,1A1A1A,FFFFFF
brushstrokes|Brushstrokes|artistic|strokes|F4EDE4,5B8DEF,E26D8C,F2C14E
gothicArches|Gothic Arches|gothic|arches|0D0B10,2B1B3A,8E1B2E,BFA5C9
stainedWindow|Stained Window|gothic|stained|1A1A1A,4B1D3F,1F6FB2,E3A42B
velvetDamask|Velvet Damask|gothic|damask|2A0F1C,4B1D3F,8E1B2E,C9A227
grungeConcrete|Grunge Concrete|gothic|grunge|3A3A3A,2B2A28,6B705C,A5494C
punkPlaid|Punk Plaid|gothic|plaid|111111,B3001B,FFBE0B,3A86FF
spiderLace|Spider Lace|gothic|cobweb|0D0D12,1C1C24,BFA5C9,6B5B7B
moonlitGraveyard|Moonlit Graveyard|gothic|graveyard|0A0D1A,1B2238,C8D1FF,3A4A6A
candleCrypt|Candle Crypt|gothic|candle|0D0805,2A1208,F6A623,8E1B2E
ravenFeathers|Raven Feathers|gothic|feathers|0D0B10,1E1A28,4A4560,8E7CC3
chainLink|Chain Link|gothic|chains|141414,232323,8A8F99,C0C0C0
kawaiiClouds|Kawaii Clouds|cute|cuteClouds|BDE0FE,FFE3EE,FFFFFF,FF8FB1
pastelHearts|Pastel Hearts|cute|hearts|FFF0F5,FFD6E7,FF8FB1,C3B1E1
candyStripes|Candy Stripes|cute|stripes|FFF7FB,FF4F9A,5CE1E6,FFD93D
starSprinkles|Star Sprinkles|cute|sprinkles|FFF4C9,FFE08A,FF7AB6,8FE3CF
bubblegumDots|Bubblegum Dots|cute|polka|FFC2D9,FF8FB1,FFFFFF,FFE57F
rainbowArcs|Rainbow Arcs|cute|rainbow|FFF8F0,FF8FAB,FFD166,8FE3CF
dreamyCheck|Dreamy Check|cute|checker|F7C6D9,FDF7FF,BDE0FE,E2C2FF
plushPaws|Plush Paws|cute|paws|F6E3D4,EBC9B0,C27C8E,FFFFFF
fairyMeadow|Fairy Meadow|cute|meadow|E2F0CB,B5EAD7,FFDAC1,E2C2FF
cloudCastle|Cloud Castle|cute|aeroSky|F4FAFF,9AD0F5,FFE08A,F7B6D2
moroccanTiles|Moroccan Tiles|cultural|tiles|0F4C5C,E36414,FB8B24,F5F0E1
azulejo|Azulejo|cultural|azulejo|F5F7FA,1F4E9A,7FA7D9,FFFFFF
shojiScreen|Shoji Screen|cultural|shoji|F2EAD3,D9C9A6,6B4F3A,FFFFFF
seigaiha|Seigaiha Waves|cultural|seigaiha|0B3C5D,328CC1,D9B310,F5F5F5
kenteWeave|Kente Weave|cultural|kente|F4B400,0F7B3D,C0392B,111111
mosaicDome|Mosaic Dome|cultural|mosaic|1D3557,457B9D,E9C46A,F1FAEE
romanColumns|Roman Columns|cultural|columns|F4EFE6,E3D9C6,B8A88A,8C7A5A
paperLanterns|Paper Lanterns|cultural|lanterns|1A0E2E,3A1C4A,FF6B35,FFB627
batikWax|Batik Wax|cultural|batik|3E2723,8D6E63,D7A86E,F5E6CA
celticKnot|Celtic Knot|cultural|knots|0F3D2E,1E5B43,C9A227,E9DFC8
softGradient|Soft Gradient|minimal|soft|F3EFFA,E3ECFA,FFFFFF,B8C4E8
materialLayers|Material Layers|minimal|layers|ECEFF1,CFD8DC,90A4AE,546E7A
monoLines|Mono Lines|minimal|lines|FAFAFA,F0F0F0,BDBDBD,424242
paperFold|Paper Fold|minimal|fold|F5F5F0,E8E8E0,FFFFFF,D0D0C8
charcoalMatte|Charcoal Matte|minimal|matte|2B2D31,232428,3A3D42,5A5E66
sandstone|Sandstone|minimal|grain|E8DCC6,D9C9AE,C2B090,A8957A
slateGrid|Slate Grid|minimal|dotgrid|1E2329,262C33,4A5562,7A8899
pebblePath|Pebble Path|minimal|pebbles|E9EDEA,D5DDD8,B3C2BA,8FA39A
duotoneWave|Duotone Wave|minimal|duowave|1D3557,457B9D,A8DADC,F1FAEE
nordicFrost|Nordic Frost|minimal|frost|EEF4F8,DCE7EF,A9C3D6,FFFFFF
vinylRecords|Vinyl Records|music|vinyl|141414,222222,C1440E,F2A541
pianoKeys|Piano Keys|music|piano|1A1A1A,F5F5F5,2B2B2B,C9A227
musicStaff|Music Staff|music|staff|FFF8EC,F2E6CF,1D3557,E63946
jazzClub|Jazz Club|music|jazz|0F1B2D,1B2B45,C9A227,7A1F3D
stageLights|Stage Lights|music|spotlights|0A0A12,1A1030,FFE066,FF6FD8
filmStrip|Film Strip|music|film|161616,222222,F2C14E,EDEDED
marqueeBulbs|Marquee Bulbs|music|marquee|3A0A0A,B3001B,FFD166,F5F5F5
equalizer|Equalizer|music|equalizer|0B0C10,141824,39FF14,FF3864
cassetteTape|Cassette Tape|music|cassette|F1E3C8,E94F37,1C9CA6,393E41
arcadeRoom|Arcade Room|music|arcade|0D0221,190535,FF2A6D,05D9E8
''';

List<CollectionBackground>? _all;

List<CollectionBackground> get collectionBackgrounds => _all ??= [
  for (final (i, l)
      in _rows.split('\n').where((l) => l.trim().isNotEmpty).indexed)
    () {
      final p = l.split('|');
      return CollectionBackground(p[0].replaceAll(' ', ''), p[1], p[2], p[3], [
        for (final h in p[4].split(',')) 0xFF000000 | int.parse(h, radix: 16),
      ], seed: 17 + i * 31);
    }(),
];

final Map<String, CollectionBackground> _byId = {
  for (final b in collectionBackgrounds) b.id: b,
};

CollectionBackground? collectionBackgroundById(String id) => _byId[id];

// ── Painting ───────────────────────────────────────────────────────────

double _r(int seed, int i) {
  var h = seed * 374761393 + i * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return ((h ^ (h >> 16)) & 0xffff) / 0xffff;
}

void paintCollectionBackground(Canvas c, Size size, CollectionBackground b) {
  final w = size.width, h = size.height;
  if (w <= 0 || h <= 0) return;
  final rect = Offset.zero & size;
  final col = [for (final x in b.colors) Color(x)];
  final s = b.seed;
  final u = math.min(w, h);
  Paint fill(Color x, [double a = 1]) =>
      Paint()..color = x.withValues(alpha: a);
  Paint line(Color x, double width, [double a = 1]) => Paint()
    ..color = x.withValues(alpha: a)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
  void vgrad(List<Color> cs, [List<double>? stops]) => c.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: cs,
        stops: stops,
      ).createShader(rect),
  );
  void blob(Offset o, double r, Color x, double a) => c.drawCircle(
    o,
    r,
    Paint()
      ..shader = RadialGradient(
        colors: [
          x.withValues(alpha: a),
          x.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: o, radius: r)),
  );
  void stars(int n, Color x, {double maxR = 1.6}) {
    for (var i = 0; i < n; i++) {
      c.drawCircle(
        Offset(_r(s, i) * w, _r(s, i + 500) * h),
        0.4 + _r(s, i + 900) * maxR,
        fill(x, 0.3 + _r(s, i + 77) * 0.7),
      );
    }
  }

  void layersOf(Path Function(int k) shape, List<Color> cs) {
    for (var k = 0; k < cs.length; k++) {
      c.drawPath(shape(k), fill(cs[k]));
    }
  }

  switch (b.style) {
    // ── Sky & space ──
    case 'nebula':
      vgrad([col[0], col[1]]);
      for (var i = 0; i < 7; i++) {
        blob(
          Offset(_r(s, i) * w, _r(s, i + 9) * h),
          u * (0.35 + _r(s, i + 3) * 0.3),
          i.isEven ? col[2] : col[3],
          0.35,
        );
      }
      stars(160, const Color(0xFFFFFFFF));
    case 'galaxy':
      vgrad([col[0], col[1], col[0]]);
      final o = Offset(w / 2, h * 0.45);
      for (var i = 0; i < 700; i++) {
        final t = _r(s, i) * 6;
        final arm = (i % 2) * math.pi;
        final r = t * u * 0.09;
        final a = t * 1.2 + arm + (_r(s, i + 1) - 0.5) * 0.6;
        c.drawCircle(
          o + Offset(math.cos(a) * r * 1.4, math.sin(a) * r * 0.55),
          0.5 + _r(s, i + 2) * 1.4,
          fill(i % 5 == 0 ? col[2] : col[3], 0.35 + _r(s, i + 3) * 0.5),
        );
      }
      blob(o, u * 0.25, col[2], 0.45);
      stars(120, const Color(0xFFFFFFFF), maxR: 1);
    case 'moonlit':
      vgrad([col[0], col[1]]);
      stars(150, const Color(0xFFFFFFFF));
      final m = Offset(w * 0.75, h * 0.16);
      blob(m, u * 0.35, col[2], 0.25);
      c.drawCircle(m, u * 0.09, fill(col[2]));
      c.drawCircle(
        m + Offset(u * 0.035, -u * 0.02),
        u * 0.08,
        fill(col[1], 0.25),
      );
    case 'aurora':
      vgrad([col[0], col[1]]);
      stars(90, const Color(0xFFFFFFFF), maxR: 1);
      for (var k = 0; k < 4; k++) {
        final p = Path()..moveTo(-w * 0.1, h * (0.18 + k * 0.08));
        for (var x = 0.0; x <= w * 1.2; x += w / 12) {
          p.lineTo(
            x,
            h * (0.18 + k * 0.08) + math.sin(x / w * 5 + k + s) * h * 0.05,
          );
        }
        c.drawPath(
          p,
          line(k.isEven ? col[2] : col[3], h * 0.08, 0.32)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.04),
        );
      }
    case 'starfield':
      vgrad([col[0], col[1]]);
      blob(Offset(w * 0.2, h * 0.3), u * 0.6, col[2], 0.18);
      blob(Offset(w * 0.8, h * 0.75), u * 0.6, col[3], 0.18);
      stars(260, const Color(0xFFFFFFFF), maxR: 2);
    case 'planets':
      vgrad([col[0], col[1]]);
      stars(140, const Color(0xFFFFFFFF), maxR: 1.2);
      final o = Offset(w * 0.5, h * 1.08);
      c.drawCircle(
        o,
        u * 0.7,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.6),
            colors: [col[2], col[3]],
          ).createShader(Rect.fromCircle(center: o, radius: u * 0.7)),
      );
      c.drawOval(
        Rect.fromCenter(
          center: o - Offset(0, u * 0.1),
          width: u * 2.2,
          height: u * 0.32,
        ),
        line(col[2], u * 0.012, 0.6),
      );
      c.drawCircle(Offset(w * 0.2, h * 0.2), u * 0.05, fill(col[3]));
    case 'constellations':
      vgrad([col[0], col[1]]);
      stars(120, col[3], maxR: 1);
      for (var g = 0; g < 4; g++) {
        final pts = [
          for (var i = 0; i < 5; i++)
            Offset(
              (0.1 + _r(s, g * 9 + i) * 0.8) * w,
              (0.1 + (g + _r(s, g * 9 + i + 4)) / 4 * 0.85) * h,
            ),
        ];
        for (var i = 0; i < pts.length - 1; i++) {
          c.drawLine(pts[i], pts[i + 1], line(col[2], 1, 0.5));
        }
        for (final p in pts) {
          c.drawCircle(p, 2.4, fill(col[2]));
        }
      }
    case 'eclipse':
      vgrad([col[1], col[0]]);
      final o = Offset(w / 2, h * 0.32);
      blob(o, u * 0.55, col[3], 0.45);
      blob(o, u * 0.32, col[2], 0.7);
      c.drawCircle(o, u * 0.16, fill(col[0]));
      stars(70, const Color(0xFFFFFFFF), maxR: 1);
    case 'comets':
      vgrad([col[0], col[1]]);
      stars(140, const Color(0xFFFFFFFF), maxR: 1.2);
      for (var i = 0; i < 6; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 4) * h * 0.8);
        c.drawLine(
          o,
          o + Offset(-u * 0.3, -u * 0.12),
          Paint()
            ..shader = LinearGradient(
              colors: [col[2], col[2].withValues(alpha: 0)],
            ).createShader(Rect.fromPoints(o, o + Offset(-u * 0.3, -u * 0.12)))
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
        c.drawCircle(o, 3, fill(col[3]));
      }
    case 'zodiac' || 'starchart':
      vgrad([col[0], col[1]]);
      final o = Offset(w / 2, h * 0.45);
      for (var k = 1; k <= 4; k++) {
        c.drawCircle(o, u * 0.12 * k, line(col[2], 1.2, 0.45));
      }
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        c.drawLine(
          o + Offset(math.cos(a), math.sin(a)) * u * 0.12,
          o + Offset(math.cos(a), math.sin(a)) * u * 0.48,
          line(col[2], 1, 0.35),
        );
      }
      if (b.style == 'zodiac') stars(100, col[3], maxR: 1.2);
    // ── Nature ──
    case 'mountains':
      vgrad([col[0], col[1]]);
      layersOf((k) {
        final p = Path()..moveTo(0, h);
        final base = h * (0.45 + k * 0.15);
        for (var x = 0.0; x <= w; x += w / 8) {
          p.lineTo(x, base - (_r(s, k * 20 + (x / w * 8).round()) * 0.15) * h);
        }
        return p
          ..lineTo(w, h)
          ..close();
      }, [col[1], col[2], col[3]]);
    case 'forest' || 'snowforest':
      vgrad([col[0], col[1]]);
      for (var k = 0; k < 3; k++) {
        final color = b.style == 'snowforest'
            ? col[2].withValues(alpha: 0.5 + k * 0.25)
            : (k == 2 ? col[3] : col[2]);
        for (var i = 0; i < 9; i++) {
          final x = (i + _r(s, k * 10 + i)) / 9 * w;
          final base = h * (0.62 + k * 0.14);
          final th = h * (0.18 + _r(s, k * 30 + i) * 0.08);
          c.drawPath(
            Path()
              ..moveTo(x, base - th)
              ..lineTo(x - th * 0.3, base)
              ..lineTo(x + th * 0.3, base)
              ..close(),
            fill(color.withValues(alpha: 1)),
          );
        }
        c.drawRect(Rect.fromLTWH(0, h * (0.62 + k * 0.14), w, h), fill(color));
      }
      if (b.style == 'snowforest') stars(140, col[3], maxR: 2);
    case 'dunes':
      vgrad([col[0], col[1]]);
      layersOf((k) {
        final p = Path()..moveTo(0, h);
        final base = h * (0.55 + k * 0.14);
        p.lineTo(0, base);
        p.cubicTo(
          w * 0.3,
          base - h * 0.08,
          w * 0.6,
          base + h * 0.06,
          w,
          base - h * 0.04,
        );
        return p
          ..lineTo(w, h)
          ..close();
      }, [col[1], col[2], col[3]]);
    case 'waves':
      vgrad([col[3], col[1], col[0]]);
      for (var k = 0; k < 6; k++) {
        final p = Path()..moveTo(0, h * (0.3 + k * 0.12));
        for (var x = 0.0; x <= w; x += w / 16) {
          p.lineTo(
            x,
            h * (0.3 + k * 0.12) + math.sin(x / w * 8 + k) * h * 0.012,
          );
        }
        c.drawPath(p, line(col[2], 2, 0.35));
      }
    case 'meadow' || 'hills':
      vgrad([col[0], col[1]]);
      layersOf(
        (k) {
          final base = h * (0.55 + k * 0.13);
          return Path()
            ..moveTo(0, h)
            ..lineTo(0, base)
            ..quadraticBezierTo(w * (0.3 + k * 0.2), base - h * 0.12, w, base)
            ..lineTo(w, h)
            ..close();
        },
        b.style == 'hills'
            ? [col[2], col[3]]
            : [col[1], col[1].withValues(alpha: 1)],
      );
      if (b.style == 'meadow') {
        for (var i = 0; i < 70; i++) {
          c.drawCircle(
            Offset(_r(s, i) * w, h * (0.62 + _r(s, i + 3) * 0.36)),
            2 + _r(s, i + 5) * 2.5,
            fill(i.isEven ? col[2] : col[3]),
          );
        }
      } else {
        for (var i = 0; i < 3; i++) {
          blob(
            Offset(_r(s, i) * w, h * 0.15),
            u * 0.12,
            const Color(0xFFFFFFFF),
            0.9,
          );
        }
      }
    case 'rain' || 'windowRain':
      vgrad([col[0], col[1]]);
      if (b.style == 'windowRain') {
        for (var i = 0; i < 8; i++) {
          blob(Offset(_r(s, i) * w, _r(s, i + 4) * h), u * 0.12, col[2], 0.35);
        }
      }
      for (var i = 0; i < 160; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 7) * h);
        c.drawLine(
          o,
          o + Offset(-2, 14),
          line(col[b.style == 'windowRain' ? 3 : 2], 1.2, 0.45),
        );
      }
      if (b.style == 'windowRain') {
        c.drawRect(
          Rect.fromLTWH(w / 2 - 4, 0, 8, h),
          fill(const Color(0xFF2B2B2B), 0.35),
        );
        c.drawRect(
          Rect.fromLTWH(0, h * 0.45, w, 8),
          fill(const Color(0xFF2B2B2B), 0.35),
        );
      }
    case 'bubbles':
      vgrad([col[0], col[1]]);
      for (var i = 0; i < 26; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 3) * h);
        final r = u * (0.03 + _r(s, i + 6) * 0.08);
        c.drawCircle(
          o,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.4),
              colors: [
                const Color(0xCCFFFFFF),
                col[2].withValues(alpha: 0.15),
                col[3].withValues(alpha: 0.3),
              ],
              stops: const [0, 0.6, 1],
            ).createShader(Rect.fromCircle(center: o, radius: r)),
        );
      }
    case 'leaves':
      vgrad([col[0], col[0]]);
      for (var i = 0; i < 60; i++) {
        c.save();
        c.translate(_r(s, i) * w, _r(s, i + 2) * h);
        c.rotate(_r(s, i + 4) * math.pi * 2);
        c.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: u * 0.08,
            height: u * 0.035,
          ),
          fill([col[1], col[2], col[3]][i % 3], 0.75),
        );
        c.restore();
      }
    case 'bamboo':
      vgrad([col[0], col[1]]);
      for (var i = 0; i < 9; i++) {
        final x = (i + 0.5) / 9 * w + (_r(s, i) - 0.5) * w * 0.05;
        final cw = u * 0.035;
        c.drawRect(
          Rect.fromLTWH(x - cw / 2, 0, cw, h),
          fill(i.isEven ? col[2] : col[3], 0.85),
        );
        for (var y = _r(s, i + 3) * h * 0.2; y < h; y += h * 0.16) {
          c.drawLine(
            Offset(x - cw / 2, y),
            Offset(x + cw / 2, y),
            line(col[3], 2, 0.8),
          );
        }
      }
    // ── Cozy ──
    case 'candle':
      vgrad([col[0], col[1], col[0]]);
      blob(Offset(w * 0.5, h * 0.7), u * 0.8, col[2], 0.35);
      blob(Offset(w * 0.5, h * 0.72), u * 0.3, col[3], 0.4);
      for (var i = 0; i < 40; i++) {
        c.drawCircle(
          Offset(_r(s, i) * w, h * (0.3 + _r(s, i + 1) * 0.6)),
          1.2,
          fill(col[2], 0.6),
        );
      }
    case 'knit':
      c.drawRect(rect, fill(col[0]));
      final st = u * 0.06;
      for (var y = 0.0; y < h + st; y += st) {
        for (var x = 0.0; x < w + st; x += st) {
          final row = (y / st).round();
          final color = row % 6 == 2
              ? col[1]
              : (row % 6 == 3 ? col[2] : col[0]);
          c.drawPath(
            Path()
              ..moveTo(x, y)
              ..quadraticBezierTo(
                x + st * 0.25,
                y + st * 0.9,
                x + st * 0.5,
                y + st * 0.7,
              )
              ..quadraticBezierTo(x + st * 0.75, y + st * 0.9, x + st, y),
            fill(Color.lerp(color, col[3], 0.15)!, 0.9),
          );
        }
      }
    case 'plaid' || 'gingham':
      c.drawRect(rect, fill(col[0]));
      final step = u * (b.style == 'gingham' ? 0.08 : 0.16);
      for (var x = 0.0; x < w + step; x += step) {
        c.drawRect(
          Rect.fromLTWH(x, 0, step / 2, h),
          fill(col[1], b.style == 'gingham' ? 0.35 : 0.45),
        );
        if (b.style == 'plaid')
          c.drawRect(Rect.fromLTWH(x + step * 0.7, 0, 2, h), fill(col[2], 0.8));
      }
      for (var y = 0.0; y < h + step; y += step) {
        c.drawRect(
          Rect.fromLTWH(0, y, w, step / 2),
          fill(col[1], b.style == 'gingham' ? 0.35 : 0.45),
        );
        if (b.style == 'plaid')
          c.drawRect(Rect.fromLTWH(0, y + step * 0.7, w, 2), fill(col[3], 0.8));
      }
    case 'wood':
      final plank = u * 0.22;
      for (var x = 0.0; x < w + plank; x += plank) {
        final i = (x / plank).round();
        c.drawRect(
          Rect.fromLTWH(x, 0, plank, h),
          fill([col[0], col[1], col[2]][i % 3]),
        );
        for (var k = 0; k < 6; k++) {
          final p = Path()..moveTo(x + plank * (0.15 + k * 0.13), 0);
          for (var y = 0.0; y <= h; y += h / 10) {
            p.lineTo(
              x +
                  plank * (0.15 + k * 0.13) +
                  math.sin(y / h * 7 + i + k) * plank * 0.04,
              y,
            );
          }
          c.drawPath(p, line(col[3], 1.2, 0.35));
        }
        c.drawLine(Offset(x, 0), Offset(x, h), line(col[3], 2, 0.7));
      }
    case 'quilt':
      final q = u * 0.18;
      for (var y = 0.0; y < h; y += q) {
        for (var x = 0.0; x < w; x += q) {
          final i = ((x / q).round() * 7 + (y / q).round() * 3) % 4;
          c.drawRect(Rect.fromLTWH(x, y, q, q), fill(col[i]));
          c.drawRect(
            Rect.fromLTWH(x + 3, y + 3, q - 6, q - 6),
            line(const Color(0xFFFFFFFF), 1.2, 0.6),
          );
        }
      }
    case 'polka':
      c.drawRect(rect, fill(col[0]));
      final g = u * 0.1;
      for (var y = 0.0; y < h + g; y += g) {
        for (var x = 0.0; x < w + g; x += g) {
          c.drawCircle(
            Offset(x + ((y / g).round().isOdd ? g / 2 : 0), y),
            g * 0.18,
            fill((y / g).round() % 3 == 0 ? col[2] : col[1], 0.85),
          );
        }
      }
    case 'books':
      c.drawRect(rect, fill(col[0]));
      final shelf = h / 6;
      for (var r = 0; r < 6; r++) {
        var x = 0.0;
        var i = 0;
        while (x < w) {
          final bw = u * (0.04 + _r(s, r * 50 + i) * 0.04);
          final bh = shelf * (0.6 + _r(s, r * 50 + i + 1) * 0.3);
          c.drawRect(
            Rect.fromLTWH(x, (r + 1) * shelf - bh - 6, bw - 2, bh),
            fill([col[1], col[2], col[3]][(r + i) % 3], 0.9),
          );
          x += bw;
          i++;
        }
        c.drawRect(
          Rect.fromLTWH(0, (r + 1) * shelf - 6, w, 6),
          fill(col[3], 0.6),
        );
      }
    case 'bokeh':
      vgrad([col[0], col[1]]);
      for (var i = 0; i < 40; i++) {
        c.drawCircle(
          Offset(_r(s, i) * w, _r(s, i + 1) * h),
          u * (0.02 + _r(s, i + 2) * 0.05),
          fill(i.isEven ? col[2] : col[3], 0.25 + _r(s, i + 3) * 0.3)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.01),
        );
      }
    // ── Tech ──
    case 'skyline':
      vgrad([col[0], col[1]]);
      for (var k = 0; k < 2; k++) {
        var x = 0.0;
        var i = 0;
        while (x < w) {
          final bw = u * (0.08 + _r(s, k * 40 + i) * 0.1);
          final bh = h * (0.2 + _r(s, k * 40 + i + 1) * (k == 0 ? 0.35 : 0.25));
          final r = Rect.fromLTWH(x, h - bh, bw - 3, bh);
          c.drawRect(r, fill(k == 0 ? col[1] : col[0], 0.95));
          for (var y = r.top + 8; y < h - 8; y += 14) {
            for (var xx = r.left + 5; xx < r.right - 5; xx += 10) {
              if (_r(s, (y * xx).round()) > 0.55) {
                c.drawRect(
                  Rect.fromLTWH(xx, y, 4, 6),
                  fill(_r(s, xx.round()) > 0.5 ? col[2] : col[3], 0.8),
                );
              }
            }
          }
          x += bw;
          i++;
        }
      }
    case 'synthgrid' || 'lasers':
      vgrad([col[0], col[1]]);
      final horizon = h * 0.55;
      if (b.style == 'synthgrid') {
        final o = Offset(w / 2, horizon);
        c.drawCircle(
          o,
          u * 0.28,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [col[3], col[2]],
            ).createShader(Rect.fromCircle(center: o, radius: u * 0.28)),
        );
      }
      c.drawRect(Rect.fromLTWH(0, horizon, w, h), fill(col[0], 0.9));
      for (var i = -12; i <= 12; i++) {
        c.drawLine(
          Offset(w / 2 + i * w * 0.04, horizon),
          Offset(w / 2 + i * w * 0.3, h),
          line(col[2], 1.4, 0.8),
        );
      }
      for (var k = 0; k < 10; k++) {
        final y = horizon + math.pow(k / 9, 1.8) * (h - horizon);
        c.drawLine(
          Offset(0, y),
          Offset(w, y),
          line(b.style == 'lasers' ? col[3] : col[2], 1.4, 0.8),
        );
      }
    case 'circuit':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 60; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 1) * h);
        final p = Path()
          ..moveTo(o.dx, o.dy)
          ..lineTo(o.dx + u * 0.1, o.dy)
          ..lineTo(o.dx + u * 0.16, o.dy + u * 0.06)
          ..lineTo(o.dx + u * 0.16, o.dy + u * 0.14);
        c.drawPath(p, line(col[2], 1.6, 0.6));
        c.drawCircle(o + Offset(u * 0.16, u * 0.14), 3, fill(col[3]));
      }
    case 'hex':
      c.drawRect(rect, fill(col[0]));
      final r = u * 0.06;
      for (var y = 0.0; y < h + r * 2; y += r * 1.5) {
        for (var x = 0.0; x < w + r * 2; x += r * 1.732) {
          final o = Offset(
            x + ((y / (r * 1.5)).round().isOdd ? r * 0.866 : 0),
            y,
          );
          final p = Path();
          for (var k = 0; k < 6; k++) {
            final a = math.pi / 6 + k * math.pi / 3;
            final pt = o + Offset(math.cos(a), math.sin(a)) * r * 0.95;
            k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
          }
          c.drawPath(
            p..close(),
            line(_r(s, (x + y).round()) > 0.9 ? col[3] : col[2], 1, 0.4),
          );
        }
      }
    case 'holo':
      c.drawRect(
        rect,
        Paint()
          ..shader = SweepGradient(
            center: const Alignment(-0.3, -0.5),
            colors: [col[0], col[1], col[2], col[3], col[0]],
          ).createShader(rect),
      );
      c.drawRect(rect, fill(const Color(0xFFFFFFFF), 0.25));
    case 'panels':
      c.drawRect(rect, fill(col[0]));
      final pw = u * 0.3;
      for (var y = 0.0; y < h; y += pw * 0.7) {
        for (var x = 0.0; x < w; x += pw) {
          final r = Rect.fromLTWH(x + 4, y + 4, pw - 8, pw * 0.7 - 8);
          c.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(6)),
            fill(col[1]),
          );
          c.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(6)),
            line(col[2], 1, 0.4),
          );
          if (_r(s, (x * y).round()) > 0.6)
            c.drawCircle(r.topRight + const Offset(-8, 8), 2.5, fill(col[3]));
        }
      }
    case 'datarain':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 40; i++) {
        final x = _r(s, i) * w;
        final y0 = _r(s, i + 2) * h;
        for (var k = 0; k < 14; k++) {
          c.drawRect(
            Rect.fromLTWH(x, y0 + k * 12, 5, 8),
            fill(k == 13 ? col[3] : col[2], 0.15 + k / 18),
          );
        }
      }
    case 'chrome':
      vgrad([col[3], col[0], col[2], col[1], col[3], col[0]]);
      c.drawRect(
        Rect.fromLTWH(0, h * 0.48, w, h * 0.02),
        fill(const Color(0xFFFFFFFF), 0.4),
      );
    case 'solarcity':
      vgrad([col[0], col[1]]);
      for (var i = 0; i < 7; i++) {
        final x = i / 7 * w;
        final bh = h * (0.3 + _r(s, i) * 0.3);
        final r = RRect.fromRectAndCorners(
          Rect.fromLTWH(x + 6, h - bh, w / 7 - 12, bh),
          topLeft: const Radius.circular(30),
          topRight: const Radius.circular(30),
        );
        c.drawRRect(r, fill(const Color(0xFFFFFFFF), 0.7));
        for (var k = 0; k < 4; k++) {
          c.drawCircle(
            Offset(x + w / 14, h - bh + 20 + k * bh / 4),
            9,
            fill(col[2], 0.85),
          );
        }
      }
      blob(Offset(w * 0.8, h * 0.15), u * 0.3, col[3], 0.5);
    // ── Retro ──
    case 'aeroSky':
      vgrad([col[0], col[1], const Color(0xFFFFFFFF)]);
      blob(Offset(w * 0.8, h * 0.1), u * 0.5, const Color(0xFFFFFFFF), 0.7);
      for (var i = 0; i < 5; i++) {
        final o = Offset(_r(s, i) * w, h * (0.15 + _r(s, i + 2) * 0.35));
        for (var k = 0; k < 3; k++) {
          c.drawCircle(
            o + Offset((k - 1) * u * 0.07, k == 1 ? -u * 0.03 : 0),
            u * 0.06,
            fill(const Color(0xFFFFFFFF), 0.85),
          );
        }
      }
      c.drawPath(
        Path()
          ..moveTo(0, h)
          ..lineTo(0, h * 0.8)
          ..quadraticBezierTo(w * 0.4, h * 0.68, w, h * 0.78)
          ..lineTo(w, h)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [col[2], Color.lerp(col[2], const Color(0xFF000000), 0.3)!],
          ).createShader(rect),
      );
    case 'pixel':
      final cell = u / 14;
      for (var y = 0.0; y < h; y += cell) {
        for (var x = 0.0; x < w; x += cell) {
          final t = y / h;
          final grass = t > 0.7 + math.sin(x / w * 6) * 0.03;
          final cloud =
              t < 0.4 &&
              _r(s, (x / cell).round() + (y / cell).round() * 99) > 0.93;
          c.drawRect(
            Rect.fromLTWH(x, y, cell + 0.5, cell + 0.5),
            fill(
              grass
                  ? ((x / cell).round().isEven ? col[1] : col[3])
                  : cloud
                  ? const Color(0xFFFFFFFF)
                  : col[0],
            ),
          );
        }
      }
      c.drawRect(
        Rect.fromLTWH(w * 0.75, h * 0.1, cell * 3, cell * 3),
        fill(col[2]),
      );
    case 'crt':
      vgrad([col[1], col[0]]);
      for (var y = 0.0; y < h; y += 4) {
        c.drawRect(
          Rect.fromLTWH(0, y, w, 1.5),
          fill(const Color(0xFF000000), 0.25),
        );
      }
      blob(Offset(w / 2, h / 2), u * 0.8, col[2], 0.18);
      c.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(14), const Radius.circular(40)),
        line(col[3], 3, 0.35),
      );
    case 'vapor':
      vgrad([col[0], col[2], col[1]]);
      final o = Offset(w / 2, h * 0.4);
      c.drawCircle(o, u * 0.25, fill(col[3], 0.9));
      for (var k = 0; k < 6; k++) {
        c.drawRect(
          Rect.fromLTWH(0, o.dy + k * u * 0.05, w, u * 0.012 * (k + 1)),
          fill(col[2]),
        );
      }
      for (var i = -10; i <= 10; i++) {
        c.drawLine(
          Offset(w / 2 + i * w * 0.05, h * 0.65),
          Offset(w / 2 + i * w * 0.35, h),
          line(col[1], 1.2, 0.8),
        );
      }
    case 'sunset':
      vgrad([col[0], col[1], col[2]]);
      final o = Offset(w / 2, h * 0.62);
      c.drawCircle(
        o,
        u * 0.3,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [col[2], col[3]],
          ).createShader(Rect.fromCircle(center: o, radius: u * 0.3)),
      );
      for (var k = 0; k < 6; k++) {
        c.drawRect(
          Rect.fromLTWH(0, o.dy + k * u * 0.05, w, u * 0.015 + k * 2),
          fill(col[1]),
        );
      }
      c.drawRect(Rect.fromLTWH(0, h * 0.8, w, h * 0.2), fill(col[0]));
    case 'memphis':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 46; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 1) * h);
        final color = [col[1], col[2], col[3]][i % 3];
        switch (i % 4) {
          case 0:
            final p = Path()..moveTo(o.dx, o.dy);
            for (var k = 1; k < 6; k++) {
              p.lineTo(o.dx + k * 8, o.dy + (k.isEven ? -8 : 8));
            }
            c.drawPath(p, line(color, 3));
          case 1:
            c.drawCircle(o, 7, line(color, 3));
          case 2:
            c.drawPath(
              Path()
                ..moveTo(o.dx, o.dy - 9)
                ..lineTo(o.dx + 9, o.dy + 7)
                ..lineTo(o.dx - 9, o.dy + 7)
                ..close(),
              fill(color),
            );
          default:
            c.drawRect(
              Rect.fromCenter(center: o, width: 10, height: 10),
              fill(color),
            );
        }
      }
    case 'terrazzo':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 160; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 1) * h);
        final p = Path();
        final n = 5 + (i % 3);
        final rr = 3 + _r(s, i + 2) * 9;
        for (var k = 0; k < n; k++) {
          final a = k / n * math.pi * 2;
          final rad = rr * (0.6 + _r(s, i * 7 + k) * 0.6);
          final pt = o + Offset(math.cos(a), math.sin(a)) * rad;
          k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        c.drawPath(p..close(), fill([col[1], col[2], col[3]][i % 3], 0.85));
      }
    // ── Academic ──
    case 'chalk':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 300; i++) {
        c.drawCircle(
          Offset(_r(s, i) * w, _r(s, i + 1) * h),
          1.5,
          fill(col[1], 0.6),
        );
      }
      for (var i = 0; i < 8; i++) {
        final o = Offset(_r(s, i + 40) * w, _r(s, i + 41) * h);
        c.drawLine(o, o + Offset(u * 0.15, -u * 0.02), line(col[2], 2.2, 0.18));
      }
      c.drawRect(
        Rect.fromLTWH(0, h - 18, w, 18),
        fill(const Color(0xFF6B4226)),
      );
    case 'notebook' || 'cornell':
      c.drawRect(rect, fill(col[0]));
      for (var y = h * 0.08; y < h; y += 26) {
        c.drawLine(Offset(0, y), Offset(w, y), line(col[2], 1, 0.6));
      }
      c.drawLine(
        Offset(w * (b.style == 'cornell' ? 0.3 : 0.14), 0),
        Offset(
          w * (b.style == 'cornell' ? 0.3 : 0.14),
          h * (b.style == 'cornell' ? 0.78 : 1),
        ),
        line(col[3], 1.6, 0.8),
      );
      if (b.style == 'cornell') {
        c.drawLine(
          Offset(0, h * 0.78),
          Offset(w, h * 0.78),
          line(col[3], 1.6, 0.8),
        );
      }
    case 'graph' || 'blueprint' || 'dotgrid':
      c.drawRect(rect, fill(col[0]));
      final g = b.style == 'dotgrid' ? 22.0 : 16.0;
      for (var x = 0.0; x < w; x += g) {
        for (var y = 0.0; y < h; y += g) {
          if (b.style == 'dotgrid')
            c.drawCircle(Offset(x, y), 1.4, fill(col[2], 0.7));
        }
        if (b.style != 'dotgrid') {
          c.drawLine(
            Offset(x, 0),
            Offset(x, h),
            line(
              col[2],
              (x / g).round() % 5 == 0 ? 1.2 : 0.5,
              b.style == 'blueprint' ? 0.35 : 0.6,
            ),
          );
        }
      }
      if (b.style != 'dotgrid') {
        for (var y = 0.0; y < h; y += g) {
          c.drawLine(
            Offset(0, y),
            Offset(w, y),
            line(
              col[2],
              (y / g).round() % 5 == 0 ? 1.2 : 0.5,
              b.style == 'blueprint' ? 0.35 : 0.6,
            ),
          );
        }
      }
      if (b.style == 'blueprint') {
        c.drawCircle(Offset(w * 0.7, h * 0.3), u * 0.2, line(col[2], 1.5, 0.6));
        c.drawRect(
          Rect.fromLTWH(w * 0.15, h * 0.55, u * 0.4, u * 0.25),
          line(col[2], 1.5, 0.6),
        );
      }
    case 'parchment':
      c.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [col[0], col[1]],
            radius: 0.9,
          ).createShader(rect),
      );
      for (var i = 0; i < 400; i++) {
        c.drawCircle(
          Offset(_r(s, i) * w, _r(s, i + 1) * h),
          1.2,
          fill(col[2], 0.12),
        );
      }
      c.drawRect(
        rect.deflate(4),
        line(col[3], 8, 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    case 'ivybrick':
      final bw = u * 0.18, bh = bw * 0.4;
      for (var y = 0.0; y < h; y += bh) {
        final off = (y / bh).round().isOdd ? bw / 2 : 0.0;
        for (var x = -off; x < w; x += bw) {
          c.drawRect(
            Rect.fromLTWH(x + 2, y + 2, bw - 4, bh - 4),
            fill(Color.lerp(col[0], col[1], _r(s, (x * 3 + y).round()))!),
          );
        }
      }
      for (var i = 0; i < 40; i++) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(_r(s, i) * w * 0.4, _r(s, i + 1) * h),
            width: 16,
            height: 10,
          ),
          fill(col[2], 0.9),
        );
      }
    case 'sketch':
      c.drawRect(rect, fill(col[0]));
      for (var i = -40; i < 80; i++) {
        c.drawLine(
          Offset(i * 14.0, 0),
          Offset(i * 14.0 - h * 0.6, h),
          line(col[2], 0.6, 0.12),
        );
      }
      c.drawCircle(Offset(w * 0.75, h * 0.2), u * 0.12, line(col[3], 2, 0.5));
    // ── Artistic ──
    case 'watercolor':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 9; i++) {
        blob(
          Offset(_r(s, i) * w, _r(s, i + 3) * h),
          u * (0.3 + _r(s, i + 5) * 0.25),
          col[1 + i % 3],
          0.35,
        );
      }
    case 'splatter':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 18; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 1) * h);
        c.drawCircle(
          o,
          u * (0.01 + _r(s, i + 2) * 0.04),
          fill(i % 4 == 0 ? col[3] : col[2], 0.85),
        );
        for (var k = 0; k < 8; k++) {
          final a = _r(s, i * 9 + k) * math.pi * 2;
          c.drawCircle(
            o +
                Offset(math.cos(a), math.sin(a)) *
                    u *
                    (0.04 + _r(s, i + k) * 0.06),
            1.5 + _r(s, k) * 3,
            fill(i % 4 == 0 ? col[3] : col[2], 0.8),
          );
        }
      }
    case 'marble':
      c.drawRect(rect, fill(col[0]));
      for (var k = 0; k < 9; k++) {
        final p = Path()..moveTo(-20, _r(s, k) * h);
        var y = _r(s, k) * h;
        for (var x = 0.0; x <= w + 20; x += w / 10) {
          y += (_r(s, k * 30 + (x / 10).round()) - 0.45) * h * 0.08;
          p.lineTo(x, y);
        }
        c.drawPath(
          p,
          line(k.isEven ? col[2] : col[3], 1 + _r(s, k + 4) * 2.5, 0.45),
        );
      }
    case 'deco':
      c.drawRect(rect, fill(col[0]));
      final fw = u * 0.36;
      for (var y = 0.0; y < h + fw; y += fw * 0.5) {
        for (var x = 0.0; x < w + fw; x += fw) {
          final o = Offset(
            x + ((y / (fw * 0.5)).round().isOdd ? fw / 2 : 0),
            y,
          );
          for (var k = 1; k <= 3; k++) {
            c.drawArc(
              Rect.fromCircle(center: o, radius: fw * 0.17 * k),
              math.pi,
              math.pi,
              false,
              line(col[2], 1.4, 0.8),
            );
          }
        }
      }
    case 'bauhaus':
      c.drawRect(rect, fill(col[0]));
      c.drawCircle(Offset(w * 0.25, h * 0.2), u * 0.2, fill(col[1]));
      c.drawRect(
        Rect.fromLTWH(w * 0.55, h * 0.35, u * 0.38, u * 0.38),
        fill(col[2]),
      );
      c.drawPath(
        Path()
          ..moveTo(w * 0.1, h * 0.85)
          ..lineTo(w * 0.45, h * 0.85)
          ..lineTo(w * 0.275, h * 0.6)
          ..close(),
        fill(col[3]),
      );
      c.drawLine(
        Offset(0, h * 0.5),
        Offset(w, h * 0.48),
        line(const Color(0xFF111111), 4, 0.8),
      );
    case 'geometric':
      c.drawRect(rect, fill(col[0]));
      final t = u * 0.2;
      for (var y = 0.0; y < h + t; y += t) {
        for (var x = 0.0; x < w + t; x += t) {
          final i = (_r(s, (x * 7 + y).round()) * 4).floor();
          final p = Path();
          switch (i) {
            case 0:
              p
                ..moveTo(x, y)
                ..lineTo(x + t, y)
                ..lineTo(x, y + t);
            case 1:
              p
                ..moveTo(x + t, y)
                ..lineTo(x + t, y + t)
                ..lineTo(x, y + t);
            case 2:
              p
                ..moveTo(x, y)
                ..lineTo(x + t, y + t)
                ..lineTo(x, y + t);
            default:
              p
                ..moveTo(x, y)
                ..lineTo(x + t, y)
                ..lineTo(x + t, y + t);
          }
          c.drawPath(p..close(), fill([col[1], col[2], col[3]][i % 3], 0.85));
        }
      }
    case 'collage':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 14; i++) {
        c.save();
        c.translate(_r(s, i) * w, _r(s, i + 1) * h);
        c.rotate((_r(s, i + 2) - 0.5) * 0.5);
        final r = Rect.fromCenter(
          center: Offset.zero,
          width: u * (0.25 + _r(s, i + 3) * 0.2),
          height: u * (0.18 + _r(s, i + 4) * 0.2),
        );
        c.drawRect(r.translate(3, 4), fill(const Color(0xFF000000), 0.12));
        c.drawRect(
          r,
          fill([col[1], col[2], col[3], const Color(0xFFFFFFFF)][i % 4], 0.9),
        );
        c.restore();
      }
    case 'halftone':
      c.drawRect(rect, fill(col[0]));
      const g = 14.0;
      for (var y = 0.0; y < h; y += g) {
        for (var x = 0.0; x < w; x += g) {
          final d =
              (Offset(x, y) - Offset(w * 0.3, h * 0.3)).distance / (u * 0.9);
          c.drawCircle(
            Offset(x, y),
            (g / 2) * (1 - d).clamp(0.08, 1.0),
            fill(col[1], 0.85),
          );
        }
      }
    case 'strokes':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 22; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 1) * h);
        final p = Path()
          ..moveTo(o.dx, o.dy)
          ..quadraticBezierTo(
            o.dx + u * 0.15,
            o.dy - u * 0.1,
            o.dx + u * 0.32,
            o.dy + u * 0.02,
          );
        c.drawPath(
          p,
          line(
            [col[1], col[2], col[3]][i % 3],
            u * (0.03 + _r(s, i + 2) * 0.03),
            0.6,
          ),
        );
      }
    // ── Gothic ──
    case 'arches':
      vgrad([col[1], col[0]]);
      final aw = w / 4;
      for (var i = 0; i < 4; i++) {
        final x = i * aw;
        final p = Path()
          ..moveTo(x + aw * 0.15, h)
          ..lineTo(x + aw * 0.15, h * 0.4)
          ..quadraticBezierTo(x + aw * 0.15, h * 0.18, x + aw / 2, h * 0.12)
          ..quadraticBezierTo(x + aw * 0.85, h * 0.18, x + aw * 0.85, h * 0.4)
          ..lineTo(x + aw * 0.85, h);
        c.drawPath(p, fill(col[2], 0.25));
        c.drawPath(p, line(col[3], 2, 0.5));
      }
    case 'stained' || 'mosaic':
      c.drawRect(rect, fill(col[0]));
      final cs = u * (b.style == 'mosaic' ? 0.06 : 0.16);
      for (var y = 0.0; y < h; y += cs) {
        for (var x = 0.0; x < w; x += cs) {
          final j = (int k) =>
              (_r(s, (x * 13 + y * 7).round() + k) - 0.5) * cs * 0.25;
          final p = Path()
            ..moveTo(x + j(1), y + j(2))
            ..lineTo(x + cs + j(3), y + j(4))
            ..lineTo(x + cs + j(5), y + cs + j(6))
            ..lineTo(x + j(7), y + cs + j(8))
            ..close();
          c.drawPath(
            p,
            fill([col[1], col[2], col[3]][((x + y) / cs).round() % 3], 0.85),
          );
          c.drawPath(p, line(col[0], b.style == 'mosaic' ? 1.5 : 3));
        }
      }
    case 'damask':
      c.drawRect(rect, fill(col[0]));
      final dw = u * 0.3;
      for (var y = 0.0; y < h + dw; y += dw) {
        for (var x = 0.0; x < w + dw; x += dw) {
          final o = Offset(x + ((y / dw).round().isOdd ? dw / 2 : 0), y);
          for (var k = 0; k < 4; k++) {
            c.save();
            c.translate(o.dx, o.dy);
            c.rotate(k * math.pi / 2);
            c.drawOval(
              Rect.fromLTWH(-dw * 0.05, 0, dw * 0.1, dw * 0.28),
              fill(col[k.isEven ? 1 : 2], 0.6),
            );
            c.restore();
          }
          c.drawCircle(o, dw * 0.04, fill(col[3], 0.7));
        }
      }
    case 'grunge' || 'matte':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < (b.style == 'grunge' ? 70 : 500); i++) {
        c.drawCircle(
          Offset(_r(s, i) * w, _r(s, i + 1) * h),
          b.style == 'grunge' ? u * _r(s, i + 2) * 0.06 : 1.2,
          fill(i.isEven ? col[1] : col[2], b.style == 'grunge' ? 0.2 : 0.18),
        );
      }
      if (b.style == 'grunge') {
        for (var i = 0; i < 12; i++) {
          c.drawLine(
            Offset(_r(s, i + 80) * w, 0),
            Offset(_r(s, i + 90) * w, h),
            line(col[3], 1, 0.18),
          );
        }
      }
    case 'cobweb':
      vgrad([col[1], col[0]]);
      for (final o in [Offset.zero, Offset(w, 0)]) {
        for (var k = 0; k < 9; k++) {
          final a = (o.dx == 0 ? 0 : math.pi / 2) + k * math.pi / 16;
          c.drawLine(
            o,
            o +
                Offset(math.cos(a) * (o.dx == 0 ? 1 : -1), math.sin(a)) *
                    u *
                    0.9,
            line(col[2], 1, 0.45),
          );
        }
        for (var r = 1; r <= 6; r++) {
          c.drawArc(
            Rect.fromCircle(center: o, radius: u * 0.13 * r),
            o.dx == 0 ? 0 : math.pi / 2,
            math.pi / 2,
            false,
            line(col[2], 1, 0.35),
          );
        }
      }
    case 'graveyard':
      vgrad([col[0], col[1]]);
      stars(100, const Color(0xFFFFFFFF), maxR: 1);
      c.drawCircle(Offset(w * 0.75, h * 0.16), u * 0.1, fill(col[2]));
      for (var i = 0; i < 6; i++) {
        final x = (i + 0.5) / 6 * w;
        final top = h * (0.72 + _r(s, i) * 0.06);
        c.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x - 18, top, 36, h * 0.12),
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
          ),
          fill(col[3]),
        );
      }
      c.drawRect(Rect.fromLTWH(0, h * 0.82, w, h), fill(col[0]));
    case 'feathers':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 26; i++) {
        c.save();
        c.translate(_r(s, i) * w, _r(s, i + 1) * h);
        c.rotate(_r(s, i + 2) * math.pi);
        c.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: u * 0.06,
            height: u * 0.22,
          ),
          fill(i.isEven ? col[1] : col[2], 0.8),
        );
        c.drawLine(
          Offset(0, -u * 0.11),
          Offset(0, u * 0.12),
          line(col[3], 1, 0.6),
        );
        c.restore();
      }
    case 'chains':
      c.drawRect(rect, fill(col[0]));
      for (var x = u * 0.08; x < w; x += u * 0.2) {
        for (var y = 0.0; y < h; y += u * 0.07) {
          final vertical = (y / (u * 0.07)).round().isEven;
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(x, y),
                width: vertical ? u * 0.035 : u * 0.06,
                height: vertical ? u * 0.06 : u * 0.035,
              ),
              Radius.circular(u * 0.02),
            ),
            line(vertical ? col[2] : col[3], 2.4, 0.6),
          );
        }
      }
    // ── Cute ──
    case 'cuteClouds':
      vgrad([col[0], col[1]]);
      for (var i = 0; i < 9; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 2) * h);
        for (var k = 0; k < 3; k++) {
          c.drawCircle(
            o + Offset((k - 1) * u * 0.06, k == 1 ? -u * 0.03 : 0),
            u * 0.055,
            fill(col[2]),
          );
        }
        c.drawCircle(
          o + Offset(-u * 0.02, 0),
          2,
          fill(const Color(0xFF555555)),
        );
        c.drawCircle(o + Offset(u * 0.02, 0), 2, fill(const Color(0xFF555555)));
        c.drawCircle(o + Offset(-u * 0.04, u * 0.012), 3.5, fill(col[3], 0.6));
      }
    case 'hearts':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 40; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 1) * h);
        final r = u * (0.02 + _r(s, i + 2) * 0.03);
        c.drawPath(
          Path()
            ..moveTo(o.dx, o.dy + r)
            ..cubicTo(
              o.dx - r * 2,
              o.dy - r * 0.5,
              o.dx - r * 0.6,
              o.dy - r * 1.6,
              o.dx,
              o.dy - r * 0.6,
            )
            ..cubicTo(
              o.dx + r * 0.6,
              o.dy - r * 1.6,
              o.dx + r * 2,
              o.dy - r * 0.5,
              o.dx,
              o.dy + r,
            ),
          fill([col[1], col[2], col[3]][i % 3], 0.8),
        );
      }
    case 'stripes':
      c.drawRect(rect, fill(col[0]));
      for (var i = -30; i < 40; i++) {
        final x = i * u * 0.09;
        c.drawPath(
          Path()
            ..moveTo(x, 0)
            ..lineTo(x + u * 0.045, 0)
            ..lineTo(x + u * 0.045 - h * 0.6, h)
            ..lineTo(x - h * 0.6, h)
            ..close(),
          fill(i % 3 == 0 ? col[1] : (i % 3 == 1 ? col[2] : col[3]), 0.55),
        );
      }
    case 'sprinkles':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 180; i++) {
        c.save();
        c.translate(_r(s, i) * w, _r(s, i + 1) * h);
        c.rotate(_r(s, i + 2) * math.pi);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 10, height: 3),
            const Radius.circular(2),
          ),
          fill([col[1], col[2], col[3]][i % 3]),
        );
        c.restore();
      }
    case 'rainbow':
      c.drawRect(rect, fill(col[0]));
      final o = Offset(w / 2, h * 0.75);
      const cs = [
        Color(0xFFFF8FAB),
        Color(0xFFFFB36B),
        Color(0xFFFFE066),
        Color(0xFF8FE3CF),
        Color(0xFF8FB8FF),
        Color(0xFFC3A6FF),
      ];
      for (var k = 0; k < cs.length; k++) {
        c.drawArc(
          Rect.fromCircle(center: o, radius: u * (0.6 - k * 0.06)),
          math.pi,
          math.pi,
          false,
          line(cs[k], u * 0.055, 0.7),
        );
      }
    case 'checker':
      final q = u * 0.12;
      for (var y = 0.0; y < h; y += q) {
        for (var x = 0.0; x < w; x += q) {
          final i = ((x / q).round() + (y / q).round()) % 2;
          c.drawRect(
            Rect.fromLTWH(x, y, q + 0.5, q + 0.5),
            fill(i == 0 ? col[0] : col[1]),
          );
        }
      }
      for (var i = 0; i < 20; i++) {
        c.drawCircle(
          Offset(_r(s, i) * w, _r(s, i + 1) * h),
          4,
          fill(col[2 + i % 2], 0.7),
        );
      }
    case 'paws':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 26; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 1) * h);
        final color = i.isEven ? col[2] : col[1];
        c.drawOval(
          Rect.fromCenter(center: o, width: 18, height: 14),
          fill(color, 0.75),
        );
        for (var k = 0; k < 4; k++) {
          c.drawCircle(
            o + Offset(-12 + k * 8.0, -13 + (k == 0 || k == 3 ? 4 : 0)),
            4,
            fill(color, 0.75),
          );
        }
      }
    // ── Cultural ──
    case 'tiles' || 'azulejo':
      c.drawRect(rect, fill(col[b.style == 'azulejo' ? 0 : 3]));
      final t = u * 0.22;
      for (var y = 0.0; y < h + t; y += t) {
        for (var x = 0.0; x < w + t; x += t) {
          final o = Offset(x + t / 2, y + t / 2);
          final p = Path();
          for (var k = 0; k < 16; k++) {
            final a = k * math.pi / 8;
            final r = k.isEven ? t * 0.45 : t * 0.25;
            final pt = o + Offset(math.cos(a), math.sin(a)) * r;
            k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
          }
          c.drawPath(p..close(), fill(col[b.style == 'azulejo' ? 1 : 0], 0.85));
          c.drawCircle(o, t * 0.1, fill(col[2]));
          c.drawRect(
            Rect.fromLTWH(x, y, t, t),
            line(col[b.style == 'azulejo' ? 2 : 1], 1, 0.6),
          );
        }
      }
    case 'shoji':
      c.drawRect(rect, fill(col[0]));
      final g = u * 0.16;
      for (var x = 0.0; x < w; x += g) {
        c.drawLine(Offset(x, 0), Offset(x, h), line(col[2], 3, 0.8));
      }
      for (var y = 0.0; y < h; y += g * 1.4) {
        c.drawLine(Offset(0, y), Offset(w, y), line(col[2], 3, 0.8));
      }
      blob(Offset(w * 0.3, h * 0.3), u * 0.5, col[3], 0.4);
    case 'seigaiha':
      c.drawRect(rect, fill(col[0]));
      final r = u * 0.1;
      for (var y = -r; y < h + r; y += r * 0.5) {
        for (var x = -r; x < w + r; x += r * 2) {
          final o = Offset(x + ((y / (r * 0.5)).round().isOdd ? r : 0), y);
          for (var k = 4; k >= 1; k--) {
            c.drawCircle(o, r * k / 4, fill(k.isEven ? col[1] : col[0]));
            c.drawCircle(o, r * k / 4, line(col[k == 4 ? 2 : 3], 1, 0.7));
          }
        }
      }
    case 'kente':
      final bw = u * 0.12;
      for (var y = 0.0; y < h; y += bw) {
        for (var x = 0.0; x < w; x += bw) {
          final i = ((x / bw).round() + (y / bw).round() * 2) % 4;
          c.drawRect(Rect.fromLTWH(x, y, bw + 0.5, bw + 0.5), fill(col[i]));
          if (i == 0) {
            for (var k = 1; k < 4; k++) {
              c.drawLine(
                Offset(x, y + bw * k / 4),
                Offset(x + bw, y + bw * k / 4),
                line(col[3], 2),
              );
            }
          }
        }
      }
    case 'columns':
      vgrad([col[0], col[1]]);
      final cw = w / 5;
      for (var i = 0; i < 5; i++) {
        final x = i * cw + cw * 0.25;
        final r = Rect.fromLTWH(x, h * 0.18, cw * 0.5, h * 0.7);
        c.drawRect(r, fill(const Color(0xFFFFFFFF), 0.6));
        for (var k = 1; k < 4; k++) {
          c.drawLine(
            Offset(r.left + r.width * k / 4, r.top),
            Offset(r.left + r.width * k / 4, r.bottom),
            line(col[2], 1.2, 0.6),
          );
        }
        c.drawRect(
          Rect.fromLTWH(x - cw * 0.06, h * 0.15, cw * 0.62, h * 0.04),
          fill(col[3], 0.5),
        );
      }
      c.drawRect(Rect.fromLTWH(0, h * 0.88, w, h * 0.12), fill(col[2], 0.5));
    case 'lanterns':
      vgrad([col[0], col[1]]);
      for (var i = 0; i < 12; i++) {
        final o = Offset(_r(s, i) * w, h * (0.1 + _r(s, i + 1) * 0.7));
        blob(o, u * 0.1, col[3], 0.35);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: o, width: u * 0.07, height: u * 0.09),
            Radius.circular(u * 0.03),
          ),
          fill(i.isEven ? col[2] : col[3], 0.9),
        );
        c.drawLine(
          o - Offset(0, u * 0.045),
          o - Offset(0, u * 0.12),
          line(col[3], 1, 0.6),
        );
      }
    case 'batik':
      c.drawRect(rect, fill(col[0]));
      final g = u * 0.24;
      for (var y = 0.0; y < h + g; y += g) {
        for (var x = 0.0; x < w + g; x += g) {
          final o = Offset(x, y);
          for (var k = 0; k < 8; k++) {
            final a = k * math.pi / 4;
            c.drawOval(
              Rect.fromCenter(
                center: o + Offset(math.cos(a), math.sin(a)) * g * 0.22,
                width: g * 0.18,
                height: g * 0.1,
              ),
              fill(col[2], 0.7),
            );
          }
          c.drawCircle(o, g * 0.08, fill(col[3]));
          c.drawCircle(o, g * 0.4, line(col[1], 2, 0.6));
        }
      }
    case 'knots':
      c.drawRect(rect, fill(col[0]));
      final g = u * 0.2;
      for (var y = g / 2; y < h; y += g) {
        for (var x = g / 2; x < w; x += g) {
          final o = Offset(x, y);
          for (var k = 0; k < 4; k++) {
            c.drawArc(
              Rect.fromCircle(
                center:
                    o +
                    Offset(
                          math.cos(k * math.pi / 2),
                          math.sin(k * math.pi / 2),
                        ) *
                        g *
                        0.18,
                radius: g * 0.2,
              ),
              k * math.pi / 2 + math.pi / 2,
              math.pi,
              false,
              line(col[2], 2.4, 0.8),
            );
          }
        }
      }
    // ── Minimal ──
    case 'soft':
      vgrad([col[0], col[1]]);
      blob(Offset(w * 0.15, h * 0.2), u * 0.7, col[3], 0.18);
      blob(Offset(w * 0.9, h * 0.85), u * 0.7, col[2], 0.3);
    case 'layers':
      c.drawRect(rect, fill(col[0]));
      for (var k = 0; k < 4; k++) {
        final p = Path()
          ..moveTo(0, h * (0.35 + k * 0.17))
          ..cubicTo(
            w * 0.3,
            h * (0.3 + k * 0.17),
            w * 0.6,
            h * (0.42 + k * 0.17),
            w,
            h * (0.33 + k * 0.17),
          )
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        c.drawShadow(p, const Color(0xFF000000), 6, false);
        c.drawPath(p, fill(Color.lerp(col[1], col[3], k / 3)!));
      }
    case 'lines':
      c.drawRect(rect, fill(col[0]));
      for (var k = 0; k < 24; k++) {
        final p = Path()..moveTo(0, h * (0.2 + k * 0.03));
        p.cubicTo(
          w * 0.3,
          h * (0.1 + k * 0.03),
          w * 0.7,
          h * (0.5 + k * 0.02),
          w,
          h * (0.35 + k * 0.03),
        );
        c.drawPath(p, line(col[k % 6 == 0 ? 3 : 2], 1, 0.5));
      }
    case 'fold':
      c.drawRect(rect, fill(col[0]));
      for (var k = 0; k < 4; k++) {
        final p = Path()
          ..moveTo(w * k / 4, 0)
          ..lineTo(w * (k + 1) / 4, 0)
          ..lineTo(w * (k + 1) / 4, h)
          ..lineTo(w * k / 4, h)
          ..close();
        c.drawPath(
          p,
          Paint()
            ..shader = LinearGradient(
              colors: [k.isEven ? col[2] : col[1], k.isEven ? col[1] : col[3]],
            ).createShader(Rect.fromLTWH(w * k / 4, 0, w / 4, h)),
        );
      }
    case 'grain':
      vgrad([col[0], col[1]]);
      for (var i = 0; i < 900; i++) {
        c.drawCircle(
          Offset(_r(s, i) * w, _r(s, i + 1) * h),
          1,
          fill(i.isEven ? col[2] : col[3], 0.25),
        );
      }
    case 'pebbles':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 70; i++) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(_r(s, i) * w, _r(s, i + 1) * h),
            width: u * (0.05 + _r(s, i + 2) * 0.07),
            height: u * (0.035 + _r(s, i + 3) * 0.04),
          ),
          fill([col[1], col[2], col[3]][i % 3], 0.8),
        );
      }
    case 'duowave':
      vgrad([col[0], col[1]]);
      for (var k = 0; k < 3; k++) {
        final p = Path()..moveTo(0, h * (0.55 + k * 0.12));
        for (var x = 0.0; x <= w; x += w / 20) {
          p.lineTo(
            x,
            h * (0.55 + k * 0.12) + math.sin(x / w * 4 + k) * h * 0.03,
          );
        }
        p
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        c.drawPath(p, fill(k == 2 ? col[3] : col[2], 0.55));
      }
    case 'frost':
      vgrad([col[0], col[1]]);
      for (var i = 0; i < 36; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 1) * h);
        final r = u * (0.015 + _r(s, i + 2) * 0.025);
        for (var k = 0; k < 3; k++) {
          final a = k * math.pi / 3;
          c.drawLine(
            o - Offset(math.cos(a), math.sin(a)) * r,
            o + Offset(math.cos(a), math.sin(a)) * r,
            line(col[2], 1.2, 0.6),
          );
        }
      }
    // ── Music ──
    case 'vinyl':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 5; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 1) * h);
        final r = u * (0.18 + _r(s, i + 2) * 0.12);
        c.drawCircle(o, r, fill(col[1]));
        for (var k = 1; k < 8; k++) {
          c.drawCircle(
            o,
            r * (0.35 + k * 0.08),
            line(const Color(0xFF333333), 0.8),
          );
        }
        c.drawCircle(o, r * 0.3, fill(i.isEven ? col[2] : col[3]));
        c.drawCircle(o, r * 0.04, fill(col[0]));
      }
    case 'piano':
      c.drawRect(rect, fill(col[0]));
      final kw = w / 10;
      final top = h * 0.55;
      for (var i = 0; i < 10; i++) {
        c.drawRect(
          Rect.fromLTWH(i * kw + 1, top, kw - 2, h - top),
          fill(col[1]),
        );
        if (i % 7 != 2 && i % 7 != 6) {
          c.drawRect(
            Rect.fromLTWH(i * kw + kw * 0.65, top, kw * 0.6, (h - top) * 0.6),
            fill(col[2]),
          );
        }
      }
      c.drawRect(Rect.fromLTWH(0, top - 6, w, 6), fill(col[3]));
    case 'staff':
      c.drawRect(rect, fill(col[0]));
      for (var g = 0; g < 4; g++) {
        final y0 = h * (0.15 + g * 0.22);
        for (var k = 0; k < 5; k++) {
          c.drawLine(
            Offset(0, y0 + k * 10),
            Offset(w, y0 + k * 10),
            line(col[2], 1, 0.5),
          );
        }
        for (var i = 0; i < 6; i++) {
          final x = (i + 0.5) / 6 * w;
          final y = y0 + (_r(s, g * 9 + i) * 40);
          c.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 12, height: 9),
            fill(i % 3 == 0 ? col[3] : col[2], 0.7),
          );
          c.drawLine(
            Offset(x + 6, y),
            Offset(x + 6, y - 28),
            line(i % 3 == 0 ? col[3] : col[2], 1.4, 0.7),
          );
        }
      }
    case 'jazz' || 'spotlights':
      vgrad([col[0], col[1]]);
      for (var i = 0; i < 3; i++) {
        final top = Offset(w * (0.2 + i * 0.3), -10);
        c.drawPath(
          Path()
            ..moveTo(top.dx - 10, top.dy)
            ..lineTo(top.dx + 10, top.dy)
            ..lineTo(top.dx + u * 0.35, h)
            ..lineTo(top.dx - u * 0.35, h)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (i.isEven ? col[2] : col[3]).withValues(alpha: 0.4),
                (i.isEven ? col[2] : col[3]).withValues(alpha: 0),
              ],
            ).createShader(rect),
        );
      }
      if (b.style == 'jazz') {
        for (var i = 0; i < 30; i++) {
          c.drawCircle(
            Offset(_r(s, i) * w, _r(s, i + 1) * h),
            2,
            fill(col[2], 0.5),
          );
        }
      }
    case 'film':
      c.drawRect(rect, fill(col[0]));
      for (final x in [w * 0.12, w * 0.88]) {
        c.drawRect(Rect.fromLTWH(x - w * 0.08, 0, w * 0.16, h), fill(col[1]));
        for (var y = 6.0; y < h; y += 20) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 5, y, 10, 10),
              const Radius.circular(2),
            ),
            fill(col[3], 0.8),
          );
        }
      }
      for (var y = 0.0; y < h; y += h / 5) {
        c.drawRect(
          Rect.fromLTWH(w * 0.24, y + 8, w * 0.52, h / 5 - 16),
          line(col[2], 2, 0.4),
        );
      }
    case 'marquee':
      c.drawRect(rect, fill(col[0]));
      c.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(20), const Radius.circular(18)),
        fill(col[1]),
      );
      final p = Path()
        ..addRRect(
          RRect.fromRectAndRadius(rect.deflate(20), const Radius.circular(18)),
        );
      for (final m in p.computeMetrics()) {
        for (var t = 0.0; t < m.length; t += 26) {
          final pos = m.getTangentForOffset(t)!.position;
          blob(pos, 9, col[2], 0.7);
          c.drawCircle(pos, 4, fill(col[3]));
        }
      }
    case 'equalizer':
      vgrad([col[0], col[1]]);
      final bw = w / 16;
      for (var i = 0; i < 16; i++) {
        final bh = h * (0.15 + _r(s, i) * 0.5);
        for (var y = h - 10; y > h - bh; y -= 12) {
          final t = (h - y) / (h * 0.65);
          c.drawRect(
            Rect.fromLTWH(i * bw + bw * 0.15, y, bw * 0.7, 8),
            fill(Color.lerp(col[2], col[3], t.clamp(0.0, 1.0))!, 0.85),
          );
        }
      }
    case 'cassette':
      c.drawRect(rect, fill(col[0]));
      for (var k = 0; k < 4; k++) {
        c.drawRect(
          Rect.fromLTWH(0, h * (0.1 + k * 0.08), w, h * 0.04),
          fill([col[1], col[2], col[3], col[1]][k], 0.85),
        );
      }
      final r = Rect.fromCenter(
        center: Offset(w / 2, h * 0.65),
        width: u * 0.8,
        height: u * 0.5,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(14)),
        fill(col[3]),
      );
      for (final dx in [-0.18, 0.18]) {
        c.drawCircle(r.center + Offset(u * dx, 0), u * 0.07, fill(col[0]));
        c.drawCircle(r.center + Offset(u * dx, 0), u * 0.03, fill(col[3]));
      }
    case 'arcade':
      c.drawRect(rect, fill(col[0]));
      for (var i = 0; i < 60; i++) {
        final o = Offset(_r(s, i) * w, _r(s, i + 1) * h);
        final color = [col[2], col[3], const Color(0xFFFFE66D)][i % 3];
        switch (i % 3) {
          case 0:
            c.drawCircle(o, 6, line(color, 2.5));
          case 1:
            c.drawPath(
              Path()
                ..moveTo(o.dx, o.dy - 7)
                ..lineTo(o.dx + 7, o.dy + 6)
                ..lineTo(o.dx - 7, o.dy + 6)
                ..close(),
              line(color, 2.5),
            );
          default:
            c.drawLine(
              o - const Offset(6, 6),
              o + const Offset(6, 6),
              line(color, 2.5),
            );
            c.drawLine(
              o + const Offset(-6, 6),
              o + const Offset(6, -6),
              line(color, 2.5),
            );
        }
      }
    default:
      vgrad([col[0], col[1]]);
  }
}
