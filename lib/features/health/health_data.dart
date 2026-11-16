import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/mood/data/body_map.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const healthCheckIn = 'health.checkin';
const healthEpisode = 'health.episode';
const healthVocabulary = 'health.vocabulary';

/// A non-destructive, repeatable migration view. Older backups and remote Mood
/// records appear without rewriting the source, losing unknown terms, or
/// creating a second sync entity on every device. An edited projection shadows
/// this view using its deterministic ID; the original check-in stays intact.
TrackerRecord legacyHealthEntry(MoodEntry mood) =>
    TrackerRecord(
      id: 'health:mood:${mood.id}',
      kind: healthCheckIn,
      title: 'Body sensations',
      body: mood.note,
      memberId: mood.memberId,
      isPrivate: true,
      occurredAt: mood.recordedAt,
      createdAt: mood.createdAt,
      modifiedAt: mood.modifiedAt,
    ).withFields({
      'legacyMoodId': mood.id,
      'author': null,
      'subjectMode': mood.memberId == null ? 'system' : 'alters',
      'subjects': [if (mood.memberId != null) mood.memberId!],
      'status': 'unsure',
      'legacyIntensity': mood.intensity,
      'legacyRaw': mood.bodySensations,
      'symptoms': [
        {
          'id': 'legacy',
          'term': 'Body sensations',
          'category': 'Sensation and coordination',
          'severity': 'Unsure',
          'spots': [
            for (final raw in mood.bodySensations)
              {
                'id': raw,
                'region':
                    bodyRegions.any((r) => r.key == parseBodySensation(raw).$1)
                    ? parseBodySensation(raw).$1
                    : 'unspecified',
                'label':
                    bodyRegions.any((r) => r.key == parseBodySensation(raw).$1)
                    ? bodyRegionLabel(parseBodySensation(raw).$1)
                    : 'Location unspecified',
                'side': 'unspecified',
                'view': 'unspecified',
                'descriptors': [
                  if (parseBodySensation(raw).$2 != null)
                    parseBodySensation(raw).$2!,
                ],
                'legacyText': raw,
                'intensity': mood.intensity,
              },
          ],
        },
      ],
    });

List<Map<String, dynamic>> healthMaps(Object? value) => value is List
    ? [
        for (final x in value)
          if (x is Map) Map<String, dynamic>.from(x),
      ]
    : [];

/// Prism has an encrypted system database and fronting identities, not separate
/// authenticated alter accounts. This enforces private viewing against the
/// current local identity at Health entry points; it is not an authentication
/// boundary against another owner of the same unlocked system database.
bool canViewHealth(TrackerRecord r, Set<String> viewers) {
  if (r.str('subjectMode') == 'unsure' && r.str('author') == null) {
    return true;
  }
  if (!r.isPrivate || r.str('subjectMode') == 'system') return true;
  return viewers.contains(r.str('author')) ||
      r.strings('subjects').any(viewers.contains);
}

final healthViewersProvider = Provider<Set<String>>(
  (ref) => {
    for (final s in ref.watch(activeSessionsProvider).value ?? []) ?s.memberId,
  },
);

final healthRecordsProvider = Provider<AsyncValue<List<TrackerRecord>>>((ref) {
  final all = ref.watch(trackerRecordsProvider);
  final moods = ref.watch(moodEntriesProvider);
  final viewers = ref.watch(healthViewersProvider);
  final hidden = ref.watch(isolatedMembersProvider).ids;
  if (all.hasError) return AsyncError(all.error!, all.stackTrace!);
  if (moods.hasError) return AsyncError(moods.error!, moods.stackTrace!);
  if (!all.hasValue || !moods.hasValue) return const AsyncLoading();
  final records = {
    for (final r in all.value!)
      if (r.kind.startsWith('health.')) r.id: r,
  };
  for (final mood in moods.value!) {
    if (mood.bodySensations.isEmpty) continue;
    final legacy = legacyHealthEntry(mood);
    records.putIfAbsent(legacy.id, () => legacy);
  }
  return AsyncData(
    records.values
        .where(
          (r) =>
              !r.flag('hidden') &&
              !r.strings('subjects').any(hidden.contains) &&
              !hidden.contains(r.str('author')) &&
              canViewHealth(r, viewers),
        )
        .toList()
      ..sort(compareRecordsNewestFirst),
  );
});

class HealthActions {
  HealthActions(this.ref);
  final Ref ref;

  Future<void> save(TrackerRecord record) async {
    final viewers = ref.read(healthViewersProvider);
    final hidden = ref.read(isolatedMembersProvider).ids;
    if (record.strings('subjects').any(hidden.contains) ||
        hidden.contains(record.str('author'))) {
      throw StateError('Record unavailable');
    }
    final repo = ref.read(trackerRecordRepositoryProvider);
    final existing = await repo.getById(record.id);
    if (existing != null &&
        (!canViewHealth(existing, viewers) ||
            existing.strings('subjects').any(hidden.contains) ||
            hidden.contains(existing.str('author')))) {
      throw StateError('Record unavailable');
    }
    if (!canViewHealth(record, viewers)) {
      throw StateError(
        'Choose a subject or author currently fronting, or Whole system',
      );
    }
    if (existing == null) {
      await repo.create(record.copyWith(isPrivate: true));
    } else {
      await repo.update(
        record.copyWith(isPrivate: true, modifiedAt: DateTime.now()),
      );
    }
  }

  Future<void> _followUpQueue = Future<void>.value();
  Future<void> followUp(
    TrackerRecord record,
    String status, {
    String note = '',
  }) {
    final next = _followUpQueue.then(
      (_) => _appendFollowUp(record, status, note: note),
    );
    _followUpQueue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _appendFollowUp(
    TrackerRecord record,
    String status, {
    String note = '',
  }) async {
    // Re-read persisted state so rapid, separate follow-ups append to the latest
    // history instead of replacing observations from a stale tile.
    final repo = ref.read(trackerRecordRepositoryProvider);
    final current = await repo.getById(record.id) ?? record;
    if (!canViewHealth(current, ref.read(healthViewersProvider))) {
      throw StateError('Record unavailable');
    }
    await save(
      current.withFields({
        'status': status == 'changed'
            ? (current.str('status') ?? 'open')
            : status,
        'observations': [
          ...healthMaps(current.fields['observations']),
          {
            'id': const Uuid().v4(),
            'at': DateTime.now().toUtc().toIso8601String(),
            'author': ref.read(healthViewersProvider).singleOrNull,
            'status': status,
            'note': note,
          },
        ],
      }),
    );
  }
}

final healthActionsProvider = Provider<HealthActions>(HealthActions.new);

/// Only the already-authorized, filtered records passed by the review screen
/// are exported. Identity and notes require separate explicit opt-ins.
String healthSummary(
  List<TrackerRecord> records, {
  bool identity = false,
  bool notes = false,
}) => const JsonEncoder.withIndent('  ').convert({
  'format': 'prism-health-summary-v1',
  'generatedAt': DateTime.now().toUtc().toIso8601String(),
  'records': [
    for (final r in records)
      {
        'id': r.id,
        'type': r.kind,
        'description': r.title,
        'happenedAt': r.occurredAt?.toIso8601String(),
        'recordedAt': r.createdAt.toIso8601String(),
        'status': r.str('status'),
        'episodeId': r.str('episodeId'),
        if (identity) ...{
          'author': r.str('author'),
          'subjects': r.strings('subjects'),
          'subjectMode': r.str('subjectMode'),
        },
        if (notes) 'notes': r.body,
        'symptoms': [
          for (final symptom in healthMaps(r.fields['symptoms']))
            {
              for (final e in symptom.entries)
                if (e.key != 'notes' && e.key != 'spots') e.key: e.value,
              if (notes) 'notes': symptom['notes'],
              'spots': [
                for (final spot in healthMaps(symptom['spots']))
                  {
                    for (final e in spot.entries)
                      if (notes || (e.key != 'notes' && e.key != 'legacyText'))
                        e.key: e.value,
                  },
              ],
            },
        ],
        'observations': [
          for (final o in healthMaps(r.fields['observations']))
            {
              'at': o['at'],
              'status': o['status'],
              if (identity) 'author': o['author'],
              if (notes) 'note': o['note'],
            },
        ],
      },
  ],
});

/// Carries the edited record's access scope through nested symptom/map sheets.
final healthEditingRecordProvider = Provider<TrackerRecord?>((ref) => null);

class HealthAccessGuard extends ConsumerWidget {
  const HealthAccessGuard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(healthEditingRecordProvider);
    final viewers = ref.watch(healthViewersProvider);
    final hidden = ref.watch(isolatedMembersProvider).ids;
    if (r != null &&
        (!canViewHealth(r, viewers) ||
            r.strings('subjects').any(hidden.contains) ||
            hidden.contains(r.str('author')))) {
      return Scaffold(
        appBar: AppBar(title: const Text('Health')),
        body: const Center(
          child: Text(
            'This private record is unavailable in the current view.',
          ),
        ),
      );
    }
    return child;
  }
}
