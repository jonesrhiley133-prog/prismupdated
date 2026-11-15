import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:prism_plurality/features/dictionary/utils/dictionary_import.dart';

/// One article read from a wiki or file, before it becomes a term.
class WikiArticle {
  WikiArticle({
    required this.title,
    required this.content,
    this.url,
    this.source,
    this.description,
    this.categories = const [],
    this.images = const [],
    this.references = const [],
    this.updated,
    this.license,
    this.error,
  });
  String title;
  String content;
  final String? url;
  final String? source;
  String? description;
  final List<String> categories;
  final List<String> images;
  final List<String> references;
  final DateTime? updated;
  final String? license;

  /// Why this article couldn't be read (shown, and retried in bulk imports).
  final String? error;

  bool get ok => error == null;

  /// The short definition used for the dictionary entry.
  String get summary => description?.trim().isNotEmpty == true ? description!.trim() : firstParagraphs(content);

  TermCandidate toCandidate(int i, {String? category}) => TermCandidate(
    key: 'a$i',
    term: title.trim(),
    definition: summary,
    category: category ?? (categories.isEmpty ? null : categories.first),
    source: source,
    sourceUrl: url,
    error: error != null ? 'fetch_failed' : (title.trim().isEmpty ? 'missing_term' : (summary.isEmpty ? 'missing_definition' : null)),
  );
}

String firstParagraphs(String text, {int maxChars = 1200}) {
  final paras = text.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty);
  final b = StringBuffer();
  for (final p in paras) {
    if (b.isNotEmpty && b.length + p.length > maxChars) break;
    if (b.isNotEmpty) b.write('\n\n');
    b.write(p);
  }
  final s = b.toString();
  return s.length > maxChars + 400 ? '${s.substring(0, maxChars)}…' : s;
}

/// What a pasted link points at.
enum WikiScope { article, category, wholeWiki }

class WikiRequest {
  const WikiRequest(this.uri, this.scope, {this.page, this.category});
  final Uri uri;
  final WikiScope scope;
  final String? page;
  final String? category;
  String get origin => '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
}

class WikiImportError implements Exception {
  const WikiImportError(this.code, [this.detail]);

  /// network, not_found, blocked_by_robots, auth_required, rate_limited,
  /// unsupported, empty, not_a_url, bad_file.
  final String code;
  final String? detail;
  @override
  String toString() => 'WikiImportError($code${detail == null ? '' : ': $detail'})';
}

/// A wiki platform Prism can read. Add new platforms by implementing this
/// and listing them in [wikiProviders]; nothing else needs to change.
abstract class WikiProvider {
  String get id;
  String get name;

  /// Cheap guess from the URL alone.
  bool looksLike(Uri uri) => false;

  /// Confirms the site really is this platform (may make a request).
  Future<bool> probe(WikiHttp http, Uri uri);
  bool get canListCategory => false;
  bool get canListAll => false;

  /// Uses an official API (so robots rules for pages don't apply).
  bool get usesApi => false;
  WikiRequest parse(Uri uri);
  Future<WikiArticle> fetchArticle(WikiHttp http, WikiRequest r, String title);
  Future<List<String>> listTitles(WikiHttp http, WikiRequest r, {int limit = 500}) async => throw const WikiImportError('unsupported');
}

/// Polite HTTP: a generic client name, a gap between requests, timeouts,
/// rate-limit handling and robots.txt checks for page scraping.
class WikiHttp {
  WikiHttp({http.Client? client, this.gap = const Duration(milliseconds: 250)}) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration gap;
  DateTime _last = DateTime(2000);
  final Map<String, List<String>> _disallow = {};

  static const userAgent = 'PrismDictionaryImporter/1.0 (personal dictionary import)';

  Future<http.Response> get(Uri uri, {bool json = false}) async {
    final wait = gap - DateTime.now().difference(_last);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    _last = DateTime.now();
    final http.Response res;
    try {
      res = await _client.get(uri, headers: {if (!kIsWeb) 'User-Agent': userAgent, 'Accept': json ? 'application/json' : 'text/html,application/xhtml+xml,*/*'}).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const WikiImportError('network', 'timed out');
    } on Exception catch (e) {
      throw WikiImportError('network', '$e');
    }
    if (res.statusCode == 401 || res.statusCode == 403) throw WikiImportError('auth_required', '${res.statusCode}');
    if (res.statusCode == 429) throw const WikiImportError('rate_limited');
    if (res.statusCode == 404) throw const WikiImportError('not_found');
    if (res.statusCode >= 400) throw WikiImportError('network', 'HTTP ${res.statusCode}');
    return res;
  }

  Future<Map<String, dynamic>> getJson(Uri uri) async {
    final res = await get(uri, json: true);
    try {
      final v = jsonDecode(utf8.decode(res.bodyBytes));
      if (v is Map<String, dynamic>) return v;
    } on FormatException {
      // fallthrough
    }
    throw const WikiImportError('unsupported', 'not JSON');
  }

  /// Whether robots.txt lets generic clients read [uri].
  Future<bool> allowed(Uri uri) async {
    final origin = '${uri.scheme}://${uri.authority}';
    var rules = _disallow[origin];
    if (rules == null) {
      var found = <String>[];
      try {
        final res = await _client.get(Uri.parse('$origin/robots.txt')).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) found = parseRobots(res.body);
      } catch (_) {}
      _disallow[origin] = rules = found;
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    return !rules.any((r) => r.isNotEmpty && path.startsWith(r));
  }
}

/// Disallow rules for `User-agent: *` (and our own name).
@visibleForTesting
List<String> parseRobots(String body) {
  final out = <String>[];
  var applies = false;
  var sawRule = false;
  for (final raw in body.split('\n')) {
    final line = raw.split('#').first.trim();
    if (line.isEmpty) continue;
    final i = line.indexOf(':');
    if (i < 0) continue;
    final k = line.substring(0, i).trim().toLowerCase();
    final v = line.substring(i + 1).trim();
    if (k == 'user-agent') {
      if (sawRule) {
        applies = false;
        sawRule = false;
      }
      if (v == '*' || v.toLowerCase().startsWith('prism')) applies = true;
    } else if (k == 'disallow' || k == 'allow') {
      sawRule = true;
      if (applies && k == 'disallow' && v.isNotEmpty) out.add(v);
    }
  }
  return out;
}

// ───────────────────────── MediaWiki ─────────────────────────

/// Any MediaWiki site: Wikipedia, Fandom, Miraheze, Pluralpedia, LGBTQ wikis,
/// self-hosted installs. Uses the official API.
class MediaWikiProvider extends WikiProvider {
  final Map<String, String> _api = {};
  @override
  String get id => 'mediawiki';
  @override
  String get name => 'MediaWiki';
  @override
  bool get canListCategory => true;
  @override
  bool get canListAll => true;
  @override
  bool get usesApi => true;

  @override
  bool looksLike(Uri uri) =>
      uri.host.endsWith('wikipedia.org') ||
      uri.host.endsWith('fandom.com') ||
      uri.host.endsWith('miraheze.org') ||
      uri.host.contains('pluralpedia') ||
      uri.path.contains('/wiki/') ||
      uri.path.endsWith('api.php') ||
      uri.queryParameters.containsKey('title');

  Future<String> api(WikiHttp http, String origin, {String? hint}) async {
    final c = _api[origin];
    if (c != null) return c;
    final paths = [if (hint != null) hint, '/w/api.php', '/api.php', '/wiki/api.php', '/mediawiki/api.php'];
    for (final p in paths) {
      try {
        final r = await http.getJson(Uri.parse('$origin$p').replace(queryParameters: {'action': 'query', 'meta': 'siteinfo', 'format': 'json', 'origin': '*'}));
        if (r['query'] is Map) return _api[origin] = '$origin$p';
      } on WikiImportError catch (e) {
        if (e.code == 'network' || e.code == 'auth_required' || e.code == 'rate_limited') rethrow;
      }
    }
    throw const WikiImportError('unsupported', 'no MediaWiki API');
  }

  @override
  Future<bool> probe(WikiHttp http, Uri uri) async {
    try {
      await api(http, WikiRequest(uri, WikiScope.article).origin, hint: uri.path.endsWith('api.php') ? uri.path : null);
      return true;
    } on WikiImportError catch (e) {
      if (e.code == 'unsupported' || e.code == 'not_found') return false;
      rethrow;
    }
  }

  @override
  WikiRequest parse(Uri uri) {
    String? title = uri.queryParameters['title'] ?? uri.queryParameters['page'];
    final segs = uri.pathSegments;
    final wikiIdx = segs.indexOf('wiki');
    if (title == null && wikiIdx >= 0 && wikiIdx + 1 < segs.length) title = segs.sublist(wikiIdx + 1).join('/');
    if (title == null || title.isEmpty || uri.path.endsWith('api.php')) return WikiRequest(uri, WikiScope.wholeWiki);
    title = Uri.decodeComponent(title).replaceAll('_', ' ').trim();
    final cat = RegExp(r'^(Category|Categoría|Kategorie|Catégorie|Categoria|Kategoria):(.+)$', caseSensitive: false).firstMatch(title);
    if (cat != null) return WikiRequest(uri, WikiScope.category, category: cat.group(2)!.trim());
    final main = RegExp(r'^(Main Page|Main_Page|Portada|Hauptseite|Accueil)$', caseSensitive: false).hasMatch(title);
    return main ? WikiRequest(uri, WikiScope.wholeWiki) : WikiRequest(uri, WikiScope.article, page: title);
  }

  Uri _q(String api, Map<String, String> q) => Uri.parse(api).replace(queryParameters: {...q, 'format': 'json', 'formatversion': '2', 'origin': '*', 'maxlag': '5'});

  @override
  Future<WikiArticle> fetchArticle(WikiHttp http, WikiRequest r, String title) async {
    final a = await api(http, r.origin);
    final res = await http.getJson(_q(a, {
      'action': 'query',
      'prop': 'extracts|categories|info|pageimages|extlinks',
      'explaintext': '1',
      'exsectionformat': 'plain',
      'titles': title,
      'redirects': '1',
      'inprop': 'url',
      'clshow': '!hidden',
      'cllimit': '50',
      'ellimit': '30',
      'piprop': 'original',
    }));
    final pages = (res['query'] is Map ? res['query']['pages'] : null) as List?;
    final p = pages?.firstOrNull as Map?;
    if (p == null || p['missing'] == true) throw const WikiImportError('not_found');
    var text = '${p['extract'] ?? ''}'.trim();
    // Some wikis (Fandom, older installs) lack TextExtracts: parse HTML instead.
    if (text.isEmpty) {
      final parsed = await http.getJson(_q(a, {'action': 'parse', 'page': '${p['title']}', 'prop': 'text', 'redirects': '1', 'disabletoc': '1'}));
      final html = parsed['parse'] is Map ? parsed['parse']['text'] : null;
      text = html is String ? wikiHtmlToText(html) : (html is Map ? wikiHtmlToText('${html['*']}') : '');
    }
    final cats = [for (final c in (p['categories'] as List?) ?? const []) if (c is Map) '${c['title']}'.replaceFirst(RegExp(r'^[^:]+:'), '')];
    final img = p['original'] is Map ? '${p['original']['source']}' : null;
    final refs = [for (final e in (p['extlinks'] as List?) ?? const []) if (e is Map) '${e['url'] ?? e['*'] ?? ''}'].where((x) => x.isNotEmpty).toList();
    return WikiArticle(
      title: '${p['title']}',
      content: text,
      url: '${p['fullurl'] ?? '${r.origin}/wiki/${Uri.encodeComponent('${p['title']}'.replaceAll(' ', '_'))}'}',
      source: r.uri.host,
      categories: cats,
      images: [?img],
      references: refs,
      updated: DateTime.tryParse('${p['touched'] ?? ''}'),
      license: 'See ${r.uri.host} for the content licence',
    );
  }

  @override
  Future<List<String>> listTitles(WikiHttp http, WikiRequest r, {int limit = 500}) async {
    final a = await api(http, r.origin);
    final titles = <String>[];
    String? cont;
    final cat = r.scope == WikiScope.category;
    do {
      final res = await http.getJson(_q(a, cat
          ? {'action': 'query', 'list': 'categorymembers', 'cmtitle': 'Category:${r.category}', 'cmtype': 'page', 'cmnamespace': '0', 'cmlimit': '500', 'cmcontinue': ?cont}
          : {'action': 'query', 'list': 'allpages', 'apnamespace': '0', 'apfilterredir': 'nonredirects', 'aplimit': '500', 'apcontinue': ?cont}));
      final list = res['query'] is Map ? res['query'][cat ? 'categorymembers' : 'allpages'] : null;
      if (list is List) {
        for (final m in list) {
          if (m is Map && m['title'] is String) titles.add(m['title'] as String);
        }
      }
      final c = res['continue'];
      cont = c is Map ? (c[cat ? 'cmcontinue' : 'apcontinue'] as String?) : null;
    } while (cont != null && titles.length < limit);
    if (titles.isEmpty) throw const WikiImportError('empty');
    return titles.take(limit).toList();
  }
}

// ───────────────────────── Wikidot ─────────────────────────

/// Wikidot sites. Their API needs a personal key, so public pages are read
/// as HTML (respecting robots.txt).
class WikidotProvider extends WikiProvider {
  @override
  String get id => 'wikidot';
  @override
  String get name => 'Wikidot';
  @override
  bool get canListAll => true;
  @override
  bool looksLike(Uri uri) => uri.host.endsWith('wikidot.com');
  @override
  Future<bool> probe(WikiHttp http, Uri uri) async => looksLike(uri);
  @override
  WikiRequest parse(Uri uri) {
    final page = uri.pathSegments.where((s) => s.isNotEmpty).firstOrNull;
    return page == null || page == 'start' ? WikiRequest(uri, WikiScope.wholeWiki) : WikiRequest(uri, WikiScope.article, page: page);
  }

  @override
  Future<WikiArticle> fetchArticle(WikiHttp http, WikiRequest r, String title) async {
    final uri = Uri.parse('${r.origin}/${title.replaceAll(' ', '-').toLowerCase()}');
    if (!await http.allowed(uri)) throw const WikiImportError('blocked_by_robots');
    final html = utf8.decode((await http.get(uri)).bodyBytes, allowMalformed: true);
    final t = RegExp(r'<div id="page-title">\s*(.*?)\s*</div>', dotAll: true).firstMatch(html)?.group(1);
    final body = RegExp(r'<div id="page-content">(.*?)<div class="page-tags"', dotAll: true).firstMatch(html)?.group(1) ?? RegExp(r'<div id="page-content">(.*)', dotAll: true).firstMatch(html)?.group(1) ?? '';
    final tags = [for (final m in RegExp(r'<a href="/system:page-tags/tag/[^"]*"[^>]*>([^<]+)</a>').allMatches(html)) m.group(1)!];
    return WikiArticle(title: _clean(t ?? title), content: wikiHtmlToText(body), url: uri.toString(), source: r.uri.host, categories: tags, license: 'See ${r.uri.host} for the content licence');
  }

  @override
  Future<List<String>> listTitles(WikiHttp http, WikiRequest r, {int limit = 500}) async {
    final uri = Uri.parse('${r.origin}/system:list-all-pages');
    if (!await http.allowed(uri)) throw const WikiImportError('blocked_by_robots');
    final html = utf8.decode((await http.get(uri)).bodyBytes, allowMalformed: true);
    final out = <String>{};
    for (final m in RegExp(r'<a href="/([a-z0-9\-:_]+)"').allMatches(html)) {
      final p = m.group(1)!;
      if (p.startsWith('system:') || p.startsWith('admin:') || p.startsWith('nav:') || p.startsWith('forum')) continue;
      out.add(p);
      if (out.length >= limit) break;
    }
    if (out.isEmpty) throw const WikiImportError('empty');
    return out.toList();
  }
}

// ───────────────────────── DokuWiki ─────────────────────────

class DokuWikiProvider extends WikiProvider {
  @override
  String get id => 'dokuwiki';
  @override
  String get name => 'DokuWiki';
  @override
  bool looksLike(Uri uri) => uri.path.contains('doku.php') || uri.queryParameters.containsKey('id');
  @override
  Future<bool> probe(WikiHttp http, Uri uri) async => uri.path.contains('doku.php');
  @override
  WikiRequest parse(Uri uri) => WikiRequest(uri, WikiScope.article, page: uri.queryParameters['id'] ?? uri.pathSegments.last);
  @override
  Future<WikiArticle> fetchArticle(WikiHttp http, WikiRequest r, String title) async {
    final base = r.uri.replace(queryParameters: {'id': title, 'do': 'export_raw'});
    if (!await http.allowed(base)) throw const WikiImportError('blocked_by_robots');
    final raw = utf8.decode((await http.get(base)).bodyBytes, allowMalformed: true);
    return WikiArticle(title: title.split(':').last.replaceAll('_', ' '), content: dokuToText(raw), url: r.uri.replace(queryParameters: {'id': title}).toString(), source: r.uri.host);
  }
}

// ───────────────────────── Generic web page ─────────────────────────

/// Any other public page: reads the title, description and main content.
class HtmlPageProvider extends WikiProvider {
  @override
  String get id => 'html';
  @override
  String get name => 'Web page';
  @override
  Future<bool> probe(WikiHttp http, Uri uri) async => true;
  @override
  WikiRequest parse(Uri uri) => WikiRequest(uri, WikiScope.article, page: uri.toString());
  @override
  Future<WikiArticle> fetchArticle(WikiHttp http, WikiRequest r, String title) async {
    final uri = Uri.parse(title.startsWith('http') ? title : r.uri.toString());
    if (!await http.allowed(uri)) throw const WikiImportError('blocked_by_robots');
    final res = await http.get(uri);
    final type = res.headers['content-type'] ?? '';
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (type.contains('json')) {
      final c = parseDictionaryText(body, sourceName: uri.host);
      if (c.isEmpty) throw const WikiImportError('empty');
      final first = c.first;
      return WikiArticle(title: first.term, content: first.definition ?? '', url: uri.toString(), source: uri.host);
    }
    return htmlToArticle(body, uri);
  }
}

/// Title, description, categories and main text of an HTML page.
WikiArticle htmlToArticle(String html, Uri uri) {
  String? meta(String name) =>
      RegExp('<meta[^>]+(?:property|name)="$name"[^>]+content="([^"]*)"', caseSensitive: false).firstMatch(html)?.group(1) ??
      RegExp('<meta[^>]+content="([^"]*)"[^>]+(?:property|name)="$name"', caseSensitive: false).firstMatch(html)?.group(1);
  final title = meta('og:title') ?? RegExp(r'<h1[^>]*>(.*?)</h1>', dotAll: true, caseSensitive: false).firstMatch(html)?.group(1) ?? RegExp(r'<title>(.*?)</title>', dotAll: true, caseSensitive: false).firstMatch(html)?.group(1) ?? uri.pathSegments.lastOrNull ?? uri.host;
  final main = RegExp(r'<(?:main|article)[^>]*>(.*?)</(?:main|article)>', dotAll: true, caseSensitive: false).firstMatch(html)?.group(1) ??
      RegExp(r'<div[^>]+(?:id|class)="[^"]*(?:mw-parser-output|page-content|content|entry-content|post-content)[^"]*"[^>]*>(.*)', dotAll: true, caseSensitive: false).firstMatch(html)?.group(1) ??
      RegExp(r'<body[^>]*>(.*)</body>', dotAll: true, caseSensitive: false).firstMatch(html)?.group(1) ??
      html;
  final img = meta('og:image');
  final cats = [for (final m in RegExp(r'<a[^>]+href="[^"]*(?:Category:|/category/|/tag/)[^"]*"[^>]*>([^<]+)</a>', caseSensitive: false).allMatches(html)) _clean(m.group(1)!)].toSet().take(20).toList();
  final modified = meta('article:modified_time');
  return WikiArticle(
    title: _clean(title).replaceAll(RegExp(r'\s*[|\-–—]\s*[^|\-–—]+$'), '').trim(),
    content: wikiHtmlToText(main.replaceAll(RegExp(r'<(nav|header|footer)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), '')),
    description: meta('og:description') ?? meta('description'),
    url: uri.toString(),
    source: uri.host,
    images: [?img],
    categories: cats,
    updated: modified == null ? null : DateTime.tryParse(modified),
  );
}

String _clean(String s) => s
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Providers tried in order (most specific first, the web page last).
final List<WikiProvider> wikiProviders = [WikidotProvider(), DokuWikiProvider(), MediaWikiProvider(), HtmlPageProvider()];

/// Works out which platform a URL belongs to.
Future<(WikiProvider, WikiRequest)> detectProvider(WikiHttp http, String input) async {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) throw const WikiImportError('not_a_url');
  // Specific matches first, then probe for an API, then plain HTML.
  for (final p in wikiProviders.where((p) => p.looksLike(uri))) {
    if (await p.probe(http, uri)) return (p, p.parse(uri));
  }
  final mw = wikiProviders.whereType<MediaWikiProvider>().first;
  if (await mw.probe(http, uri)) return (mw, mw.parse(uri));
  final html = wikiProviders.whereType<HtmlPageProvider>().first;
  return (html, html.parse(uri));
}

// ───────────────────────── Files ─────────────────────────

/// Plain text from wikitext (MediaWiki markup).
String wikitextToText(String s) {
  var t = s;
  t = t.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  t = t.replaceAll(RegExp(r'<ref[^>/]*/>', caseSensitive: false), '');
  t = t.replaceAll(RegExp(r'<ref[^>]*>.*?</ref>', dotAll: true, caseSensitive: false), '');
  // Templates (nested), tables, files.
  for (var i = 0; i < 6; i++) {
    final before = t;
    t = t.replaceAll(RegExp(r'\{\{[^{}]*\}\}'), '');
    if (t == before) break;
  }
  t = t.replaceAll(RegExp(r'\{\|.*?\|\}', dotAll: true), '');
  t = t.replaceAll(RegExp(r'\[\[(?:File|Image|Archivo|Datei|Fichier):[^\[\]]*(?:\[\[[^\]]*\]\][^\[\]]*)*\]\]', caseSensitive: false), '');
  t = t.replaceAll(RegExp(r'\[\[(?:Category|Categoría|Kategorie|Catégorie):[^\]]*\]\]', caseSensitive: false), '');
  t = t.replaceAllMapped(RegExp(r'\[\[([^\]|]*)\|([^\]]*)\]\]'), (m) => m.group(2)!);
  t = t.replaceAllMapped(RegExp(r'\[\[([^\]]*)\]\]'), (m) => m.group(1)!);
  t = t.replaceAllMapped(RegExp(r'\[(?:https?:)?//[^\s\]]+\s([^\]]*)\]'), (m) => m.group(1)!);
  t = t.replaceAll(RegExp(r'\[(?:https?:)?//[^\]]*\]'), '');
  t = t.replaceAll(RegExp(r"'''''|'''|''"), '');
  t = t.replaceAllMapped(RegExp(r'^=+\s*(.*?)\s*=+\s*$', multiLine: true), (m) => '\n${m.group(1)}\n');
  t = t.replaceAll(RegExp(r'^[*#:;]+\s*', multiLine: true), '• ');
  t = t.replaceAll(RegExp(r'<[^>]+>'), '');
  t = t.replaceAll(RegExp(r'__[A-Z]+__'), '');
  return t.split('\n').map((l) => l.trimRight()).join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

List<String> wikitextCategories(String s) => [for (final m in RegExp(r'\[\[(?:Category|Categoría|Kategorie|Catégorie):([^\]|]*)', caseSensitive: false).allMatches(s)) m.group(1)!.trim()];

String dokuToText(String s) => s
    .replaceAllMapped(RegExp(r'\[\[[^\]|]*\|([^\]]*)\]\]'), (m) => m.group(1)!)
    .replaceAllMapped(RegExp(r'\[\[([^\]]*)\]\]'), (m) => m.group(1)!)
    .replaceAllMapped(RegExp(r'^=+\s*(.*?)\s*=+\s*$', multiLine: true), (m) => m.group(1)!)
    .replaceAll(RegExp(r'\*\*|//|__'), '')
    .trim();

/// Pages in a MediaWiki XML export (Special:Export or a dump).
List<WikiArticle> parseMediaWikiXml(String xml, {String? source}) {
  final siteBase = RegExp(r'<base>(.*?)</base>').firstMatch(xml)?.group(1);
  final host = siteBase == null ? source : Uri.tryParse(siteBase)?.host;
  final out = <WikiArticle>[];
  for (final m in RegExp(r'<page>(.*?)</page>', dotAll: true).allMatches(xml)) {
    final page = m.group(1)!;
    final ns = RegExp(r'<ns>(\d+)</ns>').firstMatch(page)?.group(1);
    if (ns != null && ns != '0') continue;
    if (page.contains('<redirect')) continue;
    final title = _xmlText(RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(page)?.group(1) ?? '');
    final text = _xmlText(RegExp(r'<text[^>]*>(.*?)</text>', dotAll: true).firstMatch(page)?.group(1) ?? '');
    final ts = RegExp(r'<timestamp>(.*?)</timestamp>').firstMatch(page)?.group(1);
    out.add(WikiArticle(
      title: title,
      content: wikitextToText(text),
      categories: wikitextCategories(text),
      source: host,
      url: siteBase == null ? null : '${Uri.parse(siteBase).origin}/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}',
      updated: ts == null ? null : DateTime.tryParse(ts),
    ));
  }
  return out;
}

String _xmlText(String s) => s.replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'").replaceAll('&amp;', '&');

/// Markdown: each heading becomes an article (or the whole file if none).
List<WikiArticle> parseMarkdown(String md, {String? name}) {
  final lines = md.split('\n');
  final out = <WikiArticle>[];
  String? title;
  final buf = StringBuffer();
  void flush() {
    if (title != null && buf.toString().trim().isNotEmpty) out.add(WikiArticle(title: title, content: _mdToText(buf.toString()), source: name));
    buf.clear();
  }

  final level = lines.any((l) => l.startsWith('## ')) ? '## ' : '# ';
  for (final l in lines) {
    if (l.startsWith(level)) {
      flush();
      title = l.substring(level.length).trim();
    } else if (level == '## ' && l.startsWith('# ')) {
      continue;
    } else {
      buf.writeln(l);
    }
  }
  flush();
  if (out.isEmpty && md.trim().isNotEmpty) {
    final firstHeading = RegExp(r'^#+\s+(.+)$', multiLine: true).firstMatch(md)?.group(1);
    out.add(WikiArticle(title: firstHeading ?? (name ?? 'Untitled'), content: _mdToText(md), source: name));
  }
  return out;
}

String _mdToText(String s) => s
    .replaceAllMapped(RegExp(r'!\[[^\]]*\]\([^)]*\)'), (_) => '')
    .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1)!)
    .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
    .replaceAll(RegExp(r'\*\*|__|`'), '')
    .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ')
    .trim();

/// Reads any supported file into articles.
List<WikiArticle> parseImportFile(String name, Uint8List bytes) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.zip')) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final out = <WikiArticle>[];
    for (final f in archive.files) {
      if (!f.isFile || f.name.startsWith('__MACOSX') || f.name.split('/').last.startsWith('.')) continue;
      try {
        out.addAll(parseImportFile(f.name, Uint8List.fromList(f.content)));
      } on WikiImportError {
        // Skip files we can't read inside the archive.
      }
    }
    if (out.isEmpty) throw const WikiImportError('bad_file', 'no supported files in the archive');
    return out;
  }
  final text = utf8.decode(bytes, allowMalformed: true);
  final base = name.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
  if (lower.endsWith('.xml')) {
    if (text.contains('<mediawiki') || text.contains('<page>')) return parseMediaWikiXml(text, source: base);
    return _fromCandidates(parseDictionaryText(text, sourceName: base));
  }
  if (lower.endsWith('.wiki') || lower.endsWith('.wikitext') || lower.endsWith('.mediawiki')) {
    return [WikiArticle(title: base.replaceAll('_', ' '), content: wikitextToText(text), categories: wikitextCategories(text), source: base)];
  }
  if (lower.endsWith('.html') || lower.endsWith('.htm')) return [htmlToArticle(text, Uri(path: name))];
  if (lower.endsWith('.md') || lower.endsWith('.markdown')) return parseMarkdown(text, name: base);
  if (lower.endsWith('.json') || lower.endsWith('.csv') || lower.endsWith('.tsv') || lower.endsWith('.txt')) {
    final c = _fromCandidates(parseDictionaryText(text, sourceName: base));
    if (c.isNotEmpty) return c;
  }
  // Last resort: treat as wikitext if it looks like it, else plain text.
  if (text.contains('[[') || text.contains("'''")) return [WikiArticle(title: base, content: wikitextToText(text), source: base)];
  final c = _fromCandidates(parseDictionaryText(text, sourceName: base));
  if (c.isEmpty) throw const WikiImportError('bad_file');
  return c;
}

List<WikiArticle> _fromCandidates(List<TermCandidate> cs) => [
  for (final c in cs)
    WikiArticle(title: c.term, content: c.definition ?? '', description: c.definition, source: c.source, url: c.sourceUrl, categories: [?c.category], error: c.isValid ? null : c.error),
];

/// Friendly reason for an import error.
(String, String) wikiErrorText(Object e) {
  final code = e is WikiImportError ? e.code : 'network';
  return switch (code) {
    'not_a_url' => ('That isn’t a web address (it should start with https://).', 'Eso no es una dirección web (debe empezar por https://).'),
    'not_found' => ('The page wasn’t found. Check the link.', 'No se encontró la página. Revisa el enlace.'),
    'blocked_by_robots' => ('This site asks automated tools not to read these pages (robots.txt). Export the pages yourself and import the file instead.', 'Este sitio pide que las herramientas automáticas no lean estas páginas (robots.txt). Expórtalas tú y importa el archivo.'),
    'auth_required' => ('This site needs you to sign in, so Prism can’t read it. Export the content and import the file instead.', 'Este sitio requiere iniciar sesión, así que Prism no puede leerlo. Exporta el contenido e importa el archivo.'),
    'rate_limited' => ('The site asked us to slow down. Wait a minute and retry.', 'El sitio pidió ir más despacio. Espera un minuto y reintenta.'),
    'unsupported' => ('This site doesn’t offer a supported way to list pages. Paste article links one by one, or import an export file.', 'Este sitio no ofrece una forma compatible de listar páginas. Pega enlaces uno a uno o importa un archivo.'),
    'empty' => ('Nothing was found to import.', 'No se encontró nada que importar.'),
    'bad_file' => ('That file couldn’t be read. Supported: XML dumps, wikitext, HTML, JSON, CSV, Markdown, ZIP.', 'No se pudo leer el archivo. Compatibles: volcados XML, wikitext, HTML, JSON, CSV, Markdown, ZIP.'),
    _ => ('Couldn’t reach the site. Check your connection and the link.', 'No se pudo conectar con el sitio. Revisa la conexión y el enlace.'),
  };
}
