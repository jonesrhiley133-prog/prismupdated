import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/fitness/utils/fitness.dart';
import 'package:prism_plurality/features/fitness/views/fitness_labels.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_time_picker.dart';

String _num(num? v) => v == null || v == 0
    ? ''
    : (v is double && v != v.roundToDouble())
    ? v.toString()
    : v.round().toString();

double? _parseDouble(String s) =>
    s.trim().isEmpty ? null : double.tryParse(s.trim().replaceAll(',', '.'));

Future<void> showWorkoutEditor(
  BuildContext context, {
  TrackerRecord? editing,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (context, scroll) =>
      WorkoutEditorSheet(editing: editing, scroll: scroll),
);

class _SetRow {
  _SetRow([ExerciseSet? s])
    : name = TextEditingController(text: s?.exercise ?? ''),
      sets = TextEditingController(text: _num(s?.sets)),
      reps = TextEditingController(text: _num(s?.reps)),
      weight = TextEditingController(text: _num(s?.weightKg));

  final TextEditingController name, sets, reps, weight;

  ExerciseSet? get value => name.text.trim().isEmpty
      ? null
      : ExerciseSet(
          exercise: name.text.trim(),
          sets: int.tryParse(sets.text.trim()) ?? 1,
          reps: int.tryParse(reps.text.trim()) ?? 0,
          weightKg: _parseDouble(weight.text) ?? 0,
        );

  void dispose() {
    for (final c in [name, sets, reps, weight]) {
      c.dispose();
    }
  }
}

class WorkoutEditorSheet extends ConsumerStatefulWidget {
  const WorkoutEditorSheet({super.key, this.editing, this.scroll});

  final TrackerRecord? editing;
  final ScrollController? scroll;

  @override
  ConsumerState<WorkoutEditorSheet> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends ConsumerState<WorkoutEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late String _activity = _e == null ? 'walk' : workoutActivity(_e);
  late final _title = TextEditingController(text: _e?.title ?? '');
  late final _minutes = TextEditingController(
    text: _num(_e?.integer(FitField.minutes)),
  );
  late final _km = TextEditingController(
    text: _num(_e?.number(FitField.distanceKm)),
  );
  late final _cal = TextEditingController(
    text: _num(_e?.integer(FitField.calories)),
  );
  late final _hr = TextEditingController(
    text: _num(_e?.integer(FitField.heartRate)),
  );
  late final _notes = TextEditingController(text: _e?.body ?? '');
  late int? _effort = _e?.integer(FitField.effort);
  late int? _mood = _e?.integer(FitField.moodAfter);
  late String? _member = _e == null ? currentFronterId(ref) : _e.memberId;
  late DateTime _at = _e?.occurredAt ?? DateTime.now();
  late final List<_SetRow> _sets = [
    for (final s in _e == null ? const <ExerciseSet>[] : workoutSets(_e))
      _SetRow(s),
  ];

  bool get _numbersValid {
    bool ok(TextEditingController c, {bool decimal = false}) =>
        c.text.trim().isEmpty ||
        ((decimal ? _parseDouble(c.text) : int.tryParse(c.text.trim())) ??
                -1) >=
            0;
    return ok(_minutes) && ok(_km, decimal: true) && ok(_cal) && ok(_hr);
  }

  bool get _valid =>
      _numbersValid &&
      ((int.tryParse(_minutes.text.trim()) ?? 0) > 0 ||
          _sets.any((s) => s.value != null) ||
          (_parseDouble(_km.text) ?? 0) > 0);

  @override
  void dispose() {
    for (final c in [_title, _minutes, _km, _cal, _hr, _notes]) {
      c.dispose();
    }
    for (final s in _sets) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final fields = <String, Object?>{
      FitField.activity: _activity,
      FitField.minutes: int.tryParse(_minutes.text.trim()),
      FitField.distanceKm: _parseDouble(_km.text),
      FitField.calories: int.tryParse(_cal.text.trim()),
      FitField.heartRate: int.tryParse(_hr.text.trim()),
      FitField.effort: _effort,
      FitField.moodAfter: _mood,
      FitField.sets: [
        for (final s in _sets)
          if (s.value case final v?) v.toJson(),
      ],
      'live': null,
    };
    if ((fields[FitField.sets] as List).isEmpty) fields[FitField.sets] = null;
    final title = _title.text.trim().isEmpty
        ? fitnessActivityLabel(l10n, _activity)
        : _title.text.trim();
    final n = ref.read(trackerNotifierProvider.notifier);
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.fitnessWorkout,
        title: title,
        body: _notes.text,
        occurredAt: _at,
        memberId: _member,
        fields: fields,
      );
    } else {
      await n.save(
        e
            .copyWith(
              title: title,
              body: _notes.text,
              occurredAt: _at,
              memberId: _member,
              endedAt: e.endedAt ?? DateTime.now(),
            )
            // An imported workout edited by hand keeps the user's values:
            // later syncs leave it alone.
            .withFields({...fields, if (e.flag('imported')) 'manualEdit': true}),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _numberField(
    TextEditingController c,
    String label, {
    bool decimal = false,
  }) => PrismTextField(
    controller: c,
    labelText: label,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final known = exerciseHistory(
      ref.watch(trackerKindProvider(TrackerKind.fitnessWorkout)).value ??
          const [],
    ).map((e) => e.exercise).take(12).toList();
    return ListenableBuilder(
      listenable: Listenable.merge([
        _minutes,
        _km,
        _cal,
        _hr,
        for (final s in _sets) s.name,
      ]),
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.fitNewWorkout : l10n.fitEditWorkout,
        canSave: _valid,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in fitnessActivities)
                PrismChip(
                  label: fitnessActivityLabel(l10n, a),
                  selected: _activity == a,
                  onTap: () => setState(() => _activity = a),
                ),
            ],
          ),
          const SizedBox(height: 12),
          PrismTextField(controller: _title, labelText: l10n.fitWorkoutName),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                label: DateFormat.yMMMEd(context.dateLocale).format(_at),
                icon: AppIcons.calendarToday,
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    initialDate: _at,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) {
                    setState(
                      () => _at = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        _at.hour,
                        _at.minute,
                      ),
                    );
                  }
                },
              ),
              PrismButton(
                label: DateFormat.jm(context.dateLocale).format(_at),
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final t = await showPrismTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_at),
                  );
                  if (t != null) {
                    setState(
                      () => _at = DateTime(
                        _at.year,
                        _at.month,
                        _at.day,
                        t.hour,
                        t.minute,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _numberField(_minutes, l10n.fitMinutes)),
              const SizedBox(width: 8),
              Expanded(
                child: _numberField(_km, l10n.fitDistanceKm, decimal: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _numberField(_cal, l10n.fitCalories)),
              const SizedBox(width: 8),
              Expanded(child: _numberField(_hr, l10n.fitHeartRate)),
            ],
          ),
          if (!_numbersValid)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.fitInvalidNumber,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TrackerLabel(l10n.fitEffort),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 1; i <= 10; i++)
                PrismChip(
                  label: '$i',
                  selected: _effort == i,
                  onTap: () =>
                      setState(() => _effort = _effort == i ? null : i),
                ),
            ],
          ),
          TrackerLabel(l10n.fitMoodAfter),
          Wrap(
            spacing: 8,
            children: [
              for (var m = 1; m <= 5; m++)
                InkResponse(
                  onTap: () => setState(() => _mood = _mood == m ? null : m),
                  child: Opacity(
                    opacity: _mood == null || _mood == m ? 1 : 0.35,
                    child: MoodFace(level: m, size: 36),
                  ),
                ),
            ],
          ),
          TrackerLabel(
            l10n.fitExercises,
            trailing: PrismButton(
              label: l10n.fitAddExercise,
              icon: AppIcons.add,
              density: PrismControlDensity.compact,
              onPressed: () => setState(() => _sets.add(_SetRow())),
            ),
          ),
          for (var i = 0; i < _sets.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PrismSurface(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: PrismTextField(
                            controller: _sets[i].name,
                            labelText: l10n.fitExercise,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.trackerDelete,
                          icon: Icon(AppIcons.close, size: 18),
                          onPressed: () => setState(() {
                            _sets.removeAt(i).dispose();
                          }),
                        ),
                      ],
                    ),
                    if (_sets[i].name.text.isEmpty && known.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final k in known)
                              PrismChip(
                                label: k,
                                selected: false,
                                onTap: () => _sets[i].name.text = k,
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _numberField(_sets[i].sets, l10n.fitSets),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _numberField(_sets[i].reps, l10n.fitReps),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _numberField(
                            _sets[i].weight,
                            l10n.fitWeightKg,
                            decimal: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          TrackerMemberPicker(
            label: l10n.fitWho,
            value: _member,
            onChanged: (v) => setState(() => _member = v),
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _notes,
            labelText: l10n.finNote,
            maxLines: 4,
          ),
          if (_e != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: PrismButton(
                label: l10n.trackerDelete,
                icon: AppIcons.delete,
                tone: PrismButtonTone.destructive,
                onPressed: () async {
                  final ok = await PrismDialog.confirm(
                    context: context,
                    title: l10n.fitDeleteWorkout,
                    confirmLabel: l10n.trackerDelete,
                    cancelLabel: l10n.cancel,
                    destructive: true,
                  );
                  if (!ok) return;
                  await ref
                      .read(trackerNotifierProvider.notifier)
                      .delete(_e.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showFitnessGoalEditor(
  BuildContext context, {
  TrackerRecord? editing,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (context, scroll) =>
      FitnessGoalEditorSheet(editing: editing, scroll: scroll),
);

class FitnessGoalEditorSheet extends ConsumerStatefulWidget {
  const FitnessGoalEditorSheet({super.key, this.editing, this.scroll});

  final TrackerRecord? editing;
  final ScrollController? scroll;

  @override
  ConsumerState<FitnessGoalEditorSheet> createState() => _GoalState();
}

class _GoalState extends ConsumerState<FitnessGoalEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late String _metric = _e?.str(FitField.metric) ?? 'workouts';
  late String _period = _e?.str(FitField.period) ?? 'week';
  late final _target = TextEditingController(
    text: _num(_e?.number(FitField.target)),
  );

  double? get _value => _parseDouble(_target.text);

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final title =
        '${fitnessMetricLabel(l10n, _metric)} · ${_period == 'month' ? l10n.fitPerMonth : l10n.fitPerWeek}';
    final fields = {
      FitField.metric: _metric,
      FitField.period: _period,
      FitField.target: _value,
    };
    final n = ref.read(trackerNotifierProvider.notifier);
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.fitnessGoal,
        title: title,
        fields: fields,
      );
    } else {
      await n.save(e.copyWith(title: title).withFields(fields));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _target,
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.fitNewGoal : l10n.fitEditGoal,
        canSave: (_value ?? 0) > 0,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          TrackerLabel(l10n.fitGoalMetric),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in ['workouts', 'minutes', 'distance', 'calories'])
                PrismChip(
                  label: fitnessMetricLabel(l10n, m),
                  selected: _metric == m,
                  onTap: () => setState(() => _metric = m),
                ),
            ],
          ),
          TrackerLabel(l10n.fitGoalPeriod),
          Wrap(
            spacing: 6,
            children: [
              PrismChip(
                label: l10n.fitPerWeek,
                selected: _period == 'week',
                onTap: () => setState(() => _period = 'week'),
              ),
              PrismChip(
                label: l10n.fitPerMonth,
                selected: _period == 'month',
                onTap: () => setState(() => _period = 'month'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _target,
            labelText: l10n.fitGoalTarget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (_e != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: PrismButton(
                label: l10n.trackerDelete,
                icon: AppIcons.delete,
                tone: PrismButtonTone.destructive,
                onPressed: () async {
                  await ref
                      .read(trackerNotifierProvider.notifier)
                      .delete(_e.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}
