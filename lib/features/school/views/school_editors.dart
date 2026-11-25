import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/school/utils/school.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_time_picker.dart';

String assignmentTypeLabel(AppLocalizations l10n, String t) => switch (t) {
  'homework' => l10n.schHomework,
  'reading' => l10n.schReading,
  'essay' => l10n.schEssay,
  'project' => l10n.schProject,
  'lab' => l10n.schLab,
  'quiz' => l10n.schQuiz,
  'exam' => l10n.schExam,
  'presentation' => l10n.schPresentation,
  _ => l10n.finCatOther,
};

String statusLabel(AppLocalizations l10n, String s) => switch (s) {
  AssignmentStatus.doing => l10n.schDoing,
  AssignmentStatus.done => l10n.schDone,
  _ => l10n.schTodo,
};

String weekdayShort(BuildContext context, int weekday) =>
    DateFormat.E(context.dateLocale).format(DateTime(2024, 1, weekday));

String _numText(num? v) => v == null
    ? ''
    : v == v.roundToDouble()
    ? v.round().toString()
    : v.toString();

double? _d(String s) =>
    s.trim().isEmpty ? null : double.tryParse(s.trim().replaceAll(',', '.'));

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  TrackerRecord e,
  String title, {
  String? message,
}) async {
  final l10n = context.l10n;
  final ok = await PrismDialog.confirm(
    context: context,
    title: title,
    message: message,
    confirmLabel: l10n.trackerDelete,
    cancelLabel: l10n.cancel,
    destructive: true,
  );
  if (!ok) return;
  await ref.read(trackerNotifierProvider.notifier).delete(e.id);
  if (context.mounted) Navigator.of(context).pop();
}

// ---------------------------------------------------------------------------
// Class
// ---------------------------------------------------------------------------

Future<void> showClassEditor(BuildContext context, {TrackerRecord? editing}) =>
    PrismSheet.showFullScreen(
      context: context,
      builder: (context, scroll) =>
          ClassEditorSheet(editing: editing, scroll: scroll),
    );

class _MeetingDraft {
  _MeetingDraft(this.weekday, this.start, this.end);

  int weekday;
  int start;
  int end;
}

class ClassEditorSheet extends ConsumerStatefulWidget {
  const ClassEditorSheet({super.key, this.editing, this.scroll});

  final TrackerRecord? editing;
  final ScrollController? scroll;

  @override
  ConsumerState<ClassEditorSheet> createState() => _ClassEditorState();
}

class _ClassEditorState extends ConsumerState<ClassEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late final _name = TextEditingController(text: _e?.title ?? '');
  late final _teacher = TextEditingController(
    text: _e?.str(SchoolField.teacher) ?? '',
  );
  late final _room = TextEditingController(
    text: _e?.str(SchoolField.room) ?? '',
  );
  late final _credits = TextEditingController(
    text: _numText(_e?.number(SchoolField.credits)),
  );
  late final _target = TextEditingController(
    text: _numText(_e?.number(SchoolField.targetPercent)),
  );
  late int _color =
      _e?.integer(SchoolField.color) ??
      trackerPalette[DateTime.now().millisecond % trackerPalette.length];
  late String? _member = _e == null ? currentFronterId(ref) : _e.memberId;
  late final List<_MeetingDraft> _meetings = [
    for (final m in _e == null ? const <ClassMeeting>[] : classSchedule(_e))
      _MeetingDraft(m.weekday, m.startMinute, m.endMinute),
  ];

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_credits.text.trim().isEmpty || (_d(_credits.text) ?? -1) >= 0) &&
      (_target.text.trim().isEmpty ||
          ((_d(_target.text) ?? -1) >= 0 && _d(_target.text)! <= 100)) &&
      _meetings.every((m) => m.end > m.start);

  @override
  void dispose() {
    for (final c in [_name, _teacher, _room, _credits, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final fields = <String, Object?>{
      SchoolField.teacher: _teacher.text.trim().isEmpty
          ? null
          : _teacher.text.trim(),
      SchoolField.room: _room.text.trim().isEmpty ? null : _room.text.trim(),
      SchoolField.credits: _d(_credits.text),
      SchoolField.targetPercent: _d(_target.text),
      SchoolField.color: _color,
      SchoolField.schedule: _meetings.isEmpty
          ? null
          : [
              for (final m in _meetings)
                ClassMeeting(
                  weekday: m.weekday,
                  startMinute: m.start,
                  endMinute: m.end,
                ).toJson(),
            ],
    };
    final n = ref.read(trackerNotifierProvider.notifier);
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.schoolClass,
        title: _name.text,
        memberId: _member,
        fields: fields,
      );
    } else {
      await n.save(
        e
            .copyWith(title: _name.text.trim(), memberId: _member)
            .withFields(fields),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<int?> _pickTime(int minute) async {
    final t = await showPrismTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _credits, _target]),
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.schNewClass : l10n.schEditClass,
        canSave: _valid,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          PrismTextField(
            controller: _name,
            labelText: l10n.schClassName,
            autofocus: _e == null,
          ),
          const SizedBox(height: 12),
          PrismTextField(controller: _teacher, labelText: l10n.schTeacher),
          const SizedBox(height: 12),
          PrismTextField(controller: _room, labelText: l10n.schRoom),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrismTextField(
                  controller: _credits,
                  labelText: l10n.schCredits,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrismTextField(
                  controller: _target,
                  labelText: l10n.schTargetGrade,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          TrackerMemberPicker(
            label: l10n.schWhoseClass,
            value: _member,
            onChanged: (v) => setState(() => _member = v),
          ),
          TrackerLabel(l10n.finColor),
          Wrap(
            spacing: 8,
            children: [
              for (final c in trackerPalette)
                InkResponse(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: prismRound(context),
                      border: Border.all(
                        width: _color == c ? 3 : 0,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          TrackerLabel(
            l10n.schSchedule,
            trailing: PrismButton(
              label: l10n.schAddMeeting,
              icon: AppIcons.add,
              density: PrismControlDensity.compact,
              onPressed: () => setState(
                () => _meetings.add(
                  _MeetingDraft(DateTime.monday, 9 * 60, 10 * 60),
                ),
              ),
            ),
          ),
          if (_meetings.isEmpty)
            Text(l10n.schNoSchedule, style: theme.textTheme.bodySmall),
          for (var i = 0; i < _meetings.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PrismSurface(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          PrismChip(
                            label: weekdayShort(context, d),
                            selected: _meetings[i].weekday == d,
                            onTap: () =>
                                setState(() => _meetings[i].weekday = d),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        PrismButton(
                          label: formatMinuteOfDay(_meetings[i].start),
                          density: PrismControlDensity.compact,
                          onPressed: () async {
                            final m = await _pickTime(_meetings[i].start);
                            if (m != null) {
                              setState(() => _meetings[i].start = m);
                            }
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('–'),
                        ),
                        PrismButton(
                          label: formatMinuteOfDay(_meetings[i].end),
                          density: PrismControlDensity.compact,
                          onPressed: () async {
                            final m = await _pickTime(_meetings[i].end);
                            if (m != null) setState(() => _meetings[i].end = m);
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: l10n.trackerDelete,
                          icon: Icon(AppIcons.close, size: 18),
                          onPressed: () =>
                              setState(() => _meetings.removeAt(i)),
                        ),
                      ],
                    ),
                    if (_meetings[i].end <= _meetings[i].start)
                      Text(
                        l10n.schEndAfterStart,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                  ],
                ),
              ),
            ),
          if (_e != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: PrismButton(
                label: l10n.trackerDelete,
                icon: AppIcons.delete,
                tone: PrismButtonTone.destructive,
                onPressed: () => _confirmDelete(
                  context,
                  ref,
                  _e,
                  l10n.schDeleteClass(_e.title),
                  message: l10n.schDeleteClassMessage,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Assignment
// ---------------------------------------------------------------------------

Future<void> showAssignmentEditor(
  BuildContext context, {
  TrackerRecord? editing,
  String? classId,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (context, scroll) =>
      AssignmentEditorSheet(editing: editing, classId: classId, scroll: scroll),
);

class AssignmentEditorSheet extends ConsumerStatefulWidget {
  const AssignmentEditorSheet({
    super.key,
    this.editing,
    this.classId,
    this.scroll,
  });

  final TrackerRecord? editing;
  final String? classId;
  final ScrollController? scroll;

  @override
  ConsumerState<AssignmentEditorSheet> createState() =>
      _AssignmentEditorState();
}

class _AssignmentEditorState extends ConsumerState<AssignmentEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late final _title = TextEditingController(text: _e?.title ?? '');
  late final _notes = TextEditingController(text: _e?.body ?? '');
  late final _weight = TextEditingController(
    text: _numText(_e?.number(SchoolField.weight)),
  );
  late final _earned = TextEditingController(
    text: _numText(_e?.number(SchoolField.earned)),
  );
  late final _possible = TextEditingController(
    text: _numText(_e?.number(SchoolField.possible)),
  );
  late String? _classId = _e?.parentId ?? widget.classId;
  late String _type = _e?.str(SchoolField.type) ?? 'homework';
  late String _status = _e == null
      ? AssignmentStatus.todo
      : assignmentStatus(_e);
  late int _priority = _e?.integer(SchoolField.priority) ?? 2;
  late String? _member =
      _e?.memberId ??
      _classOwner(widget.classId) ??
      (_e == null ? currentFronterId(ref) : null);

  String? _classOwner(String? id) {
    if (id == null) return null;
    final classes =
        ref.read(trackerKindProvider(TrackerKind.schoolClass)).value ??
        const <TrackerRecord>[];
    return classes.where((c) => c.id == id).firstOrNull?.memberId;
  }

  late DateTime? _due = _e?.occurredAt ?? _defaultDue();

  static DateTime _defaultDue() {
    final n = DateTime.now().add(const Duration(days: 1));
    return DateTime(n.year, n.month, n.day, 23, 59);
  }

  bool _numOk(TextEditingController c) =>
      c.text.trim().isEmpty || (_d(c.text) ?? -1) >= 0;

  bool get _gradeOk {
    final e = _d(_earned.text), p = _d(_possible.text);
    if (_earned.text.trim().isEmpty && _possible.text.trim().isEmpty) {
      return true;
    }
    return e != null && p != null && p > 0 && e >= 0;
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      _numOk(_weight) &&
      (_d(_weight.text) ?? 0) <= 100 &&
      _gradeOk;

  @override
  void dispose() {
    for (final c in [_title, _notes, _weight, _earned, _possible]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final fields = <String, Object?>{
      SchoolField.type: _type,
      SchoolField.status: _status,
      SchoolField.priority: _priority,
      SchoolField.weight: _d(_weight.text),
      SchoolField.earned: _d(_earned.text),
      SchoolField.possible: _d(_possible.text),
    };
    final n = ref.read(trackerNotifierProvider.notifier);
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.schoolAssignment,
        title: _title.text,
        body: _notes.text,
        parentId: _classId,
        occurredAt: _due,
        memberId: _member,
        fields: fields,
      );
    } else {
      await n.save(
        e
            .copyWith(
              title: _title.text.trim(),
              body: _notes.text,
              parentId: _classId,
              occurredAt: _due,
              memberId: _member,
              endedAt: _status == AssignmentStatus.done
                  ? (e.endedAt ?? DateTime.now())
                  : null,
            )
            .withFields(fields),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final classes =
        ref.watch(trackerKindProvider(TrackerKind.schoolClass)).value ??
        const <TrackerRecord>[];
    return ListenableBuilder(
      listenable: Listenable.merge([_title, _weight, _earned, _possible]),
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.schNewAssignment : l10n.schEditAssignment,
        canSave: _valid,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          PrismTextField(
            controller: _title,
            labelText: l10n.schAssignmentTitle,
            autofocus: _e == null,
          ),
          TrackerLabel(l10n.schClass),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PrismChip(
                label: l10n.schNoClass,
                selected: _classId == null,
                onTap: () => setState(() => _classId = null),
              ),
              for (final c in classes)
                PrismChip(
                  label: c.title,
                  selected: _classId == c.id,
                  selectedColor: Color(
                    c.integer(SchoolField.color) ?? trackerPalette.first,
                  ),
                  onTap: () => setState(() {
                    _classId = c.id;
                    _member = c.memberId ?? _member;
                  }),
                ),
            ],
          ),
          TrackerMemberPicker(
            label: l10n.schWhoseAssignment,
            value: _member,
            onChanged: (v) => setState(() => _member = v),
          ),
          TrackerLabel(l10n.schType),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in assignmentTypes)
                PrismChip(
                  label: assignmentTypeLabel(l10n, t),
                  selected: _type == t,
                  onTap: () => setState(() => _type = t),
                ),
            ],
          ),
          TrackerLabel(l10n.schDue),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                label: _due == null
                    ? l10n.schNoDueDate
                    : DateFormat.yMMMEd(context.dateLocale).format(_due!),
                icon: AppIcons.calendarToday,
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    initialDate: _due ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(
                      () => _due = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        _due?.hour ?? 23,
                        _due?.minute ?? 59,
                      ),
                    );
                  }
                },
              ),
              if (_due != null)
                PrismButton(
                  label: DateFormat.jm(context.dateLocale).format(_due!),
                  density: PrismControlDensity.compact,
                  onPressed: () async {
                    final t = await showPrismTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_due!),
                    );
                    if (t != null) {
                      setState(
                        () => _due = DateTime(
                          _due!.year,
                          _due!.month,
                          _due!.day,
                          t.hour,
                          t.minute,
                        ),
                      );
                    }
                  },
                ),
              if (_due != null)
                PrismButton(
                  label: l10n.schNoDueDate,
                  density: PrismControlDensity.compact,
                  onPressed: () => setState(() => _due = null),
                ),
            ],
          ),
          TrackerLabel(l10n.schStatus),
          PrismSegmentedControl<String>(
            segments: [
              for (final s in AssignmentStatus.all)
                PrismSegment(value: s, label: statusLabel(l10n, s)),
            ],
            selected: _status,
            onChanged: (s) => setState(() => _status = s),
          ),
          TrackerLabel(l10n.schPriority),
          PrismSegmentedControl<int>(
            segments: [
              PrismSegment(value: 1, label: l10n.schPriorityLow),
              PrismSegment(value: 2, label: l10n.schPriorityNormal),
              PrismSegment(value: 3, label: l10n.schPriorityHigh),
            ],
            selected: _priority,
            onChanged: (p) => setState(() => _priority = p),
          ),
          TrackerLabel(l10n.schGrade),
          Row(
            children: [
              Expanded(
                child: PrismTextField(
                  controller: _earned,
                  labelText: l10n.schEarned,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('/'),
              ),
              Expanded(
                child: PrismTextField(
                  controller: _possible,
                  labelText: l10n.schPossible,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          if (!_gradeOk)
            Text(
              l10n.schGradeInvalid,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _weight,
            labelText: l10n.schWeight,
            helperText: l10n.schWeightHelp,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _notes,
            labelText: l10n.finNote,
            maxLines: 5,
          ),
          if (_e != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: PrismButton(
                label: l10n.trackerDelete,
                icon: AppIcons.delete,
                tone: PrismButtonTone.destructive,
                onPressed: () =>
                    _confirmDelete(context, ref, _e, l10n.schDeleteAssignment),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Study session (manual entry)
// ---------------------------------------------------------------------------

Future<void> showStudyEditor(
  BuildContext context, {
  TrackerRecord? editing,
  String? classId,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (context, scroll) =>
      StudyEditorSheet(editing: editing, classId: classId, scroll: scroll),
);

class StudyEditorSheet extends ConsumerStatefulWidget {
  const StudyEditorSheet({super.key, this.editing, this.classId, this.scroll});

  final TrackerRecord? editing;
  final String? classId;
  final ScrollController? scroll;

  @override
  ConsumerState<StudyEditorSheet> createState() => _StudyEditorState();
}

class _StudyEditorState extends ConsumerState<StudyEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late final _minutes = TextEditingController(
    text: _numText(_e?.integer(SchoolField.minutes)),
  );
  late final _notes = TextEditingController(text: _e?.body ?? '');
  late String? _classId = _e?.parentId ?? widget.classId;
  late int? _focus = _e?.integer(SchoolField.focus);
  late DateTime _at = _e?.occurredAt ?? DateTime.now();
  late String? _member = _e == null ? currentFronterId(ref) : _e.memberId;

  bool get _valid => (int.tryParse(_minutes.text.trim()) ?? 0) > 0;

  @override
  void dispose() {
    _minutes.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final fields = <String, Object?>{
      SchoolField.minutes: int.parse(_minutes.text.trim()),
      SchoolField.focus: _focus,
      'live': null,
    };
    final n = ref.read(trackerNotifierProvider.notifier);
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.schoolStudy,
        title: l10n.schStudySession,
        body: _notes.text,
        parentId: _classId,
        occurredAt: _at,
        memberId: _member,
        fields: fields,
      );
    } else {
      await n.save(
        e
            .copyWith(
              body: _notes.text,
              parentId: _classId,
              occurredAt: _at,
              memberId: _member,
              endedAt: e.endedAt ?? DateTime.now(),
            )
            .withFields(fields),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final classes =
        ref.watch(trackerKindProvider(TrackerKind.schoolClass)).value ??
        const <TrackerRecord>[];
    return ListenableBuilder(
      listenable: _minutes,
      builder: (context, _) => TrackerEditorScaffold(
        title: l10n.schStudySession,
        canSave: _valid,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          PrismTextField(
            controller: _minutes,
            labelText: l10n.fitMinutes,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          PrismButton(
            label: DateFormat.yMMMEd(context.dateLocale).add_jm().format(_at),
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
          TrackerLabel(l10n.schClass),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PrismChip(
                label: l10n.schNoClass,
                selected: _classId == null,
                onTap: () => setState(() => _classId = null),
              ),
              for (final c in classes)
                PrismChip(
                  label: c.title,
                  selected: _classId == c.id,
                  onTap: () => setState(() => _classId = c.id),
                ),
            ],
          ),
          TrackerMemberPicker(
            label: l10n.schWhoStudied,
            value: _member,
            onChanged: (v) => setState(() => _member = v),
          ),
          TrackerLabel(l10n.schFocus),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 1; i <= 5; i++)
                PrismChip(
                  label: '$i',
                  selected: _focus == i,
                  onTap: () => setState(() => _focus = _focus == i ? null : i),
                ),
            ],
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
                onPressed: () =>
                    _confirmDelete(context, ref, _e, l10n.schDeleteStudy),
              ),
            ),
        ],
      ),
    );
  }
}
