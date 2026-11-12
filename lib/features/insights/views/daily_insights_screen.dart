import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/connected/widgets/how_we_feel_card.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';
import 'package:prism_plurality/features/cycle/views/cycle_screen.dart';
import 'package:prism_plurality/features/insights/providers/insight_providers.dart';
import 'package:prism_plurality/features/insights/utils/insight_engine.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/data/body_map.dart';
import 'package:prism_plurality/features/mood/data/emotion_library.dart';
import 'package:prism_plurality/features/mood/views/log_mood_sheet.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/features/work/utils/money.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/extensions/duration_extensions.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// Daily Insights: a gentle, on-device summary of one day plus possible
/// patterns from the last 30 days. Nothing leaves the device.
class DailyInsightsScreen extends ConsumerStatefulWidget {
  const DailyInsightsScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<DailyInsightsScreen> createState() =>
      _DailyInsightsScreenState();
}

class _DailyInsightsScreenState extends ConsumerState<DailyInsightsScreen> {
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final insight = ref.watch(dailyInsightProvider(_day));
    final today = DateTime.now();
    final isToday =
        _day.year == today.year &&
        _day.month == today.month &&
        _day.day == today.day;

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.insightsTitle,
        showBackButton: widget.showBackButton,
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + NavBarInset.of(context)),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: l10n.calendarPrevious,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(
                    () => _day = DateTime(_day.year, _day.month, _day.day - 1),
                  ),
                ),
                Expanded(
                  child: Text(
                    isToday
                        ? l10n.calendarToday
                        : DateFormat.yMMMMEEEEd(
                            context.dateLocale,
                          ).format(_day),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.calendarNext,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isToday
                      ? null
                      : () => setState(
                          () => _day = DateTime(
                            _day.year,
                            _day.month,
                            _day.day + 1,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (insight == null)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: PrismLoadingState(),
              )
            else
              ..._content(context, insight, isToday),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    DailyInsight insight,
    bool isToday,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final t = insight.today;
    return [
      _Opening(summary: t, isToday: isToday),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: PrismButton(
              label: l10n.timelineSystemTitle,
              icon: AppIcons.navTimelineSystem,
              expanded: true,
              onPressed: () => context.push(AppRoutePaths.systemTimeline),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PrismButton(
              label: l10n.patternsTitle,
              icon: AppIcons.patterns,
              expanded: true,
              onPressed: () => context.push(AppRoutePaths.patterns),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (isToday) ...[const HowWeFeelCard(), const SizedBox(height: 16)],
      if (!t.isEmpty) ...[
        _SectionTitle(l10n.insightsAtAGlance),
        _Glance(summary: t),
        const SizedBox(height: 16),
      ],
      _SectionTitle(l10n.insightsPatterns),
      if (insight.patterns.isEmpty)
        _Muted(
          insight.daysWithData < 5
              ? l10n.insightsNeedMoreData(insight.daysWithData)
              : l10n.insightsNoPatterns,
        )
      else
        for (final p in insight.patterns) _PatternTile(pattern: p),
      const SizedBox(height: 16),
      if (insight.suggestions.isNotEmpty) ...[
        _SectionTitle(l10n.insightsSuggestions),
        for (final s in insight.suggestions) _SuggestionTile(suggestion: s),
        const SizedBox(height: 16),
      ],
      PrismSurface(
        tone: PrismSurfaceTone.subtle,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              AppIcons.infoOutlineRounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.insightsDisclaimer(insightLookBackDays),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A warm opening line chosen from how the day went.
class _Opening extends StatelessWidget {
  const _Opening({required this.summary, required this.isToday});

  final DaySummary summary;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final m = summary.averageMood;
    final String text;
    if (summary.isEmpty) {
      text = isToday
          ? l10n.insightsOpeningEmptyToday
          : l10n.insightsOpeningEmptyPast;
    } else if (m == null) {
      text = l10n.insightsOpeningNoMood;
    } else if (m >= 4) {
      text = l10n.insightsOpeningGood;
    } else if (m >= 3) {
      text = l10n.insightsOpeningSteady;
    } else {
      text = l10n.insightsOpeningHard;
    }
    return PrismSurface(
      tone: PrismSurfaceTone.strong,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m != null) ...[
            MoodFace(level: m, size: 40),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.bodyLarge),
                if (summary.checkIns == 0 && isToday) ...[
                  const SizedBox(height: 10),
                  PrismButton(
                    label: l10n.moodLogTitle,
                    icon: AppIcons.add,
                    density: PrismControlDensity.compact,
                    onPressed: () => showLogMoodSheet(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glance extends ConsumerWidget {
  const _Glance({required this.summary});
  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = summary;
    final members = ref.watch(allMemberListProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final locations = {
      for (final l in ref.watch(savedLocationsProvider).value ?? const [])
        l.id: l,
    };
    String memberName(String id) =>
        members
            .firstWhereOrNull((m) => m.id == id)
            ?.effectiveName(preferDisplayName: prefer) ??
        '?';

    final rows = <(IconData, String)>[
      if (t.averageMood != null)
        (
          AppIcons.navMood,
          l10n.insightsGlanceMood(
            MoodLevel.label(context, t.averageMood!),
            t.checkIns,
          ),
        ),
      if (t.topEmotions.isNotEmpty)
        (
          AppIcons.heartOutline,
          l10n.insightsGlanceEmotions(
            t.topEmotions.take(4).map(emotionLabel).join(', '),
          ),
        ),
      if (t.averageIntensity != null)
        (
          AppIcons.flashOn,
          l10n.insightsGlanceIntensity(t.averageIntensity!.toStringAsFixed(1)),
        ),
      if (t.averageStress != null || t.averageEnergy != null)
        (
          AppIcons.warningAmberRounded,
          [
            if (t.averageEnergy != null)
              '${l10n.moodEnergyLabel} ${t.averageEnergy!.toStringAsFixed(1)}/5',
            if (t.averageStress != null)
              '${l10n.moodStressLabel} ${t.averageStress!.toStringAsFixed(1)}/5',
          ].join(' · '),
        ),
      if (t.bodySensations.isNotEmpty)
        (
          AppIcons.peopleOutline,
          l10n.insightsGlanceBody(
            t.bodySensations.take(3).map(bodySensationLabel).join(', '),
          ),
        ),
      if (t.cycleFlow != null || t.cycleDay != null)
        (
          AppIcons.navCycle,
          [
            if (t.cycleDay != null) l10n.insightsGlanceCycleDay(t.cycleDay!),
            if (t.cycleFlow != null && t.cycleFlow! > 0)
              flowLabel(context, t.cycleFlow!),
            if (t.cycleSymptoms.isNotEmpty)
              t.cycleSymptoms.map((k) => cycleSymptoms[k] ?? k).join(', '),
          ].join(' · '),
        ),
      if (t.sleep != null)
        (
          AppIcons.bedtimeOutlined,
          l10n.insightsGlanceSleep(t.sleep!.toExactString()),
        ),
      if (t.frontSeconds.isNotEmpty)
        (
          AppIcons.swapHoriz,
          l10n.insightsGlanceFronting(
            (t.frontSeconds.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(3)
                .map(
                  (e) =>
                      '${memberName(e.key)} ${Duration(seconds: e.value).toRoundedString()}',
                )
                .join(', '),
            t.switches,
          ),
        ),
      if (t.coFrontSeconds > 0)
        (
          AppIcons.peopleOutline,
          l10n.insightsGlanceCoFront(
            Duration(seconds: t.coFrontSeconds).toExactString(),
          ),
        ),
      if (t.locationSeconds.isNotEmpty)
        (
          AppIcons.navLocations,
          l10n.insightsGlanceLocations(
            (t.locationSeconds.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(3)
                .map(
                  (e) =>
                      '${locations[e.key]?.name ?? l10n.locationsDeletedPlace} '
                      '${Duration(seconds: e.value).toRoundedString()}',
                )
                .join(', '),
          ),
        ),
      if (t.workSeconds > 0)
        (
          AppIcons.navWork,
          l10n.insightsGlanceWork(
            Duration(seconds: t.workSeconds).toExactString(),
            t.workEarnings.entries
                .map((e) => formatMoneyCents(e.value, e.key))
                .join(' + '),
          ),
        ),
    ];
    final theme = Theme.of(context);
    return PrismSurface(
      child: Column(
        children: [
          for (final (icon, text) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PatternTile extends ConsumerWidget {
  const _PatternTile({required this.pattern});
  final InsightPattern pattern;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(allMemberListProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final locations = {
      for (final l in ref.watch(savedLocationsProvider).value ?? const [])
        l.id: l,
    };
    String f(double v) => v.toStringAsFixed(1);
    final (String title, String body) = switch (pattern) {
      SleepMoodPattern p => (
        l10n.insightsPatternSleepTitle,
        p.longSleepMood > p.shortSleepMood
            ? l10n.insightsPatternSleepBetter(
                f(p.longSleepMood),
                f(p.shortSleepMood),
                p.longDays,
                p.shortDays,
              )
            : l10n.insightsPatternSleepWorse(
                f(p.longSleepMood),
                f(p.shortSleepMood),
                p.longDays,
                p.shortDays,
              ),
      ),
      LocationMoodPattern p => (
        l10n.insightsPatternLocationTitle(
          locations[p.locationId]?.name ?? l10n.locationsDeletedPlace,
        ),
        p.moodThere > p.moodElsewhere
            ? l10n.insightsPatternLocationBetter(
                f(p.moodThere),
                f(p.moodElsewhere),
                p.checkInsThere,
              )
            : l10n.insightsPatternLocationHarder(
                f(p.moodThere),
                f(p.moodElsewhere),
                p.checkInsThere,
              ),
      ),
      MemberMoodPattern p => (
        l10n.insightsPatternMemberTitle(
          members
                  .firstWhereOrNull((m) => m.id == p.memberId)
                  ?.effectiveName(preferDisplayName: prefer) ??
              '?',
        ),
        l10n.insightsPatternMember(
          f(p.moodWhileFronting),
          f(p.moodOtherwise),
          p.checkIns,
        ),
      ),
      WorkMoodPattern p => (
        l10n.insightsPatternWorkTitle,
        l10n.insightsPatternWork(
          f(p.workDayMood),
          f(p.offDayMood),
          p.workDays,
          p.offDays,
        ),
      ),
      BodyEmotionPattern p => (
        l10n.insightsPatternBodyTitle,
        l10n.insightsPatternBody(
          bodySensationLabel(p.bodySensation),
          emotionLabel(p.emotionKey),
          p.together,
        ),
      ),
      CycleMoodPattern p => (
        l10n.insightsPatternCycleTitle,
        l10n.insightsPatternCycle(
          f(p.periodMood),
          f(p.otherMood),
          p.periodCheckIns,
          p.otherCheckIns,
        ),
      ),
      StressTrendPattern p => (
        p.rising
            ? l10n.insightsPatternStressUpTitle
            : l10n.insightsPatternStressDownTitle,
        l10n.insightsPatternStress(f(p.recentStress), f(p.earlierStress)),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PrismSurface(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              l10n.insightsPatternSupport(pattern.support),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion});
  final InsightSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final text = switch (suggestion) {
      InsightSuggestion.restBreak => l10n.insightsSuggestRest,
      InsightSuggestion.groundingPause => l10n.insightsSuggestGrounding,
      InsightSuggestion.gentleEvening => l10n.insightsSuggestEvening,
      InsightSuggestion.celebrateGoodMoment => l10n.insightsSuggestCelebrate,
      InsightSuggestion.checkInWithSystem => l10n.insightsSuggestSystem,
      InsightSuggestion.revisitComfortPlace => l10n.insightsSuggestPlace,
      InsightSuggestion.lightCheckIn => l10n.insightsSuggestCheckIn,
      InsightSuggestion.balanceWork => l10n.insightsSuggestWork,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 6),
            child: Icon(
              AppIcons.navInsights,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
