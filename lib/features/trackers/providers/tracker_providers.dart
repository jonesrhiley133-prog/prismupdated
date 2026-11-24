import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/fronting_roles/roles_data.dart';

/// Every live tracker record.
final trackerRecordsProvider = StreamProvider<List<TrackerRecord>>(
  (ref) => ref.watch(trackerRecordRepositoryProvider).watchAll(),
);

/// Records of one [TrackerRecord.kind], newest [TrackerRecord.occurredAt]
/// (then [TrackerRecord.createdAt]) first.
final trackerKindProvider =
    Provider.family<AsyncValue<List<TrackerRecord>>, String>((ref, kind) {
      return ref.watch(trackerRecordsProvider).whenData((all) {
        final list = [
          for (final r in all)
            if (r.kind == kind) r,
        ];
        list.sort(compareRecordsNewestFirst);
        return list;
      });
    });

int compareRecordsNewestFirst(TrackerRecord a, TrackerRecord b) {
  final ad = a.occurredAt ?? a.createdAt;
  final bd = b.occurredAt ?? b.createdAt;
  final c = bd.compareTo(ad);
  return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
}

class TrackerNotifier extends Notifier<void> {
  static const _uuid = Uuid();

  @override
  void build() {}

  Future<TrackerRecord> create({
    required String kind,
    String title = '',
    String? body,
    String? parentId,
    Map<String, Object?> fields = const {},
    List<String> tags = const [],
    DateTime? occurredAt,
    DateTime? endedAt,
    int? amount,
    String? memberId,
    bool isPrivate = false,
    bool isPinned = false,
    int sortOrder = 0,
    DateTime? now,
  }) async {
    final t = now ?? DateTime.now();
    // Who was Primary when this was written, for attribution.
    if (!kind.startsWith('front.') && !fields.containsKey('recordedBy')) {
      String? by;
      try {
        by = ref.read(primaryFronterIdProvider);
      } catch (_) {}
      if (by != null) fields = {...fields, 'recordedBy': by};
    }
    final record = TrackerRecord(
      id: _uuid.v4(),
      kind: kind,
      parentId: parentId,
      title: title.trim(),
      body: _nullIfBlank(body),
      tags: normalizeTags(tags),
      occurredAt: occurredAt,
      endedAt: endedAt,
      amount: amount,
      memberId: memberId,
      isPrivate: isPrivate,
      isPinned: isPinned,
      sortOrder: sortOrder,
      createdAt: t,
      modifiedAt: t,
    ).withFields(fields);
    await ref.read(trackerRecordRepositoryProvider).create(record);
    return record;
  }

  Future<void> save(TrackerRecord record, {DateTime? now}) async {
    await ref
        .read(trackerRecordRepositoryProvider)
        .update(
          record.copyWith(
            title: record.title.trim(),
            body: _nullIfBlank(record.body),
            tags: normalizeTags(record.tags),
            modifiedAt: now ?? DateTime.now(),
          ),
        );
  }

  /// Deletes [id] and, when [children] is true, every record whose
  /// [TrackerRecord.parentId] chain leads to it.
  Future<void> delete(String id, {bool children = true}) async {
    final repo = ref.read(trackerRecordRepositoryProvider);
    if (children) {
      final all = await repo.getAll();
      final doomed = <String>{id};
      var grew = true;
      while (grew) {
        grew = false;
        for (final r in all) {
          if (r.parentId != null &&
              doomed.contains(r.parentId) &&
              doomed.add(r.id)) {
            grew = true;
          }
        }
      }
      for (final d in doomed) {
        await repo.delete(d);
      }
      await _dropLinksTo(all, doomed);
    } else {
      await repo.delete(id);
      await _dropLinksTo(await repo.getAll(), {id});
    }
  }

  /// Keeps record links consistent: links pointing at deleted records go too.
  Future<void> _dropLinksTo(List<TrackerRecord> all, Set<String> ids) async {
    final keys = {for (final id in ids) 'rec:$id'};
    final repo = ref.read(trackerRecordRepositoryProvider);
    for (final r in all) {
      if (r.kind != 'link.edge' || ids.contains(r.id)) continue;
      if (keys.contains(r.str('a')) || keys.contains(r.str('b'))) {
        await repo.delete(r.id);
      }
    }
  }

  static String? _nullIfBlank(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}

/// Trims, removes a leading `#`, drops empties and case-insensitive
/// duplicates, keeping the first spelling.
List<String> normalizeTags(Iterable<String> tags) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in tags) {
    var t = raw.trim();
    while (t.startsWith('#')) {
      t = t.substring(1).trim();
    }
    if (t.isEmpty || !seen.add(t.toLowerCase())) continue;
    out.add(t);
  }
  return out;
}

/// Splits user input like `"walk, #calm  self care"` on commas/newlines.
List<String> parseTagInput(String input) =>
    normalizeTags(input.split(RegExp(r'[,\n]')));

final trackerNotifierProvider = NotifierProvider<TrackerNotifier, void>(
  TrackerNotifier.new,
);
