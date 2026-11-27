import 'package:prism_plurality/features/seasonal/seasonal_models.dart';

/// Palettes, as `id|base|primary|secondary|accent` (hex RGB).
const _palettes = '''
classic|FFF3E0|C0392B|1E6B3A|D4AF37
cozy|FBE3C2|E67E22|8B5A2B|6B3E1F
pastel|FFF1B8|F8C8DC|BFE3F2|D5C6F0
gothic|2B1B3A|7B1E3A|8E7CC3|E8D9F2
golden|FFF6D6|D4AF37|F5D76E|8C6A1C
minimal|FFFFFF|222222|777777|E5E5E5
retro|F2B632|E8742B|1E8C8C|5A2E1A
kawaii|FFF4C9|FF7AB6|8FE3CF|C9A7FF
midnight|0D1B3E|2E4A8C|F4D35E|9FB4E8
celestial|E7DDFF|5B3FA6|37C6E8|FFD66B
woodland|D9C9A0|4E6B3A|8A6A3F|B5532A
elegant|F4EBD9|C9B38A|3A3A3A|8C7A5A
whimsical|FFC43D|FF5E8A|3DD6D0|7A5CFF
rustic|D9A441|B5651D|6B4226|8E9B5A
vintage|E6C9A8|A7664C|6C9A8B|7A4B5C
neon|0B0B1A|00F0FF|FF2E93|B6FF3B
watercolor|FFE08A|8EC5E8|F4A6B8|A8D8B0
folk|F5F0E1|C8102E|1F4E9A|2E7D32
storybook|F2E2C2|2A7F7F|E76F51|264653
cafe|F3E0C7|6F4E37|E8A0A9|3E2723
village|F5E6C8|3B5B8C|F4A53A|8FB0D8
garden|FFE27A|5FA05B|F4A6C0|2F6F3E
frost|DCEEFB|A9D6F5|6FA8D8|FFFFFF
bold|F1C40F|E63946|1D3557|2A9D8F
dreamy|F8BBD0|B7A4E8|FFCBA4|A7C7E7
sweet|FFFFFF|FF5C8A|7DD6B1|FFD166
market|F0D9A8|C97B2C|8B2E2E|3E5C3A
workshop|F2D49B|B5782A|C0392B|2E7D32
tropical|FFD93D|0FA3A3|FF6B6B|2B9348
carnival|FFC107|6A1B9A|00A86B|E91E63
forest|C8B88A|1F4D2B|6B8E4E|3B2A1A
ocean|F2E3B3|0B6E99|5FC8E8|073B4C
desert|F5E6C8|D9A66B|C06C5B|3FA7A0
sacred|F7F3E8|C9A227|2C3E7C|8FB5C9
floral|FFF6EE|E9A0B5|7FAE6A|C06A8A
paper|FFFFFF|C9A978|D64545|4A6FA5
sunset|F7B267|F26B38|B0527A|4B2A5E
sky|FFFFFF|7EC8F0|FFE08A|4A90C2
harvest|E0B04A|C8741A|8B3A1A|5C6B2E
ember|2A1208|E8591A|F6A623|FFD27A
moss|E8F0D0|6B8E4E|A9C27B|4A6B3A
lilac|F0E0FA|C8A2D8|8E6BB0|FFD6E8
amber|FFE6A8|7A4A12|F0B429|3A2208
rose|FFF1F4|C85A71|7A2E45|FBD3DC
jade|C8E6D0|2E8B6B|E3C25B|1B4D3E
indigo|A3B1E8|2E3A87|F4D35E|0F1642
monsoon|A7C4D6|3F6E8C|5D8A4E|213A4A
blossom|FFF0F5|F7B7CE|8E4A66|C7E3C5
teal|BFDBF7|1F7A8C|E1E5F2|022B3A
lantern|FFF3C4|C62828|FFB300|4E0D0D
''';

/// Style words: `id|garland|lights|border|particle|corner` ('-' = none).
const _styles = '''
vine|vine|-|-|-|-
emojis|emoji|-|-|-|-
bunting|bunting|-|-|-|-
ribbons|ribbon|-|-|-|-
beads|beads|-|-|-|-
tinsel|tinsel|-|-|-|-
chain|chain|-|-|-|-
pompoms|pompom|-|-|-|-
swag|swag|-|-|-|-
fairy|-|fairy|-|-|-
bulbs|-|bulbs|-|-|-
lanterns|-|lanterns|-|-|lantern
starlights|-|stars|-|-|-
candles|-|candles|-|-|-
nolights|-|none|-|-|-
frosty|-|-|frost|snow|-
scallops|-|-|scallop|-|-
ornate|-|-|ornate|-|frame
dotted|-|-|dotted|-|-
double|-|-|double|-|-
hairline|-|-|hairline|-|-
vined|-|-|vine|-|sprig
wreathed|-|-|-|-|wreath
scroll|-|-|-|-|scroll
windowed|-|-|-|-|window
clustered|-|-|-|-|cluster
ribboned|-|-|-|-|ribbon
snowing|-|-|-|snow|-
leafy|-|-|-|leaves|-
petalfall|-|-|-|petals|-
raining|-|-|-|rain|-
glowing|-|-|-|fireflies|-
starry|-|-|-|stars|-
confettied|-|-|-|confetti|-
hearty|-|-|-|hearts|-
bubbly|-|-|-|bubbles|-
sparkly|-|-|-|sparkles|-
embers|-|-|-|embers|-
cloudy|-|-|-|clouds|-
flutter|-|-|-|butterflies|-
bokehy|-|-|-|bokeh|-
calm|-|fairy|-|none|-
kente|kente|-|-|-|-
papel|papel|-|-|-|-
streamers|streamers|-|-|-|-
tassels|tassels|-|-|-|-
flags|flags|-|-|-|-
icicles|-|icicle|-|-|-
neonlights|-|neon|-|-|-
diyas|-|diya|-|-|-
mkeka|-|-|mkeka|-|-
zigzag|-|-|zigzag|-|-
lace|-|-|lace|-|-
stitched|-|-|stitched|-|-
kinara|-|-|-|-|kinara
fans|-|-|-|-|fan
rangoli|-|-|-|-|rangoli
sunburst|-|-|-|-|sunburst
feathery|-|-|-|feathers|-
glittery|-|-|-|glitter|-
skylanterns|-|-|-|skylanterns|-
ribbonfall|-|-|-|ribbons|-
''';

int _hex(String h) => 0xFF000000 | int.parse(h, radix: 16);

Map<String, DecoPalette>? _pal;
Map<String, List<String>>? _sty;

Map<String, DecoPalette> get decoPalettes => _pal ??= _buildPalettes();

Map<String, DecoPalette> _buildPalettes() {
  final m = <String, DecoPalette>{};
  for (final l in _palettes.split('\n')) {
    if (l.trim().isEmpty) continue;
    final p = l.split('|');
    m[p[0]] = DecoPalette(p[0], _hex(p[1]), _hex(p[2]), _hex(p[3]), _hex(p[4]));
  }
  return m;
}

Map<String, List<String>> get decoStyles => _sty ??= _buildStyles();

Map<String, List<String>> _buildStyles() {
  final m = <String, List<String>>{};
  for (final l in _styles.split('\n')) {
    if (l.trim().isEmpty) continue;
    final p = l.split('|');
    m[p[0]] = p.sublist(1);
  }
  return m;
}

GarlandStyle? garlandOf(String s) =>
    GarlandStyle.values.where((e) => e.name == s).firstOrNull;
LightsStyle? lightsOf(String s) =>
    LightsStyle.values.where((e) => e.name == s).firstOrNull;
DecoBorder? borderOf(String s) =>
    DecoBorder.values.where((e) => e.name == s).firstOrNull;
ParticleKind? particleOf(String s) =>
    ParticleKind.values.where((e) => e.name == s).firstOrNull;
CornerStyle? cornerOf(String s) =>
    CornerStyle.values.where((e) => e.name == s).firstOrNull;
