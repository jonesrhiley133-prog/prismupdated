import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/journal/utils/journal_stats.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

TrackerRecord _e(
  DateTime at, {
  String title = 't',
  String? body,
  int? mood,
  List<String> tags = const [],
}) => TrackerRecord(
  id: '$at',
  kind: TrackerKind.journalEntry,
  title: title,
  body: body,
  tags: tags,
  occurredAt: at,
  createdAt: at,
  modifiedAt: at,
).withFields({JournalField.mood: mood});

void main() {
  test('streaks, month count, mood average, tags and words', () {
    final now = DateTime(2026, 11, 12, 20);
    final entries = [
      _e(
        DateTime(2026, 11, 12, 9),
        mood: 4,
        tags: ['calm'],
        body: 'one two three',
      ),
      _e(DateTime(2026, 11, 11, 9), mood: 2, tags: ['calm', 'work']),
      _e(DateTime(2026, 11, 10, 9)),
      _e(DateTime(2026, 10, 1, 9), tags: ['work']),
      _e(DateTime(2026, 10, 2, 9)),
      _e(DateTime(2026, 10, 3, 9)),
      _e(DateTime(2026, 10, 4, 9)),
    ];
    final s = JournalStats.of(entries, now);
    expect(s.total, 7);
    expect(s.thisMonth, 3);
    expect(s.currentStreak, 3);
    expect(s.longestStreak, 4);
    expect(s.averageMood30, 3);
    expect(s.topTags, [('calm', 2), ('work', 2)]);
    expect(s.words, 7 + 3);
    // A streak that ended yesterday still counts as current.
    expect(JournalStats.of(entries.skip(1).toList(), now).currentStreak, 2);
  });

  test('editing keeps previous versions, newest first, capped', () {
    final t0 = DateTime(2026);
    var e = _e(t0, title: 'v0', body: 'b0');
    for (var i = 1; i <= journalHistoryLimit + 3; i++) {
      final edited = e.copyWith(
        title: 'v$i',
        body: 'b$i',
        modifiedAt: t0.add(Duration(minutes: i)),
      );
      e = withRevision(e, edited, t0.add(Duration(minutes: i)));
    }
    final h = journalHistory(e);
    expect(h, hasLength(journalHistoryLimit));
    expect(h.first.title, 'v${journalHistoryLimit + 2}');
    // Changing only metadata adds no revision.
    expect(
      journalHistory(withRevision(e, e.copyWith(isPinned: true), t0)),
      hasLength(journalHistoryLimit),
    );
  });

  test('search matches title, body and tags; tag input is normalised', () {
    final e = _e(
      DateTime(2026),
      title: 'Walk',
      body: 'Leaves turning',
      tags: ['Self care'],
    );
    expect(journalMatches(e, 'leaves'), isTrue);
    expect(journalMatches(e, '#self'), isTrue);
    expect(journalMatches(e, 'zzz'), isFalse);
    expect(parseTagInput('#calm, Calm,  self care ,,#'), ['calm', 'self care']);
  });
}
