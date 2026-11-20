import 'dart:async';

import 'package:prism_plurality/shared/widgets/section_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/shared/l10n/tr.dart';
import 'package:prism_plurality/features/prism_social/social_share.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/fitness/views/fitness_screen.dart'
    show formatElapsed;
import 'package:prism_plurality/features/school/utils/school.dart';
import 'package:prism_plurality/features/school/views/school_editors.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_checkbox_row.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

enum SchoolTab { today, classes, assignments, study, progress }

enum _AssignFilter { open, overdue, done, all }

Color classColor(TrackerRecord? c) =>
    Color(c?.integer(SchoolField.color) ?? trackerPalette.first);

class SchoolScreen extends ConsumerStatefulWidget {
  const SchoolScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<SchoolScreen> createState() => _SchoolScreenState();
}

class _SchoolScreenState extends ConsumerState<SchoolScreen> {
  SchoolTab _tab = SchoolTab.today;
  _AssignFilter _filter = _AssignFilter.open;
  String? _classFilter;
  String? _member;

  List<TrackerRecord> _kind(String k) => [
    for (final r
        in ref.watch(trackerKindProvider(k)).value ?? const <TrackerRecord>[])
      if (_member == null || r.memberId == null || r.memberId == _member) r,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final classes = [..._kind(TrackerKind.schoolClass)]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final assignments = _kind(TrackerKind.schoolAssignment);
    final study = _kind(TrackerKind.schoolStudy);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.navSchool,
        showBackButton: widget.showBackButton,
        actions: [
          FeatureDataAction(featureId: 'school'),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: _tab == SchoolTab.classes
                ? l10n.schNewClass
                : l10n.schNewAssignment,
            onPressed: () => switch (_tab) {
              SchoolTab.classes => showClassEditor(context),
              SchoolTab.study => showStudyEditor(context),
              _ => showAssignmentEditor(context),
            },
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: PrismTokens.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in SchoolTab.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: PrismChip(
                              label: switch (t) {
                                SchoolTab.today => l10n.schTabToday,
                                SchoolTab.classes => l10n.schTabClasses,
                                SchoolTab.assignments => l10n.schTabAssignments,
                                SchoolTab.study => l10n.schTabStudy,
                                SchoolTab.progress => l10n.schTabProgress,
                              },
                              selected: _tab == t,
                              onTap: () => setState(() => _tab = t),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TrackerMemberFilter(
                    value: _member,
                    onChanged: (m) => setState(() => _member = m),
                    onlyIds: {
                      for (final r
                          in ref
                                  .watch(
                                    trackerKindProvider(
                                      TrackerKind.schoolClass,
                                    ),
                                  )
                                  .value ??
                              const <TrackerRecord>[])
                        ?r.memberId,
                    },
                  ),
                  const SizedBox(height: 12),
                  SectionSwitcher(
                    id: _tab,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...switch (_tab) {
                          SchoolTab.today => _today(
                            context,
                            classes,
                            assignments,
                            study,
                          ),
                          SchoolTab.classes => _classes(
                            context,
                            classes,
                            assignments,
                          ),
                          SchoolTab.assignments => _assignments(
                            context,
                            classes,
                            assignments,
                          ),
                          SchoolTab.study => _study(context, classes, study),
                          SchoolTab.progress => _progress(
                            context,
                            classes,
                            assignments,
                            study,
                          ),
                        },
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _today(
    BuildContext context,
    List<TrackerRecord> classes,
    List<TrackerRecord> assignments,
    List<TrackerRecord> study,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = scheduleFor(classes, now);
    final nowMin = now.hour * 60 + now.minute;
    final overdue = [
      for (final a in assignments)
        if (isOverdue(a, now)) a,
    ];
    final soon = [
      for (final a in assignments)
        if (!isDone(a) &&
            a.occurredAt != null &&
            !a.occurredAt!.isBefore(now) &&
            a.occurredAt!.isBefore(now.add(const Duration(days: 7))))
          a,
    ]..sort((a, b) => a.occurredAt!.compareTo(b.occurredAt!));
    final byId = {for (final c in classes) c.id: c};
    final live = study
        .where((s) => s.flag('live') && s.endedAt == null)
        .toList();
    return [
      for (final s in live) _LiveStudyCard(session: s, cls: byId[s.parentId]),
      if (live.isEmpty)
        PrismButton(
          label: l10n.schStartStudying,
          icon: AppIcons.timer,
          tone: PrismButtonTone.filled,
          onPressed: () => _startStudy(context, classes),
        ),
      TrackerLabel(
        l10n.schTodaysClasses(DateFormat.EEEE(context.dateLocale).format(now)),
      ),
      if (today.isEmpty)
        Text(
          classes.isEmpty ? l10n.schNoClassesYet : l10n.schNoClassesToday,
          style: theme.textTheme.bodySmall,
        ),
      for (final (c, m) in today)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            accentColor: nowMin >= m.startMinute && nowMin < m.endMinute
                ? classColor(c)
                : null,
            onTap: () => _openClass(context, c),
            child: Row(
              children: [
                Container(width: 4, height: 36, color: classColor(c)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: theme.textTheme.titleSmall),
                      Text(
                        [
                          '${formatMinuteOfDay(m.startMinute)}–${formatMinuteOfDay(m.endMinute)}',
                          ?c.str(SchoolField.room),
                          ?c.str(SchoolField.teacher),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (nowMin >= m.startMinute && nowMin < m.endMinute)
                  Text(
                    l10n.schNow,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: classColor(c),
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (overdue.isNotEmpty) ...[
        TrackerLabel(l10n.schOverdue(overdue.length)),
        for (final a in overdue) _AssignmentTile(a: a, cls: byId[a.parentId]),
      ],
      TrackerLabel(l10n.schDueThisWeek),
      if (soon.isEmpty)
        Text(l10n.schNothingDue, style: theme.textTheme.bodySmall),
      for (final a in soon) _AssignmentTile(a: a, cls: byId[a.parentId]),
    ];
  }

  Future<void> _startStudy(
    BuildContext context,
    List<TrackerRecord> classes,
  ) async {
    String? classId;
    if (classes.isNotEmpty) {
      classId = await PrismSheet.show<String>(
        context: context,
        title: context.l10n.schStudyWhich,
        builder: (ctx) => Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismChip(
              label: ctx.l10n.schNoClass,
              selected: false,
              onTap: () => Navigator.of(ctx).pop(''),
            ),
            for (final c in classes)
              PrismChip(
                label: c.title,
                selected: false,
                onTap: () => Navigator.of(ctx).pop(c.id),
              ),
          ],
        ),
      );
      if (classId == null) return;
    }
    if (!context.mounted) return;
    await ref
        .read(trackerNotifierProvider.notifier)
        .create(
          kind: TrackerKind.schoolStudy,
          title: context.l10n.schStudySession,
          parentId: classId == null || classId.isEmpty ? null : classId,
          occurredAt: DateTime.now(),
          memberId: currentFronterId(ref),
          fields: {'live': true},
        );
  }

  void _openClass(BuildContext context, TrackerRecord c) =>
      PrismSheet.showFullScreen(
        context: context,
        builder: (context, scroll) =>
            ClassDetailSheet(classId: c.id, scroll: scroll),
      );

  List<Widget> _classes(
    BuildContext context,
    List<TrackerRecord> classes,
    List<TrackerRecord> assignments,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final by = groupByParent(assignments);
    if (classes.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.schNoClassesYet, textAlign: TextAlign.center),
        ),
        PrismButton(
          label: l10n.schNewClass,
          icon: AppIcons.add,
          tone: PrismButtonTone.filled,
          onPressed: () => showClassEditor(context),
        ),
      ];
    }
    return [
      for (final c in classes)
        Builder(
          builder: (context) {
            final list = by[c.id] ?? const <TrackerRecord>[];
            final pct = classPercent(list);
            final open = list.where((a) => !isDone(a)).length;
            final sched = classSchedule(c);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PrismSurface(
                onTap: () => _openClass(context, c),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 48,
                      decoration: BoxDecoration(
                        color: classColor(c),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: theme.textTheme.titleMedium),
                          Text(
                            [
                              if (sched.isNotEmpty)
                                sched
                                    .map(
                                      (m) => weekdayShort(context, m.weekday),
                                    )
                                    .toSet()
                                    .join(' '),
                              l10n.schOpenCount(open),
                              ?memberNameFor(ref, c.memberId),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (pct != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            letterGrade(pct),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: classColor(c),
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
    ];
  }

  List<Widget> _assignments(
    BuildContext context,
    List<TrackerRecord> classes,
    List<TrackerRecord> assignments,
  ) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final byId = {for (final c in classes) c.id: c};
    final shown =
        [
          for (final a in assignments)
            if ((_classFilter == null || a.parentId == _classFilter) &&
                switch (_filter) {
                  _AssignFilter.open => !isDone(a),
                  _AssignFilter.overdue => isOverdue(a, now),
                  _AssignFilter.done => isDone(a),
                  _AssignFilter.all => true,
                })
              a,
        ]..sort((a, b) {
          final ad = a.occurredAt, bd = b.occurredAt;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return _filter == _AssignFilter.done
              ? bd.compareTo(ad)
              : ad.compareTo(bd);
        });
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final f in _AssignFilter.values)
            PrismChip(
              label: switch (f) {
                _AssignFilter.open => l10n.schFilterOpen,
                _AssignFilter.overdue => l10n.schFilterOverdue,
                _AssignFilter.done => l10n.schDone,
                _AssignFilter.all => l10n.journalFilterAll,
              },
              selected: _filter == f,
              onTap: () => setState(() => _filter = f),
            ),
        ],
      ),
      if (classes.isNotEmpty) ...[
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c in classes)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    label: c.title,
                    selected: _classFilter == c.id,
                    selectedColor: classColor(c),
                    onTap: () => setState(
                      () => _classFilter = _classFilter == c.id ? null : c.id,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 8),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(l10n.schNoAssignments)),
        ),
      for (final a in shown) _AssignmentTile(a: a, cls: byId[a.parentId]),
    ];
  }

  List<Widget> _study(
    BuildContext context,
    List<TrackerRecord> classes,
    List<TrackerRecord> study,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final byId = {for (final c in classes) c.id: c};
    final done = study
        .where((s) => !(s.flag('live') && s.endedAt == null))
        .toList();
    final live = study
        .where((s) => s.flag('live') && s.endedAt == null)
        .toList();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final week = done
        .where((s) => (s.occurredAt ?? s.createdAt).isAfter(weekAgo))
        .fold(0, (t, s) => t + (s.integer(SchoolField.minutes) ?? 0));
    final total = done.fold(
      0,
      (t, s) => t + (s.integer(SchoolField.minutes) ?? 0),
    );
    final focus = [for (final s in done) ?s.integer(SchoolField.focus)];
    return [
      for (final s in live) _LiveStudyCard(session: s, cls: byId[s.parentId]),
      if (live.isEmpty)
        PrismButton(
          label: l10n.schStartStudying,
          icon: AppIcons.timer,
          tone: PrismButtonTone.filled,
          onPressed: () => _startStudy(context, classes),
        ),
      const SizedBox(height: 12),
      TrackerStatGrid(
        children: [
          TrackerStatTile(
            label: l10n.schStudyThisWeek,
            value: l10n.fitMinutesShort(week),
          ),
          TrackerStatTile(
            label: l10n.schStudyTotal,
            value: l10n.schHours((total / 60).toStringAsFixed(1)),
          ),
          TrackerStatTile(label: l10n.schSessions, value: '${done.length}'),
          TrackerStatTile(
            label: l10n.schAvgFocus,
            value: focus.isEmpty
                ? '–'
                : (focus.reduce((a, b) => a + b) / focus.length)
                      .toStringAsFixed(1),
          ),
        ],
      ),
      const SizedBox(height: 8),
      PrismButton(
        label: l10n.schLogStudy,
        icon: AppIcons.add,
        onPressed: () => showStudyEditor(context),
      ),
      TrackerLabel(l10n.fitTabHistory),
      if (done.isEmpty) Text(l10n.schNoStudy, style: theme.textTheme.bodySmall),
      for (final s in done)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            onTap: () => showStudyEditor(context, editing: s),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 32,
                  color: classColor(byId[s.parentId]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        byId[s.parentId]?.title ?? l10n.schNoClass,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        DateFormat.MMMEd(
                          context.dateLocale,
                        ).add_jm().format(s.occurredAt ?? s.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(l10n.fitMinutesShort(s.integer(SchoolField.minutes) ?? 0)),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _progress(
    BuildContext context,
    List<TrackerRecord> classes,
    List<TrackerRecord> assignments,
    List<TrackerRecord> study,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final by = groupByParent(assignments);
    final studyBy = groupByParent(study);
    final g = gpa(classes, by);
    final doneCount = assignments.where(isDone).length;
    final onTime = assignments
        .where(
          (a) =>
              isDone(a) &&
              a.occurredAt != null &&
              a.endedAt != null &&
              !a.endedAt!.isAfter(a.occurredAt!),
        )
        .length;
    return [
      TrackerStatGrid(
        children: [
          TrackerStatTile(
            label: l10n.schGpa,
            value: g == null ? '–' : g.toStringAsFixed(2),
            icon: AppIcons.navSchool,
          ),
          TrackerStatTile(
            label: l10n.schCompleted,
            value: '$doneCount / ${assignments.length}',
          ),
          TrackerStatTile(
            label: l10n.schOnTime,
            value: doneCount == 0
                ? '–'
                : '${(onTime * 100 / doneCount).round()}%',
          ),
          TrackerStatTile(
            label: l10n.schClassesCount,
            value: '${classes.length}',
          ),
        ],
      ),
      TrackerLabel(l10n.schGradesByClass),
      if (classes.isEmpty)
        Text(l10n.schNoClassesYet, style: theme.textTheme.bodySmall),
      for (final c in classes)
        Builder(
          builder: (context) {
            final pct = classPercent(by[c.id] ?? const []);
            final target = c.number(SchoolField.targetPercent);
            final need = target == null
                ? null
                : neededOnRemaining(by[c.id] ?? const [], target);
            final mins = (studyBy[c.id] ?? const <TrackerRecord>[]).fold(
              0,
              (t, s) => t + (s.integer(SchoolField.minutes) ?? 0),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PrismSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.title,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          pct == null
                              ? l10n.schNoGradesYet
                              : '${letterGrade(pct)} · ${pct.toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TrackerBar(
                      value: (pct ?? 0) / 100,
                      color: classColor(c),
                      height: 8,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        l10n.schStudiedHours((mins / 60).toStringAsFixed(1)),
                        if (target != null) l10n.schTargetIs(target.round()),
                        if (need != null)
                          need > 100
                              ? l10n.schTargetOutOfReach
                              : l10n.schNeedOnRest(
                                  need.clamp(0, 100).toStringAsFixed(0),
                                ),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
    ];
  }
}

class _AssignmentTile extends ConsumerWidget {
  const _AssignmentTile({required this.a, this.cls});

  final TrackerRecord a;
  final TrackerRecord? cls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final due = a.occurredAt;
    final score = assignmentScore(a);
    final overdue = isOverdue(a, now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PrismSurface(
        padding: EdgeInsets.zero,
        child: PrismCheckboxRow(
          checkboxAffinity: PrismCheckboxAffinity.leading,
          value: isDone(a),
          onChanged: (v) => ref
              .read(trackerNotifierProvider.notifier)
              .save(
                a.copyWith(endedAt: v ? DateTime.now() : null).withFields({
                  SchoolField.status: v
                      ? AssignmentStatus.done
                      : AssignmentStatus.todo,
                }),
              ),
          title: Text(
            a.title,
            style: isDone(a)
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: Text(
            [
              ?cls?.title,
              assignmentTypeLabel(l10n, a.str(SchoolField.type) ?? 'homework'),
              if (due != null)
                DateFormat.MMMEd(context.dateLocale).add_jm().format(due),
              if (score != null) '${(score * 100).toStringAsFixed(0)}%',
              if (a.integer(SchoolField.priority) == 3) l10n.schPriorityHigh,
            ].join(' · '),
            style: TextStyle(color: overdue ? theme.colorScheme.error : null),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDone(a))
                ShareToSocialButton(
                  title: a.title,
                  source: tr(context, 'School', 'Escuela'),
                  details: [
                    if (cls != null)
                      (tr(context, 'Class', 'Clase'), cls!.title),
                    (
                      tr(context, 'Type', 'Tipo'),
                      assignmentTypeLabel(
                        l10n,
                        a.str(SchoolField.type) ?? 'homework',
                      ),
                    ),
                    if (score != null)
                      (
                        tr(context, 'Score', 'Nota'),
                        '${(score * 100).toStringAsFixed(0)}%',
                      ),
                  ],
                ),
              IconButton(
                tooltip: l10n.edit,
                icon: Icon(AppIcons.edit, size: 18, color: classColor(cls)),
                onPressed: () => showAssignmentEditor(context, editing: a),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStudyCard extends ConsumerStatefulWidget {
  const _LiveStudyCard({required this.session, this.cls});

  final TrackerRecord session;
  final TrackerRecord? cls;

  @override
  ConsumerState<_LiveStudyCard> createState() => _LiveStudyCardState();
}

class _LiveStudyCardState extends ConsumerState<_LiveStudyCard> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _finish() async {
    final s = widget.session;
    final now = DateTime.now();
    final done = s.copyWith(endedAt: now).withFields({
      'live': null,
      SchoolField.minutes: (now.difference(s.occurredAt ?? now).inSeconds / 60)
          .ceil()
          .clamp(1, 100000),
    });
    await ref.read(trackerNotifierProvider.notifier).save(done);
    if (mounted) await showStudyEditor(context, editing: done);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final elapsed = DateTime.now().difference(
      widget.session.occurredAt ?? DateTime.now(),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PrismSurface(
        accentColor: classColor(widget.cls),
        child: Row(
          children: [
            Icon(AppIcons.timer, color: classColor(widget.cls)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.cls?.title ?? l10n.schStudySession,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    formatElapsed(elapsed.isNegative ? Duration.zero : elapsed),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            PrismButton(
              label: l10n.fitFinish,
              tone: PrismButtonTone.filled,
              onPressed: _finish,
            ),
            IconButton(
              tooltip: l10n.trackerDelete,
              icon: Icon(AppIcons.close),
              onPressed: () => ref
                  .read(trackerNotifierProvider.notifier)
                  .delete(widget.session.id),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything about one class: schedule, grade, target and assignments.
class ClassDetailSheet extends ConsumerWidget {
  const ClassDetailSheet({super.key, required this.classId, this.scroll});

  final String classId;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c =
        (ref.watch(trackerKindProvider(TrackerKind.schoolClass)).value ??
                const <TrackerRecord>[])
            .where((x) => x.id == classId)
            .firstOrNull;
    if (c == null) {
      return SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(title: l10n.navSchool),
            Expanded(child: Center(child: Text(l10n.schClassGone))),
          ],
        ),
      );
    }
    final list =
        (ref.watch(trackerKindProvider(TrackerKind.schoolAssignment)).value ??
                const <TrackerRecord>[])
            .where((a) => a.parentId == c.id)
            .toList()
          ..sort(
            (a, b) => (a.occurredAt ?? DateTime(9999)).compareTo(
              b.occurredAt ?? DateTime(9999),
            ),
          );
    final pct = classPercent(list);
    final target = c.number(SchoolField.targetPercent);
    final need = target == null ? null : neededOnRemaining(list, target);
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(title: c.title),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrismButton(
                      label: l10n.edit,
                      icon: AppIcons.edit,
                      density: PrismControlDensity.compact,
                      onPressed: () => showClassEditor(context, editing: c),
                    ),
                    PrismButton(
                      label: l10n.schNewAssignment,
                      icon: AppIcons.add,
                      density: PrismControlDensity.compact,
                      onPressed: () =>
                          showAssignmentEditor(context, classId: c.id),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (c.str(SchoolField.teacher) != null)
                  Text(l10n.schTeacherIs(c.str(SchoolField.teacher)!)),
                if (c.str(SchoolField.room) != null)
                  Text(l10n.schRoomIs(c.str(SchoolField.room)!)),
                if (c.number(SchoolField.credits) != null)
                  Text(
                    l10n.schCreditsIs(
                      c.number(SchoolField.credits)!.toString(),
                    ),
                  ),
                TrackerLabel(l10n.schSchedule),
                for (final m in classSchedule(c))
                  Text(
                    '${DateFormat.EEEE(context.dateLocale).format(DateTime(2024, 1, m.weekday))} ${formatMinuteOfDay(m.startMinute)}–${formatMinuteOfDay(m.endMinute)}',
                  ),
                if (classSchedule(c).isEmpty)
                  Text(l10n.schNoSchedule, style: theme.textTheme.bodySmall),
                TrackerLabel(l10n.schGrade),
                Text(
                  pct == null
                      ? l10n.schNoGradesYet
                      : '${letterGrade(pct)} · ${pct.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: classColor(c),
                  ),
                ),
                if (need != null)
                  Text(
                    need > 100
                        ? l10n.schTargetOutOfReach
                        : l10n.schNeedOnRest(
                            need.clamp(0, 100).toStringAsFixed(0),
                          ),
                  ),
                TrackerLabel(l10n.schTabAssignments),
                if (list.isEmpty)
                  Text(l10n.schNoAssignments, style: theme.textTheme.bodySmall),
                for (final a in list) _AssignmentTile(a: a, cls: c),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
