import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/scrapbook/scrap_sticker_view.dart';
import 'package:prism_plurality/features/scrapbook/scrap_stickers.dart';

void main() {
  test(
    '500+ unique stickers across all 23 categories, each category stocked',
    () {
      expect(scrapStickers.length, greaterThanOrEqualTo(500));
      expect(scrapStickerCategories.length, 23);
      expect(
        scrapStickers.map((s) => s.id).toSet().length,
        scrapStickers.length,
      );
      for (final c in scrapStickerCategories) {
        expect(stickersIn(c).length, greaterThanOrEqualTo(20), reason: c);
      }
      for (final s in scrapStickers) {
        expect(scrapStickerCategories, contains(s.category), reason: s.id);
        expect(s.name, isNotEmpty);
        expect(s.data, isNotEmpty);
      }
    },
  );

  test('search finds by name and category', () {
    expect(scrapStickers.where((s) => s.matches('strawberry')), isNotEmpty);
    expect(scrapStickers.where((s) => s.matches('pixel')), isNotEmpty);
    expect(
      scrapStickers.where((s) => s.matches('')).length,
      scrapStickers.length,
    );
  });

  testWidgets('every kind draws', (tester) async {
    for (final kind in StickerKind.values) {
      final s = scrapStickers.firstWhere((s) => s.kind == kind);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(width: 80, height: 80, child: ScrapStickerView(s)),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: s.id);
    }
  });
}
