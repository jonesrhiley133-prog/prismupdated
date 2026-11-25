import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prism_plurality/features/companions/companion_home_card.dart';
import 'package:prism_plurality/features/experiences/experiences_hub.dart';
import 'package:prism_plurality/features/fitness/health/health_home_card.dart';
import 'package:prism_plurality/features/fronting_roles/roles_widgets.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/features/alter_status/status_widgets.dart'
    show StatusesDashboardCard;
import 'package:prism_plurality/features/automations/automations_screen.dart'
    show AutomationDashboardCard;
import 'package:prism_plurality/features/availability/availability_screen.dart'
    show AvailabilityNowCard;
import 'package:prism_plurality/features/nutrition/nutrition_screen.dart'
    show HydrationDashboardCard;
import 'package:prism_plurality/shared/l10n/tr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/social/widgets/stories_row.dart';
import 'package:prism_plurality/features/app_update/app_update_widgets.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/preferences/dashboard_preferences.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_data_provider.dart';
import 'package:prism_plurality/features/calendar/views/edit_event_sheet.dart';
import 'package:prism_plurality/features/calendar/views/event_detail_sheet.dart';
import 'package:prism_plurality/features/connected/widgets/how_we_feel_card.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/contacts/views/contact_editor_sheet.dart';
import 'package:prism_plurality/features/cycle/providers/cycle_providers.dart';
import 'package:prism_plurality/features/cycle/views/cycle_screen.dart';
import 'package:prism_plurality/features/fronting/views/add_front_session_sheet.dart';
import 'package:prism_plurality/features/home/widgets/home_now_section.dart';
import 'package:prism_plurality/features/insights/providers/insight_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/utils/birthday.dart';
import 'package:prism_plurality/features/mood/views/log_mood_sheet.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/features/achievements/providers/achievement_providers.dart';
import 'package:prism_plurality/features/achievements/views/achievements_screen.dart';
import 'package:prism_plurality/features/dictionary/views/term_editor_sheet.dart';
import 'package:prism_plurality/features/journal/utils/journal_stats.dart';
import 'package:prism_plurality/features/journal/views/journal_editor_sheet.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/features/whats_new/whats_new.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/extensions/duration_extensions.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';

final dashboardWidgetsProvider = StreamProvider<List<String>>((ref) {
  final repo = ref.watch(appPreferenceRepositoryProvider);
  // One-time: lists saved before the roles strip, health card and companion
  // card became regular cards keep showing them (they used to be fixed).
  return repo.watch(dashboardWidgetsPreference).asyncMap((list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var next = list;
      if (prefs.getBool('dashboard.cards.v2') != true) {
        await prefs.setBool('dashboard.cards.v2', true);
        final missing = [
          for (final id in const [
            DashboardWidgetId.frontingRoles,
            DashboardWidgetId.health,
            DashboardWidgetId.companion,
          ])
            if (!next.contains(id)) id,
        ];
        final at = next.indexOf(DashboardWidgetId.now);
        if (missing.isNotEmpty)
          next = [...next]..insertAll(at < 0 ? 0 : at + 1, missing);
      }
      // v3: the Experiences modules (memory of the day, latest recap).
      if (prefs.getBool('dashboard.cards.v3') != true) {
        await prefs.setBool('dashboard.cards.v3', true);
        final missing = [
          for (final id in const [
            DashboardWidgetId.memoryOfDay,
            DashboardWidgetId.wrapped,
          ])
            if (!next.contains(id)) id,
        ];
        final at = next.indexOf(DashboardWidgetId.companion);
        if (missing.isNotEmpty)
          next = [...next]..insertAll(at < 0 ? next.length : at + 1, missing);
      }
      if (!identical(next, list))
        await repo.set(dashboardWidgetsPreference, next);
      return next;
    } catch (_) {
      return list;
    }
  });
});

/// Compact or full size per resizable Home card (device setting).
final homeCardSizesProvider =
    NotifierProvider<HomeCardSizes, Map<String, String>>(HomeCardSizes.new);

class HomeCardSizes extends Notifier<Map<String, String>> {
  static const _key = 'home.card.sizes';
  @override
  Map<String, String> build() {
    SharedPreferences.getInstance().then((p) {
      final raw = p.getStringList(_key) ?? const [];
      state = {
        for (final e in raw)
          if (e.contains('=')) e.split('=').first: e.split('=').last,
      };
    });
    return const {};
  }

  bool compact(String id) => state[id] == 'compact';

  Future<void> toggle(String id) async {
    state = {...state, id: state[id] == 'compact' ? 'full' : 'compact'};
    (await SharedPreferences.getInstance()).setStringList(_key, [
      for (final e in state.entries) '${e.key}=${e.value}',
    ]);
  }
}

final dashboardQuickActionsProvider = StreamProvider<List<String>>((ref) {
  return ref
      .watch(appPreferenceRepositoryProvider)
      .watch(dashboardQuickActionsPreference);
});

String dashboardWidgetLabel(BuildContext context, String id) {
  final l10n = context.l10n;
  return switch (id) {
    DashboardWidgetId.now => l10n.dashboardWidgetNow,
    DashboardWidgetId.quickActions => l10n.dashboardWidgetQuickActions,
    DashboardWidgetId.howWeFeel => l10n.howWeFeelTitle,
    DashboardWidgetId.insight => l10n.insightsTitle,
    DashboardWidgetId.stats => l10n.dashboardWidgetStats,
    DashboardWidgetId.sleep => l10n.navSleep,
    DashboardWidgetId.cycle => l10n.navCycle,
    DashboardWidgetId.birthdays => l10n.dashboardWidgetBirthdays,
    DashboardWidgetId.events => l10n.dashboardWidgetEvents,
    DashboardWidgetId.achievements => l10n.navAchievements,
    DashboardWidgetId.journal => l10n.navJournal,
    DashboardWidgetId.stories => l10n.stoTitle,
    DashboardWidgetId.statuses => tr(context, 'Statuses', 'Estados'),
    DashboardWidgetId.hydration => tr(context, 'Hydration', 'Hidratación'),
    DashboardWidgetId.availability => tr(
      context,
      'Availability',
      'Disponibilidad',
    ),
    DashboardWidgetId.automation => tr(
      context,
      'Automations',
      'Automatizaciones',
    ),
    DashboardWidgetId.frontingRoles => tr(
      context,
      'Who\'s fronting (statuses)',
      'Quién está al frente',
    ),
    DashboardWidgetId.health => tr(
      context,
      'Steps & health today',
      'Pasos y salud hoy',
    ),
    DashboardWidgetId.companion => tr(context, 'My companion', 'Mi compañero'),
    DashboardWidgetId.memoryOfDay => tr(
      context,
      'Memory of the day',
      'Recuerdo del día',
    ),
    DashboardWidgetId.wrapped => tr(
      context,
      'Recaps (Wrapped)',
      'Resúmenes (Wrapped)',
    ),
    DashboardWidgetId.passportStamps => tr(
      context,
      'Passport & latest stamps',
      'Pasaporte y sellos',
    ),
    DashboardWidgetId.habitat => tr(
      context,
      'Companion habitat',
      'Hábitat del compañero',
    ),
    _ => id,
  };
}

(IconData, String) quickActionMeta(BuildContext context, String id) {
  final l10n = context.l10n;
  return switch (id) {
    QuickActionId.switchFront => (AppIcons.swapHoriz, l10n.quickActionSwitch),
    QuickActionId.logMood => (AppIcons.navMood, l10n.homeQuickLogMood),
    QuickActionId.logBody => (AppIcons.peopleOutline, l10n.quickActionLogBody),
    QuickActionId.startLocation => (
      AppIcons.navLocations,
      l10n.homeQuickStartLocation,
    ),
    QuickActionId.clockIn => (AppIcons.navWork, l10n.workClockIn),
    QuickActionId.journal => (AppIcons.navJournal, l10n.quickActionJournal),
    QuickActionId.dictionary => (
      AppIcons.navDictionary,
      l10n.quickActionDictionary,
    ),
    QuickActionId.achievements => (
      AppIcons.navAchievements,
      l10n.navAchievements,
    ),
    QuickActionId.event => (AppIcons.navCalendar, l10n.calendarNewEvent),
    QuickActionId.birthday => (AppIcons.cake, l10n.quickActionBirthday),
    QuickActionId.contact => (AppIcons.navContacts, l10n.contactsNew),
    QuickActionId.cycle => (AppIcons.navCycle, l10n.cycleLogToday),
    QuickActionId.insights => (AppIcons.navInsights, l10n.insightsTitle),
    QuickActionId.timeline => (
      AppIcons.navTimelineSystem,
      l10n.timelineSystemTitle,
    ),
    QuickActionId.importCenter => (AppIcons.navImport, l10n.importCenterTitle),
    _ => (AppIcons.add, id),
  };
}

void runQuickAction(BuildContext context, WidgetRef ref, String id) {
  final now = DateTime.now();
  switch (id) {
    case QuickActionId.switchFront:
      AddFrontSessionSheet.show(context);
    case QuickActionId.logMood:
    case QuickActionId.logBody:
      showLogMoodSheet(context);
    case QuickActionId.startLocation:
      HomeNowSection.pickLocation(context, ref);
    case QuickActionId.clockIn:
      HomeNowSection.pickJob(context, ref);
    case QuickActionId.journal:
      showJournalEditor(context);
    case QuickActionId.dictionary:
      showTermEditor(context);
    case QuickActionId.achievements:
      context.push(AppRoutePaths.achievements);
    case QuickActionId.event:
      showEditEventSheet(context);
    case QuickActionId.birthday:
    case QuickActionId.contact:
      showContactEditor(context);
    case QuickActionId.cycle:
      showCycleDaySheet(context, DateTime(now.year, now.month, now.day));
    case QuickActionId.insights:
      context.push(AppRoutePaths.insights);
    case QuickActionId.timeline:
      context.push(AppRoutePaths.systemTimeline);
    case QuickActionId.importCenter:
      context.push(AppRoutePaths.importCenter);
  }
}

/// The configurable dashboard on Home: widgets in the order the system
/// chose, with a customise sheet to show, hide, reorder or reset them.
class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ids =
        ref.watch(dashboardWidgetsProvider).value ?? DashboardWidgetId.defaults;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.MMMMEEEEd(
                    context.dateLocale,
                  ).format(DateTime.now()),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.dashboardCustomize,
                icon: Icon(AppIcons.dashboardCustomize, size: 20),
                onPressed: () => PrismSheet.show(
                  context: context,
                  title: l10n.dashboardCustomize,
                  builder: (_) => const _CustomizeSheet(),
                ),
              ),
            ],
          ),
          const AppUpdateBanner(),
          const WhatsNewLauncher(),
          ..._cards(context, ids),
        ],
      ),
    );
  }

  /// Phones: one column. Wide web windows: the "now" card across the top,
  /// then the rest in two balanced columns, like a web dashboard.
  List<Widget> _cards(BuildContext context, List<String> ids) {
    final wide =
        PrismTokens.desktopWebContentWidth != null &&
        MediaQuery.sizeOf(context).width >= 1180;
    if (!wide || ids.length < 3)
      return [for (final id in ids) _widgetFor(context, id)];
    final full = {
      DashboardWidgetId.now,
      DashboardWidgetId.quickActions,
      DashboardWidgetId.stories,
    };
    final top = [
      for (final id in ids)
        if (full.contains(id)) id,
    ];
    final rest = [
      for (final id in ids)
        if (!full.contains(id)) id,
    ];
    final left = <Widget>[], right = <Widget>[];
    for (final (i, id) in rest.indexed) {
      (i.isEven ? left : right).add(_widgetFor(context, id));
    }
    return [
      for (final id in top) _widgetFor(context, id),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: left,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: right,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _widgetFor(BuildContext context, String id) {
    final child = switch (id) {
      DashboardWidgetId.now => const HomeNowSection(showQuickChips: false),
      DashboardWidgetId.quickActions => const _QuickActions(),
      DashboardWidgetId.howWeFeel => const _HowWeFeelWidget(),
      DashboardWidgetId.insight => const _InsightWidget(),
      DashboardWidgetId.stats => const _StatsWidget(),
      DashboardWidgetId.sleep => const _SleepWidget(),
      DashboardWidgetId.cycle => const _CycleWidget(),
      DashboardWidgetId.birthdays => const _BirthdaysWidget(),
      DashboardWidgetId.events => const _EventsWidget(),
      DashboardWidgetId.achievements => const _AchievementsWidget(),
      DashboardWidgetId.journal => const _JournalWidget(),
      DashboardWidgetId.stories => const StoriesRow(),
      DashboardWidgetId.statuses => StatusesDashboardCard(
        onOpenAll: () => context.push('/statuses'),
      ),
      DashboardWidgetId.hydration => HydrationDashboardCard(
        onOpen: () => context.push('/nutrition'),
      ),
      DashboardWidgetId.availability => AvailabilityNowCard(
        onOpen: () => context.push('/availability'),
      ),
      DashboardWidgetId.automation => AutomationDashboardCard(
        onOpen: () => context.push('/automations'),
      ),
      DashboardWidgetId.frontingRoles => const FrontingRolesStrip(),
      DashboardWidgetId.health => const HealthHomeCard(),
      DashboardWidgetId.companion => const CompanionHomeCard(),
      DashboardWidgetId.memoryOfDay => const MemoryOfDayHomeCard(),
      DashboardWidgetId.wrapped => const WrappedHomeCard(),
      DashboardWidgetId.passportStamps => const StampsHomeCard(),
      DashboardWidgetId.habitat => const HabitatHomeCard(),
      _ => const SizedBox.shrink(),
    };
    // Each card repaints on its own (stories, timers, charts animate).
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RepaintBoundary(child: child),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids =
        ref.watch(dashboardQuickActionsProvider).value ??
        QuickActionId.defaults;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in ids)
          Builder(
            builder: (context) {
              final (icon, label) = quickActionMeta(context, id);
              return PrismChip(
                label: label,
                selected: false,
                avatar: Icon(icon, size: 16),
                onTap: () => runQuickAction(context, ref, id),
              );
            },
          ),
      ],
    );
  }
}

class _HowWeFeelWidget extends StatelessWidget {
  const _HowWeFeelWidget();

  @override
  Widget build(BuildContext context) =>
      HowWeFeelCard(onTap: () => context.push(AppRoutePaths.mood));
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

class _InsightWidget extends ConsumerWidget {
  const _InsightWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final insight = ref.watch(dailyInsightProvider(_today()));
    if (insight == null) return const SizedBox.shrink();
    final m = insight.today.averageMood;
    return PrismSurface(
      onTap: () => context.push(AppRoutePaths.insights),
      child: Row(
        children: [
          if (m != null) ...[
            MoodFace(level: m, size: 32),
            const SizedBox(width: 10),
          ] else ...[
            Icon(AppIcons.navInsights, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.insightsTitle, style: theme.textTheme.titleSmall),
                Text(
                  insight.patterns.isEmpty
                      ? (insight.today.checkIns == 0
                            ? l10n.insightsSuggestCheckIn
                            : l10n.dashboardInsightNoPatterns)
                      : l10n.dashboardInsightPatterns(insight.patterns.length),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _StatsWidget extends ConsumerWidget {
  const _StatsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final t = ref.watch(dailyInsightProvider(_today()))?.today;
    if (t == null) return const SizedBox.shrink();
    Widget stat(String v, String label) => Expanded(
      child: Column(
        children: [
          Text(
            v,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
    return PrismSurface(
      onTap: () => context.push(AppRoutePaths.systemTimeline),
      child: Row(
        children: [
          stat('${t.switches}', l10n.dashboardStatSwitches),
          stat('${t.frontSeconds.length}', l10n.dashboardStatFronted),
          stat(
            Duration(seconds: t.coFrontSeconds).toRoundedString(),
            l10n.dashboardStatCoFront,
          ),
          stat('${t.checkIns}', l10n.moodStatCheckIns),
        ],
      ),
    );
  }
}

class _SleepWidget extends ConsumerWidget {
  const _SleepWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final t = ref.watch(dailyInsightProvider(_today()))?.today;
    return PrismSurface(
      onTap: () => context.push(AppRoutePaths.sleep),
      child: Row(
        children: [
          Icon(AppIcons.bedtimeOutlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t?.sleep == null
                  ? l10n.dashboardNoSleep
                  : l10n.insightsGlanceSleep(t!.sleep!.toExactString()),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleWidget extends ConsumerWidget {
  const _CycleWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final stats = ref.watch(cycleStatsProvider);
    final next = stats.nextPeriodEstimate;
    return PrismSurface(
      onTap: () => context.push(AppRoutePaths.cycle),
      child: Row(
        children: [
          Icon(AppIcons.navCycle, color: Colors.pink.shade300),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                if (stats.currentCycleDay != null)
                  l10n.insightsGlanceCycleDay(stats.currentCycleDay!),
                if (next != null)
                  l10n.cycleNextEstimate(
                    DateFormat.MMMd(context.dateLocale).format(next),
                  ),
                if (stats.currentCycleDay == null && next == null)
                  l10n.dashboardCycleEmpty,
              ].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          PrismButton(
            label: l10n.cycleLogToday,
            density: PrismControlDensity.compact,
            onPressed: () => showCycleDaySheet(context, _today()),
          ),
        ],
      ),
    );
  }
}

class _BirthdaysWidget extends ConsumerWidget {
  const _BirthdaysWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final today = _today();
    final contacts = upcomingContactBirthdays(
      ref.watch(contactsProvider).value ?? const [],
      today,
      days: 14,
    );
    final members =
        ref.watch(userVisibleMemberListProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final items = <(DateTime, String)>[
      for (final u in contacts)
        (
          u.date,
          u.turning == null
              ? u.contact.displayName
              : l10n.calendarBirthdayTurning(u.contact.displayName, u.turning!),
        ),
      for (final m in members)
        if (parseBirthday(m.birthday) case final b?)
          for (final d in [
            DateTime(today.year, b.month, b.day),
            DateTime(today.year + 1, b.month, b.day),
          ])
            if (!d.isBefore(today) &&
                d.isBefore(today.add(const Duration(days: 14))))
              (d, m.effectiveName(preferDisplayName: prefer)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return PrismSurface(
      onTap: () => context.push(AppRoutePaths.contacts),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dashboardWidgetBirthdays,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          if (items.isEmpty)
            Text(l10n.dashboardNoBirthdays, style: theme.textTheme.bodySmall)
          else
            for (final (d, name) in items.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(AppIcons.cake, size: 16, color: Colors.pinkAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(name, style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      d == today
                          ? l10n.calendarToday
                          : DateFormat.MMMd(context.dateLocale).format(d),
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _EventsWidget extends ConsumerWidget {
  const _EventsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final data = ref.watch(calendarDataProvider);
    final today = _today();
    final occ =
        data?.occurrencesBetween(today, today.add(const Duration(days: 2))) ??
        const [];
    return PrismSurface(
      onTap: () => context.push(AppRoutePaths.calendar),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.dashboardWidgetEvents, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          if (occ.isEmpty)
            Text(l10n.dashboardNoEvents, style: theme.textTheme.bodySmall)
          else
            for (final o in occ.take(4))
              InkWell(
                onTap: () => showEventDetailSheet(context, o),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.navCalendar,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o.event.title,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        o.isAllDay
                            ? l10n.calendarAllDay
                            : '${o.start.day != today.day ? '${DateFormat.E(context.dateLocale).format(o.start)} ' : ''}'
                                  '${context.formatTime(o.start)}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _CustomizeSheet extends ConsumerStatefulWidget {
  const _CustomizeSheet();

  @override
  ConsumerState<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends ConsumerState<_CustomizeSheet> {
  late List<String> _widgets = [
    ...(ref.read(dashboardWidgetsProvider).value ?? DashboardWidgetId.defaults),
  ];
  late List<String> _actions = [
    ...(ref.read(dashboardQuickActionsProvider).value ??
        QuickActionId.defaults),
  ];

  Future<void> _persist() async {
    final repo = ref.read(appPreferenceRepositoryProvider);
    await repo.set(dashboardWidgetsPreference, _widgets);
    await repo.set(dashboardQuickActionsPreference, _actions);
  }

  void _move(List<String> list, int index, int delta) {
    final to = index + delta;
    if (to < 0 || to >= list.length) return;
    setState(() {
      final item = list.removeAt(index);
      list.insert(to, item);
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hiddenWidgets = DashboardWidgetId.all
        .where((w) => !_widgets.contains(w))
        .toList();
    final hiddenActions = QuickActionId.all
        .where((a) => !_actions.contains(a))
        .toList();

    final sizes = ref.watch(homeCardSizesProvider);
    Widget orderedRow(List<String> list, int i, String label) => Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        if (identical(list, _widgets) &&
            DashboardWidgetId.resizable.contains(list[i]))
          IconButton(
            tooltip: sizes[list[i]] == 'compact'
                ? 'Make full size'
                : 'Make compact',
            icon: Icon(
              sizes[list[i]] == 'compact'
                  ? Icons.unfold_more
                  : Icons.unfold_less,
              size: 18,
            ),
            onPressed: () =>
                ref.read(homeCardSizesProvider.notifier).toggle(list[i]),
          ),
        IconButton(
          tooltip: l10n.dashboardMoveUp,
          icon: const Icon(Icons.arrow_upward, size: 18),
          onPressed: i == 0 ? null : () => _move(list, i, -1),
        ),
        IconButton(
          tooltip: l10n.dashboardMoveDown,
          icon: const Icon(Icons.arrow_downward, size: 18),
          onPressed: i == list.length - 1 ? null : () => _move(list, i, 1),
        ),
        IconButton(
          tooltip: l10n.dashboardHide,
          icon: Icon(AppIcons.close, size: 18),
          onPressed: () {
            setState(() => list.removeAt(i));
            _persist();
          },
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.dashboardWidgetsLabel, style: theme.textTheme.titleSmall),
            for (var i = 0; i < _widgets.length; i++)
              orderedRow(
                _widgets,
                i,
                dashboardWidgetLabel(context, _widgets[i]),
              ),
            if (hiddenWidgets.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(l10n.dashboardAddWidget, style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final w in hiddenWidgets)
                    PrismChip(
                      label: dashboardWidgetLabel(context, w),
                      selected: false,
                      avatar: Icon(AppIcons.add, size: 14),
                      onTap: () {
                        setState(() => _widgets.add(w));
                        _persist();
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l10n.dashboardWidgetQuickActions,
              style: theme.textTheme.titleSmall,
            ),
            for (var i = 0; i < _actions.length; i++)
              orderedRow(_actions, i, quickActionMeta(context, _actions[i]).$2),
            if (hiddenActions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(l10n.dashboardAddAction, style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in hiddenActions)
                    PrismChip(
                      label: quickActionMeta(context, a).$2,
                      selected: false,
                      avatar: Icon(quickActionMeta(context, a).$1, size: 14),
                      onTap: () {
                        setState(() => _actions.add(a));
                        _persist();
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            PrismButton(
              label: l10n.dashboardReset,
              onPressed: () async {
                setState(() {
                  _widgets = [...DashboardWidgetId.defaults];
                  _actions = [...QuickActionId.defaults];
                });
                final repo = ref.read(appPreferenceRepositoryProvider);
                await repo.reset(dashboardWidgetsPreference);
                await repo.reset(dashboardQuickActionsPreference);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementsWidget extends ConsumerWidget {
  const _AchievementsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    ref.watch(achievementRecorderProvider);
    final progress = ref.watch(achievementProgressProvider).value;
    if (progress == null) return const SizedBox.shrink();
    final unlocked = progress.where((p) => p.unlocked).length;
    final next = [
      for (final p in progress)
        if (!p.unlocked) p,
    ]..sort((a, b) => b.fraction.compareTo(a.fraction));
    return PrismSurface(
      onTap: () => context.push(AppRoutePaths.achievements),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.navAchievements,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                '$unlocked / ${progress.length}',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          for (final p in next.take(2)) ...[
            const SizedBox(height: 8),
            Text(
              achievementTitle(l10n, p.def),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            TrackerBar(
              value: p.fraction,
              color: achievementTierColor(p.def.tier),
            ),
          ],
        ],
      ),
    );
  }
}

class _JournalWidget extends ConsumerWidget {
  const _JournalWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final entries =
        ref.watch(trackerKindProvider(TrackerKind.journalEntry)).value ??
        const [];
    final stats = JournalStats.of(entries, DateTime.now());
    final latest = entries.where((e) => !e.isPrivate).firstOrNull;
    return PrismSurface(
      onTap: () => context.push(AppRoutePaths.journal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.navJournal, style: theme.textTheme.titleSmall),
              ),
              Text(
                l10n.journalDays(stats.currentStreak),
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (latest == null)
            Text(l10n.journalEmptyTitle, style: theme.textTheme.bodySmall)
          else
            Text(
              latest.title.isEmpty ? (latest.body ?? '') : latest.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 8),
          PrismButton(
            label: l10n.journalNewEntry,
            icon: AppIcons.add,
            density: PrismControlDensity.compact,
            onPressed: () => showJournalEditor(context),
          ),
        ],
      ),
    );
  }
}
