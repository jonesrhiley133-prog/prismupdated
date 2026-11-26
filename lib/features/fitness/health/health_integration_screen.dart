import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/fitness/health/fitness_file_import.dart';
import 'package:prism_plurality/features/fitness/health/health_sync.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_checkbox_row.dart';

final healthAvailabilityProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.read(healthGatewayProvider).availability(),
);

String platformName(BuildContext c, HealthGateway g) =>
    g.ios ? 'Apple Health' : 'Health Connect';

/// The connection's state, as the user should see it.
enum ProviderState {
  unavailable,
  permissionNeeded,
  partial,
  syncing,
  imported,
  zeroRecords,
  failed,
  connected,
}

ProviderState providerState(
  HealthSettings s,
  String? availability,
  bool syncing,
) {
  if (availability != null && availability != 'available')
    return ProviderState.unavailable;
  if (!s.connected) return ProviderState.permissionNeeded;
  if (syncing) return ProviderState.syncing;
  final results = s.lastResults;
  if (s.lastError != null &&
      s.lastError != 'denied' &&
      results.values.every((r) => r.status != 'ok' && r.status != 'empty'))
    return ProviderState.failed;
  if (s.denied.isNotEmpty ||
      results.values.any((r) => r.status == 'denied' || r.status == 'failed'))
    return ProviderState.partial;
  if (results.isNotEmpty && results.values.every((r) => r.status == 'empty'))
    return ProviderState.zeroRecords;
  if (results.values.any((r) => r.status == 'ok'))
    return ProviderState.imported;
  return ProviderState.connected;
}

/// Fitness › Connected Apps: live sync with the platform health store,
/// file imports, and what has been imported.
class HealthIntegrationScreen extends ConsumerStatefulWidget {
  const HealthIntegrationScreen({super.key});
  @override
  ConsumerState<HealthIntegrationScreen> createState() =>
      _HealthIntegrationScreenState();
}

class _HealthIntegrationScreenState
    extends ConsumerState<HealthIntegrationScreen> {
  bool _syncing = false;
  bool _importing = false;

  Future<void> _syncNow({bool force = false}) async {
    setState(() => _syncing = true);
    final r = await ref.read(healthSyncProvider).sync(force: force);
    if (!mounted) return;
    setState(() => _syncing = false);
    PrismToast.show(
      context,
      message: r.error != null
          ? tr(
              context,
              'Sync failed. Details are on this page.',
              'La sincronización falló. Los detalles están en esta página.',
            )
          : r.partial
          ? tr(
              context,
              'Synced what’s allowed. Some types need permission.',
              'Sincronizado lo permitido. Algunos tipos necesitan permiso.',
            )
          : (r.workouts + r.updated + r.days == 0
                ? tr(
                    context,
                    'Connected, but no new records came back.',
                    'Conectado, pero no llegaron registros nuevos.',
                  )
                : tr(
                    context,
                    '${r.workouts} new workouts · ${r.updated} updated · ${r.days} days of totals',
                    '${r.workouts} entrenamientos nuevos · ${r.updated} actualizados · ${r.days} días de totales',
                  )),
      icon: r.error == null ? PhosphorIcons.check() : PhosphorIcons.warning(),
    );
  }

  Future<void> _connect(Set<HealthCategory> current) async {
    final picked = await showCategoryPicker(context, current);
    if (picked == null || picked.isEmpty || !mounted) return;
    final ok = await ref
        .read(healthSyncProvider)
        .connect(
          picked,
          historyDays: ref.read(healthSettingsProvider).historyDays,
        );
    if (!mounted) return;
    if (ok) {
      await _syncNow();
    } else {
      PrismToast.show(
        context,
        message: tr(
          context,
          'No access was granted. Nothing will be read.',
          'No se concedió acceso. No se leerá nada.',
        ),
        icon: PhosphorIcons.warning(),
      );
    }
  }

  Future<void> _importFile() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip', 'xml', 'csv'],
      allowMultiple: true,
      withData: true,
    );
    if (res == null || res.files.isEmpty || !mounted) return;
    setState(() => _importing = true);
    try {
      ImportPreview preview;
      final files = [
        for (final f in res.files)
          if (f.bytes != null) f,
      ];
      if (files.isEmpty)
        throw ImportFormatException('The file couldn’t be read.');
      if (files.length > 1 &&
          files.every((f) => f.name.toLowerCase().endsWith('.csv'))) {
        preview = await compute(_parseSamsungMany, [
          for (final f in files) String.fromCharCodes(f.bytes!),
        ]);
      } else {
        preview = await compute(_parseOne, (
          files.first.bytes!,
          files.first.name,
        ));
      }
      if (!mounted) return;
      final ok = await showImportPreview(context, preview);
      if (ok != true || !mounted) return;
      final w = ref.read(fitnessWriterProvider);
      final alter = ref.read(healthSettingsProvider).defaultAlter;
      final (created, updated, dups) = await w.upsertWorkouts(
        preview.workouts,
        platform: exportPlatform(preview.kind),
        memberId: alter,
      );
      final days = await w.upsertDaily(
        preview.daily,
        platform: exportPlatform(preview.kind),
        memberId: alter,
      );
      await _recordFileImport(preview, created, updated, dups, days);
      if (mounted) {
        PrismToast.show(
          context,
          message: tr(
            context,
            'Imported: $created new workouts, $updated updated, $dups already there · $days days of totals',
            'Importado: $created entrenamientos nuevos, $updated actualizados, $dups ya existían · $days días de totales',
          ),
          icon: PhosphorIcons.check(),
        );
      }
    } on ImportFormatException catch (e) {
      if (mounted)
        PrismToast.show(
          context,
          message: e.message,
          icon: PhosphorIcons.warning(),
        );
    } catch (_) {
      if (mounted)
        PrismToast.show(
          context,
          message: tr(
            context,
            'This file couldn’t be imported.',
            'No se pudo importar este archivo.',
          ),
          icon: PhosphorIcons.warning(),
        );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _recordFileImport(
    ImportPreview p,
    int created,
    int updated,
    int dups,
    int days,
  ) async {
    final t = ref.read(trackerNotifierProvider.notifier);
    final title = exportPlatform(p.kind);
    final prev =
        (ref.read(trackerKindProvider(TrackerKind.fitnessSource)).value ??
                const <TrackerRecord>[])
            .where((r) => r.title == title)
            .firstOrNull;
    final fields = {
      'fileSource': p.kind.name,
      'lastImport': DateTime.now().toIso8601String(),
      'lastCounts': {
        'created': created,
        'updated': updated,
        'duplicates': dups,
        'days': days,
        'skipped': p.skipped,
      },
      'from': p.from?.toIso8601String(),
      'to': p.to?.toIso8601String(),
    };
    if (prev == null) {
      await t.create(
        kind: TrackerKind.fitnessSource,
        title: title,
        fields: fields,
      );
    } else {
      await t.save(prev.withFields(fields));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = ref.watch(healthGatewayProvider);
    final s = ref.watch(healthSettingsProvider);
    final avail = ref.watch(healthAvailabilityProvider).value;
    final all =
        ref.watch(trackerRecordsProvider).value ?? const <TrackerRecord>[];
    final bySource = <String, int>{};
    for (final r in all) {
      if ((r.kind == TrackerKind.fitnessWorkout && r.flag('imported')) ||
          r.kind == TrackerKind.fitnessDaily) {
        final k = r.str('platform') ?? 'healthconnect';
        bySource[k] = (bySource[k] ?? 0) + 1;
      }
    }
    final fileImports = [
      for (final r
          in ref.watch(trackerKindProvider(TrackerKind.fitnessSource)).value ??
              const <TrackerRecord>[])
        if (r.str('fileSource') != null) r,
    ];

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Connected apps', 'Apps conectadas'),
        showBackButton: true,
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 32),
          children: [
            Text(
              tr(
                context,
                'Bring steps, workouts and more into Fitness. Prism only reads what you allow, and keeps manual entries separate from imported ones.',
                'Trae pasos, entrenamientos y más a Ejercicio. Prism solo lee lo que permitas y separa lo manual de lo importado.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            PrismSectionHeader(
              title: tr(context, 'LIVE SYNC', 'SINCRONIZACIÓN'),
            ),
            if (!g.supported)
              PrismSurface(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      PhosphorIcons.deviceMobile(),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(
                          context,
                          'Live sync needs the Prism app on Android (Health Connect) or iPhone (Apple Health). Here, import an export file instead — see below.',
                          'La sincronización en vivo necesita la app de Prism en Android (Health Connect) o iPhone (Apple Health). Aquí puedes importar un archivo de exportación (abajo).',
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else
              _ProviderCard(
                name: platformName(context, g),
                ios: g.ios,
                settings: s,
                availability: avail,
                syncing: _syncing,
                onConnect: () => _connect(s.categories),
                onSync: () => _syncNow(),
                onManage: () => _connect(s.categories),
                onInstall: () => g.install(),
                onDisconnect: () async {
                  final keep = await PrismDialog.confirm(
                    context: context,
                    title: tr(
                      context,
                      'Disconnect ${platformName(context, g)}?',
                      '¿Desconectar ${platformName(context, g)}?',
                    ),
                    message: tr(
                      context,
                      'Prism stops reading new data. Records already imported stay in Fitness; you can remove them below.',
                      'Prism deja de leer datos nuevos. Lo ya importado se queda en Ejercicio; puedes borrarlo abajo.',
                    ),
                    confirmLabel: tr(context, 'Disconnect', 'Desconectar'),
                  );
                  if (keep) await ref.read(healthSyncProvider).disconnect();
                },
              ),
            if (g.supported && s.connected) ...[
              PrismSectionHeader(title: tr(context, 'HISTORY', 'HISTORIAL')),
              PrismSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr(
                        context,
                        'How far back the first import (and a re-import) reads.',
                        'Hasta cuándo lee la primera importación (y una reimportación).',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final d in const [7, 30, 90, 365])
                          PrismChip(
                            label: tr(context, '$d days', '$d días'),
                            selected: s.historyDays == d,
                            onTap: () async {
                              await ref.read(healthSyncProvider).saveSettings({
                                'historyDays': d,
                              });
                              if (d > 30)
                                await ref
                                    .read(healthGatewayProvider)
                                    .requestHistory();
                            },
                          ),
                      ],
                    ),
                    if (!g.ios && s.historyDays > 30)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          tr(
                            context,
                            'Health Connect asks separately before sharing data older than 30 days.',
                            'Health Connect pide permiso aparte para datos de más de 30 días.',
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PrismButton(
                        label: tr(
                          context,
                          'Re-import this range',
                          'Reimportar este periodo',
                        ),
                        icon: PhosphorIcons.arrowCounterClockwise(),
                        density: PrismControlDensity.compact,
                        isLoading: _syncing,
                        onPressed: () => _syncNow(force: true),
                      ),
                    ),
                  ],
                ),
              ),
              PrismSectionHeader(
                title: tr(
                  context,
                  'ATTRIBUTION & SCHEDULE',
                  'ATRIBUCIÓN Y HORARIO',
                ),
              ),
              PrismSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr(
                        context,
                        'Imported activity belongs to',
                        'La actividad importada pertenece a',
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AlterChoice(
                      selected: s.defaultAlter,
                      onChanged: (id) => ref
                          .read(healthSyncProvider)
                          .saveSettings({'defaultAlter': id}),
                    ),
                    const SizedBox(height: 8),
                    PrismSwitchRow(
                      title: tr(
                        context,
                        'Sync automatically',
                        'Sincronizar automáticamente',
                      ),
                      subtitle: tr(
                        context,
                        'When Prism opens and every 30 minutes while it’s open. “Sync now” always works.',
                        'Al abrir Prism y cada 30 minutos mientras está abierta. «Sincronizar ahora» siempre funciona.',
                      ),
                      value: s.autoSync,
                      onChanged: (v) => ref
                          .read(healthSyncProvider)
                          .saveSettings({'autoSync': v}),
                    ),
                  ],
                ),
              ),
            ],
            PrismSectionHeader(
              title: tr(context, 'IMPORT A FILE', 'IMPORTAR UN ARCHIVO'),
            ),
            PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(
                      context,
                      'Apple Health export (.zip or export.xml), Google Fit Takeout “Daily activity metrics.csv” (or its zip), or Samsung Health CSV files (step_daily_trend and exercise). Importing the same file again won’t duplicate anything.',
                      'Exportación de Apple Health (.zip o export.xml), “Daily activity metrics.csv” de Google Fit Takeout (o su zip) o CSV de Samsung Health (step_daily_trend y exercise). Importar el mismo archivo otra vez no duplica nada.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PrismButton(
                      label: tr(context, 'Import file…', 'Importar archivo…'),
                      icon: PhosphorIcons.fileArrowUp(),
                      isLoading: _importing,
                      onPressed: _importFile,
                    ),
                  ),
                  for (final r in fileImports) ...[
                    const SizedBox(height: 10),
                    _FileImportRow(r: r),
                  ],
                ],
              ),
            ),
            if (bySource.isNotEmpty) ...[
              PrismSectionHeader(
                title: tr(context, 'IMPORTED RECORDS', 'REGISTROS IMPORTADOS'),
              ),
              PrismSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final e in bySource.entries)
                      PrismListRow(
                        leading: Icon(
                          e.key.startsWith('file:')
                              ? PhosphorIcons.file()
                              : PhosphorIcons.heartbeat(),
                          size: 20,
                        ),
                        title: Text(_platformLabel(e.key)),
                        subtitle: Text(
                          tr(
                            context,
                            '${e.value} records',
                            '${e.value} registros',
                          ),
                        ),
                        trailing: PrismButton(
                          label: tr(context, 'Remove', 'Borrar'),
                          density: PrismControlDensity.compact,
                          tone: PrismButtonTone.destructive,
                          onPressed: () async {
                            final ok = await PrismDialog.confirm(
                              context: context,
                              title: tr(
                                context,
                                'Remove records from ${_platformLabel(e.key)}?',
                                '¿Borrar los registros de ${_platformLabel(e.key)}?',
                              ),
                              message: tr(
                                context,
                                'Only records imported from this source are removed. Manual entries and imported workouts you edited stay.',
                                'Solo se borra lo importado de esta fuente. Lo manual y los entrenamientos importados que editaste se quedan.',
                              ),
                              confirmLabel: tr(context, 'Remove', 'Borrar'),
                              destructive: true,
                            );
                            if (ok)
                              await ref
                                  .read(healthSyncProvider)
                                  .removeImported(platform: e.key);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

ImportPreview _parseOne((Uint8List, String) a) =>
    parseFitnessExport(a.$1, a.$2);
ImportPreview _parseSamsungMany(List<String> texts) => parseSamsungCsvs(texts);

String _platformLabel(String p) => switch (p) {
  'healthconnect' => 'Health Connect',
  'healthkit' => 'Apple Health',
  'file:apple' => 'Apple Health file',
  'file:googlefit' => 'Google Fit file',
  'file:samsung' => 'Samsung Health file',
  _ => p,
};

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.name,
    required this.ios,
    required this.settings,
    required this.availability,
    required this.syncing,
    required this.onConnect,
    required this.onSync,
    required this.onManage,
    required this.onInstall,
    required this.onDisconnect,
  });

  final String name;
  final bool ios;
  final HealthSettings settings;
  final String? availability;
  final bool syncing;
  final VoidCallback onConnect;
  final VoidCallback onSync;
  final VoidCallback onManage;
  final VoidCallback onInstall;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = settings;
    final state = providerState(s, availability, syncing);
    final df = DateFormat.MMMd(context.dateLocale).add_jm();
    final (label, color, icon) = switch (state) {
      ProviderState.unavailable => (
        availability == 'updateRequired'
            ? tr(context, 'Needs an update', 'Necesita actualizarse')
            : tr(context, 'Not available', 'No disponible'),
        theme.colorScheme.onSurfaceVariant,
        PhosphorIcons.prohibit(),
      ),
      ProviderState.permissionNeeded => (
        tr(context, 'Permission needed', 'Necesita permiso'),
        theme.colorScheme.onSurfaceVariant,
        PhosphorIcons.lockSimple(),
      ),
      ProviderState.partial => (
        tr(context, 'Partly allowed', 'Permitido en parte'),
        theme.colorScheme.tertiary,
        PhosphorIcons.circleHalf(),
      ),
      ProviderState.syncing => (
        tr(context, 'Syncing…', 'Sincronizando…'),
        theme.colorScheme.primary,
        PhosphorIcons.arrowsClockwise(),
      ),
      ProviderState.imported => (
        tr(context, 'Imported', 'Importado'),
        theme.colorScheme.primary,
        PhosphorIcons.checkCircle(),
      ),
      ProviderState.zeroRecords => (
        tr(context, 'Allowed · no records found', 'Permitido · sin registros'),
        theme.colorScheme.tertiary,
        PhosphorIcons.tray(),
      ),
      ProviderState.failed => (
        tr(context, 'Last sync failed', 'Falló la última sincronización'),
        theme.colorScheme.error,
        PhosphorIcons.warning(),
      ),
      ProviderState.connected => (
        tr(context, 'Connected', 'Conectado'),
        theme.colorScheme.primary,
        PhosphorIcons.plugsConnected(),
      ),
    };
    return PrismSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: prismCorners(context, 12),
                ),
                child: Icon(
                  PhosphorIcons.heartbeat(),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: prismCorners(context, 8),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state == ProviderState.unavailable) ...[
            Text(
              tr(
                context,
                'Health Connect isn’t installed or needs an update on this phone.',
                'Health Connect no está instalado o necesita actualizarse en este teléfono.',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: PrismButton(
                label: tr(
                  context,
                  'Get Health Connect',
                  'Obtener Health Connect',
                ),
                tone: PrismButtonTone.filled,
                onPressed: onInstall,
              ),
            ),
          ] else ...[
            _InfoLine(
              label: tr(context, 'Last attempt', 'Último intento'),
              value: s.lastAttempt == null
                  ? '—'
                  : df.format(s.lastAttempt!.toLocal()),
            ),
            _InfoLine(
              label: tr(
                context,
                'Last successful sync',
                'Última sincronización correcta',
              ),
              value: s.lastSync == null
                  ? '—'
                  : df.format(s.lastSync!.toLocal()),
            ),
            if (s.sourcesSeen.isNotEmpty)
              _InfoLine(
                label: tr(context, 'Sources seen', 'Fuentes vistas'),
                value: s.sourcesSeen.toSet().join(', '),
              ),
            if (s.connected) ...[
              const SizedBox(height: 10),
              for (final c in s.categories)
                _CategoryLine(
                  category: c,
                  result: s.lastResults[c],
                  denied: s.denied.contains(c),
                ),
            ],
            if (state == ProviderState.failed && s.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr(context, 'Error: ${s.lastError}', 'Error: ${s.lastError}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (!ios &&
                (state == ProviderState.zeroRecords ||
                    state == ProviderState.permissionNeeded))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  tr(
                    context,
                    'Using Samsung Health or another app? Turn on its Health Connect sync (Samsung Health › Settings › Health Connect) so it writes data Prism can read.',
                    '¿Usas Samsung Health u otra app? Activa su sincronización con Health Connect (Samsung Health › Ajustes › Health Connect) para que escriba datos que Prism pueda leer.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!s.connected)
                  PrismButton(
                    label: tr(context, 'Connect', 'Conectar'),
                    icon: PhosphorIcons.plugsConnected(),
                    tone: PrismButtonTone.filled,
                    onPressed: onConnect,
                  )
                else ...[
                  PrismButton(
                    label: tr(context, 'Sync now', 'Sincronizar ahora'),
                    icon: PhosphorIcons.arrowsClockwise(),
                    tone: PrismButtonTone.filled,
                    isLoading: syncing,
                    onPressed: onSync,
                  ),
                  PrismButton(
                    label: tr(
                      context,
                      'Manage permissions',
                      'Gestionar permisos',
                    ),
                    icon: PhosphorIcons.shieldCheck(),
                    onPressed: onManage,
                  ),
                  PrismButton(
                    label: tr(context, 'Disconnect', 'Desconectar'),
                    icon: PhosphorIcons.plugs(),
                    onPressed: onDisconnect,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryLine extends StatelessWidget {
  const _CategoryLine({
    required this.category,
    required this.result,
    required this.denied,
  });
  final HealthCategory category;
  final CategoryResult? result;
  final bool denied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    final (text, color) = denied || r?.status == 'denied'
        ? (
            tr(
              context,
              'Not allowed — sync skips it',
              'No permitido: se omite',
            ),
            theme.colorScheme.onSurfaceVariant,
          )
        : r == null
        ? (
            tr(
              context,
              'Allowed · not synced yet',
              'Permitido · aún sin sincronizar',
            ),
            theme.colorScheme.onSurfaceVariant,
          )
        : switch (r.status) {
            'failed' => (
              tr(
                context,
                'Failed — will retry next sync',
                'Falló: se reintentará',
              ),
              theme.colorScheme.error,
            ),
            'empty' => (
              tr(
                context,
                'Allowed · nothing in range',
                'Permitido · nada en este periodo',
              ),
              theme.colorScheme.onSurfaceVariant,
            ),
            _ => (
              category == HealthCategory.workouts
                  ? tr(
                      context,
                      '${r.created} new · ${r.updated} updated · ${r.duplicates} already there',
                      '${r.created} nuevos · ${r.updated} actualizados · ${r.duplicates} ya existían',
                    )
                  : tr(
                      context,
                      '${r.updated} days updated',
                      '${r.updated} días actualizados',
                    ),
              theme.colorScheme.primary,
            ),
          };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              healthCategoryText(context, category),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileImportRow extends StatelessWidget {
  const _FileImportRow({required this.r});
  final TrackerRecord r;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = (r.fields['lastCounts'] as Map?) ?? const {};
    final at = DateTime.tryParse('${r.fields['lastImport']}');
    final df = DateFormat.yMMMd(context.dateLocale);
    return Row(
      children: [
        Icon(
          PhosphorIcons.file(),
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${_platformLabel(r.title)} · ${at == null ? '' : df.format(at.toLocal())} · ${tr(context, '${c['created'] ?? 0} new, ${c['updated'] ?? 0} updated, ${c['days'] ?? 0} days, ${c['skipped'] ?? 0} rows skipped', '${c['created'] ?? 0} nuevos, ${c['updated'] ?? 0} actualizados, ${c['days'] ?? 0} días, ${c['skipped'] ?? 0} filas omitidas')}',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _AlterChoice extends ConsumerWidget {
  const _AlterChoice({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(userVisibleMemberListProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        PrismChip(
          label: tr(context, 'Shared system activity', 'Actividad del sistema'),
          selected: selected == null,
          onTap: () => onChanged(null),
        ),
        for (final m in members)
          PrismChip(
            label: m.effectiveName(preferDisplayName: prefer),
            selected: selected == m.id,
            onTap: () => onChanged(m.id),
          ),
      ],
    );
  }
}

/// Choose which data types to request. Optional types start off.
Future<Set<HealthCategory>?> showCategoryPicker(
  BuildContext context,
  Set<HealthCategory> current,
) => PrismSheet.show<Set<HealthCategory>>(
  context: context,
  title: tr(context, 'What should Prism read?', '¿Qué debe leer Prism?'),
  subtitle: tr(
    context,
    'You’ll confirm each type in the system dialog. You can allow some and not others.',
    'Confirmarás cada tipo en el diálogo del sistema. Puedes permitir unos y no otros.',
  ),
  builder: (ctx) => _CategoryPicker(initial: current),
);

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker({required this.initial});
  final Set<HealthCategory> initial;
  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  late final Set<HealthCategory> _cats = {...widget.initial};
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in HealthCategory.values)
          PrismCheckboxRow(
            title: Text(healthCategoryText(context, c)),
            subtitle: Text(healthCategoryWhy(context, c)),
            value: _cats.contains(c),
            onChanged: (v) =>
                setState(() => v == true ? _cats.add(c) : _cats.remove(c)),
          ),
        const SizedBox(height: 12),
        PrismButton(
          label: tr(context, 'Continue', 'Continuar'),
          tone: PrismButtonTone.filled,
          expanded: true,
          enabled: _cats.isNotEmpty,
          onPressed: () => Navigator.of(context).pop(_cats),
        ),
      ],
    );
  }
}

/// Shows what a file contains before importing it.
Future<bool?> showImportPreview(BuildContext context, ImportPreview p) {
  final df = DateFormat.yMMMd(context.dateLocale);
  final counts = p.countsByField;
  String fieldName(String f) => switch (f) {
    'steps' => tr(context, 'Steps', 'Pasos'),
    'distanceKm' => tr(context, 'Distance', 'Distancia'),
    'calories' => tr(context, 'Calories', 'Calorías'),
    'activeMinutes' => tr(context, 'Active minutes', 'Minutos activos'),
    'heartRateAvg' => tr(context, 'Heart rate', 'Frecuencia cardiaca'),
    'sleepMinutes' => tr(context, 'Sleep', 'Sueño'),
    _ => f,
  };
  return PrismSheet.show<bool>(
    context: context,
    title: exportKindLabel(p.kind),
    subtitle: p.from == null
        ? null
        : '${df.format(p.from!)} – ${df.format(p.to!)}',
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.workouts.isNotEmpty)
          PrismListRow(
            dense: true,
            leading: Icon(PhosphorIcons.barbell(), size: 18),
            title: Text(tr(context, 'Workouts', 'Entrenamientos')),
            trailing: Text('${p.workouts.length}'),
          ),
        for (final e in counts.entries)
          PrismListRow(
            dense: true,
            leading: Icon(PhosphorIcons.calendarBlank(), size: 18),
            title: Text(fieldName(e.key)),
            trailing: Text(tr(context, '${e.value} days', '${e.value} días')),
          ),
        PrismListRow(
          dense: true,
          leading: Icon(PhosphorIcons.skipForward(), size: 18),
          title: Text(
            tr(
              context,
              'Rows skipped (unreadable or unsupported)',
              'Filas omitidas (ilegibles o no admitidas)',
            ),
          ),
          trailing: Text('${p.skipped}'),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            context,
            'Where two apps counted the same day, the larger total is used — never both added together.',
            'Si dos apps contaron el mismo día, se usa el total mayor; nunca se suman.',
          ),
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        PrismButton(
          label: tr(context, 'Import', 'Importar'),
          tone: PrismButtonTone.filled,
          expanded: true,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
}
