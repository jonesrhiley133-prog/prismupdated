import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/models.dart' hide CornerStyle;
import 'package:prism_plurality/features/connected/utils/pattern_explorer.dart';
import 'package:prism_plurality/features/cycle/providers/cycle_providers.dart';
import 'package:prism_plurality/features/insights/providers/insight_providers.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/data/body_map.dart';
import 'package:prism_plurality/features/mood/data/emotion_library.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/features/work/providers/work_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// Compare mood and emotions against sleep, fronting, places, cycle, body
/// sensations and work. Descriptive groupings, not conclusions.
class PatternExplorerScreen extends ConsumerStatefulWidget {
  const PatternExplorerScreen({super.key});

  @override
  ConsumerState<PatternExplorerScreen> createState() =>
      _PatternExplorerScreenState();
}

class _PatternExplorerScreenState extends ConsumerState<PatternExplorerScreen> {
  PatternComparison _comparison = PatternComparison.emotionSleep;
  int _days = 30;

  String _comparisonLabel(PatternComparison c) {
    final l10n = context.l10n;
    return switch (c) {
      PatternComparison.emotionSleep => l10n.patternsEmotionSleep,
      PatternComparison.emotionFronting => l10n.patternsEmotionFronting,
      PatternComparison.emotionLocation => l10n.patternsEmotionLocation,
      PatternComparison.emotionCycle => l10n.patternsEmotionCycle,
      PatternComparison.bodyEmotion => l10n.patternsBodyEmotion,
      PatternComparison.workMood => l10n.patternsWorkMood,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final moods = ref.watch(moodEntriesProvider);
    final fronting = ref.watch(insightFrontingSessionsProvider(today));
    final locations = ref.watch(locationSessionsProvider);
    final work = ref.watch(workSessionsProvider);
    final cycle = ref.watch(cycleEntriesProvider);
    final ready = [
      moods,
      fronting,
      locations,
      work,
      cycle,
    ].every((a) => a.hasValue);

    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.patternsTitle, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: !ready
            ? const PrismLoadingState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in PatternComparison.values)
                        PrismChip(
                          label: _comparisonLabel(c),
                          selected: _comparison == c,
                          onTap: () => setState(() => _comparison = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final d in const [30, 90, 365])
                        PrismChip(
                          label: l10n.moodRangeDays(d),
                          selected: _days == d,
                          onTap: () => setState(() => _days = d),
                        ),
                    ],
                  ),
                  if (_days > insightLookBackDays &&
                      (_comparison == PatternComparison.emotionSleep ||
                          _comparison == PatternComparison.emotionFronting))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.patternsFrontingWindowNote(insightLookBackDays),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ..._results(
                    context,
                    now,
                    today,
                    moods.value!,
                    fronting.value!,
                    locations.value!,
                    work.value!,
                    cycle.value!,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.patternsDisclaimer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _results(
    BuildContext context,
    DateTime now,
    DateTime today,
    List<MoodEntry> moods,
    List<FrontingSession> fronting,
    List<LocationSession> locations,
    List<WorkSession> work,
    List<CycleEntry> cycle,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final groups = explorePattern(
      _comparison,
      PatternExplorerInputs(
        moods: moods,
        fronting: fronting,
        locations: locations,
        work: work,
        cycle: cycle,
      ),
      from: DateTime(today.year, today.month, today.day - _days + 1),
      to: DateTime(today.year, today.month, today.day + 1),
      now: now,
    );
    if (groups.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            l10n.patternsNoData,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }
    final members = ref.watch(allMemberListProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final locs = {
      for (final l in ref.watch(savedLocationsProvider).value ?? const [])
        l.id: l,
    };
    final jobs = ref.watch(jobByIdProvider);
    String label(String key) {
      if (key.startsWith('member:')) {
        return members
                .firstWhereOrNull((m) => m.id == key.substring(7))
                ?.effectiveName(preferDisplayName: prefer) ??
            '?';
      }
      if (key.startsWith('location:')) {
        return locs[key.substring(9)]?.name ?? l10n.locationsDeletedPlace;
      }
      if (key.startsWith('job:')) {
        return jobs[key.substring(4)]?.name ?? l10n.workDeletedJob;
      }
      if (key.startsWith('body:')) return bodyRegionLabel(key.substring(5));
      return switch (key) {
        'sleep_unknown' => l10n.patternsSleepUnknown,
        'sleep_lt6' => l10n.patternsSleepLt6,
        'sleep_6_7' => l10n.patternsSleep67,
        'sleep_7_8' => l10n.patternsSleep78,
        'sleep_8plus' => l10n.patternsSleep8plus,
        'front_none' => l10n.patternsNoFronter,
        'front_cofront' => l10n.patternsCoFronting,
        'location_none' => l10n.patternsNoLocation,
        'cycle_period' => l10n.patternsCyclePeriod,
        'cycle_6_13' => l10n.patternsCycleDays('6–13'),
        'cycle_14_20' => l10n.patternsCycleDays('14–20'),
        'cycle_21plus' => l10n.patternsCycleDays('21+'),
        'cycle_unknown' => l10n.patternsCycleUnknown,
        'body_none' => l10n.patternsNoBody,
        'work_on' => l10n.patternsWorkDays,
        'work_off' => l10n.patternsOffDays,
        _ => key,
      };
    }

    return [
      for (final g in groups)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PrismSurface(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (g.averageMood != null) ...[
                      MoodFace(level: g.averageMood!, size: 28),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        label(g.key),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      g.averageMood == null
                          ? '–'
                          : g.averageMood!.toStringAsFixed(1),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (g.averageMood != null)
                  ClipRRect(
                    borderRadius: prismCorners(context, 4),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          Expanded(
                            flex: ((g.averageMood! - 1) * 25).round().clamp(
                              1,
                              100,
                            ),
                            child: Container(
                              color: MoodLevel.color(g.averageMood!),
                            ),
                          ),
                          Expanded(
                            flex: (100 - ((g.averageMood! - 1) * 25).round())
                                .clamp(1, 100),
                            child: Container(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  [
                    l10n.patternsCheckIns(g.checkIns),
                    if (g.topEmotions.isNotEmpty)
                      g.topEmotions
                          .take(4)
                          .map((e) => '${emotionLabel(e.$1)} ${e.$2}')
                          .join(', '),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}
