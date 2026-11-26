import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';
import 'package:prism_plurality/shared/l10n/tr.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/cycle/views/cycle_insights_screen.dart';
import 'package:prism_plurality/domain/models/cycle_entry.dart';
import 'package:prism_plurality/features/calendar/widgets/month_grid.dart';
import 'package:prism_plurality/features/cycle/providers/cycle_providers.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

const _flowColors = [
  Colors.transparent,
  Color(0xFFF4A6B4),
  Color(0xFFE77A8E),
  Color(0xFFD3506A),
  Color(0xFFB02A48),
];

String flowLabel(BuildContext context, int flow) {
  final l10n = context.l10n;
  return switch (flow) {
    1 => l10n.cycleFlowSpotting,
    2 => l10n.cycleFlowLight,
    3 => l10n.cycleFlowMedium,
    4 => l10n.cycleFlowHeavy,
    _ => l10n.cycleFlowNone,
  };
}

Future<void> showCycleDaySheet(BuildContext context, DateTime day) {
  return PrismSheet.show(
    context: context,
    title: DateFormat.yMMMMEEEEd(context.dateLocale).format(day),
    builder: (context) => _CycleDaySheet(day: day),
  );
}

/// Cycle tracking: a month view of logged days plus averages.
class CycleScreen extends ConsumerStatefulWidget {
  const CycleScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends ConsumerState<CycleScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(cycleEntriesProvider);
    final byDate = ref.watch(cycleEntriesByDateProvider);
    final stats = ref.watch(cycleStatsProvider);
    final now = DateTime.now();
    final predicted = stats.nextPeriodEstimate;

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.cycleTitle,
        showBackButton: widget.showBackButton,
        actions: [
          FeatureDataAction(featureId: 'cycle'),
          PrismTopBarAction(
            icon: Icons.upload_file_outlined,
            tooltip: tr(context, 'Import history', 'Importar historial'),
            onPressed: () => context.push(AppRoutePaths.cycleImport),
          ),
          PrismTopBarAction(
            icon: AppIcons.navInsights,
            tooltip: l10n.cycInsightsTitle,
            onPressed: () => context.push(AppRoutePaths.cycleInsights),
          ),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.cycleLogToday,
            onPressed: () => showCycleDaySheet(
              context,
              DateTime(now.year, now.month, now.day),
            ),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.hasError
          ? Center(child: Text(l10n.errorWithDetail(async.error!)))
          : !async.hasValue
          ? const PrismLoadingState()
          : ClampedBody(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  24 + NavBarInset.of(context),
                ),
                children: [
                  _StatsRow(stats: stats),
                  const SizedBox(height: 12),
                  PrismSurface(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Column(
                      children: [
                        MonthHeader(
                          month: _month,
                          onPrevious: () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month - 1,
                            ),
                          ),
                          onNext: () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month + 1,
                            ),
                          ),
                        ),
                        MonthGrid(
                          month: _month,
                          onDaySelected: (d) {
                            if (d.isAfter(now)) return;
                            showCycleDaySheet(context, d);
                          },
                          dayBuilder:
                              (
                                context,
                                day, {
                                required inMonth,
                                required isToday,
                                required isSelected,
                              }) {
                                final e = byDate[CycleStats.dateKey(day)];
                                final isPredicted =
                                    predicted != null &&
                                    !day.isBefore(predicted) &&
                                    day.isBefore(
                                      predicted.add(
                                        Duration(
                                          days: (stats.averagePeriodLength ?? 4)
                                              .round(),
                                        ),
                                      ),
                                    );
                                final flow = e?.flow ?? 0;
                                return Container(
                                  margin: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    borderRadius: prismRound(context),
                                    color: flow > 0
                                        ? _flowColors[flow].withValues(
                                            alpha: inMonth ? 0.9 : 0.35,
                                          )
                                        : null,
                                    border: isPredicted
                                        ? Border.all(
                                            color: _flowColors[3],
                                            width: 1.5,
                                          )
                                        : isToday
                                        ? Border.all(
                                            color: theme.colorScheme.primary,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${day.day}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: flow >= 3
                                                  ? Colors.white
                                                  : theme.colorScheme.onSurface
                                                        .withValues(
                                                          alpha: inMonth
                                                              ? 1
                                                              : 0.35,
                                                        ),
                                              fontWeight: isToday
                                                  ? FontWeight.w800
                                                  : FontWeight.w500,
                                            ),
                                      ),
                                      if (e != null && e.symptoms.isNotEmpty)
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: flow >= 3
                                                ? Colors.white
                                                : theme.colorScheme.primary,
                                            borderRadius: prismRound(context),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: [
                            for (var f = 1; f <= 4; f++)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _flowColors[f],
                                      borderRadius: prismRound(context),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    flowLabel(context, f),
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    borderRadius: prismRound(context),
                                    border: Border.all(color: _flowColors[3]),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.cycleEstimated,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.cycleDisclaimer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget tile(String value, String label) => Expanded(
      child: PrismSurface(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
    final next = stats.nextPeriodEstimate;
    return Column(
      children: [
        Row(
          children: [
            tile(stats.currentCycleDay?.toString() ?? '–', l10n.cycleDayLabel),
            const SizedBox(width: 8),
            tile(
              stats.averageCycleLength?.toStringAsFixed(0) ?? '–',
              l10n.cycleAverageLength,
            ),
            const SizedBox(width: 8),
            tile(
              stats.averagePeriodLength?.toStringAsFixed(0) ?? '–',
              l10n.cyclePeriodLength,
            ),
          ],
        ),
        const SizedBox(height: 8),
        PrismSurface(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(AppIcons.navCycle, size: 18, color: _flowColors[3]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  next == null
                      ? l10n.cycleNeedMoreCycles
                      : l10n.cycleNextEstimate(
                          DateFormat.MMMEd(context.dateLocale).format(next),
                        ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CycleDaySheet extends ConsumerStatefulWidget {
  const _CycleDaySheet({required this.day});
  final DateTime day;

  @override
  ConsumerState<_CycleDaySheet> createState() => _CycleDaySheetState();
}

class _CycleDaySheetState extends ConsumerState<_CycleDaySheet> {
  late final CycleEntry? _existing = ref.read(
    cycleEntriesByDateProvider,
  )[CycleStats.dateKey(widget.day)];
  late int _flow = _existing?.flow ?? 0;
  late final Set<String> _symptoms = {...?_existing?.symptoms};
  late final _note = TextEditingController(text: _existing?.note ?? '');
  late final _wellness = CycleWellnessController()
    ..load(
      (ref.read(trackerKindProvider(TrackerKind.cycleWellness)).value ??
              const <TrackerRecord>[])
          .where((w) => w.title == CycleStats.dateKey(widget.day))
          .firstOrNull,
    );
  int _section = 0;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    _wellness.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref
        .read(cycleNotifierProvider.notifier)
        .saveDay(
          widget.day,
          flow: _flow,
          symptoms: _symptoms.toList(),
          note: _note.text,
        );
    await _wellness.save(
      ref.read(trackerNotifierProvider.notifier),
      widget.day,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CycleDaySections(
              value: _section,
              onChanged: (v) => setState(() => _section = v),
            ),
            const SizedBox(height: 12),
            if (_section == 1)
              CycleWellnessSection(day: widget.day, controller: _wellness)
            else ...[
              Text(l10n.cycleFlowLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              PrismSegmentedControl<int>(
                segments: [
                  for (var f = 0; f <= 4; f++)
                    PrismSegment(value: f, label: flowLabel(context, f)),
                ],
                selected: _flow,
                onChanged: (v) => setState(() => _flow = v),
              ),
              const SizedBox(height: 16),
              Text(l10n.cycleSymptomsLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in cycleSymptoms.entries)
                    PrismChip(
                      label: s.value,
                      selected: _symptoms.contains(s.key),
                      onTap: () => setState(() {
                        if (!_symptoms.remove(s.key)) _symptoms.add(s.key);
                      }),
                    ),
                  for (final c in ref.watch(customCycleSymptomsProvider))
                    PrismChip(
                      label: c.title,
                      selected: _symptoms.contains(c.title),
                      onTap: () => setState(() {
                        if (!_symptoms.remove(c.title)) _symptoms.add(c.title);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              PrismTextField(
                controller: _note,
                labelText: l10n.locationsNotesLabel,
                maxLines: 3,
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: PrismButton(
                label: l10n.save,
                tone: PrismButtonTone.filled,
                enabled: !_saving && _wellness.valid,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
