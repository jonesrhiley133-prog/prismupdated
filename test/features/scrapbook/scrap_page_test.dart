import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/scrapbook/scrap_page.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';
import 'package:prism_plurality/features/scrapbook/scrap_washi.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

TrackerRecord _book([Map<String, Object?> f = const {}]) => TrackerRecord(
  id: 'b',
  kind: TrackerKind.scrapBook,
  title: 'B',
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
).withFields(f);
TrackerRecord _page([Map<String, Object?> f = const {}]) => TrackerRecord(
  id: 'p',
  kind: TrackerKind.scrapPage,
  title: '',
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
).withFields(f);

void main() {
  test('page style falls back from the page to the book to the theme', () {
    final theme = themeById('classic').$5;
    expect(ScrapPageStyle.of(_book(), _page()).color, theme);
    expect(
      ScrapPageStyle.of(_book({'pageColor': 0xFF112233}), _page()).color,
      0xFF112233,
    );
    expect(
      ScrapPageStyle.of(
        _book({'pageColor': 0xFF112233}),
        _page({'bg': 0xFF445566}),
      ).color,
      0xFF445566,
    );
    expect(
      ScrapPageStyle.of(_book({'pattern': 'dots'}), _page()).pattern,
      'dots',
    );
  });

  test(
    'a style survives saving and loading, and tidy defaults are not stored',
    () {
      final s = ScrapPageStyle(
        color: 0xFFAABBCC,
        color2: 0xFF001122,
        angle: 30,
        pattern: 'grid',
        texture: const ScrapTextureStyle(
          id: 'cl-linen',
          opacity: 0.5,
          blend: 'multiply',
        ),
        aspect: 1.4,
        spread: true,
        transition: 'cube',
      );
      final back = ScrapPageStyle.of(_book(), _page(s.toFields()));
      expect(back.color2, 0xFF001122);
      expect(back.texture.id, 'cl-linen');
      expect(back.texture.blend, 'multiply');
      expect(back.aspect, 1.4);
      expect(back.spread, isTrue);
      expect(back.transition, 'cube');
      expect(back.drawnAspect, closeTo(2.8, 1e-9));
      final plain = ScrapPageStyle().toFields();
      expect(plain['tex'], isNull);
      expect(plain['asp'], isNull);
      expect(plain['spr'], isNull);
      expect(plain['trn'], isNull);
      expect(ScrapPageStyle.fromJson(s.toJson()).toJson(), s.toJson());
    },
  );

  test('damaged page settings never crash', () {
    final s = ScrapPageStyle.of(
      _book(),
      _page({
        'asp': 'wide',
        'trn': 'bogus',
        'tex': 7,
        'spr': 'yes',
        'ga': null,
      }),
    );
    expect(s.aspect, scrapPageAspect);
    expect(s.transition, 'slide');
    expect(s.texture.id, 'plain');
    expect(s.spread, isFalse);
    expect(
      ScrapPageStyle.of(_book(), _page({'asp': 99})).aspect,
      ScrapPageStyle.maxAspect,
    );
  });

  test(
    'every built-in template builds fresh elements that exist in the catalogs',
    () {
      expect(builtInPageTemplates.length, greaterThanOrEqualTo(8));
      expect(
        builtInPageTemplates.map((t) => t.id).toSet().length,
        builtInPageTemplates.length,
      );
      for (final t in builtInPageTemplates) {
        final a = t.build(), b = t.build();
        if (a.els.isNotEmpty)
          expect(
            a.els.first.id,
            isNot(b.els.first.id),
            reason: '${t.id} shares elements',
          );
        for (final e in a.els) {
          final fr = e.opts['fr2'];
          if (fr is String)
            expect(scrapFrameById(fr), isNotNull, reason: '${t.id}: $fr');
          final wp = e.opts['wp'];
          if (wp is String)
            expect(washiById(wp), isNotNull, reason: '${t.id}: $wp');
        }
      }
    },
  );

  test('9 transitions, 25+ washi patterns', () {
    expect(scrapTransitions.length, greaterThanOrEqualTo(9));
    expect(washiPatterns.length, greaterThanOrEqualTo(25));
    expect(washiPatterns.map((w) => w.id).toSet().length, washiPatterns.length);
  });

  testWidgets('every transition and every washi pattern draws', (t) async {
    for (final k in scrapTransitions.keys) {
      for (final d in [-1.0, -0.4, 0.0, 0.6, 1.0]) {
        await t.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: scrapPageTransition(
              k,
              const SizedBox(width: 100, height: 140),
              d,
            ),
          ),
        );
        expect(t.takeException(), isNull, reason: '$k $d');
      }
    }
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(
          children: [
            for (final w in washiPatterns)
              SizedBox(
                width: 120,
                height: 30,
                child: CustomPaint(painter: WashiPainter(w)),
              ),
          ],
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('a spread page is drawn twice as wide with the fold', (t) async {
    await t.pumpWidget(
      ProviderScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Center(
              child: SizedBox(
                width: 600,
                child: ScrapPageView(
                  book: _book(),
                  page: _page({'spr': true, 'asp': 0.7}),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final size = t.getSize(find.byType(ScrapPageBackdrop));
    expect(size.width / size.height, closeTo(1.4, 0.01));
  });
}
