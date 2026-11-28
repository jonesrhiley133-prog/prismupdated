import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'package:prism_plurality/core/services/files/prism_file_dialog_service.dart';
import 'package:prism_plurality/features/experiences/export_kit.dart';
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Export or share a yumeship profile. You review exactly which parts go
/// out first; nothing is uploaded — files are saved only where you choose.
class YumeExportScreen extends ConsumerStatefulWidget {
  const YumeExportScreen({super.key, required this.shipId});
  final String shipId;
  @override
  ConsumerState<YumeExportScreen> createState() => _YumeExportScreenState();
}

class _YumeExportScreenState extends ConsumerState<YumeExportScreen> {
  final _key = GlobalKey();
  Set<String>? _fields;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(yumeShipByIdProvider(widget.shipId));
    if (s == null) return const SizedBox.shrink();
    final fields = _fields ??= {...s.exportFields};
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Export profile', 'Exportar perfil'),
        showBackButton: true,
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              tr(
                context,
                'Choose what appears. Only what’s ticked leaves Prism, and only when you save or copy it.',
                'Elige qué aparece. Solo lo marcado sale de Prism, y solo cuando lo guardes o copies.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in yumeExportFields.entries)
                  PrismChip(
                    label: f.value,
                    selected: fields.contains(f.key),
                    onTap: () => setState(() {
                      fields.contains(f.key)
                          ? fields.remove(f.key)
                          : fields.add(f.key);
                    }),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: YumeAction(
                label: tr(
                  context,
                  'Remember these choices',
                  'Recordar esta selección',
                ),
                onPressed: () async {
                  await ref.read(yumeActionsProvider).saveShip(s, {
                    'export': fields.toList(),
                  });
                  if (context.mounted)
                    PrismToast.success(
                      context,
                      message: tr(
                        context,
                        'Saved as this ship’s default',
                        'Guardado como predeterminado',
                      ),
                    );
                },
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: RepaintBoundary(
                key: _key,
                child: SizedBox(
                  width: 360,
                  child: YumeProfileCard(ship: s, fields: fields),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrismButton(
              label: tr(context, 'Save as image', 'Guardar como imagen'),
              icon: Icons.image_outlined,
              tone: PrismButtonTone.filled,
              expanded: true,
              isLoading: _busy,
              onPressed: () async {
                setState(() => _busy = true);
                final b = await captureBoundary(_key, pixelRatio: 3);
                final ok =
                    b != null && await saveImageBytes(ref, b, _slug(s.name));
                if (!mounted) return;
                setState(() => _busy = false);
                PrismToast.show(
                  context,
                  message: ok
                      ? tr(context, 'Image saved', 'Imagen guardada')
                      : tr(context, 'Not saved', 'No guardado'),
                );
              },
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: tr(context, 'Copy as text', 'Copiar como texto'),
              icon: Icons.copy,
              expanded: true,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: yumeProfileText(ref, s, fields)),
                );
                if (context.mounted)
                  PrismToast.success(
                    context,
                    message: tr(context, 'Copied', 'Copiado'),
                  );
              },
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: tr(
                context,
                'Save as a file (.json)',
                'Guardar como archivo (.json)',
              ),
              icon: Icons.save_alt,
              expanded: true,
              onPressed: () async {
                final json = const JsonEncoder.withIndent(' ').convert({
                  'format': 'prism.yumeship',
                  'version': yumeSchemaVersion,
                  'exportedAt': DateTime.now().toIso8601String(),
                  'profile': yumeProfileMap(ref, s, fields),
                });
                final out = await ref
                    .read(prismFileDialogServiceProvider)
                    .saveBytes(
                      bytes: Uint8List.fromList(utf8.encode(json)),
                      suggestedName: '${_slug(s.name)}.json',
                      allowedExtensions: const ['json'],
                      mimeType: 'application/json',
                    );
                if (context.mounted)
                  PrismToast.show(
                    context,
                    message:
                        out.pathOrUri != null || out.savedDisplayName != null
                        ? tr(context, 'File saved', 'Archivo guardado')
                        : tr(context, 'Not saved', 'No guardado'),
                  );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _slug(String s) {
  final out = s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return out.isEmpty ? 'yumeship' : out;
}

/// The profile as plain data, limited to [fields].
Map<String, Object?> yumeProfileMap(
  WidgetRef ref,
  YumeShip s,
  Set<String> fields,
) {
  final names = ref.read(yumeMemberNamesProvider);
  return {
    if (fields.contains('names')) 'name': s.name,
    if (fields.contains('names') && s.shipName.isNotEmpty)
      'shipName': s.shipName,
    if (fields.contains('names'))
      'fictionalOthers': [
        for (final f in s.fos)
          {
            'name': f.name,
            if (f.pronouns.isNotEmpty) 'pronouns': f.pronouns,
            if (fields.contains('source') && f.source.isNotEmpty)
              'source': f.source,
          },
      ],
    if (fields.contains('relTypes'))
      'relationship': [
        for (final t in s.relTypes) t == 'custom' ? s.relCustom : t,
      ],
    if (fields.contains('status') && s.status.isNotEmpty) 'status': s.status,
    if (fields.contains('anniversary') && s.anniversary != null)
      'anniversary': s.anniversary!.toIso8601String().substring(0, 10),
    if (fields.contains('sharing')) 'sharing': s.sharing,
    if (fields.contains('sharing') && s.boundaryNotice.isNotEmpty)
      'boundaryNotice': s.boundaryNotice,
    if (fields.contains('about') && s.about.isNotEmpty) 'about': s.about,
    if (fields.contains('tropes')) 'tropes': s.tropes,
    if (fields.contains('headcanons'))
      'headcanons': [for (final h in s.headcanons) h.text],
    if (fields.contains('lore') && s.lore.isNotEmpty) 'lore': s.lore,
    if (fields.contains('lore') && s.backstory.isNotEmpty)
      'backstory': s.backstory,
    if (fields.contains('sonas'))
      'sonas': [
        for (final id in s.sonaIds) ?ref.read(yumeSonaByIdProvider(id))?.name,
      ],
    if (fields.contains('owners'))
      'alters': [for (final o in s.owners) ?names[o]],
  };
}

String yumeProfileText(WidgetRef ref, YumeShip s, Set<String> fields) {
  final m = yumeProfileMap(ref, s, fields);
  final b = StringBuffer();
  if (m['name'] != null)
    b.writeln(
      '${s.symbol} ${m['name']}${m['shipName'] != null ? ' (${m['shipName']})' : ''}',
    );
  for (final f in (m['fictionalOthers'] as List?) ?? const []) {
    final x = f as Map;
    b.writeln(
      '• ${x['name']}${x['pronouns'] != null ? ' (${x['pronouns']})' : ''}${x['source'] != null ? ' — ${x['source']}' : ''}',
    );
  }
  void line(String k, String label) {
    final v = m[k];
    if (v == null) return;
    if (v is List) {
      if (v.isNotEmpty) b.writeln('$label: ${v.join(', ')}');
    } else {
      b.writeln('$label: $v');
    }
  }

  line('relationship', 'Relationship');
  line('status', 'Status');
  line('anniversary', 'Anniversary');
  if (m['sharing'] != null)
    b.writeln('Sharing: ${yumeSharing[m['sharing']]?.$1}');
  line('boundaryNotice', 'Boundaries');
  line('about', 'About');
  line('tropes', 'Tropes');
  final hc = (m['headcanons'] as List?) ?? const [];
  if (hc.isNotEmpty) {
    b.writeln('Headcanons:');
    for (final h in hc) {
      b.writeln('  – $h');
    }
  }
  line('backstory', 'Backstory');
  line('lore', 'Lore');
  line('sonas', 'Sonas');
  line('alters', 'Alters');
  return b.toString().trim();
}

/// A shareable card of a ship, showing only [fields].
class YumeProfileCard extends ConsumerWidget {
  const YumeProfileCard({super.key, required this.ship, required this.fields});
  final YumeShip ship;
  final Set<String> fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = yumeAccent(context, ship.accent);
    final theme = Theme.of(context);
    final m = yumeProfileMap(ref, ship, fields);
    final pics = fields.contains('pictures');
    return YumeFontScope(
      font: ship.font,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        child: YumeCard(
          accent: a,
          card: ship.card,
          frame: ship.frame,
          ribbon: ship.ribbon,
          stickers: ship.stickers,
          radius: 22,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (pics)
                    YumePairAvatars(
                      left: ship.avatar,
                      right: ship.fos.firstOrNull?.avatar,
                      accent: a,
                      symbol: ship.symbol,
                      size: 52,
                    )
                  else
                    Text(ship.symbol, style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m['name'] != null)
                          Text(
                            '${m['name']}',
                            style: theme.textTheme.titleLarge,
                          ),
                        if (m['shipName'] != null)
                          Text(
                            '${m['shipName']}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: a,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final f in (m['fictionalOthers'] as List?) ?? const [])
                Text(
                  '✦ ${(f as Map)['name']}${f['source'] != null ? ' · ${f['source']}' : ''}',
                  style: theme.textTheme.bodyMedium,
                ),
              if (m['relationship'] != null || m['status'] != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in (m['relationship'] as List?) ?? const [])
                      Chip(
                        label: Text(yumeRelTypes['$r']?.$1 ?? '$r'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (m['status'] != null)
                      Chip(
                        label: Text('${m['status']}'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              if (m['anniversary'] != null)
                Text('💍 ${yumeDate(ship.anniversary!)}'),
              if (m['sharing'] != null)
                Text(
                  '🤝 ${yumeSharing[m['sharing']]?.$1}',
                  style: theme.textTheme.bodySmall,
                ),
              if (m['boundaryNotice'] != null)
                Text(
                  '${m['boundaryNotice']}',
                  style: theme.textTheme.bodySmall,
                ),
              if (m['about'] != null) ...[
                const SizedBox(height: 8),
                Text('${m['about']}'),
              ],
              if ((m['tropes'] as List?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(
                  (m['tropes'] as List).join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              for (final h in ((m['headcanons'] as List?) ?? const []).take(5))
                Text('💭 $h', style: theme.textTheme.bodySmall),
              if ((m['sonas'] as List?)?.isNotEmpty ?? false)
                Text(
                  '🪞 ${(m['sonas'] as List).join(', ')}',
                  style: theme.textTheme.bodySmall,
                ),
              if ((m['alters'] as List?)?.isNotEmpty ?? false)
                Text(
                  '👤 ${(m['alters'] as List).join(', ')}',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              Text(
                'made with Prism',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
