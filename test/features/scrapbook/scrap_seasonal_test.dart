import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/scrapbook/scrap_cover.dart';
import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_seasonal.dart';
import 'package:prism_plurality/features/scrapbook/scrap_seasonal_ui.dart';
import 'package:prism_plurality/features/scrapbook/scrap_stickers.dart';
import 'package:prism_plurality/features/scrapbook/scrap_texture_painter.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';

void main() {
  final looks = [for (final c in seasonalCollections) ...c.variations];

  test('every holiday and season has stickers, and every id resolves', () {
    expect(seasonalCollections.length, greaterThanOrEqualTo(30));
    for (final c in seasonalCollections) {
      final list = seasonalStickersFor(c.id);
      expect(list.length, greaterThanOrEqualTo(6), reason: c.id);
      expect(list.first.data, c.emoji);
      for (final s in list) {
        expect(scrapStickerById(s.id)?.data, s.data, reason: s.id);
        expect(s.category, seasonalStickerCategory);
      }
    }
    expect(scrapStickerById('seas.christmas.9999'), isNull);
    expect(scrapStickerById('seas.nope.1'), isNull);
    expect(scrapStickerById('seas.christmas.x'), isNull);
    expect(
      scrapStickerCategories.length,
      23,
      reason: 'the 23 built-in categories are unchanged',
    );
  });

  test(
    'every look yields a texture, frames and a cover whose references all exist',
    () {
      expect(looks.length, greaterThanOrEqualTo(750));
      for (final v in looks) {
        final t = scrapTextureById('seas:${v.id}');
        expect(t, isNotNull, reason: v.id);
        expect(t!.c1, Color(v.palette.base));
        final cover = coverFromVariation(v);
        expect(coverAnimations, contains(cover.anim));
        expect(coverBindings, contains(cover.binding));
        expect(scrapTextureById(cover.front.overlay.id), isNotNull);
        expect(
          CoverDesign.fromJson(cover.toJson())!.toJson(),
          cover.toJson(),
          reason: v.id,
        );
        final page = seasonalPageTemplate(v).build();
        expect(scrapTextureById(page.style!.texture.id), isNotNull);
        for (final e in page.els) {
          final fr = e.opts['fr2'];
          if (fr is String)
            expect(scrapFrameById(fr), isNotNull, reason: '${v.id} $fr');
        }
      }
      for (final c in seasonalCollections) {
        final frames = seasonalFramesFor(c.id);
        expect(frames.length, 4);
        for (final f in frames) {
          expect(scrapFrameById(f.id)?.name, f.name);
          expect(f.inner(const Size(200, 200)).width, greaterThan(50));
        }
      }
      expect(scrapTextureById('seas:nope.1'), isNull);
      expect(scrapFrameById('seas:nope.1'), isNull);
    },
  );

  test(
    'suggestions put what is in season first, drop hidden ones, and never apply anything',
    () {
      final dec = suggestedCollections(DateTime(2026, 12, 10));
      expect(dec.take(6).map((c) => c.id), contains('christmas'));
      final oct = suggestedCollections(DateTime(2026, 10, 20));
      expect(oct.take(4).map((c) => c.id), contains('halloween'));
      expect(
        suggestedCollections(
          DateTime(2026, 12, 10),
          hidden: {'christmas'},
        ).map((c) => c.id),
        isNot(contains('christmas')),
      );
      final first = suggestedCollections(DateTime(2026, 6, 1)).first;
      expect(first.id, isNotEmpty);
      // The same collections, just reordered.
      expect(dec.length, seasonalCollections.length);
      expect(
        {for (final c in dec) c.id},
        {for (final c in seasonalCollections) c.id},
      );
      // Celebrated ones win ties.
      final celebrated = suggestedCollections(
        DateTime(2026, 12, 10),
        celebrated: {'christmas'},
      );
      expect(
        celebrated.indexWhere((c) => c.id == 'christmas'),
        lessThanOrEqualTo(dec.indexWhere((c) => c.id == 'christmas')),
      );
    },
  );

  testWidgets('seasonal covers, textures, frames and pages all draw', (
    t,
  ) async {
    Widget host(Widget w) => ProviderScope(
      overrides: [
        trackerKindProvider.overrideWith(
          (ref, k) => const AsyncValue.data(<TrackerRecord>[]),
        ),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(data: const MediaQueryData(), child: w),
      ),
    );
    for (final c in seasonalCollections) {
      final v = c.variations[3 % c.variations.length];
      await t.pumpWidget(
        host(
          SizedBox(
            width: 160,
            child: ScrapCoverView(
              design: coverFromVariation(v),
              title: 'Title',
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull, reason: 'cover ${v.id}');
      final tex = seasonalTexture(v);
      await t.pumpWidget(
        host(
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: ScrapTexturePainter(
                kind: tex.kind,
                c1: tex.c1,
                c2: tex.c2,
                seed: tex.seed,
                scale: tex.scale,
              ),
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull, reason: 'texture ${v.id}');
      await t.pumpWidget(
        host(
          SizedBox(
            width: 100,
            height: 100,
            child: ScrapFramedImage(
              frame: seasonalFrame(v),
              child: const ColoredBox(color: Colors.teal),
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull, reason: 'frame ${v.id}');
    }
  });

  testWidgets('the seasonal pickers show up and hand back real choices', (
    t,
  ) async {
    final c = ProviderContainer(
      overrides: [
        trackerKindProvider.overrideWith(
          (ref, k) => const AsyncValue.data(<TrackerRecord>[]),
        ),
      ],
    );
    addTearDown(c.dispose);
    t.view.physicalSize = const Size(900, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    String? texture;
    String? cover;
    String? page;
    String? frame;
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                SeasonalTexturePicker(
                  current: 'plain',
                  onPick: (id) => texture = id,
                ),
                SeasonalCoverPicker(onPick: (x) => cover = x.id),
                SeasonalPageTemplatePicker(onPick: (x) => page = x.id),
                SizedBox(
                  height: 400,
                  child: ScrapFrameBrowser(
                    current: '',
                    onPick: (id) => frame = id,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    Future<void> tapFirst(Finder f) async {
      await t.ensureVisible(f.first);
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(f.first, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 100));
    }

    Finder keyed(String p) => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          (w.key as ValueKey).value.toString().startsWith(p),
    );
    await tapFirst(keyed('seas-tex:'));
    await tapFirst(keyed('seas-cover:'));
    await tapFirst(keyed('seas-page:'));
    expect(texture, startsWith('seas:'));
    expect(cover, startsWith('seas:'));
    expect(page, startsWith('seas:'));
    // The frame browser lists a Holidays & seasons category.
    final chip = find.widgetWithText(
      PrismChip,
      seasonalFrameCategory,
      skipOffstage: false,
    );
    await t.ensureVisible(chip);
    await t.pump(const Duration(milliseconds: 150));
    await t.tap(find.widgetWithText(PrismChip, seasonalFrameCategory));
    await t.pump(const Duration(milliseconds: 200));
    await tapFirst(find.byType(ScrapFramedImage));
    expect(frame, startsWith('seas:'));
    expect(t.takeException(), isNull);
  });
}
