import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/safe_link.dart';
import 'package:share_plus/share_plus.dart';

// Rentry (rentry.co / rentry.org) pages are Markdown with a few extras:
// centred and right-aligned lines, coloured text, admonition boxes,
// highlights and a table of contents. Everything here renders those safely:
// no HTML or scripts ever run, links are limited to web and mail, and
// anything unrecognised is shown as plain text instead of breaking.

const maxRentryChars = 200000;
const _rentryHosts = {
  'rentry.co',
  'rentry.org',
  'www.rentry.co',
  'www.rentry.org',
};

/// The page id in a Rentry link (`https://rentry.co/abc`, `rentry.org/abc/raw`…),
/// or null when it isn't a Rentry page link.
String? rentrySlug(String url) {
  var u = url.trim();
  if (u.isEmpty) return null;
  if (!u.contains('://')) u = 'https://$u';
  final uri = Uri.tryParse(u);
  if (uri == null || !_rentryHosts.contains(uri.host.toLowerCase()))
    return null;
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return null;
  final slug = segs.first;
  if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(slug)) return null;
  if (const {
    'api',
    'static',
    'what',
    'new',
    'raw',
  }.contains(slug.toLowerCase()))
    return null;
  return slug;
}

String _unescapeHtml(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x27;', "'")
    .replaceAll('&nbsp;', ' ')
    .replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m[1]!).clamp(0, 0x10FFFF)),
    )
    .replaceAll('&amp;', '&');

/// Removes anything active or unsafe: script/style/iframe/form blocks, all
/// remaining HTML tags (their text is kept), and script/data links. The
/// result is plain Markdown.
String sanitizeRentry(String input) {
  var s = input.length > maxRentryChars
      ? input.substring(0, maxRentryChars)
      : input;
  s = s.replaceAll('\r\n', '\n');
  s = s.replaceAll(
    RegExp(
      r'<\s*(script|style|iframe|object|embed|form|template|svg|math|noscript|link|meta|base)\b[\s\S]*?<\s*/\s*\1\s*>',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceAll(
    RegExp(
      r'<\s*(script|style|iframe|object|embed|link|meta|base|input|button|img|video|audio|source)\b[^>]*>',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  // Any other tag: drop the tag, keep its text.
  s = s.replaceAll(RegExp(r'</?[A-Za-z][A-Za-z0-9-]*(\s[^<>]*)?/?>'), '');
  // Links and images may only point at the web (or mail for links).
  s = s.replaceAllMapped(RegExp(r'(!?)\[([^\]]*)\]\(\s*([^)\s]*)([^)]*)\)'), (
    m,
  ) {
    final img = m[1] == '!';
    final url = m[3] ?? '';
    final ok = img
        ? RegExp(r'^https?://', caseSensitive: false).hasMatch(url)
        : safeExternalUri(url) != null || url.startsWith('#');
    if (ok) return m[0]!;
    return img ? '[image: ${m[2]}]' : (m[2] ?? '');
  });
  return s;
}

/// Pulls the Markdown out of a Rentry edit page (it sits in the textarea).
String? markdownFromEditPage(String html) {
  final m = RegExp(
    r'<textarea[^>]*>([\s\S]*?)</textarea>',
    caseSensitive: false,
  ).firstMatch(html);
  if (m == null) return null;
  final text = _unescapeHtml(m[1]!).trim();
  return text.isEmpty ? null : text;
}

/// A best-effort Markdown version of a rendered Rentry page, for when the
/// source itself isn't available.
String htmlToMarkdown(String html) {
  var s = html;
  final body = RegExp(
    r'<div[^>]*class="[^"]*entry-text[^"]*"[^>]*>([\s\S]*)</div>',
    caseSensitive: false,
  ).firstMatch(s);
  if (body != null) s = body[1]!;
  s = s.replaceAll(
    RegExp(r'<\s*(script|style)\b[\s\S]*?</\s*\1\s*>', caseSensitive: false),
    '',
  );
  for (var h = 6; h >= 1; h--) {
    s = s.replaceAllMapped(
      RegExp('<h$h[^>]*>([\\s\\S]*?)</h$h>', caseSensitive: false),
      (m) => '\n${'#' * h} ${m[1]!.trim()}\n',
    );
  }
  s = s.replaceAllMapped(
    RegExp(
      r'<img[^>]*src="([^"]+)"[^>]*alt="([^"]*)"[^>]*>',
      caseSensitive: false,
    ),
    (m) => '![${m[2]}](${m[1]})',
  );
  s = s.replaceAllMapped(
    RegExp(r'<img[^>]*src="([^"]+)"[^>]*>', caseSensitive: false),
    (m) => '![](${m[1]})',
  );
  s = s.replaceAllMapped(
    RegExp(r'<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>', caseSensitive: false),
    (m) => '[${m[2]}](${m[1]})',
  );
  s = s.replaceAllMapped(
    RegExp(r'<(strong|b)>([\s\S]*?)</\1>', caseSensitive: false),
    (m) => '**${m[2]}**',
  );
  s = s.replaceAllMapped(
    RegExp(r'<(em|i)>([\s\S]*?)</\1>', caseSensitive: false),
    (m) => '*${m[2]}*',
  );
  s = s.replaceAllMapped(
    RegExp(r'<(del|s)>([\s\S]*?)</\1>', caseSensitive: false),
    (m) => '~~${m[2]}~~',
  );
  s = s.replaceAllMapped(
    RegExp(r'<code>([\s\S]*?)</code>', caseSensitive: false),
    (m) => '`${m[1]}`',
  );
  s = s.replaceAllMapped(
    RegExp(r'<li[^>]*>([\s\S]*?)</li>', caseSensitive: false),
    (m) => '\n- ${m[1]!.trim()}',
  );
  s = s.replaceAll(RegExp(r'<hr[^>]*>', caseSensitive: false), '\n***\n');
  s = s.replaceAllMapped(
    RegExp(r'<tr[^>]*>([\s\S]*?)</tr>', caseSensitive: false),
    (m) {
      final cells = RegExp(
        r'<t[hd][^>]*>([\s\S]*?)</t[hd]>',
        caseSensitive: false,
      ).allMatches(m[1]!).map((c) => c[1]!.trim()).toList();
      return '\n| ${cells.join(' | ')} |';
    },
  );
  s = s.replaceAll(
    RegExp(
      r'</?(p|div|blockquote|ul|ol|table|thead|tbody|section|article)[^>]*>',
      caseSensitive: false,
    ),
    '\n',
  );
  s = _unescapeHtml(s.replaceAll(RegExp(r'<[^>]+>'), ''));
  return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// Fetches a public Rentry page's Markdown. Tries the raw text, then the edit
/// page's source, then the rendered page. Only Rentry hosts are contacted.
class RentryImporter {
  RentryImporter({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;
  static const maxBytes = 1024 * 1024;

  Future<({String? markdown, String? error})> fetch(String url) async {
    final slug = rentrySlug(url);
    if (slug == null) return (markdown: null, error: 'notRentry');
    Future<String?> get(String path) async {
      try {
        final r = await _client
            .get(
              Uri.https('rentry.co', path),
              headers: const {'Accept': 'text/plain,text/html'},
            )
            .timeout(timeout);
        if (r.statusCode != 200 || r.bodyBytes.length > maxBytes) return null;
        return utf8.decode(r.bodyBytes, allowMalformed: true);
      } on TimeoutException {
        return null;
      } on SocketException {
        throw const SocketException('offline');
      } catch (_) {
        return null;
      }
    }

    try {
      final raw = await get('/$slug/raw');
      if (raw != null && !raw.trimLeft().startsWith('<'))
        return (markdown: sanitizeRentry(raw), error: null);
      final edit = await get('/$slug/edit');
      final src = edit == null ? null : markdownFromEditPage(edit);
      if (src != null) return (markdown: sanitizeRentry(src), error: null);
      final page = await get('/$slug');
      if (page != null) {
        final md = htmlToMarkdown(page);
        if (md.isNotEmpty) return (markdown: sanitizeRentry(md), error: null);
      }
      return (markdown: null, error: 'notFound');
    } on SocketException {
      return (markdown: null, error: 'offline');
    }
  }
}

// ── Rentry extensions ───────────────────────────────────────────────────────

/// `[TOC]` becomes a list of the page's headings.
String expandRentryToc(String src) {
  if (!src.contains('[TOC]')) return src;
  final heads = RegExp(r'^(#{1,4})\s+(.+)$', multiLine: true)
      .allMatches(src)
      .map((m) => '${'  ' * (m[1]!.length - 1)}- ${m[2]!.trim()}')
      .join('\n');
  return src.replaceAll('[TOC]', heads.isEmpty ? '' : '$heads\n');
}

class _AlignBlock extends md.BlockSyntax {
  const _AlignBlock();
  @override
  RegExp get pattern => RegExp(r'^\s*->(.*?)(<-|->)\s*$');
  @override
  md.Node? parse(md.BlockParser parser) {
    final lines = <String>[];
    String? kind;
    while (!parser.isDone) {
      final m = pattern.firstMatch(parser.current.content);
      if (m == null) break;
      kind ??= m[2];
      lines.add(m[1]!.trim());
      parser.advance();
    }
    final e = md.Element.empty('ralign');
    e.attributes['src'] = lines.join('\n');
    e.attributes['side'] = kind == '->' ? 'right' : 'center';
    return e;
  }
}

class _AdmonitionBlock extends md.BlockSyntax {
  const _AdmonitionBlock();
  @override
  RegExp get pattern =>
      RegExp(r'^\s*!!!\s*(note|info|warning|danger|greentext)?\s*(.*)$');
  @override
  md.Node? parse(md.BlockParser parser) {
    final m = pattern.firstMatch(parser.current.content)!;
    parser.advance();
    final body = <String>[];
    while (!parser.isDone &&
        RegExp(r'^(\t|    )').hasMatch(parser.current.content)) {
      body.add(parser.current.content.replaceFirst(RegExp(r'^(\t|    )'), ''));
      parser.advance();
    }
    final e = md.Element.empty('radmon');
    e.attributes['kind'] = m[1] ?? 'note';
    e.attributes['title'] = (m[2] ?? '').trim();
    e.attributes['src'] = body.join('\n');
    return e;
  }
}

class _ColorInline extends md.InlineSyntax {
  _ColorInline() : super(r'%(#?[A-Za-z0-9]{3,20})%(.+?)%%');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final e = md.Element.text('rcolor', match[2]!);
    e.attributes['c'] = match[1]!;
    parser.addNode(e);
    return true;
  }
}

class _HighlightInline extends md.InlineSyntax {
  _HighlightInline() : super(r'==([^=\n]+)==');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('rmark', match[1]!));
    return true;
  }
}

const _named = <String, int>{
  'red': 0xFFE53935,
  'green': 0xFF43A047,
  'blue': 0xFF1E88E5,
  'yellow': 0xFFFDD835,
  'orange': 0xFFFB8C00,
  'purple': 0xFF8E24AA,
  'pink': 0xFFEC407A,
  'teal': 0xFF00897B,
  'grey': 0xFF757575,
  'gray': 0xFF757575,
  'black': 0xFF000000,
  'white': 0xFFFFFFFF,
  'brown': 0xFF6D4C41,
  'cyan': 0xFF00ACC1,
  'magenta': 0xFFD81B60,
  'gold': 0xFFD4AF37,
  'violet': 0xFF7E57C2,
  'lime': 0xFFC0CA33,
};

Color? rentryColor(String c) {
  final s = c.toLowerCase();
  if (_named.containsKey(s)) return Color(_named[s]!);
  final hex = s.startsWith('#') ? s.substring(1) : s;
  if (RegExp(r'^[0-9a-f]{6}$').hasMatch(hex))
    return Color(0xFF000000 | int.parse(hex, radix: 16));
  if (RegExp(r'^[0-9a-f]{3}$').hasMatch(hex))
    return Color(
      0xFF000000 |
          int.parse(hex.split('').map((x) => '$x$x').join(), radix: 16),
    );
  return null;
}

class _TextBuilder extends MarkdownElementBuilder {
  _TextBuilder(this.style);
  final TextStyle Function(md.Element e, TextStyle? parent) style;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Text.rich(
    TextSpan(
      text: element.textContent,
      style: style(element, preferredStyle ?? parentStyle),
    ),
  );
}

class _BlockBuilder extends MarkdownElementBuilder {
  _BlockBuilder(this.build);
  final Widget Function(BuildContext context, md.Element e) build;
  @override
  bool isBlockElement() => true;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => build(context, element);
}

/// Renders Rentry-flavoured Markdown safely. [scale] sizes the text (a page
/// element passes its page scale).
class RentryMarkdownView extends StatelessWidget {
  const RentryMarkdownView(
    this.source, {
    super.key,
    this.scale = 1,
    this.color,
    this.align = WrapAlignment.start,
  });
  final String source;
  final double scale;
  final Color? color;
  final WrapAlignment align;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium!.copyWith(
      color: color ?? theme.colorScheme.onSurface,
    );
    final sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: base,
      textScaler: TextScaler.linear(scale.clamp(0.3, 4.0)),
      textAlign: align,
      h1Align: align,
      h2Align: align,
      h3Align: align,
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      tableBorder: TableBorder.all(color: theme.colorScheme.outlineVariant),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.2),
        ),
      ),
    );
    return MarkdownBody(
      data: expandRentryToc(sanitizeRentry(source)),
      styleSheet: sheet,
      softLineBreak: true,
      onTapLink: (_, href, _) => launchSafeExternalUri(href),
      imageBuilder: (uri, title, alt) {
        if (uri.scheme != 'https' && uri.scheme != 'http')
          return Text('[${alt ?? 'image'}]');
        return Image.network(
          uri.toString(),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Text(
            '[${alt ?? 'image'}]',
            style: base.copyWith(color: theme.hintColor),
          ),
        );
      },
      extensionSet: md.ExtensionSet(
        [
          const _AlignBlock(),
          const _AdmonitionBlock(),
          ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        ],
        [
          _ColorInline(),
          _HighlightInline(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
      builders: {
        'rcolor': _TextBuilder(
          (e, parent) => (parent ?? base).copyWith(
            color: rentryColor(e.attributes['c'] ?? ''),
          ),
        ),
        'rmark': _TextBuilder(
          (e, parent) => (parent ?? base).copyWith(
            backgroundColor: const Color(0x66FFE066),
          ),
        ),
        'ralign': _BlockBuilder(
          (context, e) => SizedBox(
            width: double.infinity,
            child: RentryMarkdownView(
              e.attributes['src'] ?? '',
              scale: scale,
              color: color,
              align: e.attributes['side'] == 'right'
                  ? WrapAlignment.end
                  : WrapAlignment.center,
            ),
          ),
        ),
        'radmon': _BlockBuilder((context, e) {
          final kind = e.attributes['kind'] ?? 'note';
          final tone = switch (kind) {
            'warning' => const Color(0xFFF9A825),
            'danger' => const Color(0xFFE53935),
            'greentext' => const Color(0xFF43A047),
            'info' => const Color(0xFF1E88E5),
            _ => theme.colorScheme.primary,
          };
          final title = e.attributes['title'] ?? '';
          final body = e.attributes['src'] ?? '';
          return Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 4 * scale),
            padding: EdgeInsets.all(10 * scale),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: tone, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  RentryMarkdownView(
                    body.isEmpty ? title : '**$title**',
                    scale: scale,
                    color: color,
                  ),
                if (body.isNotEmpty)
                  RentryMarkdownView(body, scale: scale, color: color),
              ],
            ),
          );
        }),
      },
    );
  }
}

// ── Editor ──────────────────────────────────────────────────────────────────

/// Edits Rentry-style Markdown with a live preview: import from a Rentry
/// link or pasted text, format with the toolbar, export as a .md file.
/// Returns the Markdown, or null if cancelled.
Future<String?> showRentryEditor(
  BuildContext context, {
  String initial = '',
  RentryImporter? importer,
}) => PrismSheet.showFullScreen<String>(
  context: context,
  builder: (ctx, scroll) => _RentryEditor(initial: initial, importer: importer),
);

class _RentryEditor extends StatefulWidget {
  const _RentryEditor({required this.initial, this.importer});
  final String initial;
  final RentryImporter? importer;
  @override
  State<_RentryEditor> createState() => _RentryEditorState();
}

class _RentryEditorState extends State<_RentryEditor> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  )..addListener(_changed);
  final _url = TextEditingController();
  Timer? _debounce;
  String _preview = '';
  bool _showPreview = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _preview = widget.initial;
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _preview = _c.text);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    _url.dispose();
    super.dispose();
  }

  void _wrap(String before, [String? after]) {
    final sel = _c.selection;
    final text = _c.text;
    final a = sel.isValid ? sel.start : text.length,
        b = sel.isValid ? sel.end : text.length;
    final inner = text.substring(a, b);
    final close = after ?? before;
    _c.value = TextEditingValue(
      text: text.replaceRange(a, b, '$before$inner$close'),
      selection: TextSelection.collapsed(
        offset:
            a +
            before.length +
            inner.length +
            (inner.isEmpty ? 0 : close.length),
      ),
    );
  }

  void _line(String prefix) {
    final sel = _c.selection;
    final text = _c.text;
    final at = sel.isValid ? sel.start : text.length;
    final lineStart = text.lastIndexOf('\n', at == 0 ? 0 : at - 1) + 1;
    _c.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: at + prefix.length),
    );
  }

  void _insert(String block) {
    final sel = _c.selection;
    final text = _c.text;
    final at = sel.isValid ? sel.start : text.length;
    final pre = at > 0 && text[at - 1] != '\n' ? '\n' : '';
    _c.value = TextEditingValue(
      text: text.replaceRange(at, at, '$pre$block\n'),
      selection: TextSelection.collapsed(
        offset: at + pre.length + block.length + 1,
      ),
    );
  }

  Future<void> _import() async {
    final url = _url.text.trim();
    if (rentrySlug(url) == null) {
      PrismToast.show(
        context,
        message: tr(
          context,
          'That isn’t a Rentry link (rentry.co/… or rentry.org/…).',
          'Ese no es un enlace de Rentry.',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final r = await (widget.importer ?? RentryImporter()).fetch(url);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.markdown == null) {
      PrismToast.show(
        context,
        message: switch (r.error) {
          'offline' => tr(
            context,
            'Couldn’t reach Rentry. Check your connection.',
            'No se pudo conectar con Rentry.',
          ),
          _ => tr(
            context,
            'Couldn’t find a public page at that link.',
            'No se encontró una página pública en ese enlace.',
          ),
        },
      );
      return;
    }
    _c.text = r.markdown!;
    setState(() => _preview = r.markdown!);
    PrismToast.show(
      context,
      message: tr(
        context,
        'Imported. You can edit it freely.',
        'Importado. Puedes editarlo libremente.',
      ),
    );
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text;
    if (t == null || t.isEmpty) return;
    _insert(sanitizeRentry(t));
  }

  Future<void> _export() async {
    final text = _c.text;
    try {
      final dir = await getTemporaryDirectory();
      final f = File(p.join(dir.path, 'scrapbook-note.md'));
      await f.writeAsString(text);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path, mimeType: 'text/markdown')]),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted)
        PrismToast.show(
          context,
          message: tr(context, 'Markdown copied.', 'Markdown copiado.'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 820;
    Widget tool(IconData icon, String tip, VoidCallback f) =>
        IconButton(tooltip: tip, icon: Icon(icon, size: 20), onPressed: f);
    final editor = TextField(
      controller: _c,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      decoration: InputDecoration(
        hintText: tr(
          context,
          'Write Markdown, paste Rentry text, or import a link…',
          'Escribe Markdown, pega texto de Rentry o importa un enlace…',
        ),
        border: InputBorder.none,
      ),
    );
    final preview = SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: RentryMarkdownView(_preview),
    );
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(
            title: tr(context, 'Rentry note', 'Nota Rentry'),
            trailing: IconButton(
              tooltip: tr(context, 'Done', 'Listo'),
              icon: const Icon(Icons.check),
              onPressed: () =>
                  Navigator.of(context).pop(sanitizeRentry(_c.text)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: PrismTextField(
                    controller: _url,
                    hintText: 'rentry.co/…',
                    prefixIcon: const Icon(Icons.link),
                  ),
                ),
                const SizedBox(width: 8),
                PrismButton(
                  label: tr(context, 'Import', 'Importar'),
                  icon: Icons.download,
                  isLoading: _busy,
                  onPressed: _busy ? () {} : _import,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                tool(
                  Icons.format_bold,
                  tr(context, 'Bold', 'Negrita'),
                  () => _wrap('**'),
                ),
                tool(
                  Icons.format_italic,
                  tr(context, 'Italic', 'Cursiva'),
                  () => _wrap('*'),
                ),
                tool(
                  Icons.format_strikethrough,
                  tr(context, 'Strikethrough', 'Tachado'),
                  () => _wrap('~~'),
                ),
                tool(
                  Icons.highlight,
                  tr(context, 'Highlight', 'Resaltar'),
                  () => _wrap('=='),
                ),
                tool(
                  Icons.title,
                  tr(context, 'Heading', 'Título'),
                  () => _line('## '),
                ),
                tool(
                  Icons.format_list_bulleted,
                  tr(context, 'List', 'Lista'),
                  () => _line('- '),
                ),
                tool(
                  Icons.format_quote,
                  tr(context, 'Quote', 'Cita'),
                  () => _line('> '),
                ),
                tool(
                  Icons.code,
                  tr(context, 'Code', 'Código'),
                  () => _wrap('`'),
                ),
                tool(
                  Icons.link,
                  tr(context, 'Link', 'Enlace'),
                  () => _wrap('[', '](https://)'),
                ),
                tool(
                  Icons.image_outlined,
                  tr(context, 'Image', 'Imagen'),
                  () => _insert('![description](https://)'),
                ),
                tool(
                  Icons.table_chart_outlined,
                  tr(context, 'Table', 'Tabla'),
                  () => _insert(
                    '| Column | Column |\n| --- | --- |\n| Cell | Cell |',
                  ),
                ),
                tool(
                  Icons.horizontal_rule,
                  tr(context, 'Divider', 'Separador'),
                  () => _insert('***'),
                ),
                tool(
                  Icons.format_align_center,
                  tr(context, 'Centre', 'Centrar'),
                  () => _wrap('-> ', ' <-'),
                ),
                tool(
                  Icons.format_color_text,
                  tr(context, 'Colour', 'Color'),
                  () => _wrap('%purple% ', ' %%'),
                ),
                tool(
                  Icons.info_outline,
                  tr(context, 'Note box', 'Recuadro'),
                  () => _insert('!!! note A note'),
                ),
                tool(
                  Icons.content_paste,
                  tr(context, 'Paste Rentry text', 'Pegar texto de Rentry'),
                  _paste,
                ),
                tool(
                  Icons.ios_share,
                  tr(context, 'Export Markdown', 'Exportar Markdown'),
                  _export,
                ),
                if (!wide)
                  tool(
                    _showPreview ? Icons.edit_note : Icons.visibility_outlined,
                    _showPreview
                        ? tr(context, 'Show editor', 'Mostrar editor')
                        : tr(context, 'Show preview', 'Mostrar vista previa'),
                    () => setState(() => _showPreview = !_showPreview),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: editor,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: preview),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: editor,
                        ),
                      ),
                      if (_showPreview) ...[
                        const Divider(height: 1),
                        Expanded(child: preview),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
