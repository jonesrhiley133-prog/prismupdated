import 'package:flutter/foundation.dart';

/// Where in the year a collection belongs.
enum SeasonalKind { holiday, season, awareness }

/// What a collection's colours and shapes are built from. Every variation
/// resolves to one of these, so adding a collection never needs new code.
@immutable
class DecoPalette {
  const DecoPalette(
    this.id,
    this.base,
    this.primary,
    this.secondary,
    this.accent,
  );
  final String id;
  final int base, primary, secondary, accent;
  List<int> get all => [base, primary, secondary, accent];
}

/// Garlands, lights, borders, particles and corner pieces a style can pick.
enum GarlandStyle {
  vine,
  emoji,
  bunting,
  ribbon,
  beads,
  tinsel,
  chain,
  pompom,
  swag,
}

enum LightsStyle { none, fairy, bulbs, lanterns, stars, candles }

enum BorderStyle {
  none,
  hairline,
  double,
  dotted,
  scallop,
  frost,
  vine,
  ornate,
}

enum ParticleKind {
  none,
  snow,
  leaves,
  petals,
  rain,
  fireflies,
  stars,
  confetti,
  hearts,
  bubbles,
  sparkles,
  embers,
  clouds,
  butterflies,
  bokeh,
}

enum CornerStyle {
  cluster,
  sprig,
  wreath,
  lantern,
  scroll,
  frame,
  ribbon,
  window,
}

/// One finished look inside a collection: its own palette, garland, lights,
/// border, corner pieces, falling things, hanging things, furniture, icons,
/// companion accessory and optional sound.
@immutable
class SeasonalVariation {
  const SeasonalVariation({
    required this.id,
    required this.collectionId,
    required this.index,
    required this.name,
    required this.palette,
    required this.garland,
    required this.lights,
    required this.border,
    required this.corner,
    required this.particle,
    required this.garlandEmoji,
    required this.cornerEmoji,
    required this.hangers,
    required this.furniture,
    required this.icons,
    required this.accessory,
    required this.ambience,
    required this.seed,
    required this.tags,
  });

  /// `<collection>.<index>` — stable, never reused.
  final String id;
  final String collectionId;
  final int index;
  final String name;
  final DecoPalette palette;
  final GarlandStyle garland;
  final LightsStyle lights;
  final BorderStyle border;
  final CornerStyle corner;
  final ParticleKind particle;

  /// The things this look is made of (emoji drawn on the garland, in the
  /// corners, hanging down, standing along the bottom, and as icons).
  final List<String> garlandEmoji, cornerEmoji, hangers, furniture, icons;

  /// A small companion accessory that goes with the look.
  final String accessory;

  /// An ambience id the person can choose to hear with this look.
  final String? ambience;

  /// Varies spacing and arrangement so looks with similar parts still
  /// compose differently.
  final int seed;
  final List<String> tags;

  /// Everything that makes this look visually unique.
  String get signature => [
    palette.id,
    garland.name,
    lights.name,
    border.name,
    corner.name,
    particle.name,
    garlandEmoji.join(),
    cornerEmoji.join(),
  ].join('|');
}

/// A holiday, season or awareness period with 25+ looks.
@immutable
class SeasonalCollection {
  const SeasonalCollection({
    required this.id,
    required this.name,
    required this.emoji,
    required this.kind,
    required this.blurb,
    required this.variations,
    required this.greetings,
    this.greetingsEs = const [],
    this.note,
    this.approximateDates = false,
  });

  final String id;
  final String name;
  final String emoji;
  final SeasonalKind kind;

  /// A short, respectful description of what this is.
  final String blurb;
  final List<SeasonalVariation> variations;
  final List<String> greetings, greetingsEs;

  /// Extra context for cultural or religious collections.
  final String? note;

  /// Dates come from a lunar or observational calendar and may differ by a
  /// day or two where you live.
  final bool approximateDates;
}
