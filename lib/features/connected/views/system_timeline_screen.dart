import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/calendar/views/event_detail_sheet.dart';
import 'package:prism_plurality/features/connected/utils/system_timeline.dart';
import 'package:prism_plurality/features/cycle/providers/cycle_providers.dart';
import 'package:prism_plurality/features/cycle/views/cycle_screen.dart';
import 'package:prism_plurality/features/insights/providers/insight_providers.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/providers/notes_providers.dart';
import 'package:prism_plurality/features/mood/data/emotion_library.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/mood/views/log_mood_sheet.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/features/work/providers/work_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/extensions/duration_extensions.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

IconData timelineKindIcon(TimelineKind k) => switch (k) {
  TimelineKind.front => AppIcons.swapHoriz,
  TimelineKind.sleep => AppIcons.bedtimeOutlined,
  TimelineKind.mood => AppIcons.navMood,
  TimelineKind.location => AppIcons.navLocations,
  TimelineKind.work => AppIcons.navWork,
  TimelineKind.event => AppIcons.navCalendar,
  TimelineKind.journal => AppIcons.navNotes,
  TimelineKind.cycle => AppIcons.navCycle,
};

String timelineKindLabel(BuildContext context, TimelineKind k) {
  final l10n = context.l10n;
  return switch (k) {
    TimelineKind.front => l10n.timelineKindFront,
    TimelineKind.sleep => l10n.navSleep,
    TimelineKind.mood => l10n.navMood,
    TimelineKind.location => l10n.navLocations,
    TimelineKind.work => l10n.navWork,
    TimelineKind.event => l10n.navCalendar,
    TimelineKind.journal => l10n.timelineKindJournal,
    TimelineKind.cycle => l10n.navCycle,
  };
}

/// Everything that happened on one day, across all of Prism's trackers.
class SystemTimelineScreen extends ConsumerStatefulWidget {
  const SystemTimelineScreen({super.key});

  @override
  ConsumerState<SystemTimelineScreen> createState() =>
      _SystemTimelineScreenState();
}

class _SystemTimelineScreenState extends ConsumerState<SystemTimelineScreen> {
  late DateTime _day;
  final Set<TimelineKind> _hidden = {};

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
    final fronting = ref.watch(insightFrontingSessionsProvider(_day));
    final moods = ref.watch(moodEntriesProvider);
    final locations = ref.watch(locationSessionsProvider);
    final work = ref.watch(workSessionsProvider);
    final events = ref.watch(calendarEventsProvider);
    final notes = ref.watch(allNotesProvider);
    final cycle = ref.watch(cycleEntriesProvider);
    final ready = [
      fronting,
      moods,
      locations,
      work,
      events,
      notes,
      cycle,
    ].every((a) => a.hasValue);
    final today = DateTime.now();
    final isToday =
        _day.year == today.year &&
        _day.month == today.month &&
        _day.day == today.day;

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.timelineSystemTitle,
        showBackButton: true,
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: !ready
            ? const PrismLoadingState()
            : Builder(
                builder: (context) {
                  final items = buildSystemTimeline(
                    day: _day,
                    now: DateTime.now(),
                    fronting: fronting.value!,
                    moods: moods.value!,
                    locations: locations.value!,
                    work: work.value!,
                    events: events.value!,
                    notes: notes.value!,
                    cycle: cycle.value!,
                  ).where((i) => !_hidden.contains(i.kind)).toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: l10n.calendarPrevious,
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => setState(
                              () => _day = DateTime(
                                _day.year,
                                _day.month,
                                _day.day - 1,
                              ),
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final k in TimelineKind.values)
                            PrismChip(
                              label: timelineKindLabel(context, k),
                              avatar: Icon(timelineKindIcon(k), size: 14),
                              selected: !_hidden.contains(k),
                              onTap: () => setState(
                                () => _hidden.contains(k)
                                    ? _hidden.remove(k)
                                    : _hidden.add(k),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            l10n.timelineSystemEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      for (var i = 0; i < items.length; i++)
                        _TimelineRow(
                          item: items[i],
                          isLast: i == items.length - 1,
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _TimelineRow extends ConsumerWidget {
  const _TimelineRow({required this.item, required this.isLast});

  final SystemTimelineItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(allMemberListProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final locs = {
      for (final l in ref.watch(savedLocationsProvider).value ?? const [])
        l.id: l,
    };
    final jobs = ref.watch(jobByIdProvider);
    String member(String? id) =>
        members
            .firstWhereOrNull((m) => m.id == id)
            ?.effectiveName(preferDisplayName: prefer) ??
        l10n.moodWholeSystem;
    String? span(DateTime? end) => end?.difference(item.time).toExactString();

    final (
      String title,
      String? subtitle,
      VoidCallback? onTap,
    ) = switch (item.kind) {
      TimelineKind.front => (
        item.isStart
            ? l10n.timelineStartedFronting(member(item.memberId))
            : l10n.timelineStoppedFronting(member(item.memberId)),
        item.isStart ? span(item.end) : null,
        null,
      ),
      TimelineKind.sleep => (
        item.isStart ? l10n.timelineFellAsleep : l10n.timelineWokeUp,
        item.isStart ? span(item.end) : null,
        null,
      ),
      TimelineKind.mood => (
        '${MoodLevel.emoji(item.mood ?? 3)} ${MoodLevel.label(context, item.mood ?? 3)} · ${member(item.memberId)}',
        item.moodEntry!.emotions.isEmpty
            ? null
            : item.moodEntry!.emotions.take(4).map(emotionLabel).join(', '),
        () => showLogMoodSheet(context, editing: item.moodEntry),
      ),
      TimelineKind.location => (
        item.isStart
            ? l10n.timelineArrived(
                locs[item.locationId]?.name ?? l10n.locationsDeletedPlace,
              )
            : l10n.timelineLeft(
                locs[item.locationId]?.name ?? l10n.locationsDeletedPlace,
              ),
        item.isStart ? span(item.end) : null,
        null,
      ),
      TimelineKind.work => (
        item.isStart
            ? l10n.timelineClockedIn(
                jobs[item.jobId]?.name ?? l10n.workDeletedJob,
              )
            : l10n.timelineClockedOut(
                jobs[item.jobId]?.name ?? l10n.workDeletedJob,
              ),
        item.isStart ? span(item.end) : null,
        null,
      ),
      TimelineKind.event => (
        item.event!.event.title,
        formatOccurrenceWhen(context, item.event!),
        () => showEventDetailSheet(context, item.event!),
      ),
      TimelineKind.journal => (
        item.note!.title.isEmpty ? l10n.timelineKindJournal : item.note!.title,
        item.note!.body.isEmpty ? null : item.note!.body.replaceAll('\n', ' '),
        null,
      ),
      TimelineKind.cycle => (
        '${l10n.navCycle}: ${flowLabel(context, item.cycleEntry!.flow)}',
        item.cycleEntry!.symptoms.isEmpty
            ? null
            : item.cycleEntry!.symptoms.join(', '),
        () => showCycleDaySheet(context, item.cycleEntry!.day),
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                item.kind == TimelineKind.cycle
                    ? ''
                    : context.formatTime(item.time),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: item.isStart ? 0.18 : 0.08,
                  ),
                  borderRadius: prismRound(context),
                ),
                child: Icon(
                  timelineKindIcon(item.kind),
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: theme.colorScheme.outline.withValues(alpha: 0.25),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: prismCorners(context, 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
