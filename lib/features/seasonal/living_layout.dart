import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/shared/theme/layout_decor.dart';

/// What each family calls the parts of its layout, so a space station has
/// porthole frames and a cottage has wooden shelves.
const _partNames = <String, Map<String, (String, String)>>{
  'space': {
    LayoutPart.header: ('Console header trim', 'Borde de consola'),
    LayoutPart.cards: ('Control panel badges', 'Insignias de panel'),
    LayoutPart.dividers: ('Holographic dividers', 'Divisores holográficos'),
    LayoutPart.profile: ('Porthole profile frames', 'Marcos de ojo de buey'),
    LayoutPart.nav: ('Navigation console strip', 'Consola de navegación'),
    LayoutPart.hanging: ('Hanging satellites', 'Satélites colgantes'),
  },
  'future': {
    LayoutPart.header: ('Holo header line', 'Línea holográfica'),
    LayoutPart.cards: ('Panel indicators', 'Indicadores de panel'),
    LayoutPart.dividers: ('Circuit dividers', 'Divisores de circuito'),
    LayoutPart.profile: ('Scanner frames', 'Marcos de escáner'),
    LayoutPart.nav: ('Dock lights', 'Luces del dock'),
    LayoutPart.hanging: ('Floating gadgets', 'Aparatos flotantes'),
  },
  'cozy': {
    LayoutPart.header: ('Lace header trim', 'Encaje del encabezado'),
    LayoutPart.cards: ('Scrapbook labels', 'Etiquetas de álbum'),
    LayoutPart.dividers: ('Floral dividers', 'Divisores florales'),
    LayoutPart.profile: ('Wreath frames', 'Marcos de corona'),
    LayoutPart.nav: ('Wooden shelf garland', 'Guirnalda de estante'),
    LayoutPart.hanging: ('Hanging plants', 'Plantas colgantes'),
  },
  'academic': {
    LayoutPart.header: ('Chalkboard header trim', 'Borde de pizarra'),
    LayoutPart.cards: ('Sticky-note tags', 'Notas adhesivas'),
    LayoutPart.dividers: ('Notebook-margin dividers', 'Márgenes de cuaderno'),
    LayoutPart.profile: ('Stamp frames', 'Marcos de sello'),
    LayoutPart.nav: ('Pencil-case strip', 'Estuche'),
    LayoutPart.hanging: ('Pinned notes', 'Notas clavadas'),
  },
  'nature': {
    LayoutPart.header: ('Leafy header trim', 'Borde de hojas'),
    LayoutPart.cards: ('Little creatures', 'Pequeñas criaturas'),
    LayoutPart.dividers: ('Vine dividers', 'Divisores de enredadera'),
    LayoutPart.profile: ('Nature frames', 'Marcos naturales'),
    LayoutPart.nav: ('Foliage strip', 'Franja de follaje'),
    LayoutPart.hanging: ('Hanging vines', 'Enredaderas colgantes'),
  },
  'artistic': {
    LayoutPart.header: ('Ornamental header', 'Encabezado ornamental'),
    LayoutPart.cards: ('Corner flourishes', 'Florituras'),
    LayoutPart.dividers: ('Ornamental borders', 'Bordes ornamentales'),
    LayoutPart.profile: ('Portrait frames', 'Marcos de retrato'),
    LayoutPart.nav: ('Trimmed navigation', 'Navegación adornada'),
    LayoutPart.hanging: ('Hanging charms', 'Dijes colgantes'),
  },
  'cute': {
    LayoutPart.header: ('Scalloped header', 'Encabezado festoneado'),
    LayoutPart.cards: ('Sticker corners', 'Pegatinas en esquinas'),
    LayoutPart.dividers: ('Bubbly dividers', 'Divisores burbujeantes'),
    LayoutPart.profile: ('Plush frames', 'Marcos de peluche'),
    LayoutPart.nav: ('Candy garland', 'Guirnalda dulce'),
    LayoutPart.hanging: ('Dangling charms', 'Colgantes'),
  },
  'lifestyle': {
    LayoutPart.header: ('Marquee header trim', 'Marquesina'),
    LayoutPart.cards: ('Ticket-stub corners', 'Esquinas de entrada'),
    LayoutPart.dividers: ('Track dividers', 'Divisores de pista'),
    LayoutPart.profile: ('Record frames', 'Marcos de disco'),
    LayoutPart.nav: ('Stage lights', 'Luces de escenario'),
    LayoutPart.hanging: ('Hanging gear', 'Equipo colgante'),
  },
};

const _defaultNames = <String, (String, String)>{
  LayoutPart.header: ('Header trim', 'Borde del encabezado'),
  LayoutPart.cards: ('Card corners', 'Esquinas de tarjetas'),
  LayoutPart.dividers: ('Dividers', 'Divisores'),
  LayoutPart.profile: ('Profile frames', 'Marcos de perfil'),
  LayoutPart.nav: ('Navigation garland', 'Guirnalda de navegación'),
  LayoutPart.hanging: ('Hanging decorations', 'Decoraciones colgantes'),
};

/// The name of [part] in [v]'s family.
String layoutPartName(BuildContext context, SeasonalVariation? v, String part) {
  final family = v == null ? null : collectionById(v.collectionId)?.group;
  final n = _partNames[family]?[part] ?? _defaultNames[part]!;
  return Localizations.localeOf(context).languageCode == 'es' ? n.$2 : n.$1;
}

/// The layout arrangement of a look, with [parts] switched on.
LayoutDecorData layoutDecorFor(SeasonalVariation v, Set<String> parts) {
  final line = switch (v.border) {
    DecoBorder.none || DecoBorder.hairline => 'hairline',
    DecoBorder.double => 'double',
    DecoBorder.dotted => 'dotted',
    DecoBorder.scallop => 'scallop',
    DecoBorder.frost => 'frost',
    DecoBorder.vine => 'vine',
    DecoBorder.ornate => 'ornate',
    DecoBorder.mkeka => 'mkeka',
    DecoBorder.zigzag => 'zigzag',
    DecoBorder.lace => 'lace',
    DecoBorder.stitched => 'stitched',
  };
  final p = v.palette;
  // Readable on light and dark themes: the base colour is often near white
  // or near black, so the look's three strong colours are used.
  return LayoutDecorData(
    parts: parts,
    primary: Color(p.primary),
    secondary: Color(p.secondary),
    accent: Color(p.accent),
    motif: v.icons.isEmpty ? '✨' : v.icons.first,
    corner: v.cornerEmoji.isEmpty ? '✨' : v.cornerEmoji.first,
    line: line,
  );
}

/// The arrangement shown now, if any.
final layoutDecorProvider = Provider<LayoutDecorData?>((ref) {
  final prefs = ref.watch(seasonalPrefsProvider);
  if (prefs.performance == DecoPerformance.off) return null;
  final room = ref.watch(activeRoomProvider);
  final id = room?.layout ?? prefs.layoutVariation;
  if (id == null) return null;
  final v = variationById(id);
  if (v == null) return null;
  final parts = room?.layout != null ? room?.layoutParts : prefs.layoutParts;
  return layoutDecorFor(v, parts ?? LayoutPart.all.toSet());
});

/// The overlay parts of an arrangement: a garland along the navigation bar
/// and hanging decorations from the top.
List<DecorItem> layoutOverlayItems(SeasonalVariation v, Set<String> parts) => [
  if (parts.contains(LayoutPart.nav))
    DecorItem(
      id: 'layout-nav-${v.id}',
      kind: DecoKind.garland,
      variationId: v.id,
      anchor: DecoAnchor.bottom,
      x: 0.5,
      y: 0.0,
      w: 1.0,
      z: 2,
      opacity: 0.9,
    ),
  if (parts.contains(LayoutPart.hanging))
    for (var i = 0; i < 2; i++)
      DecorItem(
        id: 'layout-hang-${v.id}-$i',
        kind: DecoKind.ornament,
        variationId: v.id,
        glyph: v.hangers[(i + 1) % v.hangers.length],
        anchor: i == 0 ? DecoAnchor.topLeft : DecoAnchor.topRight,
        x: i == 0 ? 0.25 : 0.75,
        y: 0.2,
        w: 0.22,
        z: 5,
      ),
];

/// Puts the active arrangement where shared widgets can find it.
class LayoutDecorHost extends ConsumerWidget {
  const LayoutDecorHost({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      LayoutDecor(data: ref.watch(layoutDecorProvider), child: child);
}
