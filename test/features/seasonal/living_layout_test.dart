import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/layouts_screen.dart';
import 'package:prism_plurality/features/seasonal/living_layout.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/theme/layout_decor.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

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

Widget _app(Widget child, {LayoutDecorData? decor}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: LayoutDecor(
    data: decor,
    child: Scaffold(body: child),
  ),
);

bool _hasLine(WidgetTester t) => t
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .any((c) => c.painter is LayoutLinePainter);

void main() {
  final v = variationById('cottagecore.3')!;

  test('every living look has a layout in a known line style', () {
    const styles = {
      'dotted',
      'scallop',
      'zigzag',
      'double',
      'stitched',
      'vine',
      'lace',
      'ornate',
      'hairline',
      'mkeka',
      'frost',
    };
    for (final c in livingCollections) {
      for (final x in c.variations) {
        final d = layoutDecorFor(x, LayoutPart.all.toSet());
        expect(styles, contains(d.line));
        expect(d.motif, isNotEmpty);
        expect(d.corner, isNotEmpty);
      }
    }
  });

  test('layout choice and parts are saved, separate from the living look', () {
    final p = const SeasonalPrefs().copyWith(
      layoutVariation: 'cyberpunk.2',
      layoutParts: {LayoutPart.cards, LayoutPart.dividers},
    );
    final b = SeasonalPrefs.fromJson(p.toJson());
    expect(b.layoutVariation, 'cyberpunk.2');
    expect(b.layoutParts, {LayoutPart.cards, LayoutPart.dividers});
    expect(b.livingVariation, isNull);
    expect(
      SeasonalPrefs.fromJson(const SeasonalPrefs().toJson()).layoutParts,
      isNull,
    );
  });

  testWidgets('dividers and cards are decorated only when their part is on', (
    t,
  ) async {
    final page = Column(
      children: const [
        PrismSectionHeader(title: 'TITLE'),
        PrismSurface(child: Text('card')),
      ],
    );
    await t.pumpWidget(_app(page));
    expect(_hasLine(t), isFalse);
    expect(find.text(layoutDecorFor(v, {}).corner), findsNothing);

    await t.pumpWidget(
      _app(page, decor: layoutDecorFor(v, {LayoutPart.dividers})),
    );
    expect(_hasLine(t), isTrue);
    expect(find.text(v.icons.first), findsOneWidget);
    expect(find.byType(LayoutGlyph), findsOneWidget);

    await t.pumpWidget(
      _app(page, decor: layoutDecorFor(v, {LayoutPart.cards})),
    );
    expect(_hasLine(t), isFalse);
    expect(find.text(v.cornerEmoji.first), findsOneWidget);
    // The title and card text are untouched.
    expect(find.text('TITLE'), findsOneWidget);
    expect(find.text('card'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the header trim only shows when switched on', (t) async {
    const bar = PrismTopBar(title: 'Hello');
    await t.pumpWidget(_app(bar, decor: layoutDecorFor(v, {LayoutPart.cards})));
    expect(_hasLine(t), isFalse);
    await t.pumpWidget(
      _app(bar, decor: layoutDecorFor(v, {LayoutPart.header})),
    );
    expect(_hasLine(t), isTrue);
    expect(find.text('Hello'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('navigation and hanging parts add overlay decorations', () {
    final c = _container();
    addTearDown(c.dispose);
    c
        .read(seasonalPrefsProvider.notifier)
        .update(
          (p) => p.copyWith(
            performance: DecoPerformance.balanced,
            layoutVariation: v.id,
            layoutParts: {LayoutPart.nav},
          ),
        );
    final items = c.read(seasonalItemsProvider);
    expect(
      items.where(
        (i) => i.anchor == DecoAnchor.bottom && i.kind == DecoKind.garland,
      ),
      hasLength(1),
    );
    expect(items.where((i) => i.kind == DecoKind.ornament), isEmpty);
    expect(c.read(layoutDecorProvider)?.on(LayoutPart.nav), isTrue);
    expect(c.read(layoutDecorProvider)?.on(LayoutPart.cards), isFalse);
  });

  testWidgets('layouts screen switches parts and turns off with undo', (
    t,
  ) async {
    final c = _container();
    t.view.physicalSize = const Size(420, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    c
        .read(seasonalPrefsProvider.notifier)
        .update(
          (p) => p.copyWith(
            performance: DecoPerformance.balanced,
            layoutVariation: v.id,
          ),
        );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LayoutsScreen(),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    // Cottagecore names its parts its own way.
    expect(find.text('Floral dividers'), findsOneWidget);
    await t.tap(find.text('Floral dividers'));
    await t.pump(const Duration(milliseconds: 200));
    expect(
      c.read(seasonalPrefsProvider).layoutParts,
      isNot(contains(LayoutPart.dividers)),
    );
    await t.tap(find.text('Turn off'));
    await t.pump(const Duration(milliseconds: 200));
    expect(c.read(seasonalPrefsProvider).layoutVariation, isNull);
    await t.tap(find.text('Undo'));
    await t.pump(const Duration(milliseconds: 200));
    expect(c.read(seasonalPrefsProvider).layoutVariation, v.id);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
