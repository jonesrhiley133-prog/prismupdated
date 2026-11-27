import 'package:flutter/widgets.dart';

import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_shapes.dart';
import 'package:prism_plurality/features/scrapbook/scrap_washi.dart';
import 'package:prism_plurality/features/seasonal/decor_assets_data.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/shared/icons/phosphor_icon_catalog.dart';

/// How a placed asset moves by default. The person can change any of it per
/// decoration; these are only starting points.
enum AssetBehavior {
  none,
  sway,
  twinkle,
  bloom,
  toggle,
  flicker,
  open,
  play,
  bounce,
  walk,
  flutter,
  swim,
  orbit,
  drift,
  fall,
  ripple,
  shimmer,
  tick,
  blink,
  float,
  spin,
  move,
  steam,
  pulse,
  wave,
}

@immutable
class DecorAssetCategory {
  const DecorAssetCategory(this.id, this.name, this.emoji, this.behavior);
  final String id, name, emoji;
  final AssetBehavior behavior;
}

/// One individually selectable decoration.
///
/// [glyph] says how it's drawn:
/// - an emoji;
/// - `ph:<icon>` line art from the app's icon font, tinted;
/// - `fr:<frame>`, `wa:<washi>`, `sh:<shape>` scrapbook pieces;
/// - `st:<g|l|b|c|p>.<style>` a garland, light string, border, corner piece
///   or falling effect in one specific style.
@immutable
class DecorAsset {
  const DecorAsset(this.id, this.name, this.category, this.glyph, this.kind);
  final String id, name, category, glyph;

  /// What gets placed when this asset is added.
  final DecoKind kind;

  bool matches(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;
    return name.toLowerCase().contains(s) ||
        category.toLowerCase().contains(s) ||
        (decorAssetCategoryById(category)?.name.toLowerCase().contains(s) ??
            false);
  }
}

List<DecorAssetCategory>? _cats;

/// Every category, in library order.
List<DecorAssetCategory> get decorAssetCategories => _cats ??= [
  for (final r in decorAssetCategoryRows)
    () {
      final p = r.split('|');
      return DecorAssetCategory(
        p[0],
        p[1],
        p[2],
        AssetBehavior.values.firstWhere(
          (b) => b.name == p[3],
          orElse: () => AssetBehavior.none,
        ),
      );
    }(),
];

DecorAssetCategory? decorAssetCategoryById(String id) {
  for (final c in decorAssetCategories) {
    if (c.id == id) return c;
  }
  return null;
}

String _title(String kebab) => kebab
    .split(RegExp('[-_]'))
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _spaced(String camel) => camel
    .replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .toLowerCase();

/// What each category places by default.
DecoKind _kindFor(String cat) => switch (cat) {
  'hanging' ||
  'lanterns' ||
  'floating' ||
  'stars' ||
  'planets' => DecoKind.ornament,
  'flowers' => DecoKind.flower,
  'furniture' || 'shelves' || 'buildings' || 'vehicles' => DecoKind.furniture,
  'candles' => DecoKind.candle,
  _ => DecoKind.illustration,
};

List<DecorAsset> _build() {
  final out = <DecorAsset>[];
  for (final c in decorAssetCategories) {
    var n = 0;
    final kind = _kindFor(c.id);
    final emoji = decorAssetEmoji[c.id];
    if (emoji != null) {
      for (final item in emoji.split('|')) {
        final sp = item.indexOf(' ');
        out.add(
          DecorAsset(
            '${c.id}.${n++}',
            item.substring(sp + 1),
            c.id,
            item.substring(0, sp),
            kind,
          ),
        );
      }
    }
    final icons = decorAssetIcons[c.id];
    if (icons != null) {
      for (final name in icons.split(' ')) {
        out.add(
          DecorAsset('${c.id}.${n++}', _title(name), c.id, 'ph:$name', kind),
        );
      }
    }
    // Pieces drawn by Prism's own painters, so they follow a look's colours.
    switch (c.id) {
      case 'garlands':
        for (final g in GarlandStyle.values) {
          out.add(
            DecorAsset(
              '${c.id}.${n++}',
              '${_title(_spaced(g.name))} garland',
              c.id,
              'st:g.${g.name}',
              DecoKind.garland,
            ),
          );
        }
      case 'lights':
        for (final l in LightsStyle.values) {
          if (l == LightsStyle.none) continue;
          out.add(
            DecorAsset(
              '${c.id}.${n++}',
              '${_title(_spaced(l.name))} light string',
              c.id,
              'st:l.${l.name}',
              DecoKind.fairyLights,
            ),
          );
        }
      case 'dividers':
        for (final b in DecoBorder.values) {
          if (b == DecoBorder.none) continue;
          out.add(
            DecorAsset(
              '${c.id}.${n++}',
              '${_title(_spaced(b.name))} border',
              c.id,
              'st:b.${b.name}',
              DecoKind.border,
            ),
          );
        }
      case 'corners':
        for (final k in CornerStyle.values) {
          out.add(
            DecorAsset(
              '${c.id}.${n++}',
              '${_title(_spaced(k.name))} corner',
              c.id,
              'st:c.${k.name}',
              DecoKind.corner,
            ),
          );
        }
      case 'weather':
        for (final p in ParticleKind.values) {
          if (p == ParticleKind.none) continue;
          out.add(
            DecorAsset(
              '${c.id}.${n++}',
              'Falling ${_spaced(p.name)}',
              c.id,
              'st:p.${p.name}',
              DecoKind.particles,
            ),
          );
        }
      case 'frames':
        for (final f in scrapFrames) {
          out.add(
            DecorAsset(
              '${c.id}.${n++}',
              '${f.name} frame',
              c.id,
              'fr:${f.id}',
              DecoKind.illustration,
            ),
          );
        }
      case 'washi':
        for (final w in washiPatterns) {
          out.add(
            DecorAsset(
              '${c.id}.${n++}',
              '${w.name} tape',
              c.id,
              'wa:${w.id}',
              DecoKind.illustration,
            ),
          );
        }
      case 'sculpture':
        for (final g in scrapShapeGroups.values) {
          for (final s in g) {
            out.add(
              DecorAsset(
                '${c.id}.${n++}',
                '${scrapShapeName(s)} sculpture',
                c.id,
                'sh:$s',
                DecoKind.illustration,
              ),
            );
          }
        }
    }
  }
  return out;
}

/// The whole library (1,500+ assets in 55+ categories), built once.
final List<DecorAsset> decorAssets = _build();

final Map<String, DecorAsset> _byId = {for (final a in decorAssets) a.id: a};

DecorAsset? decorAssetById(String id) => _byId[id];

List<DecorAsset> decorAssetsIn(String category) => [
  for (final a in decorAssets)
    if (a.category == category) a,
];

/// The icon an `ph:` glyph names, if it exists.
IconData? decorIconFor(String glyph) => glyph.startsWith('ph:')
    ? PhosphorIconCatalog.iconFor(glyph.substring(3))
    : null;

/// The style a `st:` glyph pins, if any.
({String part, String style})? decorStyleOf(String? glyph) {
  if (glyph == null || !glyph.startsWith('st:') || glyph.length < 6) {
    return null;
  }
  return (part: glyph.substring(3, 4), style: glyph.substring(5));
}

/// Places [a] as a new decoration, centred, at a sensible size for its kind.
DecorItem decorItemForAsset(DecorAsset a, String id, {String? variationId}) {
  final wide = switch (a.kind) {
    DecoKind.garland ||
    DecoKind.fairyLights ||
    DecoKind.border ||
    DecoKind.particles => true,
    _ => false,
  };
  return DecorItem(
    id: id,
    kind: a.kind,
    variationId: variationId,
    glyph: a.glyph,
    anchor: switch (a.kind) {
      DecoKind.garland || DecoKind.fairyLights => DecoAnchor.top,
      DecoKind.corner => DecoAnchor.topLeft,
      _ => DecoAnchor.screen,
    },
    x: a.kind == DecoKind.corner ? 0 : 0.5,
    y: switch (a.kind) {
      DecoKind.garland => 0.0,
      DecoKind.fairyLights => 0.5,
      DecoKind.corner => 0.0,
      _ => 0.5,
    },
    w: wide ? 1.0 : (a.kind == DecoKind.corner ? 0.24 : 0.14),
    z: 5,
    behavior: wide || a.kind == DecoKind.corner ? null : defaultBehaviorFor(a),
  );
}

/// How a library piece moves when first placed (the person can change it).
String? defaultBehaviorFor(DecorAsset a) {
  const players = {'ph:vinyl-record', '💿', '📀', '📻', 'ph:disc'};
  if (players.contains(a.glyph)) return 'play';
  final b = decorAssetCategoryById(a.category)?.behavior ?? AssetBehavior.none;
  return b == AssetBehavior.none ? null : b.name;
}
