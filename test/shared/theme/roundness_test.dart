import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';

Widget _themed(PrismShapes shapes, Widget child) => MaterialApp(
  theme: ThemeData(extensions: [shapes]),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('roundness follows Squared, Rounded and custom corners', () {
    expect(PrismShapes.rounded.roundness, 1);
    expect(PrismShapes.angular.roundness, 0);
    expect(
      PrismShapes.angular.copyWith(roundnessScale: 1).roundness,
      0,
      reason: 'Squared always wins',
    );
    const half = PrismShapes(
      cornerStyle: CornerStyle.rounded,
      roundnessScale: 0.5,
    );
    expect(half.radius(16), 8);
    expect(half.roundFor(60), BorderRadius.circular(15));
    expect(PrismShapes.angular.roundFor(60), BorderRadius.zero);
    expect(
      PrismShapes.rounded.roundFor(60).topLeft.x,
      greaterThanOrEqualTo(30),
    );
    expect(
      PrismShapes.angular.circleOrSquareBorder(),
      isA<RoundedRectangleBorder>(),
    );
  });

  testWidgets(
    'round stand-ins are square in Squared mode and round otherwise',
    (t) async {
      await t.pumpWidget(
        _themed(
          PrismShapes.angular,
          const PrismCircleAvatar(radius: 20, child: Text('A')),
        ),
      );
      expect(find.byType(CircleAvatar), findsNothing);
      final box = t.widget<Container>(
        find
            .descendant(
              of: find.byType(PrismCircleAvatar),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (box.decoration! as BoxDecoration).borderRadius,
        BorderRadius.zero,
      );

      await t.pumpWidget(
        _themed(
          PrismShapes.rounded,
          const PrismCircleAvatar(radius: 20, child: Text('A')),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(CircleAvatar), findsOneWidget);

      await t.pumpWidget(
        _themed(
          PrismShapes.angular,
          const SizedBox(
            width: 40,
            height: 40,
            child: PrismClipRound(child: ColoredBox(color: Colors.red)),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(ClipOval), findsNothing);
      expect(
        t.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
        BorderRadius.zero,
      );
    },
  );
}
