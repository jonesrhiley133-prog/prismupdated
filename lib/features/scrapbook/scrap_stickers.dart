import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';

/// The built-in sticker library: 500+ stickers in 23 categories, all drawn
/// on the device (emoji glyphs, pixel sprites, shape art and lettering), so
/// nothing is downloaded and everything works offline.
enum StickerKind { emoji, pixel, shape, text }

class ScrapSticker {
  const ScrapSticker(this.id, this.name, this.category, this.kind, this.data);
  final String id, name, category, data;
  final StickerKind kind;

  bool matches(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;
    return name.toLowerCase().contains(s) || category.toLowerCase().contains(s);
  }
}

const scrapStickerCategories = <String>[
  'Kawaii',
  'Animals',
  'Celestial',
  'Food',
  'Emotions',
  'Stationery',
  'Vintage',
  'Gothic',
  'Grunge',
  'Cottagecore',
  'Nature',
  'Ocean',
  'Music',
  'School',
  'Gaming',
  'Pride',
  'Seasonal',
  'Holidays',
  'Lettering',
  'Abstract',
  'Pixel art',
  'Scrapbooking',
  'Fantasy',
];

// "glyph name|glyph name|…"
const _emojiData = <String, String>{
  'Kawaii':
      '🌸 sakura|🍓 strawberry|🍡 dango|🧁 cupcake|🐰 bunny|🐱 kitty|🐻 teddy|🦄 unicorn|🌈 rainbow|☁️ cloud|⭐ star|💖 sparkle heart|🎀 bow|🍭 lollipop|🍩 donut|🧸 plush|🍙 onigiri|🥟 dumpling|🐥 chick|🍑 peach|🫧 bubbles|🪽 wings|💌 love letter|🎠 carousel|🍼 bottle',
  'Animals':
      '🐶 dog|🐱 cat|🐭 mouse|🐹 hamster|🐰 rabbit|🦊 fox|🐻 bear|🐼 panda|🐨 koala|🐯 tiger|🦁 lion|🐮 cow|🐷 pig|🐸 frog|🐵 monkey|🐔 chicken|🐧 penguin|🐦 bird|🦉 owl|🦋 butterfly|🐝 bee|🐞 ladybug|🐢 turtle|🦔 hedgehog|🦦 otter|🦥 sloth|🦝 raccoon|🐴 horse|🐺 wolf',
  'Celestial':
      '🌙 crescent moon|🌕 full moon|🌑 new moon|☀️ sun|⭐ star|🌟 glowing star|✨ sparkles|💫 dizzy star|☄️ comet|🪐 planet|🌍 earth|🌌 galaxy|🌠 shooting star|🔭 telescope|🚀 rocket|🛸 ufo|👽 alien|🌛 moon face|🌞 sun face|⚡ lightning|🌈 rainbow|🔮 crystal ball|♈ aries|♌ leo|♏ scorpio|♓ pisces',
  'Food':
      '🍎 apple|🍊 orange|🍋 lemon|🍌 banana|🍉 watermelon|🍇 grapes|🍓 strawberry|🍒 cherries|🍑 peach|🥑 avocado|🍕 pizza|🍔 burger|🌮 taco|🍣 sushi|🍜 ramen|🍰 cake|🍪 cookie|🍫 chocolate|🍩 donut|🍦 ice cream|☕ coffee|🍵 tea|🧋 bubble tea|🥐 croissant|🥞 pancakes|🧀 cheese|🍿 popcorn|🍯 honey|🥕 carrot|🌽 corn',
  'Emotions':
      '😀 happy|😂 laughing|🥰 loved|😍 heart eyes|😎 cool|🤔 thinking|😴 sleepy|😭 crying|😡 angry|😱 scared|🥺 pleading|😳 flushed|🤯 mind blown|🥳 party|😇 angel|😈 devil|🤗 hug|😌 relieved|🙃 upside down|😬 awkward|🤒 sick|🥹 touched|😤 determined|🫠 melting|🫶 heart hands|💔 broken heart|💖 sparkle heart|💪 strong',
  'Stationery':
      '✏️ pencil|🖊️ pen|🖋️ fountain pen|🖍️ crayon|📎 paperclip|🖇️ linked clips|📌 pushpin|📍 round pin|✂️ scissors|📏 ruler|📐 triangle ruler|📒 ledger|📓 notebook|📔 decorated notebook|📕 red book|📚 books|🗒️ notepad|📋 clipboard|🗂️ dividers|🗃️ card box|📇 card index|🖌️ paintbrush|🎨 palette|📮 mailbox',
  'Vintage':
      '📻 radio|📷 camera|🎞️ film|📼 cassette|☎️ telephone|⌛ hourglass|🕰️ mantel clock|🗝️ old key|📜 scroll|🪶 quill|🕯️ candle|🧭 compass|🗺️ map|🎩 top hat|🪞 mirror|🛎️ bell|⚓ anchor|📯 post horn|🧵 thread|🪡 needle|🎻 violin|🏺 vase',
  'Gothic':
      '🦇 bat|🕷️ spider|🕸️ web|💀 skull|☠️ crossbones|⚰️ coffin|🪦 gravestone|🕯️ candle|🔮 crystal ball|🥀 wilted rose|🌹 rose|🗝️ key|⚔️ swords|🗡️ dagger|🩸 blood drop|🖤 black heart|🌑 new moon|🧛 vampire|🪄 wand|📿 beads|🏰 castle|👁️ eye',
  'Grunge':
      '⛓️ chain|🩹 bandage|📼 tape|🧷 safety pin|💣 bomb|🔪 knife|🧨 firecracker|🎸 guitar|📟 pager|💿 disc|🪧 sign|🚬 smoke|🧪 test tube|🔧 wrench|⚙️ gear|📌 pin|🥀 wilted flower|🕳️ hole|🛹 skateboard|🪩 disco ball|📢 megaphone|🧱 brick',
  'Cottagecore':
      '🌻 sunflower|🌼 daisy|🌷 tulip|🌿 herb|🍄 mushroom|🧺 basket|🍯 honey|🥖 baguette|🧶 yarn|🪴 plant|🐝 bee|🕯️ candle|🍵 tea|🫖 teapot|🥧 pie|🍓 strawberries|🏡 cottage|🪺 nest|🐇 bunny|🌾 wheat|🧵 thread|🪻 lavender|🍂 leaves|🕰️ clock',
  'Nature':
      '🌲 pine|🌳 tree|🌴 palm|🌵 cactus|🍀 clover|🍁 maple|🍂 fallen leaves|🌾 grass|🌿 herb|🌱 sprout|🌸 blossom|🌹 rose|🌺 hibiscus|🌻 sunflower|🌼 daisy|🍄 mushroom|🪨 rock|⛰️ mountain|🌋 volcano|🏞️ park|🌅 sunrise|🌄 mountains|💧 droplet|❄️ snowflake|🔥 fire|🌪️ tornado|🌊 wave|🪵 log',
  'Ocean':
      '🐠 fish|🐟 blue fish|🐡 puffer|🦈 shark|🐬 dolphin|🐳 whale|🐙 octopus|🦑 squid|🦀 crab|🦞 lobster|🦐 shrimp|🐚 shell|🪸 coral|🌊 wave|⚓ anchor|🚢 ship|⛵ sailboat|🏝️ island|🏖️ beach|🪼 jellyfish|🦭 seal|🐢 turtle',
  'Music':
      '🎵 note|🎶 notes|🎼 score|🎤 mic|🎧 headphones|🎸 guitar|🎹 keyboard|🥁 drum|🎷 sax|🎺 trumpet|🎻 violin|🪕 banjo|🪗 accordion|📻 radio|💿 CD|📀 DVD|🔊 speaker|🎙️ studio mic|🪘 bongo|🪈 flute|🎚️ sliders|📢 megaphone',
  'School':
      '🎒 backpack|📖 open book|📚 books|✏️ pencil|📝 memo|📐 ruler|🔬 microscope|🧪 test tube|🧮 abacus|🌍 globe|🏫 school|🎓 graduation|🔔 bell|📏 straight ruler|🖍️ crayon|🧑‍🏫 teacher|🗒️ notes|🧫 petri dish|🔭 telescope|💡 idea|📊 chart|⏰ alarm',
  'Gaming':
      '🎮 controller|🕹️ joystick|👾 invader|🎲 dice|♟️ chess pawn|🃏 joker|🎯 target|🏆 trophy|🥇 gold medal|💎 gem|🪙 coin|❤️ health heart|⚔️ sword|🛡️ shield|🏹 bow|🧙 wizard|🐉 dragon|🗝️ key|💣 bomb|⭐ power star|🍄 power-up|🎰 slot machine',
  'Pride':
      '🏳️‍🌈 rainbow flag|🏳️‍⚧️ trans flag|❤️ red heart|🧡 orange heart|💛 yellow heart|💚 green heart|💙 blue heart|💜 purple heart|🤍 white heart|🖤 black heart|🤎 brown heart|🩷 pink heart|🩵 light blue heart|🌈 rainbow|✨ sparkle|🦄 unicorn|🫶 heart hands|🤝 handshake|👭 two women|👬 two men|🧑‍🤝‍🧑 holding hands|🏳️ white flag',
  'Seasonal':
      '🌸 spring blossom|🌷 tulip|🐣 hatching chick|🌧️ rain|☔ umbrella|🌞 summer sun|🏖️ beach|🍦 ice cream|🍉 watermelon|🕶️ sunglasses|🍂 autumn leaves|🍁 maple|🎃 pumpkin|🌰 chestnut|🧣 scarf|⛄ snowman|❄️ snowflake|🧤 gloves|☕ hot drink|🔥 fireplace|🌬️ wind|🌻 sunflower|🪁 kite|🍄 mushroom',
  'Holidays':
      '🎄 tree|🎅 santa|🎁 gift|🦌 reindeer|🔔 bell|🕎 menorah|🪔 diya|🎆 fireworks|🎇 sparkler|🎃 jack-o-lantern|👻 ghost|🐣 easter chick|🥚 egg|💘 cupid heart|🌹 rose|🍀 shamrock|🦃 turkey|🎂 birthday cake|🎈 balloon|🎉 party popper|🧧 red envelope|🏮 lantern|🎊 confetti|🥂 cheers',
  'Fantasy':
      '🧙 wizard|🧚 fairy|🧜 mermaid|🧝 elf|🧞 genie|🧛 vampire|🐉 dragon|🦄 unicorn|🪄 wand|🔮 crystal ball|🏰 castle|⚔️ sword|🛡️ shield|👑 crown|💎 gem|🗝️ key|📜 spell scroll|🧪 potion|🕯️ candle|🪽 wings|🦅 griffin|🌙 moon|⭐ star|🍄 magic mushroom',
  'Scrapbooking':
      '📎 paperclip|📌 pushpin|✂️ scissors|🎀 ribbon|🏷️ tag|🔖 bookmark|📍 pin|🖇️ clips|📷 photo|🎞️ film|💌 letter|📮 post|🗓️ calendar|📆 tear-off calendar|🧵 thread|🪡 needle|🖼️ frame|⭐ star|❤️ heart|✨ sparkles|☁️ cloud|🌼 flower|🍃 leaf|🪶 feather',
};

// Lettering: "Word|color|font|style"
const _lettering = <String>[
  'Hello|FF5C8A|Pacifico|bubble',
  'Love|E8355E|Lobster|bubble',
  'Happy|FFB300|Fredoka One|bubble',
  'Dream|7C5CFF|Satisfy|script',
  'Magic|9B5CFF|Cinzel|neon',
  'Cozy|C9783A|Caveat|script',
  'Wow!|FF6B35|Bangers|retro',
  'Yay|2EC4B6|Chewy|bubble',
  'Friends|FF7AA2|Pacifico|bubble',
  'Memories|8A6B3A|Dancing Script|script',
  'Home|4E8A58|Shadows Into Light|script',
  'Smile|FFC400|Baloo 2|bubble',
  'Best day|E86A33|Permanent Marker|retro',
  'Sweet|F06292|Lobster|bubble',
  'Adventure|2D9CDB|Bangers|retro',
  'Hope|42A5F5|Satisfy|script',
  'Kindness|FF8A80|Dancing Script|script',
  'Brave|D32F2F|Bungee|stamp',
  'Joy|FFB300|Pacifico|bubble',
  'Vibes|AB47BC|Bungee Shade|neon',
  'Sparkle|FFD54F|Cinzel|neon',
  'Together|26A69A|Caveat|script',
  'Forever|C2185B|Great Vibes|script',
  'Moon|5C6BC0|Cinzel|neon',
];

const _pixel = <String, String>{
  'Heart': '.rr.rr.|rrrrrrr|rrrrrrr|.rrrrr.|..rrr..|...r...',
  'Star': '...y...|...y...|yyyyyyy|.yyyyy.|..yyy..|.yy.yy.|yy...yy',
  'Mushroom':
      '..rrrr..|.rrwwrr.|rrrrwrrr|rwwrrrww|........|..wwww..|..wwww..|..wwww..',
  'Ghost': '..wwww..|.wwwwww.|wbwwwbww|wwwwwwww|wwwwwwww|wwwwwwww|ww.ww.ww',
  'Cat': 'o.....o.|oo...oo.|oooooooo|obooobo.|oooooooo|ooopoooo|.oooooo.',
  'Cherry': '....g...|...g.g..|..g...g.|..r...r.|.rrr.rrr|.rrr.rrr|..r...r.',
  'Sword': '......w|.....ww|....ww.|...ww..|.bww...|..bb...|.b.b...',
  'Gem': '..cccc..|.cwcccc.|cccccccc|.cccccc.|..cccc..|...cc...',
  'Coin': '..yyyy..|.yyooyy.|yyoyyoyy|yyoyyoyy|yyoooyyy|.yyooyy.|..yyyy..',
  'Potion': '..bbbb..|...bb...|..pppp..|.pppppp.|.pppwpp.|.pppppp.|..pppp..',
  'Invader':
      '..p...p..|...p.p...|..ppppp..|.pp.p.pp.|ppppppppp|p.ppppp.p|p.p...p.p|...pp.pp.',
  'Apple': '....g...|..rr.rr.|.rrrrrrr|.rrrrrrr|.rrrrrrr|..rrrrr.|...r.r..',
  'Key':
      '.yyy....|y...y...|y...y...|.yyy....|..y.....|..yyy...|..y.....|..yyy...',
  'Skull': '.wwwwww.|wwwwwwww|wbbwwbbw|wbbwwbbw|wwwbbwww|.wwwwww.|.w.ww.w.',
  'Flower': '..pp..|.pppp.|ppyypp|.pppp.|..gg..|..gg..',
  'Cloud': '..www...|.wwwww..|wwwwwwww|wwwwwwww|.wwwwww.',
  'Moon': '..yyy..|.yy....|yy.....|yy.....|yy.....|.yy....|..yyy..',
  'Pizza': 'oooooooo|orrrrrro|.orprpro.|..orrro..|...oro...|....o...',
  'Duck': '...yyy..|..yyyyo.|..ybyy..|yyyyyy..|yyyyyyy.|.yyyyyy.|..yy.yy.',
  'Tree': '...gg...|..gggg..|.gggggg.|gggggggg|..gggg..|...bb...|...bb...',
  'Crown': 'y..y..y.|yy.yy.yy|yyyyyyyy|yyrywyyy|yyyyyyyy',
  'Ice cream': '..pppp..|.pppppp.|pppppppp|.oooooo.|..oooo..|...oo...|....o...',
  'Rocket': '...w....|..www...|..wbw...|..www...|.rwwwr..|rr.w.rr.|...o....',
  'Bomb': '.....y.|....o..|..kkkk.|.kkkkkk|kkwkkkk|kkkkkkk|.kkkkk.',
  'Smiley': '.yyyyyy.|yyyyyyyy|yb.yy.by|yyyyyyyy|ybyyyyby|yybbbbyy|.yyyyyy.',
  'Fish': '..cccc....c|.ccccccc.cc|cbccccccccc|.ccccccc.cc|..cccc....c',
};

const _pixelColors = <String, int>{
  'r': 0xFFE53935,
  'g': 0xFF43A047,
  'b': 0xFF3949AB,
  'y': 0xFFFFD54F,
  'o': 0xFFFB8C00,
  'w': 0xFFFAFAFA,
  'k': 0xFF263238,
  'p': 0xFFEC407A,
  'c': 0xFF26C6DA,
};

int pixelColor(String ch) => _pixelColors[ch] ?? 0;

// Abstract shape art: "shape|color1|color2|name"
const _abstract = <String>[
  'blob|FF8A80|FFD180|Peach blob',
  'blob|80D8FF|B388FF|Cool blob',
  'blob|A5D6A7|FFF59D|Meadow blob',
  'burst|FFD54F|FF7043|Pop burst',
  'burst|F48FB1|CE93D8|Pink burst',
  'star6|FFF176|FFB74D|Gold star',
  'star8|90CAF9|7986CB|Blue star',
  'ring|FF5252|FF8A80|Red ring',
  'ring|7C4DFF|B388FF|Violet ring',
  'hex|26C6DA|80DEEA|Teal hex',
  'hex|FFA726|FFCC80|Amber hex',
  'diamond|EC407A|F8BBD0|Rose diamond',
  'diamond|66BB6A|C8E6C9|Jade diamond',
  'wave|42A5F5|90CAF9|Blue wave',
  'wave|FF7043|FFAB91|Coral wave',
  'scallop|F06292|F8BBD0|Scallop pink',
  'scallop|4DB6AC|B2DFDB|Scallop mint',
  'drop|29B6F6|B3E5FC|Water drop',
  'flower8|FFCA28|FFF59D|Sun flower',
  'clover|66BB6A|A5D6A7|Lucky clover',
  'sparkle|FFF176|FFFFFF|Glint',
  'sparkle|B39DDB|FFFFFF|Violet glint',
  'seal16|EF5350|FFCDD2|Red seal',
  'seal24|5C6BC0|C5CAE9|Indigo seal',
  'cloud|90CAF9|E3F2FD|Soft cloud',
  'bolt|FFEB3B|FF9800|Zap',
  'moon|FFE082|FFFFFF|Moon slice',
];
// Pride extras use shape art too.
const _prideShape = <String>[
  'heart|FF0018|FFA52C|Warm gradient heart',
  'heart|0000F9|86007D|Cool gradient heart',
  'heart|55CDFC|F7A8B8|Trans-blue heart',
  'heart|D52D00|B55690|Lesbian heart',
  'heart|FF218C|21B1FF|Bi heart',
];

List<ScrapSticker> _build() {
  final out = <ScrapSticker>[];
  _emojiData.forEach((cat, raw) {
    var i = 0;
    for (final item in raw.split('|')) {
      final sp = item.indexOf(' ');
      out.add(
        ScrapSticker(
          '$cat.${i++}',
          item.substring(sp + 1),
          cat,
          StickerKind.emoji,
          item.substring(0, sp),
        ),
      );
    }
  });
  var i = 0;
  for (final l in _lettering) {
    out.add(
      ScrapSticker(
        'Lettering.${i++}',
        l.split('|')[0],
        'Lettering',
        StickerKind.text,
        l,
      ),
    );
  }
  i = 0;
  _pixel.forEach(
    (name, rows) => out.add(
      ScrapSticker(
        'Pixel art.${i++}',
        name,
        'Pixel art',
        StickerKind.pixel,
        rows,
      ),
    ),
  );
  i = 0;
  for (final a in _abstract) {
    out.add(
      ScrapSticker(
        'Abstract.${i++}',
        a.split('|')[3],
        'Abstract',
        StickerKind.shape,
        a,
      ),
    );
  }
  i = 100;
  for (final a in _prideShape) {
    out.add(
      ScrapSticker(
        'Pride.${i++}',
        a.split('|')[3],
        'Pride',
        StickerKind.shape,
        a,
      ),
    );
  }
  return out;
}

final List<ScrapSticker> scrapStickerCatalog = _build();

final Map<String, ScrapSticker> _byId = {
  for (final s in scrapStickerCatalog) s.id: s,
};

ScrapSticker? scrapStickerById(String id) =>
    _byId[id] ?? (id.startsWith('seas.') ? _seasonalById(id) : null);

/// Where holiday and season stickers are filed in the picker.
const seasonalStickerCategory = 'Holidays & seasons';

final Map<String, List<ScrapSticker>> _seasonalCache = {};

/// The emoji a holiday or season is made of: its own symbol first, then
/// everything its looks use (garlands, corners, hangers, furniture, icons).
List<ScrapSticker> seasonalStickersFor(String collectionId) =>
    _seasonalCache.putIfAbsent(collectionId, () {
      final c = collectionById(collectionId);
      if (c == null) return const [];
      final seen = <String>{};
      final glyphs = <String>[];
      void add(String g) {
        if (g.trim().isNotEmpty && seen.add(g)) glyphs.add(g);
      }

      add(c.emoji);
      for (final v in c.variations) {
        for (final l in [
          v.icons,
          v.cornerEmoji,
          v.garlandEmoji,
          v.hangers,
          v.furniture,
        ]) {
          l.forEach(add);
        }
      }
      return [
        for (var i = 0; i < glyphs.length; i++)
          ScrapSticker(
            'seas.$collectionId.$i',
            '${c.name} ${i + 1}',
            seasonalStickerCategory,
            StickerKind.emoji,
            glyphs[i],
          ),
      ];
    });

ScrapSticker? _seasonalById(String id) {
  final dot = id.lastIndexOf('.');
  if (dot <= 5) return null;
  final n = int.tryParse(id.substring(dot + 1));
  final list = seasonalStickersFor(id.substring(5, dot));
  return n == null || n < 0 || n >= list.length ? null : list[n];
}

List<ScrapSticker> stickersIn(String category) => [
  for (final s in scrapStickerCatalog)
    if (s.category == category) s,
];

/// A readable name for whatever a sticker element holds (built-in, imported or an old emoji).
String scrapStickerName(String? id) =>
    (id == null ? null : scrapStickerById(id)?.name) ??
    (id != null && id.startsWith('c:')
        ? 'Imported sticker'
        : (id ?? 'Sticker'));
