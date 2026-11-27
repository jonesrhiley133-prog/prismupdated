import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_shapes.dart';
import 'package:prism_plurality/features/scrapbook/scrap_washi.dart';
import 'package:prism_plurality/features/seasonal/decor_assets.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/living_data.dart';
import 'package:prism_plurality/features/seasonal/living_screens.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/icons/phosphor_icon_catalog.dart';

class _FakePrefs extends SeasonalPrefsNotifier {
  @override
  Future<void> flush() async {}
}

class _FakeLib extends AppearanceLibraryNotifier {
  @override
  Future<void> flush() async {}
}

ProviderContainer _container() => ProviderContainer(
  overrides: [
    seasonalPrefsProvider.overrideWith(_FakePrefs.new),
    appearanceLibraryProvider.overrideWith(_FakeLib.new),
    trackerKindProvider.overrideWith(
      (ref, kind) => const AsyncValue.data(<TrackerRecord>[]),
    ),
  ],
);

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  group('living genres', () {
    test('80 genres in 8 families of 10, each with 25 looks', () {
      expect(livingCollections, hasLength(80));
      expect(livingFamilies, hasLength(8));
      for (final f in livingFamilies) {
        expect(livingInGroup(f.$1), hasLength(10), reason: f.$2);
      }
      var looks = 0;
      for (final c in livingCollections) {
        expect(c.kind, SeasonalKind.living);
        expect(c.variations.length, greaterThanOrEqualTo(25), reason: c.id);
        expect(c.blurb, isNotEmpty);
        looks += c.variations.length;
      }
      expect(looks, greaterThanOrEqualTo(2000));
    });

    test('ids are unique and never clash with holidays', () {
      final ids = <String>{for (final c in seasonalCollections) c.id};
      for (final c in livingCollections) {
        expect(ids.add(c.id), isTrue, reason: 'duplicate ${c.id}');
      }
    });

    test('looks in a genre have distinct names and designs', () {
      for (final c in livingCollections) {
        expect(
          c.variations.map((v) => v.name).toSet(),
          hasLength(c.variations.length),
          reason: c.id,
        );
        expect(
          c.variations.map((v) => v.signature).toSet(),
          hasLength(c.variations.length),
          reason: c.id,
        );
        // Not just recolours: looks vary their garland/lights/border/corner.
        final parts = {
          for (final v in c.variations)
            '${v.garland}|${v.lights}|${v.border}|${v.corner}|${v.particle}',
        };
        expect(parts.length, greaterThanOrEqualTo(8), reason: c.id);
        // And each genre draws from its own objects.
        final objects = {
          for (final v in c.variations) ...[
            ...v.garlandEmoji,
            ...v.hangers,
            ...v.furniture,
          ],
        };
        expect(objects.length, greaterThanOrEqualTo(8), reason: c.id);
      }
    });

    test('every look resolves by id', () {
      for (final c in livingCollections) {
        for (final v in c.variations) {
          expect(variationById(v.id)?.name, v.name);
          expect(arrangementForVariation(v), isNotEmpty);
        }
      }
    });

    test('living genres are never scheduled', () {
      final p = SeasonalPrefs(
        performance: DecoPerformance.balanced,
        autoSchedule: true,
        celebrated: {for (final c in livingCollections) c.id},
      );
      for (var m = 1; m <= 12; m++) {
        expect(resolveActiveSeason(DateTime(2026, m, 15), p), isNull);
      }
    });

    test('a living look is saved and is its own layer', () {
      final p = const SeasonalPrefs().copyWith(
        livingVariation: 'cyberpunk.3',
        manualVariation: 'christmas.0',
      );
      final back = SeasonalPrefs.fromJson(p.toJson());
      expect(back.livingVariation, 'cyberpunk.3');
      expect(back.manualVariation, 'christmas.0');
      expect(back.copyWith(livingVariation: null).livingVariation, isNull);
    });

    test('the decorations provider draws the living look', () {
      final c = _container();
      addTearDown(c.dispose);
      c
          .read(seasonalPrefsProvider.notifier)
          .update(
            (p) => p.copyWith(
              performance: DecoPerformance.balanced,
              livingVariation: 'kawaii.2',
            ),
          );
      final items = c.read(seasonalItemsProvider);
      expect(items.where((i) => i.variationId == 'kawaii.2'), isNotEmpty);
    });
  });

  group('asset library', () {
    test('1,500+ assets in 50+ categories, none empty', () {
      expect(decorAssets.length, greaterThanOrEqualTo(1500));
      expect(decorAssetCategories.length, greaterThanOrEqualTo(50));
      for (final c in decorAssetCategories) {
        expect(decorAssetsIn(c.id), isNotEmpty, reason: c.id);
      }
    });

    test('ids and glyphs are unique', () {
      expect(
        decorAssets.map((a) => a.id).toSet(),
        hasLength(decorAssets.length),
      );
      expect(
        decorAssets.map((a) => a.glyph).toSet(),
        hasLength(decorAssets.length),
      );
    });

    test('every asset can be drawn', () {
      for (final a in decorAssets) {
        final g = a.glyph;
        if (g.startsWith('ph:')) {
          expect(
            PhosphorIconCatalog.iconFor(g.substring(3)),
            isNotNull,
            reason: g,
          );
        } else if (g.startsWith('fr:')) {
          expect(scrapFrameById(g.substring(3)), isNotNull, reason: g);
        } else if (g.startsWith('wa:')) {
          expect(washiPatterns.any((w) => w.id == g.substring(3)), isTrue);
        } else if (g.startsWith('sh:')) {
          expect(scrapShapeIds, contains(g.substring(3)));
        } else if (g.startsWith('st:')) {
          expect(decorStyleOf(g), isNotNull);
        } else {
          expect(g.runes, isNotEmpty);
        }
        expect(a.name.trim(), isNotEmpty);
      }
    });

    test('search finds by name and category', () {
      expect(decorAssets.where((a) => a.matches('cat')), isNotEmpty);
      expect(decorAssets.where((a) => a.matches('Holograms')), isNotEmpty);
    });

    test('placing an asset makes a usable decoration', () {
      for (final a in [
        decorAssets.firstWhere((a) => a.glyph.startsWith('st:g.')),
        decorAssets.firstWhere((a) => a.glyph.startsWith('ph:')),
        decorAssets.first,
      ]) {
        final i = decorItemForAsset(a, 'x', variationId: 'kawaii.0');
        final back = DecorItem.fromJson(i.toJson())!;
        expect(back.glyph, a.glyph);
        expect(back.kind, a.kind);
      }
    });

    test('favourites and recents round-trip', () {
      var l = const AppearanceLibrary();
      l = l.toggleFavorite('asset:food.1').used('genre:cyberpunk');
      final back = AppearanceLibrary.fromJson(l.toJson());
      expect(back.favoritesIn('asset:'), ['food.1']);
      expect(back.recentsIn('genre:'), ['cyberpunk']);
      expect(back.toggleFavorite('asset:food.1').favorites, isEmpty);
    });
  });

  group('screens', () {
    testWidgets('collections list, apply a look, undo', (tester) async {
      final c = _container();
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(c, const LivingGenreScreen(genreId: 'space_station')),
      );
      await _settle(tester);
      expect(find.text('Orbital Dawn'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('living-look:space_station.0')),
      );
      await _settle(tester);
      await tester.tap(find.text('Use this look'));
      await _settle(tester);
      expect(c.read(seasonalPrefsProvider).livingVariation, 'space_station.0');
      expect(
        c.read(seasonalPrefsProvider).performance,
        isNot(DecoPerformance.off),
      );
      // Theme-side settings are never part of a living look.
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await _settle(tester);
      expect(c.read(seasonalPrefsProvider).livingVariation, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('families list renders with search', (tester) async {
      final c = _container();
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(c, const LivingCollectionsScreen()));
      await _settle(tester);
      expect(find.text('Space Station'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'frutiger');
      await _settle(tester);
      expect(find.text('Frutiger Aero'), findsOneWidget);
      expect(find.text('Space Station'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('asset library browses and favourites', (tester) async {
      final c = _container();
      tester.view.physicalSize = const Size(420, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(c, const DecorAssetLibraryScreen()));
      await _settle(tester);
      final first = decorAssetsIn('hanging').first;
      expect(find.byKey(ValueKey('asset:${first.id}')), findsOneWidget);
      await tester.longPress(find.byKey(ValueKey('asset:${first.id}')));
      await _settle(tester);
      expect(
        c.read(appearanceLibraryProvider).isFavorite('asset:${first.id}'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  });
}
