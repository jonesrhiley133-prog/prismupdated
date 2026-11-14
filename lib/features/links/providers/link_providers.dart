import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/habit.dart';
import 'package:prism_plurality/features/habits/providers/habit_providers.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

/// Recent fronting and sleep sessions offered for linking.
final linkableSessionsProvider = StreamProvider<List<FrontingSession>>(
  (ref) => ref
      .watch(frontingSessionRepositoryProvider)
      .watchRecentAllSessions(limit: 400),
);

/// Every record that can be linked, keyed by [RecordRef.key].
final recordCatalogProvider = Provider<Map<String, RecordInfo>>((ref) {
  final out = <String, RecordInfo>{};
  final members = ref.watch(allMembersProvider).value ?? const <Member>[];
  final preferDisplay = ref.watch(memberNamePreferDisplayProvider);
  final names = <String, String>{};
  for (final m in members) {
    final name = m.effectiveName(preferDisplayName: preferDisplay);
    names[m.id] = name;
    final r = RecordRef(RecordRef.member, m.id);
    out[r.key] = RecordInfo(
      ref: r,
      module: 'member',
      title: m.emoji.trim().isEmpty || m.emoji == '❔' ? name : '${m.emoji} $name',
      subtitle: m.pronouns,
      date: m.createdAt,
    );
  }
  for (final s in ref.watch(linkableSessionsProvider).value ?? const <FrontingSession>[]) {
    final r = RecordRef(RecordRef.front, s.id);
    final sleep = s.sessionType == SessionType.sleep;
    out[r.key] = RecordInfo(
      ref: r,
      module: sleep ? 'sleep' : 'front',
      title: sleep ? 'Sleep' : (names[s.memberId] ?? 'Front'),
      subtitle: s.notes,
      date: s.startTime,
      memberId: s.memberId,
    );
  }
  for (final m in ref.watch(moodEntriesProvider).value ?? const []) {
    final r = RecordRef(RecordRef.mood, m.id);
    out[r.key] = RecordInfo(
      ref: r,
      module: 'mood',
      title: '${['😞', '🙁', '😐', '🙂', '😄'][(m.mood - 1).clamp(0, 4)]} ${m.emotions.take(3).join(', ')}'.trim(),
      subtitle: m.note,
      date: m.recordedAt,
      memberId: m.memberId,
    );
  }
  for (final l in ref.watch(savedLocationsProvider).value ?? const []) {
    final r = RecordRef(RecordRef.location, l.id);
    out[r.key] = RecordInfo(
      ref: r,
      module: 'location',
      title: '${l.emoji ?? ''} ${l.name}'.trim(),
      subtitle: l.address,
    );
  }
  for (final e in ref.watch(calendarEventsProvider).value ?? const []) {
    final r = RecordRef(RecordRef.event, e.id);
    out[r.key] = RecordInfo(
      ref: r,
      module: 'event',
      title: e.title,
      subtitle: e.location,
      date: e.startAt,
    );
  }
  final habitNames = <String, String>{};
  for (final h in ref.watch(habitsProvider).value ?? const <Habit>[]) {
    habitNames[h.id] = h.name;
    final r = RecordRef(RecordRef.habit, h.id);
    out[r.key] = RecordInfo(ref: r, module: 'habit', title: '${h.icon ?? ''} ${h.name}'.trim(), subtitle: h.description, date: h.createdAt, isPrivate: h.isPrivate);
  }
  final completions = [...?ref.watch(allCompletionsProvider).value]..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  for (final c in completions.take(600)) {
    final r = RecordRef(RecordRef.habitLog, c.id);
    out[r.key] = RecordInfo(
      ref: r,
      module: 'habit',
      title: '✓ ${habitNames[c.habitId] ?? 'Habit'}',
      subtitle: c.notes,
      date: c.completedAt,
      memberId: c.completedByMemberId,
    );
  }
  for (final t in ref.watch(trackerRecordsProvider).value ?? const <TrackerRecord>[]) {
    final module = moduleForKind(t.kind);
    if (module == null) continue;
    final r = RecordRef(RecordRef.rec, t.id);
    out[r.key] = RecordInfo(
      ref: r,
      module: module,
      title: t.title.isEmpty ? _fallbackTitle(t) : t.title,
      subtitle: t.isPrivate ? null : t.body,
      date: t.occurredAt ?? t.createdAt,
      kind: t.kind,
      isPrivate: t.isPrivate,
      memberId: t.memberId,
    );
  }
  return out;
});

String _fallbackTitle(TrackerRecord t) {
  final d = t.occurredAt ?? t.createdAt;
  return '${TrackerKind.section(t.kind)} ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// A stored link between two records.
class RecordLink {
  const RecordLink({
    required this.id,
    required this.a,
    required this.b,
    required this.category,
    this.note,
    required this.record,
  });

  final String id;
  final RecordRef a;
  final RecordRef b;
  final String category;
  final String? note;
  final TrackerRecord record;

  RecordRef other(RecordRef self) => a == self ? b : a;

  static RecordLink? from(TrackerRecord r) {
    final a = RecordRef.parse(r.str('a'));
    final b = RecordRef.parse(r.str('b'));
    if (a == null || b == null) return null;
    return RecordLink(
      id: r.id,
      a: a,
      b: b,
      category: r.str('cat') ?? 'related',
      note: r.body,
      record: r,
    );
  }
}

final recordLinksProvider = Provider<List<RecordLink>>((ref) {
  final rows = ref.watch(trackerKindProvider(TrackerKind.linkEdge)).value ?? const [];
  return [for (final r in rows) ?RecordLink.from(r)];
});

/// Custom categories (records) plus the built-in ones.
class LinkCategory {
  const LinkCategory(this.id, this.label, this.color, {this.record});
  final String id;
  final String label;
  final int color;
  final TrackerRecord? record;
}

final linkCategoriesProvider = Provider.family<List<LinkCategory>, String>((ref, lang) {
  final custom = ref.watch(trackerKindProvider(TrackerKind.linkCategory)).value ?? const [];
  return [
    for (final c in builtInLinkCategories)
      LinkCategory(c.id, lang == 'es' ? c.es : c.en, c.color),
    for (final c in custom)
      LinkCategory(c.id, c.title, c.integer('color') ?? 0xFF8C8C8C, record: c),
  ];
});

/// Links touching [key] whose other end still exists.
final linksForRecordProvider =
    Provider.family<List<(RecordLink, RecordInfo)>, String>((ref, key) {
      final self = RecordRef.parse(key);
      if (self == null) return const [];
      final mine = [for (final l in ref.watch(recordLinksProvider)) if (l.a == self || l.b == self) l];
      // Only build the full catalogue when there is something to show.
      if (mine.isEmpty) return const [];
      final catalog = ref.watch(recordCatalogProvider);
      final out = <(RecordLink, RecordInfo)>[];
      for (final l in mine) {
        final info = catalog[l.other(self).key];
        if (info != null) out.add((l, info));
      }
      out.sort((x, y) => (y.$2.date ?? DateTime(0)).compareTo(x.$2.date ?? DateTime(0)));
      return out;
    });

class LinkActions {
  LinkActions(this.ref);
  final Ref ref;

  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  /// Links [a] and [b]; returns false if that exact link already exists.
  Future<bool> link(RecordRef a, RecordRef b, {String category = 'related', String? note}) async {
    if (a == b) return false;
    for (final l in ref.read(recordLinksProvider)) {
      final same = (l.a == a && l.b == b) || (l.a == b && l.b == a);
      if (same && l.category == category) return false;
    }
    await _t.create(
      kind: TrackerKind.linkEdge,
      body: note,
      fields: {'a': a.key, 'b': b.key, 'cat': category},
      occurredAt: DateTime.now(),
    );
    return true;
  }

  Future<void> unlink(String linkId) => _t.delete(linkId, children: false);

  Future<void> update(RecordLink l, {String? category, String? note}) => _t.save(
    l.record
        .copyWith(body: note ?? l.note)
        .withFields({'cat': category ?? l.category}),
  );

  Future<TrackerRecord> addCategory(String name, int color) => _t.create(
    kind: TrackerKind.linkCategory,
    title: name,
    fields: {'color': color},
  );

  /// Removes links whose ends no longer exist. Only types whose full list is
  /// loaded are judged; fronting sessions outside the recent window are
  /// looked up individually so old links are never dropped by mistake.
  Future<int> removeBroken() async {
    final catalog = ref.read(recordCatalogProvider);
    final repo = ref.read(frontingSessionRepositoryProvider);
    final allTracker = {
      for (final r in await ref.read(trackerRecordRepositoryProvider).getAll()) r.id,
    };
    var removed = 0;
    Future<bool> exists(RecordRef r) async {
      if (catalog.containsKey(r.key)) return true;
      return switch (r.type) {
        RecordRef.front => (await repo.getSessionById(r.id)) != null,
        RecordRef.habitLog => (await ref.read(habitRepositoryProvider).getCompletionById(r.id)) != null,
        RecordRef.habit => (await ref.read(habitRepositoryProvider).getHabitById(r.id)) != null,
        RecordRef.rec => allTracker.contains(r.id),
        _ => false,
      };
    }

    final loaded = ref.read(allMembersProvider).hasValue &&
        ref.read(moodEntriesProvider).hasValue &&
        ref.read(savedLocationsProvider).hasValue &&
        ref.read(calendarEventsProvider).hasValue &&
        ref.read(habitsProvider).hasValue;
    if (!loaded) return 0;
    for (final l in ref.read(recordLinksProvider)) {
      if (!await exists(l.a) || !await exists(l.b)) {
        await unlink(l.id);
        removed++;
      }
    }
    return removed;
  }
}

final linkActionsProvider = Provider<LinkActions>(LinkActions.new);
