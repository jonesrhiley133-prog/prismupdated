import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/mood/utils/mood_stats.dart';

MoodEntry _e(
  String id,
  DateTime at, {
  int mood = 3,
  String? member,
  List<String> emotions = const [],
  int? energy,
}) => MoodEntry(
  id: id,
  memberId: member,
  mood: mood,
  emotions: emotions,
  energy: energy,
  recordedAt: at,
  createdAt: at,
  modifiedAt: at,
);

void main() {
  final now = DateTime(2026, 3, 10, 20);

  test('summary averages, distribution and top emotions', () {
    final s = MoodSummary.of([
      _e(
        '1',
        DateTime(2026, 3, 10, 8),
        mood: 4,
        emotions: ['calm', 'happy'],
        energy: 4,
      ),
      _e(
        '2',
        DateTime(2026, 3, 10, 14),
        mood: 2,
        emotions: ['anxious', 'calm'],
      ),
      _e('3', DateTime(2026, 3, 9, 23), mood: 3, member: 'm1', energy: 2),
    ], now: now);
    expect(s.count, 3);
    expect(s.averageMood, 3);
    expect(s.averageEnergy, 3);
    expect(s.averageStress, isNull);
    expect(s.moodDistribution, {1: 0, 2: 1, 3: 1, 4: 1, 5: 0});
    expect(s.topEmotions.first.key, 'calm');
    expect(s.topEmotions.first.value, 2);
    expect(s.averageMoodByMember[null], 3);
    expect(s.averageMoodByMember['m1'], 3);
    expect(s.averageMoodByTimeOfDay['morning'], 4);
    expect(s.averageMoodByTimeOfDay['night'], 3);
    expect(s.daysLogged, 2);
  });

  test(
    'streak counts back from today, or from yesterday if today is empty',
    () {
      final entries = [
        _e('a', DateTime(2026, 3, 9, 9)),
        _e('b', DateTime(2026, 3, 8, 9)),
        _e('c', DateTime(2026, 3, 6, 9)),
      ];
      expect(MoodSummary.of(entries, now: now).currentStreak, 2);
      expect(
        MoodSummary.of([
          ...entries,
          _e('d', DateTime(2026, 3, 10, 7)),
        ], now: now).currentStreak,
        3,
      );
      expect(
        MoodSummary.of(entries, now: DateTime(2026, 3, 12)).currentStreak,
        0,
      );
    },
  );

  test('grouping by day is newest first and daily average is per day', () {
    final entries = [
      _e('1', DateTime(2026, 3, 8, 9), mood: 5),
      _e('2', DateTime(2026, 3, 10, 9), mood: 1),
      _e('3', DateTime(2026, 3, 10, 18), mood: 3),
    ];
    expect(groupMoodEntriesByDay(entries).keys.first, DateTime(2026, 3, 10));
    expect(dailyAverageMood(entries)[DateTime(2026, 3, 10)], 2);
    expect(moodEntriesInLastDays(entries, 2, now: now).map((e) => e.id), [
      '2',
      '3',
    ]);
  });
}
