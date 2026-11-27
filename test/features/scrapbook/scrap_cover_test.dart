import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/scrapbook/scrap_cover.dart';
import 'package:prism_plurality/features/scrapbook/scrap_cover_templates.dart';
import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/scrapbook/scrap_stickers.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';

Widget _host(Widget child) => ProviderScope(
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Center(child: child),
    ),
  ),
);

void main() {
  test(
    'templates reference only things that exist, and round-trip through JSON',
    () {
      expect(coverTemplates.length, greaterThanOrEqualTo(12));
      expect(
        coverTemplates.map((t) => t.id).toSet().length,
        coverTemplates.length,
      );
      for (final t in coverTemplates) {
        final d = t.build();
        for (final face in [d.front, d.back]) {
          if (face.base == 'material')
            expect(scrapTextureById(face.material), isNotNull, reason: t.id);
          if (face.overlay.id != 'plain')
            expect(
              scrapTextureById(face.overlay.id),
              isNotNull,
              reason: '${t.id} overlay',
            );
          for (final e in face.els) {
            if (e.type == ScrapType.sticker)
              expect(
                scrapStickerById(e.text!),
                isNotNull,
                reason: '${t.id} ${e.text}',
              );
            final fr = e.opts['fr2'];
            if (fr is String)
              expect(scrapFrameById(fr), isNotNull, reason: t.id);
          }
        }
        expect(coverAnimations, contains(d.anim));
        expect(coverBindings, contains(d.binding));
        final back = CoverDesign.fromJson(d.toJson())!;
        expect(back.toJson(), d.toJson(), reason: t.id);
      }
    },
  );

  test('corrupt saved covers load safely or not at all', () {
    expect(CoverDesign.fromJson(null), isNull);
    expect(CoverDesign.fromJson({'v': 2}), isNull);
    final d = CoverDesign.fromJson({
      'v': 1,
      'ar': 99,
      'th': -3,
      'co': 'x',
      'bi': 'bogus',
      'an': 'bogus',
      'f': 5,
      'k': {
        'b': 'weird',
        'g': [1],
      },
    })!;
    expect(d.aspect, CoverDesign.maxAspect);
    expect(d.thickness, 0);
    expect(d.binding, 'spine');
    expect(d.anim, 'swing');
    expect(d.back.base, 'color');
    expect(d.back.gradient.length, 2);
  });

  test('12 opening animations, 8 bindings, 30+ materials to pick from', () {
    expect(coverAnimations.length, greaterThanOrEqualTo(12));
    expect(coverBindings.length, greaterThanOrEqualTo(8));
    expect(scrapMaterials.length, greaterThanOrEqualTo(30));
  });

  test('title and subtitle placeholders fill in', () {
    final d = coverTemplateById('leather')!.build();
    final els = ScrapCoverView.resolved(d.front, 'Dreams', 'Vol. 1');
    expect(els.where((e) => e.text == 'Dreams'), isNotEmpty);
    expect(els.where((e) => e.text == 'Vol. 1'), isNotEmpty);
    expect(
      d.front.els.any((e) => e.text == '{title}'),
      isTrue,
      reason: 'the design keeps the placeholder',
    );
  });

  testWidgets(
    'every template draws front and back, with every binding, at odd sizes',
    (tester) async {
      for (final t in coverTemplates) {
        for (final back in [false, true]) {
          await tester.pumpWidget(
            _host(
              SizedBox(
                width: 180,
                child: ScrapCoverView(
                  design: t.build(),
                  title: 'Title',
                  subtitle: 'Sub',
                  back: back,
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: t.id);
        }
      }
      for (final b in coverBindings.keys) {
        final d = coverTemplateById('leather')!.build()
          ..binding = b
          ..aspect = 1.6
          ..thickness = 1;
        await tester.pumpWidget(
          _host(SizedBox(width: 300, child: ScrapCoverView(design: d))),
        );
        expect(tester.takeException(), isNull, reason: b);
      }
    },
  );

  testWidgets('every opening animation plays to the end and calls back once', (
    tester,
  ) async {
    for (final a in coverAnimations.keys.where((k) => k != 'none')) {
      var done = 0;
      final d = coverTemplateById('leather')!.build()..anim = a;
      await tester.pumpWidget(
        _host(
          ScrapCoverOpening(
            key: ValueKey(a),
            design: d,
            title: 'T',
            subtitle: '',
            onDone: () => done++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));
      expect(done, 1, reason: a);
      expect(tester.takeException(), isNull, reason: a);
    }
  });
}
