import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:prism_plurality/core/services/files/prism_file_dialog_service.dart';
import 'package:prism_plurality/features/dictionary/importer/wiki_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Flags saved on a term (main flag first, then alternates). Older imports
/// only kept `images`; those are shown as untitled flags.
List<WikiFlag> termFlags(TrackerRecord t) {
  final raw = t.fields['flags'];
  final flags = [
    for (final f in (raw is List ? raw : const [])) ?WikiFlag.fromJson(f),
  ];
  return flags;
}

String _ext(String url) {
  final m = RegExp(
    r'\.(png|svg|jpe?g|gif|webp)(?:$|[?#/])',
    caseSensitive: false,
  ).firstMatch(Uri.tryParse(url)?.path ?? url);
  return (m?.group(1) ?? 'png').toLowerCase().replaceAll('jpeg', 'jpg');
}

String _mime(String ext) => switch (ext) {
  'svg' => 'image/svg+xml',
  'jpg' => 'image/jpeg',
  'gif' => 'image/gif',
  'webp' => 'image/webp',
  _ => 'image/png',
};

String _safeName(String s) => s
    .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

Future<Uint8List> _download(String url) async {
  final r = await http
      .get(Uri.parse(url), headers: {'user-agent': WikiHttp.userAgent})
      .timeout(const Duration(seconds: 30));
  if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
  return r.bodyBytes;
}

/// Saves one flag to the device (the system "save to" dialog).
Future<void> downloadFlag(
  BuildContext context,
  WidgetRef ref,
  WikiFlag f, {
  String? term,
}) async {
  final title = tr(context, 'Save flag', 'Guardar bandera');
  try {
    final bytes = await _download(f.url);
    final ext = _ext(f.url);
    final name = _safeName(f.label.isEmpty ? (term ?? 'flag') : f.label);
    final out = await ref
        .read(prismFileDialogServiceProvider)
        .saveBytes(
          bytes: bytes,
          suggestedName: '$name.$ext',
          allowedExtensions: [ext],
          mimeType: _mime(ext),
          dialogTitle: title,
        );
    if (context.mounted && out.didSave)
      PrismToast.show(
        context,
        message: tr(context, 'Flag saved', 'Bandera guardada'),
        icon: PhosphorIcons.check(),
      );
  } catch (_) {
    if (context.mounted)
      PrismToast.show(
        context,
        message: tr(
          context,
          'Couldn’t download this flag.',
          'No se pudo descargar la bandera.',
        ),
        icon: PhosphorIcons.warning(),
      );
  }
}

/// Saves every flag of a term as one ZIP.
Future<void> downloadAllFlags(
  BuildContext context,
  WidgetRef ref,
  List<WikiFlag> flags,
  String term,
) async {
  final archive = Archive();
  var n = 0;
  for (final f in flags) {
    try {
      final bytes = await _download(f.url);
      n++;
      final name = _safeName(f.label.isEmpty ? '$term $n' : f.label);
      archive.addFile(ArchiveFile('$name.${_ext(f.url)}', bytes.length, bytes));
    } catch (_) {}
  }
  if (n == 0) {
    if (context.mounted)
      PrismToast.show(
        context,
        message: tr(
          context,
          'Couldn’t download the flags.',
          'No se pudieron descargar las banderas.',
        ),
        icon: PhosphorIcons.warning(),
      );
    return;
  }
  final zip = Uint8List.fromList(ZipEncoder().encode(archive));
  if (!context.mounted) return;
  final out = await ref
      .read(prismFileDialogServiceProvider)
      .saveBytes(
        bytes: zip,
        suggestedName: '${_safeName(term)} flags.zip',
        allowedExtensions: const ['zip'],
        mimeType: 'application/zip',
        dialogTitle: tr(context, 'Save flags', 'Guardar banderas'),
      );
  if (context.mounted && out.didSave)
    PrismToast.show(
      context,
      message: tr(context, '$n flags saved', '$n banderas guardadas'),
      icon: PhosphorIcons.check(),
    );
}

/// The flags section of a term: main flag, alternates, view and download.
class TermFlags extends ConsumerWidget {
  const TermFlags({super.key, required this.term});
  final TrackerRecord term;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final flags = termFlags(term);
    if (flags.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  flags.length == 1
                      ? tr(context, 'Flag', 'Bandera')
                      : tr(
                          context,
                          'Flags · ${flags.length}',
                          'Banderas · ${flags.length}',
                        ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (flags.length > 1)
                PrismButton(
                  label: tr(context, 'Download all', 'Descargar todas'),
                  icon: PhosphorIcons.downloadSimple(),
                  density: PrismControlDensity.compact,
                  onPressed: () =>
                      downloadAllFlags(context, ref, flags, term.title),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: flags.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final f = flags[i];
              final label = f.label.isEmpty
                  ? (i == 0
                        ? tr(context, 'Main flag', 'Bandera principal')
                        : tr(
                            context,
                            'Alternate ${i + 1}',
                            'Alternativa ${i + 1}',
                          ))
                  : f.label;
              return Semantics(
                button: true,
                label: tr(context, '$label. Open', '$label. Abrir'),
                child: InkWell(
                  borderRadius: prismCorners(context, 10),
                  onTap: () => _open(context, ref, f, label),
                  child: SizedBox(
                    width: 132,
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: prismCorners(context, 8),
                            child: ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Image.network(
                                  f.url,
                                  fit: BoxFit.contain,
                                  cacheWidth: 264,
                                  errorBuilder: (_, _, _) => Icon(
                                    PhosphorIcons.flag(),
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          i == 0 && flags.length > 1 ? '★ $label' : label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, WidgetRef ref, WikiFlag f, String label) =>
      PrismSheet.showFullScreen(
        context: context,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              label,
              style: Theme.of(
                ctx,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            InteractiveViewer(
              maxScale: 6,
              child: Image.network(
                f.url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Text(
                  tr(
                    ctx,
                    'Couldn’t load this image.',
                    'No se pudo cargar la imagen.',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismButton(
                  label: tr(
                    ctx,
                    'Download to device',
                    'Descargar al dispositivo',
                  ),
                  icon: PhosphorIcons.downloadSimple(),
                  tone: PrismButtonTone.filled,
                  onPressed: () => downloadFlag(ctx, ref, f, term: term.title),
                ),
                PrismButton(
                  label: ctx.l10n.dictSource,
                  icon: AppIcons.globe,
                  onPressed: () => showDialogSafeCopy(ctx, f.url),
                ),
              ],
            ),
          ],
        ),
      );
}

/// Shows the image address so it can be copied.
void showDialogSafeCopy(BuildContext context, String url) => PrismSheet.show(
  context: context,
  title: tr(context, 'Image address', 'Dirección de la imagen'),
  builder: (ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: SelectableText(url),
  ),
);
