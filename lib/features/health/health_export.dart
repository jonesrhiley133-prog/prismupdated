import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/health/health_model.dart';
import 'package:prism_plurality/features/health/health_widgets.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_checkbox_row.dart';

/// User-initiated summary of Health records. Only records the current alter
/// may see are offered; the user reviews dates, alters and fields first.
/// Names and private notes are left out unless chosen.
Future<void> showHealthExport(BuildContext context) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (ctx, scroll) => _HealthExport(scroll: scroll),
);

enum _Field { severity, timing, locations, followups, episodes, measurements, details, notes, names }

String _fieldLabel(_Field f, bool es) => switch (f) {
  _Field.severity => es ? 'Gravedad y puntuación' : 'Severity and ratings',
  _Field.timing => es ? 'Inicio, fin y evolución' : 'Onset, end and course',
  _Field.locations => es ? 'Ubicaciones en el cuerpo' : 'Body locations',
  _Field.followups => es ? 'Seguimientos' : 'Follow-ups',
  _Field.episodes => es ? 'Episodios' : 'Episodes',
  _Field.measurements => es ? 'Temperaturas (introducidas)' : 'Temperatures (self-entered)',
  _Field.details => es ? 'Desencadenantes, alivio y efectos' : 'Triggers, relief and effects',
  _Field.notes => es ? 'Notas privadas' : 'Private notes',
  _Field.names => es ? 'Nombres de los alters' : 'Alter names',
};

class _HealthExport extends ConsumerStatefulWidget {
  const _HealthExport({required this.scroll});
  final ScrollController scroll;
  @override
  ConsumerState<_HealthExport> createState() => _HealthExportState();
}

class _HealthExportState extends ConsumerState<_HealthExport> {
  int _days = 30;
  Set<String>? _alters;
  final Set<_Field> _fields = {_Field.severity, _Field.timing, _Field.locations, _Field.followups, _Field.episodes, _Field.measurements, _Field.details};
  bool _preview = false;

  String _build(List<TrackerRecord> records, Map<String, Member> members, List<BodySpot> spots, bool es, String locale) {
    final now = DateTime.now();
    final from = _days == 0 ? DateTime(1970) : now.subtract(Duration(days: _days));
    final df = DateFormat.yMMMd(locale).add_jm();
    final checkins = [
      for (final r in records)
        if (r.kind == TrackerKind.healthCheckin && !r.happenedAt.isBefore(from) && _included(r)) r,
    ]..sort((a, b) => a.happenedAt.compareTo(b.happenedAt));
    final followups = [for (final r in records) if (r.kind == TrackerKind.healthFollowup) r];
    final episodes = {for (final r in records) if (r.kind == TrackerKind.healthEpisode) r.id: r};
    final b = StringBuffer()
      ..writeln(es ? 'Resumen de síntomas' : 'Symptom summary')
      ..writeln(es
          ? 'Periodo: ${_days == 0 ? 'todo' : 'últimos $_days días'} · generado ${DateFormat.yMMMd(locale).format(now)}'
          : 'Period: ${_days == 0 ? 'all time' : 'last $_days days'} · generated ${DateFormat.yMMMd(locale).format(now)}')
      ..writeln(es ? 'Registrado por la persona usuaria; no son diagnósticos.' : 'Recorded by the user; these are observations, not diagnoses.')
      ..writeln();
    if (checkins.isEmpty) b.writeln(es ? 'No hay entradas en este periodo.' : 'No entries in this period.');
    for (final c in checkins) {
      final who = Attribution.of(c);
      b.writeln('■ ${df.format(c.happenedAt)}${c.timePrecision == TimePrecision.approx ? (es ? ' (aprox.)' : ' (approx.)') : ''}${c.backdated ? (es ? ' — registrado ${df.format(c.createdAt.toLocal())}' : ' — recorded ${df.format(c.createdAt.toLocal())}') : ''}');
      if (_fields.contains(_Field.names)) b.writeln('  ${es ? 'Sobre' : 'About'}: ${attributionText(who, members, es, preferDisplayName: ref.read(memberNamePreferDisplayProvider))}');
      if (_fields.contains(_Field.episodes) && c.episodeId != null && episodes[c.episodeId] != null) b.writeln('  ${es ? 'Episodio' : 'Episode'}: ${episodes[c.episodeId]!.title}');
      if (c.symptoms.isEmpty && c.body != null) b.writeln('  ${c.body}');
      for (final s in c.symptoms) {
        final parts = <String>[s.label];
        if (_fields.contains(_Field.severity)) {
          if (s.severity != null) parts.add(severityLabel(s.severity!, es));
          if (s.score != null) parts.add('${s.score}/10');
        }
        b.writeln('  • ${parts.join(' — ')}');
        if (_fields.contains(_Field.timing)) {
          if (s.onset != null) b.writeln('    ${es ? 'Inicio' : 'Onset'}: ${df.format(s.onset!)}${s.onsetPrecision == TimePrecision.approx ? (es ? ' (aprox.)' : ' (approx.)') : ''}');
          if (s.onsetPrecision == TimePrecision.unknown) b.writeln('    ${es ? 'Inicio: desconocido' : 'Onset: unknown'}');
          if (s.end != null) b.writeln('    ${es ? 'Fin' : 'End'}: ${df.format(s.end!)}');
          if (s.course.isNotEmpty) b.writeln('    ${es ? 'Evolución' : 'Course'}: ${s.course.map((id) => courseOptions.firstWhere((o) => o.$1 == id, orElse: () => (id, id, id))).map((o) => es ? o.$3 : o.$2).join(', ')}');
        }
        if (_fields.contains(_Field.locations)) {
          final mine = spots.where((p) => s.spotIds.contains(p.id));
          for (final p in mine) {
            b.writeln('    ${es ? 'Ubicación' : 'Location'}: ${[p.placeLabel(es), ...p.descriptors.map((d) => d.label)].join(' · ')}${p.spreads.isNotEmpty ? ' → ${p.spreads.map((x) => x.label(es)).join(' → ')}' : ''}');
          }
        }
        if (_fields.contains(_Field.details)) {
          if (s.triggers != null) b.writeln('    ${es ? 'Desencadenantes' : 'Triggers'}: ${s.triggers}');
          if (s.relief != null) b.writeln('    ${es ? 'Alivio' : 'Relief'}: ${s.relief}');
          if (s.tried != null) b.writeln('    ${es ? 'Probado' : 'Tried'}: ${s.tried}');
          if (s.after != null) b.writeln('    ${es ? 'Después' : 'Afterwards'}: ${s.after}');
          if (s.impact.isNotEmpty) b.writeln('    ${es ? 'Afecta a' : 'Affects'}: ${s.impact.map((id) => impactOptions.firstWhere((o) => o.$1 == id, orElse: () => (id, id, id))).map((o) => es ? o.$3 : o.$2).join(', ')}');
        }
        if (_fields.contains(_Field.measurements) && s.tempValue != null) b.writeln('    ${es ? 'Temperatura' : 'Temperature'}: ${s.tempValue} °${s.tempUnit} (${es ? 'introducida' : 'self-entered'})');
        if (_fields.contains(_Field.notes) && s.notes != null) b.writeln('    ${es ? 'Notas' : 'Notes'}: ${s.notes}');
      }
      if (_fields.contains(_Field.notes) && c.symptoms.isNotEmpty && c.body != null) b.writeln('  ${es ? 'Notas' : 'Notes'}: ${c.body}');
      if (_fields.contains(_Field.followups)) {
        final mine = followups.where((f) => f.parentId == c.id).toList()..sort((a, b) => a.happenedAt.compareTo(b.happenedAt));
        for (final f in mine) {
          final st = FollowStatus.values.where((s) => s.name == f.str('status')).firstOrNull ?? FollowStatus.still;
          b.writeln('  ↳ ${df.format(f.happenedAt)}: ${followStatusLabel(st, es)}${_fields.contains(_Field.notes) && f.body != null ? ' — ${f.body}' : ''}');
        }
      }
      b.writeln();
    }
    final days = daysWithLoggedSymptom(checkins, from, now.add(const Duration(minutes: 1)));
    b.writeln(es ? 'Días con algún síntoma registrado: $days. Los días sin registro no se cuentan como días sin síntomas.' : 'Days with a logged symptom: $days. Days without a log aren’t counted as symptom-free.');
    return b.toString();
  }

  bool _included(TrackerRecord r) {
    final a = _alters;
    if (a == null) return true;
    final who = Attribution.of(r);
    if (who.scope == HealthScope.system) return a.contains('system');
    if (who.scope == HealthScope.unsure) return a.contains('unsure');
    return who.subjects.any(a.contains);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final records = ref.watch(visibleHealthRecordsProvider).value ?? const <TrackerRecord>[];
    final members = {for (final m in ref.watch(userVisibleMembersProvider).value ?? const <Member>[]) m.id: m};
    final spots = ref.watch(bodySpotsProvider);
    final subjectIds = <String>{
      for (final r in records)
        if (r.kind == TrackerKind.healthCheckin) ...Attribution.of(r).subjects,
    };
    final text = _build(records, members, spots, es, context.dateLocale);
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(title: es ? 'Exportar resumen' : 'Export summary'),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  controller: widget.scroll,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    Text(
                      es ? 'Revisa qué se incluye antes de compartir. Solo aparecen entradas que puedes ver ahora.' : 'Review what’s included before sharing. Only entries you can see right now are offered.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    HealthFormLabel(es ? 'Fechas' : 'Dates'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (d, label) in [(7, es ? '7 días' : '7 days'), (30, es ? '30 días' : '30 days'), (90, es ? '90 días' : '90 days'), (0, es ? 'Todo' : 'All time')])
                          PrismChip(label: label, selected: _days == d, onTap: () => setState(() => _days = d)),
                      ],
                    ),
                    HealthFormLabel(es ? 'Alters' : 'Alters'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        PrismChip(label: es ? 'Todos los visibles' : 'All visible', selected: _alters == null, onTap: () => setState(() => _alters = null)),
                        for (final id in subjectIds)
                          if (members[id] != null)
                            PrismChip(
                              label: memberLabel(members[id]!, preferDisplayName: ref.watch(memberNamePreferDisplayProvider)),
                              selected: _alters?.contains(id) ?? false,
                              onTap: () => setState(() {
                                final next = {...?_alters};
                                next.contains(id) ? next.remove(id) : next.add(id);
                                _alters = next.isEmpty ? null : next;
                              }),
                            ),
                        for (final (id, label) in [('system', context.l10n.trackerWholeSystem), ('unsure', es ? 'No se sabe quién' : 'Unsure who')])
                          PrismChip(
                            label: label,
                            selected: _alters?.contains(id) ?? false,
                            onTap: () => setState(() {
                              final next = {...?_alters};
                              next.contains(id) ? next.remove(id) : next.add(id);
                              _alters = next.isEmpty ? null : next;
                            }),
                          ),
                      ],
                    ),
                    HealthFormLabel(es ? 'Incluir' : 'Include'),
                    PrismSurface(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final f in _Field.values)
                            PrismCheckboxRow(title: Text(_fieldLabel(f, es)), subtitle: f == _Field.names
                                  ? Text(es ? 'Desactivado por defecto' : 'Off by default')
                                  : f == _Field.notes
                                  ? Text(es ? 'Tus notas libres; desactivado por defecto' : 'Your free-text notes; off by default')
                                  : null, value: _fields.contains(f), onChanged: (v) => setState(() => v == true ? _fields.add(f) : _fields.remove(f)), dense: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrismButton(
                      label: _preview ? (es ? 'Ocultar vista previa' : 'Hide preview') : (es ? 'Ver vista previa' : 'Preview'),
                      icon: PhosphorIcons.eye(),
                      expanded: true,
                      onPressed: () => setState(() => _preview = !_preview),
                    ),
                    if (_preview) ...[
                      const SizedBox(height: 12),
                      PrismSurface(
                        child: SelectableText(text, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'], height: 1.45)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: PrismButton(
                            label: es ? 'Copiar' : 'Copy',
                            icon: PhosphorIcons.copy(),
                            expanded: true,
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: text));
                              if (context.mounted) PrismToast.show(context, message: es ? 'Copiado' : 'Copied', icon: PhosphorIcons.check());
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrismButton(
                            label: es ? 'Compartir' : 'Share',
                            icon: PhosphorIcons.export(),
                            tone: PrismButtonTone.filled,
                            expanded: true,
                            onPressed: () => SharePlus.instance.share(ShareParams(text: text, subject: es ? 'Resumen de síntomas' : 'Symptom summary')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
