import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:prism_plurality/features/dictionary/importer/wiki_providers.dart';

void main() {
  test('robots.txt rules for generic clients', () {
    final r = parseRobots(
      'User-agent: Googlebot\nDisallow: /g\n\nUser-agent: *\nDisallow: /private\nAllow: /\n# c\nUser-agent: Other\nDisallow: /x',
    );
    expect(r, ['/private']);
  });

  test('wikitext becomes readable text', () {
    const w =
        "'''Plural''' is a [[word]] for [[System|systems]].<ref>cite</ref> {{Infobox|a=b}}\n== History ==\n* one\n[[Category:Terms]]";
    final t = wikitextToText(w);
    expect(t, contains('Plural is a word for systems.'));
    expect(t, isNot(contains('Infobox')));
    expect(t, isNot(contains('cite')));
    expect(t, contains('History'));
    expect(wikitextCategories(w), ['Terms']);
  });

  test('MediaWiki XML dump: articles only, no redirects', () {
    const xml =
        '<mediawiki><siteinfo><base>https://pluralpedia.org/wiki/Main_Page</base></siteinfo>'
        '<page><title>Headmate</title><ns>0</ns><revision><timestamp>2024-05-01T00:00:00Z</timestamp><text>A \'\'\'headmate\'\'\' is &lt;b&gt;someone&lt;/b&gt; [[Category:Plurality]]</text></revision></page>'
        '<page><title>Talk:Headmate</title><ns>1</ns><revision><text>x</text></revision></page>'
        '<page><title>Alter</title><ns>0</ns><redirect title="Headmate"/><revision><text>#REDIRECT</text></revision></page>'
        '</mediawiki>';
    final a = parseMediaWikiXml(xml);
    expect(a.map((x) => x.title), ['Headmate']);
    expect(a.single.content, contains('A headmate is someone'));
    expect(a.single.categories, ['Plurality']);
    expect(a.single.source, 'pluralpedia.org');
    expect(a.single.url, 'https://pluralpedia.org/wiki/Headmate');
  });

  test('Markdown headings become articles; files and zips are read', () {
    final md = parseMarkdown(
      '# Glossary\n\n## Fronting\nBeing in control.\n\n## Switch\nA change in who fronts.',
    );
    expect(md.map((a) => a.title), ['Fronting', 'Switch']);
    final csv = parseImportFile(
      'terms.csv',
      Uint8List.fromList(
        utf8.encode('term,definition\nCo-con,Being co-conscious\n'),
      ),
    );
    expect(csv.single.title, 'Co-con');
    final zip = Archive()
      ..addFile(
        ArchiveFile.bytes('a.md', utf8.encode('## Host\nThe main fronter.')),
      )
      ..addFile(
        ArchiveFile.bytes(
          'b.wiki',
          utf8.encode("'''Little''' is a younger alter."),
        ),
      );
    final z = parseImportFile(
      'export.zip',
      Uint8List.fromList(ZipEncoder().encode(zip)),
    );
    expect(z.map((a) => a.title), containsAll(['Host', 'b']));
    expect(
      () => parseImportFile(
        'bad.zip',
        Uint8List.fromList(ZipEncoder().encode(Archive())),
      ),
      throwsA(isA<WikiImportError>()),
    );
  });

  test(
    'detects MediaWiki, fetches articles and categories through the API',
    () async {
      final calls = <Uri>[];
      final client = MockClient((req) async {
        calls.add(req.url);
        final q = req.url.queryParameters;
        if (req.url.path == '/w/api.php' && q['meta'] == 'siteinfo')
          return http.Response(
            jsonEncode({
              'query': {'general': {}},
            }),
            200,
          );
        if (q['prop']?.contains('extracts') == true) {
          return http.Response(
            jsonEncode({
              'query': {
                'pages': [
                  {
                    'title': 'Fronting',
                    'extract':
                        'Fronting is being in control of the body.\n\nMore text.',
                    'fullurl': 'https://example.org/wiki/Fronting',
                    'touched': '2025-01-02T00:00:00Z',
                    'categories': [
                      {'title': 'Category:Terms'},
                    ],
                    'extlinks': [
                      {'url': 'https://ref.example'},
                    ],
                  },
                ],
              },
            }),
            200,
          );
        }
        if (q['list'] == 'categorymembers') {
          return http.Response(
            jsonEncode({
              'query': {
                'categorymembers': [
                  {'title': 'A'},
                  {'title': 'B'},
                ],
              },
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final h = WikiHttp(client: client, gap: Duration.zero);
      final (p, r) = await detectProvider(
        h,
        'https://example.org/wiki/Fronting',
      );
      expect(p.id, 'mediawiki');
      expect(r.scope, WikiScope.article);
      final a = await p.fetchArticle(h, r, r.page!);
      expect(a.title, 'Fronting');
      expect(a.summary, contains('being in control'));
      expect(a.categories, ['Terms']);
      expect(a.references, ['https://ref.example']);
      expect(a.updated, DateTime.utc(2025, 1, 2));
      final (_, cat) = await detectProvider(
        h,
        'https://example.org/wiki/Category:Terms',
      );
      expect(cat.scope, WikiScope.category);
      expect(await p.listTitles(h, cat), ['A', 'B']);
      expect(calls.every((u) => u.queryParameters['origin'] == '*'), isTrue);
    },
  );

  test('plain pages respect robots.txt and errors explain themselves', () async {
    final client = MockClient((req) async {
      if (req.url.path == '/robots.txt')
        return http.Response('User-agent: *\nDisallow: /secret', 200);
      if (req.url.path.endsWith('api.php')) return http.Response('nope', 404);
      if (req.url.path == '/open')
        return http.Response(
          '<html><head><title>Open term | Site</title><meta name="description" content="Desc here"></head><body><main><p>Body text</p></main></body></html>',
          200,
        );
      return http.Response('<html></html>', 200);
    });
    final h = WikiHttp(client: client, gap: Duration.zero);
    final (p, r) = await detectProvider(h, 'https://site.test/open');
    expect(p.id, 'html');
    final a = await p.fetchArticle(h, r, r.page!);
    expect(a.title, 'Open term');
    expect(a.summary, 'Desc here');
    final (p2, r2) = await detectProvider(h, 'https://site.test/secret/page');
    await expectLater(
      p2.fetchArticle(h, r2, r2.page!),
      throwsA(
        isA<WikiImportError>().having(
          (e) => e.code,
          'code',
          'blocked_by_robots',
        ),
      ),
    );
    await expectLater(
      detectProvider(h, 'not a url'),
      throwsA(
        isA<WikiImportError>().having((e) => e.code, 'code', 'not_a_url'),
      ),
    );
    expect(
      wikiErrorText(const WikiImportError('auth_required')).$1,
      contains('sign in'),
    );
  });
}
