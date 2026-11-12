import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/cycle_entry.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';

final cycleEntriesProvider = StreamProvider<List<CycleEntry>>((ref) {
  return ref.watch(cycleEntryRepositoryProvider).watchAll();
});

/// Date key → entry (latest edit wins if two devices logged the same day).
final cycleEntriesByDateProvider = Provider<Map<String, CycleEntry>>((ref) {
  final entries = [...?ref.watch(cycleEntriesProvider).value]
    ..sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
  return {for (final e in entries) e.date: e};
});

final cycleStatsProvider = Provider<CycleStats>((ref) {
  return CycleStats.of(
    ref.watch(cycleEntriesByDateProvider).values,
    today: DateTime.now(),
  );
});

class CycleNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Saves the log for [day], creating or updating its entry. Clearing
  /// everything (no flow, symptoms or note) deletes the entry.
  Future<void> saveDay(
    DateTime day, {
    required int flow,
    required List<String> symptoms,
    String? note,
    String? memberId,
  }) async {
    final repo = ref.read(cycleEntryRepositoryProvider);
    final key = CycleStats.dateKey(day);
    final existing = ref.read(cycleEntriesByDateProvider)[key];
    final trimmed = note?.trim();
    final empty = flow == 0 && symptoms.isEmpty && (trimmed?.isEmpty ?? true);
    final now = DateTime.now();
    state = await AsyncValue.guard(() async {
      if (existing != null && empty) {
        await repo.delete(existing.id);
      } else if (existing != null) {
        await repo.update(
          existing.copyWith(
            flow: flow.clamp(0, 4),
            symptoms: symptoms,
            note: (trimmed?.isEmpty ?? true) ? null : trimmed,
            memberId: memberId ?? existing.memberId,
            modifiedAt: now,
          ),
        );
      } else if (!empty) {
        await repo.create(
          CycleEntry(
            id: const Uuid().v4(),
            date: key,
            flow: flow.clamp(0, 4),
            symptoms: symptoms,
            note: (trimmed?.isEmpty ?? true) ? null : trimmed,
            memberId: memberId,
            createdAt: now,
            modifiedAt: now,
          ),
        );
      }
    });
  }
}

final cycleNotifierProvider = AsyncNotifierProvider<CycleNotifier, void>(
  CycleNotifier.new,
);
