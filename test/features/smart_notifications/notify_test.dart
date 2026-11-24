import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/features/smart_notifications/holidays.dart';
import 'package:prism_plurality/features/smart_notifications/notify_data.dart';

void main() {
  test('holiday rules compute known dates', () {
    expect(easterSunday(2026), DateTime(2026, 4, 5));
    expect(easterSunday(2027), DateTime(2027, 3, 28));
    expect(
      nthWeekday(2026, 11, DateTime.thursday, 4),
      DateTime(2026, 11, 26),
    ); // US Thanksgiving
    expect(
      nthWeekday(2026, 5, DateTime.monday, -1),
      DateTime(2026, 5, 25),
    ); // Memorial Day
    expect(
      nthWeekday(2026, 10, DateTime.monday, 2),
      DateTime(2026, 10, 12),
    ); // CA Thanksgiving
  });

  test('holidays respect country and category', () {
    final us = holidaysBetween(
      DateTime(2026, 11, 1),
      DateTime(2026, 12, 1),
      country: 'US',
      categories: {HolidayCategory.public},
    );
    expect(
      us.map((e) => e.$1.id),
      containsAll(['veterans', 'us_thanksgiving']),
    );
    expect(us.map((e) => e.$1.id), isNot(contains('remembrance')));
    final gb = holidaysBetween(
      DateTime(2026, 11, 1),
      DateTime(2026, 12, 1),
      country: 'GB',
      categories: {HolidayCategory.public},
      disabled: {'remembrance'},
    );
    expect(gb, isEmpty);
  });

  test('quiet hours push reminders to the end of the window', () {
    const s = NotifySettings(
      quietOn: true,
      quietStart: 22 * 60,
      quietEnd: 7 * 60,
    );
    expect(
      applyQuietHours(DateTime(2026, 1, 1, 23, 30), s),
      DateTime(2026, 1, 2, 7),
    );
    expect(
      applyQuietHours(DateTime(2026, 1, 1, 5), s),
      DateTime(2026, 1, 1, 7),
    );
    expect(
      applyQuietHours(DateTime(2026, 1, 1, 12), s),
      DateTime(2026, 1, 1, 12),
    );
  });

  test('birthday reminders: offsets, ages, de-duplication', () {
    const s = NotifySettings(birthdayOffsets: {0, 1}, birthdayMinutes: 9 * 60);
    final plan = planCalendarNotifications(
      settings: s,
      now: DateTime(2026, 3, 1, 8),
      birthdays: [
        BirthdayItem(
          'm:a',
          'Ash',
          DateTime.utc(2000, 3, 5),
          BirthdaySource.alters,
        ),
        BirthdayItem(
          'm:a',
          'Ash',
          DateTime.utc(2000, 3, 5),
          BirthdaySource.alters,
        ),
        BirthdayItem(
          'c:b',
          'Bea',
          DateTime.utc(4, 3, 2),
          BirthdaySource.contacts,
        ),
      ],
    );
    expect(plan.map((p) => p.key), [
      'bday:c:b:2026:1',
      'bday:c:b:2026:0',
      'bday:m:a:2026:1',
      'bday:m:a:2026:0',
    ]);
    expect(plan.last.body, contains('turns 26'));
    expect(plan[1].body, isNot(contains('turns')));
    final noContacts = planCalendarNotifications(
      settings: s.copyWith(birthdaySources: {BirthdaySource.alters}),
      now: DateTime(2026, 3, 1, 8),
      birthdays: [
        BirthdayItem(
          'c:b',
          'Bea',
          DateTime.utc(4, 3, 2),
          BirthdaySource.contacts,
        ),
      ],
    );
    expect(noContacts, isEmpty);
  });

  test('settings round-trip', () {
    const s = NotifySettings(
      holidaysOn: true,
      country: 'CA',
      birthdayOffsets: {3, 0},
      quietOn: true,
      disabledHolidays: {'halloween'},
    );
    final back = NotifySettings.of(null).copyWith();
    expect(back.birthdaysOn, isTrue);
    final f = s.toFields();
    expect(f['country'], 'CA');
    expect(f['birthdayOffsets'], [0, 3]);
  });
}
