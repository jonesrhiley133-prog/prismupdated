import 'package:prism_plurality/features/scrapbook/scrap_models.dart';

/// Content libraries for the scrapbooking studio. Everything here is a plain,
/// const-friendly data table so the editors can render it instantly and add
/// new entries (or downloadable packs) without touching widget code.

// ---------------------------------------------------------------------------
// Cover materials (30+ presets)
// ---------------------------------------------------------------------------

enum ScrapMaterialStyle { solid, fabric, paper, gloss, pattern }

class ScrapMaterial {
  const ScrapMaterial(this.id, this.en, this.es, this.base, this.style, this.grain, this.sheen);

  final String id;
  final String en;
  final String es;

  /// Default colour of the material (ARGB). Users may recolour freely.
  final int base;

  /// How the grain is drawn.
  final ScrapMaterialStyle style;

  /// Grain strength 0..1 used by the cover painter.
  final double grain;

  /// Glossy sheen strength 0..1 (diagonal highlight).
  final double sheen;
}

const scrapMaterials = <ScrapMaterial>[
  ScrapMaterial('leather', 'Leather', 'Cuero', 0xFF6B4226, ScrapMaterialStyle.fabric, 0.55, 0.12),
  ScrapMaterial('suede', 'Suede', 'Ante', 0xFF8D6E53, ScrapMaterialStyle.fabric, 0.7, 0.04),
  ScrapMaterial('denim', 'Denim', 'Vaquero', 0xFF3F5C8F, ScrapMaterialStyle.fabric, 0.6, 0.05),
  ScrapMaterial('velvet', 'Velvet', 'Terciopelo', 0xFF5B2A4E, ScrapMaterialStyle.fabric, 0.45, 0.22),
  ScrapMaterial('linen', 'Linen', 'Lino', 0xFFD9CDB8, ScrapMaterialStyle.fabric, 0.5, 0.05),
  ScrapMaterial('canvas', 'Canvas', 'Lienzo', 0xFFCBB791, ScrapMaterialStyle.fabric, 0.65, 0.04),
  ScrapMaterial('cardboard', 'Cardboard', 'Cartón', 0xFFB08D57, ScrapMaterialStyle.paper, 0.5, 0.02),
  ScrapMaterial('construction', 'Construction paper', 'Papel de colores', 0xFFE4572E, ScrapMaterialStyle.paper, 0.35, 0.02),
  ScrapMaterial('kraft', 'Kraft paper', 'Papel kraft', 0xFFA9713C, ScrapMaterialStyle.paper, 0.45, 0.02),
  ScrapMaterial('vintage', 'Vintage paper', 'Papel vintage', 0xFFD8C39A, ScrapMaterialStyle.paper, 0.6, 0.03),
  ScrapMaterial('parchment', 'Parchment', 'Pergamino', 0xFFEADFC4, ScrapMaterialStyle.paper, 0.5, 0.05),
  ScrapMaterial('newsprint', 'Newsprint', 'Prensa', 0xFFE8E4D8, ScrapMaterialStyle.pattern, 0.4, 0.02),
  ScrapMaterial('holographic', 'Holographic', 'Holográfico', 0xFFB7A6FF, ScrapMaterialStyle.gloss, 0.15, 0.85),
  ScrapMaterial('foilGold', 'Gold foil', 'Lámina dorada', 0xFFC9A227, ScrapMaterialStyle.gloss, 0.2, 0.7),
  ScrapMaterial('foilSilver', 'Silver foil', 'Lámina plateada', 0xFFB9C0C9, ScrapMaterialStyle.gloss, 0.2, 0.7),
  ScrapMaterial('glitter', 'Glitter', 'Purpurina', 0xFF8E5AA8, ScrapMaterialStyle.gloss, 0.9, 0.5),
  ScrapMaterial('marble', 'Marble', 'Mármol', 0xFFEDEDF2, ScrapMaterialStyle.pattern, 0.35, 0.3),
  ScrapMaterial('wood', 'Wood', 'Madera', 0xFF8A5A2B, ScrapMaterialStyle.pattern, 0.6, 0.1),
  ScrapMaterial('cork', 'Cork', 'Corcho', 0xFFC69B6D, ScrapMaterialStyle.paper, 0.7, 0.03),
  ScrapMaterial('lace', 'Lace', 'Encaje', 0xFFF3E8EF, ScrapMaterialStyle.pattern, 0.5, 0.08),
  ScrapMaterial('knitted', 'Knitted fabric', 'Punto de aguja', 0xFFB23A48, ScrapMaterialStyle.fabric, 0.8, 0.05),
  ScrapMaterial('corduroy', 'Corduroy', ' Pana', 0xFF4F6D4F, ScrapMaterialStyle.fabric, 0.7, 0.06),
  ScrapMaterial('silk', 'Silk', 'Seda', 0xFFD8A7B1, ScrapMaterialStyle.gloss, 0.15, 0.55),
  ScrapMaterial('vinyl', 'Vinyl', 'Vinilo', 0xFF232323, ScrapMaterialStyle.gloss, 0.1, 0.6),
  ScrapMaterial('rubber', 'Rubber', 'Goma', 0xFF3A3A3A, ScrapMaterialStyle.solid, 0.3, 0.08),
  ScrapMaterial('stone', 'Stone', 'Piedra', 0xFF8C8C93, ScrapMaterialStyle.pattern, 0.6, 0.05),
  ScrapMaterial('terrazzo', 'Terrazzo', 'Terrazo', 0xFFEFE6DA, ScrapMaterialStyle.pattern, 0.75, 0.08),
  ScrapMaterial('plaid', 'Plaid', 'Cuadros', 0xFF7A3B3B, ScrapMaterialStyle.pattern, 0.5, 0.05),
  ScrapMaterial('polka', 'Polka dot', 'Lunares', 0xFF3D5A80, ScrapMaterialStyle.pattern, 0.4, 0.08),
  ScrapMaterial('washiCover', 'Washi-tape wrap', 'Cintillado washi', 0xFF9FD3C7, ScrapMaterialStyle.pattern, 0.45, 0.15),
  ScrapMaterial('galaxy', 'Galaxy print', 'Galaxia', 0xFF1E2140, ScrapMaterialStyle.pattern, 0.7, 0.3),
  ScrapMaterial('floral', 'Floral print', 'Floral', 0xFFE7B7CE, ScrapMaterialStyle.pattern, 0.55, 0.06),
  ScrapMaterial('graphPaper', 'Graph paper', 'Papel milimetrado', 0xFFF4F7F5, ScrapMaterialStyle.pattern, 0.3, 0.03),
  ScrapMaterial('crumpled', 'Crumpled paper', 'Papel arrugado', 0xFFE9E2D0, ScrapMaterialStyle.paper, 0.8, 0.05),
];

ScrapMaterial materialById(String? id) => scrapMaterials.firstWhere((m) => m.id == id, orElse: () => scrapMaterials.first);

/// Book binding styles.
const scrapBindings = [
  ('ring', 'Ring bound', 'Anillas'),
  ('spiral', 'Spiral', 'Espiral'),
  ('hardcover', 'Hardcover', 'Tapa dura'),
  ('paperback', 'Paperback', 'Tapa blanda'),
  ('stitched', 'Thread stitched', 'Cosido'),
  ('binder', 'Rivet binder', 'Remaches'),
  ('clip', 'Chipboard clip', 'Pinza'),
  ('accordion', 'Accordion fold', 'Acordeón'),
];

/// Cover opening animations.
const scrapOpeningAnimations = [
  ('none', 'Instant', 'Instantáneo'),
  ('fade', 'Fade in', 'Fundido'),
  ('lift', 'Lift cover', 'Levantar tapa'),
  ('swing', 'Swing open', 'Abrir girando'),
  ('slide', 'Slide aside', 'Deslizar'),
  ('ribbon', 'Unwrap ribbon', 'Developar'),
];

// ---------------------------------------------------------------------------
// Page textures (60+)
// ---------------------------------------------------------------------------

class ScrapTexture {
  const ScrapTexture(this.id, this.category, this.tintable);

  final String id;
  final String category;

  /// Whether the texture looks good when recoloured by the user.
  final bool tintable;
}

const scrapTextureCategories = [
  'Vintage & aged', 'Notebook & graph', 'Watercolour', 'Crumpled', 'Newspaper', 'Fabric & linen',
  'Construction', 'Parchment', 'Glitter & foil', 'Floral', 'Lace', 'Canvas', 'Marble', 'Handmade',
  'Seasonal', 'Celestial', 'Minimalist', 'Grunge',
];

List<ScrapTexture> _tx(String cat, List<String> ids, {bool tintable = true}) => [for (final id in ids) ScrapTexture(id, cat, tintable)];

const scrapTextures = <ScrapTexture>[
  ..._tx('Vintage & aged', ['aged1', 'aged2', 'aged3', 'coffeeStain', 'teaStain', 'foxed', 'sepiaPhoto', 'oldMap', 'fadedEdges', 'antiqueLedger']),
  ..._tx('Notebook & graph', ['ruled', 'collegeRuled', 'graphFine', 'graphWide', 'dotGrid', 'quadRule', 'bulletJournal', 'toDoSheet', 'musicStaff', 'compositionBook']),
  ..._tx('Watercolour', ['wcColdPress', 'wcHotPress', 'wcRough', 'washPink', 'washBlue', 'washGreen', 'inkBloom', 'saltBloom', 'granulation', 'wetEdge']),
  ..._tx('Crumpled', ['crumpledWhite', 'crumpledKraft', 'crumpledFoiled', 'foldedCrease', 'paperBall', 'softCrush', 'sharpCrush', 'wetDry']),
  ..._tx('Newspaper', ['newsClassic', 'newsColumns', 'newsHeadline', 'newsComics', 'newsFinancial', 'newsSunday', 'tornNews']),
  ..._tx('Fabric & linen', ['linenNatural', 'linenGrey', 'denimWeave', 'burlap', 'silkSheen', 'feltSoft', 'corduroyFine', 'knitWool', 'chevron', 'gingham']),
  ..._tx('Construction', ['constrRed', 'constrBlue', 'constrGreen', 'constrYellow', 'constrBlack', 'constrCoral', 'constrSlate']),
  ..._tx('Parchment', ['parchIvory', 'parchBurnt', 'parchRoyal', 'scrollEdge', 'waxSeal']),
  ..._tx('Glitter & foil', ['glitterGold', 'glitterPink', 'glitterHolo', 'foilRose', 'foilSilver', 'foilMirror', 'hologramShift']),
  ..._tx('Floral', ['ditsy', 'bouquetScatter', 'sunflowerField', 'sakuraFall', 'vineCorner', 'wildflowerMeadow', 'pressedFlowers']),
  ..._tx('Lace', ['laceValencia', 'laceChantilly', 'laceEyellet', 'laceCrochet', 'laceTrim']),
  ..._tx('Canvas', ['canvasPlain', 'canvasCoarse', 'canvasPainted', 'canvasWeave']),
  ..._tx('Marble', ['marbleWhite', 'marbleBlack', 'marbleRose', 'marbleGreen', 'paperMarbleFlow']),
  ..._tx('Handmade', ['deckle', 'speckled', 'cottonPaper', 'mulberry', 'recycledFleck', 'bambooFibre']),
  ..._tx('Seasonal', ['snowDrift', 'ginghamXmas', 'candyCane', 'pumpkinPatch', 'autumnLeafFall', 'springMeadow', 'summerZest', 'rainyDay']),
  ..._tx('Celestial', ['nightSky', 'constellation', 'moonPhase', 'starfield', 'aurora', 'nebulaCloud']),
  ..._tx('Minimalist', ['plainWarm', 'plainCool', 'bone', 'charcoalMatte', 'thinLineBorder', 'cornerMarks', 'gridDotFaint']),
  ..._tx('Grunge', ['grungeScratch', 'grungeTorn', 'grungeRust', 'grungeInkSplatter', 'grungePeeling', 'grungeSmoke', 'tapeResidue']),
];

/// Legacy pattern names kept working: they map onto real textures.
const scrapPatternToTexture = {'paper': 'speckled', 'dots': 'dotGrid', 'grid': 'graphFine', 'lines': 'ruled', 'none': 'plainWarm', 'kraft': 'crumpledKraft', 'stars': 'starfield'};

String textureIdFor(String legacyPattern) => scrapPatternToTexture[legacyPattern] ?? legacyPattern;

ScrapTexture? textureById(String? id) {
  if (id == null) return null;
  final mapped = textureIdFor(id);
  return scrapTextures.where((t) => t.id == mapped).firstOrNull;
}

// ---------------------------------------------------------------------------
// Sticker library (500+ emoji stickers across 23 categories)
// ---------------------------------------------------------------------------

class ScrapStickerCategory {
  const ScrapStickerCategory(this.id, this.en, this.es, this.icons);

  final String id;
  final String en;
  final String es;
  final List<String> icons;
}

const scrapStickerCategories = <ScrapStickerCategory>[
  ScrapStickerCategory('kawaii', 'Cute & kawaii', 'Kawaii', ['😊','🥰','😍','🥺','✨','💖','💕','🌸','🍓','🧁','🍭','🎀','🐰','🐱','🐶','⭐','🌈','🍡','🍩','🍦','🫶','💗','💝','🌼','🍑','🥟','🐹','🦄','🌷','💫']),
  ScrapStickerCategory('animals', 'Animals', 'Animales', ['🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐷','🐸','🐵','🐔','🐧','🐦','🦅','🦉','🦇','🐺','🐗','🐴','🦄','🐝','🐛','🦋','🐌','🐞','🐢','🐍','🦎','🐙','🦑','🦀','🐠','🐟','🐬','🐳','🐋','🦈','🐊','🐅','🐆','🦓','🦍','🐘','🦛','🦏','🐪','🦒','🐄','🐖','🐏','🐑','🐐','🌰']),
  ScrapStickerCategory('celestial', 'Celestial', 'Celestial', ['☀️','🌙','⭐','🌟','✨','💫','🪐','🌌','🌠','🌃','🌑','🌒','🌓','🌔','🌕','🌖','🌗','🌘','🌍','🌎','🌏','🌞','🌛','🌜','🔭','🚀','🛸','🌠','☄️','🌂']),
  ScrapStickerCategory('food', 'Food & drinks', 'Comida y bebida', ['🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🫐','🍒','🍑','🥭','🍍','🥥','🥝','🍅','🥑','🌽','🥕','🥐','🍞','🥖','🧀','🥚','🍳','🥞','🧇','🥓','🍔','🍟','🍕','🌭','🥪','🌮','🌯','🥗','🍝','🍜','🍲','🍣','🍱','🍛','🍤','🍙','🍚','🍦','🍧','🍨','🍰','🎂','🧁','🍪','🍫','🍬','🍭','☕','🍵','🧋','🍺','🍷','🍹']),
  ScrapStickerCategory('emotions', 'Emotions', 'Emociones', ['😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃','😉','😊','😇','🥰','😍','🤩','😘','😗','😚','😙','🥲','☺️','😊','🙂','🙃','😌','😔','😪','🤤','😴','😷','🤒','🤕','🥴','😵','🤯','🤠','🥳','😎','🤓','🧐','😕','😟','🙁','😮','😯','😲','😳','🥺','😦','😧','😨','😰','😥','😢','😭','😱','😖','😣','😞','😓','😩','😫','🥱','😤','😡','😠','🤬','😈','💀','☠️','💩','🤡','👻','😱']),
  ScrapStickerCategory('stationery', 'Stationery', 'Papelería', ['✏️','🖊️','🖋️','🖍️','📝','📌','📎','🖇️','📏','📐','✂️','🗂️','📁','📂','🗃️','📅','📆','🗒️','🗓️','📇','📈','📉','📊','📋','🗄️','📦','🗳️','✉️','📩','📨','📧','💌','📮','🏷️','📒','📔','📕','📖','📗','📘','📙','📚','🔖','🖇️','📑']),
  ScrapStickerCategory('vintage', 'Vintage', 'Vintage', ['🕰️','⌛','⏳','📻','📷','📸','📹','🎞️','🎬','💾','📼','☎️','📟','📠','🗞️','📰','📜','🖋️','🏺','🗝️','🔑','🪙','🏛️','🎩','👒','🧳','🛍️','🪆','📻','🕯️']),
  ScrapStickerCategory('gothic', 'Gothic', 'Gótico', ['🦇','🕷️','🕸️','💀','☠️','🖤','🥀','🌑','🕯️','⚰️','🪦','🏚️','🌫️','🐦‍⬛','🦉','🗡️','🛡️','🔮','🧿','🐈‍⬛','🥀','🕸️','🌘','⛓️','🖤','🦴','🩸','🕰️','🌚','🪬']),
  ScrapStickerCategory('grunge', 'Grunge', 'Grunge', ['🎸','🤘','🩹','⛓️','🔩','⚙️','🛞','🚧','⚡','💥','🔥','🌀','♻️','🗑️','📻','🎤','🧨','🪨','🏭','🛹','🚃','🛢️','⛏️','🔧','🔨','🪛','🧲','🎛️','📼','☢️']),
  ScrapStickerCategory('cottagecore', 'Cottagecore', 'Cottagecore', ['🍄','🌿','🍃','🌾','🐝','🦋','🐌','🫖','🍯','🧺','🥧','🌻','🌼','💐','🪴','🏡','🐇','🦌','🐤','🐣','🥚','🧶','🪵','🌰','🫐','🍒','🌹','🌷','🧺','☕']),
  ScrapStickerCategory('nature', 'Nature', 'Naturaleza', ['🌲','🌳','🌴','🌱','🌿','☘️','🍀','🍁','🍂','🍃','🍄','🌰','🦀','🌸','💐','🌷','🌹','🥀','🌺','🌻','🌼','🌞','🌝','🌛','🌜','🌡️','☀️','🕶️','🌈','⛅','☁️','⛈️','❄️','⛄','🌊','💧','🔥','🌪️','🌋','🏔️','⛰️','🗻','🏕️','🌅','🌄']),
  ScrapStickerCategory('ocean', 'Ocean', 'Océano', ['🌊','🐚','🦪','🐋','🐬','🦈','🐙','🦑','🦐','🦞','🦀','🐡','🐠','🐟','🐳','⚓','🛟','🚢','⛵','🛶','🏖️','🏝️','🪸','🫧','🧜‍♀️','🧜‍♂️','🐢','🦭','🐧','🌅']),
  ScrapStickerCategory('music', 'Music', 'Música', ['🎵','🎶','🎼','🎤','🎧','🎷','🎸','🎹','🎺','🎻','🥁','🪘','📯','🎙️','🎚️','🎛️','📻','🎼','🎧','🪕','🎹','🎷','🎺','🥁']),
  ScrapStickerCategory('school', 'School', 'Escuela', ['📚','📖','✏️','🎒','🍎','📐','📏','🧪','🔬','🎓','🏫','📝','🖍️','📓','📒','📕','📗','📘','📙','🗄️','📊','🧮','🖥️','⏰','🔔','🚸','📇','🏅']),
  ScrapStickerCategory('gaming', 'Gaming', 'Videojuegos', ['🎮','🕹️','👾','🎲','🎯','🏆','🥇','🎰','♟️','🃏','🀄','🎴','🧙','🗡️','🛡️','🏹','🪄','🧊','🔋','💾','🖥️','⌨️','🕹️','🎮']),
  ScrapStickerCategory('fantasy', 'Fantasy', 'Fantasía', ['🧚','🧜','🧛','🧟','🧞','🧙','🦄','🐉','🐲','🏰','🗼','⚔️','🛡️','🪄','🔮','📿','🧿','🌠','🫧','🦌','🐺','🦅','🌕','🌑','🕯️','🗝️','👑','💎']),
  ScrapStickerCategory('pride', 'Pride', 'Orgullo', ['🏳️‍🌈','🏳️‍⚧️','❤️','🧡','💛','💚','💙','💜','🤍','🖤','💖','💗','💓','💞','💕','💌','✨','🌈','🎉','🪩','💃','🕺','🎊','🫂']),
  ScrapStickerCategory('seasonal', 'Seasonal', 'Estacional', ['❄️','⛄','☃️','🎿','⛸️','🍂','🍁','🎃','👻','🦃','🍽️','🎄','🎅','🤶','🎁','🕯️','💝','🌹','🐰','🥚','🌸','🌞','🏖️','🌊','⛱️','🍉','🌻','🌷','🍀','🐣']),
  ScrapStickerCategory('holidays', 'Holidays', 'Festividades', ['🎆','🎇','🧨','✨','🎈','🎉','🎊','🎋','🎍','🎎','🎏','🎐','🎑','🕍','🕌','☪️','🪔','🕉️','✡️','🔯','🌙','⭐','🎄','🥮','🏮','🧧','🎴','🪅']),
  ScrapStickerCategory('typography', 'Typography', 'Tipografía', ['🅰️','🆎','🆑','🆒','🆓','🆔','🆕','🆗','🔝','💯','🔠','🔡','🔤','✳️','❇️','©️','®️','™️','❗','❓','‼️','⁉️','🈁','🈶','🈚','🈸','🈺','🉐','🉑','〰️']),
  ScrapStickerCategory('abstract', 'Abstract', 'Abstracto', ['🌀','💠','🔘','🔗','⚜️','🔱','🪬','♾️','🔯','✡️','☸️','☯️','🛐','🕎','🎭','🖼️','🧩','🔶','🔷','🔸','🔹','🔺','🔻','▪️','▫️','◻️','◼️','🟥','🟧','🟨','🟩','🟦','🟪','⬛','⬜']),
  ScrapStickerCategory('pixel', 'Pixel art', 'Pixel art', ['👾','🕹️','🎮','🎲','🧱','⛏️','🗿','🪙','💎','🔋','📟','🖥️','⌨️','🖱️','💾','📼','🎰','🚀','🛸','🌟','🔥','💥','⚡','🌈','🍄','🗺️','🧭','⚔️','🏹','🪓']),
  ScrapStickerCategory('essentials', 'Scrapbooking essentials', 'Imprescindibles', ['📷','📸','🖼️','🎞️','📌','📎','✂️','📏','🖍️','🖇️','🏷️','📛','🔖','💌','📮','🗳️','🧷','🪪','📅','🗓️','📒','📔','📕','📚','🖼️','🪞','🔍','🧲']),
];

/// Flat list of all default sticker glyphs (deduped) — 500+ entries.
final List<String> scrapStickerAll = (() {
  final seen = <String>{};
  for (final c in scrapStickerCategories) {
    seen.addAll(c.icons);
  }
  return seen.toList(growable: false);
})();

// ---------------------------------------------------------------------------
// Shapes & decorative elements (75+)
// ---------------------------------------------------------------------------

class ScrapShapeSpec {
  const ScrapShapeSpec(this.id, this.en, this.es, this.category);

  final String id;
  final String en;
  final String es;
  final String category;
}

const scrapShapeCategories = ['Stars', 'Hearts', 'Sky', 'Flora', 'Ribbons', 'Speech', 'Paper', 'Organic', 'Geometric', 'Dividers', 'Cards & tags', 'Stamps', 'Flourishes'];

const scrapShapes = <ScrapShapeSpec>[
  // Stars
  ScrapShapeSpec('star', 'Star', 'Estrella', 'Stars'),
  ScrapShapeSpec('starburst', 'Starburst', 'Estallido', 'Stars'),
  ScrapShapeSpec('sparkle', 'Sparkle', 'Destello', 'Stars'),
  ScrapShapeSpec('fourStar', 'Four-point star', 'Estrella de 4 puntas', 'Stars'),
  ScrapShapeSpec('sixStar', 'Six-point star', 'Estrella de 6 puntas', 'Stars'),
  ScrapShapeSpec('shootingStar', 'Shooting star', 'Estrella fugaz', 'Stars'),
  ScrapShapeSpec('constellation', 'Constellation', 'Constelación', 'Stars'),
  // Hearts
  ScrapShapeSpec('heart', 'Heart', 'Corazón', 'Hearts'),
  ScrapShapeSpec('twoHearts', 'Two hearts', 'Dos corazones', 'Hearts'),
  ScrapShapeSpec('brokenHeart', 'Broken heart', 'Corazón roto', 'Hearts'),
  ScrapShapeSpec('heartRibbon', 'Heart with ribbon', 'Corazón con lazo', 'Hearts'),
  ScrapShapeSpec('heartOutline', 'Heart outline', 'Corazón perfil', 'Hearts'),
  // Sky
  ScrapShapeSpec('cloud', 'Cloud', 'Nube', 'Sky'),
  ScrapShapeSpec('cloudSun', 'Sun behind cloud', 'Sol tras nube', 'Sky'),
  ScrapShapeSpec('crescent', 'Crescent moon', 'Media luna', 'Sky'),
  ScrapShapeSpec('halfMoon', 'Half moon', 'Semiluna', 'Sky'),
  ScrapShapeSpec('sunFace', 'Sun', 'Sol', 'Sky'),
  ScrapShapeSpec('rainbow', 'Rainbow', 'Arcoíris', 'Sky'),
  ScrapShapeSpec('lightning', 'Lightning bolt', 'Rayo', 'Sky'),
  // Flora
  ScrapShapeSpec('flower5', 'Five-petal flower', 'Flor de 5 pétalos', 'Flora'),
  ScrapShapeSpec('daisy', 'Daisy', 'Margarita', 'Flora'),
  ScrapShapeSpec('tulip', 'Tulip', 'Tulipán', 'Flora'),
  ScrapShapeSpec('leafSprig', 'Leaf sprig', 'Rama de hojas', 'Flora'),
  ScrapShapeSpec('monstera', 'Monstera leaf', 'Hoja de monstera', 'Flora'),
  ScrapShapeSpec('vine', 'Vine', 'Enredadera', 'Flora'),
  ScrapShapeSpec('mushroom', 'Mushroom', 'Seta', 'Flora'),
  ScrapShapeSpec('sunflower', 'Sunflower', 'Girasol', 'Flora'),
  // Ribbons & bows
  ScrapShapeSpec('ribbon', 'Ribbon', 'Cinta', 'Ribbons'),
  ScrapShapeSpec('bow', 'Bow', 'Lazo', 'Ribbons'),
  ScrapShapeSpec('banner', 'Banner', 'Banderín', 'Ribbons'),
  ScrapShapeSpec('flagGarland', 'Flag garland', 'Guirnalda de banderas', 'Ribbons'),
  ScrapShapeSpec('rosette', 'Rosette', 'Escarapela', 'Ribbons'),
  // Speech
  ScrapShapeSpec('bubble', 'Speech bubble', 'Bocadillo', 'Speech'),
  ScrapShapeSpec('cloudBubble', 'Cloud bubble', 'Bocadillo nube', 'Speech'),
  ScrapShapeSpec('thought', 'Thought bubble', 'Burbuja de pensamiento', 'Speech'),
  ScrapShapeSpec('exclaim', 'Exclamation burst', 'Golpe de exclamación', 'Speech'),
  ScrapShapeSpec('whisper', 'Whisper tail bubble', 'Cola susurrada', 'Speech'),
  // Paper
  ScrapShapeSpec('tornStrip', 'Torn strip', 'Tira rasgada', 'Paper'),
  ScrapShapeSpec('tornBlob', 'Torn blob', 'Recorte rasgado', 'Paper'),
  ScrapShapeSpec('tornEdge', 'Torn edge card', 'Tarjeta borde rasgado', 'Paper'),
  ScrapShapeSpec('paperClipFrame', 'Clipped frame', 'Marco con clips', 'Paper'),
  ScrapShapeSpec('notebookPage', 'Notebook page', 'Página de cuaderno', 'Paper'),
  ScrapShapeSpec('stickyNote', 'Sticky note', 'Nota adhesiva', 'Paper'),
  // Organic blobs
  ScrapShapeSpec('blob1', 'Blob one', 'Mancha uno', 'Organic'),
  ScrapShapeSpec('blob2', 'Blob two', 'Mancha dos', 'Organic'),
  ScrapShapeSpec('blob3', 'Blob three', 'Mancha tres', 'Organic'),
  ScrapShapeSpec('splash', 'Splash', 'Salpicadura', 'Organic'),
  ScrapShapeSpec('pebble', 'Pebble', 'Guijarro', 'Organic'),
  // Geometric
  ScrapShapeSpec('circle', 'Circle', 'Círculo', 'Geometric'),
  ScrapShapeSpec('square', 'Square', 'Cuadrado', 'Geometric'),
  ScrapShapeSpec('roundedRect', 'Rounded rect', 'Rectángulo redondeado', 'Geometric'),
  ScrapShapeSpec('triangle', 'Triangle', 'Triángulo', 'Geometric'),
  ScrapShapeSpec('diamond', 'Diamond', 'Rombo', 'Geometric'),
  ScrapShapeSpec('pentagon', 'Pentagon', 'Pentágono', 'Geometric'),
  ScrapShapeSpec('hexagon', 'Hexagon', 'Hexágono', 'Geometric'),
  ScrapShapeSpec('octagon', 'Octagon', 'Octógono', 'Geometric'),
  ScrapShapeSpec('semicircle', 'Semicircle', 'Semicírculo', 'Geometric'),
  ScrapShapeSpec('quarterArc', 'Quarter arc', 'Cuarto de arco', 'Geometric'),
  ScrapShapeSpec('cross', 'Plus cross', 'Cruz griega', 'Geometric'),
  // Dividers
  ScrapShapeSpec('dividerDots', 'Dotted divider', 'Separador punteado', 'Dividers'),
  ScrapShapeSpec('dividerWave', 'Wavy divider', 'Separador ondulado', 'Dividers'),
  ScrapShapeSpec('dividerFlourish', 'Flourish divider', 'Separador ornamental', 'Dividers'),
  ScrapShapeSpec('dividerArrow', 'Arrow divider', 'Separador con flechas', 'Dividers'),
  ScrapShapeSpec('dividerLeaf', 'Leaf divider', 'Separador vegetal', 'Dividers'),
  // Cards, tags & stamps
  ScrapShapeSpec('ticket', 'Ticket', 'Entrada', 'Cards & tags'),
  ScrapShapeSpec('tag', 'Tag', 'Etiqueta', 'Cards & tags'),
  ScrapShapeSpec('label', 'Label', 'Label', 'Cards & tags'),
  ScrapShapeSpec('stampPost', 'Postage stamp', 'Sello postal', 'Stamps'),
  ScrapShapeSpec('stampRubber', 'Rubber stamp', 'Sello de goma', 'Stamps'),
  ScrapShapeSpec('polaroidShape', 'Polaroid', 'Polaroid', 'Cards & tags'),
  ScrapShapeSpec('postcard', 'Postcard', 'Postal', 'Cards & tags'),
  ScrapShapeSpec('barcode', 'Barcode', 'Código de barras', 'Cards & tags'),
  // Flourishes & hand-drawn
  ScrapShapeSpec('flourishLeft', 'Flourish left', 'Adorno izquierdo', 'Flourishes'),
  ScrapShapeSpec('cornerFlourish', 'Corner flourish', 'Adorno de esquina', 'Flourishes'),
  ScrapShapeSpec('swash', 'Swash underline', 'Subrayado caligráfico', 'Flourishes'),
  ScrapShapeSpec('scribbleLine', 'Scribble line', 'Línea garabato', 'Flourishes'),
  ScrapShapeSpec('handArrow', 'Hand-drawn arrow', 'Flecha dibujada', 'Flourishes'),
  ScrapShapeSpec('handCircle', 'Hand-drawn circle', 'Círculo dibujado', 'Flourishes'),
  ScrapShapeSpec('handUnderline', 'Hand underline', 'Subrayado a mano', 'Flourishes'),
  ScrapShapeSpec('doodleSpiral', 'Doodle spiral', 'Espiral garabato', 'Flourishes'),
];

ScrapShapeSpec? shapeById(String? id) => id == null ? null : scrapShapes.where((s) => s.id == id).firstOrNull;

// ---------------------------------------------------------------------------
// Frames (100+)
// ---------------------------------------------------------------------------

enum ScrapFrameKind { polaroid, filmstrip, wooden, ornate, gothic, floral, lace, heart, star, torn, postcard, cutout, pixel, magazine, celestial, seasonal, minimal, border, animated, tape, stamp }

class ScrapFrameSpec {
  const ScrapFrameSpec(this.id, this.en, this.es, this.kind, this.color);

  final String id;
  final String en;
  final String es;
  final ScrapFrameKind kind;

  /// Default accent colour of the frame (ARGB).
  final int color;
}

List<ScrapFrameSpec> _fr(ScrapFrameKind k, List<(String, String, String, int)> rows) => [for (final (id, en, es, c) in rows) ScrapFrameSpec(id, en, es, k, c)];

const scrapFrames = <ScrapFrameSpec>[
  ..._fr(ScrapFrameKind.polaroid, [('poClassic','Polaroid classic','Polaroid clásica',0xFFFFFFFF),('poCream','Polaroid cream','Polaroid crema',0xFFFFF3E0),('poPink','Polaroid pink','Polaroid rosa',0xFFFFD1DC),('poMint','Polaroid mint','Polaroid menta',0xFFCFF5E7),('poNight','Polaroid night','Polaroid noche',0xFF2A2E57),('poSun','Polaroid sunset','Polaroid atardecer',0xFFFFE0B2),('poDouble','Double polaroid','Polaroid doble',0xFFFFFFFF)]),
  ..._fr(ScrapFrameKind.filmstrip, [('fsMono','Film strip mono','Tira de película b/n',0xFF1C1C1C),('fsSepia','Film strip sepia','Tira sepia',0xFF4A3728),('fsColor','Negative strip','Negativo',0xFF263238),('fsSuper8','Super 8','Super 8',0xFF3E2723),('fsVertical','Vertical film','Película vertical',0xFF212121)]),
  ..._fr(ScrapFrameKind.wooden, [('wdOak','Oak frame','Roble',0xFF8A5A2B),('wdWalnut','Walnut frame','Nogal',0xFF5D4037),('wdPine','Pine frame','Pino',0xFFC8A165),('wdDrift','Driftwood','Madera flotante',0xFFA1887F),('wdCarved','Carved wood','Talla en madera',0xFF6D4C41)]),
  ..._fr(ScrapFrameKind.ornate, [('orGold','Ornate gold','Oro ornado',0xFFC9A227),('orRose','Rose gold','Oro rosa',0xFFB76E79),('orBaroque','Baroque','Barroco',0xFFD4AF37),('orVictorian','Victorian gilt','Dorado victoriano',0xFFA67C00),('orArtDeco','Art deco','Art déco',0xFFC9A227),('orEmpire','Empire','Imperio',0xFFB8860B)]),
  ..._fr(ScrapFrameKind.gothic, [('goArch','Gothic arch','Arco gótico',0xFF2B2B2B),('goWindow','Chapel window','Ventanal',0xFF1A1A2E),('goIron','Wrought iron','Hierro forjado',0xFF3A3A3A),('goRaven','Raven frame','Marco cuervo',0xFF16161D),('goCathedral','Cathedral','Catedral',0xFF241F31),('goBlood','Blood red','Rojo sangre',0xFF5A0E0E)]),
  ..._fr(ScrapFrameKind.floral, [('flSpring','Spring blossoms','Flores primavera',0xFFF6C6D8),('flWild','Wildflowers','Flores silvestres',0xFFA8D5BA),('flRose','Rose garland','Guirnalda de rosas',0xFFE7B7CE),('flSakura','Sakura','Sakura',0xFFFFD9E5),('flSunfl','Sunflower rim','Orla girasoles',0xFFF1C40F),('flLavender','Lavender','Lavanda',0xFFB39DDB),('flPressed','Pressed flowers','Flores prensadas',0xFFD7BDE2)]),
  ..._fr(ScrapFrameKind.lace, [('lcWhite','White lace','Encaje blanco',0xFFFBF7F4),('lcBlack','Black lace','Encaje negro',0xFF2E2E2E),('lcVintage','Vintage lace','Encaje vintage',0xFFF3E8D8),('lcCrochet','Crochet','Ganchillo',0xFFEED9C4),('lcEyellet','Eyelet','Ojal',0xFFFDFEFE)]),
  ..._fr(ScrapFrameKind.heart, [('hePink','Heart pink','Corazón rosa',0xFFFF6B9D),('heRed','Heart red','Corazón rojo',0xFFE74C3C),('hePastel','Heart pastel','Corazón pastel',0xFFFFC4D6),('heBeat','Beating heart','Corazón latiendo',0xFFFF4D6D)]),
  ..._fr(ScrapFrameKind.star, [('stGold','Star gold','Estrella dorada',0xFFF1C40F),('stNight','Star night','Estrella nocturna',0xFF5B7FFF),('stTwinkle','Twinkle','Parpadeo',0xFFFFE082),('stBurst','Star burst','Estallido estelar',0xFFFFB300)]),
  ..._fr(ScrapFrameKind.torn, [('toPaper','Torn paper','Papel rasgado',0xFFF5EFE1),('toKraft','Torn kraft','Kraft rasgado',0xFFB08D57),('toEdge','Rough edge','Borde irregular',0xFFE0D6C3),('toRagged','Ragged tear','Desgarro rugoso',0xFFD7CCC8),('toBurnt','Burnt edge','Borde quemado',0xFF4E342E)]),
  ..._fr(ScrapFrameKind.postcard, [('pcAir','Air mail','Correo aéreo',0xFFFFF8E1),('pcRetro','Retro postcard','Postal retro',0xFFFFCC80),('pcBeach','Beach postcard','Postal playera',0xFF80DEEA),('pcGreetings','Greetings from','Saludos desde',0xFFFFAB91),('pcVintage','Vintage postcard','Postal vintage',0xFFD7CCC8)]),
  ..._fr(ScrapFrameKind.cutout, [('cuScallop','Scalloped','Recorte festoneado',0xFFF8BBD0),('cuZigzag','Zigzag cut','Recorte zigzag',0xFFB2EBF2),('cuCloud','Cloud cut','Recorte nube',0xFFE3F2FD),('cuStampCut','Stamp cut','Recorte sello',0xFFECEFF1),('cuWave','Wave cut','Recorte onda',0xFFB2DFDB),('cuBubble','Bubble cut','Recorte burbuja',0xFFFCE4EC)]),
  ..._fr(ScrapFrameKind.pixel, [('pxGreen','Gameboy','Gameboy',0xFF9BBC0F),('pxArcade','Arcade','Arcade',0xFF212121),('px8bit','8-bit border','Borde 8 bits',0xFF3F51B5),('pxBrick','Brick wall','Muro de ladrillos',0xFFBF360C)]),
  ..._fr(ScrapFrameKind.magazine, [('mgGlossy','Glossy magazine','Revista brillante',0xFFFFFFFF),('mgEditorial','Editorial spread','Página editorial',0xFFF5F5F5),('mgNeon','Neon cover','Portada neón',0xFFE91E63),('mgNews','Newsprint','Papel de periódico',0xFFE8E4D8),('mgCollage','Magazine collage','Collage de revistas',0xFFFFF9C4)]),
  ..._fr(ScrapFrameKind.celestial, [('ceMoon','Moonlit','Noche de luna',0xFF1E2140),('ceStars','Studded stars','Estrellas',0xFF283593),('ceAurora','Aurora','Aurora',0xFF00897B),('ceNebula','Nebula','Nebulosa',0xFF4A148C),('ceZodiac','Zodiac ring','Zodíaco',0xFF311B92),('ceSolar','Solar flare','Llama solar',0xFFFF8F00)]),
  ..._fr(ScrapFrameKind.seasonal, [('snSnow','Snowfall','Nevada',0xFFE3F2FD),('snXmas','Christmas','Navidad',0xFF2E7D32),('snSpooky','Spooky','Terrorífico',0xFF4A148C),('snPumpkin','Pumpkin','Calabaza',0xFFEF6C00),('snBlossom','Cherry blossom','Flor de cerezo',0xFFF8BBD0),('snAutumn','Autumn leaves','Hojas otoñales',0xFFBF360C),('snSpring','Spring','Primavera',0xFFAED581),('snSummer','Summer sun','Verano',0xFFFFD54F),('snRain','Rainy day','Día lluvioso',0xFF90A4AE)]),
  ..._fr(ScrapFrameKind.minimal, [('miHairline','Hairline','Línea fina',0xFF9E9E9E),('miShadow','Soft shadow','Sombra suave',0xFFEEEEEE),('miRound','Rounded','Redondeado',0xFFFAFAFA),('miInset','Inset','Interior',0xFFE0E0E0),('miDouble','Double line','Doble línea',0xFF424242),('miCorner','Corner marks','Marcas de esquina',0xFF616161),('miNone','Clean edge','Sin borde',0xFFFFFFFF)]),
  ..._fr(ScrapFrameKind.animated, [('anGlow','Glow pulse','Resplandor',0xFF7C4DFF),('anShimmer','Shimmer','Brillo móvil',0xFFFFD54F),('anNeonFlicker','Neon flicker','Neón parpadeante',0xFF00E5FF),('anSnowDrift','Drifting snow','Nieve a la deriva',0xFFB3E5FC),('anSparklePop','Sparkle pop','Destellos',0xFFFFAB40),('anHeartbeat','Heartbeat frame','Latido',0xFFFF4D6D),('anFilmGrain','Film grain','Grano de película',0xFF37474F)]),
  ..._fr(ScrapFrameKind.tape, [('taMasking','Masking tape','Cinta de carrocero',0xFFF7E3A1),('taWashiFloral','Floral washi','Washi floral',0xFFF6C6D8),('taWashiStripe','Striped washi','Washi rayas',0xFFA5D8F3),('taDuct','Duct tape','Cinta americana',0xFF9E9E9E),('taKraftTape','Kraft tape','Cinta de embalaje',0xFFB08D57),('taGlitterTape','Glitter tape','Cinta glitter',0xFFCE93D8)]),
  ..._fr(ScrapFrameKind.stamp, [('stRound','Round stamp','Sello redondo',0xFFE57373),('stRect','Rectangular stamp','Sello rectangular',0xFF64B5F6),('stVintage','Vintage stamp','Sello vintage',0xFFBCAAA4),('stAirmail','Airmail stamp','Sello aéreo',0xFFFFD54F)]),
];

ScrapFrameSpec? frameSpecById(String? id) => id == null ? null : scrapFrames.where((f) => f.id == id).firstOrNull;

/// Backwards-compat mapping: old enum frames → new frame ids.
String? legacyFrameToId(ScrapFrame f) => switch (f) {
  ScrapFrame.polaroid => 'poClassic',
  ScrapFrame.tape => 'taMasking',
  ScrapFrame.round => 'miRound',
  ScrapFrame.shadow => 'miShadow',
  ScrapFrame.border => 'miHairline',
  ScrapFrame.none => null,
};

ScrapFrame legacyFromFrameId(String? id) {
  final spec = frameSpecById(id);
  if (spec == null) return ScrapFrame.none;
  return switch (spec.kind) {
    ScrapFrameKind.polaroid => ScrapFrame.polaroid,
    ScrapFrameKind.tape => ScrapFrame.tape,
    ScrapFrameKind.minimal => spec.id == 'miRound' ? ScrapFrame.round : (spec.id == 'miShadow' ? ScrapFrame.shadow : ScrapFrame.border),
    _ => ScrapFrame.border,
  };
}

// ---------------------------------------------------------------------------
// Rentry-style markdown support
// ---------------------------------------------------------------------------

/// A single sanitised block parsed from Rentry-flavoured markdown.
sealed class RentryBlock {
  const RentryBlock();
}

class RentryHeading extends RentryBlock {
  const RentryHeading(this.level, this.text);
  final int level;
  final String text;
}

class RentryParagraph extends RentryBlock {
  const RentryParagraph(this.spans);
  final List<RentrySpan> spans;
}

class RentryListItem extends RentryBlock {
  const RentryListItem(this.text, {this.checked, this.indent = 0});
  final String text;
  final bool? checked; // null = bullet, true/false = task item
  final int indent;
}

class RentryDivider extends RentryBlock {
  const RentryDivider();
}

class RentryQuote extends RentryBlock {
  const RentryQuote(this.text);
  final String text;
}

class RentryCode extends RentryBlock {
  const RentryCode(this.text);
  final String text;
}

class RentryImage extends RentryBlock {
  const RentryImage(this.url, this.alt);
  final String url;
  final String alt;
}

class RentryTable extends RentryBlock {
  const RentryTable(this.rows);
  final List<List<String>> rows;
}

class RentryRawHtml extends RentryBlock {
  /// Unsupported/unsafe HTML degrades to escaped plain text.
  const RentryRawHtml(this.text);
  final String text;
}

class RentrySpan {
  const RentrySpan(this.text, {this.bold = false, this.italic = false, this.strike = false, this.code = false, this.link});
  final String text;
  final bool bold, italic, strike, code;
  final String? link;
}

final _safeUrlRegExp = RegExp(r'^(https?:)?//', caseSensitive: false);
bool isSafeUrl(String? url) => url != null && (_safeUrlRegExp.hasMatch(url) || url.startsWith('#'));

/// Strips scripts/styles/events and any tag that is not on the allowlist.
/// Returns escaped visible text (inline formatting handled separately).
String sanitizeRentryHtml(String input) {
  var out = input;
  out = out.replaceAll(RegExp(r'<\s*(script|style|iframe|object|embed|form|link|meta)[^>]*>.*?<\s*/\s*\1\s*>', dotAll: true, caseSensitive: false), '');
  out = out.replaceAll(RegExp(r'<\s*(script|style|iframe|object|embed|form|link|meta)[^>]*/?>', caseSensitive: false), '');
  out = out.replaceAll(RegExp(r'\son\w+\s*=\s*("[^"]*"|\'[^\']*\'|[^\s>]+)', caseSensitive: false), '');
  out = out.replaceAll(RegExp(r'(href|src)\s*=\s*(["\']?)\s*javascript:[^"\'>\s]*\2', caseSensitive: false), '$1=$2#$2');
  // Keep remaining tags visible as escaped text so nothing renders as raw HTML.
  out = out.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  return out;
}

List<RentrySpan> parseInline(String text) {
  final spans = <RentrySpan>[];
  final re = RegExp(r'(\*\*\*|___)(.+?)\1|(\*\*|__)(.+?)\3|(\*|_)(.+?)\5|(~~)(.+?)\6|(`+)(.+?)\8|\[([^\]]*)\]\(([^)\s]+)[^)]*\)', dotAll: true);
  var last = 0;
  void pushPlain(String s) {
    if (s.isEmpty) return;
    if (spans.isNotEmpty && !spans.last.bold && !spans.last.italic && !spans.last.strike && !spans.last.code && spans.last.link == null) {
      spans[spans.length - 1] = RentrySpan(spans.last.text + s);
    } else {
      spans.add(RentrySpan(s));
    }
  }
  for (final m in re.all(text)) {
    pushPlain(sanitizeRentryHtml(text.substring(last, m.start)));
    final href = m.group(11);
    if (href != null) {
      spans.add(RentrySpan(m.group(10) ?? '', link: isSafeUrl(href) ? href : '#'));
    } else {
      final bold = m.group(3) != null || m.group(1) != null;
      final italic = m.group(5) != null || m.group(1) != null;
      final strike = m.group(6) != null;
      final code = m.group(8) != null;
      final content = m.group(2) ?? m.group(4) ?? m.group(7) ?? m.group(9) ?? '';
      spans.add(RentrySpan(content, bold: bold, italic: italic, strike: strike, code: code));
    }
    last = m.end;
  }
  pushPlain(sanitizeRentryHtml(text.substring(last)));
  return spans;
}

/// Parses Rentry-flavoured markdown into safe blocks. Unsafe HTML never
/// survives; unknown formatting degrades to escaped text.
List<RentryBlock> parseRentryMarkdown(String source) {
  final blocks = <RentryBlock>[];
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  var i = 0;
  while (i < lines.length) {
    final raw = lines[i];
    final line = raw.trimRight();
    if (line.trim().isEmpty) { i++; continue; }
    // Fenced code
    if (line.trimLeft().startsWith('```')) {
      final buf = <String>[];
      i++;
      while (i < lines.length && !lines[i].trimLeft().startsWith('```')) { buf.add(lines[i]); i++; }
      i++;
      blocks.add(RentryCode(buf.join('\n')));
      continue;
    }
    // Image-only line
    final img = RegExp(r'^!\[([^\]]*)\]\(([^)\s]+)[^)]*\)$').firstMatch(line.trim());
    if (img != null) {
      final url = img.group(2)!;
      blocks.add(RentryImage(isSafeUrl(url) ? url : '#', img.group(1) ?? ''));
      i++;
      continue;
    }
    // Heading
    final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (h != null) {
      blocks.add(RentryHeading(h.group(1)!.length, h.group(2)!));
      i++;
      continue;
    }
    // Divider
    if (RegExp(r'^\s*(-{3,}|\*{3,}|_{3,})\s*$').hasMatch(line)) {
      blocks.add(const RentryDivider());
      i++;
      continue;
    }
    // Table
    if (line.contains('|') && i + 1 < lines.length && RegExp(r'^\s*\|?[\s:|-]+\|?\s*$').hasMatch(lines[i + 1]) && lines[i + 1].contains('-')) {
      final rows = <List<String>>[];
      List<String> cells(String l) => l.trim().replaceAll(RegExp(r'^\|'), '').replaceAll(RegExp(r'\|$'), '').split('|').map((c) => c.trim()).toList();
      rows.add(cells(line));
      i += 2;
      while (i < lines.length && lines[i].contains('|')) { rows.add(cells(lines[i])); i++; }
      blocks.add(RentryTable(rows));
      continue;
    }
    // Quote
    if (line.trimLeft().startsWith('>')) {
      final buf = <String>[];
      while (i < lines.length && lines[i].trimLeft().startsWith('>')) { buf.add(lines[i].trimLeft().substring(1).trim()); i++; }
      blocks.add(RentryQuote(buf.join(' ')));
      continue;
    }
    // List items
    final li = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+(.*)$').firstMatch(line);
    if (li != null) {
      final indent = li.group(1)!.length ~/ 2;
      final marker = li.group(2)!;
      var text = li.group(3)!;
      bool? checked;
      final task = RegExp(r'^\[([ xX])\]\s*(.*)$').firstMatch(text);
      if (task != null) { checked = task.group(1)!.toLowerCase() == 'x'; text = task.group(2)!; }
      blocks.add(RentryListItem(text, checked: marker.startsWith('-') || marker.startsWith('*') || marker.startsWith('+') ? checked : null, indent: indent));
      i++;
      continue;
    }
    // Raw html line (starts with '<') degrades to escaped text paragraph.
    if (line.trimLeft().startsWith('<')) {
      blocks.add(RentryRawHtml(sanitizeRentryHtml(line)));
      i++;
      continue;
    }
    // Paragraph: merge consecutive plain lines.
    final para = StringBuffer(line);
    i++;
    while (i < lines.length && lines[i].trim().isNotEmpty && !RegExp(r'^(#{1,6}\s|```|>\s*|-{3,}$|\s*([-*+]|\d+[.)])\s)').hasMatch(lines[i])) {
      para.write(' ');
      para.write(lines[i].trim());
      i++;
    }
    blocks.add(RentryParagraph(parseInline(para.toString())));
  }
  return blocks;
}

/// Serialises blocks back to Rentry-compatible markdown for export.
String rendertToMarkdown(List<RentryBlock> blocks) {
  final sb = StringBuffer();
  for (final b in blocks) {
    switch (b) {
      case RentryHeading(): sb.writeln('${'#' * b.level} ${b.text}');
      case RentryParagraph(): sb.writeln(renderSpans(b.spans));
      case RentryListItem(): sb.writeln('${'  ' * b.indent}${b.checked == null ? '-' : b.checked! ? '- [x]' : '- [ ]'} ${b.text}');
      case RentryDivider(): sb.writeln('---');
      case RentryQuote(): sb.writeln('> ${b.text}');
      case RentryCode(): sb.writeln('```\n${b.text}\n```');
      case RentryImage(): sb.writeln('![${b.alt}](${b.url})');
      case RentryTable():
        for (var r = 0; r < b.rows.length; r++) {
          sb.writeln('| ${b.rows[r].join(' | ')} |');
          if (r == 0) sb.writeln('| ${List.filled(b.rows[r].length, '---').join(' | ')} |');
        }
      case RentryRawHtml(): sb.writeln(b.text);
    }
    if (b is RentryTable) continue;
  }
  return sb.toString().trimRight();
}

String renderSpans(List<RentrySpan> spans) {
  final sb = StringBuffer();
  for (final s in spans) {
    var t = s.text;
    if (s.code) t = '`$t`';
    if (s.bold) t = '**$t**';
    if (s.italic) t = '*$t*';
    if (s.strike) t = '~~$t~~';
    if (s.link != null) t = '[$t](${s.link})';
    sb.write(t);
  }
  return sb.toString();
}

/// Extracts http(s) image URLs from Rentry content for importing as media.
List<String> rendertImageUrls(List<RentryBlock> blocks) => [
  for (final b in blocks)
    if (b is RentryImage && isSafeUrl(b.url) && b.url!.startsWith('http')) b.url!,
];
