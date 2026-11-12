import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/cycle/providers/cycle_providers.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_advanced.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

Map<String, String> phaseNames(AppLocalizations l10n) => {
  'menstrual': l10n.cycPhaseMenstrual,
  'follicular': l10n.cycPhaseFollicular,
  'ovulation': l10n.cycPhaseOvulation,
  'luteal': l10n.cycPhaseLuteal,
};

/// Phases in effect: the user's custom ones, else defaults fitted to their
/// averages.
final cyclePhasesProvider = Provider.family<List<CyclePhase>, AppLocalizations>(
  (ref, l10n) {
    final custom = customPhases(
      ref.watch(trackerKindProvider(TrackerKind.cyclePhase)).value ?? const [],
    );
    if (custom != null) return custom;
    final stats = ref.watch(cycleStatsProvider);
    return defaultPhases(
      averageCycle: stats.averageCycleLength,
      averagePeriod: stats.averagePeriodLength,
      names: phaseNames(l10n),
    );
  },
);

/// User-defined symptom names (keys are the record titles).
final customCycleSymptomsProvider = Provider<List<TrackerRecord>>(
  (ref) => ref.watch(trackerKindProvider(cycleSymptomKind)).value ?? const [],
);

String cycleSymptomLabel(String key) => cycleSymptoms[key] ?? key;

enum _Tab { overview, history, patterns, phases }

class CycleInsightsScreen extends ConsumerStatefulWidget {
  const CycleInsightsScreen({super.key});

  @override
  ConsumerState<CycleInsightsScreen> createState() => _CycleInsightsState();
}

class _CycleInsightsState extends ConsumerState<CycleInsightsScreen> {
  _Tab _tab = _Tab.overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.cycInsightsTitle, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: PrismTokens.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _Tab.values)
                        PrismChip(
                          label: switch (t) {
                            _Tab.overview => l10n.finTabOverview,
                            _Tab.history => l10n.fitTabHistory,
                            _Tab.patterns => l10n.cycPatterns,
                            _Tab.phases => l10n.cycPhasesAndSymptoms,
                          },
                          selected: _tab == t,
                          onTap: () => setState(() => _tab = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...switch (_tab) {
                    _Tab.overview => _overview(context),
                    _Tab.history => _history(context),
                    _Tab.patterns => _patterns(context),
                    _Tab.phases => _phases(context),
                  },
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PhasePattern> _computePatterns() {
    final l10n = context.l10n;
    final stats = ref.watch(cycleStatsProvider);
    return phasePatterns(
      phases: ref.watch(cyclePhasesProvider(l10n)),
      starts: stats.periodStarts,
      entries: ref.watch(cycleEntriesProvider).value ?? const [],
      wellness:
          ref.watch(trackerKindProvider(TrackerKind.cycleWellness)).value ??
          const [],
      moods: ref.watch(moodEntriesProvider).value ?? const [],
    );
  }

  List<Widget> _overview(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final stats = ref.watch(cycleStatsProvider);
    final phases = ref.watch(cyclePhasesProvider(l10n));
    final phase = phaseFor(stats.currentCycleDay, phases);
    final predictions = predictCycles(stats);
    final variability = cycleVariability(stats.cycleLengths);
    final patterns = _computePatterns();
    final fmt = DateFormat.MMMd(context.dateLocale);
    final insights = <String>[];
    for (final p in patterns) {
      final top = p.symptomShare.entries.where((e) => e.value >= 0.4).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (p.daysLogged >= 3 && top.isNotEmpty) {
        insights.add(
          l10n.cycInsightSymptom(
            cycleSymptomLabel(top.first.key),
            (top.first.value * 100).round(),
            p.phase.name,
          ),
        );
      }
    }
    final withEnergy = patterns.where((p) => p.averageEnergy != null).toList()
      ..sort((a, b) => a.averageEnergy!.compareTo(b.averageEnergy!));
    if (withEnergy.length >= 2) {
      insights.add(
        l10n.cycInsightEnergy(
          withEnergy.first.phase.name,
          withEnergy.last.phase.name,
        ),
      );
    }
    final withMood = patterns.where((p) => p.averageMood != null).toList()
      ..sort((a, b) => a.averageMood!.compareTo(b.averageMood!));
    if (withMood.length >= 2 &&
        withMood.last.averageMood! - withMood.first.averageMood! >= 0.4) {
      insights.add(
        l10n.cycInsightMood(
          withMood.first.phase.name,
          withMood.first.averageMood!.toStringAsFixed(1),
          withMood.last.phase.name,
          withMood.last.averageMood!.toStringAsFixed(1),
        ),
      );
    }
    if (variability != null) {
      insights.add(
        variability <= 3
            ? l10n.cycInsightRegular(variability.toStringAsFixed(1))
            : l10n.cycInsightIrregular(variability.toStringAsFixed(1)),
      );
    }
    return [
      PrismSurface(
        accentColor: phase == null ? null : Color(phase.color),
        child: Row(
          children: [
            Icon(
              AppIcons.navCycleActive,
              color: phase == null ? null : Color(phase.color),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.currentCycleDay == null
                        ? l10n.cycNoCurrentCycle
                        : l10n.cycDayN(stats.currentCycleDay!),
                    style: theme.textTheme.titleLarge,
                  ),
                  if (phase != null)
                    Text(
                      l10n.cycPhaseNow(phase.name),
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      TrackerStatGrid(
        children: [
          TrackerStatTile(
            label: l10n.cycAvgCycle,
            value: stats.averageCycleLength == null
                ? '–'
                : l10n.journalDays(stats.averageCycleLength!.round()),
          ),
          TrackerStatTile(
            label: l10n.cycAvgPeriod,
            value: stats.averagePeriodLength == null
                ? '–'
                : l10n.journalDays(stats.averagePeriodLength!.round()),
          ),
          TrackerStatTile(
            label: l10n.cycVariability,
            value: variability == null
                ? '–'
                : '± ${variability.toStringAsFixed(1)}',
          ),
          TrackerStatTile(
            label: l10n.cycCyclesLogged,
            value: '${stats.cycleLengths.length}',
          ),
        ],
      ),
      TrackerLabel(l10n.cycPredictions),
      if (predictions.isEmpty)
        Text(l10n.cycNeedTwoCycles, style: theme.textTheme.bodySmall)
      else
        for (final p in predictions)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.cycPeriodAround(fmt.format(p.periodStart)),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    l10n.cycFertileWindow(
                      fmt.format(p.fertileStart),
                      fmt.format(p.fertileEnd),
                      fmt.format(p.ovulation),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      Text(l10n.cycPredictionDisclaimer, style: theme.textTheme.bodySmall),
      TrackerLabel(l10n.cycInsights),
      if (insights.isEmpty)
        Text(l10n.cycNoInsights, style: theme.textTheme.bodySmall),
      for (final i in insights)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            child: Row(
              children: [
                Icon(
                  AppIcons.navInsights,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(i)),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _history(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final history = cycleHistory(
      ref.watch(cycleEntriesProvider).value ?? const [],
      ref.watch(cycleStatsProvider),
    );
    final maxLen = history.fold<int>(
      35,
      (m, c) => (c.length ?? 0) > m ? c.length! : m,
    );
    if (history.isEmpty)
      return [Text(l10n.cycNoHistory, style: theme.textTheme.bodySmall)];
    return [
      for (final c in history)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat.yMMMd(context.dateLocale).format(c.start),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      c.length == null
                          ? l10n.cycCurrent
                          : l10n.journalDays(c.length!),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    TrackerBar(
                      value:
                          (c.length ??
                              cycleDayOn(DateTime.now(), [c.start]) ??
                              0) /
                          maxLen,
                      color: theme.colorScheme.secondary,
                      height: 10,
                    ),
                    TrackerBar(
                      value: c.periodLength / maxLen,
                      color: const Color(0xFFE57373),
                      height: 10,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.cycHistoryLine(c.periodLength, c.symptomDays),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _patterns(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final patterns = _computePatterns();
    return [
      for (final p in patterns)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PrismSurface(
            accentColor: Color(p.phase.color),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.phase.name,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      l10n.cycDaysRange(p.phase.startDay, p.phase.endDay),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                Text(
                  [
                    l10n.cycDaysLogged(p.daysLogged),
                    if (p.averageMood != null)
                      l10n.cycAvgMood(p.averageMood!.toStringAsFixed(1)),
                    if (p.averageEnergy != null)
                      l10n.cycAvgEnergy(p.averageEnergy!.toStringAsFixed(1)),
                    if (p.averagePain != null)
                      l10n.cycAvgPain(p.averagePain!.toStringAsFixed(1)),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                for (final e
                    in (p.symptomShare.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            cycleSymptomLabel(e.key),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: TrackerBar(
                            value: e.value,
                            color: Color(p.phase.color),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${(e.value * 100).round()}%',
                            textAlign: TextAlign.end,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (p.symptomShare.isEmpty)
                  Text(
                    l10n.cycNoSymptomsInPhase,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _phases(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final phases = ref.watch(cyclePhasesProvider(l10n));
    final isCustom = phases.any((p) => p.record != null);
    final custom = ref.watch(customCycleSymptomsProvider);
    final n = ref.read(trackerNotifierProvider.notifier);
    return [
      Text(
        isCustom ? l10n.cycCustomPhasesOn : l10n.cycDefaultPhasesInfo,
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      for (final p in phases)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            onTap: isCustom ? () => _editPhase(context, p.record) : null,
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Color(p.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(p.name)),
                Text(
                  l10n.cycDaysRange(p.startDay, p.endDay),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (!isCustom)
            PrismButton(
              label: l10n.cycCustomizePhases,
              icon: AppIcons.edit,
              onPressed: () async {
                for (final p in phases) {
                  await n.create(
                    kind: TrackerKind.cyclePhase,
                    title: p.name,
                    fields: {
                      CycleField.startDay: p.startDay,
                      CycleField.endDay: p.endDay,
                      CycleField.color: p.color,
                    },
                  );
                }
              },
            )
          else ...[
            PrismButton(
              label: l10n.cycAddPhase,
              icon: AppIcons.add,
              onPressed: () => _editPhase(context, null),
            ),
            PrismButton(
              label: l10n.cycResetPhases,
              onPressed: () async {
                final ok = await PrismDialog.confirm(
                  context: context,
                  title: l10n.cycResetPhases,
                  confirmLabel: l10n.cycResetPhases,
                  cancelLabel: l10n.cancel,
                );
                if (!ok) return;
                for (final p in phases) {
                  if (p.record != null) await n.delete(p.record!.id);
                }
              },
            ),
          ],
        ],
      ),
      TrackerLabel(l10n.cycCustomSymptoms),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in custom)
            PrismChip(
              label: '${s.title}  ✕',
              selected: false,
              onTap: () => n.delete(s.id),
            ),
          PrismChip(
            label: l10n.cycAddSymptom,
            selected: false,
            avatar: Icon(AppIcons.add, size: 14),
            onTap: () async {
              final c = TextEditingController();
              final ok = await PrismDialog.show<bool>(
                context: context,
                title: l10n.cycAddSymptom,
                builder: (_) => PrismTextField(controller: c, autofocus: true),
                actions: [
                  PrismButton(
                    label: l10n.cancel,
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(false),
                  ),
                  PrismButton(
                    label: l10n.save,
                    tone: PrismButtonTone.filled,
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(true),
                  ),
                ],
              );
              final t = c.text.trim();
              c.dispose();
              if (ok == true &&
                  t.isNotEmpty &&
                  !custom.any(
                    (x) => x.title.toLowerCase() == t.toLowerCase(),
                  )) {
                await n.create(kind: cycleSymptomKind, title: t);
              }
            },
          ),
        ],
      ),
    ];
  }

  Future<void> _editPhase(BuildContext context, TrackerRecord? r) =>
      PrismSheet.show(
        context: context,
        title: r == null ? context.l10n.cycAddPhase : context.l10n.cycEditPhase,
        builder: (_) => _PhaseEditor(record: r),
      );
}

class _PhaseEditor extends ConsumerStatefulWidget {
  const _PhaseEditor({this.record});

  final TrackerRecord? record;

  @override
  ConsumerState<_PhaseEditor> createState() => _PhaseEditorState();
}

class _PhaseEditorState extends ConsumerState<_PhaseEditor> {
  late final _name = TextEditingController(text: widget.record?.title ?? '');
  late final _start = TextEditingController(
    text: '${widget.record?.integer(CycleField.startDay) ?? 1}',
  );
  late final _end = TextEditingController(
    text: '${widget.record?.integer(CycleField.endDay) ?? 5}',
  );
  late int _color =
      widget.record?.integer(CycleField.color) ?? trackerPalette.first;

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _start, _end]),
      builder: (context, _) {
        final s = int.tryParse(_start.text.trim()),
            e = int.tryParse(_end.text.trim());
        final ok =
            _name.text.trim().isNotEmpty &&
            s != null &&
            e != null &&
            s >= 1 &&
            e >= s &&
            e <= 60;
        final n = ref.read(trackerNotifierProvider.notifier);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrismTextField(
              controller: _name,
              labelText: l10n.cycPhaseName,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PrismTextField(
                    controller: _start,
                    labelText: l10n.cycFromDay,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrismTextField(
                    controller: _end,
                    labelText: l10n.cycToDay,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            if (!ok && _name.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.cycPhaseInvalid,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in trackerPalette)
                  InkResponse(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(width: _color == c ? 3 : 0),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.record != null)
                  PrismButton(
                    label: l10n.trackerDelete,
                    tone: PrismButtonTone.destructive,
                    onPressed: () async {
                      await n.delete(widget.record!.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                const Spacer(),
                PrismButton(
                  label: l10n.save,
                  tone: PrismButtonTone.filled,
                  enabled: ok,
                  onPressed: () async {
                    final fields = {
                      CycleField.startDay: s,
                      CycleField.endDay: e,
                      CycleField.color: _color,
                    };
                    final r = widget.record;
                    if (r == null) {
                      await n.create(
                        kind: TrackerKind.cyclePhase,
                        title: _name.text,
                        fields: fields,
                      );
                    } else {
                      await n.save(
                        r.copyWith(title: _name.text.trim()).withFields(fields),
                      );
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Body signs logged per day (energy, pain, basal temperature, tests …).
class CycleWellnessSection extends ConsumerStatefulWidget {
  const CycleWellnessSection({
    super.key,
    required this.day,
    required this.controller,
  });

  final DateTime day;
  final CycleWellnessController controller;

  @override
  ConsumerState<CycleWellnessSection> createState() =>
      _CycleWellnessSectionState();
}

/// Holds wellness edits until the day sheet saves.
class CycleWellnessController {
  TrackerRecord? existing;
  int? energy, pain, libido;
  String? mucus, ovulationTest, pregnancyTest;
  final bbt = TextEditingController();
  final medication = TextEditingController();

  void load(TrackerRecord? r) {
    existing = r;
    energy = r?.integer(CycleField.energy);
    pain = r?.integer(CycleField.pain);
    libido = r?.integer(CycleField.libido);
    mucus = r?.str(CycleField.mucus);
    ovulationTest = r?.str(CycleField.ovulationTest);
    pregnancyTest = r?.str(CycleField.pregnancyTest);
    bbt.text = r?.number(CycleField.bbt)?.toString() ?? '';
    medication.text = r?.str(CycleField.medication) ?? '';
  }

  double? get bbtValue => bbt.text.trim().isEmpty
      ? null
      : double.tryParse(bbt.text.trim().replaceAll(',', '.'));
  bool get valid =>
      bbt.text.trim().isEmpty ||
      (bbtValue != null && bbtValue! > 30 && bbtValue! < 45);

  Map<String, Object?> get fields => {
    CycleField.energy: energy,
    CycleField.pain: pain,
    CycleField.libido: libido,
    CycleField.mucus: mucus,
    CycleField.ovulationTest: ovulationTest,
    CycleField.pregnancyTest: pregnancyTest,
    CycleField.bbt: bbtValue,
    CycleField.medication: medication.text.trim().isEmpty
        ? null
        : medication.text.trim(),
  };

  bool get isEmpty => fields.values.every((v) => v == null);

  Future<void> save(TrackerNotifier n, DateTime day) async {
    final key = CycleStats.dateKey(day);
    final e = existing;
    if (isEmpty) {
      if (e != null) await n.delete(e.id);
      return;
    }
    if (e == null) {
      await n.create(
        kind: TrackerKind.cycleWellness,
        title: key,
        occurredAt: day,
        fields: fields,
      );
    } else {
      await n.save(e.withFields(fields));
    }
  }

  void dispose() {
    bbt.dispose();
    medication.dispose();
  }
}

class _CycleWellnessSectionState extends ConsumerState<CycleWellnessSection> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.controller;
    Widget scale(
      String label,
      int max,
      int? v,
      ValueChanged<int?> set, {
      int min = 1,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrackerLabel(label),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var i = min; i <= max; i++)
              PrismChip(
                label: '$i',
                selected: v == i,
                onTap: () => setState(() => set(v == i ? null : i)),
              ),
          ],
        ),
      ],
    );
    Widget choice(
      String label,
      List<(String, String)> opts,
      String? v,
      ValueChanged<String?> set,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrackerLabel(label),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (k, t) in opts)
              PrismChip(
                label: t,
                selected: v == k,
                onTap: () => setState(() => set(v == k ? null : k)),
              ),
          ],
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        scale(l10n.cycEnergy, 5, c.energy, (v) => c.energy = v),
        scale(l10n.cycPain, 10, c.pain, (v) => c.pain = v, min: 0),
        scale(l10n.cycLibido, 5, c.libido, (v) => c.libido = v),
        choice(
          l10n.cycMucus,
          [
            for (final m in mucusOptions)
              (
                m,
                switch (m) {
                  'dry' => l10n.cycMucusDry,
                  'sticky' => l10n.cycMucusSticky,
                  'creamy' => l10n.cycMucusCreamy,
                  'watery' => l10n.cycMucusWatery,
                  _ => l10n.cycMucusEggwhite,
                },
              ),
          ],
          c.mucus,
          (v) => c.mucus = v,
        ),
        choice(
          l10n.cycOvulationTest,
          [('pos', l10n.cycPositive), ('neg', l10n.cycNegative)],
          c.ovulationTest,
          (v) => c.ovulationTest = v,
        ),
        choice(
          l10n.cycPregnancyTest,
          [('pos', l10n.cycPositive), ('neg', l10n.cycNegative)],
          c.pregnancyTest,
          (v) => c.pregnancyTest = v,
        ),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: c.bbt,
          builder: (context, _) => PrismTextField(
            controller: c.bbt,
            labelText: l10n.cycBbt,
            errorText: c.valid ? null : l10n.cycBbtInvalid,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(height: 12),
        PrismTextField(controller: c.medication, labelText: l10n.cycMedication),
      ],
    );
  }
}

/// Segmented helper so the day sheet can switch between flow/symptoms and
/// body signs without growing too tall on phones.
class CycleDaySections extends StatelessWidget {
  const CycleDaySections({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => PrismSegmentedControl<int>(
    segments: [
      PrismSegment(value: 0, label: context.l10n.cycFlowAndSymptoms),
      PrismSegment(value: 1, label: context.l10n.cycBodySigns),
    ],
    selected: value,
    onChanged: onChanged,
  );
}
