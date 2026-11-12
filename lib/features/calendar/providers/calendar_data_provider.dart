import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/calendar/utils/calendar_data.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/reminders/providers/reminders_providers.dart';

/// Combined calendar data, or null while events are still loading.
final calendarDataProvider = Provider<CalendarData?>((ref) {
  final events = ref.watch(calendarEventsProvider).value;
  if (events == null) return null;
  final overlays = ref.watch(calendarOverlaysProvider);
  return CalendarData(
    events: events,
    members: overlays.birthdays
        ? (ref.watch(userVisibleMemberListProvider).value ?? const [])
        : const [],
    moodEntries: overlays.mood
        ? (ref.watch(moodEntriesProvider).value ?? const [])
        : const [],
    reminders: overlays.reminders
        ? (ref.watch(remindersProvider).value ?? const [])
        : const [],
    overlays: overlays,
    categoryFilter: ref.watch(calendarCategoryFilterProvider),
  );
});
