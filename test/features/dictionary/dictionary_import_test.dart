import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/sync/prism_sync_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/dictionary/utils/dictionary_import.dart';
import 'package:prism_plurality/features/dictionary/views/dictionary_import_flow.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

void main() {
  group('file and text parsing', () {
    test('JSON list with synonyms, map, and nested key', () {
      final a = parseDictionaryText(
        '[{"word":"Front","meaning":"In control","category":"Roles","aliases":["fronter"]},{"name":"x"}]',
      );
      expect(a.first.term, 'Front');
      expect(a.first.definition, 'In control');
      expect(a.first.category, 'Roles');
      expect(a.first.aliases, ['fronter']);
      expect(a.last.error, 'missing_definition');
      final b = parseDictionaryText(
        '{"Host":"The main fronter","Little":"A child headmate"}',
      );
      expect(b.map((c) => c.term), ['Host', 'Little']);
      final c = parseDictionaryText(
        '{"glossary":[{"term":"Switch","definition":"Change of fronter"}]}',
      );
      expect(c.single.term, 'Switch');
    });

    test('CSV with header and quoted commas, TSV without header', () {
      final a = parseDictionaryText(
        'term,definition,category\n"Co-con","Aware, not fronting",States\nSplit,A new headmate,',
      );
      expect(a[0].definition, 'Aware, not fronting');
      expect(a[0].category, 'States');
      expect(a[1].category, isNull);
      final b = parseDictionaryText('Alpha\tFirst\nBeta\tSecond');
      expect(b.map((x) => x.term), ['Alpha', 'Beta']);
    });

    test('plain text in inline and block forms', () {
      final a = parseDictionaryText(
        'Fronting: in control\nHeadspace - inner world\nSystem = everyone',
      );
      expect(a.map((x) => (x.term, x.definition)), [
        ('Fronting', 'in control'),
        ('Headspace', 'inner world'),
        ('System', 'everyone'),
      ]);
      final b = parseDictionaryText(
        'Gatekeeper\nManages switches\nand memories.\n\nProtector\nKeeps the system safe.',
      );
      expect(b[0].definition, 'Manages switches and memories.');
      expect(b[1].term, 'Protector');
    });

    test(
      'duplicates match on term and aliases, case and spacing insensitive',
      () {
        final now = DateTime(2026);
        final existing = indexTerms([
          TrackerRecord(
            id: '1',
            kind: TrackerKind.dictTerm,
            title: 'Co-Fronting',
            createdAt: now,
            modifiedAt: now,
          ).withFields({
            DictField.aliases: ['cofront'],
          }),
        ]);
        expect(
          findDuplicateTerm(
            const TermCandidate(key: 'a', term: 'co-fronting '),
            existing,
          )?.id,
          '1',
        );
        expect(
          findDuplicateTerm(
            const TermCandidate(key: 'b', term: 'X', aliases: ['COFRONT']),
            existing,
          )?.id,
          '1',
        );
        expect(
          findDuplicateTerm(
            const TermCandidate(key: 'c', term: 'Other'),
            existing,
          ),
          isNull,
        );
      },
    );
  });

  test('wiki HTML to text drops infoboxes, references and tags', () {
    const html =
        '<div class="mw-parser-output"><table class="infobox"><tr><td>x</td></tr></table>'
        '<p><b>Fronting</b> is being in control<sup class="reference">[1]</sup> of the body.</p>'
        '<div class="toc">Contents</div><ul><li>One</li><li>Two &amp; three</li></ul></div>';
    expect(
      wikiHtmlToText(html),
      'Fronting is being in control of the body.\n\n• One\n\n• Two & three',
    );
  });

  test('wiki URLs: page, category, index.php, non-http', () {
    final p = parseWikiUrl('https://pluralpedia.org/w/Fronting')!;
    expect(p.origin, 'https://pluralpedia.org');
    final a = parseWikiUrl('https://x.fandom.com/wiki/Co-fronting_(term)')!;
    expect(a.page, 'Co-fronting (term)');
    final c = parseWikiUrl(
      'https://en.wikipedia.org/wiki/Category:Psychology_terms',
    )!;
    expect(c.category, 'Psychology terms');
    final q = parseWikiUrl('https://wiki.example.org/index.php?title=Host')!;
    expect(q.page, 'Host');
    expect(parseWikiUrl('not a url'), isNull);
  });

  test(
    'wiki client resolves the API, reads a category and each intro',
    () async {
      final calls = <String>[];
      final client = MockClient((req) async {
        calls.add(req.url.path);
        expect(req.url.queryParameters['origin'], '*');
        final q = req.url.queryParameters;
        if (req.url.path == '/w/api.php') return http.Response('not here', 404);
        if (q['meta'] == 'siteinfo')
          return http.Response(
            jsonEncode({
              'query': {'general': {}},
            }),
            200,
          );
        if (q['list'] == 'categorymembers') {
          return http.Response(
            jsonEncode({
              'query': {
                'categorymembers': [
                  {'title': 'Host'},
                  {'title': 'Missing'},
                ],
              },
            }),
            200,
          );
        }
        if (q['action'] == 'parse') {
          if (q['page'] == 'Missing')
            return http.Response(
              jsonEncode({
                'error': {'code': 'missingtitle'},
              }),
              200,
            );
          return http.Response(
            jsonEncode({
              'parse': {
                'title': 'Host',
                'text': {'*': '<p>The headmate who fronts most.</p>'},
              },
            }),
            200,
          );
        }
        return http.Response('?', 400);
      });
      final wiki = WikiClient(client: client);
      final titles = await wiki.categoryMembers('https://w.example', 'Roles');
      expect(titles, ['Host', 'Missing']);
      final progress = <int>[];
      final terms = await wiki.fetchTerms(
        'https://w.example',
        titles,
        category: 'Roles',
        onProgress: (d, _) => progress.add(d),
      );
      expect(terms[0].term, 'Host');
      expect(terms[0].definition, 'The headmate who fronts most.');
      expect(terms[0].sourceUrl, 'https://w.example/wiki/Host');
      expect(terms[0].source, 'w.example');
      expect(terms[1].error, 'fetch_failed');
      expect(progress, [1, 2]);
      expect(
        calls.where((p) => p == '/w/api.php'),
        hasLength(1),
      ); // cached after resolving
    },
  );

  test(
    'import creates collections from categories and handles duplicates',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          prismSyncHandleProvider.overrideWithBuild((ref, notifier) => null),
        ],
      );
      addTearDown(c.dispose);
      final n = c.read(trackerNotifierProvider.notifier);
      final existing = await n.create(
        kind: TrackerKind.dictTerm,
        title: 'Host',
        body: 'old',
      );
      final skipMe = await n.create(
        kind: TrackerKind.dictTerm,
        title: 'Little',
        body: 'keep',
      );
      final result = await importTerms(
        notifier: n,
        chosen: const [
          TermCandidate(
            key: 'a',
            term: 'Host',
            definition: 'new',
            category: 'Roles',
          ),
          TermCandidate(
            key: 'b',
            term: 'Little',
            definition: 'dup',
            category: 'Roles',
          ),
          TermCandidate(
            key: 'c',
            term: 'Protector',
            definition: 'p',
            category: 'Roles',
          ),
          TermCandidate(
            key: 'd',
            term: 'Blend',
            definition: 'b',
            category: 'States',
          ),
          TermCandidate(key: 'e', term: '', error: 'missing_term'),
        ],
        existingTerms: [existing, skipMe],
        existingCollections: const [],
        actionFor: (t) => t.key == 'a'
            ? TermDuplicateAction.replace
            : TermDuplicateAction.skip,
        useSourceCategories: true,
      );
      expect(
        (
          result.created,
          result.replaced,
          result.skipped,
          result.collectionsCreated,
        ),
        (2, 1, 2, 2),
      );
      final all = await c.read(trackerRecordRepositoryProvider).getAll();
      final terms = {
        for (final r in all.where((r) => r.kind == TrackerKind.dictTerm))
          r.title: r,
      };
      expect(terms['Host']!.body, 'new');
      expect(terms['Little']!.body, 'keep');
      final cols = {
        for (final r in all.where((r) => r.kind == TrackerKind.dictCollection))
          r.id: r.title,
      };
      expect(cols[terms['Protector']!.str(DictField.collection)], 'Roles');
      expect(cols[terms['Blend']!.str(DictField.collection)], 'States');
    },
  );
}
