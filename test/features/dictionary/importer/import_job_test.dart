import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/dictionary/importer/import_job.dart';
import 'package:prism_plurality/features/dictionary/importer/wiki_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

class _Repo implements EntityRepository<TrackerRecord> {
  final rows = <TrackerRecord>[];
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

class _FakeWork extends BackgroundWorkPlatform {
  final updates = <String>[];
  final finishes = <String?>[];
  @override
  Future<void> update({required String title, required String text, int progress = 0, int max = 0}) async => updates.add('$title|$progress/$max');
  @override
  Future<void> finish({String? title, String? text}) async => finishes.add(title);
}

/// A pride-wiki-like MediaWiki: [pages] articles, each with a main flag,
/// two alternate flags and an unrelated icon.
class _FakeWiki {
  _FakeWiki(this.pages);
  final int pages;
  int requests = 0;
  int articleRequests = 0;
  Completer<void>? gate; // blocks article batches while set

  String title(int i) => 'Term $i';

  Future<http.Response> handle(http.Request req) async {
    requests++;
    final q = req.url.queryParameters;
    if (q['meta'] == 'siteinfo') return http.Response(jsonEncode({'query': {'general': {}}}), 200);
    if (q['list'] == 'allpages') {
      final start = int.tryParse(q['apcontinue'] ?? '0') ?? 0;
      final end = (start + 500).clamp(0, pages);
      return http.Response(jsonEncode({
        'query': {'allpages': [for (var i = start; i < end; i++) {'title': title(i)}]},
        if (end < pages) 'continue': {'apcontinue': '$end'},
      }), 200);
    }
    if (q['prop'] == 'imageinfo') {
      final files = q['titles']!.split('|');
      return http.Response(jsonEncode({
        'query': {'pages': [for (final f in files) {'title': f, 'imageinfo': [{'url': 'https://img.test/${Uri.encodeComponent(f)}'}]}]},
      }), 200);
    }
    if (q['prop']?.contains('extracts') == true) {
      articleRequests++;
      if (gate != null) await gate!.future;
      final titles = q['titles']!.split('|');
      return http.Response(jsonEncode({
        'query': {
          'pages': [
            for (final t in titles)
              {
                'title': t,
                'extract': '$t is a test term.\n\nMore.',
                'fullurl': 'https://wiki.test/wiki/${t.replaceAll(' ', '_')}',
                'categories': [{'title': 'Category:Identities'}],
                'pageimage': '${t.replaceAll(' ', '_')}_flag.png',
                'original': {'source': 'https://img.test/main/$t.png'},
                'images': [
                  {'title': 'File:${t.replaceAll(' ', '_')}_flag.png'},
                  {'title': 'File:${t.replaceAll(' ', '_')}_alt_flag.svg'},
                  {'title': 'File:${t.replaceAll(' ', '_')} alternate flag 2.png'},
                  {'title': 'File:Wiki_icon.png'},
                ],
              },
          ],
        },
      }), 200);
    }
    return http.Response('nope', 404);
  }
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('prism_import_job'));
  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer container(_FakeWiki wiki, _Repo repo, _FakeWork work) {
    final c = ProviderContainer(
      overrides: [
        trackerRecordRepositoryProvider.overrideWithValue(repo),
        wikiHttpProvider.overrideWithValue(WikiHttp(client: MockClient(wiki.handle), gap: Duration.zero)),
        backgroundWorkPlatformProvider.overrideWithValue(work),
        importJobFileProvider.overrideWithValue(() async => File('${dir.path}/job.json')),
      ],
    );
    c.listen(trackerRecordsProvider, (_, _) {});
    c.listen(importJobProvider, (_, _) {});
    return c;
  }

  Future<void> until(bool Function() cond) async {
    for (var i = 0; i < 400 && !cond(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cond(), isTrue);
  }

  test('flag files: main and alternates, not icons', () {
    expect(looksLikeFlagFile('File:Lesbian_flag.png'), isTrue);
    expect(looksLikeFlagFile('File:Alt flag 2.svg'), isTrue);
    expect(looksLikeFlagFile('File:Pride_flag_icon.png'), isFalse);
    expect(looksLikeFlagFile('File:Wiki_logo.png'), isFalse);
    expect(looksLikeFlagFile('File:Flag.pdf'), isFalse);
    expect(flagLabel('File:Lesbian_alt_flag_2.png'), 'Lesbian alt flag 2');
    final a = WikiArticle(title: 'X', content: 'y', flags: const [WikiFlag('https://a/b.png', 'X flag')], categories: const ['C']);
    final back = WikiArticle.fromJson(a.toJson());
    expect((back.title, back.flags.single.url, back.flags.single.label), ('X', 'https://a/b.png', 'X flag'));
    expect(back.categories, ['C']);
  });

  test('batch fetching: 20 per request, with every flag', () async {
    final wiki = _FakeWiki(45);
    final h = WikiHttp(client: MockClient(wiki.handle), gap: Duration.zero);
    final (p, r) = await detectProvider(h, 'https://wiki.test/wiki/Main_Page');
    expect(r.scope, WikiScope.wholeWiki);
    final titles = await p.listTitles(h, r, limit: wikiNoLimit);
    expect(titles, hasLength(45));
    final got = await p.fetchArticles(h, r, titles.take(20).toList());
    expect(got, hasLength(20));
    expect(wiki.articleRequests, 1, reason: 'one request for 20 articles');
    final flags = got.first.flags;
    expect(flags.map((f) => f.label), ['Term 0 flag', 'Term 0 alt flag', 'Term 0 alternate flag 2']);
    expect(flags.first.url, startsWith('https://img.test/'));
  });

  test('"All" lists every page across continuation', () async {
    final wiki = _FakeWiki(1234);
    final h = WikiHttp(client: MockClient(wiki.handle), gap: Duration.zero);
    final (p, r) = await detectProvider(h, 'https://wiki.test/wiki/Main_Page');
    expect(await p.listTitles(h, r, limit: wikiNoLimit), hasLength(1234));
    expect(await p.listTitles(h, r, limit: 200), hasLength(200));
  });

  test('a whole-wiki job runs in the background and adds terms with flags', () async {
    final wiki = _FakeWiki(65);
    final repo = _Repo();
    final work = _FakeWork();
    final c = container(wiki, repo, work);
    addTearDown(c.dispose);
    final n = c.read(importJobProvider.notifier);
    await n.ready();
    await n.detect('https://wiki.test/wiki/Main_Page');
    n.setOptions((o) => o.limit = wikiNoLimit);
    await n.listAndFetch();
    expect(n.job.status, ImportJobStatus.done);
    final terms = repo.rows.where((r) => r.kind == TrackerKind.dictTerm).toList();
    expect(terms, hasLength(65));
    final flags = terms.firstWhere((t) => t.title == 'Term 3').fields['flags'] as List;
    expect(flags, hasLength(3), reason: 'main flag + two alternates');
    expect(repo.rows.where((r) => r.kind == TrackerKind.dictImport).single.integer('imported'), 65);
    expect(wiki.articleRequests, 4, reason: '65 articles in batches of 20');
    // Progress notification while running, then a finished notification.
    expect(work.updates, isNotEmpty);
    expect(work.finishes.last, 'Dictionary import finished');
    // The job is saved to disk.
    final saved = jsonDecode(File('${dir.path}/job.json').readAsStringSync()) as Map;
    expect(saved['status'], 'done');
  });

  test('an interrupted import resumes by itself when Prism starts again', () async {
    final wiki = _FakeWiki(70)..gate = Completer<void>();
    final repo = _Repo();
    final c1 = container(wiki, repo, _FakeWork());
    final n1 = c1.read(importJobProvider.notifier);
    await n1.ready();
    await n1.detect('https://wiki.test/wiki/Main_Page');
    n1.setOptions((o) {
      o.limit = wikiNoLimit;
      o.autoImport = false;
    });
    unawaited(n1.listAndFetch());
    // Let the first batch through, then "kill" the app mid-import.
    await until(() => wiki.articleRequests == 1);
    final firstGate = wiki.gate!;
    wiki.gate = Completer<void>();
    firstGate.complete();
    await until(() => n1.job.next == 20 && wiki.articleRequests == 2);
    // Force a save of the current state, as the periodic save would.
    n1.edited();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    c1.dispose();
    final saved = jsonDecode(File('${dir.path}/job.json').readAsStringSync()) as Map;
    expect(saved['status'], 'fetching');
    expect(saved['next'], 20);

    // Prism starts again: the job loads and continues on its own.
    wiki.gate!.complete();
    wiki.gate = null;
    final c2 = container(wiki, repo, _FakeWork());
    addTearDown(c2.dispose);
    final n2 = c2.read(importJobProvider.notifier);
    await n2.ready();
    await until(() => n2.job.status == ImportJobStatus.ready);
    expect(n2.job.items, hasLength(70));
    expect(n2.job.items.first.a.flags, hasLength(3));
    // Review mode (auto-import off): nothing is added until Import.
    expect(repo.rows.where((r) => r.kind == TrackerKind.dictTerm), isEmpty);
    n2.select(n2.job.items.first, false);
    final r = await n2.importNow();
    expect(r!.created, 69);
  });

  test('pause keeps the place; resume finishes', () async {
    final wiki = _FakeWiki(60)..gate = Completer<void>();
    final repo = _Repo();
    final c = container(wiki, repo, _FakeWork());
    addTearDown(c.dispose);
    final n = c.read(importJobProvider.notifier);
    await n.ready();
    await n.detect('https://wiki.test/wiki/Main_Page');
    n.setOptions((o) => o.limit = wikiNoLimit);
    final run = n.listAndFetch();
    await until(() => wiki.articleRequests == 1);
    n.pause();
    wiki.gate!.complete();
    wiki.gate = null;
    await run;
    expect(n.job.status, ImportJobStatus.paused);
    expect(n.job.next, 20);
    await n.resume();
    expect(n.job.status, ImportJobStatus.done);
    expect(repo.rows.where((r) => r.kind == TrackerKind.dictTerm), hasLength(60));
  });
}
