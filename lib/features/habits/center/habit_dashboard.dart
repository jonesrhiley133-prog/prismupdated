import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/habit_completion.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/habits/center/habit_center_data.dart';
import 'package:prism_plurality/features/habits/center/habit_sheets.dart';
import 'package:prism_plurality/features/habits/center/habit_visuals.dart';
import 'package:prism_plurality/features/habits/views/add_edit_habit_sheet.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/features/links/views/record_opener.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/prism_social/social_share.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/live_ticker.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

enum _Range { week, month, year, all }

class HabitDashboardScreen extends ConsumerStatefulWidget {
  const HabitDashboardScreen({super.key, required this.habitId});
  final String habitId;
  @override
  ConsumerState<HabitDashboardScreen> createState() =>
      _HabitDashboardScreenState();
}

class _HabitDashboardScreenState extends ConsumerState<HabitDashboardScreen> {
  _Range _range = _Range.month;

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(habitViewsProvider)[widget.habitId];
    if (view == null) {
      return PrismPageScaffold(
        topBar: PrismTopBar(
          title: tr(context, 'Habit', 'Hábito'),
          showBackButton: true,
        ),
        body: Center(
          child: Text(
            tr(
              context,
              'This habit isn’t available.',
              'Este hábito no está disponible.',
            ),
          ),
        ),
      );
    }
    final h = view.habit, m = view.meta;
    final timer = ref.watch(habitTimersProvider)[h.id];
    final color = habitColor(context, h);
    final today = dayKey(DateTime.now());
    final todays = view.byDay[today] ?? const <HabitCompletion>[];
    final progress = view.todayProgress;
    final remaining = math.max(0, m.target - progress);
    final state = view.stateOn(today);
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: '',
        showBackButton: true,
        actions: [
          ShareToSocialButton(
            title: view.habit.name,
            source: tr(context, 'Habit', 'Hábito'),
            details: [
              (
                tr(context, 'Current streak', 'Racha actual'),
                tr(
                  context,
                  '${view.currentStreak} days',
                  '${view.currentStreak} días',
                ),
              ),
              (
                tr(context, 'Longest streak', 'Racha más larga'),
                tr(
                  context,
                  '${view.longestStreak} days',
                  '${view.longestStreak} días',
                ),
              ),
            ],
          ),
          PrismTopBarAction(
            icon: AppIcons.moreVert,
            tooltip: tr(context, 'Habit options', 'Opciones del hábito'),
            onPressed: () => _menu(view),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              NavBarInset.of(context) + 24,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: PrismTokens.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _identity(view, state),
                      const SizedBox(height: 18),
                      _progressRow(view, progress, remaining, timer, color),
                      const SizedBox(height: 18),
                      HabitSectionTitle(
                        icon: PhosphorIcons.sparkle(),
                        title: tr(
                          context,
                          'Today’s activity',
                          'Actividad de hoy',
                        ),
                      ),
                      _timeline(view, todays),
                      const SizedBox(height: 8),
                      GlowPill(
                        label: tr(context, 'Log another', 'Registrar otro'),
                        icon: PhosphorIcons.plus(),
                        height: 48,
                        color: color,
                        onTap: () => showHabitLogSheet(context, habit: h),
                      ),
                      const SizedBox(height: 16),
                      _weekly(view, color),
                      _connections(view),
                      _pattern(view),
                      _rhythm(view, color),
                      _alters(view),
                      _milestones(view),
                      _reflections(view),
                      _history(view, color),
                      const SizedBox(height: 8),
                      if (state != DayState.met)
                        GlowPill(
                          label: tr(
                            context,
                            'Complete target',
                            'Completar meta',
                          ),
                          icon: PhosphorIcons.check(),
                          color: habitGold(context),
                          onTap: () => _completeTarget(view, remaining),
                        )
                      else
                        Center(
                          child: Text(
                            '✓ ${tr(context, 'Target complete for today', 'Meta de hoy completada')}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: habitGold(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _identity(HabitView view, DayState state) {
    final h = view.habit, m = view.meta;
    final theme = Theme.of(context);
    final gold = habitGold(context);
    final streak = view.currentStreak;
    final pill = switch (state) {
      _ when m.isPausedOn(DateTime.now()) => (
        '⏸',
        tr(context, 'Paused', 'En pausa'),
      ),
      DayState.skipped => ('↷', tr(context, 'Skipped today', 'Omitido hoy')),
      DayState.rest => ('🌙', tr(context, 'Rest day', 'Día de descanso')),
      _ => ('🔥', tr(context, '$streak day streak', 'Racha de $streak días')),
    };
    return Row(
      children: [
        HabitIconBadge(habit: h, size: 84),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                h.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                h.description?.isNotEmpty == true
                    ? h.description!
                    : scheduleText(context, h, m),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.12),
                  borderRadius: prismCorners(context, 20),
                  border: Border.all(color: gold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${pill.$1} ${pill.$2}',
                  style: theme.textTheme.labelLarge?.copyWith(color: gold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progressRow(
    HabitView view,
    num progress,
    num remaining,
    TrackerRecord? timer,
    Color color,
  ) {
    final h = view.habit, m = view.meta;
    final theme = Theme.of(context);
    final actions = ref.read(habitCenterActionsProvider);
    final unit = unitWord(context, m, m.target);
    String two(int n) => n.toString().padLeft(2, '0');
    final elapsed = timer == null ? null : HabitCenterActions.elapsed(timer);
    final ring = GlowRing(
      fraction: view.todayFraction,
      color: color,
      size: 160,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${fmtNum(progress)} / ${m.target}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(unit, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          SizedBox(
            width: 90,
            child: Divider(color: theme.colorScheme.outlineVariant),
          ),
          Text(
            remaining <= 0
                ? '✓ ${tr(context, 'done', 'hecho')}'
                : tr(
                    context,
                    '${fmtNum(remaining)} to go',
                    'faltan ${fmtNum(remaining)}',
                  ),
            style: theme.textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
    final quickLabel = m.unit == HabitUnit.minutes
        ? tr(
            context,
            'Log ${m.defaultMinutes} min',
            'Registrar ${m.defaultMinutes} min',
          )
        : tr(
            context,
            'Add ${m.unitLabel?.isNotEmpty == true ? m.unitLabel : 'one'}',
            'Añadir ${m.unitLabel?.isNotEmpty == true ? m.unitLabel : 'uno'}',
          );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlowPill(
          label: quickLabel,
          icon: PhosphorIcons.plus(),
          color: color,
          height: 60,
          onTap: () async {
            await actions.log(
              habit: h,
              memberId: currentFronterId(ref),
              minutes: m.unit == HabitUnit.minutes ? m.defaultMinutes : null,
            );
            _afterLog(view);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: HabitActionTile(
                icon: PhosphorIcons.drop(),
                label: tr(context, 'Log amount', 'Registrar cantidad'),
                onTap: () => showHabitLogSheet(context, habit: h),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              // Only this tile follows a running timer (once a second);
              // the rest of the dashboard does not rebuild with it.
              child: timer != null && timer.str('pausedAt') == null
                  ? LiveTicker(
                      builder: (context, _) {
                        final e = HabitCenterActions.elapsed(timer);
                        return HabitActionTile(
                          icon: PhosphorIcons.pause(),
                          label: '${two(e.inMinutes)}:${two(e.inSeconds % 60)}',
                          active: true,
                          onTap: () => actions.pauseTimer(timer),
                        );
                      },
                    )
                  : HabitActionTile(
                      icon: timer == null
                          ? PhosphorIcons.timer()
                          : PhosphorIcons.play(),
                      label: timer == null
                          ? tr(context, 'Start timer', 'Iniciar')
                          : '${two(elapsed!.inMinutes)}:${two(elapsed.inSeconds % 60)}',
                      active: timer != null,
                      onTap: () => timer == null
                          ? actions.startTimer(h.id)
                          : actions.pauseTimer(timer),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HabitActionTile(
                icon: PhosphorIcons.notePencil(),
                label: tr(context, 'Add note', 'Añadir nota'),
                onTap: () {
                  final last =
                      (view.byDay[dayKey(DateTime.now())] ??
                              const <HabitCompletion>[])
                          .firstOrNull;
                  showHabitLogSheet(
                    context,
                    habit: h,
                    editing: last,
                    focusNote: true,
                  );
                },
              ),
            ),
          ],
        ),
        if (timer != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PrismButton(
                  label: tr(context, 'Finish & log', 'Terminar y registrar'),
                  icon: PhosphorIcons.flagCheckered(),
                  tone: PrismButtonTone.filled,
                  onPressed: () async {
                    final mins = math.max(
                      1,
                      HabitCenterActions.elapsed(timer).inMinutes,
                    );
                    await actions.discardTimer(timer);
                    if (mounted)
                      await showHabitLogSheet(context, habit: h, minutes: mins);
                  },
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Discard timer', 'Descartar'),
                icon: Icon(AppIcons.close),
                onPressed: () => actions.discardTimer(timer),
              ),
            ],
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 360
          ? Column(children: [ring, const SizedBox(height: 12), side])
          : Row(
              children: [
                ring,
                const SizedBox(width: 14),
                Expanded(child: side),
              ],
            ),
    );
  }

  void _afterLog(HabitView view) {
    final now = ref.read(habitViewsProvider)[view.habit.id];
    if (now == null || !mounted) return;
    if (now.todayProgress >= now.meta.target) {
      final next = [
        for (final id in now.meta.nextHabits) ?ref.read(habitViewsProvider)[id],
      ].where((v) => v.isDueToday).toList();
      PrismToast.show(
        context,
        message: next.isEmpty
            ? tr(
                context,
                'Target reached for today 🎉',
                'Meta de hoy alcanzada 🎉',
              )
            : tr(
                context,
                'Target reached! Up next: ${next.first.habit.name}',
                '¡Meta alcanzada! Siguiente: ${next.first.habit.name}',
              ),
        icon: PhosphorIcons.sparkle(),
      );
    }
  }

  Future<void> _completeTarget(HabitView view, num remaining) async {
    final m = view.meta;
    if (remaining <= 0) return;
    await ref
        .read(habitCenterActionsProvider)
        .log(
          habit: view.habit,
          memberId: currentFronterId(ref),
          count: m.unit == HabitUnit.times ? remaining.ceil() : 1,
          minutes: m.unit == HabitUnit.minutes ? remaining.ceil() : null,
          amount: m.unit == HabitUnit.amount ? remaining.toDouble() : null,
        );
    _afterLog(view);
  }

  Widget _timeline(HabitView view, List<HabitCompletion> todays) {
    final theme = Theme.of(context);
    final members = {
      for (final mm in ref.watch(allMembersProvider).value ?? const <Member>[])
        mm.id: mm,
    };
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    if (todays.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          tr(context, 'Nothing logged yet today.', 'Aún no hay registros hoy.'),
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    return Column(
      children: [
        for (final (i, c) in todays.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: 2,
                          color: i == 0
                              ? Colors.transparent
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: prismRound(context),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 2,
                          color: i == todays.length - 1
                              ? Colors.transparent
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: HabitCard(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    onTap: () => showHabitLogSheet(
                      context,
                      habit: view.habit,
                      editing: c,
                    ),
                    child: Row(
                      children: [
                        if (members[c.completedByMemberId] case final mm?)
                          MemberAvatar(
                            avatarImageData: mm.avatarImageData,
                            memberName: mm.effectiveName(
                              preferDisplayName: prefer,
                            ),
                            emoji: mm.emoji,
                            customColorEnabled: mm.customColorEnabled,
                            customColorHex: mm.customColorHex,
                            size: 44,
                          )
                        else
                          HabitIconBadge(habit: view.habit, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat.jm(
                                  context.dateLocale,
                                ).format(c.completedAt),
                                style: theme.textTheme.titleSmall,
                              ),
                              Text(
                                [
                                  _amountText(view, c),
                                  if (members[c.completedByMemberId]
                                      case final mm?)
                                    tr(
                                      context,
                                      'by ${mm.effectiveName(preferDisplayName: prefer)}',
                                      'por ${mm.effectiveName(preferDisplayName: prefer)}',
                                    ),
                                  if (view.logOf(c).source != null)
                                    tr(context, 'auto', 'auto'),
                                ].join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (c.rating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: habitGold(context).withValues(alpha: 0.1),
                              borderRadius: prismCorners(context, 14),
                            ),
                            child: StarRow(value: c.rating, size: 14),
                          ),
                        Icon(AppIcons.chevronRight, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _amountText(HabitView view, HabitCompletion c) {
    final l = view.logOf(c), m = view.meta;
    final main = switch (m.unit) {
      HabitUnit.times => '${l.count} ${unitWord(context, m, l.count)}',
      HabitUnit.minutes => '${l.minutes ?? m.defaultMinutes} min',
      HabitUnit.amount =>
        '${fmtNum(l.amount ?? 1)} ${m.unitLabel ?? ''}'.trim(),
    };
    return [
      main,
      if (m.unit != HabitUnit.minutes && l.minutes != null) '${l.minutes} min',
    ].join(' · ');
  }

  Widget _weekly(HabitView view, Color color) {
    final theme = Theme.of(context);
    final today = dayKey(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    final values = [for (final d in days) view.progressOn(d).toDouble()];
    final maxY =
        [...values, view.meta.target.toDouble()].reduce(math.max) * 1.2;
    return HabitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.chartBar(), color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(context, 'This week', 'Esta semana'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${fmtNum(view.todayProgress)} / ${view.meta.target} ${tr(context, 'today', 'hoy')}',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: maxY <= 0 ? 1 : maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: view.meta.target.toDouble(),
                      color: habitGold(context).withValues(alpha: 0.6),
                      dashArray: [5, 4],
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        DateFormat.E(
                          context.dateLocale,
                        ).format(days[v.toInt()]),
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < 7; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i],
                          width: 26,
                          borderRadius: prismCorners(context, 8),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [color.withValues(alpha: 0.55), color],
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: days[i].isAfter(today),
                            toY: maxY,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.04,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connections(HabitView view) {
    final links = ref.watch(recordLinksProvider);
    final catalog = ref.watch(recordCatalogProvider);
    final keys = {
      RecordRef(RecordRef.habit, view.habit.id).key,
      for (final c in view.completions) RecordRef(RecordRef.habitLog, c.id).key,
    };
    final byModule = <String, List<RecordInfo>>{};
    for (final l in links) {
      final mine = keys.contains(l.a.key)
          ? l.b
          : (keys.contains(l.b.key) ? l.a : null);
      if (mine == null || keys.contains(mine.key)) continue;
      final info = catalog[mine.key];
      if (info != null) byModule.putIfAbsent(info.module, () => []).add(info);
    }
    // Places and alters recorded on completions count as connections too.
    final people = {for (final c in view.completions) ?c.completedByMemberId};
    final theme = Theme.of(context);
    return HabitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.linkSimple(),
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(context, 'Connected to', 'Conectado con'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PrismButton(
                label: tr(context, 'Connect', 'Conectar'),
                icon: AppIcons.add,
                density: PrismControlDensity.compact,
                onPressed: () => showLinkPicker(
                  context,
                  RecordRef(RecordRef.habit, view.habit.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (byModule.isEmpty && people.isEmpty)
            Text(
              tr(
                context,
                'Link moods, journal entries, sleep, places and more to this habit or to single completions.',
                'Enlaza ánimos, diario, sueño, lugares y más con este hábito o con registros concretos.',
              ),
              style: theme.textTheme.bodySmall,
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in byModule.entries)
                _ModuleChip(
                  module: moduleFor(e.key),
                  count: e.value.length,
                  onTap: () => PrismSheet.show(
                    context: context,
                    title: moduleFor(e.key).label(context),
                    builder: (ctx) => ListView(
                      shrinkWrap: true,
                      children: [
                        for (final i in e.value)
                          PrismListRow(
                            title: Text(i.isPrivate ? '🔒' : i.title),
                            subtitle: i.date == null
                                ? null
                                : Text(shortDate(ctx, i.date)),
                            onTap: () => openRecord(ctx, ref, i),
                          ),
                      ],
                    ),
                  ),
                ),
              if (people.isNotEmpty)
                _ModuleChip(
                  module: moduleFor('member'),
                  count: people.length,
                  onTap: () {},
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pattern(HabitView view) {
    final cs = view.completions;
    if (cs.length < 3) return const SizedBox.shrink();
    final notes = <String>[];
    final parts = [0, 0, 0, 0]; // night, morning, afternoon, evening
    for (final c in cs) {
      final h = c.completedAt.hour;
      parts[h < 5
          ? 0
          : h < 12
          ? 1
          : h < 17
          ? 2
          : h < 22
          ? 3
          : 0]++;
    }
    final best = parts.indexOf(parts.reduce(math.max));
    final when = [
      tr(context, 'at night', 'de noche'),
      tr(context, 'in the morning', 'por la mañana'),
      tr(context, 'in the afternoon', 'por la tarde'),
      tr(context, 'in the evening', 'al anochecer'),
    ][best];
    notes.add(
      tr(context, 'You tend to log this $when.', 'Sueles registrarlo $when.'),
    );
    final byMember = <String, int>{};
    for (final c in cs) {
      if (c.completedByMemberId != null)
        byMember[c.completedByMemberId!] =
            (byMember[c.completedByMemberId!] ?? 0) + 1;
    }
    if (byMember.length > 1) {
      final top = byMember.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final name = memberNameFor(ref, top.key);
      if (name != null)
        notes.add(
          tr(
            context,
            '$name logs it most often (${(top.value * 100 / cs.length).round()}%).',
            '$name lo registra más a menudo (${(top.value * 100 / cs.length).round()}%).',
          ),
        );
    }
    // Mood on days the target was met vs not (observation, not cause).
    final moods = ref.watch(moodEntriesProvider).value ?? const <MoodEntry>[];
    final met = <double>[], notMet = <double>[];
    final byDayMood = <DateTime, List<int>>{};
    for (final e in moods) {
      byDayMood.putIfAbsent(dayKey(e.recordedAt), () => []).add(e.mood);
    }
    byDayMood.forEach((d, list) {
      final avg = list.reduce((a, b) => a + b) / list.length;
      final s = view.stateOn(d);
      if (s == DayState.met) met.add(avg);
      if (s == DayState.missed || s == DayState.partial) notMet.add(avg);
    });
    if (met.length >= 5 && notMet.length >= 5) {
      final a = met.reduce((x, y) => x + y) / met.length,
          b = notMet.reduce((x, y) => x + y) / notMet.length;
      if ((a - b).abs() >= 0.3) {
        notes.add(
          tr(
            context,
            'Average mood was ${a.toStringAsFixed(1)} on days you hit the target and ${b.toStringAsFixed(1)} on other days.',
            'El ánimo medio fue ${a.toStringAsFixed(1)} los días con la meta cumplida y ${b.toStringAsFixed(1)} los demás.',
          ),
        );
      }
    }
    final gold = habitGold(context);
    final theme = Theme.of(context);
    return HabitCard(
      accent: gold,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIcons.lightbulb(), color: gold, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'Your pattern', 'Tu patrón'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final n in notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(n),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (DateTime, DateTime) _bounds(HabitView view) {
    final now = DateTime.now();
    final end = dayKey(now).add(const Duration(days: 1));
    final start = switch (_range) {
      _Range.week => end.subtract(const Duration(days: 7)),
      _Range.month => end.subtract(const Duration(days: 30)),
      _Range.year => end.subtract(const Duration(days: 365)),
      _Range.all => dayKey(view.habit.createdAt),
    };
    return (start, end);
  }

  Widget _rhythm(HabitView view, Color color) {
    final theme = Theme.of(context);
    final (from, to) = _bounds(view);
    final cs = view.completionsBetween(from, to);
    final consistency = view.consistency(
      from,
      to.subtract(const Duration(days: 1)),
    );
    final avgMin = view.averageMinutes(cs);
    final avgRating = view.averageRating(cs);
    final days = to.difference(from).inDays;
    final perDay = days == 0 ? 0 : cs.length / days;
    final cells = math.min(days, 371);
    final firstCell = to.subtract(Duration(days: cells));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HabitSectionTitle(
          icon: PhosphorIcons.waveform(),
          title: tr(context, 'Rhythm', 'Ritmo'),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (r, label) in [
                (_Range.week, tr(context, 'Week', 'Semana')),
                (_Range.month, tr(context, 'Month', 'Mes')),
                (_Range.year, tr(context, 'Year', 'Año')),
                (_Range.all, tr(context, 'All time', 'Todo')),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    label: label,
                    selected: _range == r,
                    onTap: () => setState(() => _range = r),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        HabitCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Calendar heatmap: columns are weeks, rows weekdays.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Builder(
                  builder: (context) {
                    final start = firstCell.subtract(
                      Duration(days: firstCell.weekday - 1),
                    );
                    final weeks = (to.difference(start).inDays / 7).ceil();
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var w = 0; w < weeks; w++)
                          Column(
                            children: [
                              for (var d = 0; d < 7; d++)
                                () {
                                  final day = start.add(
                                    Duration(days: w * 7 + d),
                                  );
                                  final s = view.stateOn(day);
                                  final f = view.meta.target == 0
                                      ? 0.0
                                      : (view.progressOn(day) /
                                                view.meta.target)
                                            .clamp(0, 1)
                                            .toDouble();
                                  final c =
                                      day.isBefore(firstCell) ||
                                          !day.isBefore(to)
                                      ? Colors.transparent
                                      : switch (s) {
                                          DayState.met => color,
                                          DayState.partial => color.withValues(
                                            alpha: 0.25 + f * 0.5,
                                          ),
                                          DayState.skipped => habitGold(
                                            context,
                                          ).withValues(alpha: 0.45),
                                          DayState.rest || DayState.paused =>
                                            theme.colorScheme.onSurface
                                                .withValues(alpha: 0.06),
                                          _ =>
                                            theme.colorScheme.onSurface
                                                .withValues(alpha: 0.12),
                                        };
                                  return Tooltip(
                                    message:
                                        '${DateFormat.yMMMd(context.dateLocale).format(day)} · ${fmtNum(view.progressOn(day))}/${view.meta.target}',
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      margin: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        color: c,
                                        borderRadius: prismCorners(context, 4),
                                      ),
                                    ),
                                  );
                                }(),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: '${(consistency * 100).round()}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    TextSpan(
                      text: tr(
                        context,
                        ' of scheduled days on target · ',
                        ' de los días programados con meta · ',
                      ),
                    ),
                    TextSpan(
                      text: '${cs.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: tr(
                        context,
                        ' completions (${perDay.toStringAsFixed(1)}/day)',
                        ' registros (${perDay.toStringAsFixed(1)}/día)',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(
                    '🔥 ${tr(context, 'Current streak', 'Racha actual')} ${view.currentStreak}',
                  ),
                  Text(
                    '🏆 ${tr(context, 'Longest', 'Más larga')} ${view.longestStreak}',
                  ),
                  if (avgMin != null)
                    Text(
                      '⏱ ${tr(context, 'Avg', 'Media')} ${avgMin.round()} min',
                    ),
                  if (avgRating != null)
                    Text('★ ${avgRating.toStringAsFixed(1)}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _alters(HabitView view) {
    final (from, to) = _bounds(view);
    final cs = view.completionsBetween(from, to);
    final counts = <String, int>{};
    for (final c in cs) {
      final ids = {?c.completedByMemberId, ...view.logOf(c).coMembers};
      for (final id in ids) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const SizedBox.shrink();
    final list = counts.entries.toList()..sort((a, b) => b.value - a.value);
    final max = list.first.value;
    final members = {
      for (final mm in ref.watch(allMembersProvider).value ?? const <Member>[])
        mm.id: mm,
    };
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HabitSectionTitle(
          icon: PhosphorIcons.users(),
          title: view.meta.shared
              ? tr(context, 'Shared by the system', 'Compartido por el sistema')
              : tr(context, 'Who completes it', 'Quién lo completa'),
        ),
        for (final e in list.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (members[e.key] case final mm?)
                  MemberAvatar(
                    avatarImageData: mm.avatarImageData,
                    memberName: mm.effectiveName(preferDisplayName: prefer),
                    emoji: mm.emoji,
                    customColorEnabled: mm.customColorEnabled,
                    customColorHex: mm.customColorHex,
                    size: 30,
                  ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 96,
                  child: Text(
                    members[e.key]?.effectiveName(preferDisplayName: prefer) ??
                        '?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: TrackerBar(
                    value: e.value / max,
                    color: theme.colorScheme.primary,
                    height: 8,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value}', style: theme.textTheme.labelLarge),
              ],
            ),
          ),
      ],
    );
  }

  Widget _milestones(HabitView view) {
    final total = view.completions.length;
    final longest = view.longestStreak;
    final all = <(String, bool)>[
      for (final n in const [1, 10, 50, 100, 250, 500, 1000])
        (tr(context, '$n completions', '$n registros'), total >= n),
      for (final n in const [3, 7, 14, 30, 100])
        (tr(context, '$n-day streak', 'Racha de $n días'), longest >= n),
    ];
    final ch = view.meta.challengeTarget;
    final gold = habitGold(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HabitSectionTitle(
          icon: PhosphorIcons.medal(),
          title: tr(context, 'Milestones', 'Hitos'),
        ),
        if (ch != null) ...[
          Builder(
            builder: (context) {
              final start = view.meta.record?.createdAt ?? view.habit.createdAt;
              final done = view.completions
                  .where((c) => c.completedAt.isAfter(start))
                  .length;
              final end = view.meta.challengeEnd;
              return HabitCard(
                accent: gold,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr(
                        context,
                        'Challenge: $done / $ch',
                        'Reto: $done / $ch',
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(color: gold),
                    ),
                    const SizedBox(height: 6),
                    TrackerBar(
                      value: (done / ch).clamp(0, 1).toDouble(),
                      color: gold,
                      height: 8,
                    ),
                    if (end != null)
                      Text(
                        tr(
                          context,
                          'Ends ${DateFormat.yMMMd(context.dateLocale).format(end)}',
                          'Termina ${DateFormat.yMMMd(context.dateLocale).format(end)}',
                        ),
                        style: theme.textTheme.labelSmall,
                      ),
                  ],
                ),
              );
            },
          ),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, done) in all)
              Opacity(
                opacity: done ? 1 : 0.4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: prismCorners(context, 16),
                    color: done
                        ? gold.withValues(alpha: 0.14)
                        : theme.colorScheme.surfaceContainerHigh,
                    border: Border.all(
                      color: done
                          ? gold.withValues(alpha: 0.6)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    '${done ? '🏅' : '○'} $label',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _reflections(HabitView view) {
    final notes = [
      for (final c in view.completions)
        if ((c.notes?.isNotEmpty ?? false) || c.rating != null) c,
    ].take(5).toList();
    if (notes.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HabitSectionTitle(
          icon: PhosphorIcons.quotes(),
          title: tr(context, 'Reflections', 'Reflexiones'),
        ),
        for (final c in notes)
          HabitCard(
            margin: const EdgeInsets.only(bottom: 8),
            onTap: () =>
                showHabitLogSheet(context, habit: view.habit, editing: c),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat.MMMEd(
                          context.dateLocale,
                        ).add_jm().format(c.completedAt),
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    if (c.rating != null) StarRow(value: c.rating, size: 13),
                  ],
                ),
                if (c.notes?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(c.notes!),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _history(HabitView view, Color color) {
    final theme = Theme.of(context);
    final today = dayKey(DateTime.now());
    final rows = [
      for (var i = 1; i <= 7; i++) today.subtract(Duration(days: i)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HabitSectionTitle(
          icon: PhosphorIcons.clockCounterClockwise(),
          title: tr(context, 'Recent history', 'Historial reciente'),
          trailing: InkWell(
            onTap: () => _allHistory(view),
            child: Text(
              '${tr(context, 'See all', 'Ver todo')} →',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        for (final d in rows)
          HabitCard(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => _dayDetail(view, d),
            child: Row(
              children: [
                SizedBox(
                  width: 170,
                  child: Text(
                    '${DateFormat.MMMd(context.dateLocale).format(d)} · ${switch (view.stateOn(d)) {
                      DayState.skipped => tr(context, 'skipped', 'omitido'),
                      DayState.rest => tr(context, 'rest day', 'descanso'),
                      DayState.paused => tr(context, 'paused', 'en pausa'),
                      _ => '${fmtNum(view.progressOn(d))} / ${view.meta.target}',
                    }}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: TrackerBar(
                    value: view.meta.target == 0
                        ? 0
                        : (view.progressOn(d) / view.meta.target)
                              .clamp(0, 1)
                              .toDouble(),
                    color: color,
                    height: 8,
                  ),
                ),
                Icon(AppIcons.chevronRight, size: 18),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _dayDetail(HabitView view, DateTime d) => PrismSheet.show(
    context: context,
    title: DateFormat.yMMMMEEEEd(context.dateLocale).format(d),
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final v = ref.watch(habitViewsProvider)[view.habit.id] ?? view;
        final list = v.byDay[dayKey(d)] ?? const <HabitCompletion>[];
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final c in list)
              PrismListRow(
                title: Text(
                  '${DateFormat.jm(ctx.dateLocale).format(c.completedAt)} · ${_amountText(v, c)}',
                ),
                subtitle: Text(memberNameFor(ref, c.completedByMemberId) ?? ''),
                trailing: c.rating == null
                    ? null
                    : StarRow(value: c.rating, size: 12),
                onTap: () => showHabitLogSheet(ctx, habit: v.habit, editing: c),
              ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  tr(
                    ctx,
                    'No completions this day.',
                    'Sin registros este día.',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                PrismButton(
                  label: tr(ctx, 'Log for this day', 'Registrar este día'),
                  icon: AppIcons.add,
                  onPressed: () async {
                    await ref
                        .read(habitCenterActionsProvider)
                        .log(
                          habit: v.habit,
                          memberId: currentFronterId(ref),
                          at: DateTime(d.year, d.month, d.day, 12),
                        );
                  },
                ),
                PrismButton(
                  label: v.skips.contains(dayKey(d))
                      ? tr(ctx, 'Unskip', 'Quitar omisión')
                      : tr(ctx, 'Skip this day', 'Omitir este día'),
                  icon: PhosphorIcons.arrowBendUpRight(),
                  onPressed: () => ref
                      .read(habitCenterActionsProvider)
                      .toggleSkip(v.habit.id, d),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Future<void> _allHistory(HabitView view) => PrismSheet.showFullScreen(
    context: context,
    builder: (ctx, scroll) => Consumer(
      builder: (ctx, ref, _) {
        final v = ref.watch(habitViewsProvider)[view.habit.id] ?? view;
        final days = v.byDay.keys.toList()..sort((a, b) => b.compareTo(a));
        return SafeArea(
          child: Column(
            children: [
              PrismSheetTopBar(
                title: tr(ctx, 'All completions', 'Todos los registros'),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final d in days) ...[
                      TrackerLabel(
                        '${DateFormat.yMMMEd(ctx.dateLocale).format(d)} · ${fmtNum(v.progressOn(d))} / ${v.meta.target}',
                      ),
                      for (final c in v.byDay[d]!)
                        PrismListRow(
                          dense: true,
                          title: Text(
                            '${DateFormat.jm(ctx.dateLocale).format(c.completedAt)} · ${_amountText(v, c)}',
                          ),
                          subtitle: Text(
                            [
                              ?memberNameFor(ref, c.completedByMemberId),
                              if (c.notes?.isNotEmpty ?? false) c.notes!,
                            ].join(' · '),
                          ),
                          trailing: c.rating == null
                              ? null
                              : StarRow(value: c.rating, size: 12),
                          onTap: () => showHabitLogSheet(
                            ctx,
                            habit: v.habit,
                            editing: c,
                          ),
                        ),
                    ],
                    if (days.isEmpty)
                      Text(
                        tr(ctx, 'No completions yet.', 'Aún no hay registros.'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _menu(HabitView view) async {
    final h = view.habit;
    final skippedToday = view.skips.contains(dayKey(DateTime.now()));
    final choice = await PrismSheet.show<String>(
      context: context,
      title: h.name,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          PrismListRow(
            leading: Icon(AppIcons.edit),
            title: Text(tr(ctx, 'Edit habit', 'Editar hábito')),
            onTap: () => Navigator.of(ctx).pop('edit'),
          ),
          PrismListRow(
            leading: Icon(PhosphorIcons.slidersHorizontal()),
            title: Text(
              tr(
                ctx,
                'Targets, routine & reminders',
                'Metas, rutina y recordatorios',
              ),
            ),
            onTap: () => Navigator.of(ctx).pop('track'),
          ),
          PrismListRow(
            leading: Icon(PhosphorIcons.arrowBendUpRight()),
            title: Text(
              skippedToday
                  ? tr(ctx, 'Unskip today', 'Quitar omisión de hoy')
                  : tr(
                      ctx,
                      'Skip today (keeps streak)',
                      'Omitir hoy (mantiene racha)',
                    ),
            ),
            onTap: () => Navigator.of(ctx).pop('skip'),
          ),
          PrismListRow(
            leading: Icon(
              view.meta.paused ? PhosphorIcons.play() : PhosphorIcons.pause(),
            ),
            title: Text(
              view.meta.paused
                  ? tr(ctx, 'Resume habit', 'Reanudar hábito')
                  : tr(ctx, 'Pause habit', 'Pausar hábito'),
            ),
            onTap: () => Navigator.of(ctx).pop('pause'),
          ),
          PrismListRow(
            leading: Icon(PhosphorIcons.linkSimple()),
            title: Text(tr(ctx, 'Connected records', 'Registros conectados')),
            onTap: () => Navigator.of(ctx).pop('links'),
          ),
          PrismListRow(
            leading: Icon(AppIcons.delete),
            destructive: true,
            title: Text(tr(ctx, 'Delete habit', 'Eliminar hábito')),
            onTap: () => Navigator.of(ctx).pop('delete'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    final actions = ref.read(habitCenterActionsProvider);
    switch (choice) {
      case 'edit':
        await PrismSheet.showFullScreen(
          context: context,
          builder: (ctx, scroll) =>
              AddEditHabitSheet(existingHabit: h, scrollController: scroll),
        );
      case 'track':
        await showHabitTrackingSettings(context, h);
      case 'skip':
        await actions.toggleSkip(h.id, DateTime.now());
      case 'pause':
        await actions.saveMeta(h.id, {
          'paused': !view.meta.paused,
          'pausedUntil': null,
        });
      case 'links':
        await PrismSheet.showFullScreen(
          context: context,
          builder: (ctx, scroll) => SafeArea(
            child: Column(
              children: [
                PrismSheetTopBar(
                  title: tr(ctx, 'Connected records', 'Registros conectados'),
                ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      RelatedRecordsSection(
                        self: RecordRef(RecordRef.habit, h.id),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      case 'delete':
        final ok = await PrismDialog.confirm(
          context: context,
          title: tr(context, 'Delete “${h.name}”?', '¿Eliminar «${h.name}»?'),
          message: tr(
            context,
            'All its completions, notes and links are removed. This can’t be undone.',
            'Se quitan todos sus registros, notas y enlaces. No se puede deshacer.',
          ),
          destructive: true,
          confirmLabel: tr(context, 'Delete', 'Eliminar'),
          cancelLabel: context.l10n.cancel,
        );
        if (!ok) return;
        await actions.deleteHabit(h);
        if (mounted && GoRouter.of(context).canPop()) context.pop();
    }
  }
}

class _ModuleChip extends StatelessWidget {
  const _ModuleChip({
    required this.module,
    required this.count,
    required this.onTap,
  });
  final RecordModule module;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: module.color.withValues(alpha: 0.14),
    shape: StadiumBorder(
      side: BorderSide(color: module.color.withValues(alpha: 0.4)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(module.icon, size: 18, color: module.color),
            const SizedBox(width: 6),
            Text('${module.label(context)} · $count'),
          ],
        ),
      ),
    ),
  );
}
