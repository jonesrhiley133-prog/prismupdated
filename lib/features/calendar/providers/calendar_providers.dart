import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/features/calendar/utils/recurrence.dart';

/// All live calendar events (series, not expanded occurrences).
final calendarEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  return ref.watch(calendarRepositoryProvider).watchAll();
});

/// Which extra layers the calendar shows alongside events.
class CalendarOverlays {
  const CalendarOverlays({
    this.birthdays = true,
    this.mood = true,
    this.reminders = false,
    this.habits = true,
    this.companions = true,
  });

  /// Companion birthdays and adoption anniversaries.
  final bool companions;

  /// Scheduled habits in the day view.
  final bool habits;

  final bool birthdays;
  final bool mood;
  final bool reminders;

  CalendarOverlays copyWith({
    bool? birthdays,
    bool? mood,
    bool? reminders,
    bool? habits,
    bool? companions,
  }) => CalendarOverlays(
    companions: companions ?? this.companions,
    birthdays: birthdays ?? this.birthdays,
    mood: mood ?? this.mood,
    reminders: reminders ?? this.reminders,
    habits: habits ?? this.habits,
  );
}

class CalendarOverlaysNotifier extends Notifier<CalendarOverlays> {
  @override
  CalendarOverlays build() => const CalendarOverlays();

  void set(CalendarOverlays value) => state = value;
}

final calendarOverlaysProvider =
    NotifierProvider<CalendarOverlaysNotifier, CalendarOverlays>(
      CalendarOverlaysNotifier.new,
    );

/// Category filter: null shows everything.
class CalendarCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final calendarCategoryFilterProvider =
    NotifierProvider<CalendarCategoryFilterNotifier, String?>(
      CalendarCategoryFilterNotifier.new,
    );

/// Distinct categories in use, plus the built-in suggestions.
const defaultCalendarCategories = [
  'Appointment',
  'Therapy',
  'Medical',
  'Work',
  'School',
  'Social',
  'Self-care',
  'Birthday',
  'Holiday',
  'System',
];

final calendarCategoriesProvider = Provider<List<String>>((ref) {
  final events = ref.watch(calendarEventsProvider).value ?? const [];
  final used = events.map((e) => e.category).whereType<String>().toSet();
  return {...defaultCalendarCategories, ...used}.toList();
});

/// How editing or deleting one occurrence of a recurring event applies.
enum RecurringEditScope { thisOccurrence, thisAndFollowing, allOccurrences }

class CalendarNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  CalendarEvent newEvent({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final now = DateTime.now();
    return CalendarEvent(
      id: const Uuid().v4(),
      title: title,
      startAt: startAt,
      endAt: endAt,
      createdAt: now,
      modifiedAt: now,
    );
  }

  Future<void> create(CalendarEvent event) async {
    state = await AsyncValue.guard(
      () => ref.read(calendarRepositoryProvider).create(event),
    );
  }

  Future<void> save(CalendarEvent event) async {
    state = await AsyncValue.guard(
      () => ref
          .read(calendarRepositoryProvider)
          .update(event.copyWith(modifiedAt: DateTime.now())),
    );
  }

  Future<void> delete(String id) async {
    state = await AsyncValue.guard(
      () => ref.read(calendarRepositoryProvider).delete(id),
    );
  }

  /// Applies an edit made to [occurrence] of a recurring series.
  ///
  /// * [RecurringEditScope.thisOccurrence]: the occurrence is removed from
  ///   the series and [edited] is saved as a new one-off event.
  /// * [RecurringEditScope.thisAndFollowing]: the series is ended the day
  ///   before, and [edited] continues as a new series from this occurrence.
  /// * [RecurringEditScope.allOccurrences]: the series itself is updated.
  Future<void> saveOccurrence({
    required CalendarOccurrence occurrence,
    required CalendarEvent edited,
    required RecurringEditScope scope,
  }) async {
    final series = occurrence.event;
    final repo = ref.read(calendarRepositoryProvider);
    final now = DateTime.now();
    state = await AsyncValue.guard(() async {
      switch (scope) {
        case RecurringEditScope.allOccurrences:
          await repo.update(edited.copyWith(modifiedAt: now));
        case RecurringEditScope.thisOccurrence:
          await repo.update(
            series.copyWith(
              recurrenceExceptions: {
                ...series.recurrenceExceptions,
                occurrence.occurrenceKey,
              }.toList(),
              modifiedAt: now,
            ),
          );
          await repo.create(
            edited.copyWith(
              id: const Uuid().v4(),
              recurrence: CalendarRecurrence.none,
              recurrenceExceptions: const [],
              recurrenceUntil: null,
              recurrenceCount: null,
              createdAt: now,
              modifiedAt: now,
            ),
          );
        case RecurringEditScope.thisAndFollowing:
          await _endSeriesBefore(series, occurrence, now);
          await repo.create(
            edited.copyWith(
              id: const Uuid().v4(),
              recurrenceExceptions: const [],
              recurrenceCount: null,
              createdAt: now,
              modifiedAt: now,
            ),
          );
      }
    });
  }

  /// Deletes [occurrence] according to [scope].
  Future<void> deleteOccurrence(
    CalendarOccurrence occurrence,
    RecurringEditScope scope,
  ) async {
    final series = occurrence.event;
    final repo = ref.read(calendarRepositoryProvider);
    final now = DateTime.now();
    state = await AsyncValue.guard(() async {
      switch (scope) {
        case RecurringEditScope.allOccurrences:
          await repo.delete(series.id);
        case RecurringEditScope.thisOccurrence:
          await repo.update(
            series.copyWith(
              recurrenceExceptions: {
                ...series.recurrenceExceptions,
                occurrence.occurrenceKey,
              }.toList(),
              modifiedAt: now,
            ),
          );
        case RecurringEditScope.thisAndFollowing:
          await _endSeriesBefore(series, occurrence, now);
      }
    });
  }

  Future<void> _endSeriesBefore(
    CalendarEvent series,
    CalendarOccurrence occurrence,
    DateTime now,
  ) async {
    final repo = ref.read(calendarRepositoryProvider);
    final dayBefore = DateTime(
      occurrence.start.year,
      occurrence.start.month,
      occurrence.start.day - 1,
    );
    final seriesStartDay = DateTime(
      series.startAt.year,
      series.startAt.month,
      series.startAt.day,
    );
    if (dayBefore.isBefore(seriesStartDay)) {
      // Editing from the very first occurrence: the old series is replaced.
      await repo.delete(series.id);
    } else {
      await repo.update(
        series.copyWith(recurrenceUntil: dayBefore, modifiedAt: now),
      );
    }
  }
}

final calendarNotifierProvider = AsyncNotifierProvider<CalendarNotifier, void>(
  CalendarNotifier.new,
);
