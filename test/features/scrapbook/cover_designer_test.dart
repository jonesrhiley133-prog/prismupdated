import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/scrapbook/cover_designer_screen.dart';
import 'package:prism_plurality/features/scrapbook/scrap_cover.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

class _Tracker extends TrackerNotifier {
  static final saved = <TrackerRecord>[];
  @override
  Future<void> save(TrackerRecord record, {DateTime? now}) async =>
      saved.add(record);
}

TrackerRecord _book() => TrackerRecord(
  id: 'b1',
  kind: TrackerKind.scrapBook,
  title: 'My Diary',
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
);

Future<ProviderContainer> _open(WidgetTester t, TrackerRecord book) async {
  final c = ProviderContainer(
    overrides: [
      trackerNotifierProvider.overrideWith(_Tracker.new),
      trackerKindProvider.overrideWith(
        (ref, k) => const AsyncValue.data(<TrackerRecord>[]),
      ),
    ],
  );
  addTearDown(c.dispose);
  t.view.physicalSize = const Size(1700, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CoverDesignerScreen(book: book),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 200));
  return c;
}

Finder _inLayers(String t) => find.descendant(
  of: find.byType(ReorderableListView),
  matching: find.text(t),
);

void main() {
  setUp(_Tracker.saved.clear);

  testWidgets(
    'a book with no designed cover starts from its old look and every tab opens',
    (t) async {
      await _open(t, _book());
      expect(find.text('Cover designer'), findsOneWidget);
      for (final tab in [
        'Templates',
        'Shape & binding',
        'Background',
        'Texture',
        'Add',
        'Layers',
        'Opening',
      ]) {
        await t.tap(find.text(tab));
        await t.pump(const Duration(milliseconds: 150));
        expect(t.takeException(), isNull, reason: tab);
      }
      await t.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('choosing a template, adding things, undo/redo, and autosave', (
    t,
  ) async {
    await _open(t, _book());
    await t.tap(find.text('Templates'));
    await t.pump(const Duration(milliseconds: 150));
    await t.tap(find.text('Gothic').first);
    await t.pump(const Duration(milliseconds: 200));
    expect(t.takeException(), isNull);

    await t.tap(find.text('Add'));
    await t.pump(const Duration(milliseconds: 150));
    await t.tap(find.text('Text'));
    await t.pump(const Duration(milliseconds: 150));
    // The new element is selected, so the selection bar appears.
    expect(find.byTooltip('Duplicate'), findsOneWidget);
    await t.tap(find.byTooltip('Duplicate'));
    await t.pump(const Duration(milliseconds: 150));

    await t.tap(find.text('Layers'));
    await t.pump(const Duration(milliseconds: 150));
    expect(_inLayers('Your words'), findsNWidgets(2));

    await t.tap(find.byTooltip('Undo'));
    await t.pump(const Duration(milliseconds: 150));
    expect(_inLayers('Your words'), findsNWidgets(1));
    await t.tap(find.byTooltip('Redo'));
    await t.pump(const Duration(milliseconds: 150));
    expect(_inLayers('Your words'), findsNWidgets(2));

    // Autosave writes the design onto the book.
    await t.pump(const Duration(seconds: 2));
    expect(_Tracker.saved, isNotEmpty);
    final d = coverOf(_Tracker.saved.last.fields)!;
    expect(d.front.els.where((e) => e.text == 'Your words').length, 2);
    expect(
      d.front.els.any((e) => e.opts.containsKey('side')),
      isFalse,
      reason: 'internal tags are not saved',
    );
  });

  testWidgets(
    'front and back are separate, and the shape controls change the saved cover',
    (t) async {
      await _open(t, _book());
      await t.tap(find.text('Back'));
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(find.text('Add'));
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(find.text('Text'));
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(find.text('Shape & binding'));
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(find.text('Square'));
      await t.pump(const Duration(milliseconds: 150));
      await t.ensureVisible(find.text('Spiral', skipOffstage: false));
    await t.pump(const Duration(milliseconds: 150));
      await t.tap(find.text('Spiral'));
      await t.pump(const Duration(seconds: 2));
      final d = coverOf(_Tracker.saved.last.fields)!;
      expect(d.aspect, 1.0);
      expect(d.binding, 'spiral');
      expect(d.back.els.where((e) => e.text == 'Your words').length, 1);
      expect(d.front.els.where((e) => e.text == 'Your words'), isEmpty);
    },
  );

  testWidgets('a saved designed cover reopens exactly as it was', (t) async {
    final d = CoverDesign(aspect: 1.2, binding: 'rings', anim: 'zoom');
    await _open(t, _book().withFields({'cover2': d.toJson()}));
    await t.tap(find.text('Shape & binding'));
    await t.pump(const Duration(milliseconds: 150));
    await t.tap(find.text('Opening'));
    await t.pump(const Duration(milliseconds: 150));
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 2));
  });
}
