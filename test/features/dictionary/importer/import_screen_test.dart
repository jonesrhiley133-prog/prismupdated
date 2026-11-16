import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/dictionary/importer/import_job.dart';
import 'package:prism_plurality/features/dictionary/importer/universal_import_screen.dart';
import 'package:prism_plurality/features/dictionary/importer/wiki_providers.dart';
import 'package:prism_plurality/features/dictionary/views/dictionary_screen.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

class _Repo implements EntityRepository<TrackerRecord> {
  _Repo(this.rows);
  final List<TrackerRecord> rows;
  @override
  Stream<List<TrackerRecord>> watchAll() async* {
    yield [...rows];
  }

  @override
  Future<List<TrackerRecord>> getAll() async => [...rows];
  @override
  Future<TrackerRecord?> getById(String id) async => rows.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> create(TrackerRecord item) async => rows.add(item);
  @override
  Future<void> update(TrackerRecord item) async => rows[rows.indexWhere((r) => r.id == item.id)] = item;
  @override
  Future<void> delete(String id) async => rows.removeWhere((r) => r.id == id);
}

Widget _app(Widget home, _Repo repo, Directory dir) => ProviderScope(
  overrides: [
    trackerRecordRepositoryProvider.overrideWithValue(repo),
    importJobFileProvider.overrideWithValue(() async => File('${dir.path}/job.json')),
    backgroundWorkPlatformProvider.overrideWithValue(const BackgroundWorkPlatform()),
  ],
  child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: const [Locale('en')], home: home),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('prism_import_ui'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('3000 fetched terms: lazy list, Import pinned at top, jump to bottom', (t) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const UniversalImportScreen(), _Repo([]), dir));
    await _settle(t);
    final container = ProviderScope.containerOf(t.element(find.byType(UniversalImportScreen)));
    container.read(importJobProvider.notifier).addArticles([
      for (var i = 0; i < 3000; i++) WikiArticle(title: 'Term ${i.toString().padLeft(4, '0')}', content: 'Definition $i', flags: i.isEven ? const [WikiFlag('https://x/a.png', 'A flag'), WikiFlag('https://x/b.png', 'Alt flag')] : const []),
    ], label: 'Test wiki');
    await _settle(t);

    expect(find.text('Import 3000'), findsOneWidget);
    expect(find.text('3000 of 3000 selected'), findsOneWidget);
    // Only visible rows are built.
    expect(find.textContaining('Term 0').evaluate().length, lessThan(40));
    expect(find.text('Term 2999'), findsNothing);
    expect(find.textContaining('2 flags'), findsWidgets);

    // Scroll a little: the Import bar stays pinned at the top.
    await t.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await _settle(t);
    expect(find.text('Import 3000'), findsOneWidget);
    // Jump to the very end.
    await t.tap(find.bySemanticsLabel('Jump to bottom'));
    await _settle(t);
    expect(find.text('Term 2999'), findsOneWidget);
    expect(find.text('Import 3000'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Jump to top'));
    await _settle(t);
    expect(find.text('Term 0000'), findsOneWidget);
  });

  testWidgets('a term shows its main and alternate flags with download', (t) async {
    final now = DateTime(2026);
    final term = TrackerRecord(id: 't1', kind: TrackerKind.dictTerm, title: 'Lesbian', body: 'An identity.', createdAt: now, modifiedAt: now).withFields({
      'flags': [
        {'url': 'https://img.test/Lesbian_flag.png', 'label': 'Lesbian flag'},
        {'url': 'https://img.test/Lesbian_alt_flag.png', 'label': 'Lesbian alt flag'},
        {'url': 'https://img.test/Labrys_flag.svg', 'label': 'Labrys flag'},
      ],
    });
    await t.pumpWidget(_app(const Scaffold(body: TermDetailSheet(termId: 't1')), _Repo([term]), dir));
    await _settle(t);
    expect(find.text('Flags · 3'), findsOneWidget);
    expect(find.text('Download all'), findsOneWidget);
    expect(find.text('★ Lesbian flag'), findsOneWidget);
    expect(find.text('Lesbian alt flag'), findsOneWidget);
    expect(find.text('Labrys flag'), findsOneWidget);
  });
}
