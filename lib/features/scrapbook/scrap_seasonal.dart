import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_plurality/features/scrapbook/scrap_cover.dart';
import 'package:prism_plurality/features/scrapbook/scrap_cover_templates.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/scrapbook/scrap_page.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';
import 'package:prism_plurality/features/seasonal/seasonal_calendar.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';

// Seasonal Living feeds the scrapbook with covers, page textures, stickers,
// frames and page templates drawn from each holiday's and season's looks.
// Nothing here ever changes anything by itself: these are things to choose.

bool _dark(int c) =>
    ThemeData.estimateBrightnessForColor(Color(c)) == Brightness.dark;

/// A readable text colour for [bg].
int _onColor(int bg) => _dark(bg) ? 0xFFFFFFFF : 0xFF2B2230;

ScrapElement _emoji(
  String glyph,
  double x,
  double y,
  double s, {
  double rot = 0,
  int z = 0,
}) => ScrapElement(
  type: ScrapType.sticker,
  text: glyph,
  x: x,
  y: y,
  w: s,
  h: s * 0.72,
  rot: rot,
  z: z,
);

/// A whole cover made from one look: its colours, texture, edge, garland and
/// corner pieces.
CoverDesign coverFromVariation(SeasonalVariation v, {String? greeting}) {
  final p = v.palette;
  final onBase = _onColor(p.base);
  final corners = v.cornerEmoji.isEmpty ? v.icons : v.cornerEmoji;
  String at(List<String> l, int i) => l.isEmpty ? '✨' : l[i % l.length];
  final border = v.border == DecoBorder.none
      ? null
      : ScrapElement(
          type: ScrapType.shape,
          text: switch (v.border) {
            DecoBorder.scallop => 'scallop',
            DecoBorder.ornate => 'octagon',
            DecoBorder.frost => 'star16',
            _ => 'rrect',
          },
          color: p.accent,
          x: 0.05,
          y: 0.036,
          w: 0.9,
          h: 0.928,
          opts: {
            'nf': true,
            'bc': p.accent,
            'bw': v.border == DecoBorder.hairline ? 1.0 : 2.0,
          },
        );
  final face = CoverFace(
    base: 'gradient',
    gradient: [p.base, p.primary],
    angle: 40.0 + (v.seed % 5) * 25,
    overlay: ScrapTextureStyle(
      id: 'seas:${v.id}',
      opacity: 0.45,
      blend: 'soft light',
    ),
    els: [
      ?border,
      // Garland across the top.
      for (var i = 0; i < 5; i++)
        _emoji(
          at(v.garlandEmoji, i),
          0.06 + i * 0.18,
          0.03 + (i.isEven ? 0.0 : 0.015),
          0.16,
          rot: (i.isEven ? -0.1 : 0.1),
        ),
      _emoji(at(corners, 0), 0.05, 0.84, 0.2, rot: -0.2),
      _emoji(at(corners, 1), 0.75, 0.84, 0.2, rot: 0.2),
      _emoji(at(v.icons, 0), 0.34, 0.2, 0.32),
      ScrapElement(
        type: ScrapType.text,
        text: '{title}',
        font: 'g:Pacifico',
        color: onBase,
        size: 2.3,
        x: 0.1,
        y: 0.5,
        w: 0.8,
        h: 0.18,
        opts: {
          'ta': 'center',
          'shrink': true,
          'ow': 1.2,
          'oc': _dark(p.base) ? p.primary : p.base,
          'shd': 0.4,
        },
      ),
      ScrapElement(
        type: ScrapType.text,
        text: greeting ?? '{subtitle}',
        font: 'g:Caveat',
        color: onBase,
        size: 1.3,
        x: 0.12,
        y: 0.7,
        w: 0.76,
        h: 0.08,
        opts: {'ta': 'center', 'shrink': true},
      ),
    ],
  );
  final d = CoverDesign(
    front: face,
    back: CoverFace(
      base: 'gradient',
      gradient: [p.base, p.primary],
      angle: face.angle,
      overlay: face.overlay,
    ),
    binding: v.garland == GarlandStyle.ribbon
        ? 'ribbon'
        : v.lights != LightsStyle.none
        ? 'rings'
        : 'spine',
    anim: v.lights == LightsStyle.none ? 'swing' : 'sparkle',
    spineColor: p.secondary,
    corner: v.corner == CornerStyle.wreath ? 0.12 : 0.06,
  );
  return d;
}

CoverTemplate seasonalCoverTemplate(SeasonalVariation v) {
  final c = collectionById(v.collectionId);
  return CoverTemplate(
    'seas:${v.id}',
    '${c?.name ?? ''} · ${v.name}',
    () => coverFromVariation(v),
  );
}

/// A page laid out in one look: garland, corner pieces, a framed photo and
/// a title in the collection's own words.
ScrapPageTemplate seasonalPageTemplate(SeasonalVariation v) {
  final c = collectionById(v.collectionId);
  return ScrapPageTemplate(
    id: 'seas:${v.id}',
    name: '${c?.name ?? ''} · ${v.name}',
    build: () {
      final p = v.palette;
      final on = _onColor(p.base);
      String at(List<String> l, int i) => l.isEmpty ? '✨' : l[i % l.length];
      final corners = v.cornerEmoji.isEmpty ? v.icons : v.cornerEmoji;
      final greeting = c == null || c.greetings.isEmpty
          ? ''
          : c.greetings[v.seed % c.greetings.length];
      return (
        els: [
          for (var i = 0; i < 5; i++)
            _emoji(
              at(v.garlandEmoji, i),
              0.04 + i * 0.19,
              0.01 + (i.isEven ? 0 : 0.012),
              0.15,
              rot: i.isEven ? -0.08 : 0.08,
            ),
          ScrapElement(
            type: ScrapType.photo,
            x: 0.12,
            y: 0.16,
            w: 0.76,
            h: 0.5,
            opts: {'fr2': 'seas:${v.id}'},
          ),
          ScrapElement(
            type: ScrapType.text,
            text: greeting,
            x: 0.1,
            y: 0.7,
            w: 0.8,
            h: 0.1,
            font: 'g:Pacifico',
            color: on,
            size: 1.6,
            opts: {'ta': 'center', 'shrink': true},
          ),
          _emoji(at(corners, 0), 0.03, 0.84, 0.17, rot: -0.2),
          _emoji(at(corners, 1), 0.8, 0.84, 0.17, rot: 0.2),
          _emoji(at(v.icons, 1), 0.42, 0.85, 0.16),
        ],
        style: ScrapPageStyle(
          color: p.base,
          color2: v.seed.isEven ? p.primary : null,
          angle: 90,
          pattern: 'none',
          texture: ScrapTextureStyle(
            id: 'seas:${v.id}',
            opacity: 0.55,
            blend: 'multiply',
          ),
        ),
      );
    },
  );
}

/// Collections in the order that suits *today*: what's in season now
/// (shortest window first), then what's coming up soonest, then the rest.
/// Hidden ones are left out and ones you celebrate come first within a tier.
/// This only orders things for browsing; it never applies anything.
List<SeasonalCollection> suggestedCollections(
  DateTime now, {
  SeasonalRegion region = SeasonalRegion.global,
  Hemisphere hemisphere = Hemisphere.auto,
  Set<String> hidden = const {},
  Set<String> celebrated = const {},
}) {
  final today = DateTime(now.year, now.month, now.day);
  final scored = <(SeasonalCollection, int)>[];
  for (final c in seasonalCollections) {
    if (hidden.contains(c.id)) continue;
    var score = 1 << 20;
    for (final r in SeasonalWindows.candidates(
      c.id,
      today.year,
      region: region,
      hemisphere: hemisphere,
    )) {
      int s;
      if (r.contains(today)) {
        s = r.days; // in season: shorter windows are more specific
      } else if (r.start.isAfter(today)) {
        s = 1000 + r.start.difference(today).inDays;
      } else {
        s = 5000 + today.difference(r.end).inDays;
      }
      score = math.min(score, s);
    }
    if (celebrated.contains(c.id)) score -= 1;
    scored.add((c, score));
  }
  scored.sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final s in scored) s.$1];
}
