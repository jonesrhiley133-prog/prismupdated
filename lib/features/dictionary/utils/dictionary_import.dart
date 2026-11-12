import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:prism_plurality/domain/models/tracker_record.dart';

/// Field keys inside a dictionary term's `data`.
abstract final class DictField {
  static const collection = 'collection';
  static const aliases = 'aliases';
  static const pronunciation = 'pronunciation';
  static const examples = 'examples';
  static const source = 'source';
  static const sourceUrl = 'sourceUrl';
  static const color = 'color';
  static const description = 'description';
}

/// A term read from a file, pasted text or a wiki, before import.
@immutable
class TermCandidate {
  const TermCandidate({
    required this.key,
    required this.term,
    this.definition,
    this.aliases = const [],
    this.category,
    this.source,
    this.sourceUrl,
    this.error,
  });

  final String key;
  final String term;
  final String? definition;
  final List<String> aliases;

  /// Collection name suggested by the source (CSV column, wiki category).
  final String? category;
  final String? source;
  final String? sourceUrl;

  /// `missing_term`, `missing_definition`, `fetch_failed`.
  final String? error;

  bool get isValid => error == null;
}

String normalizeTerm(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Existing term that a candidate would duplicate (same term or alias).
TrackerRecord? findDuplicateTerm(
  TermCandidate c,
  Map<String, TrackerRecord> existingByName,
) {
  final names = [c.term, ...c.aliases].map(normalizeTerm);
  for (final n in names) {
    final hit = existingByName[n];
    if (hit != null) return hit;
  }
  return null;
}

/// Index of existing terms by normalized term and aliases.
Map<String, TrackerRecord> indexTerms(Iterable<TrackerRecord> terms) {
  final out = <String, TrackerRecord>{};
  for (final t in terms) {
    out.putIfAbsent(normalizeTerm(t.title), () => t);
    for (final a in t.strings(DictField.aliases)) {
      out.putIfAbsent(normalizeTerm(a), () => t);
    }
  }
  return out;
}

TermCandidate _candidate(
  int i,
  String? term,
  String? def, {
  List<String> aliases = const [],
  String? category,
  String? source,
  String? sourceUrl,
}) {
  final t = term?.trim() ?? '';
  final d = def?.trim();
  return TermCandidate(
    key: 'c$i',
    term: t,
    definition: d == null || d.isEmpty ? null : d,
    aliases: [
      for (final a in aliases)
        if (a.trim().isNotEmpty) a.trim(),
    ],
    category: category?.trim().isEmpty ?? true ? null : category!.trim(),
    source: source,
    sourceUrl: sourceUrl,
    error: t.isEmpty
        ? 'missing_term'
        : (d == null || d.isEmpty)
        ? 'missing_definition'
        : null,
  );
}

const _termKeys = ['term', 'name', 'word', 'title', 'label', 'headword'];
const _defKeys = [
  'definition',
  'description',
  'meaning',
  'desc',
  'explanation',
  'text',
  'body',
  'summary',
];
const _catKeys = ['category', 'collection', 'group', 'type', 'section'];
const _aliasKeys = ['aliases', 'alias', 'synonyms', 'also', 'alternatives'];

String? _pick(Map m, List<String> keys) {
  for (final k in m.keys) {
    if (keys.contains(k.toString().toLowerCase())) {
      final v = m[k];
      if (v is String) return v;
      if (v is num) return '$v';
    }
  }
  return null;
}

List<String> _pickList(Map m, List<String> keys) {
  for (final k in m.keys) {
    if (keys.contains(k.toString().toLowerCase())) {
      final v = m[k];
      if (v is List) return [for (final x in v) '$x'];
      if (v is String) return v.split(RegExp(r'[,;|]'));
    }
  }
  return const [];
}

/// Parses a dictionary file. Accepts:
/// * JSON: a list of objects (`term`/`definition` and common synonyms), a
///   `{term: definition}` map, or either nested under a key such as
///   `terms`/`entries`/`glossary`;
/// * CSV/TSV with a header row (term, definition, category, aliases) or two
///   bare columns;
/// * plain text, one `Term: definition` / `Term - definition` /
///   `Term = definition` per line, or a term line followed by indented or
///   following definition lines separated by blank lines.
List<TermCandidate> parseDictionaryText(String source, {String? sourceName}) {
  final text = source.replaceFirst('﻿', '').trim();
  if (text.isEmpty) return const [];
  if (text.startsWith('[') || text.startsWith('{')) {
    try {
      return _fromJson(jsonDecode(text), sourceName);
    } on FormatException {
      // Fall through to text parsing.
    }
  }
  final firstLine = text.split('\n').first;
  if (firstLine.contains('\t') ||
      (firstLine.contains(',') &&
          RegExp(
            r'^\s*"?(term|word|name)"?\s*,',
            caseSensitive: false,
          ).hasMatch(firstLine))) {
    return _fromCsv(text, sourceName);
  }
  return _fromLines(text, sourceName);
}

List<TermCandidate> _fromJson(Object? v, String? src) {
  if (v is Map) {
    for (final key in [
      'terms',
      'entries',
      'glossary',
      'dictionary',
      'words',
      'items',
      'data',
    ]) {
      final inner = v[key];
      if (inner is List || inner is Map) return _fromJson(inner, src);
    }
    if (v.values.every((x) => x is String)) {
      var i = 0;
      return [
        for (final e in v.entries)
          _candidate(i++, '${e.key}', e.value as String, source: src),
      ];
    }
    return [_fromJsonObject(0, v, src)];
  }
  if (v is List) {
    return [
      for (var i = 0; i < v.length; i++)
        if (v[i] is Map)
          _fromJsonObject(i, v[i] as Map, src)
        else if (v[i] is List && (v[i] as List).length >= 2)
          _candidate(
            i,
            '${(v[i] as List)[0]}',
            '${(v[i] as List)[1]}',
            source: src,
          ),
    ];
  }
  return const [];
}

TermCandidate _fromJsonObject(int i, Map m, String? src) => _candidate(
  i,
  _pick(m, _termKeys),
  _pick(m, _defKeys),
  aliases: _pickList(m, _aliasKeys),
  category: _pick(m, _catKeys),
  source: src,
  sourceUrl: _pick(m, ['url', 'link', 'source_url', 'sourceurl']),
);

List<String> _splitCsvLine(String line, String sep) {
  final out = <String>[];
  final b = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          b.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        b.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == sep) {
      out.add(b.toString());
      b.clear();
    } else {
      b.write(ch);
    }
  }
  out.add(b.toString());
  return out;
}

List<TermCandidate> _fromCsv(String text, String? src) {
  final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty);
  final sep = text.split('\n').first.contains('\t') ? '\t' : ',';
  final rows = [for (final l in lines) _splitCsvLine(l, sep)];
  if (rows.isEmpty) return const [];
  final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
  int col(List<String> keys) => header.indexWhere(keys.contains);
  var ti = col(_termKeys), di = col(_defKeys);
  final ci = col(_catKeys), ai = col(_aliasKeys);
  var body = rows.skip(1).toList();
  if (ti < 0 || di < 0) {
    ti = 0;
    di = 1;
    body = rows;
  }
  String? at(List<String> r, int i) => i >= 0 && i < r.length ? r[i] : null;
  return [
    for (var i = 0; i < body.length; i++)
      _candidate(
        i,
        at(body[i], ti),
        at(body[i], di),
        category: at(body[i], ci),
        aliases: at(body[i], ai)?.split(RegExp(r'[;|]')) ?? const [],
        source: src,
      ),
  ];
}

final _inlineDef = RegExp(
  r'^\s*[-*•]?\s*([^:=–—]{1,80}?)\s*(?::|=|\s[-–—]\s)\s*(.+)$',
);

List<TermCandidate> _fromLines(String text, String? src) {
  final out = <TermCandidate>[];
  final blocks = text.split(RegExp(r'\n\s*\n'));
  var i = 0;
  for (final block in blocks) {
    final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) continue;
    final inline = lines.map(_inlineDef.firstMatch).toList();
    if (inline.every((m) => m != null)) {
      for (final m in inline) {
        out.add(_candidate(i++, m!.group(1), m.group(2), source: src));
      }
    } else {
      final first = _inlineDef.firstMatch(lines.first);
      if (first != null) {
        out.add(
          _candidate(
            i++,
            first.group(1),
            [first.group(2)!, ...lines.skip(1).map((l) => l.trim())].join(' '),
            source: src,
          ),
        );
      } else {
        out.add(
          _candidate(
            i++,
            lines.first,
            lines.skip(1).map((l) => l.trim()).join(' '),
            source: src,
          ),
        );
      }
    }
  }
  return out;
}

/// Turns MediaWiki parser HTML into plain text paragraphs, dropping
/// infoboxes, references, tables and edit links.
String wikiHtmlToText(String html) {
  var s = html;
  for (final tag in ['table', 'style', 'script', 'sup', 'figure', 'aside']) {
    s = s.replaceAll(
      RegExp('<$tag[^>]*>.*?</$tag>', caseSensitive: false, dotAll: true),
      '',
    );
  }
  s = s.replaceAll(
    RegExp(
      r'<div[^>]*class="[^"]*(?:toc|navbox|mw-references|reflist|thumb|hatnote|metadata|ambox)[^"]*"[^>]*>.*?</div>',
      caseSensitive: false,
      dotAll: true,
    ),
    '',
  );
  s = s.replaceAll(
    RegExp(r'<span class="mw-editsection".*?</span>\s*</span>', dotAll: true),
    '',
  );
  s = s.replaceAll(
    RegExp(r'</(p|li|h\d|div|dd|dt)>', caseSensitive: false),
    '\n',
  );
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m[1]!)),
      );
  s = s.replaceAll(RegExp(r'\[\d+\]'), '');
  final paras = s
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .toList();
  return paras.join('\n\n');
}

/// What a wiki link points at.
@immutable
class WikiTarget {
  const WikiTarget({required this.origin, this.page, this.category});

  /// Scheme and host, e.g. `https://pluralpedia.org`.
  final String origin;
  final String? page;
  final String? category;
}

/// Reads a wiki page or category URL. Returns null for non-http input.
WikiTarget? parseWikiUrl(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
    return null;
  }
  if (uri.host.isEmpty) return null;
  final origin =
      '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  String? title = uri.queryParameters['title'];
  final segs = uri.pathSegments;
  final wikiIdx = segs.indexOf('wiki');
  if (title == null && wikiIdx >= 0 && wikiIdx + 1 < segs.length) {
    title = segs.sublist(wikiIdx + 1).join('/');
  }
  if (title == null || title.isEmpty) return WikiTarget(origin: origin);
  title = Uri.decodeComponent(title).replaceAll('_', ' ').trim();
  final cat = RegExp(
    r'^(Category|Categoría|Kategorie|Catégorie):(.+)$',
  ).firstMatch(title);
  if (cat != null) return WikiTarget(origin: origin, category: cat.group(2));
  return WikiTarget(origin: origin, page: title);
}

class WikiImportException implements Exception {
  const WikiImportException(this.code);

  /// `not_mediawiki`, `network`, `not_found`, `empty_category`.
  final String code;

  @override
  String toString() => 'WikiImportException($code)';
}

/// Talks to any MediaWiki-based wiki (Wikipedia, Fandom, Miraheze,
/// Pluralpedia …) through its public API. Anonymous CORS is requested so it
/// also works on the web build.
class WikiClient {
  WikiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, String> _apiByOrigin = {};

  static const maxCategoryPages = 300;

  Future<Map<String, dynamic>> _get(String api, Map<String, String> q) async {
    final uri = Uri.parse(
      api,
    ).replace(queryParameters: {...q, 'format': 'json', 'origin': '*'});
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 20));
    } on Exception {
      throw const WikiImportException('network');
    }
    if (res.statusCode != 200) throw const WikiImportException('not_mediawiki');
    try {
      final v = jsonDecode(res.body);
      if (v is Map<String, dynamic>) return v;
    } on FormatException {
      // Not JSON: not an API endpoint.
    }
    throw const WikiImportException('not_mediawiki');
  }

  /// Finds the API endpoint for [origin] (`/w/api.php` or `/api.php`).
  Future<String> resolveApi(String origin) async {
    final cached = _apiByOrigin[origin];
    if (cached != null) return cached;
    for (final path in ['/w/api.php', '/api.php']) {
      try {
        final r = await _get('$origin$path', {
          'action': 'query',
          'meta': 'siteinfo',
        });
        if (r['query'] is Map) return _apiByOrigin[origin] = '$origin$path';
      } on WikiImportException catch (e) {
        if (e.code == 'network') rethrow;
      }
    }
    throw const WikiImportException('not_mediawiki');
  }

  /// Plain-text introduction of [title] (section 0).
  Future<({String title, String text, String url})> fetchIntro(
    String origin,
    String title,
  ) async {
    final api = await resolveApi(origin);
    final r = await _get(api, {
      'action': 'parse',
      'page': title,
      'prop': 'text',
      'section': '0',
      'redirects': '1',
      'disabletoc': '1',
    });
    final parse = r['parse'];
    if (parse is! Map) throw const WikiImportException('not_found');
    final html = (parse['text'] is Map ? parse['text']['*'] : parse['text']);
    final resolved = parse['title'] is String
        ? parse['title'] as String
        : title;
    final text = html is String ? wikiHtmlToText(html) : '';
    return (
      title: resolved,
      text: text,
      url: '$origin/wiki/${Uri.encodeComponent(resolved.replaceAll(' ', '_'))}',
    );
  }

  /// Page titles in a category (articles only), up to [maxCategoryPages].
  Future<List<String>> categoryMembers(String origin, String category) async {
    final api = await resolveApi(origin);
    final titles = <String>[];
    String? cont;
    do {
      final r = await _get(api, {
        'action': 'query',
        'list': 'categorymembers',
        'cmtitle': 'Category:$category',
        'cmtype': 'page',
        'cmnamespace': '0',
        'cmlimit': '500',
        'cmcontinue': ?cont,
      });
      final members = r['query'] is Map ? r['query']['categorymembers'] : null;
      if (members is List) {
        for (final m in members) {
          if (m is Map && m['title'] is String) {
            titles.add(m['title'] as String);
          }
        }
      }
      final c = r['continue'];
      cont = c is Map && c['cmcontinue'] is String
          ? c['cmcontinue'] as String
          : null;
    } while (cont != null && titles.length < maxCategoryPages);
    if (titles.isEmpty) throw const WikiImportException('empty_category');
    return titles.take(maxCategoryPages).toList();
  }

  /// Builds candidates for [titles], fetching each intro; failures become
  /// invalid candidates rather than aborting the import.
  Future<List<TermCandidate>> fetchTerms(
    String origin,
    List<String> titles, {
    String? category,
    void Function(int done, int total)? onProgress,
  }) async {
    final host = Uri.parse(origin).host;
    final out = <TermCandidate>[];
    for (var i = 0; i < titles.length; i++) {
      try {
        final p = await fetchIntro(origin, titles[i]);
        out.add(
          _candidate(
            i,
            p.title,
            _firstParagraphs(p.text),
            category: category,
            source: host,
            sourceUrl: p.url,
          ),
        );
      } on WikiImportException {
        out.add(
          TermCandidate(
            key: 'c$i',
            term: titles[i],
            source: host,
            error: 'fetch_failed',
          ),
        );
      }
      onProgress?.call(i + 1, titles.length);
    }
    return out;
  }

  static String _firstParagraphs(String text, {int maxChars = 1200}) {
    final paras = text.split('\n\n');
    final b = StringBuffer();
    for (final p in paras) {
      if (b.isNotEmpty && b.length + p.length > maxChars) break;
      if (b.isNotEmpty) b.write('\n\n');
      b.write(p);
    }
    return b.toString();
  }
}
