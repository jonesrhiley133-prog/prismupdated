import 'package:prism_plurality/shared/widgets/section_switcher.dart';
import 'package:flutter/material.dart';
import 'package:prism_plurality/features/astro/views/astro_integrations.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/features/habits/center/habit_center_screen.dart'
    show CalendarHabitsForDay;
import 'package:prism_plurality/shared/l10n/tr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/calendar/providers/calendar_data_provider.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/calendar/utils/calendar_data.dart';
import 'package:prism_plurality/features/calendar/utils/recurrence.dart';
import 'package:prism_plurality/features/calendar/views/edit_event_sheet.dart';
import 'package:prism_plurality/features/calendar/views/event_detail_sheet.dart';
import 'package:prism_plurality/features/calendar/widgets/calendar_colors.dart';
import 'package:prism_plurality/features/calendar/widgets/month_grid.dart';
import 'package:prism_plurality/features/calendar/widgets/occurrence_tile.dart';
import 'package:prism_plurality/features/calendar/widgets/time_grid.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/views/log_mood_sheet.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

enum CalendarView { month, week, day, agenda }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarView _view = CalendarView.month;
  late DateTime _focused;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focused = DateTime(now.year, now.month, now.day);
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() => _focused = DateTime(now.year, now.month, now.day));
  }

  void _shift(int direction) {
    setState(() {
      _focused = switch (_view) {
        CalendarView.month => DateTime(
          _focused.year,
          _focused.month + direction,
          1,
        ),
        CalendarView.week => DateTime(
          _focused.year,
          _focused.month,
          _focused.day + 7 * direction,
        ),
        CalendarView.day || CalendarView.agenda => DateTime(
          _focused.year,
          _focused.month,
          _focused.day + direction,
        ),
      };
    });
  }

  void _newEvent({DateTime? at, bool allDay = false}) {
    final base =
        at ??
        (() {
          final now = DateTime.now();
          final d = _focused;
          return DateTime(d.year, d.month, d.day, now.hour + 1);
        })();
    showEditEventSheet(context, initialStart: base, initialAllDay: allDay);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = ref.watch(calendarDataProvider);
    final eventsAsync = ref.watch(calendarEventsProvider);

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.calendarTitle,
        showBackButton: widget.showBackButton,
        actions: [
          FeatureDataAction(featureId: 'calendar'),
          PrismTopBarAction(
            icon: AppIcons.calendarJumpToday,
            tooltip: l10n.calendarToday,
            onPressed: _goToday,
          ),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.calendarNewEvent,
            onPressed: _newEvent,
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: eventsAsync.hasError
          ? Center(child: Text(l10n.errorWithDetail(eventsAsync.error!)))
          : data == null
          ? const PrismLoadingState()
          : ClampedBody(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: PrismSegmentedControl<CalendarView>(
                            segments: [
                              PrismSegment(
                                value: CalendarView.month,
                                label: l10n.calendarViewMonth,
                              ),
                              PrismSegment(
                                value: CalendarView.week,
                                label: l10n.calendarViewWeek,
                              ),
                              PrismSegment(
                                value: CalendarView.day,
                                label: l10n.calendarViewDay,
                              ),
                              PrismSegment(
                                value: CalendarView.agenda,
                                label: l10n.calendarViewAgenda,
                              ),
                            ],
                            selected: _view,
                            onChanged: (v) => setState(() => _view = v),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: l10n.calendarFilters,
                          icon: Icon(
                            AppIcons.funnel,
                            color:
                                ref.watch(calendarCategoryFilterProvider) !=
                                    null
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          onPressed: () => _showFilters(context),
                        ),
                      ],
                    ),
                  ),
                  if (ref.watch(calendarCategoryFilterProvider) case final c?)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: PrismChip(
                          label: l10n.calendarFilteredBy(c),
                          selected: true,
                          avatar: Icon(AppIcons.close, size: 14),
                          onTap: () => ref
                              .read(calendarCategoryFilterProvider.notifier)
                              .set(null),
                        ),
                      ),
                    ),
                  Expanded(
                    child: SectionSwitcher(
                      id: _view,
                      child: switch (_view) {
                        CalendarView.month => _MonthView(
                          data: data,
                          focused: _focused,
                          onFocus: (d) => setState(() => _focused = d),
                          onShift: _shift,
                          onOpenDay: (d) => setState(() {
                            _focused = d;
                            _view = CalendarView.day;
                          }),
                          onNewEvent: (d) => _newEvent(
                            at: DateTime(d.year, d.month, d.day, 9),
                          ),
                        ),
                        CalendarView.week => _WeekView(
                          data: data,
                          focused: _focused,
                          onShift: _shift,
                          onOpenDay: (d) => setState(() {
                            _focused = d;
                            _view = CalendarView.day;
                          }),
                          onCreateAt: (t) => _newEvent(at: t),
                        ),
                        CalendarView.day => _DayView(
                          data: data,
                          day: _focused,
                          onShift: _shift,
                          onPickDate: (d) => setState(() => _focused = d),
                          onCreateAt: (t) => _newEvent(at: t),
                        ),
                        CalendarView.agenda => _AgendaView(
                          data: data,
                          from: _focused,
                        ),
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _showFilters(BuildContext context) {
    return PrismSheet.show(
      context: context,
      title: context.l10n.calendarFilters,
      builder: (context) => const _FilterSheet(),
    );
  }
}

// ── Month ─────────────────────────────────────────────────────────────────

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.data,
    required this.focused,
    required this.onFocus,
    required this.onShift,
    required this.onOpenDay,
    required this.onNewEvent,
  });

  final CalendarData data;
  final DateTime focused;
  final ValueChanged<DateTime> onFocus;
  final ValueChanged<int> onShift;
  final ValueChanged<DateTime> onOpenDay;
  final ValueChanged<DateTime> onNewEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final month = DateTime(focused.year, focused.month);
    final firstDow = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final gridStart = monthGridStart(month, firstDow);
    final gridEnd = DateTime(
      gridStart.year,
      gridStart.month,
      gridStart.day + 42,
    );
    final occurrences = data.occurrencesBetween(gridStart, gridEnd);

    return ListView(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 24 + NavBarInset.of(context)),
      children: [
        CompactCalendar(
          maxWidth: 680,
          child: GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 250) return;
              onShift(v < 0 ? 1 : -1);
            },
            child: PrismSurface(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Column(
                children: [
                  MonthHeader(
                    month: month,
                    onPrevious: () => onShift(-1),
                    onNext: () => onShift(1),
                    onTitleTap: () async {
                      final picked = await showPrismMonthYearPicker(
                        context: context,
                        initialDate: month,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2200),
                      );
                      if (picked != null) {
                        onFocus(DateTime(picked.year, picked.month, 1));
                      }
                    },
                  ),
                  MonthGrid(
                    month: month,
                    selectedDay: focused,
                    cellAspectRatio: 0.72,
                    onDaySelected: onFocus,
                    onDayLongPressed: onNewEvent,
                    dayBuilder:
                        (
                          context,
                          day, {
                          required inMonth,
                          required isToday,
                          required isSelected,
                        }) {
                          final dayOccurrences = occurrences
                              .where((o) => o.coversDay(day))
                              .toList();
                          final mood = data.moodAverageOn(day);
                          final hasBirthday = data.birthdaysOn(day).isNotEmpty;
                          final hasReminder = data.remindersOn(day).isNotEmpty;
                          final fg = inMonth
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.35,
                                );
                          return Container(
                            margin: const EdgeInsets.all(1.5),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    )
                                  : null,
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.primary,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      alignment: Alignment.center,
                                      decoration: isToday
                                          ? BoxDecoration(
                                              color: theme.colorScheme.primary,
                                              shape: BoxShape.circle,
                                            )
                                          : null,
                                      child: Text(
                                        '${day.day}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: isToday
                                                  ? theme.colorScheme.onPrimary
                                                  : fg,
                                            ),
                                      ),
                                    ),
                                    const Spacer(),
                                    AstroDayGlyph(day: day),
                                    if (mood != null)
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: MoodLevel.color(mood),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, c) {
                                      final maxBars = ((c.maxHeight - 10) / 13)
                                          .floor()
                                          .clamp(0, 4);
                                      final shown = dayOccurrences
                                          .take(maxBars)
                                          .toList();
                                      final more =
                                          dayOccurrences.length - shown.length;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (final o in shown)
                                            Container(
                                              height: 12,
                                              margin: const EdgeInsets.only(
                                                bottom: 1,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    eventColor(
                                                      context,
                                                      o.event,
                                                    ).withValues(
                                                      alpha: inMonth
                                                          ? 0.85
                                                          : 0.35,
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                o.event.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.clip,
                                                style: TextStyle(
                                                  fontSize: 8.5,
                                                  height: 1.35,
                                                  color: onEventColor(
                                                    eventColor(
                                                      context,
                                                      o.event,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          const Spacer(),
                                          Row(
                                            children: [
                                              if (more > 0)
                                                Text(
                                                  '+$more',
                                                  style: TextStyle(
                                                    fontSize: 8.5,
                                                    color: fg,
                                                  ),
                                                ),
                                              const Spacer(),
                                              if (hasBirthday)
                                                Icon(
                                                  AppIcons.cake,
                                                  size: 9,
                                                  color: fg,
                                                ),
                                              if (hasReminder)
                                                Icon(
                                                  AppIcons
                                                      .notificationsNoneRounded,
                                                  size: 9,
                                                  color: fg,
                                                ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _DayPanel(
          data: data,
          day: focused,
          onOpenDay: () => onOpenDay(focused),
          onNewEvent: () => onNewEvent(focused),
        ),
      ],
    );
  }
}

/// Everything on one day: birthdays, mood, reminders and events.
class _DayPanel extends ConsumerWidget {
  const _DayPanel({
    required this.data,
    required this.day,
    this.onOpenDay,
    this.onNewEvent,
  });

  final CalendarData data;
  final DateTime day;
  final VoidCallback? onOpenDay;
  final VoidCallback? onNewEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final occurrences = data.occurrencesOn(day);
    final birthdays = data.birthdaysOn(day);
    final reminders = data.remindersOn(day);
    final mood = data.moodAverageOn(day);
    final prefer = ref.watch(memberNamePreferDisplayProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenDay,
                child: Text(
                  DateFormat.yMMMMEEEEd(context.dateLocale).format(day),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (onNewEvent != null)
              PrismButton(
                label: l10n.calendarAddEvent,
                icon: AppIcons.add,
                density: PrismControlDensity.compact,
                onPressed: onNewEvent!,
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final b in birthdays)
          _OverlayRow(
            icon: AppIcons.cake,
            color: Colors.pinkAccent,
            text: b.age == null
                ? l10n.calendarBirthdayOf(b.name(preferDisplayName: prefer))
                : l10n.calendarBirthdayTurning(
                    b.name(preferDisplayName: prefer),
                    b.age!,
                  ),
          ),
        if (mood != null)
          _OverlayRow(
            emoji: MoodLevel.emoji(mood),
            color: MoodLevel.color(mood),
            text: l10n.calendarMoodAverage(
              MoodLevel.label(context, mood),
              mood.toStringAsFixed(1),
            ),
            onTap: () => showLogMoodSheet(context),
          ),
        for (final r in reminders)
          _OverlayRow(
            icon: AppIcons.notificationsNoneRounded,
            color: theme.colorScheme.tertiary,
            text:
                '${r.reminder.name} · ${r.times.map((t) {
                  final p = t.split(':');
                  return context.formatTime(DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1])));
                }).join(', ')}',
          ),
        if (data.overlays.habits) CalendarHabitsForDay(day: day),
        CalendarAstroForDay(day: day),
        if (occurrences.isEmpty &&
            birthdays.isEmpty &&
            reminders.isEmpty &&
            mood == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.calendarNothingOnDay,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final o in occurrences) OccurrenceTile(occurrence: o, day: day),
      ],
    );
  }
}

class _OverlayRow extends StatelessWidget {
  const _OverlayRow({
    required this.text,
    required this.color,
    this.icon,
    this.emoji,
    this.onTap,
  });
  final String text;
  final Color color;
  final IconData? icon;
  final String? emoji;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (emoji != null)
                Text(emoji!)
              else
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Week ──────────────────────────────────────────────────────────────────

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.data,
    required this.focused,
    required this.onShift,
    required this.onOpenDay,
    required this.onCreateAt,
  });

  final CalendarData data;
  final DateTime focused;
  final ValueChanged<int> onShift;
  final ValueChanged<DateTime> onOpenDay;
  final ValueChanged<DateTime> onCreateAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDow = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final offset = (focused.weekday % 7 - firstDow + 7) % 7;
    final start = DateTime(focused.year, focused.month, focused.day - offset);
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    final end = DateTime(start.year, start.month, start.day + 7);
    final occurrences = data.occurrencesBetween(start, end);
    final today = DateTime.now();
    final rangeFmt = DateFormat.MMMd(context.dateLocale);

    List<CalendarOccurrence> forDay(DateTime d) =>
        occurrences.where((o) => o.coversDay(d)).toList();

    return Column(
      children: [
        _RangeHeader(
          title:
              '${rangeFmt.format(days.first)} – ${rangeFmt.format(days.last)}',
          onPrevious: () => onShift(-1),
          onNext: () => onShift(1),
        ),
        Padding(
          padding: const EdgeInsets.only(left: TimeGrid.gutterWidth, right: 4),
          child: Row(
            children: [
              for (final d in days)
                Expanded(
                  child: InkWell(
                    onTap: () => onOpenDay(d),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.E(context.dateLocale).format(d),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: isSameDay(d, today)
                              ? BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: Text(
                            '${d.day}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: isSameDay(d, today)
                                  ? theme.colorScheme.onPrimary
                                  : null,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (data.moodAverageOn(d) case final m?)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: MoodLevel.color(m),
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _AllDayLane(
          days: days,
          itemsForDay: (d) => [
            for (final o in forDay(d).where((o) => o.isAllDay))
              _LaneItem(
                o.event.title,
                eventColor(context, o.event),
                () => showEventDetailSheet(context, o),
              ),
            for (final b in data.birthdaysOn(d))
              _LaneItem(
                '🎂 ${b.name(preferDisplayName: false)}',
                Colors.pinkAccent,
                null,
              ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: NavBarInset.of(context), right: 4),
            child: TimeGrid(
              days: days,
              occurrencesForDay: forDay,
              onCreateAt: onCreateAt,
            ),
          ),
        ),
      ],
    );
  }
}

class _LaneItem {
  const _LaneItem(this.label, this.color, this.onTap);
  final String label;
  final Color color;
  final VoidCallback? onTap;
}

class _AllDayLane extends StatelessWidget {
  const _AllDayLane({required this.days, required this.itemsForDay});
  final List<DateTime> days;
  final List<_LaneItem> Function(DateTime day) itemsForDay;

  @override
  Widget build(BuildContext context) {
    final perDay = [for (final d in days) itemsForDay(d)];
    if (perDay.every((l) => l.isEmpty)) return const SizedBox(height: 4);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: TimeGrid.gutterWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 6),
              child: Text(
                context.l10n.calendarAllDay,
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          for (final items in perDay)
            Expanded(
              child: Column(
                children: [
                  for (final item in items.take(3))
                    GestureDetector(
                      onTap: item.onTap,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(1, 0, 1, 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: onEventColor(item.color),
                          ),
                        ),
                      ),
                    ),
                  if (items.length > 3)
                    Text(
                      '+${items.length - 3}',
                      style: theme.textTheme.labelSmall,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeHeader extends StatelessWidget {
  const _RangeHeader({
    required this.title,
    required this.onPrevious,
    required this.onNext,
    this.onTitleTap,
  });
  final String title;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: context.l10n.calendarPrevious,
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Expanded(
          child: InkWell(
            onTap: onTitleTap,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.calendarNext,
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

// ── Day ───────────────────────────────────────────────────────────────────

class _DayView extends ConsumerWidget {
  const _DayView({
    required this.data,
    required this.day,
    required this.onShift,
    required this.onPickDate,
    required this.onCreateAt,
  });

  final CalendarData data;
  final DateTime day;
  final ValueChanged<int> onShift;
  final ValueChanged<DateTime> onPickDate;
  final ValueChanged<DateTime> onCreateAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occurrences = data.occurrencesOn(day);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final mood = data.moodAverageOn(day);
    final reminders = data.remindersOn(day);
    return Column(
      children: [
        _RangeHeader(
          title: DateFormat.yMMMMEEEEd(context.dateLocale).format(day),
          onPrevious: () => onShift(-1),
          onNext: () => onShift(1),
          onTitleTap: () async {
            final picked = await showPrismDatePicker(
              context: context,
              initialDate: day,
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (picked != null) {
              onPickDate(DateTime(picked.year, picked.month, picked.day));
            }
          },
        ),
        _AllDayLane(
          days: [day],
          itemsForDay: (d) => [
            for (final o in occurrences.where((o) => o.isAllDay))
              _LaneItem(
                o.event.title,
                eventColor(context, o.event),
                () => showEventDetailSheet(context, o),
              ),
            for (final b in data.birthdaysOn(d))
              _LaneItem(
                '🎂 ${b.name(preferDisplayName: prefer)}'
                '${b.age == null ? '' : ' (${b.age})'}',
                Colors.pinkAccent,
                null,
              ),
            if (mood != null)
              _LaneItem(
                '${MoodLevel.emoji(mood)} ${MoodLevel.label(context, mood)} ${mood.toStringAsFixed(1)}',
                MoodLevel.color(mood),
                () => showLogMoodSheet(context),
              ),
            for (final r in reminders)
              _LaneItem(
                '⏰ ${r.reminder.name}',
                Theme.of(context).colorScheme.tertiary,
                null,
              ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: NavBarInset.of(context), right: 4),
            child: TimeGrid(
              days: [day],
              occurrencesForDay: (_) => occurrences,
              onCreateAt: onCreateAt,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Agenda ────────────────────────────────────────────────────────────────

class _AgendaView extends ConsumerStatefulWidget {
  const _AgendaView({required this.data, required this.from});
  final CalendarData data;
  final DateTime from;

  @override
  ConsumerState<_AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends ConsumerState<_AgendaView> {
  final _search = TextEditingController();
  int _days = 60;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final query = _search.text;
    final start = widget.from;
    final span = query.trim().isEmpty ? _days : 366;
    final end = DateTime(start.year, start.month, start.day + span);
    final occurrences = widget.data
        .occurrencesBetween(start, end)
        .where((o) => CalendarData.matchesQuery(o.event, query))
        .toList();

    // Group by every day an occurrence covers (multi-day events repeat).
    final byDay = <DateTime, List<CalendarOccurrence>>{};
    for (final o in occurrences) {
      var d = DateTime(o.start.year, o.start.month, o.start.day);
      if (d.isBefore(start)) d = start;
      while (d.isBefore(o.endExclusive) && d.isBefore(end)) {
        byDay.putIfAbsent(d, () => []).add(o);
        d = DateTime(d.year, d.month, d.day + 1);
      }
    }
    final birthdayDays = <DateTime, List<BirthdayOnDay>>{};
    if (query.trim().isEmpty) {
      for (var i = 0; i < span; i++) {
        final d = DateTime(start.year, start.month, start.day + i);
        final b = widget.data.birthdaysOn(d);
        if (b.isNotEmpty) birthdayDays[d] = b;
      }
    }
    final days = {...byDay.keys, ...birthdayDays.keys}.toList()..sort();
    final dayFmt = DateFormat.MMMEd(context.dateLocale);
    final today = DateTime.now();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + NavBarInset.of(context)),
      children: [
        PrismTextField(
          controller: _search,
          labelText: l10n.calendarSearch,
          prefixIcon: Icon(AppIcons.search),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (days.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              query.trim().isEmpty
                  ? l10n.calendarAgendaEmpty
                  : l10n.calendarSearchEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final d in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Row(
              children: [
                Text(
                  isSameDay(d, today)
                      ? '${l10n.calendarToday} · ${dayFmt.format(d)}'
                      : dayFmt.format(d),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSameDay(d, today)
                        ? theme.colorScheme.primary
                        : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.data.moodAverageOn(d) case final m?) ...[
                  const SizedBox(width: 6),
                  Text(MoodLevel.emoji(m)),
                ],
              ],
            ),
          ),
          for (final b in birthdayDays[d] ?? const <BirthdayOnDay>[])
            _OverlayRow(
              icon: AppIcons.cake,
              color: Colors.pinkAccent,
              text: b.age == null
                  ? l10n.calendarBirthdayOf(b.name(preferDisplayName: prefer))
                  : l10n.calendarBirthdayTurning(
                      b.name(preferDisplayName: prefer),
                      b.age!,
                    ),
            ),
          for (final o in byDay[d] ?? const <CalendarOccurrence>[])
            OccurrenceTile(occurrence: o, day: d),
        ],
        if (query.trim().isEmpty) ...[
          const SizedBox(height: 12),
          Center(
            child: PrismButton(
              label: l10n.calendarShowMore,
              onPressed: () => setState(() => _days += 60),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Filters ───────────────────────────────────────────────────────────────

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overlays = ref.watch(calendarOverlaysProvider);
    final notifier = ref.read(calendarOverlaysProvider.notifier);
    final categories = ref.watch(calendarCategoriesProvider);
    final filter = ref.watch(calendarCategoryFilterProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismSwitchRow(
            title: l10n.calendarShowBirthdays,
            icon: AppIcons.cake,
            value: overlays.birthdays,
            onChanged: (v) => notifier.set(overlays.copyWith(birthdays: v)),
          ),
          PrismSwitchRow(
            title: l10n.calendarShowMood,
            icon: AppIcons.navMood,
            value: overlays.mood,
            onChanged: (v) => notifier.set(overlays.copyWith(mood: v)),
          ),
          PrismSwitchRow(
            title: l10n.calendarShowReminders,
            icon: AppIcons.notificationsNoneRounded,
            value: overlays.reminders,
            onChanged: (v) => notifier.set(overlays.copyWith(reminders: v)),
          ),
          PrismSwitchRow(
            title: tr(context, 'Show habits', 'Mostrar hábitos'),
            icon: AppIcons.navHabits,
            value: overlays.habits,
            onChanged: (v) => notifier.set(overlays.copyWith(habits: v)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              l10n.calendarCategory,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismChip(
                  label: l10n.calendarAllCategories,
                  selected: filter == null,
                  onTap: () => ref
                      .read(calendarCategoryFilterProvider.notifier)
                      .set(null),
                ),
                for (final c in categories)
                  PrismChip(
                    label: c,
                    selected: filter == c,
                    onTap: () => ref
                        .read(calendarCategoryFilterProvider.notifier)
                        .set(c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
