import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/habit.dart';
import 'package:prism_plurality/domain/models/habit_completion.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/habits/center/habit_center_data.dart';
import 'package:prism_plurality/features/habits/center/habit_visuals.dart';
import 'package:prism_plurality/features/habits/providers/habit_providers.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Logs a new completion ([editing] null) or edits one.
Future<void> showHabitLogSheet(
  BuildContext context, {
  required Habit habit,
  HabitCompletion? editing,
  int? minutes,
  bool focusNote = false,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) => _LogSheet(
    habit: habit,
    editing: editing,
    presetMinutes: minutes,
    focusNote: focusNote,
    scroll: scroll,
  ),
);

/// Opens a completion by id (used by the connections explorer).
void openHabitCompletion(BuildContext context, String id) {
  final container = ProviderScope.containerOf(context, listen: false);
  final c =
      (container.read(allCompletionsProvider).value ??
              const <HabitCompletion>[])
          .where((x) => x.id == id)
          .firstOrNull;
  if (c == null) return;
  final h = container.read(habitViewsProvider)[c.habitId]?.habit;
  if (h != null) showHabitLogSheet(context, habit: h, editing: c);
}

class _LogSheet extends ConsumerStatefulWidget {
  const _LogSheet({
    required this.habit,
    this.editing,
    this.presetMinutes,
    required this.focusNote,
    required this.scroll,
  });
  final Habit habit;
  final HabitCompletion? editing;
  final int? presetMinutes;
  final bool focusNote;
  final ScrollController scroll;
  @override
  ConsumerState<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends ConsumerState<_LogSheet> {
  late final HabitCompletion? e = widget.editing;
  late final HabitLog _log = e == null
      ? const HabitLog(null)
      : (ref.read(habitLogsProvider)[e!.id] ?? const HabitLog(null));
  late DateTime _at = e?.completedAt ?? DateTime.now();
  late String? _member = e?.completedByMemberId ?? currentFronterId(ref);
  late final Set<String> _co = {..._log.coMembers};
  late int _count = _log.count;
  late final _minutes = TextEditingController(
    text: '${widget.presetMinutes ?? _log.minutes ?? ''}',
  );
  late final _amount = TextEditingController(
    text: _log.amount == null ? '' : fmtNum(_log.amount!),
  );
  late int? _rating = e?.rating;
  late final _notes = TextEditingController(text: e?.notes);
  late List<String> _media = [..._log.media];
  late String? _location =
      _log.locationId ??
      (e == null ? ref.read(activeLocationSessionProvider)?.locationId : null);

  @override
  void initState() {
    super.initState();
    final meta =
        ref.read(habitMetasProvider)[widget.habit.id] ?? const HabitMeta(null);
    if (e == null &&
        widget.presetMinutes == null &&
        meta.unit == HabitUnit.minutes)
      _minutes.text = '${meta.defaultMinutes}';
  }

  @override
  void dispose() {
    _minutes.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final actions = ref.read(habitCenterActionsProvider);
    final minutes = int.tryParse(_minutes.text.trim());
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    if (e == null) {
      await actions.log(
        habit: widget.habit,
        memberId: _member,
        at: _at,
        count: _count,
        minutes: minutes,
        amount: amount,
        rating: _rating,
        notes: notes,
        media: _media,
        locationId: _location,
        coMembers: _co.toList(),
      );
    } else {
      await ref
          .read(habitNotifierProvider.notifier)
          .updateCompletion(
            completionId: e!.id,
            habitId: e!.habitId,
            changedFields: {
              'completed_at': _at.toUtc().toIso8601String(),
              'completed_by_member_id': _member,
              'notes': notes,
              'rating': _rating,
            },
          );
      await actions.saveLog(e!, _log, {
        'count': _count == 1 ? null : _count,
        'minutes': minutes,
        'amount': amount,
        'media': _media.isEmpty ? null : _media,
        'location': _location,
        'co': _co.isEmpty ? null : _co.toList(),
      });
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final meta =
        ref.watch(habitMetasProvider)[widget.habit.id] ?? const HabitMeta(null);
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final places = ref.watch(sortedSavedLocationsProvider);
    final theme = Theme.of(context);
    return TrackerEditorScaffold(
      title: e == null
          ? tr(
              context,
              'Log ${widget.habit.name}',
              'Registrar ${widget.habit.name}',
            )
          : tr(context, 'Completion', 'Registro'),
      canSave: true,
      scrollController: widget.scroll,
      onSave: _save,
      children: [
        PrismButton(
          label: DateFormat.yMMMEd(context.dateLocale).add_jm().format(_at),
          icon: AppIcons.history,
          onPressed: () async {
            final d = await showPrismDatePicker(
              context: context,
              initialDate: _at,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (d == null || !context.mounted) return;
            final t = await showPrismTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(_at),
            );
            setState(
              () => _at = DateTime(
                d.year,
                d.month,
                d.day,
                t?.hour ?? _at.hour,
                t?.minute ?? _at.minute,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        if (meta.unit == HabitUnit.times) ...[
          TrackerLabel(tr(context, 'How many', 'Cuántas')),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: '-',
                onPressed: _count > 1 ? () => setState(() => _count--) : null,
                icon: Icon(PhosphorIcons.minus()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_count ${unitWord(context, meta, _count)}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton.filledTonal(
                tooltip: '+',
                onPressed: () => setState(() => _count++),
                icon: Icon(PhosphorIcons.plus()),
              ),
            ],
          ),
        ],
        if (meta.unit == HabitUnit.amount)
          PrismTextField(
            controller: _amount,
            labelText:
                '${tr(context, 'Amount', 'Cantidad')} ${meta.unitLabel == null ? '' : '(${meta.unitLabel})'}',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _minutes,
          labelText: tr(context, 'Duration (minutes)', 'Duración (minutos)'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TrackerMemberPicker(
          label: tr(context, 'Completed by', 'Completado por'),
          value: _member,
          onChanged: (m) => setState(() => _member = m),
        ),
        if (members.length > 1) ...[
          TrackerLabel(
            tr(context, 'Together with (co-fronting)', 'Junto con (co-frente)'),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in members)
                if (m.id != _member)
                  PrismChip(
                    label: m.effectiveName(preferDisplayName: prefer),
                    selected: _co.contains(m.id),
                    onTap: () => setState(
                      () =>
                          _co.contains(m.id) ? _co.remove(m.id) : _co.add(m.id),
                    ),
                  ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'How did it go?', '¿Qué tal fue?')),
        StarRow(
          value: _rating,
          size: 30,
          onChanged: (v) => setState(() => _rating = v),
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _notes,
          autofocus: widget.focusNote,
          labelText: tr(context, 'Notes & reflections', 'Notas y reflexiones'),
          maxLines: 5,
          minLines: 2,
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Photos', 'Fotos')),
        MediaAttachRow(
          ids: _media,
          allowVideo: false,
          allowAudio: true,
          owner: _member,
          onChanged: (v) => setState(() => _media = v),
        ),
        if (places.isNotEmpty) ...[
          const SizedBox(height: 12),
          TrackerLabel(tr(context, 'Where', 'Dónde')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final l in places)
                PrismChip(
                  label: '${l.emoji ?? '📍'} ${l.name}',
                  selected: _location == l.id,
                  onTap: () => setState(
                    () => _location = _location == l.id ? null : l.id,
                  ),
                ),
            ],
          ),
        ],
        if (e != null) ...[
          RelatedRecordsSection(self: RecordRef(RecordRef.habitLog, e!.id)),
          const SizedBox(height: 16),
          PrismButton(
            label: tr(
              context,
              'Delete this completion',
              'Eliminar este registro',
            ),
            tone: PrismButtonTone.destructive,
            icon: AppIcons.delete,
            onPressed: () async {
              final ok = await PrismDialog.confirm(
                context: context,
                title: tr(
                  context,
                  'Delete this completion?',
                  '¿Eliminar este registro?',
                ),
                message: tr(
                  context,
                  'Its notes, photos and links are removed too.',
                  'También se quitan sus notas, fotos y enlaces.',
                ),
                destructive: true,
                confirmLabel: tr(context, 'Delete', 'Eliminar'),
                cancelLabel: context.l10n.cancel,
              );
              if (!ok) return;
              await ref.read(habitCenterActionsProvider).deleteCompletion(e!);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              tr(
                context,
                'After saving you can link this completion to moods, journal entries, sleep and more.',
                'Tras guardar podrás enlazarlo con ánimos, diario, sueño y más.',
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Targets, routines, schedules, reminders, dependencies, auto-logging,
/// challenges and pausing for one habit.
Future<void> showHabitTrackingSettings(BuildContext context, Habit habit) =>
    PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) => _Settings(habit: habit, scroll: scroll),
    );

const habitAutoSources = [
  (
    'nutri.drink',
    'A drink is logged in Nourish',
    'Se registra una bebida en Nutrición',
  ),
  ('nutri.meal', 'A meal is logged', 'Se registra una comida'),
  ('fitness.workout', 'A workout is logged', 'Se registra un entrenamiento'),
  ('journal.entry', 'A journal entry is written', 'Se escribe en el diario'),
  ('dream.entry', 'A dream is recorded', 'Se registra un sueño'),
  ('mood', 'A mood check-in is logged', 'Se registra el ánimo'),
  ('sleep', 'A sleep session ends', 'Termina una sesión de sueño'),
];

class _Settings extends ConsumerStatefulWidget {
  const _Settings({required this.habit, required this.scroll});
  final Habit habit;
  final ScrollController scroll;
  @override
  ConsumerState<_Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<_Settings> {
  late final HabitMeta m =
      ref.read(habitMetasProvider)[widget.habit.id] ?? const HabitMeta(null);
  late int _target = m.target;
  late HabitUnit _unit = m.unit;
  late final _label = TextEditingController(text: m.unitLabel);
  late int _defaultMinutes = m.defaultMinutes;
  late String? _group = m.groupId;
  late final Set<int> _recovery = {...m.recoveryDays};
  late int? _monthDay = m.monthDay;
  late final Set<String> _next = {...m.nextHabits};
  late final List<String> _reminders = [...m.reminders];
  late bool _remindMissed = m.remindMissed;
  late String? _auto = m.autoLog;
  late final _challenge = TextEditingController(
    text: m.challengeTarget?.toString() ?? '',
  );
  late DateTime? _challengeEnd = m.challengeEnd;
  late bool _paused = m.paused;
  late DateTime? _pausedUntil = m.pausedUntil;
  late bool _shared = m.shared;

  @override
  void dispose() {
    _label.dispose();
    _challenge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(habitGroupsProvider);
    final others = [
      for (final v in ref.watch(habitViewsProvider).values)
        if (v.habit.id != widget.habit.id) v.habit,
    ];
    final dfmt = DateFormat.yMMMd(context.dateLocale);
    final monday = DateTime(2024, 1, 1);
    return TrackerEditorScaffold(
      title: tr(context, 'Tracking & routine', 'Seguimiento y rutina'),
      canSave: true,
      scrollController: widget.scroll,
      onSave: () async {
        await ref.read(habitCenterActionsProvider).saveMeta(widget.habit.id, {
          'target': _target,
          'unit': _unit.name,
          'unitLabel': _label.text.trim().isEmpty ? null : _label.text.trim(),
          'defaultMinutes': _defaultMinutes,
          'group': _group,
          'recovery': [for (final d in _recovery) '$d'],
          'monthDay': _monthDay,
          'next': _next.toList(),
          'reminders': _reminders,
          'remindMissed': _remindMissed,
          'autoLog': _auto,
          'challenge': int.tryParse(_challenge.text.trim()),
          'challengeEnd': _challengeEnd?.toIso8601String(),
          'paused': _paused,
          'pausedUntil': _paused ? _pausedUntil?.toIso8601String() : null,
          'shared': _shared,
        });
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        TrackerLabel(tr(context, 'Measure by', 'Medir por')),
        PrismSegmentedControl<HabitUnit>(
          segments: [
            PrismSegment(
              value: HabitUnit.times,
              label: tr(context, 'Count', 'Veces'),
            ),
            PrismSegment(
              value: HabitUnit.minutes,
              label: tr(context, 'Minutes', 'Minutos'),
            ),
            PrismSegment(
              value: HabitUnit.amount,
              label: tr(context, 'Amount', 'Cantidad'),
            ),
          ],
          selected: _unit,
          onChanged: (u) => setState(() => _unit = u),
        ),
        const SizedBox(height: 8),
        if (_unit != HabitUnit.minutes)
          PrismTextField(
            controller: _label,
            labelText: tr(
              context,
              'Unit name (e.g. glass, session, page, km)',
              'Unidad (p. ej. vaso, sesión, página, km)',
            ),
          ),
        const SizedBox(height: 10),
        TrackerLabel(tr(context, 'Daily target', 'Meta diaria')),
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: '-',
              onPressed: _target > 1 ? () => setState(() => _target--) : null,
              icon: Icon(PhosphorIcons.minus()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$_target',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton.filledTonal(
              tooltip: '+',
              onPressed: () => setState(() => _target++),
              icon: Icon(PhosphorIcons.plus()),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _unit == HabitUnit.minutes
                    ? tr(context, 'minutes a day', 'minutos al día')
                    : tr(
                        context,
                        'per day — log as many times as you like',
                        'al día; registra cuantas veces quieras',
                      ),
              ),
            ),
          ],
        ),
        ...[
          TrackerLabel(
            tr(context, 'Usual session length', 'Duración habitual'),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final d in const [5, 10, 15, 25, 45, 60])
                PrismChip(
                  label: '$d min',
                  selected: _defaultMinutes == d,
                  onTap: () => setState(() => _defaultMinutes = d),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Routine', 'Rutina')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismChip(
              label: tr(context, 'None', 'Ninguna'),
              selected: _group == null,
              onTap: () => setState(() => _group = null),
            ),
            for (final g in groups)
              PrismChip(
                label: g.title,
                selected: _group == g.id,
                onTap: () => setState(() => _group = g.id),
              ),
            PrismChip(
              label: tr(context, '+ New routine', '+ Nueva rutina'),
              selected: false,
              variant: PrismChipVariant.inline,
              onTap: () async {
                final name = await promptText(
                  context,
                  tr(context, 'Routine name', 'Nombre de la rutina'),
                  hint: tr(
                    context,
                    'e.g. Morning Routine',
                    'p. ej. Rutina de mañana',
                  ),
                );
                if (name == null || name.isEmpty) return;
                final g = await ref
                    .read(habitCenterActionsProvider)
                    .saveGroup(name: name, habitIds: [widget.habit.id]);
                setState(() => _group = g.id);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        TrackerLabel(
          tr(
            context,
            'Rest days (no streak penalty)',
            'Días de descanso (sin romper racha)',
          ),
        ),
        Wrap(
          spacing: 4,
          children: [
            for (var d = 1; d <= 7; d++)
              PrismChip(
                label: DateFormat.E(
                  context.dateLocale,
                ).format(monday.add(Duration(days: d - 1))),
                selected: _recovery.contains(d),
                onTap: () => setState(
                  () => _recovery.contains(d)
                      ? _recovery.remove(d)
                      : _recovery.add(d),
                ),
              ),
          ],
        ),
        PrismSwitchRow(
          title: tr(context, 'Monthly habit', 'Hábito mensual'),
          subtitle: _monthDay == null
              ? null
              : tr(
                  context,
                  'On day $_monthDay of each month',
                  'El día $_monthDay de cada mes',
                ),
          value: _monthDay != null,
          onChanged: (v) =>
              setState(() => _monthDay = v ? DateTime.now().day : null),
        ),
        if (_monthDay != null)
          Slider(
            value: _monthDay!.toDouble(),
            min: 1,
            max: 31,
            divisions: 30,
            label: '$_monthDay',
            onChanged: (v) => setState(() => _monthDay = v.round()),
          ),
        const SizedBox(height: 8),
        TrackerLabel(tr(context, 'Reminders', 'Recordatorios')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in _reminders)
              PrismChip(
                label: '⏰ $r  ✕',
                selected: true,
                onTap: () => setState(() => _reminders.remove(r)),
              ),
            PrismChip(
              label: tr(context, '+ Add time', '+ Añadir hora'),
              selected: false,
              variant: PrismChipVariant.inline,
              onTap: () async {
                final t = await showPrismTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 9, minute: 0),
                );
                if (t == null) return;
                final s =
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                if (!_reminders.contains(s))
                  setState(
                    () => _reminders
                      ..add(s)
                      ..sort(),
                  );
              },
            ),
          ],
        ),
        PrismSwitchRow(
          title: tr(
            context,
            'Evening nudge if the target is missed',
            'Aviso por la tarde si falta la meta',
          ),
          subtitle: tr(
            context,
            'At 20:00 on scheduled days when the target isn’t reached yet.',
            'A las 20:00 en días programados si aún falta.',
          ),
          value: _remindMissed,
          onChanged: (v) => setState(() => _remindMissed = v),
        ),
        const SizedBox(height: 8),
        if (others.isNotEmpty) ...[
          TrackerLabel(
            tr(
              context,
              'Up next — suggest after finishing',
              'A continuación: sugerir al terminar',
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in others)
                PrismChip(
                  label: '${h.icon ?? ''} ${h.name}'.trim(),
                  selected: _next.contains(h.id),
                  onTap: () => setState(
                    () => _next.contains(h.id)
                        ? _next.remove(h.id)
                        : _next.add(h.id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TrackerLabel(
          tr(
            context,
            'Count automatically when…',
            'Contar automáticamente cuando…',
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismChip(
              label: tr(context, 'Off', 'No'),
              selected: _auto == null,
              onTap: () => setState(() => _auto = null),
            ),
            for (final (k, en, es) in habitAutoSources)
              PrismChip(
                label: tr(context, en, es),
                selected: _auto == k,
                onTap: () => setState(() => _auto = k),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Challenge (optional)', 'Reto (opcional)')),
        Row(
          children: [
            Expanded(
              child: PrismTextField(
                controller: _challenge,
                labelText: tr(
                  context,
                  'Total completions to reach',
                  'Total de registros a alcanzar',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            PrismButton(
              label: _challengeEnd == null
                  ? tr(context, 'By date…', 'Antes de…')
                  : dfmt.format(_challengeEnd!),
              onPressed: () async {
                final d = await showPrismDatePicker(
                  context: context,
                  initialDate:
                      _challengeEnd ??
                      DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                setState(() => _challengeEnd = d);
              },
            ),
          ],
        ),
        PrismSwitchRow(
          title: tr(
            context,
            'Shared system habit',
            'Hábito compartido del sistema',
          ),
          subtitle: tr(
            context,
            'Show who contributed and count everyone’s completions together.',
            'Muestra quién contribuyó y suma los registros de todos.',
          ),
          value: _shared,
          onChanged: (v) => setState(() => _shared = v),
        ),
        PrismSwitchRow(
          title: tr(context, 'Pause this habit', 'Pausar este hábito'),
          subtitle: tr(
            context,
            'Paused days never break a streak.',
            'Los días en pausa no rompen la racha.',
          ),
          value: _paused,
          onChanged: (v) => setState(() => _paused = v),
        ),
        if (_paused)
          PrismButton(
            label: _pausedUntil == null
                ? tr(context, 'Until I resume it', 'Hasta que lo reanude')
                : tr(
                    context,
                    'Until ${dfmt.format(_pausedUntil!)}',
                    'Hasta ${dfmt.format(_pausedUntil!)}',
                  ),
            onPressed: () async {
              final d = await showPrismDatePicker(
                context: context,
                initialDate:
                    _pausedUntil ?? DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              setState(() => _pausedUntil = d);
            },
          ),
      ],
    );
  }
}
