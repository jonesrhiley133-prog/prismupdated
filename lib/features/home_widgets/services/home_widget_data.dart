import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/domain/models/cycle_entry.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/location.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/domain/models/note.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/achievements/providers/achievement_providers.dart';
import 'package:prism_plurality/features/achievements/utils/achievements.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_data_provider.dart';
import 'package:prism_plurality/features/calendar/utils/calendar_data.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/cycle/providers/cycle_providers.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';
import 'package:prism_plurality/features/finance/providers/finance_providers.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/fronting/providers/sleep_providers.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_settings_store.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/providers/notes_providers.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';

/// Everything widgets can show, gathered from Prism's live data.
@immutable
class HomeWidgetData {
  const HomeWidgetData({
    required this.now,
    required this.members,
    required this.activeSessions,
    required this.recentSessions,
    required this.sleepSessions,
    this.activeSleep,
    required this.moods,
    required this.cycleEntries,
    required this.cycleStats,
    required this.places,
    this.activePlaceId,
    required this.records,
    required this.notes,
    required this.contacts,
    this.calendar,
    required this.achievements,
    required this.currency,
    required this.customStatus,
  });

  final DateTime now;
  final Map<String, Member> members;
  final List<FrontingSession> activeSessions;
  final List<FrontingSession> recentSessions;
  final List<FrontingSession> sleepSessions;
  final FrontingSession? activeSleep;
  final List<MoodEntry> moods;
  final List<CycleEntry> cycleEntries;
  final CycleStats cycleStats;
  final List<SavedLocation> places;
  final String? activePlaceId;
  final List<TrackerRecord> records;
  final List<Note> notes;
  final List<Contact> contacts;
  final CalendarData? calendar;
  final List<AchievementProgress> achievements;
  final String currency;
  final String customStatus;

  List<TrackerRecord> kind(String k) => [
    for (final r in records)
      if (r.kind == k) r,
  ];
}

/// Fronting in the last 30 days (for recent fronters and statistics).
final _recentSessionsProvider = StreamProvider<List<FrontingSession>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(frontingSessionRepositoryProvider)
      .watchSessionsOverlappingRange(
        now.subtract(const Duration(days: 30)),
        now.add(const Duration(days: 1)),
      );
});

final _recentSleepProvider = StreamProvider<List<FrontingSession>>(
  (ref) => ref
      .watch(frontingSessionRepositoryProvider)
      .watchRecentSleepSessions(limit: 10),
);

/// Recomputed whenever any source stream changes; null until the core
/// data has loaded.
final homeWidgetDataProvider = Provider<HomeWidgetData?>((ref) {
  final members = ref.watch(allMembersProvider);
  final active = ref.watch(activeSessionsProvider);
  if (!members.hasValue || !active.hasValue) return null;
  final loc = ref.watch(activeLocationSessionProvider);
  return HomeWidgetData(
    now: DateTime.now(),
    members: {for (final m in members.value!) m.id: m},
    activeSessions: [
      for (final s in active.value!)
        if (s.sessionType != SessionType.sleep) s,
    ],
    recentSessions: ref.watch(_recentSessionsProvider).value ?? const [],
    sleepSessions: ref.watch(_recentSleepProvider).value ?? const [],
    activeSleep: ref.watch(activeSleepSessionProvider).value,
    moods: ref.watch(moodEntriesProvider).value ?? const [],
    cycleEntries: ref.watch(cycleEntriesProvider).value ?? const [],
    cycleStats: ref.watch(cycleStatsProvider),
    places: ref.watch(savedLocationsProvider).value ?? const [],
    activePlaceId: loc?.locationId,
    records: ref.watch(trackerRecordsProvider).value ?? const [],
    notes: ref.watch(allNotesProvider).value ?? const [],
    contacts: ref.watch(contactsProvider).value ?? const [],
    calendar: ref.watch(calendarDataProvider),
    achievements: ref.watch(achievementProgressProvider).value ?? const [],
    currency: ref.watch(financeCurrencyProvider).value ?? 'USD',
    customStatus:
        ref.watch(frontingNotificationSettingsProvider).value?.customStatus ??
        '',
  );
});
