import 'dart:async';

import 'package:prism_plurality/shared/widgets/section_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:prism_plurality/features/prism_social/social_share.dart';
import 'package:prism_plurality/shared/l10n/tr.dart';
import 'package:prism_plurality/features/fitness/health/health_banner.dart';
import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/fitness/utils/fitness.dart';
import 'package:prism_plurality/features/fitness/views/fitness_editors.dart';
import 'package:prism_plurality/features/fitness/views/fitness_labels.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

enum FitnessTab { overview, history, exercises, goals }

String formatElapsed(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

bool isLiveWorkout(TrackerRecord w) => w.flag('live') && w.endedAt == null;

class FitnessScreen extends ConsumerStatefulWidget {
  const FitnessScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends ConsumerState<FitnessScreen> {
  FitnessTab _tab = FitnessTab.overview;
  String? _activityFilter;
  String? _member;

  Future<void> _startLive(BuildContext context) async {
    final activity = await PrismSheet.show<String>(
      context: context,
      title: context.l10n.fitStartWhich,
      builder: (ctx) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final a in fitnessActivities)
            PrismChip(
              label: fitnessActivityLabel(ctx.l10n, a),
              selected: false,
              onTap: () => Navigator.of(ctx).pop(a),
            ),
        ],
      ),
    );
    if (activity == null || !context.mounted) return;
    await ref
        .read(trackerNotifierProvider.notifier)
        .create(
          kind: TrackerKind.fitnessWorkout,
          title: fitnessActivityLabel(context.l10n, activity),
          occurredAt: DateTime.now(),
          memberId: currentFronterId(ref),
          fields: {FitField.activity: activity, 'live': true},
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all =
        ref.watch(trackerKindProvider(TrackerKind.fitnessWorkout)).value ??
        const <TrackerRecord>[];
    final live = all.where(isLiveWorkout).toList();
    final workouts = all
        .where((w) => !isLiveWorkout(w))
        .where((w) => _member == null || w.memberId == _member)
        .toList();
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.navFitness,
        showBackButton: widget.showBackButton,
        actions: [
          FeatureDataAction(featureId: 'fitness'),
          if (ref.watch(featureEnabledProvider('healthIntegration')))
            PrismTopBarAction(
              icon: PhosphorIcons.heartbeat(),
              tooltip: tr(
                context,
                'Connected apps',
                'Apps conectadas',
              ),
              onPressed: () => context.push('/fitness/integrations'),
            ),

          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: _tab == FitnessTab.goals
                ? l10n.fitNewGoal
                : l10n.fitNewWorkout,
            onPressed: () => _tab == FitnessTab.goals
                ? showFitnessGoalEditor(context)
                : showWorkoutEditor(context),
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
                  const HealthFitnessBanner(),
                  for (final w in live) _LiveCard(workout: w),
                  if (live.isEmpty)
                    PrismButton(
                      label: l10n.fitStartWorkout,
                      icon: AppIcons.navFitness,
                      tone: PrismButtonTone.filled,
                      onPressed: () => _startLive(context),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final t in FitnessTab.values)
                        PrismChip(
                          label: switch (t) {
                            FitnessTab.overview => l10n.finTabOverview,
                            FitnessTab.history => l10n.fitTabHistory,
                            FitnessTab.exercises => l10n.fitExercises,
                            FitnessTab.goals => l10n.finTabGoals,
                          },
                          selected: _tab == t,
                          onTap: () => setState(() => _tab = t),
                        ),
                    ],
                  ),
                  TrackerMemberFilter(
                    value: _member,
                    onChanged: (m) => setState(() => _member = m),
                    onlyIds: {for (final w in all) ?w.memberId},
                  ),
                  const SizedBox(height: 12),
                  SectionSwitcher(
                    id: _tab,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...switch (_tab) {
                          FitnessTab.overview => _overview(context, workouts),
                          FitnessTab.history => _history(context, workouts),
                          FitnessTab.exercises => _exercises(context, workouts),
                          FitnessTab.goals => _goals(context, workouts),
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

  List<Widget> _overview(BuildContext context, List<TrackerRecord> workouts) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final ws = weekStart(now);
    final week = totalsBetween(workouts, ws, ws.add(const Duration(days: 7)));
    final weeks = weeklyTotals(workouts, now);
    final maxMin = weeks.fold<int>(
      1,
      (m, w) => w.$2.minutes > m ? w.$2.minutes : m,
    );
    final byActivity = <String, int>{};
    for (final w in workouts) {
      final a = workoutActivity(w);
      byActivity[a] = (byActivity[a] ?? 0) + workoutMinutes(w);
    }
    final acts = byActivity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalMin = byActivity.values.fold(0, (a, b) => a + b);
    final bests = personalBests(workouts);
    final goals =
        ref.watch(trackerKindProvider(TrackerKind.fitnessGoal)).value ??
        const <TrackerRecord>[];
    return [
      TrackerStatGrid(
        children: [
          TrackerStatTile(
            label: l10n.fitThisWeekWorkouts,
            value: '${week.workouts}',
            icon: AppIcons.navFitness,
          ),
          TrackerStatTile(
            label: l10n.fitThisWeekMinutes,
            value: '${week.minutes}',
            icon: AppIcons.timer,
          ),
          TrackerStatTile(
            label: l10n.fitThisWeekKm,
            value: week.km.toStringAsFixed(1),
            icon: AppIcons.locationOn,
          ),
          TrackerStatTile(
            label: l10n.fitWeekStreak,
            value: l10n.fitWeeks(weekStreak(workouts, now)),
            icon: AppIcons.navAchievements,
          ),
        ],
      ),
      if (goals.isNotEmpty) ...[
        TrackerLabel(l10n.finTabGoals),
        for (final g in goals) _GoalTile(goal: g, workouts: workouts),
      ],
      TrackerLabel(l10n.fitMinutesPerWeek),
      PrismSurface(
        child: SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (start, t) in weeks)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${t.minutes}', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: (t.minutes / maxMin).clamp(0.02, 1),
                            child: Container(
                              width: 16,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.Md(context.dateLocale).format(start),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      if (acts.isNotEmpty) ...[
        TrackerLabel(l10n.fitByActivity),
        PrismSurface(
          child: Column(
            children: [
              for (final a in acts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(fitnessActivityLabel(l10n, a.key)),
                          ),
                          Text(l10n.fitMinutesShort(a.value)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      TrackerBar(value: totalMin == 0 ? 0 : a.value / totalMin),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      if (bests.isNotEmpty) ...[
        TrackerLabel(l10n.fitPersonalBests),
        for (final b in bests.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(fitnessActivityLabel(l10n, b.key))),
                Text(
                  [
                    l10n.fitMinutesShort(b.value.$1),
                    if (b.value.$2 > 0) '${b.value.$2.toStringAsFixed(1)} km',
                  ].join(' · '),
                ),
              ],
            ),
          ),
      ],
      if (workouts.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(l10n.fitEmpty, textAlign: TextAlign.center),
          ),
        ),
    ];
  }

  List<Widget> _history(BuildContext context, List<TrackerRecord> workouts) {
    final l10n = context.l10n;
    final shown = [
      for (final w in workouts)
        if (_activityFilter == null || workoutActivity(w) == _activityFilter) w,
    ];
    final used = {for (final w in workouts) workoutActivity(w)};
    final out = <Widget>[
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          PrismChip(
            label: l10n.journalFilterAll,
            selected: _activityFilter == null,
            onTap: () => setState(() => _activityFilter = null),
          ),
          for (final a in fitnessActivities)
            if (used.contains(a))
              PrismChip(
                label: fitnessActivityLabel(l10n, a),
                selected: _activityFilter == a,
                onTap: () => setState(() => _activityFilter = a),
              ),
        ],
      ),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(l10n.fitEmpty)),
        ),
    ];
    String? month;
    for (final w in shown) {
      final d = w.occurredAt ?? w.createdAt;
      final m = DateFormat.yMMMM(context.dateLocale).format(d);
      if (m != month) {
        month = m;
        out.add(TrackerLabel(m));
      }
      out.add(_WorkoutTile(workout: w));
    }
    return out;
  }

  List<Widget> _exercises(BuildContext context, List<TrackerRecord> workouts) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final stats = exerciseHistory(workouts);
    if (stats.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.fitNoExercises, textAlign: TextAlign.center),
        ),
      ];
    }
    return [
      for (final s in stats)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.exercise, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  [
                    l10n.fitSessions(s.sessions),
                    if (s.bestWeightKg > 0)
                      l10n.fitBestWeight(s.bestWeightKg.toStringAsFixed(1)),
                    if (s.bestReps > 0) l10n.fitBestReps(s.bestReps),
                    if (s.totalVolume > 0)
                      l10n.fitVolume(s.totalVolume.round()),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  l10n.fitLastDone(
                    DateFormat.yMMMd(context.dateLocale).format(s.lastDone),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _goals(BuildContext context, List<TrackerRecord> workouts) {
    final l10n = context.l10n;
    final goals =
        ref.watch(trackerKindProvider(TrackerKind.fitnessGoal)).value ??
        const <TrackerRecord>[];
    return [
      if (goals.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(l10n.fitNoGoals),
        ),
      for (final g in goals) _GoalTile(goal: g, workouts: workouts),
      const SizedBox(height: 12),
      PrismButton(
        label: l10n.fitNewGoal,
        icon: AppIcons.add,
        onPressed: () => showFitnessGoalEditor(context),
      ),
    ];
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.workouts});

  final TrackerRecord goal;
  final List<TrackerRecord> workouts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (cur, target) = goalProgress(goal, workouts, DateTime.now());
    String fmt(num v) => v is double && v != v.roundToDouble()
        ? v.toStringAsFixed(1)
        : '${v.round()}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PrismSurface(
        onTap: () => showFitnessGoalEditor(context, editing: goal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(goal.title, style: theme.textTheme.titleSmall),
                ),
                Text('${fmt(cur)} / ${fmt(target)}'),
              ],
            ),
            const SizedBox(height: 6),
            TrackerBar(value: target == 0 ? 0 : cur / target, height: 8),
            if (target > 0 && cur >= target)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.finGoalReached,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutTile extends ConsumerWidget {
  const _WorkoutTile({required this.workout});

  final TrackerRecord workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final w = workout;
    final who = memberNameFor(ref, w.memberId);
    final d = w.occurredAt ?? w.createdAt;
    final mood = w.integer(FitField.moodAfter);
    final sets = workoutSets(w);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PrismSurface(
        onTap: () => showWorkoutEditor(context, editing: w),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.title.isNotEmpty
                        ? w.title
                        : fitnessActivityLabel(
                            l10n,
                            w.str(FitField.activity) ?? 'other',
                          ),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    [
                      DateFormat.MMMEd(context.dateLocale).add_jm().format(d),
                      if (w.flag('imported'))
                        tr(
                          context,
                          'from ${w.str('source') ?? 'a health app'}',
                          'de ${w.str('source') ?? 'una app de salud'}',
                        ),
                      if (workoutMinutes(w) > 0)
                        l10n.fitMinutesShort(workoutMinutes(w)),
                      if (workoutKm(w) > 0)
                        '${workoutKm(w).toStringAsFixed(1)} km',
                      if (workoutCalories(w) > 0) '${workoutCalories(w)} kcal',
                      if (w.integer(FitField.effort) != null)
                        l10n.fitEffortValue(w.integer(FitField.effort)!),
                      if (sets.isNotEmpty) l10n.fitExerciseCount(sets.length),
                      ?who,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (mood != null) MoodFace(level: mood, size: 28),
            ShareToSocialButton(
              title: w.title.isNotEmpty
                  ? w.title
                  : fitnessActivityLabel(
                      l10n,
                      w.str(FitField.activity) ?? 'other',
                    ),
              source: tr(context, 'Workout', 'Entrenamiento'),
              details: [
                (
                  tr(context, 'Date', 'Fecha'),
                  DateFormat.yMMMd(context.dateLocale).format(d),
                ),
                if (workoutMinutes(w) > 0)
                  (
                    tr(context, 'Duration', 'Duración'),
                    l10n.fitMinutesShort(workoutMinutes(w)),
                  ),
                if (workoutKm(w) > 0)
                  (
                    tr(context, 'Distance', 'Distancia'),
                    '${workoutKm(w).toStringAsFixed(1)} km',
                  ),
                if (workoutCalories(w) > 0)
                  (
                    tr(context, 'Energy', 'Energía'),
                    '${workoutCalories(w)} kcal',
                  ),
                if (sets.isNotEmpty)
                  (tr(context, 'Exercises', 'Ejercicios'), '${sets.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A workout in progress, ticking every second; survives restarts because
/// its start time is stored.
class _LiveCard extends ConsumerStatefulWidget {
  const _LiveCard({required this.workout});

  final TrackerRecord workout;

  @override
  ConsumerState<_LiveCard> createState() => _LiveCardState();
}

class _LiveCardState extends ConsumerState<_LiveCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _finish() async {
    final w = widget.workout;
    final now = DateTime.now();
    final minutes = now.difference(w.occurredAt ?? now).inSeconds / 60;
    final done = w.copyWith(endedAt: now).withFields({
      'live': null,
      FitField.minutes: minutes.ceil().clamp(1, 100000),
    });
    await ref.read(trackerNotifierProvider.notifier).save(done);
    if (mounted) await showWorkoutEditor(context, editing: done);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final w = widget.workout;
    final elapsed = DateTime.now().difference(w.occurredAt ?? DateTime.now());
    return PrismSurface(
      accentColor: theme.colorScheme.primary,
      child: Row(
        children: [
          Icon(AppIcons.navFitnessActive, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.title, style: theme.textTheme.titleSmall),
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
            onPressed: () =>
                ref.read(trackerNotifierProvider.notifier).delete(w.id),
          ),
        ],
      ),
    );
  }
}
