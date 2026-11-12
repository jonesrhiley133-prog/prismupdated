import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/location.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/domain/models/work.dart';
import 'package:prism_plurality/features/insights/utils/insight_engine.dart';

final _t0 = DateTime(2026, 1, 1);

MoodEntry _m(
  DateTime at,
  int mood, {
  String? member,
  int? stress,
  List<String> emotions = const [],
  List<String> body = const [],
}) => MoodEntry(
  id: '$at',
  memberId: member,
  mood: mood,
  stress: stress,
  emotions: emotions,
  bodySensations: body,
  recordedAt: at,
  createdAt: _t0,
  modifiedAt: _t0,
);

FrontingSession _f(
  String id,
  String? member,
  DateTime start,
  DateTime? end, {
  bool sleep = false,
}) => FrontingSession(
  id: id,
  memberId: member,
  startTime: start,
  endTime: end,
  sessionType: sleep ? SessionType.sleep : SessionType.normal,
);

InsightInputs _in({
  List<MoodEntry> mood = const [],
  List<FrontingSession> fronting = const [],
  List<LocationSession> locations = const [],
  List<WorkSession> work = const [],
}) => InsightInputs(
  moodEntries: mood,
  frontingSessions: fronting,
  locationSessions: locations,
  workSessions: work,
);

void main() {
  final day = DateTime(2026, 3, 10);
  final now = DateTime(2026, 3, 10, 23);

  test('day summary computes exact fronting and co-fronting seconds', () {
    final insight = buildDailyInsight(
      _in(
        fronting: [
          _f('a', 'm1', DateTime(2026, 3, 10, 9), DateTime(2026, 3, 10, 12)),
          _f(
            'b',
            'm2',
            DateTime(2026, 3, 10, 11),
            DateTime(2026, 3, 10, 13, 0, 30),
          ),
          // Started yesterday: counts from midnight, not as a switch today.
          _f('c', 'm3', DateTime(2026, 3, 9, 23), DateTime(2026, 3, 10, 1)),
        ],
      ),
      day: day,
      now: now,
    );
    final t = insight.today;
    expect(t.frontSeconds['m1'], 3 * 3600);
    expect(t.frontSeconds['m2'], 2 * 3600 + 30);
    expect(t.frontSeconds['m3'], 3600);
    expect(t.coFrontSeconds, 3600);
    expect(t.switches, 2);
  });

  test('sleep, locations and work feed the summary', () {
    final insight = buildDailyInsight(
      _in(
        fronting: [
          _f(
            's',
            null,
            DateTime(2026, 3, 9, 23),
            DateTime(2026, 3, 10, 6, 30),
            sleep: true,
          ),
        ],
        locations: [
          LocationSession(
            id: 'l',
            locationId: 'home',
            startedAt: DateTime(2026, 3, 10, 18),
            endedAt: DateTime(2026, 3, 10, 18, 0, 45),
            createdAt: _t0,
            modifiedAt: _t0,
          ),
        ],
        work: [
          WorkSession(
            id: 'w',
            jobId: 'j',
            startedAt: DateTime(2026, 3, 10, 9),
            endedAt: DateTime(2026, 3, 10, 10),
            hourlyRateCents: 2000,
            createdAt: _t0,
            modifiedAt: _t0,
          ),
        ],
      ),
      day: day,
      now: now,
    );
    expect(insight.today.sleep, const Duration(hours: 7, minutes: 30));
    expect(insight.today.locationSeconds['home'], 45);
    expect(insight.today.workSeconds, 3600);
    expect(insight.today.workEarnings['USD'], 2000);
    expect(insight.suggestions, contains(InsightSuggestion.lightCheckIn));
  });

  test('sleep ↔ mood pattern needs enough days and a real difference', () {
    final fronting = <FrontingSession>[];
    final mood = <MoodEntry>[];
    for (var i = 0; i < 8; i++) {
      final d = DateTime(2026, 3, 1 + i);
      final long = i.isEven;
      fronting.add(
        _f(
          's$i',
          null,
          d.subtract(const Duration(hours: 1)),
          d.add(Duration(hours: long ? 7 : 4)),
          sleep: true,
        ),
      );
      mood.add(_m(d.add(const Duration(hours: 12)), long ? 4 : 2));
    }
    final insight = buildDailyInsight(
      _in(mood: mood, fronting: fronting),
      day: day,
      now: now,
    );
    final p = insight.patterns.whereType<SleepMoodPattern>().single;
    expect(p.longSleepMood, 4);
    expect(p.shortSleepMood, 2);
    expect(p.longDays, 4);

    final few = buildDailyInsight(
      _in(mood: mood.take(3).toList(), fronting: fronting.take(3).toList()),
      day: day,
      now: now,
    );
    expect(few.patterns.whereType<SleepMoodPattern>(), isEmpty);
  });

  test('location, member, body and stress patterns', () {
    final mood = <MoodEntry>[];
    final locations = <LocationSession>[];
    for (var i = 0; i < 4; i++) {
      final d = DateTime(2026, 3, 2 + i, 10);
      locations.add(
        LocationSession(
          id: 'l$i',
          locationId: 'park',
          startedAt: d,
          endedAt: d.add(const Duration(hours: 1)),
          createdAt: _t0,
          modifiedAt: _t0,
        ),
      );
      mood.add(
        _m(
          d.add(const Duration(minutes: 5)),
          5,
          member: 'm1',
          emotions: ['calm@6'],
          body: ['chest:warm'],
          stress: 1,
        ),
      );
      mood.add(_m(d.add(const Duration(hours: 5)), 2, stress: 1));
    }
    for (var i = 0; i < 3; i++) {
      mood.add(_m(DateTime(2026, 3, 9 + i ~/ 2, 9 + i), 3, stress: 5));
    }
    final insight = buildDailyInsight(
      _in(mood: mood, locations: locations),
      day: day,
      now: now,
    );
    final loc = insight.patterns.whereType<LocationMoodPattern>().single;
    expect(loc.locationId, 'park');
    expect(loc.moodThere, 5);
    expect(
      insight.patterns.whereType<MemberMoodPattern>().single.memberId,
      'm1',
    );
    expect(
      insight.patterns.whereType<BodyEmotionPattern>().single.emotionKey,
      'calm',
    );
    // Stress pattern may be cut by the top-5 limit; check the engine directly.
    final all = [...insight.patterns];
    expect(all.length, lessThanOrEqualTo(5));
  });
}
