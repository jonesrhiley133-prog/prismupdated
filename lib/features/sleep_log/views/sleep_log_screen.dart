import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/sleep_log/providers/sleep_log_providers.dart';
import 'package:prism_plurality/features/sleep_log/utils/sleep_log.dart';
import 'package:prism_plurality/features/sleep_log/views/sleep_details_sheet.dart';
import 'package:prism_plurality/features/sleep_log/views/sleep_labels.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_time_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

String _hm(Duration d) =>
    '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

String _clock(BuildContext context, int minuteOfDay) => DateFormat.jm(
  context.dateLocale,
).format(DateTime(2000, 1, 1, minuteOfDay ~/ 60, minuteOfDay % 60));

/// Detailed sleep analysis: schedule, environment and what helps.
class SleepLogScreen extends ConsumerWidget {
  const SleepLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(sleepNightsProvider);
    final schedule = ref.watch(sleepScheduleProvider);
    final target = schedule?.number(SleepField.targetHours) ?? 8;
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.slpAnalysisTitle, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (nights) {
          final week = nights.take(7).toList();
          final s7 = SleepSummary.of(week, targetHours: target);
          final s30 = SleepSummary.of(
            nights.take(30).toList(),
            targetHours: target,
          );
          final impacts = factorImpacts(nights.take(90).toList());
          final recent = nights.take(14).toList().reversed.toList();
          final maxH = [
            target,
            for (final n in recent) n.asleep.inMinutes / 60,
          ].reduce((a, b) => a > b ? a : b);
          final bed = schedule?.integer(SleepField.bedtimeMin);
          final wake = schedule?.integer(SleepField.wakeMin);
          final children = <Widget>[
            TrackerStatGrid(
              children: [
                TrackerStatTile(
                  label: l10n.slpAvgAsleep7,
                  value: _hm(s7.averageAsleep),
                  icon: AppIcons.navSleep,
                ),
                TrackerStatTile(
                  label: l10n.slpAvgQuality,
                  value: s30.averageQuality == null
                      ? '–'
                      : '${s30.averageQuality!.toStringAsFixed(1)} / 5',
                  icon: AppIcons.heartOutline,
                ),
                TrackerStatTile(
                  label: l10n.slpAvgLatency,
                  value: s30.averageLatency == null
                      ? '–'
                      : l10n.fitMinutesShort(s30.averageLatency!.round()),
                  icon: AppIcons.timer,
                ),
                TrackerStatTile(
                  label: l10n.slpDebt7,
                  value: '${s7.debtHours.toStringAsFixed(1)} h',
                  icon: AppIcons.warningAmber,
                ),
                TrackerStatTile(
                  label: l10n.slpRegularity,
                  value: s30.bedtimeSpreadMin == null
                      ? '–'
                      : l10n.slpPlusMinus(s30.bedtimeSpreadMin!.round()),
                ),
                TrackerStatTile(
                  label: l10n.slpAvgInterruptions,
                  value: s30.averageInterruptions.toStringAsFixed(1),
                ),
                TrackerStatTile(
                  label: l10n.slpAvgBedtime,
                  value: s30.averageBedtimeFromNoon == null
                      ? '–'
                      : DateFormat.jm(
                          context.dateLocale,
                        ).format(fromNoonMinutes(s30.averageBedtimeFromNoon!)),
                ),
                TrackerStatTile(
                  label: l10n.slpAvgWake,
                  value: s30.averageWakeFromNoon == null
                      ? '–'
                      : DateFormat.jm(
                          context.dateLocale,
                        ).format(fromNoonMinutes(s30.averageWakeFromNoon!)),
                ),
              ],
            ),
            TrackerLabel(
              l10n.slpSchedule,
              trailing: PrismButton(
                label: schedule == null ? l10n.slpSetSchedule : l10n.edit,
                density: PrismControlDensity.compact,
                onPressed: () => PrismSheet.show(
                  context: context,
                  title: l10n.slpSchedule,
                  builder: (_) => _ScheduleSheet(existing: schedule),
                ),
              ),
            ),
            PrismSurface(
              child: bed == null || wake == null
                  ? Text(l10n.slpNoSchedule, style: theme.textTheme.bodySmall)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.slpScheduleSummary(
                            _clock(context, bed),
                            _clock(context, wake),
                            target.toStringAsFixed(1),
                          ),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        for (final n in week)
                          Builder(
                            builder: (context) {
                              final dev = bedtimeDeviation(n.start, bed);
                              return Row(
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      DateFormat.MMMEd(
                                        context.dateLocale,
                                      ).format(n.start),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      dev.abs() <= 15
                                          ? l10n.slpOnTime
                                          : dev > 0
                                          ? l10n.slpLate(dev)
                                          : l10n.slpEarly(-dev),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: dev.abs() <= 15
                                                ? theme.colorScheme.primary
                                                : dev > 60
                                                ? theme.colorScheme.error
                                                : null,
                                          ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
            ),
            TrackerLabel(l10n.slpLast14),
            PrismSurface(
              child: SizedBox(
                height: 150,
                child: recent.isEmpty
                    ? Center(child: Text(l10n.slpNoNights))
                    : Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 18 + (150 - 36) * (target / maxH),
                            child: Container(
                              height: 1,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final n in recent)
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                            heightFactor:
                                                (n.asleep.inMinutes / 60 / maxH)
                                                    .clamp(0.02, 1),
                                            child: Container(
                                              width: 12,
                                              decoration: BoxDecoration(
                                                color: switch (n.quality) {
                                                  1 ||
                                                  2 => const Color(0xFFEF5350),
                                                  3 => const Color(0xFFFFCA28),
                                                  4 ||
                                                  5 => const Color(0xFF66BB6A),
                                                  _ =>
                                                    theme.colorScheme.outline,
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat.d(
                                          context.dateLocale,
                                        ).format(n.start),
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.slpChartLegend(target.toStringAsFixed(1)),
                style: theme.textTheme.bodySmall,
              ),
            ),
            TrackerLabel(l10n.slpWhatHelps),
            if (impacts.isEmpty)
              Text(l10n.slpNeedMoreLogs, style: theme.textTheme.bodySmall)
            else
              PrismSurface(
                child: Column(
                  children: [
                    for (final i in impacts.take(12))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(sleepImpactLabel(l10n, i.key)),
                            ),
                            Text(
                              [
                                if (i.averageQuality != null)
                                  '${i.averageQuality!.toStringAsFixed(1)}★',
                                '${i.averageHours.toStringAsFixed(1)} h',
                                l10n.slpNights(i.nights),
                              ].join(' · '),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.slpImpactNote, style: theme.textTheme.bodySmall),
            ),
            TrackerLabel(l10n.slpRecentNights),
            if (nights.isEmpty)
              Text(l10n.slpNoNights, style: theme.textTheme.bodySmall),
            for (final n in nights.take(30))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: PrismSurface(
                  onTap: () => showSleepDetails(context, n.session),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat.MMMEd(
                                context.dateLocale,
                              ).format(n.start),
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              [
                                '${DateFormat.jm(context.dateLocale).format(n.start)} → ${DateFormat.jm(context.dateLocale).format(n.end!)}',
                                _hm(n.asleep),
                                if (n.interruptions > 0)
                                  l10n.slpInterruptions(n.interruptions),
                                ?memberNameFor(ref, n.log?.memberId),
                              ].join(' · '),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        n.log == null
                            ? l10n.slpAddDetails
                            : l10n.slpDetailsLogged,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: n.log == null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: PrismTokens.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScheduleSheet extends ConsumerStatefulWidget {
  const _ScheduleSheet({this.existing});

  final TrackerRecord? existing;

  @override
  ConsumerState<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends ConsumerState<_ScheduleSheet> {
  late int _bed = widget.existing?.integer(SleepField.bedtimeMin) ?? 23 * 60;
  late int _wake = widget.existing?.integer(SleepField.wakeMin) ?? 7 * 60;
  late final _hours = TextEditingController(
    text: (widget.existing?.number(SleepField.targetHours) ?? 8).toString(),
  );

  double? get _h => double.tryParse(_hours.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _hours.dispose();
    super.dispose();
  }

  Future<int?> _pick(int m) async {
    final t = await showPrismTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _hours,
      builder: (context, _) {
        final ok = _h != null && _h! >= 3 && _h! <= 14;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.slpTargetBedtime)),
                PrismButton(
                  label: _clock(context, _bed),
                  density: PrismControlDensity.compact,
                  onPressed: () async {
                    final m = await _pick(_bed);
                    if (m != null) setState(() => _bed = m);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(l10n.slpTargetWake)),
                PrismButton(
                  label: _clock(context, _wake),
                  density: PrismControlDensity.compact,
                  onPressed: () async {
                    final m = await _pick(_wake);
                    if (m != null) setState(() => _wake = m);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _hours,
              labelText: l10n.slpTargetHours,
              errorText: ok ? null : l10n.slpTargetHoursInvalid,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            PrismButton(
              label: l10n.save,
              tone: PrismButtonTone.filled,
              enabled: ok,
              onPressed: () async {
                final n = ref.read(trackerNotifierProvider.notifier);
                final fields = {
                  SleepField.bedtimeMin: _bed,
                  SleepField.wakeMin: _wake,
                  SleepField.targetHours: _h,
                };
                final e = widget.existing;
                if (e == null) {
                  await n.create(
                    kind: sleepScheduleKind,
                    title: 'schedule',
                    fields: fields,
                  );
                } else {
                  await n.save(e.withFields(fields));
                }
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
