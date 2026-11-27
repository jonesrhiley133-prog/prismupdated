import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prism_plurality/features/scrapbook/scrap_rentry.dart';

void main() {
  test('only Rentry page links are accepted', () {
    expect(rentrySlug('https://rentry.co/abc-123'), 'abc-123');
    expect(rentrySlug('rentry.org/hello/raw'), 'hello');
    expect(rentrySlug('https://www.rentry.co/x_y/edit'), 'x_y');
    expect(rentrySlug('https://evil.com/rentry.co/abc'), isNull);
    expect(rentrySlug('https://rentry.co.evil.com/abc'), isNull);
    expect(rentrySlug('https://rentry.co/'), isNull);
    expect(rentrySlug('https://rentry.co/api'), isNull);
    expect(rentrySlug('https://rentry.co/<script>'), isNull);
    expect(rentrySlug(''), isNull);
  });

  test(
    'sanitising removes scripts, HTML and unsafe links but keeps the text',
    () {
      const evil = '''# Hi
<script>alert(1)</script><style>body{}</style>
<iframe src="https://x"></iframe>
<b>bold</b> and <span onclick="x()">kept</span>
[ok](https://example.com) [bad](javascript:alert(1)) [data](data:text/html,x) [mail](mailto:a@b.c)
![pic](https://img.test/a.png) ![nope](javascript:x) ![local](file:///etc/passwd)
<!-- secret -->''';
      final s = sanitizeRentry(evil);
      expect(s, isNot(contains('<script')));
      expect(s, isNot(contains('alert(1)</')));
      expect(s, isNot(contains('<style')));
      expect(s, isNot(contains('iframe')));
      expect(s, isNot(contains('onclick')));
      expect(s, isNot(contains('javascript:')));
      expect(s, isNot(contains('data:text')));
      expect(s, isNot(contains('file:///')));
      expect(s, isNot(contains('secret')));
      expect(s, contains('bold'));
      expect(s, contains('kept'));
      expect(s, contains('[ok](https://example.com)'));
      expect(s, contains('[mail](mailto:a@b.c)'));
      expect(s, contains('![pic](https://img.test/a.png)'));
      expect(s, contains('[image: local]'));
      expect(
        sanitizeRentry('x' * (maxRentryChars + 50)).length,
        maxRentryChars,
      );
    },
  );

  test('the table of contents lists the headings', () {
    final s = expandRentryToc('[TOC]\n# One\n## Two\ntext');
    expect(s, contains('- One'));
    expect(s, contains('  - Two'));
    expect(s, isNot(contains('[TOC]')));
  });

  test('colours by name and hex, and nonsense is ignored', () {
    expect(rentryColor('red'), const Color(0xFFE53935));
    expect(rentryColor('#00ff00'), const Color(0xFF00FF00));
    expect(rentryColor('#0f0'), const Color(0xFF00FF00));
    expect(rentryColor('bogus'), isNull);
  });

  test('the edit page source and the rendered page both yield Markdown', () {
    expect(
      markdownFromEditPage(
        '<html><textarea id="id_text"># T &amp; &lt;b&gt;</textarea></html>',
      ),
      '# T & <b>',
    );
    expect(markdownFromEditPage('<html></html>'), isNull);
    final md = htmlToMarkdown(
      '<div class="entry-text"><h2>Title</h2><p>Hello <strong>you</strong> <a href="https://a.b">link</a></p><ul><li>one</li><li>two</li></ul><hr><table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table></div>',
    );
    expect(md, contains('## Title'));
    expect(md, contains('**you**'));
    expect(md, contains('[link](https://a.b)'));
    expect(md, contains('- one'));
    expect(md, contains('***'));
    expect(md, contains('| A | B |'));
  });

  test(
    'importing uses the raw text, then the edit page, then the page; only Rentry is contacted',
    () async {
      final asked = <Uri>[];
      MockClient client(Map<String, http.Response> routes) =>
          MockClient((r) async {
            asked.add(r.url);
            return routes[r.url.path] ?? http.Response('nope', 404);
          });
      var res = await RentryImporter(
        client: client({
          '/abc/raw': http.Response('# Raw <script>x</script>', 200),
        }),
      ).fetch('rentry.co/abc');
      expect(res.markdown, '# Raw ');
      expect(asked.every((u) => u.host == 'rentry.co'), isTrue);

      res = await RentryImporter(
        client: client({
          '/abc/raw': http.Response('<html>login</html>', 200),
          '/abc/edit': http.Response('<textarea># From edit</textarea>', 200),
        }),
      ).fetch('https://rentry.org/abc');
      expect(res.markdown, '# From edit');

      res = await RentryImporter(
        client: client({
          '/abc': http.Response(
            '<div class="entry-text"><h1>Page</h1></div>',
            200,
          ),
        }),
      ).fetch('https://rentry.co/abc');
      expect(res.markdown, contains('# Page'));

      res = await RentryImporter(
        client: client({}),
      ).fetch('https://rentry.co/missing');
      expect(res.error, 'notFound');
      res = await RentryImporter(
        client: client({}),
      ).fetch('https://example.com/x');
      expect(res.error, 'notRentry');

      final huge = http.Response.bytes(
        utf8.encode('#' * (RentryImporter.maxBytes + 10)),
        200,
      );
      res = await RentryImporter(
        client: client({'/big/raw': huge}),
      ).fetch('rentry.co/big');
      expect(res.markdown, isNull, reason: 'oversized pages are refused');
    },
  );

  testWidgets(
    'Rentry extras render: centre, right, colour, highlight, note box, table, divider',
    (t) async {
      const src = '''# Title
-> centred <-
-> right ->
%red% red words %%  and ==marked==
!!! warning Careful
    inside the box
| A | B |
|---|---|
| 1 | 2 |

***
~~gone~~ **bold** [link](https://example.com)
![x](javascript:bad)''';
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: RentryMarkdownView(src)),
          ),
        ),
      );
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.textContaining('centred'), findsOneWidget);
      expect(find.textContaining('right'), findsWidgets);
      expect(find.textContaining('red words'), findsOneWidget);
      expect(find.textContaining('marked'), findsOneWidget);
      expect(find.textContaining('Careful'), findsOneWidget);
      expect(find.textContaining('inside the box'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(find.textContaining('javascript'), findsNothing);
    },
  );
}
