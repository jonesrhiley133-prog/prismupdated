import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/features/feature_registry.dart';
import 'package:prism_plurality/domain/models/models.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

enum ResetPeriod { today, week, month, year, custom, all }

/// A half-open local-time range [start, end).
class ResetRange {
  const ResetRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
  bool contains(DateTime t) {
    final l = t.toLocal();
    return !l.isBefore(start) && l.isBefore(end);
  }
}

/// Date boundaries in the device's time zone. Weeks start on [firstWeekday]
/// (1 = Monday … 7 = Sunday) and may cross month or year boundaries.
ResetRange rangeFor(
  ResetPeriod p,
  DateTime now, {
  int firstWeekday = DateTime.monday,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (p) {
    ResetPeriod.today => ResetRange(
      today,
      DateTime(now.year, now.month, now.day + 1),
    ),
    ResetPeriod.week => () {
      final back = (today.weekday - firstWeekday + 7) % 7;
      final s = DateTime(today.year, today.month, today.day - back);
      return ResetRange(s, DateTime(s.year, s.month, s.day + 7));
    }(),
    ResetPeriod.month => ResetRange(
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    ),
    ResetPeriod.year => ResetRange(DateTime(now.year), DateTime(now.year + 1)),
    ResetPeriod.custom => () {
      final s = customStart ?? today;
      final e = customEnd ?? s;
      return ResetRange(
        DateTime(s.year, s.month, s.day),
        DateTime(e.year, e.month, e.day + 1),
      );
    }(),
    ResetPeriod.all => ResetRange(DateTime(1), DateTime(9999)),
  };
}

/// One record found by a reset.
class ResetItem {
  ResetItem({
    required this.source,
    required this.id,
    required this.date,
    this.json,
    this.raw,
    this.parentId,
  });
  final String source;
  final String id;
  final DateTime date;
  final Map<String, dynamic>? json;
  final Object? raw;
  final String? parentId;
}

/// A place a feature keeps records.
class ResetSource {
  const ResetSource({
    required this.key,
    required this.label,
    required this.collect,
    required this.delete,
    this.restore,
    this.persistable = true,
  });
  final String key;
  final (String, String) label;
  final Future<List<ResetItem>> Function(Ref ref) collect;
  final Future<void> Function(Ref ref, ResetItem item) delete;

  /// Re-creates an item (with a new id). Null when the data can't be put back.
  final Future<void> Function(
    Ref ref,
    ResetItem item,
    String newId,
    String? newParent,
  )?
  restore;

  /// Whether the copy survives an app restart (otherwise undo lasts until Prism closes).
  final bool persistable;
}

const _uuid = Uuid();

ResetSource trackerSource(String key, List<String> kinds) => ResetSource(
  key: key,
  label: ('Records', 'Registros'),
  collect: (ref) async {
    final all = await ref.read(trackerRecordRepositoryProvider).getAll();
    final ks = kinds.toSet();
    return [
      for (final r in all)
        if (ks.contains(r.kind))
          ResetItem(
            source: key,
            id: r.id,
            date: r.occurredAt ?? r.createdAt,
            json: r.toJson(),
            parentId: r.parentId,
          ),
    ];
  },
  delete: (ref, i) => ref.read(trackerRecordRepositoryProvider).delete(i.id),
  restore: (ref, i, id, parent) {
    final r = TrackerRecord.fromJson(i.json!);
    return ref
        .read(trackerRecordRepositoryProvider)
        .create(
          r.copyWith(
            id: id,
            parentId: parent ?? r.parentId,
            modifiedAt: DateTime.now(),
          ),
        );
  },
);

/// Dated records stored in their own tables.
final Map<String, ResetSource> resetSources = {
  'mood': ResetSource(
    key: 'mood',
    label: ('Mood entries', 'Registros de ánimo'),
    collect: (ref) async => [
      for (final m in await ref.read(moodRepositoryProvider).getAll())
        ResetItem(
          source: 'mood',
          id: m.id,
          date: m.recordedAt,
          json: m.toJson(),
        ),
    ],
    delete: (ref, i) => ref.read(moodRepositoryProvider).delete(i.id),
    restore: (ref, i, id, _) => ref
        .read(moodRepositoryProvider)
        .create(MoodEntry.fromJson(i.json!).copyWith(id: id)),
  ),
  'notes': ResetSource(
    key: 'notes',
    label: ('Notes', 'Notas'),
    collect: (ref) async => [
      for (final n in await ref.read(notesRepositoryProvider).getAllNotes())
        ResetItem(source: 'notes', id: n.id, date: n.date, json: n.toJson()),
    ],
    delete: (ref, i) => ref.read(notesRepositoryProvider).deleteNote(i.id),
    restore: (ref, i, id, _) => ref
        .read(notesRepositoryProvider)
        .createNote(Note.fromJson(i.json!).copyWith(id: id)),
  ),
  'reminders': ResetSource(
    key: 'reminders',
    label: ('Reminders', 'Recordatorios'),
    collect: (ref) async => [
      for (final r
          in await ref.read(remindersRepositoryProvider).watchAll().first)
        ResetItem(
          source: 'reminders',
          id: r.id,
          date: r.createdAt,
          json: r.toJson(),
        ),
    ],
    delete: (ref, i) => ref.read(remindersRepositoryProvider).delete(i.id),
    restore: (ref, i, id, _) => ref
        .read(remindersRepositoryProvider)
        .create(Reminder.fromJson(i.json!).copyWith(id: id)),
  ),
  'calendar': ResetSource(
    key: 'calendar',
    label: ('Calendar events', 'Eventos'),
    collect: (ref) async => [
      for (final e in await ref.read(calendarRepositoryProvider).getAll())
        ResetItem(
          source: 'calendar',
          id: e.id,
          date: e.startAt,
          json: e.toJson(),
        ),
    ],
    delete: (ref, i) => ref.read(calendarRepositoryProvider).delete(i.id),
    restore: (ref, i, id, _) => ref
        .read(calendarRepositoryProvider)
        .create(CalendarEvent.fromJson(i.json!).copyWith(id: id)),
  ),
  'chat': ResetSource(
    key: 'chat',
    label: ('Chat messages', 'Mensajes'),
    collect: (ref) async => [
      for (final m
          in await ref.read(chatMessageRepositoryProvider).getAllMessages())
        ResetItem(
          source: 'chat',
          id: m.id,
          date: m.timestamp,
          json: m.toJson(),
        ),
    ],
    delete: (ref, i) =>
        ref.read(chatMessageRepositoryProvider).deleteMessage(i.id),
    restore: (ref, i, id, _) => ref
        .read(chatMessageRepositoryProvider)
        .createMessage(ChatMessage.fromJson(i.json!).copyWith(id: id)),
  ),
  'fronting': ResetSource(
    key: 'fronting',
    label: (
      'Fronting sessions (not current ones)',
      'Sesiones de frente (no las actuales)',
    ),
    collect: (ref) async => [
      for (final s
          in await ref.read(frontingSessionRepositoryProvider).getAllSessions())
        if (!s.isSleep && s.endTime != null)
          ResetItem(
            source: 'fronting',
            id: s.id,
            date: s.startTime,
            json: s.toJson(),
          ),
    ],
    delete: (ref, i) =>
        ref.read(frontingSessionRepositoryProvider).deleteSession(i.id),
    restore: (ref, i, id, _) => ref
        .read(frontingSessionRepositoryProvider)
        .createSession(
          FrontingSession.fromJson(i.json!).copyWith(id: id, isDeleted: false),
        ),
  ),
  'sleepSessions': ResetSource(
    key: 'sleepSessions',
    label: (
      'Sleep sessions (not the current one)',
      'Sesiones de sueño (no la actual)',
    ),
    collect: (ref) async => [
      for (final s
          in await ref.read(frontingSessionRepositoryProvider).getAllSessions())
        if (s.isSleep && s.endTime != null)
          ResetItem(
            source: 'sleepSessions',
            id: s.id,
            date: s.startTime,
            json: s.toJson(),
          ),
    ],
    delete: (ref, i) =>
        ref.read(frontingSessionRepositoryProvider).deleteSession(i.id),
    restore: (ref, i, id, _) => ref
        .read(frontingSessionRepositoryProvider)
        .createSession(
          FrontingSession.fromJson(i.json!).copyWith(id: id, isDeleted: false),
        ),
  ),
  'habitCompletions': ResetSource(
    key: 'habitCompletions',
    label: ('Habit completions', 'Hábitos completados'),
    collect: (ref) async => [
      for (final c
          in await ref.read(habitRepositoryProvider).getAllCompletions())
        ResetItem(
          source: 'habitCompletions',
          id: c.id,
          date: c.completedAt,
          json: c.toJson(),
        ),
    ],
    delete: (ref, i) =>
        ref.read(habitRepositoryProvider).deleteCompletion(i.id),
    restore: (ref, i, id, _) => ref
        .read(habitRepositoryProvider)
        .createCompletion(HabitCompletion.fromJson(i.json!).copyWith(id: id)),
  ),
  'cycle': ResetSource(
    key: 'cycle',
    label: ('Cycle days', 'Días del ciclo'),
    collect: (ref) async => [
      for (final c in await ref.read(cycleEntryRepositoryProvider).getAll())
        ResetItem(source: 'cycle', id: c.id, date: c.day, json: c.toJson()),
    ],
    delete: (ref, i) => ref.read(cycleEntryRepositoryProvider).delete(i.id),
    restore: (ref, i, id, _) => ref
        .read(cycleEntryRepositoryProvider)
        .create(CycleEntry.fromJson(i.json!).copyWith(id: id)),
  ),
  'work': ResetSource(
    key: 'work',
    label: ('Work sessions', 'Sesiones de trabajo'),
    persistable: false,
    collect: (ref) async => [
      for (final w in await ref.read(workSessionRepositoryProvider).getAll())
        if (w.endedAt != null)
          ResetItem(source: 'work', id: w.id, date: w.startedAt, raw: w),
    ],
    delete: (ref, i) => ref.read(workSessionRepositoryProvider).delete(i.id),
    restore: (ref, i, id, _) => ref
        .read(workSessionRepositoryProvider)
        .create((i.raw! as WorkSession).copyWith(id: id)),
  ),
  'locations': ResetSource(
    key: 'locations',
    label: ('Location visits', 'Visitas a lugares'),
    persistable: false,
    collect: (ref) async => [
      for (final l
          in await ref.read(locationSessionRepositoryProvider).getAll())
        if (l.endedAt != null)
          ResetItem(source: 'locations', id: l.id, date: l.startedAt, raw: l),
    ],
    delete: (ref, i) =>
        ref.read(locationSessionRepositoryProvider).delete(i.id),
    restore: (ref, i, id, _) => ref
        .read(locationSessionRepositoryProvider)
        .create((i.raw! as LocationSession).copyWith(id: id)),
  ),
  'polls': ResetSource(
    key: 'polls',
    label: (
      'Polls (with their options and votes)',
      'Encuestas (con opciones y votos)',
    ),
    collect: (ref) async => [
      for (final p in await ref.read(pollRepositoryProvider).getAllPolls())
        ResetItem(source: 'polls', id: p.id, date: p.createdAt),
    ],
    delete: (ref, i) => ref.read(pollRepositoryProvider).deletePoll(i.id),
  ),
};

/// What a reset would remove.
class ResetPlan {
  ResetPlan(this.feature, this.period, this.range, this.items);
  final PrismFeature feature;
  final ResetPeriod period;
  final ResetRange range;
  final List<ResetItem> items;
  Map<String, int> get countsBySource {
    final out = <String, int>{};
    for (final i in items) {
      out[i.source] = (out[i.source] ?? 0) + 1;
    }
    return out;
  }

  bool get recoverable => items.every(
    (i) =>
        i.source.startsWith('tracker') ||
        resetSources[i.source]?.restore != null,
  );
  bool get survivesRestart =>
      items.every((i) => resetSources[i.source]?.persistable ?? true);
}

/// A recoverable batch (no content shown in history, only counts).
class ResetBatch {
  ResetBatch({
    required this.id,
    required this.featureId,
    required this.at,
    required this.period,
    required this.items,
  });
  final String id;
  final String featureId;
  final DateTime at;
  final String period;
  final List<ResetItem> items;
}

const recoveryDays = 7;

class DataResetService {
  DataResetService(this.ref);
  final Ref ref;

  /// Session-only copies (data that can't be saved as JSON).
  static final Map<String, ResetBatch> _memory = {};

  List<ResetSource> sourcesFor(PrismFeature f, {required bool all}) => [
    if (f.data.activityKinds.isNotEmpty)
      trackerSource('tracker.activity', f.data.activityKinds),
    if (all && f.data.permanentKinds.isNotEmpty)
      trackerSource('tracker.permanent', f.data.permanentKinds),
    for (final s in f.data.sources) ?resetSources[s],
  ];

  /// Finds what would be removed. Long-term records are only included when
  /// clearing everything.
  Future<ResetPlan> plan(
    PrismFeature f,
    ResetPeriod period,
    ResetRange range,
  ) async {
    final all = period == ResetPeriod.all;
    final items = <ResetItem>[];
    for (final s in sourcesFor(f, all: all)) {
      for (final i in await s.collect(ref)) {
        if (all || range.contains(i.date)) items.add(i);
      }
    }
    return ResetPlan(f, period, range, items);
  }

  ResetSource? _source(String key, PrismFeature f) => key == 'tracker.activity'
      ? trackerSource(key, f.data.activityKinds)
      : (key == 'tracker.permanent'
            ? trackerSource(key, f.data.permanentKinds)
            : resetSources[key]);

  /// Removes the planned records, keeping a copy for [recoveryDays] where
  /// the data allows it. Returns the batch id.
  Future<String> execute(ResetPlan plan, {String? periodLabel}) async {
    final id = _uuid.v4();
    final kept = <ResetItem>[];
    // Children first so nothing is left pointing at a removed parent.
    final ordered = [...plan.items]
      ..sort(
        (a, b) => (a.parentId == null ? 1 : 0) - (b.parentId == null ? 1 : 0),
      );
    for (final i in ordered) {
      final s = _source(i.source, plan.feature);
      if (s == null) continue;
      await s.delete(ref, i);
      if (s.restore != null) kept.add(i);
    }
    final batch = ResetBatch(
      id: id,
      featureId: plan.feature.id,
      at: DateTime.now(),
      period: periodLabel ?? plan.period.name,
      items: kept,
    );
    if (kept.any((i) => i.raw != null)) _memory[id] = batch;
    await _saveTrash(batch);
    await ref
        .read(trackerNotifierProvider.notifier)
        .create(
          kind: TrackerKind.appResetLog,
          occurredAt: DateTime.now(),
          fields: {
            'feature': plan.feature.id,
            'period': periodLabel ?? plan.period.name,
            'from': plan.range.start.toIso8601String(),
            'to': plan.range.end.toIso8601String(),
            'count': plan.items.length,
            'recoverable':
                kept.length == plan.items.length && plan.items.isNotEmpty,
            'batch': id,
          },
        );
    return id;
  }

  /// Puts a batch back (as new copies). Returns how many were restored.
  Future<int> undo(String batchId) async {
    final batch = await _loadBatch(batchId);
    if (batch == null) return 0;
    final f = prismFeatureIndex[batch.featureId];
    if (f == null) return 0;
    final ids = {for (final i in batch.items) i.id: _uuid.v4()};
    // Parents first.
    final ordered = [...batch.items]
      ..sort(
        (a, b) => (a.parentId == null ? 0 : 1) - (b.parentId == null ? 0 : 1),
      );
    var n = 0;
    for (final i in ordered) {
      final s = _source(i.source, f);
      if (s?.restore == null) continue;
      try {
        await s!.restore!(
          ref,
          i,
          ids[i.id]!,
          i.parentId == null ? null : ids[i.parentId],
        );
        n++;
      } catch (_) {}
    }
    _memory.remove(batchId);
    await _deleteTrash(batchId);
    final log =
        (ref.read(trackerKindProvider(TrackerKind.appResetLog)).value ??
                const <TrackerRecord>[])
            .where((r) => r.str('batch') == batchId)
            .firstOrNull;
    if (log != null)
      await ref
          .read(trackerNotifierProvider.notifier)
          .save(log.withFields({'undone': true}));
    return n;
  }

  /// Whether a batch can still be undone.
  Future<bool> canUndo(String batchId) async =>
      (await _loadBatch(batchId)) != null;

  // ── Recovery copies (stored on this device only) ──

  static Directory? testDir;

  Future<File?> _file() async {
    if (kIsWeb) return null;
    final dir = testDir ?? await getApplicationSupportDirectory();
    return File('${dir.path}/prism_reset_recovery.json');
  }

  Future<Map<String, dynamic>> _readAll() async {
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return {};
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final cutoff = DateTime.now().subtract(
        const Duration(days: recoveryDays),
      );
      m.removeWhere(
        (_, v) =>
            DateTime.tryParse('${(v as Map)['at']}')?.isBefore(cutoff) ?? true,
      );
      return m;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> m) async {
    final f = await _file();
    if (f == null) return;
    await f.writeAsString(jsonEncode(m));
  }

  Future<void> _saveTrash(ResetBatch b) async {
    final m = await _readAll();
    m[b.id] = {
      'feature': b.featureId,
      'at': b.at.toIso8601String(),
      'period': b.period,
      'items': [
        for (final i in b.items)
          if (i.json != null)
            {
              'source': i.source,
              'id': i.id,
              'parent': i.parentId,
              'date': i.date.toIso8601String(),
              'json': i.json,
            },
      ],
    };
    await _writeAll(m);
  }

  Future<void> _deleteTrash(String id) async {
    final m = await _readAll();
    m.remove(id);
    await _writeAll(m);
  }

  Future<ResetBatch?> _loadBatch(String id) async {
    final m = await _readAll();
    final v = m[id] as Map<String, dynamic>?;
    final mem = _memory[id];
    if (v == null && mem == null) return null;
    final items = <ResetItem>[
      for (final i in (v?['items'] as List?) ?? const [])
        ResetItem(
          source: '${i['source']}',
          id: '${i['id']}',
          parentId: i['parent'] as String?,
          date: DateTime.parse('${i['date']}'),
          json: (i['json'] as Map).cast<String, dynamic>(),
        ),
      ...?mem?.items.where((i) => i.raw != null),
    ];
    return ResetBatch(
      id: id,
      featureId: '${v?['feature'] ?? mem!.featureId}',
      at: DateTime.tryParse('${v?['at']}') ?? mem!.at,
      period: '${v?['period'] ?? mem!.period}',
      items: items,
    );
  }

  @visibleForTesting
  static void clearMemory() => _memory.clear();
}

final dataResetServiceProvider = Provider<DataResetService>(
  DataResetService.new,
);
