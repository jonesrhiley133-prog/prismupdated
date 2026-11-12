import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/work.dart';

final jobsProvider = StreamProvider<List<Job>>((ref) {
  return ref.watch(jobRepositoryProvider).watchAll();
});

/// Work sessions, newest first.
final workSessionsProvider = StreamProvider<List<WorkSession>>((ref) {
  return ref.watch(workSessionRepositoryProvider).watchAll();
});

/// Open clock-ins (at most one per job).
final activeWorkSessionsProvider = Provider<List<WorkSession>>((ref) {
  final sessions = ref.watch(workSessionsProvider).value ?? const [];
  return sessions.where((s) => s.isActive).toList();
});

final jobByIdProvider = Provider<Map<String, Job>>((ref) {
  final jobs = ref.watch(jobsProvider).value ?? const [];
  return {for (final j in jobs) j.id: j};
});

class WorkNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Job?> createJob({
    required String name,
    required int hourlyRateCents,
    required String currencyCode,
    String? colorHex,
    String? notes,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || hourlyRateCents < 0) return null;
    final now = DateTime.now();
    final job = Job(
      id: const Uuid().v4(),
      name: trimmed,
      hourlyRateCents: hourlyRateCents,
      currencyCode: currencyCode,
      colorHex: colorHex,
      notes: _blank(notes),
      createdAt: now,
      modifiedAt: now,
    );
    state = await AsyncValue.guard(
      () => ref.read(jobRepositoryProvider).create(job),
    );
    return state.hasError ? null : job;
  }

  /// Saves a job. A wage change applies to new clock-ins only; finished and
  /// open sessions keep the rate they started with.
  Future<void> saveJob(Job job) async {
    state = await AsyncValue.guard(
      () => ref
          .read(jobRepositoryProvider)
          .update(job.copyWith(modifiedAt: DateTime.now())),
    );
  }

  Future<void> deleteJob(String id) async {
    await clockOut(jobId: id);
    state = await AsyncValue.guard(
      () => ref.read(jobRepositoryProvider).delete(id),
    );
  }

  /// Clocks in to [job] at its current rate. No-op if already clocked in.
  Future<void> clockIn(Job job, {String? memberId, DateTime? at}) async {
    final repo = ref.read(workSessionRepositoryProvider);
    final now = at ?? DateTime.now();
    state = await AsyncValue.guard(() async {
      final open = (await repo.getAll()).any(
        (s) => s.isActive && s.jobId == job.id,
      );
      if (open) return;
      await repo.create(
        WorkSession(
          id: const Uuid().v4(),
          jobId: job.id,
          startedAt: now,
          hourlyRateCents: job.hourlyRateCents,
          currencyCode: job.currencyCode,
          memberId: memberId,
          createdAt: now,
          modifiedAt: now,
        ),
      );
    });
  }

  /// Clocks out of [jobId], or of every open session when null.
  Future<void> clockOut({String? jobId, DateTime? at}) async {
    final repo = ref.read(workSessionRepositoryProvider);
    final now = at ?? DateTime.now();
    state = await AsyncValue.guard(() async {
      for (final s in await repo.getAll()) {
        if (!s.isActive || (jobId != null && s.jobId != jobId)) continue;
        await repo.update(s.copyWith(endedAt: now, modifiedAt: now));
      }
    });
  }

  Future<void> saveSession(WorkSession session) async {
    state = await AsyncValue.guard(
      () => ref
          .read(workSessionRepositoryProvider)
          .update(session.copyWith(modifiedAt: DateTime.now())),
    );
  }

  Future<void> addPastSession({
    required Job job,
    required DateTime startedAt,
    required DateTime endedAt,
    int breakSeconds = 0,
    String? note,
  }) async {
    final now = DateTime.now();
    state = await AsyncValue.guard(
      () => ref
          .read(workSessionRepositoryProvider)
          .create(
            WorkSession(
              id: const Uuid().v4(),
              jobId: job.id,
              startedAt: startedAt,
              endedAt: endedAt,
              hourlyRateCents: job.hourlyRateCents,
              currencyCode: job.currencyCode,
              breakSeconds: breakSeconds,
              note: _blank(note),
              createdAt: now,
              modifiedAt: now,
            ),
          ),
    );
  }

  Future<void> deleteSession(String id) async {
    state = await AsyncValue.guard(
      () => ref.read(workSessionRepositoryProvider).delete(id),
    );
  }
}

final workNotifierProvider = AsyncNotifierProvider<WorkNotifier, void>(
  WorkNotifier.new,
);

String? _blank(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}
