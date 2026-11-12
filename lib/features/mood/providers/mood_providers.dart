import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';

/// All live mood check-ins, newest first.
final moodEntriesProvider = StreamProvider<List<MoodEntry>>((ref) {
  return ref.watch(moodRepositoryProvider).watchAll();
});

/// CRUD for mood check-ins.
class MoodNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<MoodEntry?> create({
    required int mood,
    required int intensity,
    String? memberId,
    List<String> emotions = const [],
    int? energy,
    int? stress,
    int? sleepQuality,
    List<String> bodySensations = const [],
    String? note,
    DateTime? recordedAt,
  }) async {
    final now = DateTime.now();
    final entry = MoodEntry(
      id: const Uuid().v4(),
      memberId: memberId,
      mood: mood,
      intensity: intensity,
      emotions: emotions,
      energy: energy,
      stress: stress,
      sleepQuality: sleepQuality,
      bodySensations: bodySensations,
      note: note,
      recordedAt: recordedAt ?? now,
      createdAt: now,
      modifiedAt: now,
    );
    state = await AsyncValue.guard(
      () => ref.read(moodRepositoryProvider).create(entry),
    );
    return state.hasError ? null : entry;
  }

  Future<void> save(MoodEntry entry) async {
    state = await AsyncValue.guard(
      () => ref
          .read(moodRepositoryProvider)
          .update(entry.copyWith(modifiedAt: DateTime.now())),
    );
  }

  Future<void> delete(String id) async {
    state = await AsyncValue.guard(
      () => ref.read(moodRepositoryProvider).delete(id),
    );
  }
}

final moodNotifierProvider = AsyncNotifierProvider<MoodNotifier, void>(
  MoodNotifier.new,
);
