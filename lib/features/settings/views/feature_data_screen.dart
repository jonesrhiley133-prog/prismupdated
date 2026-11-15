import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/core/features/data_reset.dart';
import 'package:prism_plurality/core/features/feature_registry.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

void openFeatureData(BuildContext context, String featureId) => GoRouter.of(context).push('/settings/features/data/$featureId');

int firstWeekdayOf(BuildContext context) {
  final i = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
  return i == 0 ? DateTime.sunday : i;
}

String periodText(BuildContext c, ResetPeriod p) => switch (p) {
  ResetPeriod.today => tr(c, 'Today', 'Hoy'),
  ResetPeriod.week => tr(c, 'This week', 'Esta semana'),
  ResetPeriod.month => tr(c, 'This month', 'Este mes'),
  ResetPeriod.year => tr(c, 'This year', 'Este año'),
  ResetPeriod.custom => tr(c, 'Custom dates', 'Fechas personalizadas'),
  ResetPeriod.all => tr(c, 'All data', 'Todos los datos'),
};

/// Data management for one feature: reset by period or clear everything.
class FeatureDataScreen extends ConsumerStatefulWidget {
  const FeatureDataScreen({super.key, required this.featureId});
  final String featureId;
  @override
  ConsumerState<FeatureDataScreen> createState() => _FeatureDataScreenState();
}

class _FeatureDataScreenState extends ConsumerState<FeatureDataScreen> {
  ResetPeriod _period = ResetPeriod.today;
  DateTime? _from;
  DateTime? _to;
  bool _busy = false;
  String? _lastBatch;

  PrismFeature? get _f => prismFeatureIndex[widget.featureId];

  ResetRange _range() => rangeFor(_period, DateTime.now(), firstWeekday: firstWeekdayOf(context), customStart: _from, customEnd: _to);

  Future<void> _run(ResetPeriod period) async {
    final f = _f!;
    if (period == ResetPeriod.custom && (_from == null || _to == null)) {
      PrismToast.show(context, message: tr(context, 'Choose a start and end date.', 'Elige fecha de inicio y fin.'));
      return;
    }
    setState(() => _busy = true);
    final svc = ref.read(dataResetServiceProvider);
    final range = period == _period ? _range() : rangeFor(period, DateTime.now(), firstWeekday: firstWeekdayOf(context));
    final plan = await svc.plan(f, period, range);
    if (!mounted) return;
    setState(() => _busy = false);
    if (plan.items.isEmpty) {
      PrismToast.show(context, message: tr(context, 'Nothing to reset for this period.', 'No hay nada que restablecer en este periodo.'));
      return;
    }
    final df = DateFormat.yMMMd(context.dateLocale);
    final counts = plan.countsBySource;
    String sourceLabel(String k) => switch (k) {
      'tracker.activity' => tr(context, 'Dated entries', 'Entradas con fecha'),
      'tracker.permanent' => tr(context, 'Long-term records and settings', 'Registros a largo plazo y ajustes'),
      _ => tr(context, resetSources[k]?.label.$1 ?? k, resetSources[k]?.label.$2 ?? k),
    };
    final undo = !plan.recoverable
        ? tr(context, 'This can’t be undone.', 'Esto no se puede deshacer.')
        : (plan.survivesRestart
              ? tr(context, 'You can undo this for $recoveryDays days (a recovery copy is kept on this device).', 'Puedes deshacerlo durante $recoveryDays días (se guarda una copia en este dispositivo).')
              : tr(context, 'You can undo this until you close Prism.', 'Puedes deshacerlo hasta que cierres Prism.'));
    final ok = await PrismDialog.confirm(
      context: context,
      title: period == ResetPeriod.all ? tr(context, 'Clear all ${f.name.$1} data?', '¿Borrar todos los datos de ${f.name.$2}?') : tr(context, 'Reset ${f.name.$1}?', '¿Restablecer ${f.name.$2}?'),
      message: [
        tr(context, 'Feature: ${f.name.$1}', 'Función: ${f.name.$2}'),
        period == ResetPeriod.all ? tr(context, 'Period: everything', 'Periodo: todo') : tr(context, 'Period: ${df.format(range.start)} – ${df.format(range.end.subtract(const Duration(days: 1)))}', 'Periodo: ${df.format(range.start)} – ${df.format(range.end.subtract(const Duration(days: 1)))}'),
        tr(context, '${plan.items.length} records will be removed:', 'Se quitarán ${plan.items.length} registros:'),
        for (final e in counts.entries) '• ${sourceLabel(e.key)}: ${e.value}',
        if (period != ResetPeriod.all && f.data.permanentKinds.isNotEmpty) tr(context, 'Long-term records and settings are kept.', 'Se conservan los registros a largo plazo y los ajustes.'),
        tr(context, 'Other features are not affected.', 'Las demás funciones no se ven afectadas.'),
        undo,
      ].join('\n'),
      destructive: true,
      confirmLabel: period == ResetPeriod.all ? tr(context, 'Clear all', 'Borrar todo') : tr(context, 'Reset', 'Restablecer'),
      cancelLabel: context.l10n.cancel,
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final id = await svc.execute(plan, periodLabel: period.name);
      if (!mounted) return;
      setState(() => _lastBatch = plan.recoverable ? id : null);
      PrismToast.show(context, message: tr(context, '${plan.items.length} records removed', 'Se quitaron ${plan.items.length} registros'), icon: PhosphorIcons.check());
    } catch (e) {
      if (mounted) PrismToast.show(context, message: tr(context, 'Reset failed: $e', 'Error al restablecer: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = _f;
    if (f == null) {
      return PrismPageScaffold(topBar: PrismTopBar(title: tr(context, 'Data management', 'Gestión de datos'), showBackButton: true), body: Center(child: Text(tr(context, 'Unknown feature.', 'Función desconocida.'))));
    }
    final df = DateFormat.yMMMd(context.dateLocale);
    final range = _range();
    final d = f.data;
    final logs = [for (final r in ref.watch(trackerKindProvider(TrackerKind.appResetLog)).value ?? const <TrackerRecord>[]) if (r.str('feature') == f.id) r];
    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, '${f.name.$1} · Data', '${f.name.$2} · Datos'), showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 32),
        children: [
          ClampedBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [Icon(f.icon, color: theme.colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(tr(context, f.name.$1, f.name.$2), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)))]),
                const SizedBox(height: 12),
                if (!d.hasAny)
                  PrismSurface(child: Text(d.note == null ? tr(context, 'This feature has no data of its own to reset.', 'Esta función no tiene datos propios que restablecer.') : tr(context, d.note!.$1, d.note!.$2)))
                else ...[
                  if (d.hasActivity) ...[
                    Text(tr(context, 'Reset data', 'Restablecer datos'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      tr(context, 'Removes only this feature’s dated entries in the chosen period (by your device’s time zone). Long-term records, settings and other features are untouched.', 'Quita solo las entradas con fecha de esta función en el periodo elegido (según la zona horaria del dispositivo). No toca registros a largo plazo, ajustes ni otras funciones.'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in const [ResetPeriod.today, ResetPeriod.week, ResetPeriod.month, ResetPeriod.year, ResetPeriod.custom])
                          PrismChip(label: periodText(context, p), selected: _period == p, onTap: () => setState(() => _period = p)),
                      ],
                    ),
                    if (_period == ResetPeriod.custom) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          PrismButton(
                            label: _from == null ? tr(context, 'From…', 'Desde…') : df.format(_from!),
                            icon: PhosphorIcons.calendar(),
                            onPressed: () async {
                              final v = await showPrismDatePicker(context: context, initialDate: _from ?? DateTime.now(), firstDate: DateTime(1990), lastDate: DateTime.now().add(const Duration(days: 366)));
                              if (v != null) setState(() => _from = v);
                            },
                          ),
                          PrismButton(
                            label: _to == null ? tr(context, 'To…', 'Hasta…') : df.format(_to!),
                            icon: PhosphorIcons.calendar(),
                            onPressed: () async {
                              final v = await showPrismDatePicker(context: context, initialDate: _to ?? _from ?? DateTime.now(), firstDate: _from ?? DateTime(1990), lastDate: DateTime.now().add(const Duration(days: 366)));
                              if (v != null) setState(() => _to = v);
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_period != ResetPeriod.custom || (_from != null && _to != null))
                      Text(tr(context, 'Covers ${df.format(range.start)} – ${df.format(range.end.subtract(const Duration(days: 1)))}', 'Abarca ${df.format(range.start)} – ${df.format(range.end.subtract(const Duration(days: 1)))}'), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerLeft, child: PrismButton(label: tr(context, 'Review & reset…', 'Revisar y restablecer…'), icon: PhosphorIcons.arrowCounterClockwise(), tone: PrismButtonTone.filled, isLoading: _busy, onPressed: _busy ? () {} : () => _run(_period))),
                  ] else
                    PrismSurface(child: Text(d.note == null ? tr(context, 'This feature keeps only long-term information, so there’s nothing to reset by date.', 'Esta función solo guarda información a largo plazo, así que no hay nada que restablecer por fecha.') : tr(context, d.note!.$1, d.note!.$2))),
                  if (_lastBatch != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(child: Text(tr(context, 'Reset done.', 'Restablecido.'), style: TextStyle(color: theme.colorScheme.onSecondaryContainer))),
                          PrismButton(
                            label: tr(context, 'Undo', 'Deshacer'),
                            density: PrismControlDensity.compact,
                            onPressed: () async {
                              final n = await ref.read(dataResetServiceProvider).undo(_lastBatch!);
                              if (!mounted) return;
                              setState(() => _lastBatch = null);
                              PrismToast.show(context, message: tr(context, '$n records restored', 'Se restauraron $n registros'), icon: PhosphorIcons.check());
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(tr(context, 'Clear all data', 'Borrar todos los datos'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.error)),
                  const SizedBox(height: 4),
                  Text(
                    tr(context, 'Removes everything this feature stores${d.permanentKinds.isNotEmpty ? ', including long-term records and its settings' : ''}. Alter profiles and other features are never affected.', 'Quita todo lo que guarda esta función${d.permanentKinds.isNotEmpty ? ', incluidos registros a largo plazo y sus ajustes' : ''}. Nunca afecta a los perfiles ni a otras funciones.'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: PrismButton(label: tr(context, 'Clear all ${f.name.$1} data…', 'Borrar todos los datos de ${f.name.$2}…'), tone: PrismButtonTone.destructive, onPressed: _busy ? () {} : () => _run(ResetPeriod.all))),
                ],
                if (logs.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(tr(context, 'Recent resets', 'Restablecimientos recientes'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final r in logs.take(10)) ResetLogRow(record: r),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One reset in the history (counts only, never the removed content).
class ResetLogRow extends ConsumerWidget {
  const ResetLogRow({super.key, required this.record, this.showFeature = false});
  final TrackerRecord record;
  final bool showFeature;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final df = DateFormat.yMMMd(context.dateLocale).add_jm();
    final f = prismFeatureIndex[record.str('feature')];
    final period = ResetPeriod.values.where((p) => p.name == record.str('period')).firstOrNull;
    final undone = record.flag('undone');
    final recoverable = record.flag('recoverable');
    final batch = record.str('batch');
    return PrismListRow(
      dense: true,
      leading: Icon(f?.icon ?? PhosphorIcons.database(), size: 20),
      title: Text([if (showFeature && f != null) tr(context, f.name.$1, f.name.$2), period == null ? (record.str('period') ?? '') : periodText(context, period)].join(' · ')),
      subtitle: Text('${df.format(record.occurredAt ?? record.createdAt)} · ${tr(context, '${record.integer('count') ?? 0} records', '${record.integer('count') ?? 0} registros')} · ${undone ? tr(context, 'undone', 'deshecho') : (recoverable ? tr(context, 'recoverable', 'recuperable') : tr(context, 'permanent', 'permanente'))}'),
      trailing: !undone && recoverable && batch != null
          ? FutureBuilder<bool>(
              future: ref.read(dataResetServiceProvider).canUndo(batch),
              builder: (context, snap) => snap.data == true
                  ? PrismButton(
                      label: tr(context, 'Undo', 'Deshacer'),
                      density: PrismControlDensity.compact,
                      onPressed: () async {
                        final n = await ref.read(dataResetServiceProvider).undo(batch);
                        if (context.mounted) PrismToast.show(context, message: tr(context, '$n records restored', 'Se restauraron $n registros'));
                      },
                    )
                  : Text(tr(context, 'expired', 'caducado'), style: theme.textTheme.labelSmall),
            )
          : null,
    );
  }
}

/// Every reset across Prism.
class ResetHistoryScreen extends ConsumerWidget {
  const ResetHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = [...ref.watch(trackerKindProvider(TrackerKind.appResetLog)).value ?? const <TrackerRecord>[]];
    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, 'Reset history', 'Historial de restablecimientos'), showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: logs.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(tr(context, 'No resets yet.', 'Aún no hay restablecimientos.'), textAlign: TextAlign.center)))
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 24),
              children: [
                ClampedBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(tr(context, 'Only the feature, dates and counts are kept here — never the removed content.', 'Aquí solo se guardan la función, las fechas y los recuentos, nunca el contenido eliminado.'), style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      for (final r in logs) ResetLogRow(record: r, showFeature: true),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Top-bar shortcut to a feature's Data management page.
class FeatureDataAction extends StatelessWidget {
  const FeatureDataAction({super.key, required this.featureId});
  final String featureId;
  @override
  Widget build(BuildContext context) => PrismTopBarAction(icon: PhosphorIcons.database(), tooltip: tr(context, 'Data management', 'Gestión de datos'), onPressed: () => openFeatureData(context, featureId));
}
