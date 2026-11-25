import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/members/utils/birthday.dart';
import 'package:prism_plurality/features/smart_notifications/holidays.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

/// Which birthdays to remind about.
enum BirthdaySource {
  alters('Alters'),
  system('System birthday'),
  contacts('Contacts'),
  calendar('Calendar birthday events'),
  companions('Companion birthdays & adoption days');

  const BirthdaySource(this.label);
  final String label;
}

/// Birthday, holiday and horoscope reminders, plus quiet hours. Synced with
/// the rest of the system's data.
@immutable
class NotifySettings {
  const NotifySettings({
    this.birthdaysOn = true,
    this.birthdayOffsets = const {0},
    this.birthdaySources = const {
      BirthdaySource.alters,
      BirthdaySource.system,
      BirthdaySource.contacts,
      BirthdaySource.calendar,
    },
    this.birthdayMinutes = 9 * 60,
    this.systemBirthday,
    this.systemBirthdayLabel = 'System birthday',
    this.holidaysOn = false,
    this.country = 'US',
    this.holidayCategories = const {
      HolidayCategory.public,
      HolidayCategory.cultural,
      HolidayCategory.awareness,
    },
    this.disabledHolidays = const {},
    this.holidayMinutes = 9 * 60,
    this.horoscopeDaily = false,
    this.horoscopeWeekly = false,
    this.moonPhases = false,
    this.horoscopeMinutes = 8 * 60,
    this.quietOn = false,
    this.quietStart = 22 * 60,
    this.quietEnd = 7 * 60,
    this.record,
  });

  final bool birthdaysOn;

  /// Days before the birthday to remind (0 = on the day).
  final Set<int> birthdayOffsets;
  final Set<BirthdaySource> birthdaySources;
  final int birthdayMinutes;

  /// The system's own birthday ("YYYY-MM-DD"; year may be hidden).
  final String? systemBirthday;
  final String systemBirthdayLabel;

  final bool holidaysOn;
  final String country;
  final Set<HolidayCategory> holidayCategories;
  final Set<String> disabledHolidays;
  final int holidayMinutes;

  /// For whoever is Primary.
  final bool horoscopeDaily;
  final bool horoscopeWeekly;
  final bool moonPhases;
  final int horoscopeMinutes;

  /// Nothing is delivered inside quiet hours; reminders move to their end.
  final bool quietOn;
  final int quietStart;
  final int quietEnd;
  final TrackerRecord? record;

  bool get anyOn =>
      birthdaysOn ||
      holidaysOn ||
      horoscopeDaily ||
      horoscopeWeekly ||
      moonPhases;

  NotifySettings copyWith({
    bool? birthdaysOn,
    Set<int>? birthdayOffsets,
    Set<BirthdaySource>? birthdaySources,
    int? birthdayMinutes,
    String? systemBirthday,
    bool clearSystemBirthday = false,
    String? systemBirthdayLabel,
    bool? holidaysOn,
    String? country,
    Set<HolidayCategory>? holidayCategories,
    Set<String>? disabledHolidays,
    int? holidayMinutes,
    bool? horoscopeDaily,
    bool? horoscopeWeekly,
    bool? moonPhases,
    int? horoscopeMinutes,
    bool? quietOn,
    int? quietStart,
    int? quietEnd,
  }) => NotifySettings(
    birthdaysOn: birthdaysOn ?? this.birthdaysOn,
    birthdayOffsets: birthdayOffsets ?? this.birthdayOffsets,
    birthdaySources: birthdaySources ?? this.birthdaySources,
    birthdayMinutes: birthdayMinutes ?? this.birthdayMinutes,
    systemBirthday: clearSystemBirthday
        ? null
        : (systemBirthday ?? this.systemBirthday),
    systemBirthdayLabel: systemBirthdayLabel ?? this.systemBirthdayLabel,
    holidaysOn: holidaysOn ?? this.holidaysOn,
    country: country ?? this.country,
    holidayCategories: holidayCategories ?? this.holidayCategories,
    disabledHolidays: disabledHolidays ?? this.disabledHolidays,
    holidayMinutes: holidayMinutes ?? this.holidayMinutes,
    horoscopeDaily: horoscopeDaily ?? this.horoscopeDaily,
    horoscopeWeekly: horoscopeWeekly ?? this.horoscopeWeekly,
    moonPhases: moonPhases ?? this.moonPhases,
    horoscopeMinutes: horoscopeMinutes ?? this.horoscopeMinutes,
    quietOn: quietOn ?? this.quietOn,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    record: record,
  );

  Map<String, Object?> toFields() => {
    'birthdaysOn': birthdaysOn,
    'birthdayOffsets': (birthdayOffsets.toList()..sort()),
    'birthdaySources': [for (final s in birthdaySources) s.name],
    'birthdayMinutes': birthdayMinutes,
    'systemBirthday': systemBirthday,
    'systemBirthdayLabel': systemBirthdayLabel,
    'holidaysOn': holidaysOn,
    'country': country,
    'holidayCategories': [for (final c in holidayCategories) c.name],
    'disabledHolidays': disabledHolidays.toList(),
    'holidayMinutes': holidayMinutes,
    'horoscopeDaily': horoscopeDaily,
    'horoscopeWeekly': horoscopeWeekly,
    'moonPhases': moonPhases,
    'horoscopeMinutes': horoscopeMinutes,
    'quietOn': quietOn,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
  };

  static NotifySettings of(TrackerRecord? r, {String? defaultCountry}) {
    const d = NotifySettings();
    final country = holidayCountries.containsKey(defaultCountry)
        ? defaultCountry!
        : d.country;
    if (r == null) return NotifySettings(country: country);
    final f = r.fields;
    int minutes(String k, int fb) =>
        ((f[k] as num?)?.toInt() ?? fb).clamp(0, 24 * 60 - 1);
    Set<T> names<T extends Enum>(String k, List<T> values, Set<T> fb) {
      final raw = f[k];
      if (raw is! List) return fb;
      return {
        for (final v in values)
          if (raw.contains(v.name)) v,
      };
    }

    final offsets = f['birthdayOffsets'];
    return NotifySettings(
      birthdaysOn: f['birthdaysOn'] != false,
      birthdayOffsets: offsets is List
          ? {
              for (final o in offsets)
                if (o is num && o >= 0 && o <= 60) o.toInt(),
            }
          : d.birthdayOffsets,
      birthdaySources: names(
        'birthdaySources',
        BirthdaySource.values,
        d.birthdaySources,
      ),
      birthdayMinutes: minutes('birthdayMinutes', d.birthdayMinutes),
      systemBirthday: f['systemBirthday'] as String?,
      systemBirthdayLabel:
          (f['systemBirthdayLabel'] as String?)?.trim().isNotEmpty == true
          ? f['systemBirthdayLabel'] as String
          : d.systemBirthdayLabel,
      holidaysOn: f['holidaysOn'] == true,
      country: holidayCountries.containsKey(f['country'])
          ? f['country'] as String
          : country,
      holidayCategories: names(
        'holidayCategories',
        HolidayCategory.values,
        d.holidayCategories,
      ),
      disabledHolidays: {
        for (final x in (f['disabledHolidays'] as List? ?? const [])) '$x',
      },
      holidayMinutes: minutes('holidayMinutes', d.holidayMinutes),
      horoscopeDaily: f['horoscopeDaily'] == true,
      horoscopeWeekly: f['horoscopeWeekly'] == true,
      moonPhases: f['moonPhases'] == true,
      horoscopeMinutes: minutes('horoscopeMinutes', d.horoscopeMinutes),
      quietOn: f['quietOn'] == true,
      quietStart: minutes('quietStart', d.quietStart),
      quietEnd: minutes('quietEnd', d.quietEnd),
      record: r,
    );
  }
}

final notifySettingsProvider = Provider<NotifySettings>((ref) {
  final list =
      ref.watch(trackerKindProvider(TrackerKind.notifySettings)).value ??
      const <TrackerRecord>[];
  final latest = list.isEmpty
      ? null
      : (list.toList()..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt)))
            .first;
  return NotifySettings.of(latest, defaultCountry: _deviceCountry());
});

/// The device's country code, used only as the default holiday country.
String? _deviceCountry() {
  try {
    return PlatformDispatcher.instance.locale.countryCode;
  } catch (_) {
    return null;
  }
}

Future<void> saveNotifySettings(WidgetRef ref, NotifySettings s) async {
  final t = ref.read(trackerNotifierProvider.notifier);
  if (s.record == null) {
    await t.create(kind: TrackerKind.notifySettings, fields: s.toFields());
  } else {
    await t.save(s.record!.withFields(s.toFields()));
  }
}

// ── Planning ────────────────────────────────────────────────────────────

enum NotifyCategory { birthday, holiday, horoscope, moon }

/// One notification to schedule.
@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.key,
    required this.when,
    required this.title,
    required this.body,
    required this.category,
    this.payload,
  });

  /// Stable identity, so the same reminder is never scheduled twice.
  final String key;
  final DateTime when;
  final String title;
  final String body;
  final NotifyCategory category;
  final String? payload;
}

/// A birthday to remind about.
@immutable
class BirthdayItem {
  const BirthdayItem(
    this.key,
    this.name,
    this.date,
    this.source, {
    this.adoption = false,
  });
  final String key;
  final String name;
  final DateTime date;
  final BirthdaySource source;

  /// A companion's adoption anniversary rather than a birthday.
  final bool adoption;
}

/// Moves [t] out of quiet hours to the moment they end.
DateTime applyQuietHours(DateTime t, NotifySettings s) {
  if (!s.quietOn || s.quietStart == s.quietEnd) return t;
  final m = t.hour * 60 + t.minute;
  final inside = s.quietStart < s.quietEnd
      ? (m >= s.quietStart && m < s.quietEnd)
      : (m >= s.quietStart || m < s.quietEnd);
  if (!inside) return t;
  var end = DateTime(t.year, t.month, t.day, s.quietEnd ~/ 60, s.quietEnd % 60);
  if (!end.isAfter(t))
    end = DateTime(
      t.year,
      t.month,
      t.day + 1,
      s.quietEnd ~/ 60,
      s.quietEnd % 60,
    );
  return end;
}

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

/// Birthday and holiday reminders between [now] and [now] + [days].
/// Horoscope items are planned separately because they need the chart.
List<PlannedNotification> planCalendarNotifications({
  required NotifySettings settings,
  required List<BirthdayItem> birthdays,
  required DateTime now,
  int days = 21,
}) {
  final out = <PlannedNotification>[];
  final horizon = now.add(Duration(days: days));
  final today = DateTime(now.year, now.month, now.day);
  if (settings.birthdaysOn) {
    for (final b in birthdays) {
      if (!settings.birthdaySources.contains(b.source)) continue;
      for (final year in [today.year, today.year + 1]) {
        // Feb 29 birthdays fall on Feb 28 in other years.
        var day = DateTime(year, b.date.month, b.date.day);
        if (day.month != b.date.month)
          day = DateTime(year, b.date.month + 1, 0);
        for (final off in settings.birthdayOffsets) {
          final when = applyQuietHours(
            _at(day.subtract(Duration(days: off)), settings.birthdayMinutes),
            settings,
          );
          if (!when.isAfter(now) || when.isAfter(horizon)) continue;
          final hasYear = !isBirthdayYearHidden(b.date) && b.date.year > 1900;
          final age = hasYear ? year - b.date.year : null;
          if (b.adoption && (age == null || age < 1)) continue;
          final title = b.adoption
              ? (off == 0
                    ? '🐾 Happy adoption day, ${b.name}!'
                    : '🐾 ${b.name}\'s adoption day is ${off == 1 ? 'tomorrow' : 'in $off days'}')
              : off == 0
              ? '🎂 Happy birthday, ${b.name}!'
              : '🎂 ${b.name}\'s birthday is ${off == 1 ? 'tomorrow' : 'in $off days'}';
          final body = b.adoption
              ? (off == 0
                    ? '${age!} year${age == 1 ? '' : 's'} together today.'
                    : 'Coming up on ${_monthDay(day)} — $age year${age == 1 ? '' : 's'} together.')
              : off == 0
              ? (age != null && age > 0
                    ? '${b.name} turns $age today.'
                    : 'Today is ${b.name}\'s birthday.')
              : 'Coming up on ${_monthDay(day)}${age != null && age > 0 ? ' — turning $age' : ''}.';
          out.add(
            PlannedNotification(
              key: 'bday:${b.key}:$year:$off',
              when: when,
              title: title,
              body: body,
              category: NotifyCategory.birthday,
            ),
          );
        }
      }
    }
  }
  if (settings.holidaysOn) {
    for (final (h, d) in holidaysBetween(
      today,
      horizon.add(const Duration(days: 1)),
      country: settings.country,
      categories: settings.holidayCategories,
      disabled: settings.disabledHolidays,
    )) {
      final when = applyQuietHours(_at(d, settings.holidayMinutes), settings);
      if (!when.isAfter(now) || when.isAfter(horizon)) continue;
      out.add(
        PlannedNotification(
          key: 'hol:${h.id}:${d.year}',
          when: when,
          title: '${h.emoji} ${h.name}',
          body: h.approximate
              ? 'Today (the date can vary by a day where you are).'
              : 'Today is ${h.name}.',
          category: NotifyCategory.holiday,
        ),
      );
    }
  }
  return dedupeAndSort(out);
}

/// One per key, soonest first.
List<PlannedNotification> dedupeAndSort(List<PlannedNotification> items) {
  final seen = <String>{};
  final out = <PlannedNotification>[];
  for (final p in items..sort((a, b) => a.when.compareTo(b.when))) {
    if (seen.add(p.key)) out.add(p);
  }
  return out;
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
String _monthDay(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// Parses a stored birthday string, accepting "--MM-DD" as well.
DateTime? parseAnyBirthday(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  if (t.startsWith('--') && t.length == 7)
    return parseBirthday('0004${t.substring(1)}');
  return parseBirthday(t.length >= 10 ? t.substring(0, 10) : t);
}
