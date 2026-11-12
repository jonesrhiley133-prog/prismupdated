import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/domain/models/reminder.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/calendar/utils/recurrence.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';
import 'package:prism_plurality/features/members/utils/birthday.dart';
import 'package:prism_plurality/features/mood/utils/mood_stats.dart';

/// A member's birthday falling on a given day.
class BirthdayOnDay {
  const BirthdayOnDay({this.member, this.contact, this.age})
    : assert(member != null || contact != null);
  final Member? member;
  final Contact? contact;

  /// Display name of whoever's birthday it is.
  String name({required bool preferDisplayName}) =>
      member?.effectiveName(preferDisplayName: preferDisplayName) ??
      contact!.displayName;

  /// Age turned on that day, when the birth year is known.
  final int? age;
}

/// A scheduled reminder firing on a given day.
class ReminderOnDay {
  const ReminderOnDay({required this.reminder, required this.times});
  final Reminder reminder;
  final List<String> times;
}

/// Everything the calendar draws, combined from events and the optional
/// overlays (birthdays, mood, reminders), with the category filter applied.
class CalendarData {
  CalendarData({
    required List<CalendarEvent> events,
    required this.members,
    this.contacts = const [],
    required this.moodEntries,
    required this.reminders,
    required this.overlays,
    this.categoryFilter,
  }) : events = categoryFilter == null
           ? events
           : events.where((e) => e.category == categoryFilter).toList(),
       _moodByDay = overlays.mood
           ? dailyAverageMood(moodEntries)
           : const <DateTime, double>{};

  final List<CalendarEvent> events;
  final List<Member> members;
  final List<Contact> contacts;
  final List<MoodEntry> moodEntries;
  final List<Reminder> reminders;
  final CalendarOverlays overlays;
  final String? categoryFilter;
  final Map<DateTime, double> _moodByDay;

  List<CalendarOccurrence> occurrencesBetween(DateTime start, DateTime end) =>
      expandCalendarEvents(events, start, end);

  List<CalendarOccurrence> occurrencesOn(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return occurrencesBetween(
      start,
      DateTime(day.year, day.month, day.day + 1),
    );
  }

  double? moodAverageOn(DateTime day) =>
      _moodByDay[DateTime(day.year, day.month, day.day)];

  List<BirthdayOnDay> birthdaysOn(DateTime day) {
    if (!overlays.birthdays) return const [];
    final out = <BirthdayOnDay>[];
    for (final m in members) {
      final b = parseBirthday(m.birthday);
      if (b == null) continue;
      final matches =
          (b.month == day.month && b.day == day.day) ||
          // Feb 29 birthdays show on Feb 28 in non-leap years.
          (b.month == 2 &&
              b.day == 29 &&
              day.month == 2 &&
              day.day == 28 &&
              DateTime(day.year, 2, 29).month != 2);
      if (!matches) continue;
      final known = !isBirthdayYearHidden(b) && b.year < day.year;
      out.add(BirthdayOnDay(member: m, age: known ? day.year - b.year : null));
    }
    // Contact birthdays recur every year (Feb 29 → Feb 28 in other years).
    final d = DateTime(day.year, day.month, day.day);
    for (final c in contacts) {
      final b = BirthdayDate.fromStorage(c.birthday);
      if (b == null || b.nextOccurrence(d) != d) continue;
      out.add(BirthdayOnDay(contact: c, age: b.ageOn(d)));
    }
    return out;
  }

  List<ReminderOnDay> remindersOn(DateTime day) {
    if (!overlays.reminders) return const [];
    final out = <ReminderOnDay>[];
    final d = DateTime(day.year, day.month, day.day);
    for (final r in reminders) {
      if (!r.isActive || r.trigger != ReminderTrigger.scheduled) continue;
      final fires = switch (r.frequency) {
        ReminderFrequency.daily => true,
        ReminderFrequency.weekly => (r.weeklyDays ?? const <int>[]).contains(
          d.weekday % 7,
        ),
        ReminderFrequency.interval => _intervalFiresOn(r, d),
      };
      if (fires) out.add(ReminderOnDay(reminder: r, times: r.allTimesOfDay));
    }
    return out;
  }

  static bool _intervalFiresOn(Reminder r, DateTime day) {
    final n = r.intervalDays ?? 1;
    if (n <= 1) return true;
    final anchor = r.createdAt;
    final a = DateTime.utc(anchor.year, anchor.month, anchor.day);
    final b = DateTime.utc(day.year, day.month, day.day);
    final diff = b.difference(a).inDays;
    return diff >= 0 && diff % n == 0;
  }

  /// Agenda search: title, description, location or category contains
  /// [query] (case-insensitive).
  static bool matchesQuery(CalendarEvent e, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      e.title,
      e.description,
      e.location,
      e.category,
    ].whereType<String>().any((s) => s.toLowerCase().contains(q));
  }
}
