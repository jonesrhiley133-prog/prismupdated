/// Prism's font library: every family here is an open-licence (SIL OFL /
/// Apache) Google Fonts family, fetched only when someone actually picks or
/// previews it, then cached on the device for offline use.
library;

/// The 19 browsing categories.
const fontCategories = <String, String>{
  'sans': 'Modern sans-serif',
  'serif': 'Classic serif',
  'hand': 'Handwritten',
  'cursive': 'Cursive',
  'calligraphy': 'Calligraphy',
  'rounded': 'Rounded',
  'cute': 'Cute',
  'gothic': 'Gothic',
  'blackletter': 'Blackletter',
  'retro': 'Retro',
  'vintage': 'Vintage',
  'pixel': 'Pixel',
  'mono': 'Monospace',
  'futuristic': 'Futuristic',
  'editorial': 'Editorial',
  'decorative': 'Decorative',
  'elegant': 'Elegant',
  'minimal': 'Minimalist',
  'multi': 'Multilingual',
};

/// Writing systems a font can show.
const fontScripts = <String, String>{
  'latin': 'Latin',
  'cyrillic': 'Cyrillic',
  'greek': 'Greek',
  'korean': 'Korean',
  'japanese': 'Japanese',
  'chinese': 'Chinese',
  'arabic': 'Arabic',
  'hebrew': 'Hebrew',
  'thai': 'Thai',
  'devanagari': 'Devanagari',
  'bengali': 'Bengali',
};

/// Categories that are ornamental: the accessibility override can swap
/// these for a plain readable font.
const decorativeCategories = {
  'hand',
  'cursive',
  'calligraphy',
  'cute',
  'gothic',
  'blackletter',
  'retro',
  'pixel',
  'futuristic',
  'decorative',
};

class PrismFont {
  const PrismFont(this.family, this.categories, this.scripts);

  /// Google Fonts family name, e.g. `Playfair Display`.
  final String family;
  final Set<String> categories;
  final Set<String> scripts;

  bool get decorative => categories.any(decorativeCategories.contains);
  String get id => 'g:$family';
}

// family | categories | scripts (latin is assumed when scripts is empty)
const _raw = '''
Inter|sans,minimal|latin,cyrillic,greek
Roboto|sans|latin,cyrillic,greek
Open Sans|sans|latin,cyrillic,greek,hebrew
Lato|sans|latin
Montserrat|sans|latin,cyrillic
Poppins|sans|latin,devanagari
Work Sans|sans,minimal|latin
DM Sans|sans,minimal|latin
Manrope|sans,minimal|latin,cyrillic,greek
Rubik|sans|latin,cyrillic,hebrew
Karla|sans,minimal|latin
Mulish|sans|latin,cyrillic
Outfit|sans|latin
Plus Jakarta Sans|sans|latin
Figtree|sans|latin
Sora|sans|latin
Urbanist|sans|latin
Public Sans|sans|latin
IBM Plex Sans|sans|latin,cyrillic,greek
Source Sans 3|sans|latin,cyrillic,greek
Nunito Sans|sans,minimal|latin,cyrillic
Raleway|sans|latin,cyrillic
Josefin Sans|sans,elegant|latin
Barlow|sans|latin
Cabin|sans|latin
Albert Sans|sans|latin
Red Hat Display|sans|latin
Be Vietnam Pro|sans,minimal|latin
Space Grotesk|sans,minimal,futuristic|latin
Syne|sans,editorial|latin
Epilogue|sans|latin
Hanken Grotesk|sans|latin
Instrument Sans|sans,minimal|latin
Onest|sans|latin,cyrillic
Geologica|sans|latin,cyrillic
Jost|sans,elegant,minimal|latin,cyrillic
Lexend Deca|sans,minimal|latin
Questrial|sans,minimal|latin
Didact Gothic|sans,minimal|latin,cyrillic,greek
Archivo|sans,minimal|latin
Commissioner|sans,minimal|latin,cyrillic,greek
Schibsted Grotesk|sans,minimal|latin
Afacad|sans,minimal|latin
Merriweather|serif|latin,cyrillic
Lora|serif|latin,cyrillic
Libre Baskerville|serif|latin
EB Garamond|serif,elegant|latin,cyrillic,greek
Crimson Text|serif|latin
Cormorant Garamond|serif,elegant|latin,cyrillic
Source Serif 4|serif|latin,cyrillic,greek
PT Serif|serif|latin,cyrillic
Bitter|serif|latin,cyrillic
Spectral|serif|latin,cyrillic
Libre Caslon Text|serif|latin
Vollkorn|serif|latin,cyrillic,greek
Alegreya|serif|latin,cyrillic,greek
Cardo|serif|latin,greek
Gelasio|serif|latin
Newsreader|serif,editorial|latin
Literata|serif,editorial|latin,cyrillic,greek
Domine|serif|latin
Zilla Slab|serif|latin
Playfair Display|serif,editorial,elegant|latin,cyrillic
DM Serif Display|serif,editorial|latin
DM Serif Text|serif,editorial|latin
Fraunces|serif,editorial|latin
Bodoni Moda|serif,editorial,elegant|latin
Libre Bodoni|serif,editorial,vintage|latin
Prata|serif,editorial,elegant|latin,cyrillic
Young Serif|serif,editorial|latin
Instrument Serif|serif,editorial|latin
Gloock|serif,editorial|latin
Marcellus|serif,editorial,elegant|latin
Caveat|hand|latin,cyrillic
Patrick Hand|hand|latin
Indie Flower|hand|latin
Shadows Into Light|hand|latin
Gochi Hand|hand|latin
Architects Daughter|hand|latin
Nanum Pen Script|hand|korean
Reenie Beanie|hand|latin
Covered By Your Grace|hand|latin
Rock Salt|hand,decorative|latin
Permanent Marker|hand|latin
Kalam|hand|latin,devanagari
Handlee|hand|latin
Gloria Hallelujah|hand|latin
Just Another Hand|hand|latin
Walter Turncoat|hand|latin
Sue Ellen Francisco|hand|latin
Nothing You Could Do|hand|latin
Homemade Apple|hand|latin
Swanky and Moo Moo|hand|latin
Dancing Script|cursive|latin
Pacifico|cursive|latin,cyrillic
Satisfy|cursive|latin
Sacramento|cursive|latin
Kaushan Script|cursive|latin,cyrillic
Courgette|cursive|latin
Yellowtail|cursive|latin
Cookie|cursive|latin
Lobster|cursive,retro|latin,cyrillic
Marck Script|cursive|latin,cyrillic
Damion|cursive|latin
Allura|cursive,calligraphy|latin
Parisienne|cursive|latin
Niconne|cursive|latin
Mr Dafoe|cursive|latin
Great Vibes|calligraphy|latin
Alex Brush|calligraphy|latin
Tangerine|calligraphy|latin
Pinyon Script|calligraphy,elegant|latin
Italianno|calligraphy|latin
Petit Formal Script|calligraphy|latin
Rouge Script|calligraphy|latin
Monsieur La Doulaise|calligraphy|latin
Herr Von Muellerhoff|calligraphy|latin
Mrs Saint Delafield|calligraphy|latin
Euphoria Script|calligraphy|latin
Arizonia|calligraphy|latin
Bad Script|calligraphy,cursive|latin,cyrillic
Playball|calligraphy|latin
Mea Culpa|calligraphy|latin
Ballet|calligraphy|latin
Nunito|rounded|latin,cyrillic
Quicksand|rounded|latin
Varela Round|rounded|latin,hebrew
Comfortaa|rounded|latin,cyrillic,greek
M PLUS Rounded 1c|rounded|latin,japanese,greek,cyrillic
Fredoka|rounded,cute|latin,hebrew
Baloo 2|rounded,cute|latin,devanagari
Sniglet|rounded,cute|latin
Mali|rounded,cute|latin,thai
Dosis|rounded|latin
Zen Maru Gothic|rounded|latin,japanese
Kosugi Maru|rounded|latin,japanese
Chewy|cute|latin
Bubblegum Sans|cute|latin
Boogaloo|cute|latin
Grandstander|cute|latin
Gaegu|cute,hand|latin,korean
Hi Melody|cute,hand|latin,korean
Cute Font|cute|korean
Hachi Maru Pop|cute|latin,japanese
Yomogi|cute,hand|latin,japanese
Mochiy Pop One|cute|latin,japanese
Potta One|cute|latin,japanese
Dongle|cute,rounded|latin,korean
Gamja Flower|cute,hand|latin,korean
Single Day|cute|latin,korean
Poor Story|cute,hand|latin,korean
Itim|cute,hand|latin,thai
Pangolin|cute,hand|latin,cyrillic
Fuzzy Bubbles|cute,hand|latin
Delicious Handrawn|cute,hand|latin
Londrina Solid|cute|latin
Chelsea Market|cute|latin
Cherry Bomb One|cute|latin,japanese
Modak|cute,decorative|latin,devanagari
Cinzel Decorative|gothic,elegant|latin
Cinzel|gothic,elegant,editorial|latin
Metamorphous|gothic|latin
Almendra|gothic,vintage|latin
Macondo|gothic|latin
Eagle Lake|gothic,calligraphy|latin
Uncial Antiqua|gothic|latin
New Rocker|gothic,blackletter|latin
Creepster|gothic,decorative|latin
Nosifer|gothic,decorative|latin
Butcherman|gothic,decorative|latin
Eater|gothic,decorative|latin
Pirata One|gothic,blackletter|latin
Grenze Gotisch|gothic,blackletter|latin
Jim Nightshade|gothic,calligraphy|latin
MedievalSharp|gothic|latin
IM Fell English|gothic,vintage|latin
Aladin|gothic,calligraphy|latin
UnifrakturCook|blackletter|latin
UnifrakturMaguntia|blackletter|latin
Jacquard 12|blackletter,pixel|latin
Jacquarda Bastarda 9|blackletter,pixel|latin
Fruktur|blackletter|latin
Righteous|retro|latin
Bungee|retro,decorative|latin
Monoton|retro,decorative|latin
Shrikhand|retro|latin
Lobster Two|retro,cursive|latin
Bowlby One|retro|latin
Chango|retro|latin
Fugaz One|retro|latin
Rubik Mono One|retro|latin,cyrillic
Rammetto One|retro|latin
Titan One|retro,cute|latin
Yeseva One|retro,editorial|latin,cyrillic
Oleo Script|retro,cursive|latin
Sonsie One|retro|latin
Limelight|retro,vintage|latin
Lilita One|retro,cute|latin
Ultra|retro|latin
Alfa Slab One|retro|latin
Abril Fatface|retro,editorial|latin
Bungee Shade|retro,decorative|latin
Sansita Swashed|retro,cursive|latin
Special Elite|vintage|latin
Cutive Mono|vintage,mono|latin
Old Standard TT|vintage,serif|latin,cyrillic
Playfair Display SC|vintage,elegant|latin,cyrillic
Rye|vintage,decorative|latin
Sancreek|vintage,decorative|latin
Ewert|vintage,decorative|latin
Smokum|vintage,decorative|latin
Federo|vintage|latin
Poiret One|vintage,elegant|latin,cyrillic
Megrim|vintage,futuristic|latin
Vast Shadow|vintage,decorative|latin
Elsie|vintage,elegant|latin
Fascinate|vintage,decorative|latin
Gruppo|vintage,minimal|latin
Italiana|vintage,elegant,editorial|latin
Cormorant SC|vintage,elegant|latin,cyrillic
Courier Prime|vintage,mono|latin
Bellefair|vintage,elegant|latin,hebrew
Press Start 2P|pixel|latin,cyrillic,greek
VT323|pixel,mono|latin
Pixelify Sans|pixel|latin,cyrillic
Silkscreen|pixel|latin
DotGothic16|pixel|latin,japanese
Jersey 10|pixel|latin
Jersey 15|pixel|latin
Tiny5|pixel|latin
Micro 5|pixel|latin
Handjet|pixel|latin,greek,cyrillic,arabic,hebrew
Workbench|pixel|latin
Doto|pixel|latin
JetBrains Mono|mono|latin,cyrillic,greek
Fira Code|mono|latin,cyrillic,greek
Source Code Pro|mono|latin,cyrillic,greek
IBM Plex Mono|mono|latin,cyrillic
Space Mono|mono|latin
Roboto Mono|mono|latin,cyrillic,greek
Inconsolata|mono|latin
Ubuntu Mono|mono|latin,cyrillic,greek
DM Mono|mono|latin
Overpass Mono|mono|latin
Red Hat Mono|mono|latin
Anonymous Pro|mono|latin,cyrillic,greek
Share Tech Mono|mono,futuristic|latin
B612 Mono|mono|latin
Cousine|mono|latin,cyrillic,greek,hebrew
Nanum Gothic Coding|mono|latin,korean
Major Mono Display|mono,decorative|latin
Orbitron|futuristic|latin
Audiowide|futuristic|latin
Exo 2|futuristic|latin,cyrillic
Rajdhani|futuristic|latin,devanagari
Michroma|futuristic|latin
Oxanium|futuristic|latin
Syncopate|futuristic|latin
Zen Dots|futuristic|latin
Quantico|futuristic|latin
Chakra Petch|futuristic|latin,thai
Saira|futuristic|latin
Electrolize|futuristic|latin
Russo One|futuristic|latin,cyrillic
Aldrich|futuristic|latin
Bruno Ace|futuristic|latin
Tourney|futuristic,decorative|latin
Nova Square|futuristic|latin
Jura|futuristic|latin,cyrillic,greek
Goldman|futuristic|latin
Iceland|futuristic|latin
Wallpoet|futuristic,decorative|latin
Cormorant|editorial,elegant|latin,cyrillic
Fascinate Inline|decorative|latin
Bungee Inline|decorative|latin
Rubik Glitch|decorative|latin,cyrillic
Rubik Bubbles|decorative|latin,cyrillic
Rubik Wet Paint|decorative|latin,cyrillic
Kablammo|decorative|latin
Foldit|decorative|latin
Honk|decorative|latin
Nabla|decorative|latin
Emilys Candy|decorative,cute|latin
Flavors|decorative,cute|latin
Londrina Shadow|decorative|latin
Londrina Sketch|decorative|latin
Londrina Outline|decorative|latin
Rubik Maze|decorative|latin,cyrillic
Rubik Dirt|decorative|latin,cyrillic
Sarina|decorative|latin
Barriecito|decorative|latin
Butterfly Kids|decorative,cute|latin
Ribeye Marrow|decorative|latin
Snowburst One|decorative|latin
Spicy Rice|decorative|latin
Gorditas|decorative,cute|latin
Original Surfer|decorative,retro|latin
Mystery Quest|decorative,gothic|latin
Henny Penny|decorative,gothic|latin
Frijole|decorative|latin
Lacquer|decorative|latin
Bigelow Rules|decorative,vintage|latin
Codystar|decorative|latin
Miltonian|decorative,vintage|latin
Risque|decorative|latin
Margarine|decorative,cute|latin
Cormorant Infant|elegant|latin,cyrillic
Forum|elegant|latin,cyrillic
Tenor Sans|elegant|latin,cyrillic
Gilda Display|elegant|latin
Josefin Slab|elegant|latin
Philosopher|elegant|latin,cyrillic
Rosarivo|elegant|latin
Lustria|elegant|latin
Aboreto|elegant|latin
Cormorant Upright|elegant|latin,cyrillic
Linden Hill|elegant,vintage|latin
Sorts Mill Goudy|elegant,vintage|latin
Rufina|elegant|latin
Hind|minimal,multi|latin,devanagari
Heebo|minimal,multi|latin,hebrew
Red Hat Text|minimal|latin
Gantari|minimal|latin
Noto Sans|multi,sans|latin,cyrillic,greek
Noto Serif|multi,serif|latin,cyrillic,greek
Noto Sans KR|multi,sans|korean,latin
Noto Serif KR|multi,serif|korean,latin
Nanum Gothic|multi,sans|korean,latin
Nanum Myeongjo|multi,serif|korean,latin
Do Hyeon|multi,decorative|korean,latin
Black Han Sans|multi,decorative|korean,latin
Gowun Dodum|multi,rounded|korean,latin
Gowun Batang|multi,serif|korean,latin
Jua|multi,rounded,cute|korean,latin
East Sea Dokdo|multi,hand|korean,latin
IBM Plex Sans KR|multi,sans|korean,latin
Sunflower|multi,sans|korean,latin
Song Myung|multi,serif|korean,latin
Yeon Sung|multi,cute|korean,latin
Noto Sans JP|multi,sans|japanese,latin
Noto Serif JP|multi,serif|japanese,latin
M PLUS 1p|multi,sans|japanese,latin,greek,cyrillic
Zen Kaku Gothic New|multi,sans|japanese,latin
Sawarabi Mincho|multi,serif|japanese,latin
Shippori Mincho|multi,serif,elegant|japanese,latin
Kaisei Decol|multi,decorative|japanese,latin
Yusei Magic|multi,hand|japanese,latin
Dela Gothic One|multi,decorative|japanese,latin,cyrillic,greek
Reggae One|multi,decorative|japanese,latin
RocknRoll One|multi,decorative|japanese,latin
Klee One|multi,hand|japanese,latin
Zen Antique|multi,serif,vintage|japanese,latin
Noto Sans SC|multi,sans|chinese,latin
Noto Serif SC|multi,serif|chinese,latin
Noto Sans TC|multi,sans|chinese,latin
Noto Serif TC|multi,serif|chinese,latin
ZCOOL KuaiLe|multi,cute|chinese,latin
ZCOOL XiaoWei|multi,serif|chinese,latin
ZCOOL QingKe HuangYou|multi,decorative|chinese,latin
Ma Shan Zheng|multi,calligraphy|chinese,latin
Zhi Mang Xing|multi,calligraphy|chinese,latin
Long Cang|multi,calligraphy|chinese,latin
Liu Jian Mao Cao|multi,calligraphy|chinese,latin
LXGW WenKai TC|multi,serif|chinese,latin
Noto Sans Arabic|multi,sans|arabic,latin
Noto Naskh Arabic|multi,serif|arabic,latin
Noto Kufi Arabic|multi,sans|arabic,latin
Cairo|multi,sans|arabic,latin
Tajawal|multi,sans,minimal|arabic,latin
Amiri|multi,serif,elegant|arabic,latin
Almarai|multi,sans|arabic,latin
IBM Plex Sans Arabic|multi,sans|arabic,latin
Reem Kufi|multi,decorative|arabic,latin
Lalezar|multi,decorative|arabic,latin
Noto Sans Hebrew|multi,sans|hebrew,latin
Assistant|multi,sans,minimal|hebrew,latin
Frank Ruhl Libre|multi,serif|hebrew,latin
Noto Sans Thai|multi,sans|thai,latin
Prompt|multi,sans|thai,latin,cyrillic
Sarabun|multi,sans|thai,latin,cyrillic
Kanit|multi,sans|thai,latin,cyrillic
Noto Sans Devanagari|multi,sans|devanagari,latin
Mukta|multi,sans|devanagari,latin
Noto Sans Bengali|multi,sans|bengali,latin
PT Sans|multi,sans|cyrillic,latin
Ubuntu|multi,sans|cyrillic,greek,latin
Gentium Plus|multi,serif|cyrillic,greek,latin
''';

List<PrismFont>? _cache;

/// The full catalogue, parsed once.
List<PrismFont> get fontCatalog => _cache ??= [
  for (final line in _raw.split('\n'))
    if (line.trim().isNotEmpty)
      () {
        final p = line.split('|');
        return PrismFont(
          p[0].trim(),
          p[1].split(',').map((e) => e.trim()).toSet(),
          (p.length > 2 ? p[2] : 'latin')
              .split(',')
              .map((e) => e.trim())
              .toSet(),
        );
      }(),
];

PrismFont? fontByFamily(String family) {
  for (final f in fontCatalog) {
    if (f.family == family) return f;
  }
  return null;
}
