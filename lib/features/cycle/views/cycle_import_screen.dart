import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/cycle/providers/cycle_providers.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_import.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Import period history from a file: Prism CSV/JSON, Clue's data export,
/// or a table from another tracker. Shows what will change before saving.
class CycleImportScreen extends ConsumerStatefulWidget {
  const CycleImportScreen({super.key});

  @override
  ConsumerState<CycleImportScreen> createState() => _CycleImportScreenState();
}

class _CycleImportScreenState extends ConsumerState<CycleImportScreen> {
  String? _fileName;
  String? _content;
  String? _error;
  int _unspecified = 3;
  bool _fillBlanksOnly = true;
  String? _memberId;
  bool _busy = false;

  CycleParseResult? get _parsed {
    final c = _content;
    if (c == null) return null;
    try {
      return parseCycleFile(_fileName ?? '', c, unspecified: _unspecified);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pick() async {
    setState(() => _error = null);
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'json', 'txt', 'cluedata', 'zip'],
      withData: true,
    );
    final f = res?.files.firstOrNull;
    if (f == null || f.bytes == null) return;
    try {
      String text;
      final b = f.bytes!;
      if (b.length > 4 && b[0] == 0x50 && b[1] == 0x4B) {
        final zip = ZipDecoder().decodeBytes(b);
        final files = [
          for (final e in zip.files)
            if (e.isFile &&
                RegExp(r'\.(json|csv)$', caseSensitive: false).hasMatch(e.name))
              e,
        ]..sort((a, b) => b.size.compareTo(a.size));
        if (files.isEmpty) throw const FormatException('no data file');
        text = utf8.decode(
          files.first.content as List<int>,
          allowMalformed: true,
        );
      } else {
        text = utf8.decode(b, allowMalformed: true);
      }
      final parsed = parseCycleFile(f.name, text);
      setState(() {
        _fileName = f.name;
        _content = text;
        if (parsed.days.isEmpty)
          _error = tr(
            context,
            "Couldn't find any period days in this file. It needs a date column and a flow or period column (or start/end dates).",
            'No se encontraron días de periodo. El archivo necesita una columna de fecha y otra de flujo o periodo (o fechas de inicio/fin).',
          );
      });
    } catch (_) {
      setState(
        () => _error = tr(
          context,
          "This file couldn't be read. Try a CSV or JSON export.",
          'No se pudo leer el archivo. Prueba con una exportación CSV o JSON.',
        ),
      );
    }
  }

  Future<void> _import(CycleParseResult parsed) async {
    setState(() => _busy = true);
    try {
      final (cr, up, same) = await ref
          .read(cycleImportWriterProvider)
          .apply(
            parsed.days,
            fillBlanksOnly: _fillBlanksOnly,
            memberId: _memberId,
          );
      if (!mounted) return;
      PrismToast.show(
        context,
        message: tr(
          context,
          'Imported: $cr new, $up updated, $same already there',
          'Importado: $cr nuevos, $up actualizados, $same ya estaban',
        ),
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted)
        setState(
          () => _error = tr(
            context,
            'Import failed. Nothing was changed.',
            'Falló la importación. No se cambió nada.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parsed;
    final plan = parsed == null
        ? null
        : planCycleImport(
            ref.watch(cycleEntriesByDateProvider),
            parsed.days,
            fillBlanksOnly: _fillBlanksOnly,
          );
    final fmt = DateFormat.yMMMd();
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(
          context,
          'Import cycle history',
          'Importar historial del ciclo',
        ),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'From a file', 'Desde un archivo'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      context,
                      'Works with Clue\'s data export, Prism exports, and CSV or JSON from other trackers (a date plus flow, or period start and end dates). Apps that write to Health Connect or Apple Health can also sync periods from Fitness → Health integrations.',
                      'Funciona con la exportación de Clue, exportaciones de Prism y CSV o JSON de otras apps (fecha y flujo, o inicio y fin del periodo). Las apps que escriben en Health Connect o Apple Health también pueden sincronizar periodos desde Ejercicio → Integraciones.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  PrismButton(
                    label:
                        _fileName ??
                        tr(context, 'Choose file', 'Elegir archivo'),
                    icon: Icons.upload_file_outlined,
                    onPressed: _pick,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
            if (parsed != null && parsed.days.isNotEmpty && plan != null) ...[
              const SizedBox(height: 12),
              PrismSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'Preview', 'Vista previa'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${parsed.format} · ${parsed.days.length} ${tr(context, 'days', 'días')} · ${fmt.format(parsed.first!)} – ${fmt.format(parsed.last!)}',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Stat(
                          label: tr(context, 'New', 'Nuevos'),
                          value: plan.create.length,
                          color: Colors.green,
                        ),
                        _Stat(
                          label: tr(context, 'Updated', 'Actualizados'),
                          value: plan.update.length,
                          color: Colors.orange,
                        ),
                        _Stat(
                          label: tr(
                            context,
                            'Already logged',
                            'Ya registrados',
                          ),
                          value: plan.unchanged,
                          color: theme.colorScheme.outline,
                        ),
                        if (parsed.skippedRows > 0)
                          _Stat(
                            label: tr(
                              context,
                              'Rows skipped',
                              'Filas omitidas',
                            ),
                            value: parsed.skippedRows,
                            color: theme.colorScheme.outline,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final d in parsed.days.reversed.take(6))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${fmt.format(d.day)} · ${_flowName(context, d.flow)}${d.symptoms.isEmpty ? '' : ' · ${d.symptoms.take(3).join(', ')}'}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrismSurface(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    PrismListRow(
                      title: Text(
                        tr(
                          context,
                          'When the flow isn\'t given',
                          'Si no se indica el flujo',
                        ),
                      ),
                      trailing: PrismSelect<int>.compact(
                        value: _unspecified,
                        menuWidth: 160,
                        items: [
                          for (final f in const [2, 3, 4])
                            PrismSelectItem(
                              value: f,
                              label: _flowName(context, f),
                            ),
                        ],
                        onChanged: (v) => setState(() => _unspecified = v ?? 3),
                      ),
                    ),
                    PrismSwitchRow(
                      title: tr(
                        context,
                        'Keep what I logged',
                        'Mantener lo que registré',
                      ),
                      subtitle: tr(
                        context,
                        'Only fill empty days and add new symptoms. Turn off to let a heavier imported flow replace yours.',
                        'Solo completa días vacíos y añade síntomas. Desactívalo para que un flujo importado mayor reemplace el tuyo.',
                      ),
                      value: _fillBlanksOnly,
                      onChanged: (v) => setState(() => _fillBlanksOnly = v),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: TrackerMemberPicker(
                        label: tr(
                          context,
                          'Whose cycle is this?',
                          '¿De quién es este ciclo?',
                        ),
                        value: _memberId,
                        onChanged: (id) => setState(() => _memberId = id),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrismButton(
                label: tr(
                  context,
                  'Import ${plan.create.length + plan.update.length} days',
                  'Importar ${plan.create.length + plan.update.length} días',
                ),
                icon: Icons.download_done,
                tone: PrismButtonTone.filled,
                expanded: true,
                isLoading: _busy,
                enabled: plan.create.length + plan.update.length > 0,
                onPressed: () => _import(parsed),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _flowName(BuildContext c, int f) => switch (f) {
  1 => tr(c, 'Spotting', 'Manchado'),
  2 => tr(c, 'Light', 'Ligero'),
  3 => tr(c, 'Medium', 'Medio'),
  4 => tr(c, 'Heavy', 'Abundante'),
  _ => tr(c, 'None', 'Ninguno'),
};

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$value $label',
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );
}
