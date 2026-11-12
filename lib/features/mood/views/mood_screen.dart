import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/calendar/widgets/month_grid.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/data/body_map.dart';
import 'package:prism_plurality/features/mood/data/emotion_library.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/mood/utils/mood_stats.dart';
import 'package:prism_plurality/features/mood/views/log_mood_sheet.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:prism_plurality/shared/widgets/empty_state.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

enum _MoodTab { overview, calendar, history }

/// Mood & wellbeing: quick check-in, analytics, a mood calendar and history.
class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  _MoodTab _tab = _MoodTab.overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entriesAsync = ref.watch(moodEntriesProvider);

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.moodTitle,
        showBackButton: widget.showBackButton,
        actions: [
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.moodLogTitle,
            onPressed: () => showLogMoodSheet(context),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: entriesAsync.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (entries) => ClampedBody(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24 + NavBarInset.of(context),
            ),
            children: [
              PrismSegmentedControl<_MoodTab>(
                segments: [
                  PrismSegment(
                    value: _MoodTab.overview,
                    label: l10n.moodTabOverview,
                  ),
                  PrismSegment(
                    value: _MoodTab.calendar,
                    label: l10n.moodTabCalendar,
                  ),
                  PrismSegment(
                    value: _MoodTab.history,
                    label: l10n.moodTabHistory,
                  ),
                ],
                selected: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
              const SizedBox(height: 16),
              ...switch (_tab) {
                _MoodTab.overview => [_Overview(entries: entries)],
                _MoodTab.calendar => [_MoodCalendar(entries: entries)],
                _MoodTab.history => [_History(entries: entries)],
              },
            ],
          ),
        ),
      ),
    );
  }
}

// ── Overview ──────────────────────────────────────────────────────────────

class _Overview extends StatefulWidget {
  const _Overview({required this.entries});
  final List<MoodEntry> entries;

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  int _rangeDays = 30;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final today = moodDayKey(DateTime.now());
    final todays = widget.entries
        .where((e) => moodDayKey(e.recordedAt) == today)
        .toList();
    final inRange = moodEntriesInLastDays(widget.entries, _rangeDays);
    final summary = MoodSummary.of(inRange);
    final streak = MoodSummary.of(widget.entries).currentStreak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuickCheckIn(latest: todays.firstOrNull),
        const SizedBox(height: 16),
        if (widget.entries.isEmpty)
          EmptyState(
            icon: Icon(AppIcons.navMood),
            title: l10n.moodEmptyTitle,
            subtitle: l10n.moodEmptySubtitle,
            actionLabel: l10n.moodLogTitle,
            onAction: () => showLogMoodSheet(context),
          )
        else ...[
          Wrap(
            spacing: 8,
            children: [
              for (final d in const [7, 30, 90, 365])
                PrismChip(
                  label: l10n.moodRangeDays(d),
                  selected: _rangeDays == d,
                  onTap: () => setState(() => _rangeDays = d),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l10n.moodStatAverage,
                  value: summary.averageMood == null
                      ? '–'
                      : '${MoodLevel.emoji(summary.averageMood!)} '
                            '${summary.averageMood!.toStringAsFixed(1)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: l10n.moodStatCheckIns,
                  value: '${summary.count}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(label: l10n.moodStatStreak, value: '$streak'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (summary.count < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l10n.moodNotEnoughData,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            _Card(
              title: l10n.moodTrendTitle,
              child: _MoodTrendChart(entries: inRange, days: _rangeDays),
            ),
            _Card(
              title: l10n.moodDistributionTitle,
              child: _DistributionBars(summary: summary),
            ),
            if (summary.averageEnergy != null ||
                summary.averageStress != null ||
                summary.averageSleepQuality != null)
              _Card(
                title: l10n.moodWellbeingAverages,
                child: Column(
                  children: [
                    if (summary.averageEnergy != null)
                      _ScaleBar(
                        label: l10n.moodEnergyLabel,
                        value: summary.averageEnergy!,
                      ),
                    if (summary.averageStress != null)
                      _ScaleBar(
                        label: l10n.moodStressLabel,
                        value: summary.averageStress!,
                      ),
                    if (summary.averageSleepQuality != null)
                      _ScaleBar(
                        label: l10n.moodSleepQualityLabel,
                        value: summary.averageSleepQuality!,
                      ),
                  ],
                ),
              ),
            if (summary.topEmotions.isNotEmpty)
              _Card(
                title: l10n.moodTopEmotions,
                child: _RankedBars(
                  items: [
                    for (final e in summary.topEmotions.take(8))
                      (emotionLabel(e.key), e.value, emotionColor(e.key)),
                  ],
                ),
              ),
            _Card(
              title: l10n.moodByTimeOfDay,
              child: _TimeOfDayRow(summary: summary),
            ),
            _MemberBreakdown(summary: summary),
            if (summary.topBodySensations.isNotEmpty)
              _Card(
                title: l10n.moodTopBody,
                child: _RankedBars(
                  items: [
                    for (final e in summary.topBodySensations.take(6))
                      (bodySensationLabel(e.key), e.value, null),
                  ],
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _QuickCheckIn extends StatelessWidget {
  const _QuickCheckIn({required this.latest});
  final MoodEntry? latest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final latest = this.latest;
    return PrismSurface(
      tone: PrismSurfaceTone.strong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.moodQuickPrompt, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var level = 1; level <= 5; level++)
                Tooltip(
                  message: MoodLevel.label(context, level),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => showLogMoodSheet(context, initialMood: level),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: MoodFace(level: level, size: 48),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (latest == null)
            Text(
              l10n.moodNoCheckInsToday,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            InkWell(
              onTap: () => showLogMoodSheet(context, editing: latest),
              child: Row(
                children: [
                  MoodFace(level: latest.mood, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.moodLatestToday}: '
                      '${MoodLevel.label(context, latest.mood)} · '
                      '${context.formatTime(latest.recordedAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrismSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PrismSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MoodTrendChart extends StatelessWidget {
  const _MoodTrendChart({required this.entries, required this.days});
  final List<MoodEntry> entries;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = moodDayKey(DateTime.now());
    final start = DateTime(today.year, today.month, today.day - (days - 1));
    final daily = dailyAverageMood(entries);
    final spots = <FlSpot>[
      for (final e in daily.entries.sortedBy((e) => e.key))
        FlSpot(
          e.key.difference(start).inHours / 24.0,
          double.parse(e.value.toStringAsFixed(2)),
        ),
    ];
    final dateFormat = DateFormat.Md(context.dateLocale);

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (days - 1).toDouble(),
          minY: 1,
          maxY: 5,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  MoodLevel.emoji(value),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: ((days - 1) / 4).clamp(1, 1000).toDouble(),
                getTitlesWidget: (value, meta) => Text(
                  dateFormat.format(
                    DateTime(
                      start.year,
                      start.month,
                      start.day + value.round(),
                    ),
                  ),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${dateFormat.format(DateTime(start.year, start.month, start.day + s.x.round()))}\n'
                    '${MoodLevel.emoji(s.y)} ${s.y.toStringAsFixed(1)}',
                    theme.textTheme.labelMedium!,
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: spots.length > 2,
              preventCurveOverShooting: true,
              barWidth: 3,
              color: theme.colorScheme.primary,
              dotData: FlDotData(
                show: spots.length <= 31,
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 3.5,
                  color: MoodLevel.color(spot.y),
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionBars extends StatelessWidget {
  const _DistributionBars({required this.summary});
  final MoodSummary summary;

  @override
  Widget build(BuildContext context) {
    final max = summary.moodDistribution.values.fold<int>(
      1,
      (a, b) => b > a ? b : a,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var level = 1; level <= 5; level++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Text(
                    '${summary.moodDistribution[level] ?? 0}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height:
                        8 + 80 * (summary.moodDistribution[level] ?? 0) / max,
                    decoration: BoxDecoration(
                      color: MoodLevel.color(level),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(MoodLevel.emoji(level)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ScaleBar extends StatelessWidget {
  const _ScaleBar({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (value - 1) / 4,
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(value.toStringAsFixed(1), style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _RankedBars extends StatelessWidget {
  const _RankedBars({required this.items});
  final List<(String, int, Color?)> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = items.fold<int>(1, (a, b) => b.$2 > a ? b.$2 : a);
    return Column(
      children: [
        for (final (label, count, color) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: count / max,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: color ?? theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$count', style: theme.textTheme.labelMedium),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimeOfDayRow extends StatelessWidget {
  const _TimeOfDayRow({required this.summary});
  final MoodSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final buckets = {
      'morning': l10n.moodTimeMorning,
      'afternoon': l10n.moodTimeAfternoon,
      'evening': l10n.moodTimeEvening,
      'night': l10n.moodTimeNight,
    };
    return Row(
      children: [
        for (final b in buckets.entries)
          Expanded(
            child: Column(
              children: [
                if (summary.averageMoodByTimeOfDay[b.key] != null)
                  MoodFace(
                    level: summary.averageMoodByTimeOfDay[b.key]!,
                    size: 34,
                  )
                else
                  const SizedBox(height: 34, child: Center(child: Text('–'))),
                const SizedBox(height: 4),
                Text(b.value, style: theme.textTheme.labelSmall),
                if (summary.averageMoodByTimeOfDay[b.key] != null)
                  Text(
                    summary.averageMoodByTimeOfDay[b.key]!.toStringAsFixed(1),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MemberBreakdown extends ConsumerWidget {
  const _MemberBreakdown({required this.summary});
  final MoodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byMember = summary.averageMoodByMember;
    if (byMember.length < 2 && byMember.keys.every((k) => k == null)) {
      return const SizedBox.shrink();
    }
    final members = ref.watch(allMemberListProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    String nameFor(String? id) {
      if (id == null) return context.l10n.moodWholeSystem;
      final m = members.firstWhereOrNull((m) => m.id == id);
      return m?.effectiveName(preferDisplayName: prefer) ?? '?';
    }

    final sorted = byMember.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _Card(
      title: context.l10n.moodByMember,
      child: Column(
        children: [
          for (final e in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  MoodFace(level: e.value, size: 24),
                  const SizedBox(width: 8),
                  Expanded(child: Text(nameFor(e.key))),
                  Text(e.value.toStringAsFixed(1)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Calendar ──────────────────────────────────────────────────────────────

class _MoodCalendar extends StatefulWidget {
  const _MoodCalendar({required this.entries});
  final List<MoodEntry> entries;

  @override
  State<_MoodCalendar> createState() => _MoodCalendarState();
}

class _MoodCalendarState extends State<_MoodCalendar> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = moodDayKey(now);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daily = dailyAverageMood(widget.entries);
    final dayEntries = widget.entries
        .where((e) => moodDayKey(e.recordedAt) == _selected)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismSurface(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Column(
            children: [
              MonthHeader(
                month: _month,
                onPrevious: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                onNext: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
              MonthGrid(
                month: _month,
                selectedDay: _selected,
                onDaySelected: (d) => setState(() {
                  _selected = d;
                  if (d.month != _month.month) {
                    _month = DateTime(d.year, d.month);
                  }
                }),
                dayBuilder:
                    (
                      context,
                      day, {
                      required inMonth,
                      required isToday,
                      required isSelected,
                    }) {
                      final avg = daily[day];
                      return Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: avg == null
                              ? null
                              : MoodLevel.color(
                                  avg,
                                ).withValues(alpha: inMonth ? 0.55 : 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                )
                              : isToday
                              ? Border.all(color: theme.colorScheme.outline)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: inMonth
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.35,
                                  ),
                          ),
                        ),
                      );
                    },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var level = 1; level <= 5; level++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: MoodLevel.color(level),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            MoodLevel.emoji(level),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          DateFormat.yMMMMEEEEd(context.dateLocale).format(_selected),
          style: theme.textTheme.titleSmall,
        ),
        if (daily[_selected] != null)
          Text(
            context.l10n.moodAverageOfDay(daily[_selected]!.toStringAsFixed(1)),
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        if (dayEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              context.l10n.moodDayEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final e in dayEntries) MoodEntryTile(entry: e),
      ],
    );
  }
}

// ── History ───────────────────────────────────────────────────────────────

class _History extends StatelessWidget {
  const _History({required this.entries});
  final List<MoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return EmptyState(
        icon: Icon(AppIcons.navMood),
        title: context.l10n.moodEmptyTitle,
        subtitle: context.l10n.moodEmptySubtitle,
        actionLabel: context.l10n.moodLogTitle,
        onAction: () => showLogMoodSheet(context),
      );
    }
    final grouped = groupMoodEntriesByDay(entries);
    final dayFormat = DateFormat.yMMMEd(context.dateLocale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dayFormat.format(day.key),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                MoodFace(level: day.value.map((e) => e.mood).average, size: 22),
              ],
            ),
          ),
          for (final e in day.value) MoodEntryTile(entry: e),
        ],
      ],
    );
  }
}

/// A single check-in row. Tap to edit, swipe to delete.
class MoodEntryTile extends ConsumerWidget {
  const MoodEntryTile({super.key, required this.entry});
  final MoodEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(allMemberListProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final member = members.firstWhereOrNull((m) => m.id == entry.memberId);
    final details = <String>[
      context.formatTime(entry.recordedAt),
      if (member != null) member.effectiveName(preferDisplayName: prefer),
      context.l10n.moodIntensityShort(entry.intensity),
      if (entry.energy != null)
        '${context.l10n.moodEnergyLabel} ${entry.energy}',
      if (entry.stress != null)
        '${context.l10n.moodStressLabel} ${entry.stress}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('mood-${entry.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.error,
            borderRadius: BorderRadius.circular(PrismTokens.radiusMedium),
          ),
          child: Icon(AppIcons.delete, color: theme.colorScheme.onError),
        ),
        onDismissed: (_) {
          ref.read(moodNotifierProvider.notifier).delete(entry.id);
          PrismToast.show(context, message: context.l10n.moodDeletedToast);
        },
        child: PrismSurface(
          onTap: () => showLogMoodSheet(context, editing: entry),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoodFace(level: entry.mood, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MoodLevel.label(context, entry.mood),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (entry.emotions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final key in entry.emotions)
                            _TinyTag(
                              label: emotionLabel(key),
                              color: emotionColor(key),
                            ),
                          for (final b in entry.bodySensations)
                            _TinyTag(label: bodySensationLabel(b), color: null),
                        ],
                      ),
                    ],
                    if (entry.note != null && entry.note!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.note!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label, required this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}
