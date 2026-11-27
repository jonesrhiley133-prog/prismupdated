import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';

void main() {
  test('100+ unique frames in the listed categories', () {
    expect(scrapFrames.length, greaterThanOrEqualTo(100));
    expect(scrapFrames.map((f) => f.id).toSet().length, scrapFrames.length);
    for (final f in scrapFrames) {
      expect(scrapFrameCategories, contains(f.category), reason: f.id);
      expect(
        f.inner(const Size(200, 200)).width,
        greaterThan(50),
        reason: f.id,
      );
    }
    expect(scrapFrameById('polaroid'), isNotNull);
  });

  test('fit settings stay in range and round-trip', () {
    final f = const ScrapImageFit(zoom: 99, dx: -5, dy: 0.3).clamped();
    expect(f.zoom, 6);
    expect(f.dx, -1);
    expect(ScrapImageFit.fromJson(f.toJson()).dy, 0.3);
    expect(ScrapImageFit.fromJson('x').zoom, 1);
  });

  testWidgets('every frame masks a non-square picture without stretching it', (
    tester,
  ) async {
    for (final f in scrapFrames) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 160,
              height: 200,
              child: ScrapFramedImage(
                frame: f,
                fit: const ScrapImageFit(zoom: 2, dx: 0.5),
                child: const FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: 400,
                    height: 100,
                    child: ColoredBox(color: Colors.teal),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: f.id);
    }
  });
}
