import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decor_painter.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_overlay.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';

class _Prefs extends SeasonalPrefsNotifier {
  _Prefs(this.initial);
  final SeasonalPrefs initial;
  @override
  SeasonalPrefs build() => initial;

  // No database in these tests.
  @override
  Future<void> flush() async {}
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  final c = TextEditingController();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextField(controller: c, key: const Key('field')),
        ElevatedButton(
          onPressed: () => setState(() => n++),
          child: Text('count $n'),
        ),
      ],
    ),
  );
}

GoRouter _router() => GoRouter(
  routes: [GoRoute(path: '/', builder: (_, _) => const _Counter())],
);

Widget _app(
  GoRouter router,
  SeasonalPrefs prefs,
  List<DecorItem> items, {
  bool reduced = false,
}) => ProviderScope(
  overrides: [
    seasonalPrefsProvider.overrideWith(() => _Prefs(prefs)),
    seasonalItemsProvider.overrideWithValue(items),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: SeasonalOverlay(router: router, child: child!),
    ),
  ),
);

List<DecorItem> _look() =>
    arrangementForVariation(variationById('christmas.0')!);

void main() {
  testWidgets('when off, nothing is drawn and the app works normally', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(_app(router, const SeasonalPrefs(), _look()));
    await tester.pump();
    expect(
      find
          .byType(CustomPaint)
          .evaluate()
          .where((e) => (e.widget as CustomPaint).painter is DecorPainter),
      isEmpty,
    );
    await tester.tap(find.text('count 0'));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);
  });

  testWidgets('decorations draw over the app but never block it', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(
      _app(
        router,
        const SeasonalPrefs(performance: DecoPerformance.immersive),
        _look(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find
          .byType(CustomPaint)
          .evaluate()
          .where((e) => (e.widget as CustomPaint).painter is DecorPainter),
      isNotEmpty,
    );
    // Taps, typing and scrolling reach the app underneath.
    await tester.tap(find.text('count 0'));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('field')), 'hello');
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets(
    'turning Seasonal Living on and off never rebuilds the app or loses state',
    (tester) async {
      final router = _router();
      final container = ProviderContainer(
        overrides: [
          seasonalPrefsProvider.overrideWith(
            () => _Prefs(const SeasonalPrefs()),
          ),
          seasonalItemsProvider.overrideWithValue(_look()),
        ],
      );
      addTearDown(container.dispose);
      // Start off, type something and count, then switch on.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) =>
                SeasonalOverlay(router: router, child: child!),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('count 0'));
      await tester.enterText(find.byKey(const Key('field')), 'kept');
      await tester.pump();
      container
          .read(seasonalPrefsProvider.notifier)
          .update((p) => p.copyWith(performance: DecoPerformance.balanced));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('count 1'), findsOneWidget);
      expect(find.text('kept'), findsOneWidget);
      container
          .read(seasonalPrefsProvider.notifier)
          .update((p) => p.copyWith(performance: DecoPerformance.off));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('count 1'), findsOneWidget);
      expect(find.text('kept'), findsOneWidget);
      await tester.pump(
        const Duration(seconds: 1),
      ); // let the save delay finish
    },
  );

  testWidgets('reduced motion keeps decorations still', (tester) async {
    final router = _router();
    await tester.pumpWidget(
      _app(
        router,
        const SeasonalPrefs(performance: DecoPerformance.immersive),
        _look(),
        reduced: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    // Only the static layer is drawn; nothing is scheduling frames.
    final painters = [
      for (final e in find.byType(CustomPaint).evaluate())
        if ((e.widget as CustomPaint).painter is DecorPainter)
          (e.widget as CustomPaint).painter as DecorPainter,
    ];
    expect(painters.length, 1);
    expect(painters.single.layersToDraw, {DecoLayer.staticDeco});
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'the interactive toy responds to a tap without disturbing anything else',
    (tester) async {
      final router = _router();
      final toy = DecorItem(
        id: 'toy',
        kind: DecoKind.interactive,
        glyph: '🎃',
        variationId: 'halloween.0',
        anchor: DecoAnchor.topRight,
        x: 0.5,
        y: 0.5,
        w: 0.3,
      );
      await tester.pumpWidget(
        _app(
          router,
          const SeasonalPrefs(performance: DecoPerformance.immersive),
          [toy],
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('🎃'), findsOneWidget);
      await tester.tap(find.text('🎃'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('😈'), findsOneWidget);
      // And the app's own button still works.
      await tester.tap(find.text('count 0'));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);
    },
  );

  testWidgets('interactive toys are hidden while the keyboard is up', (
    tester,
  ) async {
    final router = _router();
    final toy = DecorItem(
      id: 'toy',
      kind: DecoKind.interactive,
      glyph: '🎃',
      variationId: 'halloween.0',
      anchor: DecoAnchor.topRight,
      x: 0.5,
      y: 0.5,
      w: 0.3,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seasonalPrefsProvider.overrideWith(
            () => _Prefs(
              const SeasonalPrefs(performance: DecoPerformance.immersive),
            ),
          ),
          seasonalItemsProvider.overrideWithValue([toy]),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
            child: SeasonalOverlay(router: router, child: child!),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('🎃'), findsNothing);
  });
}
