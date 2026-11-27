import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/scrapbook/scrap_editor.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/scrapbook/scrap_page.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

class _Tracker extends TrackerNotifier {
  static final saved = <TrackerRecord>[];
  static final created = <(String, String, Map<String, Object?>)>[];
  @override
  Future<void> save(TrackerRecord record, {DateTime? now}) async =>
      saved.add(record);
  @override
  Future<TrackerRecord> create({
    required String kind,
    String title = '',
    String? body,
    String? parentId,
    Map<String, Object?> fields = const {},
    List<String> tags = const [],
    DateTime? occurredAt,
    DateTime? endedAt,
    int? amount,
    String? memberId,
    bool isPrivate = false,
    bool isPinned = false,
    int sortOrder = 0,
    DateTime? now,
  }) async {
    created.add((kind, title, fields));
    return TrackerRecord(
      id: 'new',
      kind: kind,
      title: title,
      createdAt: DateTime(2026),
      modifiedAt: DateTime(2026),
    ).withFields(fields);
  }
}

final _book = TrackerRecord(
  id: 'b',
  kind: TrackerKind.scrapBook,
  title: 'Book',
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
);

Future<void> _open(WidgetTester t, {TrackerRecord? page}) async {
  final c = ProviderContainer(
    overrides: [
      trackerNotifierProvider.overrideWith(_Tracker.new),
      trackerKindProvider.overrideWith(
        (ref, k) => const AsyncValue.data(<TrackerRecord>[]),
      ),
    ],
  );
  addTearDown(c.dispose);
  t.view.physicalSize = const Size(900, 1300);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScrapPageEditor(
          book: _book,
          page:
              page ??
              TrackerRecord(
                id: 'p',
                kind: TrackerKind.scrapPage,
                title: '',
                parentId: 'b',
                createdAt: DateTime(2026),
                modifiedAt: DateTime(2026),
              ),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    _Tracker.saved.clear();
    _Tracker.created.clear();
  });

  testWidgets(
    'adding things, multi-select group, undo/redo, and autosave to the page',
    (t) async {
      await _open(t);
      await t.tap(find.text('Text').first);
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(find.byTooltip('Duplicate'));
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(find.byTooltip('Select all'));
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(find.byTooltip('Group'));
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(find.byTooltip('Lock'));
      await t.pump(const Duration(milliseconds: 150));
      await t.tap(find.byTooltip('Undo'));
      await t.pump(const Duration(milliseconds: 150));
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 2));
      expect(_Tracker.saved, isNotEmpty);
      final els = elementsOf(_Tracker.saved.last);
      expect(els.length, 2);
      expect(els.map((e) => e.group).toSet().length, 1, reason: 'grouped');
      expect(els.any((e) => e.locked), isFalse, reason: 'the lock was undone');
    },
  );

  testWidgets(
    'page settings: every tab opens, and size, spread and transition are saved',
    (t) async {
      await _open(t);
      await t.tap(find.byTooltip('Page settings'));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 900));
      for (final tab in [
        'Texture',
        'Size',
        'Transition',
        'Templates',
        'Background',
      ]) {
        await t.ensureVisible(find.text(tab, skipOffstage: false).last);
        await t.pump(const Duration(milliseconds: 150));
        await t.tap(find.text(tab).last);
        await t.pump(const Duration(milliseconds: 200));
        expect(t.takeException(), isNull, reason: tab);
      }
      await t.tap(find.text('Size').last);
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Square'));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Two-page spread'));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Transition').last);
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Cube'));
      await t.pump(const Duration(seconds: 2));
      final f = _Tracker.saved.last.fields;
      expect(f['asp'], 1.0);
      expect(f['spr'], true);
      expect(f['trn'], 'cube');
    },
  );

  testWidgets(
    'a template replaces the page, undo brings the old page back, and templates can be saved',
    (t) async {
      final page =
          TrackerRecord(
            id: 'p',
            kind: TrackerKind.scrapPage,
            title: '',
            createdAt: DateTime(2026),
            modifiedAt: DateTime(2026),
          ).withFields({
            'els': [
              ScrapElement(
                type: ScrapType.text,
                text: 'mine',
                x: 0.1,
                y: 0.1,
                w: 0.5,
                h: 0.1,
              ).toJson(),
            ],
          });
      await _open(t, page: page);
      expect(find.text('mine'), findsOneWidget);
      await t.tap(find.byTooltip('Page settings'));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 900));
      await t.ensureVisible(find.text('Templates', skipOffstage: false).last);
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Templates').last);
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Four photos'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('mine'), findsNothing);
      await t.tap(find.byTooltip('Undo'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('mine'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'a page saved with a texture, gradient and spread reopens exactly so',
    (t) async {
      final s = ScrapPageStyle(
        color2: 0xFF223344,
        texture: const ScrapTextureStyle(id: 'cl-denim'),
        spread: true,
      );
      await _open(
        t,
        page: TrackerRecord(
          id: 'p',
          kind: TrackerKind.scrapPage,
          title: '',
          createdAt: DateTime(2026),
          modifiedAt: DateTime(2026),
        ).withFields(s.toFields()),
      );
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 2));
    },
  );
}
