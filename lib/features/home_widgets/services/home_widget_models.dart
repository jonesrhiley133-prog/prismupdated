import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:intl/intl.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/achievements/utils/achievements.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';
import 'package:prism_plurality/features/finance/utils/finance.dart';
import 'package:prism_plurality/features/fitness/utils/fitness.dart';
import 'package:prism_plurality/features/headspace/utils/headspace.dart';
import 'package:prism_plurality/features/home_widgets/models/widget_config.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_data.dart';
import 'package:prism_plurality/features/journal/utils/journal_stats.dart';
import 'package:prism_plurality/features/relationships/utils/relationships.dart';
import 'package:prism_plurality/features/school/utils/school.dart';
import 'package:prism_plurality/features/subsystems/utils/subsystems.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/work/utils/money.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

/// To-do items live in the shared tracker store.
const todoKind = 'todo.item';

typedef Json = Map<String, Object?>;

Json wAction(String action, {bool background = false, Json? optimistic}) => {
  'action': action,
  if (background) 'background': true,
  'optimistic': ?optimistic,
};

Json wRoute(String path) => wAction('route:$path');

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.isEmpty
      ? '?'
      : parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
}

class _Ctx {
  _Ctx(this.cfg, this.d, this.l10n, this.locale);

  final WidgetConfig cfg;
  final HomeWidgetData d;
  final AppLocalizations l10n;
  final String locale;

  WidgetPrivacy get p => cfg.privacy;

  String name(String? memberId) {
    final m = memberId == null ? null : d.members[memberId];
    if (m == null) return '?';
    return p.hideNames ? _initials(m.name) : m.name;
  }

  String person(String n) => p.hideNames ? _initials(n) : n;

  String money(int cents) => p.maskNumbers
      ? '••••'
      : formatMoneyCents(cents, d.currency, locale: locale);

  /// Formats with the app locale, falling back when locale data is not
  /// loaded yet (early start, background refresh).
  String df(DateFormat Function([dynamic locale]) make, DateTime t) {
    try {
      return make(locale).format(t);
    } catch (_) {
      return make().format(t);
    }
  }

  String time(DateTime t) => df(DateFormat.jm, t);

  Json memberRow(
    Member m, {
    String? subtitle,
    DateTime? time,
    String timeStyle = 'relative',
    Json? action,
    bool? checked,
    String? trailing,
  }) => {
    'title': p.hideNames ? _initials(m.name) : m.name,
    'subtitle': ?subtitle,
    if (time != null) 'time': time.millisecondsSinceEpoch,
    'timeStyle': timeStyle,
    'trailing': ?trailing,
    'emoji': m.emoji == '❔' ? null : m.emoji,
    if (!p.hideNames) 'memberId': m.id,
    'checked': ?checked,
    'action': action ?? wRoute(AppRoutePaths.member(m.id)),
  };
}

Json _model({
  required Json header,
  List<Json> rows = const [],
  List<Json> buttons = const [],
  String? empty,
  Json? tap,
  int? rowsSmall,
  int? rowsMedium,
  int? rowsLarge,
  int? buttonsSmall,
}) => {
  'header': header,
  'rows': rows,
  'buttons': buttons,
  'empty': ?empty,
  'tap': ?tap,
  'rowsSmall': ?rowsSmall,
  'rowsMedium': ?rowsMedium,
  'rowsLarge': ?rowsLarge,
  'buttonsSmall': ?buttonsSmall,
};

/// Builds the widget model for [cfg] (without images, which are added by
/// [enrichWidgetModel]).
Json buildWidgetModel(
  WidgetConfig cfg,
  HomeWidgetData d,
  AppLocalizations l10n,
  String locale,
) {
  final c = _Ctx(cfg, d, l10n, locale);
  final model = switch (cfg.type) {
    'recent_fronters' => _recent(c),
    'current_fronter' => _current(c),
    'quick_front' => _quickFront(c),
    'events' => _events(c),
    'journal' => _journal(c),
    'cycle' => _cycle(c),
    'mood' => _mood(c),
    'location' => _location(c),
    'sleep' => _sleep(c),
    'fitness' => _fitness(c),
    'todo' => _todo(c),
    'school' => _school(c),
    'finance' => _finance(c),
    'countdown' => _countdown(c),
    'relationships' => _relationships(c),
    'achievements' => _achievements(c),
    'headspace' => _headspace(c),
    'notes' => _notes(c),
    'subsystems' => _subsystems(c),
    _ => _stats(c),
  };
  model['style'] = nativeStyle(cfg.style);
  model['type'] = cfg.type;
  return model;
}

List<String> _orderedFronters(HomeWidgetData d) {
  final s = [...d.activeSessions]
    ..sort((a, b) => b.startTime.compareTo(a.startTime));
  return [
    for (final x in s)
      if (x.memberId != null && d.members.containsKey(x.memberId)) x.memberId!,
  ];
}

Json _recent(_Ctx c) {
  final latest = <String, ({DateTime start, DateTime? end})>{};
  for (final s in c.d.recentSessions) {
    if (s.sessionType == SessionType.sleep ||
        s.memberId == null ||
        !c.d.members.containsKey(s.memberId))
      continue;
    final cur = latest[s.memberId!];
    if (cur == null || s.startTime.isAfter(cur.start))
      latest[s.memberId!] = (start: s.startTime, end: s.endTime);
  }
  final sorted = latest.entries.toList()
    ..sort((a, b) => b.value.start.compareTo(a.value.start));
  return _model(
    header: {'title': c.l10n.hwRecentFronters, 'emoji': '🕘'},
    rows: [
      for (final e in sorted)
        c.memberRow(
          c.d.members[e.key]!,
          subtitle: e.value.end == null
              ? c.l10n.hwFrontingNow
              : c.l10n.hwFrontedAt(c.time(e.value.start)),
          time: e.value.end ?? e.value.start,
        ),
    ],
    buttons: [
      {
        'label': c.l10n.fnActionSwitch,
        'emoji': '🔄',
        ...wAction('front:switch'),
      },
    ],
    empty: c.l10n.hwNoRecentFronting,
    tap: wRoute(AppRoutePaths.timeline),
  );
}

Json _current(_Ctx c) {
  final ids = _orderedFronters(c.d);
  final sessions = [...c.d.activeSessions]
    ..sort((a, b) => b.startTime.compareTo(a.startTime));
  if (ids.isEmpty) {
    return _model(
      header: {
        'title': c.d.activeSleep != null
            ? c.l10n.hwAsleep
            : c.l10n.fnNobodyFronting,
        'emoji': c.d.activeSleep != null ? '🌙' : '👤',
        'subtitle': c.d.customStatus.isEmpty ? null : c.d.customStatus,
        'subtitleSmall': true,
      },
      buttons: [
        {
          'label': c.l10n.fnActionSwitch,
          'emoji': '🔄',
          ...wAction('front:switch'),
        },
      ],
      tap: wRoute(AppRoutePaths.home),
    );
  }
  final primary = c.d.members[ids.first]!;
  final notes = sessions.first.notes?.trim();
  return _model(
    header: {
      'title': c.name(primary.id),
      'subtitle': [
        if (c.d.customStatus.isNotEmpty)
          c.d.customStatus
        else if (notes != null && notes.isNotEmpty)
          notes,
        if (!c.p.hideNames && (primary.pronouns?.isNotEmpty ?? false))
          primary.pronouns!,
      ].join(' · '),
      'subtitleSmall': true,
      'emoji': primary.emoji == '❔' ? '👤' : primary.emoji,
      if (!c.p.hideNames) 'memberId': primary.id,
      'time': sessions.first.startTime.millisecondsSinceEpoch,
      'timeStyle': 'relative',
    },
    rows: [
      for (final id in ids.skip(1))
        c.memberRow(c.d.members[id]!, subtitle: c.l10n.hwCofronting),
    ],
    buttons: [
      {
        'label': c.l10n.fnActionSwitch,
        'emoji': '🔄',
        ...wAction('front:switch'),
      },
      {'label': c.l10n.fnActionMood, 'emoji': '🙂', ...wAction('mood:open')},
      {
        'label': c.l10n.fnActionDetails,
        'emoji': '📋',
        ...wRoute(AppRoutePaths.session(sessions.first.id)),
      },
    ],
    tap: wRoute(AppRoutePaths.member(primary.id)),
    buttonsSmall: 1,
  );
}

Json _quickFront(_Ctx c) {
  final fronting = _orderedFronters(c.d).toSet();
  final chosen = c.cfg.stringList('memberIds');
  final counts = <String, int>{};
  for (final s in c.d.recentSessions) {
    if (s.memberId != null && s.sessionType != SessionType.sleep)
      counts[s.memberId!] = (counts[s.memberId!] ?? 0) + 1;
  }
  final candidates = chosen.isNotEmpty
      ? [
          for (final id in chosen)
            if (c.d.members.containsKey(id)) id,
        ]
      : ([...c.d.members.keys.where((id) => c.d.members[id]!.isActive)]
          ..sort((a, b) {
            final fa = fronting.contains(a) ? 1 : 0,
                fb = fronting.contains(b) ? 1 : 0;
            if (fa != fb) return fb.compareTo(fa);
            return (counts[b] ?? 0).compareTo(counts[a] ?? 0);
          }));
  return _model(
    header: {
      'title': c.l10n.fnActionQuickFront,
      'emoji': '⚡',
      'subtitle': c.l10n.hwTapToToggle,
    },
    rows: [
      for (var i = 0; i < candidates.length; i++)
        c.memberRow(
          c.d.members[candidates[i]]!,
          checked: fronting.contains(candidates[i]),
          action: wAction(
            'quickfront:${candidates[i]}',
            background: true,
            optimistic: {'toggleRow': i},
          ),
        ),
    ],
    buttons: [
      {
        'label': c.l10n.fnActionSwitch,
        'emoji': '🔄',
        ...wAction('front:switch'),
      },
    ],
    empty: c.l10n.relNeedMembers,
    rowsSmall: 3,
    rowsMedium: 4,
  );
}

Json _events(_Ctx c) {
  final now = c.d.now;
  final occ =
      c.d.calendar?.occurrencesBetween(
        now,
        now.add(Duration(days: c.cfg.intOption('days', 14))),
      ) ??
      const [];
  final sorted = [...occ]..sort((a, b) => a.start.compareTo(b.start));
  return _model(
    header: {'title': c.l10n.hwEvents, 'emoji': '📅'},
    rows: [
      for (final o in sorted)
        {
          'title': o.event.title,
          'subtitle': '${c.df(DateFormat.MMMEd, o.start)} ${c.time(o.start)}',
          'time': o.start.millisecondsSinceEpoch,
          'timeStyle': 'days',
          'emoji': '📅',
          'action': wRoute(AppRoutePaths.calendar),
        },
    ],
    buttons: [
      {'label': c.l10n.hwNewEvent, 'emoji': '➕', ...wAction('event:new')},
    ],
    empty: c.l10n.hwNoEvents,
    tap: wRoute(AppRoutePaths.calendar),
  );
}

Json _journal(_Ctx c) {
  final entries = c.d.kind(TrackerKind.journalEntry)
    ..sort(
      (a, b) =>
          (b.occurredAt ?? b.createdAt).compareTo(a.occurredAt ?? a.createdAt),
    );
  final stats = JournalStats.of(entries, c.d.now);
  final prompts = [
    c.l10n.journalPrompt1,
    c.l10n.journalPrompt2,
    c.l10n.journalPrompt3,
    c.l10n.journalPrompt4,
    c.l10n.journalPrompt5,
  ];
  final prompt = prompts[c.d.now.day % prompts.length];
  return _model(
    header: {
      'title': c.l10n.navJournal,
      'emoji': '📓',
      'subtitle': prompt,
      'trailing': c.l10n.journalDays(stats.currentStreak),
    },
    rows: [
      for (final e in entries.take(8))
        {
          'title': e.isPrivate || c.p.hideSensitive
              ? c.l10n.hwPrivateEntry
              : (e.title.isEmpty ? (e.body ?? '') : e.title),
          if (!c.p.hideSensitive && !e.isPrivate && e.body != null)
            'subtitle': e.body,
          'time': (e.occurredAt ?? e.createdAt).millisecondsSinceEpoch,
          'action': wRoute(AppRoutePaths.journal),
        },
    ],
    buttons: [
      {
        'label': c.l10n.journalNewEntry,
        'emoji': '✏️',
        ...wAction('journal:new'),
      },
    ],
    empty: c.l10n.journalEmptyTitle,
    tap: wRoute(AppRoutePaths.journal),
  );
}

Json _cycle(_Ctx c) {
  final s = c.d.cycleStats;
  final todayKey = CycleStats.dateKey(c.d.now);
  final today = c.d.cycleEntries.where((e) => e.date == todayKey).firstOrNull;
  return _model(
    header: {
      'title': s.currentCycleDay == null
          ? c.l10n.navCycle
          : c.l10n.cycDayN(s.currentCycleDay!),
      'emoji': '💧',
      'subtitle': s.nextPeriodEstimate == null
          ? null
          : c.l10n.cycPeriodAround(
              c.df(DateFormat.MMMd, s.nextPeriodEstimate!),
            ),
      'subtitleSmall': true,
    },
    rows: [
      if (s.nextPeriodEstimate != null)
        {
          'title': c.l10n.hwNextPeriod,
          'time': s.nextPeriodEstimate!.millisecondsSinceEpoch,
          'timeStyle': 'days',
          'emoji': '📆',
        },
      if (s.averageCycleLength != null)
        {
          'title': c.l10n.cycAvgCycle,
          'trailing': c.l10n.journalDays(s.averageCycleLength!.round()),
          'emoji': '🔁',
        },
      if (!c.p.hideSensitive && today != null && today.symptoms.isNotEmpty)
        {
          'title': c.l10n.hwSymptomsToday,
          'subtitle': today.symptoms
              .map((x) => cycleSymptoms[x] ?? x)
              .join(', '),
          'emoji': '🩹',
        },
    ],
    buttons: [
      {'label': c.l10n.cycleLogToday, 'emoji': '➕', ...wAction('cycle:today')},
    ],
    tap: wRoute(AppRoutePaths.cycle),
    buttonsSmall: 1,
  );
}

const _moodEmoji = ['😞', '😕', '😐', '🙂', '😄'];

Json _mood(_Ctx c) {
  final moods = [...c.d.moods]
    ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  final last = moods.firstOrNull;
  String label(int m) => switch (m) {
    1 => c.l10n.moodLevelAwful,
    2 => c.l10n.moodLevelBad,
    3 => c.l10n.moodLevelOkay,
    4 => c.l10n.moodLevelGood,
    _ => c.l10n.moodLevelGreat,
  };
  return _model(
    header: {
      'title': last == null
          ? c.l10n.hwHowAreYou
          : '${_moodEmoji[(last.mood - 1).clamp(0, 4)]} ${label(last.mood)}',
      'subtitle': last == null
          ? null
          : (c.p.hideSensitive
                ? null
                : last.emotions
                      .map((e) => e.split('@').first.replaceAll('_', ' '))
                      .take(4)
                      .join(', ')),
      if (last != null) 'time': last.recordedAt.millisecondsSinceEpoch,
    },
    rows: [
      for (final m in moods.skip(1).take(6))
        {
          'title': '${_moodEmoji[(m.mood - 1).clamp(0, 4)]} ${label(m.mood)}',
          'time': m.recordedAt.millisecondsSinceEpoch,
          'action': wRoute(AppRoutePaths.mood),
        },
    ],
    buttons: [
      for (var m = 1; m <= 5; m++)
        {
          'emoji': _moodEmoji[m - 1],
          ...wAction(
            'mood:$m',
            background: true,
            optimistic: {'subtitle': c.l10n.hwLogged(_moodEmoji[m - 1])},
          ),
        },
    ],
    tap: wRoute(AppRoutePaths.mood),
    rowsSmall: 0,
    rowsMedium: 1,
    buttonsSmall: 5,
  );
}

Json _location(_Ctx c) {
  final current = c.d.places
      .where((p) => p.id == c.d.activePlaceId)
      .firstOrNull;
  final places = [...c.d.places]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return _model(
    header: {
      'title': current == null
          ? c.l10n.hwNotCheckedIn
          : c.l10n.fnLineLocation(current.name),
      'emoji': current?.emoji ?? '📍',
      'subtitleSmall': true,
    },
    rows: [
      for (var i = 0; i < places.length; i++)
        {
          'title': places[i].name,
          'emoji': places[i].emoji ?? '📍',
          'checked': places[i].id == c.d.activePlaceId,
          'action': wAction(
            'location:${places[i].id}',
            background: true,
            optimistic: {'toggleRow': i},
          ),
        },
    ],
    buttons: [
      if (current != null)
        {
          'label': c.l10n.hwCheckOut,
          'emoji': '🚪',
          ...wAction(
            'location:stop',
            background: true,
            optimistic: {'subtitle': c.l10n.hwCheckedOut},
          ),
        },
      {
        'label': c.l10n.hwPlaces,
        'emoji': '🗺',
        ...wRoute(AppRoutePaths.locations),
      },
    ],
    empty: c.l10n.hwNoPlaces,
    tap: wRoute(AppRoutePaths.locations),
  );
}

Json _sleep(_Ctx c) {
  final done = [
    for (final s in c.d.sleepSessions)
      if (s.endTime != null) s,
  ]..sort((a, b) => b.startTime.compareTo(a.startTime));
  String dur(Duration x) =>
      '${x.inHours}h ${(x.inMinutes % 60).toString().padLeft(2, '0')}m';
  final last = done.firstOrNull;
  return _model(
    header: {
      'title': c.d.activeSleep != null
          ? c.l10n.hwSleepingNow
          : (last == null ? c.l10n.navSleep : dur(last.duration)),
      'emoji': '🌙',
      'subtitle': c.d.activeSleep != null
          ? c.l10n.fnLineAsleep(c.time(c.d.activeSleep!.startTime))
          : (last == null ? null : c.l10n.hwLastNight),
      'subtitleSmall': true,
    },
    rows: [
      for (final s in done.take(5))
        {
          'title': c.df(DateFormat.MMMEd, s.startTime),
          'trailing': dur(s.duration),
          'emoji': '🛏',
          'action': wRoute(AppRoutePaths.sleepSession(s.id)),
        },
    ],
    buttons: [
      if (c.d.activeSleep != null)
        {
          'label': c.l10n.hwWakeUp,
          'emoji': '☀️',
          ...wAction(
            'sleep:end:${c.d.activeSleep!.id}',
            background: true,
            optimistic: {'subtitle': c.l10n.hwGoodMorning},
          ),
        }
      else
        {
          'label': c.l10n.hwGoToSleep,
          'emoji': '😴',
          ...wAction(
            'sleep:start',
            background: true,
            optimistic: {'subtitle': c.l10n.hwSleepWell},
          ),
        },
    ],
    tap: wRoute(AppRoutePaths.sleep),
    buttonsSmall: 1,
  );
}

Json _fitness(_Ctx c) {
  final workouts =
      [
        for (final w in c.d.kind(TrackerKind.fitnessWorkout))
          if (!(w.flag('live') && w.endedAt == null)) w,
      ]..sort(
        (a, b) => (b.occurredAt ?? b.createdAt).compareTo(
          a.occurredAt ?? a.createdAt,
        ),
      );
  final ws = weekStart(c.d.now);
  final week = totalsBetween(workouts, ws, ws.add(const Duration(days: 7)));
  final goals = c.d.kind(TrackerKind.fitnessGoal);
  return _model(
    header: {
      'title': c.l10n.hwWeekMinutes(week.minutes),
      'emoji': '💪',
      'subtitle': c.l10n.hwWeekWorkouts(week.workouts),
      'subtitleSmall': true,
    },
    rows: [
      for (final g in goals)
        () {
          final (cur, target) = goalProgress(g, workouts, c.d.now);
          return {
            'title': g.title,
            'trailing': '${cur.round()}/${target.round()}',
            'progress': target == 0 ? 0 : cur / target,
            'emoji': '🎯',
          };
        }(),
      for (final w in workouts.take(5))
        {
          'title': w.title,
          'subtitle': '${workoutMinutes(w)} min',
          'time': (w.occurredAt ?? w.createdAt).millisecondsSinceEpoch,
          'emoji': '🏃',
        },
    ],
    buttons: [
      {'label': c.l10n.fitNewWorkout, 'emoji': '➕', ...wAction('fitness:new')},
    ],
    tap: wRoute(AppRoutePaths.fitness),
    buttonsSmall: 1,
  );
}

Json _todo(_Ctx c) {
  final items = c.d.kind(todoKind);
  final showDone = c.cfg.boolOption('showDone', false);
  final open =
      [
        for (final t in items)
          if (showDone || !t.flag('done')) t,
      ]..sort((a, b) {
        if (a.flag('done') != b.flag('done')) return a.flag('done') ? 1 : -1;
        final ad = a.occurredAt, bd = b.occurredAt;
        if (ad == null && bd == null) return a.sortOrder.compareTo(b.sortOrder);
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
  final assignments = c.cfg.boolOption('includeAssignments', true)
      ? [
          for (final a in c.d.kind(TrackerKind.schoolAssignment))
            if (!isDone(a) && a.occurredAt != null) a,
        ]
      : const <TrackerRecord>[];
  final rows = <Json>[
    for (var i = 0; i < open.length; i++)
      {
        'title': open[i].title,
        if (open[i].occurredAt != null)
          'time': open[i].occurredAt!.millisecondsSinceEpoch,
        'timeStyle': 'days',
        'checked': open[i].flag('done'),
        'action': wAction(
          'todo:${open[i].id}',
          background: true,
          optimistic: {'toggleRow': i},
        ),
      },
    for (final a
        in assignments..sort((x, y) => x.occurredAt!.compareTo(y.occurredAt!)))
      {
        'title': a.title,
        'emoji': '🎓',
        'time': a.occurredAt!.millisecondsSinceEpoch,
        'timeStyle': 'days',
        'action': wRoute(AppRoutePaths.school),
      },
  ];
  return _model(
    header: {
      'title': c.l10n.hwTodo,
      'emoji': '✅',
      'trailing': '${open.where((t) => !t.flag('done')).length}',
    },
    rows: rows,
    buttons: [
      {'label': c.l10n.hwAddTask, 'emoji': '➕', ...wAction('todo:new')},
      {
        'label': c.l10n.hwAllTasks,
        'emoji': '📋',
        ...wRoute(AppRoutePaths.todos),
      },
    ],
    empty: c.l10n.hwNoTasks,
    tap: wRoute(AppRoutePaths.todos),
    rowsSmall: 3,
  );
}

Json _school(_Ctx c) {
  final classes = c.d.kind(TrackerKind.schoolClass);
  final assignments = c.d.kind(TrackerKind.schoolAssignment);
  final today = scheduleFor(classes, c.d.now);
  final due = [
    for (final a in assignments)
      if (!isDone(a) && a.occurredAt != null) a,
  ]..sort((a, b) => a.occurredAt!.compareTo(b.occurredAt!));
  final byId = {for (final x in classes) x.id: x};
  final g = gpa(classes, groupByParent(assignments));
  return _model(
    header: {
      'title': c.l10n.navSchool,
      'emoji': '🎓',
      'subtitle': c.l10n.hwClassesToday(today.length),
      'trailing': g == null || c.p.maskNumbers
          ? ''
          : 'GPA ${g.toStringAsFixed(2)}',
    },
    rows: [
      for (final (cls, m) in today)
        {
          'title': cls.title,
          'subtitle':
              '${formatMinuteOfDay(m.startMinute)}–${formatMinuteOfDay(m.endMinute)} ${cls.str(SchoolField.room) ?? ''}'
                  .trim(),
          'emoji': '🏫',
          'action': wRoute(AppRoutePaths.school),
        },
      for (final a in due.take(6))
        {
          'title': a.title,
          'subtitle': byId[a.parentId]?.title,
          'time': a.occurredAt!.millisecondsSinceEpoch,
          'timeStyle': 'days',
          'emoji':
              a.str(SchoolField.type) == 'exam' ||
                  a.str(SchoolField.type) == 'quiz'
              ? '📝'
              : '📚',
          'action': wRoute(AppRoutePaths.school),
        },
    ],
    buttons: [
      {
        'label': c.l10n.schNewAssignment,
        'emoji': '➕',
        ...wAction('school:new'),
      },
    ],
    empty: c.l10n.schNothingDue,
    tap: wRoute(AppRoutePaths.school),
    buttonsSmall: 1,
  );
}

Json _finance(_Ctx c) {
  final txns = c.d.kind(TrackerKind.financeTxn);
  final m = monthTotals(txns, c.d.now);
  final budgets = budgetStatuses(c.d.kind(TrackerKind.financeBudget), m);
  final goals = c.d.kind(TrackerKind.financeGoal);
  final hide = c.p.hideSensitive;
  return _model(
    header: {
      'title': hide
          ? c.l10n.navFinance
          : c.l10n.hwSpentMonth(c.money(m.expenses)),
      'emoji': '💰',
      'subtitle': hide ? null : c.l10n.hwIncomeMonth(c.money(m.income)),
      'subtitleSmall': true,
    },
    rows: hide
        ? const []
        : [
            for (final b in budgets)
              {
                'title': b.category,
                'trailing': '${c.money(b.spent)} / ${c.money(b.limit)}',
                'progress': b.fraction,
                'emoji': b.over ? '⚠️' : '📊',
              },
            for (final g in goals)
              {
                'title': g.title,
                'trailing':
                    '${c.money(g.integer(FinField.saved) ?? 0)} / ${c.money(g.amount ?? 0)}',
                'progress': (g.amount ?? 0) == 0
                    ? 0
                    : (g.integer(FinField.saved) ?? 0) / g.amount!,
                'emoji': '🐷',
              },
          ],
    buttons: [
      {'label': c.l10n.finNewTxn, 'emoji': '➕', ...wAction('finance:new')},
    ],
    empty: hide ? c.l10n.hwHiddenHint : null,
    tap: wRoute(AppRoutePaths.finance),
    buttonsSmall: 1,
  );
}

Json _countdown(_Ctx c) {
  final now = c.d.now;
  final today = DateTime(now.year, now.month, now.day);
  final items = <({String title, DateTime date, String emoji})>[];
  final custom = c.cfg.options['countdowns'];
  if (custom is List) {
    for (final x in custom) {
      if (x is Map && x['title'] is String && x['date'] is int) {
        final d = DateTime.fromMillisecondsSinceEpoch(x['date'] as int);
        if (!d.isBefore(today))
          items.add((
            title: x['title'] as String,
            date: d,
            emoji: x['emoji'] is String ? x['emoji'] as String : '⏳',
          ));
      }
    }
  }
  if (c.cfg.boolOption('birthdays', true)) {
    for (final m in c.d.members.values) {
      final b = DateTime.tryParse(m.birthday ?? '');
      if (b == null) continue;
      var next = DateTime(today.year, b.month, b.day);
      if (next.isBefore(today)) next = DateTime(today.year + 1, b.month, b.day);
      items.add((
        title: c.l10n.hwBirthdayOf(c.name(m.id)),
        date: next,
        emoji: '🎂',
      ));
    }
    for (final ct in c.d.contacts) {
      final b = DateTime.tryParse(ct.birthday ?? '');
      if (b == null) continue;
      var next = DateTime(today.year, b.month, b.day);
      if (next.isBefore(today)) next = DateTime(today.year + 1, b.month, b.day);
      items.add((
        title: c.l10n.hwBirthdayOf(c.person(ct.displayName)),
        date: next,
        emoji: '🎂',
      ));
    }
  }
  if (c.cfg.boolOption('events', true)) {
    for (final o
        in c.d.calendar?.occurrencesBetween(
              now,
              now.add(const Duration(days: 60)),
            ) ??
            const []) {
      items.add((title: o.event.title, date: o.start, emoji: '📅'));
    }
  }
  items.sort((a, b) => a.date.compareTo(b.date));
  final first = items.firstOrNull;
  return _model(
    header: {
      'title': first?.title ?? c.l10n.hwCountdown,
      'emoji': first?.emoji ?? '⏳',
      if (first != null) 'time': first.date.millisecondsSinceEpoch,
      'timeStyle': 'days',
      'subtitle': first == null ? null : c.df(DateFormat.yMMMd, first.date),
      'subtitleSmall': true,
    },
    rows: [
      for (final i in items.skip(1).take(8))
        {
          'title': i.title,
          'emoji': i.emoji,
          'time': i.date.millisecondsSinceEpoch,
          'timeStyle': 'days',
          'subtitle': c.df(DateFormat.MMMd, i.date),
        },
    ],
    empty: c.l10n.hwNoCountdowns,
    tap: wRoute(AppRoutePaths.calendar),
    rowsSmall: 1,
  );
}

Json _relationships(_Ctx c) {
  final chosen = c.cfg.stringList('relationshipIds');
  final all = c.d.kind(TrackerKind.relationship);
  final rels =
      (chosen.isEmpty
            ? [...all]
            : [
                for (final r in all)
                  if (chosen.contains(r.id)) r,
              ])
        ..removeWhere((r) => r.isPrivate && c.p.hideSensitive)
        ..sort(
          (a, b) => (b.integer(RelField.closeness) ?? 0).compareTo(
            a.integer(RelField.closeness) ?? 0,
          ),
        );
  final ids = {for (final r in rels) r.id};
  final events =
      [
        for (final e in c.d.kind(TrackerKind.relationshipEvent))
          if (ids.contains(e.parentId)) e,
      ]..sort(
        (a, b) => (b.occurredAt ?? b.createdAt).compareTo(
          a.occurredAt ?? a.createdAt,
        ),
      );
  String other(TrackerRecord r) => isInternal(r)
      ? c.name(r.str(RelField.otherId))
      : c.person(r.str(RelField.otherName) ?? '?');
  return _model(
    header: {
      'title': c.l10n.navRelationships,
      'emoji': '🤝',
      'trailing': '${rels.length}',
    },
    rows: [
      for (final r in rels.take(6))
        {
          'title': '${c.name(r.memberId)} ↔ ${other(r)}',
          'subtitle': r.str(RelField.type)?.replaceAll('_', ' '),
          if (r.integer(RelField.closeness) != null)
            'progress': r.integer(RelField.closeness)! / 5,
          'emoji': isInternal(r) ? '💞' : '👥',
          'action': wRoute(AppRoutePaths.relationships),
        },
      if (!c.p.hideSensitive)
        for (final e in events.take(3))
          {
            'title': e.title,
            'time': (e.occurredAt ?? e.createdAt).millisecondsSinceEpoch,
            'emoji': '🗓',
            'action': wRoute(AppRoutePaths.relationships),
          },
    ],
    empty: c.l10n.relEmpty,
    tap: wRoute(AppRoutePaths.relationships),
  );
}

Json _achievements(_Ctx c) {
  final a = c.d.achievements;
  final unlocked = [
    for (final p in a)
      if (p.unlockedAt != null) p,
  ]..sort((x, y) => y.unlockedAt!.compareTo(x.unlockedAt!));
  final next = [
    for (final p in a)
      if (!p.unlocked) p,
  ]..sort((x, y) => y.fraction.compareTo(x.fraction));
  String title(AchievementProgress p) =>
      '${p.def.metric.name.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}')} · ${p.def.target}';
  return _model(
    header: {
      'title': c.l10n.navAchievements,
      'emoji': '🏆',
      'trailing': '${a.where((p) => p.unlocked).length}/${a.length}',
    },
    rows: [
      for (final p in unlocked.take(3))
        {
          'title': title(p),
          'time': p.unlockedAt!.millisecondsSinceEpoch,
          'emoji': '🏅',
        },
      for (final p in next.take(4))
        {
          'title': title(p),
          'trailing': '${p.current}/${p.def.target}',
          'progress': p.fraction,
          'emoji': '🎯',
        },
    ],
    tap: wRoute(AppRoutePaths.achievements),
  );
}

Json _headspace(_Ctx c) {
  final maps = c.d.kind(TrackerKind.headspaceMap);
  final wanted = c.cfg.stringOption('mapId');
  final map = maps.where((m) => m.id == wanted).firstOrNull ?? maps.firstOrNull;
  if (map == null || (map.isPrivate && c.p.hideSensitive)) {
    return _model(
      header: {'title': c.l10n.navHeadspace, 'emoji': '🗺'},
      empty: c.l10n.hsIntro,
      tap: wRoute(AppRoutePaths.headspace),
    );
  }
  final areas = [
    for (final a in c.d.kind(TrackerKind.headspaceArea))
      if (a.parentId == map.id && !(a.isPrivate && c.p.hideSensitive)) a,
  ];
  return {
    ..._model(
      header: {
        'title': map.title,
        'emoji': '🗺',
        'subtitle': c.l10n.hsMapSummary(
          areas.length,
          c.d
              .kind(TrackerKind.headspaceLink)
              .where((l) => l.parentId == map.id)
              .length,
        ),
      },
      rows: [
        for (final a in areas)
          {
            'title': a.title,
            'subtitle': [
              for (final r in a.strings(HsField.residents)) c.name(r),
            ].join(', '),
            'emoji': '📍',
            'action': wRoute(AppRoutePaths.headspace),
          },
      ],
      tap: wRoute(AppRoutePaths.headspace),
      rowsLarge: 2,
    ),
    'headspaceMapId': map.id,
  };
}

Json _notes(_Ctx c) {
  final pinned = c.cfg.stringList('noteIds');
  final notes =
      (pinned.isEmpty
            ? [...c.d.notes]
            : [
                for (final id in pinned)
                  ?c.d.notes.where((n) => n.id == id).firstOrNull,
              ])
        ..sort(
          (a, b) => pinned.isEmpty ? b.modifiedAt.compareTo(a.modifiedAt) : 0,
        );
  return _model(
    header: {'title': c.l10n.hwNotes, 'emoji': '📝'},
    rows: [
      for (final n in notes.take(8))
        {
          'title': c.p.hideSensitive
              ? c.l10n.hwNoteHidden
              : (n.title.isEmpty ? c.l10n.journalUntitled : n.title),
          if (!c.p.hideSensitive) 'subtitle': n.body,
          'time': n.modifiedAt.millisecondsSinceEpoch,
          'emoji': pinned.contains(n.id) ? '📌' : '🗒',
          'action': wRoute(AppRoutePaths.note(n.id)),
        },
    ],
    buttons: [
      {'label': c.l10n.hwNewNote, 'emoji': '➕', ...wAction('note:new')},
    ],
    empty: c.l10n.hwNoNotes,
    tap: wRoute(AppRoutePaths.notes),
  );
}

Json _subsystems(_Ctx c) {
  final all = c.d.kind(TrackerKind.subsystem);
  final chosen = c.cfg.stringList('subsystemIds');
  final list = [
    for (final s in all)
      if ((chosen.isEmpty || chosen.contains(s.id)) &&
          !(s.isPrivate && c.p.hideSensitive))
        s,
  ];
  return _model(
    header: {
      'title': c.l10n.navSubsystems,
      'emoji': '🌳',
      'trailing': '${list.length}',
    },
    rows: [
      for (final s in list)
        {
          'title': '${s.str(SubField.emoji) ?? ''} ${s.title}'.trim(),
          'subtitle': [
            c.l10n.subMembersCount(allMemberIds(s, all).length),
            ...subsystemMembers(s)
                .where((m) => m.role != null)
                .take(3)
                .map((m) => '${c.name(m.memberId)}: ${m.role}'),
          ].join(' · '),
          'action': wRoute(AppRoutePaths.subsystems),
        },
    ],
    empty: c.l10n.subEmpty,
    tap: wRoute(AppRoutePaths.subsystems),
  );
}

Json _stats(_Ctx c) {
  final days = c.cfg.intOption('days', 7);
  final from = c.d.now.subtract(Duration(days: days));
  final sessions = [
    for (final s in c.d.recentSessions)
      if (s.sessionType != SessionType.sleep &&
          s.memberId != null &&
          (s.endTime ?? c.d.now).isAfter(from))
        s,
  ];
  final secs = <String, int>{};
  var switches = 0;
  for (final s in sessions) {
    if (!s.startTime.isBefore(from)) switches++;
    final start = s.startTime.isBefore(from) ? from : s.startTime;
    final end = s.endTime ?? c.d.now;
    secs[s.memberId!] =
        (secs[s.memberId!] ?? 0) +
        end.difference(start).inSeconds.clamp(0, 1 << 31);
  }
  final total = secs.values.fold(0, (a, b) => a + b);
  final ranked =
      secs.entries.where((e) => c.d.members.containsKey(e.key)).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  return _model(
    header: {
      'title': c.l10n.hwSwitches(switches),
      'emoji': '📊',
      'subtitle': c.l10n.hwLastDays(days),
      'subtitleSmall': true,
    },
    rows: [
      for (final e in ranked)
        {
          ...c.memberRow(
            c.d.members[e.key]!,
            trailing: total == 0 ? '0%' : '${(e.value * 100 / total).round()}%',
            subtitle: '${(e.value / 3600).toStringAsFixed(1)} h',
          ),
          'progress': total == 0 ? 0 : e.value / total,
        },
    ],
    empty: c.l10n.hwNoRecentFronting,
    tap: wRoute(AppRoutePaths.statistics),
    rowsSmall: 2,
    rowsMedium: 3,
    rowsLarge: 7,
  );
}
