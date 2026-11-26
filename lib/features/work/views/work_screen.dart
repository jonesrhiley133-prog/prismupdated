import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/domain/models/work.dart';
import 'package:prism_plurality/features/calendar/widgets/calendar_colors.dart';
import 'package:prism_plurality/features/work/providers/work_providers.dart';
import 'package:prism_plurality/features/work/utils/money.dart';
import 'package:prism_plurality/features/work/utils/work_stats.dart';
import 'package:prism_plurality/features/work/views/job_editor_sheet.dart';
import 'package:prism_plurality/features/work/views/work_session_sheet.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/extensions/duration_extensions.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:prism_plurality/shared/widgets/empty_state.dart';
import 'package:prism_plurality/shared/widgets/live_ticker.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

/// Jobs, clock in/out with live estimated earnings, stats and history.
class WorkScreen extends ConsumerWidget {
  const WorkScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final jobs = ref.watch(jobsProvider);
    final sessions = ref.watch(workSessionsProvider);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.workTitle,
        showBackButton: showBackButton,
        actions: [
          FeatureDataAction(featureId: 'work'),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.workNewJob,
            onPressed: () => showJobEditor(context),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: (jobs.hasError || sessions.hasError)
          ? Center(
              child: Text(l10n.errorWithDetail(jobs.error ?? sessions.error!)),
            )
          : (!jobs.hasValue || !sessions.hasValue)
          ? const PrismLoadingState()
          : const ClampedBody(child: _WorkBody()),
    );
  }
}

enum _Range { today, week, month }

class _WorkBody extends ConsumerStatefulWidget {
  const _WorkBody();

  @override
  ConsumerState<_WorkBody> createState() => _WorkBodyState();
}

class _WorkBodyState extends ConsumerState<_WorkBody> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final jobs = ref.watch(jobsProvider).value ?? const <Job>[];
    final sessions = ref.watch(workSessionsProvider).value ?? const [];
    final active = ref.watch(activeWorkSessionsProvider);
    final byId = ref.watch(jobByIdProvider);

    if (jobs.isEmpty && sessions.isEmpty) {
      return EmptyState(
        icon: Icon(AppIcons.navWork),
        title: l10n.workEmptyTitle,
        subtitle: l10n.workEmptySubtitle,
        actionLabel: l10n.workNewJob,
        onAction: () => showJobEditor(context),
      );
    }

    final visibleJobs = jobs.where((j) => !j.isArchived).toList();
    final history = sessions.where((s) => !s.isActive).take(150).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + NavBarInset.of(context)),
      children: [
        for (final s in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ActiveWorkCard(session: s, job: byId[s.jobId]),
          ),
        Text(l10n.workJobs, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final j in visibleJobs)
          _JobTile(job: j, clockedIn: active.any((s) => s.jobId == j.id)),
        const SizedBox(height: 20),
        Text(l10n.workStatsTitle, style: theme.textTheme.titleSmall),
        Text(
          l10n.workEstimatedDisclaimer,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final (r, label) in [
              (_Range.today, l10n.workRangeToday),
              (_Range.week, l10n.workRangeWeek),
              (_Range.month, l10n.workRangeMonth),
            ])
              PrismChip(
                label: label,
                selected: _range == r,
                onTap: () => setState(() => _range = r),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LiveTicker(
          builder: (context, now) => _StatsCard(
            sessions: sessions,
            jobs: byId,
            range: _range,
            now: now,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(l10n.workHistory, style: theme.textTheme.titleSmall),
            ),
            if (jobs.isNotEmpty)
              PrismButton(
                label: l10n.workAddPastShift,
                icon: AppIcons.add,
                density: PrismControlDensity.compact,
                onPressed: () => showWorkSessionSheet(context),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.workNoHistory,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ..._history(context, history, byId),
      ],
    );
  }

  List<Widget> _history(
    BuildContext context,
    List<WorkSession> history,
    Map<String, Job> byId,
  ) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMEd(context.dateLocale);
    final groups = groupBy(
      history,
      (WorkSession s) =>
          DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day),
    );
    return [
      for (final g in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Text(fmt.format(g.key), style: theme.textTheme.labelLarge),
        ),
        for (final s in g.value) _SessionRow(session: s, job: byId[s.jobId]),
      ],
    ];
  }
}

/// A live clock-in: elapsed time, hourly rate and estimated earnings, all
/// recomputed every second from exact timestamps.
class ActiveWorkCard extends ConsumerWidget {
  const ActiveWorkCard({
    super.key,
    required this.session,
    required this.job,
    this.compact = false,
  });

  final WorkSession session;
  final Job? job;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final color = parseHexColor(job?.colorHex) ?? theme.colorScheme.primary;
    return PrismSurface(
      tone: PrismSurfaceTone.strong,
      padding: EdgeInsets.all(compact ? 12 : 16),
      onTap: () => showWorkSessionSheet(context, editing: session),
      child: LiveTicker(
        builder: (context, now) {
          final worked = session.workedAt(now);
          final earned = session.estimatedEarningsCentsAt(now);
          return Row(
            children: [
              Container(
                width: compact ? 36 : 44,
                height: compact ? 36 : 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: prismCorners(context, 12),
                ),
                child: Icon(AppIcons.navWork, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job?.name ?? l10n.workDeletedJob,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      worked.toClockString(),
                      style:
                          (compact
                                  ? theme.textTheme.titleMedium
                                  : theme.textTheme.headlineSmall)
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                    ),
                    Text(
                      '${l10n.workRatePerHour(formatMoneyCents(session.hourlyRateCents, session.currencyCode))}'
                      ' · ${l10n.workEstimatedEarnings(formatMoneyCents(earned, session.currencyCode))}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PrismButton(
                label: l10n.workClockOut,
                tone: PrismButtonTone.filled,
                density: PrismControlDensity.compact,
                onPressed: () => ref
                    .read(workNotifierProvider.notifier)
                    .clockOut(jobId: session.jobId),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JobTile extends ConsumerWidget {
  const _JobTile({required this.job, required this.clockedIn});

  final Job job;
  final bool clockedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final color = parseHexColor(job.colorHex) ?? theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PrismSurface(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: prismRound(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.name, style: theme.textTheme.titleSmall),
                  Text(
                    l10n.workRatePerHour(
                      formatMoneyCents(job.hourlyRateCents, job.currencyCode),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!clockedIn)
              PrismButton(
                label: l10n.workClockIn,
                density: PrismControlDensity.compact,
                onPressed: () =>
                    ref.read(workNotifierProvider.notifier).clockIn(job),
              )
            else
              Text(
                l10n.workClockedIn,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            IconButton(
              tooltip: l10n.workEditJob,
              icon: Icon(AppIcons.edit, size: 18),
              onPressed: () => showJobEditor(context, editing: job),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.sessions,
    required this.jobs,
    required this.range,
    required this.now,
  });

  final List<WorkSession> sessions;
  final Map<String, Job> jobs;
  final _Range range;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final today = DateTime(now.year, now.month, now.day);
    // Monday-based weeks, matching ISO 8601.
    final from = switch (range) {
      _Range.today => today,
      _Range.week => DateTime(
        today.year,
        today.month,
        today.day - (today.weekday - 1),
      ),
      _Range.month => DateTime(today.year, today.month),
    };
    final to = switch (range) {
      _Range.today => DateTime(today.year, today.month, today.day + 1),
      _Range.week => DateTime(from.year, from.month, from.day + 7),
      _Range.month => DateTime(today.year, today.month + 1),
    };
    final stats = WorkStats.of(sessions, now: now, from: from, to: to);
    // Earnings are only summed within one currency; mixed currencies are
    // listed per job instead of combined.
    final currencies = sessions.map((s) => s.currencyCode).toSet();
    final singleCurrency = currencies.length <= 1;
    final currency = currencies.firstOrNull ?? 'USD';

    final days = <DateTime>[
      for (
        var d = from;
        d.isBefore(to) && !d.isAfter(today);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];
    final maxSeconds = days
        .map((d) => stats.dayOf(d).seconds)
        .fold<int>(1, (a, b) => b > a ? b : a);

    return PrismSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: l10n.workHoursLabel,
                  value: Duration(seconds: stats.total.seconds).toExactString(),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: l10n.workEstimatedEarningsLabel,
                  value: singleCurrency
                      ? formatMoneyCents(stats.total.earningsCents, currency)
                      : l10n.workMixedCurrencies,
                ),
              ),
            ],
          ),
          if (days.length > 1) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Tooltip(
                        message:
                            '${DateFormat.MMMEd(context.dateLocale).format(d)}: '
                            '${Duration(seconds: stats.dayOf(d).seconds).toExactString()}'
                            '${singleCurrency ? ' · ${formatMoneyCents(stats.dayOf(d).earningsCents, currency)}' : ''}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor:
                                        (stats.dayOf(d).seconds / maxSeconds)
                                            .clamp(0.03, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(
                                              alpha: d == today ? 1 : 0.6,
                                            ),
                                        borderRadius: prismCorners(context, 3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (days.length <= 7) ...[
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat.E(context.dateLocale).format(d),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (stats.byJob.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.workByJob, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final e in stats.byJob.entries.sortedBy<num>(
              (e) => -e.value.seconds,
            ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(jobs[e.key]?.name ?? l10n.workDeletedJob),
                    ),
                    Text(
                      '${Duration(seconds: e.value.seconds).toExactString()} · '
                      '${formatMoneyCents(e.value.earningsCents, jobs[e.key]?.currencyCode ?? currency)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.job});

  final WorkSession session;
  final Job? job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final end = session.endedAt!;
    final worked = session.workedAt(end);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PrismSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () => showWorkSessionSheet(context, editing: session),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job?.name ?? l10n.workDeletedJob,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    '${context.formatTime(session.startedAt)} – ${context.formatTime(end)}'
                    '${session.breakSeconds > 0 ? ' · ${l10n.workBreakShort(Duration(seconds: session.breakSeconds).toExactString())}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  worked.toExactString(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  formatMoneyCents(
                    session.estimatedEarningsCentsAt(end),
                    session.currencyCode,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
