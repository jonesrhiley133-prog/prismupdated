import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/calendar/utils/calendar_data.dart';
import 'package:prism_plurality/features/smart_notifications/notify_data.dart';

void main() {
  test('companion reminders are off by default and worded for adoption days', () {
    expect(const NotifySettings().birthdaySources.contains(BirthdaySource.companions), isFalse);
    final items = [
      BirthdayItem('ca:1', 'Pip', DateTime(2024, 12, 1), BirthdaySource.companions, adoption: true),
      BirthdayItem('cb:1', 'Pip', DateTime(2023, 12, 3), BirthdaySource.companions),
    ];
    final now = DateTime(2026, 11, 25, 12);
    expect(planCalendarNotifications(settings: const NotifySettings(), birthdays: items, now: now), isEmpty);
    final on = planCalendarNotifications(settings: const NotifySettings(birthdaySources: {BirthdaySource.companions}), birthdays: items, now: now);
    expect(on.map((n) => n.title), containsAll(['🐾 Happy adoption day, Pip!', '🎂 Happy birthday, Pip!']));
    expect(on.firstWhere((n) => n.title.startsWith('🐾')).body, '2 years together today.');
  });

  test('companion days show on the calendar', () {
    final data = CalendarData(
      events: const [],
      members: const [],
      companions: [('Pip', '2023-12-03', DateTime(2024, 12, 1))],
      moodEntries: const [],
      reminders: const [],
      overlays: const CalendarOverlays(),
    );
    final adoption = data.birthdaysOn(DateTime(2026, 12, 1));
    expect(adoption.single.adoption, isTrue);
    expect(adoption.single.age, 2);
    expect(data.birthdaysOn(DateTime(2026, 12, 3)).single.companion, 'Pip');
    final hidden = CalendarData(events: const [], members: const [], companions: [('Pip', null, DateTime(2024, 12, 1))], moodEntries: const [], reminders: const [], overlays: const CalendarOverlays(companions: false));
    expect(hidden.birthdaysOn(DateTime(2026, 12, 1)), isEmpty);
  });
}
