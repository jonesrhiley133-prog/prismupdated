import 'package:prism_plurality/features/scrapbook/scrap_cover.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';

ScrapElement _title({
  String font = 'g:Pacifico',
  int color = 0xFFFFFFFF,
  double y = 0.38,
  double size = 2.4,
  double h = 0.2,
  Map<String, Object?> opts = const {},
}) => ScrapElement(
  type: ScrapType.text,
  text: '{title}',
  font: font,
  color: color,
  size: size,
  x: 0.1,
  y: y,
  w: 0.8,
  h: h,
  opts: {'ta': 'center', 'shrink': true, ...opts},
);

ScrapElement _subtitle({
  String font = 'g:Caveat',
  int color = 0xFFFFFFFF,
  double y = 0.6,
}) => ScrapElement(
  type: ScrapType.text,
  text: '{subtitle}',
  font: font,
  color: color,
  size: 1.3,
  x: 0.12,
  y: y,
  w: 0.76,
  h: 0.08,
  opts: {'ta': 'center', 'shrink': true},
);

ScrapElement _sticker(
  String id,
  double x,
  double y,
  double s, {
  double rot = 0,
  Map<String, Object?> opts = const {},
}) => ScrapElement(
  type: ScrapType.sticker,
  text: id,
  x: x,
  y: y,
  w: s,
  h: s * 0.72,
  rot: rot,
  opts: {...opts},
);

ScrapElement _border(
  int color, {
  String shape = 'rrect',
  double inset = 0.05,
  double width = 2,
}) => ScrapElement(
  type: ScrapType.shape,
  text: shape,
  color: color,
  x: inset,
  y: inset * 0.72,
  w: 1 - inset * 2,
  h: 1 - inset * 1.44,
  opts: {'nf': true, 'bc': color, 'bw': width},
);

CoverDesign _d(
  CoverFace front, {
  String binding = 'spine',
  String anim = 'swing',
  double thickness = 0.35,
  double corner = 0.06,
  CoverFace? back,
  double aspect = 0.72,
}) => CoverDesign(
  front: front,
  back: back ?? (front.copy()..els = []),
  binding: binding,
  anim: anim,
  thickness: thickness,
  corner: corner,
  aspect: aspect,
);

class CoverTemplate {
  const CoverTemplate(this.id, this.name, this.build);
  final String id, name;
  final CoverDesign Function() build;
}

final List<CoverTemplate> coverTemplates = [
  CoverTemplate(
    'blank',
    'Blank',
    () => _d(
      CoverFace(base: 'color', color: 0xFFF6F1E7),
      anim: 'fade',
      binding: 'spine',
    ),
  ),
  CoverTemplate(
    'leather',
    'Leather journal',
    () => _d(
      CoverFace(
        base: 'material',
        material: 'm-leather-brown',
        els: [
          _border(0xFFD4AF37, width: 1.6),
          _title(
            font: 'g:Cinzel',
            color: 0xFFE9CF7A,
            size: 2.2,
            opts: {'shd': 0.6},
          ),
          _subtitle(font: 'g:Cinzel', color: 0xFFE9CF7A),
        ],
      ),
      binding: 'stitched',
    ),
  ),
  CoverTemplate(
    'denim',
    'Denim patch',
    () => _d(
      CoverFace(
        base: 'material',
        material: 'm-denim',
        els: [
          _sticker('Kawaii.0', 0.62, 0.06, 0.28, rot: 0.2),
          _title(
            font: 'g:Permanent Marker',
            color: 0xFFFFFFFF,
            y: 0.4,
            opts: {'shd': 0.4},
          ),
          _subtitle(color: 0xFFF0C25A, font: 'g:Shadows Into Light'),
        ],
      ),
      binding: 'stitched',
      anim: 'pop',
    ),
  ),
  CoverTemplate(
    'velvet',
    'Red velvet',
    () => _d(
      CoverFace(
        base: 'material',
        material: 'm-velvet-red',
        els: [
          _border(0xFFE9CF7A, shape: 'ellipse', inset: 0.1, width: 1.4),
          _title(
            font: 'g:Great Vibes',
            color: 0xFFF6E27A,
            size: 3,
            opts: {'shd': 0.5},
          ),
          _subtitle(font: 'g:Great Vibes', color: 0xFFF6E27A, y: 0.62),
        ],
      ),
      binding: 'ribbon',
      anim: 'curtain',
    ),
  ),
  CoverTemplate(
    'holo',
    'Holographic',
    () => _d(
      CoverFace(
        base: 'material',
        material: 'm-holo',
        els: [
          _title(
            font: 'g:Bungee',
            color: 0xFFFFFFFF,
            size: 2,
            opts: {'ow': 1.6, 'oc': 0xFF7C5CFF, 'shd': 0.5},
          ),
          _sticker('Abstract.20', 0.7, 0.08, 0.2),
          _sticker('Abstract.21', 0.1, 0.78, 0.16),
        ],
      ),
      binding: 'spiral',
      anim: 'sparkle',
    ),
  ),
  CoverTemplate(
    'marble',
    'Marble & gold',
    () => _d(
      CoverFace(
        base: 'material',
        material: 'm-marble',
        els: [
          _border(0xFFD4AF37, shape: 'rect', inset: 0.07, width: 2.4),
          _border(0xFFD4AF37, shape: 'rect', inset: 0.09, width: 0.8),
          _title(font: 'g:Cinzel', color: 0xFF8A6A12, size: 2, y: 0.4),
          _subtitle(font: 'g:Cinzel', color: 0xFF8A6A12),
        ],
      ),
      binding: 'spine',
      anim: 'flipUp',
    ),
  ),
  CoverTemplate(
    'kraft',
    'Kraft craft',
    () => _d(
      CoverFace(
        base: 'material',
        material: 'm-kraft',
        els: [
          _title(font: 'g:Caveat', color: 0xFF3A2414, size: 3.1, y: 0.42),
          _sticker('Scrapbooking.0', 0.42, 0.04, 0.16),
          _sticker('Scrapbooking.5', 0.65, 0.74, 0.2, rot: -0.2),
          _subtitle(font: 'g:Caveat', color: 0xFF5A3A1E),
        ],
      ),
      binding: 'strap',
      anim: 'drop',
    ),
  ),
  CoverTemplate(
    'night',
    'Starry night',
    () => _d(
      CoverFace(
        base: 'gradient',
        gradient: [0xFF0F0C29, 0xFF302B63, 0xFF24243E],
        angle: 70,
        overlay: const ScrapTextureStyle(
          id: 'sk-stars',
          opacity: 0.9,
          blend: 'screen',
        ),
        els: [
          _sticker('Celestial.0', 0.62, 0.08, 0.26, opts: {'shd': 0.6}),
          _title(
            font: 'g:Satisfy',
            color: 0xFFF6E27A,
            size: 2.8,
            opts: {'shd': 0.8},
          ),
          _subtitle(font: 'g:Satisfy', color: 0xFFD7D3FF),
        ],
      ),
      binding: 'spine',
      anim: 'sparkle',
    ),
  ),
  CoverTemplate(
    'cottage',
    'Cottage floral',
    () => _d(
      CoverFace(
        base: 'material',
        material: 'm-linen',
        overlay: const ScrapTextureStyle(
          id: 'fl-ditsy',
          opacity: 0.85,
          blend: 'multiply',
        ),
        els: [
          _sticker('Cottagecore.0', 0.06, 0.05, 0.22, rot: -0.2),
          _sticker('Cottagecore.2', 0.72, 0.8, 0.2, rot: 0.2),
          _title(
            font: 'g:Dancing Script',
            color: 0xFF5B3A29,
            size: 2.8,
            opts: {'ow': 1.4, 'oc': 0xFFFFF8EE},
          ),
          _subtitle(font: 'g:Dancing Script', color: 0xFF5B3A29),
        ],
      ),
      binding: 'ribbon',
      anim: 'swing',
    ),
  ),
  CoverTemplate(
    'gothic',
    'Gothic',
    () => _d(
      CoverFace(
        base: 'material',
        material: 'm-leather-black',
        els: [
          _border(0xFF8E1F2A, width: 1.4),
          _sticker('Gothic.0', 0.38, 0.06, 0.24),
          _title(
            font: 'g:Cinzel',
            color: 0xFFC62828,
            size: 2.2,
            y: 0.42,
            opts: {'shd': 0.7},
          ),
          _sticker('Gothic.3', 0.4, 0.74, 0.2),
        ],
      ),
      binding: 'hinge',
      anim: 'drop',
    ),
  ),
  CoverTemplate(
    'kawaii',
    'Pastel kawaii',
    () => _d(
      CoverFace(
        base: 'gradient',
        gradient: [0xFFFFC1D9, 0xFFD6C4FF],
        angle: 60,
        els: [
          _sticker('Kawaii.0', 0.04, 0.04, 0.26),
          _sticker('Kawaii.8', 0.7, 0.06, 0.24),
          _sticker('Kawaii.13', 0.06, 0.78, 0.2),
          _sticker('Kawaii.4', 0.72, 0.76, 0.22),
          _title(
            font: 'g:Pacifico',
            color: 0xFFFF5C8A,
            size: 2.6,
            opts: {'ow': 2, 'oc': 0xFFFFFFFF, 'shd': 0.6},
          ),
          _subtitle(font: 'g:Fredoka One', color: 0xFF8E6BC9),
        ],
      ),
      binding: 'spiral',
      anim: 'pop',
      corner: 0.12,
    ),
  ),
  CoverTemplate(
    'vintage',
    'Vintage paper',
    () => _d(
      CoverFace(
        base: 'material',
        material: 'm-vintage-paper',
        els: [
          _border(0xFF8A6B3A, inset: 0.06, width: 1.6),
          _border(0xFF8A6B3A, inset: 0.08, width: 0.6),
          _title(font: 'g:Great Vibes', color: 0xFF5A3A1E, size: 3, opts: {}),
          _subtitle(font: 'g:Dancing Script', color: 0xFF5A3A1E),
        ],
      ),
      binding: 'stitched',
      anim: 'slideLeft',
    ),
  ),
  CoverTemplate(
    'ocean',
    'Ocean',
    () => _d(
      CoverFace(
        base: 'gradient',
        gradient: [0xFF48C6EF, 0xFF1F5F8B, 0xFF0B2A4A],
        angle: 80,
        overlay: const ScrapTextureStyle(
          id: 'nt-waves',
          opacity: 0.6,
          blend: 'soft light',
        ),
        els: [
          _sticker('Ocean.5', 0.6, 0.1, 0.26, opts: {'shd': 0.4}),
          _sticker('Ocean.0', 0.08, 0.78, 0.2),
          _title(
            font: 'g:Lobster',
            color: 0xFFFFFFFF,
            size: 2.5,
            opts: {'shd': 0.6},
          ),
          _subtitle(font: 'g:Satisfy', color: 0xFFE3F6FF),
        ],
      ),
      binding: 'rings',
      anim: 'zoom',
    ),
  ),
  CoverTemplate(
    'cardboard',
    'Cardboard craft',
    () => _d(
      CoverFace(
        base: 'material',
        material: 'm-cardboard',
        els: [
          _title(
            font: 'g:Permanent Marker',
            color: 0xFF2E1B0E,
            size: 2.2,
            y: 0.38,
            opts: {'ta': 'center', 'shrink': true},
          ),
          _subtitle(font: 'g:Permanent Marker', color: 0xFF2E1B0E),
          _sticker('School.0', 0.04, 0.04, 0.2, rot: -0.3),
        ],
      ),
      binding: 'none',
      anim: 'slideUp',
      corner: 0.02,
    ),
  ),
  CoverTemplate(
    'photo',
    'Photo cover',
    () => _d(
      CoverFace(
        base: 'gradient',
        gradient: [0xFF3A3A4A, 0xFF1B1B26],
        els: [
          ScrapElement(
            type: ScrapType.photo,
            x: 0.12,
            y: 0.1,
            w: 0.76,
            h: 0.5,
            opts: {'fr2': 'polaroid'},
          ),
          _title(
            font: 'g:Caveat',
            color: 0xFFFFFFFF,
            y: 0.72,
            size: 2.2,
            h: 0.14,
          ),
        ],
      ),
      binding: 'spine',
      anim: 'swing',
    ),
  ),
];

CoverTemplate? coverTemplateById(String id) =>
    coverTemplates.where((t) => t.id == id).firstOrNull;
