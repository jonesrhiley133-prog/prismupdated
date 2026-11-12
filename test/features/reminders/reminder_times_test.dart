import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/reminder.dart';
import 'package:prism_plurality/features/reminders/utils/reminder_times.dart';

Reminder _r({String? time, List<String>? extra}) => Reminder(
  id: 'r',
  name: 'n',
  message: 'm',
  timeOfDay: time,
  additionalTimes: extra,
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
);

void main() {
  test('allTimesOfDay merges, normalizes, dedupes and sorts', () {
    expect(
      _r(
        time: '21:00',
        extra: ['8:5', '13:30', '21:00', 'bad', '25:00'],
      ).allTimesOfDay,
      ['08:05', '13:30', '21:00'],
    );
  });

  test('allTimesOfDay falls back to 09:00 and caps at maxTimesPerDay', () {
    expect(_r().allTimesOfDay, ['09:00']);
    final many = [
      for (var h = 0; h < 20; h++) '${h.toString().padLeft(2, '0')}:00',
    ];
    expect(_r(extra: many).allTimesOfDay, hasLength(Reminder.maxTimesPerDay));
  });

  test('evenlySpacedTimes fills the window inclusively', () {
    final times = evenlySpacedTimes(
      start: const TimeOfDay(hour: 8, minute: 0),
      end: const TimeOfDay(hour: 20, minute: 0),
      everyMinutes: 240,
    );
    expect(times.map(formatReminderTime), ['08:00', '12:00', '16:00', '20:00']);
  });

  test('evenlySpacedTimes returns just the start for an inverted window', () {
    final times = evenlySpacedTimes(
      start: const TimeOfDay(hour: 20, minute: 0),
      end: const TimeOfDay(hour: 8, minute: 0),
      everyMinutes: 60,
    );
    expect(times.map(formatReminderTime), ['20:00']);
  });

  test('evenlySpacedTimes is capped', () {
    final times = evenlySpacedTimes(
      start: const TimeOfDay(hour: 0, minute: 0),
      end: const TimeOfDay(hour: 23, minute: 59),
      everyMinutes: 30,
    );
    expect(times, hasLength(Reminder.maxTimesPerDay));
  });
}
