import 'package:prism_plurality/domain/models/tracker_record.dart';

/// Field keys inside a journal entry's `data`.
abstract final class JournalField {
  static const category = 'category';
  static const mood = 'mood';
  static const prompt = 'prompt';
  static const history = 'history';
  static const color = 'color';
}

/// A previous version of an entry, kept when its title or text changes.
class JournalRevision {
  const JournalRevision({required this.at, required this.title, this.body});

  final DateTime at;
  final String title;
  final String? body;

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'title': title,
    if (body != null) 'body': body,
  };

  static JournalRevision? fromJson(Object? v) {
    if (v is! Map) return null;
    final at = v['at'] is String ? DateTime.tryParse(v['at'] as String) : null;
    if (at == null) return null;
    return JournalRevision(
      at: at.toLocal(),
      title: v['title'] is String ? v['title'] as String : '',
      body: v['body'] is String ? v['body'] as String : null,
    );
  }
}

const journalHistoryLimit = 20;

List<JournalRevision> journalHistory(TrackerRecord entry) {
  final raw = entry.fields[JournalField.history];
  if (raw is! List) return const [];
  return [for (final v in raw) ?JournalRevision.fromJson(v)]
    ..sort((a, b) => b.at.compareTo(a.at));
}

/// Returns [edited] with the previous text of [original] pushed onto its
/// history when the title or body changed.
TrackerRecord withRevision(
  TrackerRecord original,
  TrackerRecord edited,
  DateTime now,
) {
  if (original.title == edited.title &&
      (original.body ?? '') == (edited.body ?? '')) {
    return edited;
  }
  final history = [
    JournalRevision(
      at: original.modifiedAt,
      title: original.title,
      body: original.body,
    ),
    ...journalHistory(original),
  ].take(journalHistoryLimit).map((r) => r.toJson()).toList();
  return edited.withFields({JournalField.history: history});
}

DateTime journalDay(TrackerRecord e) {
  final d = e.occurredAt ?? e.createdAt;
  return DateTime(d.year, d.month, d.day);
}

class JournalStats {
  const JournalStats({
    required this.total,
    required this.thisMonth,
    required this.currentStreak,
    required this.longestStreak,
    required this.averageMood30,
    required this.topTags,
    required this.words,
  });

  final int total;
  final int thisMonth;

  /// Consecutive days up to today (or yesterday) with at least one entry.
  final int currentStreak;
  final int longestStreak;
  final double? averageMood30;
  final List<(String, int)> topTags;
  final int words;

  static JournalStats of(List<TrackerRecord> entries, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final days = <DateTime>{for (final e in entries) journalDay(e)};
    var current = 0;
    var cursor = days.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    while (days.contains(cursor)) {
      current++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    final sorted = days.toList()..sort();
    var longest = 0, run = 0;
    DateTime? prev;
    for (final d in sorted) {
      run = prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d
          ? run + 1
          : 1;
      if (run > longest) longest = run;
      prev = d;
    }
    final moods = [
      for (final e in entries)
        if (journalDay(e).isAfter(today.subtract(const Duration(days: 30))))
          ?e.integer(JournalField.mood),
    ];
    final tagCounts = <String, int>{};
    var words = 0;
    for (final e in entries) {
      for (final t in e.tags) {
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
      final text = '${e.title} ${e.body ?? ''}'.trim();
      if (text.isNotEmpty) words += text.split(RegExp(r'\s+')).length;
    }
    final top = tagCounts.entries.toList()
      ..sort(
        (a, b) => b.value != a.value
            ? b.value.compareTo(a.value)
            : a.key.compareTo(b.key),
      );
    return JournalStats(
      total: entries.length,
      thisMonth: entries.where((e) {
        final d = journalDay(e);
        return d.year == now.year && d.month == now.month;
      }).length,
      currentStreak: current,
      longestStreak: longest,
      averageMood30: moods.isEmpty
          ? null
          : moods.reduce((a, b) => a + b) / moods.length,
      topTags: [for (final e in top.take(12)) (e.key, e.value)],
      words: words,
    );
  }
}

/// Case-insensitive match against title, body and tags.
bool journalMatches(TrackerRecord e, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (e.title.toLowerCase().contains(q)) return true;
  if ((e.body ?? '').toLowerCase().contains(q)) return true;
  return e.tags.any((t) => t.toLowerCase().contains(q.replaceFirst('#', '')));
}

/// Writing prompts offered in the editor.
const journalPromptKeys = <String>[
  'journalPrompt1',
  'journalPrompt2',
  'journalPrompt3',
  'journalPrompt4',
  'journalPrompt5',
  'journalPrompt6',
  'journalPrompt7',
  'journalPrompt8',
];
