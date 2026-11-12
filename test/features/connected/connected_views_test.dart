import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/domain/models/cycle_entry.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/location.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/domain/models/note.dart';
import 'package:prism_plurality/domain/models/work.dart';
import 'package:prism_plurality/features/connected/utils/pattern_explorer.dart';
import 'package:prism_plurality/features/connected/utils/system_timeline.dart';

final _t0 = DateTime(2026);

MoodEntry _m(
  DateTime at,
  int mood, {
  List<String> emotions = const [],
  List<String> body = const [],
}) => MoodEntry(
  id: '$at',
  mood: mood,
  emotions: emotions,
  bodySensations: body,
  recordedAt: at,
  createdAt: _t0,
  modifiedAt: _t0,
);

void main() {
  final day = DateTime(2026, 3, 10);
  final now = DateTime(2026, 3, 10, 22);

  test('system timeline merges every tracker, newest first', () {
    final items = buildSystemTimeline(
      day: day,
      now: now,
      fronting: [
        FrontingSession(
          id: 'f',
          memberId: 'm1',
          startTime: DateTime(2026, 3, 10, 9),
          endTime: DateTime(2026, 3, 10, 12),
        ),
        FrontingSession(
          id: 's',
          startTime: DateTime(2026, 3, 9, 23),
          endTime: DateTime(2026, 3, 10, 7),
          sessionType: SessionType.sleep,
        ),
      ],
      moods: [_m(DateTime(2026, 3, 10, 10), 4)],
      locations: [
        LocationSession(
          id: 'l',
          locationId: 'park',
          startedAt: DateTime(2026, 3, 10, 13),
          endedAt: DateTime(2026, 3, 10, 14),
          createdAt: _t0,
          modifiedAt: _t0,
        ),
      ],
      work: [
        WorkSession(
          id: 'w',
          jobId: 'j',
          startedAt: DateTime(2026, 3, 10, 15),
          createdAt: _t0,
          modifiedAt: _t0,
        ),
      ],
      events: [
        CalendarEvent(
          id: 'e',
          title: 'Therapy',
          startAt: DateTime(2026, 3, 10, 16),
          endAt: DateTime(2026, 3, 10, 17),
          createdAt: _t0,
          modifiedAt: _t0,
        ),
      ],
      notes: [
        Note(
          id: 'n',
          title: 'Journal',
          body: 'b',
          date: DateTime(2026, 3, 10, 21),
          createdAt: _t0,
          modifiedAt: _t0,
        ),
      ],
      cycle: [
        CycleEntry(
          id: 'c',
          date: '2026-03-10',
          flow: 2,
          createdAt: _t0,
          modifiedAt: _t0,
        ),
      ],
    );
    expect(items.first.kind, TimelineKind.journal);
    expect(items.map((i) => i.kind).toSet(), TimelineKind.values.toSet());
    // Sleep shows only its end (woke up) on this day; fronting shows both.
    expect(
      items.where((i) => i.kind == TimelineKind.sleep).single.isStart,
      isFalse,
    );
    expect(items.where((i) => i.kind == TimelineKind.front), hasLength(2));
    final i = items.indexWhere((x) => x.kind == TimelineKind.event);
    expect(items[i].event!.event.title, 'Therapy');
  });

  test('pattern explorer groups mood by sleep, fronter, location and body', () {
    final moods = <MoodEntry>[
      _m(
        DateTime(2026, 3, 8, 12),
        5,
        emotions: ['calm@4'],
        body: ['chest:warm'],
      ),
      _m(
        DateTime(2026, 3, 9, 12),
        2,
        emotions: ['anxious'],
        body: ['chest:tight', 'stomach'],
      ),
      _m(DateTime(2026, 3, 10, 12), 3),
    ];
    final input = PatternExplorerInputs(
      moods: moods,
      fronting: [
        FrontingSession(
          id: 's1',
          startTime: DateTime(2026, 3, 7, 23),
          endTime: DateTime(2026, 3, 8, 8),
          sessionType: SessionType.sleep,
        ),
        FrontingSession(
          id: 's2',
          startTime: DateTime(2026, 3, 9, 2),
          endTime: DateTime(2026, 3, 9, 6),
          sessionType: SessionType.sleep,
        ),
        FrontingSession(
          id: 'f1',
          memberId: 'm1',
          startTime: DateTime(2026, 3, 8, 11),
          endTime: DateTime(2026, 3, 9, 13),
        ),
        FrontingSession(
          id: 'f2',
          memberId: 'm2',
          startTime: DateTime(2026, 3, 9, 11),
          endTime: DateTime(2026, 3, 9, 13),
        ),
      ],
      locations: [
        LocationSession(
          id: 'l',
          locationId: 'home',
          startedAt: DateTime(2026, 3, 8, 11),
          endedAt: DateTime(2026, 3, 8, 13),
          createdAt: _t0,
          modifiedAt: _t0,
        ),
      ],
      work: const [],
      cycle: const [],
    );
    List<PatternGroup> run(PatternComparison c) => explorePattern(
      c,
      input,
      from: DateTime(2026, 3, 1),
      to: DateTime(2026, 3, 11),
      now: now,
    );

    final sleep = {
      for (final g in run(PatternComparison.emotionSleep)) g.key: g,
    };
    expect(sleep['sleep_8plus']!.averageMood, 5);
    expect(sleep['sleep_lt6']!.averageMood, 2);
    expect(sleep['sleep_unknown']!.checkIns, 1);

    final front = {
      for (final g in run(PatternComparison.emotionFronting)) g.key: g,
    };
    expect(front['member:m1']!.checkIns, 2);
    expect(front['front_cofront']!.averageMood, 2);
    expect(front['front_none']!.checkIns, 1);

    final loc = {
      for (final g in run(PatternComparison.emotionLocation)) g.key: g,
    };
    expect(loc['location:home']!.averageMood, 5);
    expect(loc['location_none']!.checkIns, 2);

    final body = {for (final g in run(PatternComparison.bodyEmotion)) g.key: g};
    expect(body['body:chest']!.checkIns, 2);
    expect(
      body['body:chest']!.topEmotions.map((e) => e.$1),
      containsAll(['calm', 'anxious']),
    );
    expect(body['body:stomach']!.averageMood, 2);
  });
}
