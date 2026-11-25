import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/health/body_atlas.dart';
import 'package:prism_plurality/features/health/symptom_catalog.dart';
import 'package:prism_plurality/features/mood/data/body_map.dart' as legacy;
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

// ---------------------------------------------------------------------------
// Attribution and access
// ---------------------------------------------------------------------------

/// Who an entry is about.
enum HealthScope { members, system, unsure }

/// Who can see an entry. Health is private by default: only the alters it is
/// about and the alter who logged it see it.
enum HealthVisibility { private, system }

/// Who an entry describes and who created it. Kept separate on purpose: an
/// alter may log something on behalf of another.
class Attribution {
  const Attribution({
    this.scope = HealthScope.members,
    this.subjects = const [],
    this.author,
    this.visibility = HealthVisibility.private,
  });

  final HealthScope scope;
  final List<String> subjects;
  final String? author;
  final HealthVisibility visibility;

  static Attribution of(TrackerRecord r) {
    final f = r.fields;
    return Attribution(
      scope:
          HealthScope.values.where((s) => s.name == f['scope']).firstOrNull ??
          (r.memberId == null ? HealthScope.system : HealthScope.members),
      subjects: [
        for (final s in (f['subjects'] as List?) ?? [?r.memberId])
          if (s is String) s,
      ],
      author: f['author'] as String?,
      visibility: f['visibility'] == 'system'
          ? HealthVisibility.system
          : HealthVisibility.private,
    );
  }

  Attribution copyWith({
    HealthScope? scope,
    List<String>? subjects,
    String? author,
    HealthVisibility? visibility,
  }) => Attribution(
    scope: scope ?? this.scope,
    subjects: subjects ?? this.subjects,
    author: author ?? this.author,
    visibility: visibility ?? this.visibility,
  );

  Map<String, Object?> toFields() => {
    'scope': scope.name,
    'subjects': scope == HealthScope.members ? subjects : const <String>[],
    'author': author,
    'visibility': visibility.name,
  };

  /// The tracker `memberId` column: the alter, when exactly one.
  String? get memberId => scope == HealthScope.members && subjects.length == 1
      ? subjects.first
      : null;

  bool get valid => scope != HealthScope.members || subjects.isNotEmpty;

  /// Whether [viewer] (the alter fronting now, or null when unknown) may
  /// see this entry. Entries about the whole system, or unsure who, are
  /// visible to everyone; private entries only to their subjects and author.
  bool visibleTo(String? viewer) {
    if (visibility == HealthVisibility.system) return true;
    if (scope != HealthScope.members) return true;
    if (viewer == null) return false;
    return author == viewer || subjects.contains(viewer);
  }

  bool isAbout(String memberId) =>
      scope == HealthScope.members && subjects.contains(memberId);
}

/// The alter whose view of Health is shown: whoever is fronting. Changes as
/// the front changes, so lists, drafts and links re-check access.
final healthViewerProvider = Provider<String?>(
  (ref) => ref.watch(currentFronterProvider).value?.id,
);

const healthKinds = {
  TrackerKind.healthCheckin,
  TrackerKind.healthSpot,
  TrackerKind.healthFollowup,
  TrackerKind.healthEpisode,
};

/// Every Health record (unfiltered). Only for access-checked consumers.
final _allHealthRecordsProvider = Provider<AsyncValue<List<TrackerRecord>>>((
  ref,
) {
  return ref
      .watch(trackerRecordsProvider)
      .whenData(
        (all) => [
          for (final r in all)
            if (healthKinds.contains(r.kind)) r,
        ],
      );
});

/// Health records the current viewer may see.
final visibleHealthRecordsProvider = Provider<AsyncValue<List<TrackerRecord>>>((
  ref,
) {
  final viewer = ref.watch(healthViewerProvider);
  return ref
      .watch(_allHealthRecordsProvider)
      .whenData(
        (rs) => [
          for (final r in rs)
            if (Attribution.of(r).visibleTo(viewer)) r,
        ],
      );
});

/// How many records exist that the current viewer can't see (shown as a
/// discreet note — never their content).
final hiddenHealthCountProvider = Provider<int>((ref) {
  final viewer = ref.watch(healthViewerProvider);
  final all = ref.watch(_allHealthRecordsProvider).value ?? const [];
  return all
      .where(
        (r) =>
            r.kind == TrackerKind.healthCheckin &&
            !Attribution.of(r).visibleTo(viewer),
      )
      .length;
});

/// One record by id, only if the viewer may open it. Distinguishes "gone"
/// from "not available to this profile" for links.
enum HealthLookup { found, hidden, missing }

(HealthLookup, TrackerRecord?) lookupHealthRecord(WidgetRef ref, String id) {
  final all = ref.read(_allHealthRecordsProvider).value ?? const [];
  final r = all.where((x) => x.id == id).firstOrNull;
  if (r == null) return (HealthLookup.missing, null);
  return Attribution.of(r).visibleTo(ref.read(healthViewerProvider))
      ? (HealthLookup.found, r)
      : (HealthLookup.hidden, null);
}

// ---------------------------------------------------------------------------
// Symptoms
// ---------------------------------------------------------------------------

enum TimePrecision { exact, approx, unknown }

enum Severity { unsure, mild, moderate, severe, verySevere }

String severityLabel(Severity s, bool es) => switch (s) {
  Severity.unsure => es ? 'No estoy seguro' : 'Unsure',
  Severity.mild => es ? 'Leve' : 'Mild',
  Severity.moderate => es ? 'Moderado' : 'Moderate',
  Severity.severe => es ? 'Fuerte' : 'Severe',
  Severity.verySevere => es ? 'Muy fuerte' : 'Very severe',
};

const courseOptions = <(String, String, String)>[
  ('constant', 'Constant', 'Constante'),
  ('intermittent', 'Comes and goes', 'Va y viene'),
  ('sudden', 'Started suddenly', 'Empezó de repente'),
  ('gradual', 'Came on gradually', 'Empezó poco a poco'),
  ('improving', 'Improving', 'Mejorando'),
  ('unchanged', 'Unchanged', 'Sin cambios'),
  ('worsening', 'Worsening', 'Empeorando'),
  ('resolved', 'Resolved', 'Resuelto'),
];

const impactOptions = <(String, String, String)>[
  ('sleep', 'Sleep', 'Sueño'),
  ('eating', 'Eating', 'Comer'),
  ('hydration', 'Drinking / hydration', 'Beber / hidratación'),
  ('movement', 'Movement', 'Movimiento'),
  ('school', 'School', 'Escuela'),
  ('work', 'Work', 'Trabajo'),
  ('concentration', 'Concentration', 'Concentración'),
];

/// One symptom within a check-in.
class HealthSymptom {
  HealthSymptom({
    String? id,
    this.termId,
    required this.label,
    this.category = SymptomCategory.other,
    this.onset,
    this.onsetPrecision = TimePrecision.exact,
    this.end,
    this.endPrecision = TimePrecision.exact,
    this.severity,
    this.score,
    this.course = const [],
    this.triggers,
    this.relief,
    this.tried,
    this.after,
    this.impact = const [],
    this.spotIds = const [],
    this.notes,
    this.tempValue,
    this.tempUnit = 'C',
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String? termId;
  final String label;
  final SymptomCategory category;
  final DateTime? onset;
  final TimePrecision onsetPrecision;
  final DateTime? end;
  final TimePrecision endPrecision;
  final Severity? severity;

  /// Optional 0–10 rating alongside the labelled severity.
  final int? score;
  final List<String> course;
  final String? triggers;
  final String? relief;
  final String? tried;
  final String? after;
  final List<String> impact;
  final List<String> spotIds;
  final String? notes;

  /// Self-entered temperature.
  final double? tempValue;
  final String tempUnit;

  HealthSymptom copyWith({
    String? label,
    String? termId,
    SymptomCategory? category,
    Object? onset = _keep,
    TimePrecision? onsetPrecision,
    Object? end = _keep,
    TimePrecision? endPrecision,
    Object? severity = _keep,
    Object? score = _keep,
    List<String>? course,
    Object? triggers = _keep,
    Object? relief = _keep,
    Object? tried = _keep,
    Object? after = _keep,
    List<String>? impact,
    List<String>? spotIds,
    Object? notes = _keep,
    Object? tempValue = _keep,
    String? tempUnit,
  }) => HealthSymptom(
    id: id,
    termId: termId ?? this.termId,
    label: label ?? this.label,
    category: category ?? this.category,
    onset: onset == _keep ? this.onset : onset as DateTime?,
    onsetPrecision: onsetPrecision ?? this.onsetPrecision,
    end: end == _keep ? this.end : end as DateTime?,
    endPrecision: endPrecision ?? this.endPrecision,
    severity: severity == _keep ? this.severity : severity as Severity?,
    score: score == _keep ? this.score : score as int?,
    course: course ?? this.course,
    triggers: triggers == _keep ? this.triggers : triggers as String?,
    relief: relief == _keep ? this.relief : relief as String?,
    tried: tried == _keep ? this.tried : tried as String?,
    after: after == _keep ? this.after : after as String?,
    impact: impact ?? this.impact,
    spotIds: spotIds ?? this.spotIds,
    notes: notes == _keep ? this.notes : notes as String?,
    tempValue: tempValue == _keep ? this.tempValue : tempValue as double?,
    tempUnit: tempUnit ?? this.tempUnit,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'termId': termId,
    'label': label,
    'category': category.name,
    'onset': onset?.toUtc().toIso8601String(),
    'onsetPrecision': onsetPrecision.name,
    'end': end?.toUtc().toIso8601String(),
    'endPrecision': endPrecision.name,
    'severity': severity?.name,
    'score': score,
    'course': course,
    'triggers': _blank(triggers),
    'relief': _blank(relief),
    'tried': _blank(tried),
    'after': _blank(after),
    'impact': impact,
    'spotIds': spotIds,
    'notes': _blank(notes),
    'temp': tempValue == null
        ? null
        : {'value': tempValue, 'unit': tempUnit, 'source': 'self'},
  }..removeWhere((k, v) => v == null || (v is List && v.isEmpty));

  static HealthSymptom fromJson(Map<String, dynamic> j) {
    final temp = j['temp'] is Map ? j['temp'] as Map : null;
    List<String> list(String k) => [
      for (final x in (j[k] as List?) ?? const [])
        if (x is String) x,
    ];
    return HealthSymptom(
      id: j['id'] as String?,
      termId: j['termId'] as String?,
      label: (j['label'] as String?) ?? '',
      category:
          SymptomCategory.values
              .where((c) => c.name == j['category'])
              .firstOrNull ??
          SymptomCategory.other,
      onset: DateTime.tryParse('${j['onset'] ?? ''}')?.toLocal(),
      onsetPrecision:
          TimePrecision.values
              .where((p) => p.name == j['onsetPrecision'])
              .firstOrNull ??
          TimePrecision.exact,
      end: DateTime.tryParse('${j['end'] ?? ''}')?.toLocal(),
      endPrecision:
          TimePrecision.values
              .where((p) => p.name == j['endPrecision'])
              .firstOrNull ??
          TimePrecision.exact,
      severity: Severity.values
          .where((s) => s.name == j['severity'])
          .firstOrNull,
      score: (j['score'] as num?)?.toInt(),
      course: list('course'),
      triggers: j['triggers'] as String?,
      relief: j['relief'] as String?,
      tried: j['tried'] as String?,
      after: j['after'] as String?,
      impact: list('impact'),
      spotIds: list('spotIds'),
      notes: j['notes'] as String?,
      tempValue: (temp?['value'] as num?)?.toDouble(),
      tempUnit: (temp?['unit'] as String?) ?? 'C',
    );
  }
}

const _keep = Object();
String? _blank(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

extension HealthCheckinX on TrackerRecord {
  List<HealthSymptom> get symptoms => [
    for (final s in (fields['symptoms'] as List?) ?? const [])
      if (s is Map) HealthSymptom.fromJson(s.cast<String, dynamic>()),
  ];

  /// When it happened (falls back to when it was written down).
  DateTime get happenedAt => (occurredAt ?? createdAt).toLocal();
  bool get backdated =>
      occurredAt != null &&
      createdAt.difference(occurredAt!).inMinutes.abs() > 15;
  TimePrecision get timePrecision =>
      TimePrecision.values
          .where((p) => p.name == fields['timePrecision'])
          .firstOrNull ??
      TimePrecision.exact;
  String? get episodeId => str('episodeId');
}

/// Follow-up states.
enum FollowStatus { still, changed, resolved }

String followStatusLabel(FollowStatus s, bool es) => switch (s) {
  FollowStatus.still => es ? 'Sigue igual' : 'Still happening',
  FollowStatus.changed => es ? 'Ha cambiado' : 'Changed',
  FollowStatus.resolved => es ? 'Resuelto' : 'Resolved',
};

/// The most recent follow-up status for a check-in (null: none yet).
FollowStatus? latestStatus(
  TrackerRecord checkin,
  List<TrackerRecord> followups,
) {
  final mine = [
    for (final f in followups)
      if (f.parentId == checkin.id) f,
  ]..sort((a, b) => a.happenedAt.compareTo(b.happenedAt));
  if (mine.isEmpty) return null;
  return FollowStatus.values
      .where((s) => s.name == mine.last.str('status'))
      .firstOrNull;
}

// ---------------------------------------------------------------------------
// Episodes
// ---------------------------------------------------------------------------

enum EpisodeState { open, improving, resolved, reopened }

String episodeStateLabel(EpisodeState s, bool es) => switch (s) {
  EpisodeState.open => es ? 'Abierto' : 'Open',
  EpisodeState.improving => es ? 'Mejorando' : 'Improving',
  EpisodeState.resolved => es ? 'Resuelto' : 'Resolved',
  EpisodeState.reopened => es ? 'Reabierto' : 'Reopened',
};

extension HealthEpisodeX on TrackerRecord {
  EpisodeState get episodeState =>
      EpisodeState.values.where((s) => s.name == fields['state']).firstOrNull ??
      EpisodeState.open;
  bool get episodeActive => episodeState != EpisodeState.resolved;

  /// State changes recorded by the user, oldest first.
  List<({EpisodeState state, DateTime at, String? note})> get episodeLog => [
    for (final e in (fields['log'] as List?) ?? const [])
      if (e is Map && DateTime.tryParse('${e['at']}') != null)
        (
          state:
              EpisodeState.values
                  .where((s) => s.name == e['state'])
                  .firstOrNull ??
              EpisodeState.open,
          at: DateTime.parse('${e['at']}').toLocal(),
          note: e['note'] as String?,
        ),
  ];
}

// ---------------------------------------------------------------------------
// Body Map spots (including entries carried over from Mood)
// ---------------------------------------------------------------------------

/// A descriptor as stored: id plus the label shown when it was chosen.
typedef DescriptorRef = ({String id, String label});

/// One place where something was felt. [record] is null for entries that
/// still live on an old Mood check-in.
class BodySpot {
  BodySpot({
    required this.id,
    required this.regionId,
    this.side = BodySide.center,
    this.view = BodyView.front,
    this.x,
    this.y,
    this.customLabel,
    this.descriptors = const [],
    this.intensity,
    this.notes,
    this.spreads = const [],
    this.at,
    this.checkinId,
    this.record,
    this.legacyMood,
    this.legacyText,
  });

  final String id;
  final String regionId;
  final BodySide side;
  final BodyView view;
  final double? x;
  final double? y;
  final String? customLabel;
  final List<DescriptorRef> descriptors;

  /// 0–10.
  final int? intensity;
  final String? notes;
  final List<SpreadPoint> spreads;
  final DateTime? at;
  final String? checkinId;
  final TrackerRecord? record;

  /// Set when this comes from a Mood check-in that hasn't been edited here.
  final MoodEntry? legacyMood;

  /// The original stored Mood value, e.g. `chest:tight`.
  final String? legacyText;

  bool get isLegacy => legacyMood != null;
  bool get hasPoint => x != null && y != null;

  String placeLabel(bool es) {
    if (regionId == customLocation)
      return customLabel?.isNotEmpty == true
          ? customLabel!
          : (es ? 'Ubicación personalizada' : 'Custom location');
    final r = regionById[regionId];
    if (r == null)
      return es ? 'Ubicación sin especificar' : 'Location unspecified';
    return r.label(es, side);
  }

  Map<String, Object?> toFields() => {
    'region': regionId,
    'side': side.name,
    'view': view.name,
    'x': x,
    'y': y,
    'customLabel': customLabel,
    'descriptors': [
      for (final d in descriptors) {'id': d.id, 'label': d.label},
    ],
    'intensity': intensity,
    'notes': _blank(notes),
    'spreads': [for (final s in spreads) s.toJson()],
    'checkinId': checkinId,
  }..removeWhere((k, v) => v == null);

  static BodySpot fromRecord(TrackerRecord r) {
    final f = r.fields;
    return BodySpot(
      id: r.id,
      regionId: (f['region'] as String?) ?? hardToLocate,
      side: BodySideText.parse(f['side'] as String?),
      view: BodyViewText.parse(f['view'] as String?),
      x: (f['x'] as num?)?.toDouble(),
      y: (f['y'] as num?)?.toDouble(),
      customLabel: f['customLabel'] as String?,
      descriptors: [
        for (final d in (f['descriptors'] as List?) ?? const [])
          if (d is Map && d['id'] is String)
            (
              id: d['id'] as String,
              label: (d['label'] as String?) ?? d['id'] as String,
            ),
      ],
      intensity: (f['intensity'] as num?)?.toInt(),
      notes: f['notes'] as String?,
      spreads: [
        for (final s in (f['spreads'] as List?) ?? const [])
          if (s is Map) SpreadPoint.fromJson(s.cast<String, dynamic>()),
      ],
      at: r.happenedAt,
      checkinId: f['checkinId'] as String?,
      record: r,
    );
  }

  BodySpot copyWith({
    String? regionId,
    BodySide? side,
    BodyView? view,
    Object? x = _keep,
    Object? y = _keep,
    Object? customLabel = _keep,
    List<DescriptorRef>? descriptors,
    Object? intensity = _keep,
    Object? notes = _keep,
    List<SpreadPoint>? spreads,
    Object? at = _keep,
  }) => BodySpot(
    id: id,
    regionId: regionId ?? this.regionId,
    side: side ?? this.side,
    view: view ?? this.view,
    x: x == _keep ? this.x : x as double?,
    y: y == _keep ? this.y : y as double?,
    customLabel: customLabel == _keep
        ? this.customLabel
        : customLabel as String?,
    descriptors: descriptors ?? this.descriptors,
    intensity: intensity == _keep ? this.intensity : intensity as int?,
    notes: notes == _keep ? this.notes : notes as String?,
    spreads: spreads ?? this.spreads,
    at: at == _keep ? this.at : at as DateTime?,
    checkinId: checkinId,
    record: record,
    legacyMood: legacyMood,
    legacyText: legacyText,
  );
}

/// A place a sensation spread to (the user's observation).
class SpreadPoint {
  const SpreadPoint({
    required this.regionId,
    this.side = BodySide.center,
    this.view = BodyView.front,
    this.x,
    this.y,
    this.stops = false,
  });
  final String regionId;
  final BodySide side;
  final BodyView view;
  final double? x;
  final double? y;

  /// Where it stops.
  final bool stops;

  Map<String, Object?> toJson() => {
    'region': regionId,
    'side': side.name,
    'view': view.name,
    'x': x,
    'y': y,
    'stops': stops,
  }..removeWhere((k, v) => v == null);
  static SpreadPoint fromJson(Map<String, dynamic> j) => SpreadPoint(
    regionId: (j['region'] as String?) ?? hardToLocate,
    side: BodySideText.parse(j['side'] as String?),
    view: BodyViewText.parse(j['view'] as String?),
    x: (j['x'] as num?)?.toDouble(),
    y: (j['y'] as num?)?.toDouble(),
    stops: j['stops'] == true,
  );
  String label(bool es) => regionById[regionId]?.label(es, side) ?? regionId;
}

/// Body sensations recorded on Mood check-ins before they moved to Health.
///
/// They are read straight from the Mood entries (nothing is copied or
/// deleted), so restoring an older backup simply brings them back here.
/// Ids are stable (`mood:<entry id>:<index>`) and an entry edited in Health
/// becomes a normal spot that records the id it replaces in `legacyRef`.
List<BodySpot> legacySpotsFrom(List<MoodEntry> moods, Set<String> replaced) {
  final out = <BodySpot>[];
  for (final m in moods) {
    for (var i = 0; i < m.bodySensations.length; i++) {
      final id = legacySpotId(m.id, i);
      if (replaced.contains(id)) continue;
      final raw = m.bodySensations[i];
      final (region, sensation) = legacy.parseBodySensation(raw);
      final mapped = legacyMoodRegions[region];
      final descriptor = sensation == null || sensation.isEmpty
          ? null
          : (
              id: legacyMoodSensations[sensation] ?? 'legacy:$sensation',
              label: legacy.bodySensations[sensation] ?? sensation,
            );
      out.add(
        BodySpot(
          id: id,
          regionId: mapped ?? (region.isEmpty ? hardToLocate : customLocation),
          customLabel: mapped == null && region.isNotEmpty
              ? legacy.bodyRegionLabel(region)
              : null,
          descriptors: [?descriptor],
          at: m.recordedAt.toLocal(),
          legacyMood: m,
          legacyText: raw,
          notes: m.note,
        ),
      );
    }
  }
  return out;
}

String legacySpotId(String moodId, int index) => 'mood:$moodId:$index';

/// Attribution for a Mood entry's carried-over sensations. They were
/// visible to everyone in Mood, so they stay visible to everyone here.
Attribution legacyAttribution(MoodEntry m) => Attribution(
  scope: m.memberId == null ? HealthScope.system : HealthScope.members,
  subjects: [?m.memberId],
  author: m.memberId,
  visibility: HealthVisibility.system,
);

/// All Body Map spots the viewer may see, newest first, including those
/// still stored on Mood check-ins.
final bodySpotsProvider = Provider<List<BodySpot>>((ref) {
  final records = ref.watch(visibleHealthRecordsProvider).value ?? const [];
  final all = ref.watch(_allHealthRecordsProvider).value ?? const [];
  final replaced = {
    for (final r in all)
      if (r.kind == TrackerKind.healthSpot) ?r.str('legacyRef'),
  };
  final moods = ref.watch(moodEntriesProvider).value ?? const <MoodEntry>[];
  final viewer = ref.watch(healthViewerProvider);
  final spots = [
    for (final r in records)
      if (r.kind == TrackerKind.healthSpot) BodySpot.fromRecord(r),
    for (final s in legacySpotsFrom(moods, replaced))
      if (legacyAttribution(s.legacyMood!).visibleTo(viewer)) s,
  ]..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
  return spots;
});

// ---------------------------------------------------------------------------
// Custom vocabulary
// ---------------------------------------------------------------------------

/// Custom descriptors (per region) and symptoms the user saved for reuse.
class HealthVocab {
  const HealthVocab(this.records);
  final List<TrackerRecord> records;

  List<Descriptor> descriptorsFor(String regionId) => [
    for (final r in records)
      if (r.str('type') == 'descriptor' &&
          r.str('region') == regionId &&
          !r.flag('retired'))
        Descriptor('custom:${r.id}', r.title, r.title),
  ];

  List<SymptomTerm> get symptoms => [
    for (final r in records)
      if (r.str('type') == 'symptom' && !r.flag('retired'))
        SymptomTerm(
          'custom:${r.id}',
          SymptomCategory.values
                  .where((c) => c.name == r.str('category'))
                  .firstOrNull ??
              SymptomCategory.other,
          r.title,
          r.title,
        ),
  ];
}

final healthVocabProvider = Provider<HealthVocab>(
  (ref) => HealthVocab(
    ref.watch(trackerKindProvider(TrackerKind.healthVocab)).value ?? const [],
  ),
);

// ---------------------------------------------------------------------------
// Saving
// ---------------------------------------------------------------------------

/// Writes Health records. Every save carries a client id so a double tap or
/// a retry updates the same record instead of creating a second one.
class HealthStore {
  HealthStore(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<TrackerRecord?> _byClientId(String kind, String clientId) async {
    final all = await ref.read(trackerRecordRepositoryProvider).getAll();
    return all
        .where((r) => r.kind == kind && r.str('clientId') == clientId)
        .firstOrNull;
  }

  Future<TrackerRecord> _upsert({
    required String kind,
    required String clientId,
    TrackerRecord? existing,
    required Attribution who,
    required Map<String, Object?> fields,
    String title = '',
    String? body,
    String? parentId,
    DateTime? occurredAt,
    DateTime? endedAt,
  }) async {
    final prior = existing ?? await _byClientId(kind, clientId);
    final all = {...who.toFields(), ...fields, 'clientId': clientId};
    if (prior != null) {
      final next = prior.copyWith(
        title: title,
        body: body,
        parentId: parentId ?? prior.parentId,
        occurredAt: occurredAt ?? prior.occurredAt,
        endedAt: endedAt,
        memberId: who.memberId,
        isPrivate: true,
      );
      final cleared = {for (final k in prior.fields.keys) k: null};
      final merged = next.withFields({...cleared, ...all});
      await _t.save(merged);
      return merged;
    }
    return _t.create(
      kind: kind,
      title: title,
      body: body,
      parentId: parentId,
      occurredAt: occurredAt,
      endedAt: endedAt,
      memberId: who.memberId,
      isPrivate: true,
      fields: all,
    );
  }

  Future<TrackerRecord> saveCheckin({
    required String clientId,
    TrackerRecord? existing,
    required Attribution who,
    required List<HealthSymptom> symptoms,
    String? quickText,
    required DateTime happenedAt,
    TimePrecision precision = TimePrecision.exact,
    String? episodeId,
  }) => _upsert(
    kind: TrackerKind.healthCheckin,
    clientId: clientId,
    existing: existing,
    who: who,
    title: symptoms.map((s) => s.label).where((l) => l.isNotEmpty).join(', '),
    body: _blank(quickText),
    occurredAt: happenedAt,
    fields: {
      'symptoms': [for (final s in symptoms) s.toJson()],
      'timePrecision': precision.name,
      'episodeId': episodeId,
    },
  );

  Future<TrackerRecord> saveSpot({
    required String clientId,
    TrackerRecord? existing,
    required Attribution who,
    required BodySpot spot,
    String? legacyRef,
  }) => _upsert(
    kind: TrackerKind.healthSpot,
    clientId: clientId,
    existing: existing,
    who: who,
    title: spot.placeLabel(false),
    occurredAt: spot.at ?? DateTime.now(),
    fields: {
      ...spot.toFields(),
      'legacyRef': legacyRef ?? existing?.str('legacyRef'),
    },
  );

  Future<TrackerRecord> addFollowup({
    required String clientId,
    required TrackerRecord checkin,
    required FollowStatus status,
    String? note,
    Severity? severity,
    DateTime? at,
  }) => _upsert(
    kind: TrackerKind.healthFollowup,
    clientId: clientId,
    who: Attribution.of(
      checkin,
    ).copyWith(author: ref.read(healthViewerProvider)),
    parentId: checkin.id,
    body: _blank(note),
    occurredAt: at ?? DateTime.now(),
    fields: {'status': status.name, 'severity': severity?.name},
  );

  Future<TrackerRecord> saveEpisode({
    required String clientId,
    TrackerRecord? existing,
    required Attribution who,
    required String title,
    required DateTime start,
    bool approxStart = false,
    DateTime? end,
    required EpisodeState state,
    String? note,
  }) async {
    final log = [
      ...?(existing?.fields['log'] as List?),
      if (existing == null || existing.episodeState != state)
        {
          'state': state.name,
          'at': DateTime.now().toUtc().toIso8601String(),
          'note': _blank(note),
        },
    ];
    return _upsert(
      kind: TrackerKind.healthEpisode,
      clientId: clientId,
      existing: existing,
      who: who,
      title: title.trim(),
      occurredAt: start,
      endedAt: end,
      fields: {'state': state.name, 'approxStart': approxStart, 'log': log},
    );
  }

  /// Adds or removes a check-in from an episode without touching anything else.
  Future<void> setEpisode(TrackerRecord checkin, String? episodeId) =>
      _t.save(checkin.withFields({'episodeId': episodeId}));

  Future<void> delete(TrackerRecord r) =>
      _t.delete(r.id, children: r.kind == TrackerKind.healthCheckin);

  Future<TrackerRecord> addCustomTerm({
    required String type,
    required String label,
    String? regionId,
    SymptomCategory? category,
  }) async {
    final existing = ref
        .read(healthVocabProvider)
        .records
        .where(
          (r) =>
              r.str('type') == type &&
              r.title.toLowerCase() == label.trim().toLowerCase() &&
              r.str('region') == regionId,
        )
        .firstOrNull;
    if (existing != null) return existing;
    return _t.create(
      kind: TrackerKind.healthVocab,
      title: label.trim(),
      isPrivate: true,
      fields: {'type': type, 'region': regionId, 'category': category?.name},
    );
  }
}

final healthStoreProvider = Provider<HealthStore>(HealthStore.new);

// ---------------------------------------------------------------------------
// Drafts
// ---------------------------------------------------------------------------

/// Unsaved check-ins are kept per alter (the one who was writing), so a
/// switch doesn't show one alter's half-written entry to another.
class HealthDrafts {
  static String _key(String? author) =>
      'prism.health.draft.${author ?? 'system'}';

  static Future<Map<String, dynamic>?> load(String? author) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _key(author),
      );
      if (raw == null) return null;
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String? author, Map<String, dynamic> draft) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key(author),
        jsonEncode(draft),
      );
    } catch (_) {}
  }

  static Future<void> clear(String? author) async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key(author));
    } catch (_) {}
  }
}

final healthDraftProvider = FutureProvider<Map<String, dynamic>?>(
  (ref) => HealthDrafts.load(ref.watch(healthViewerProvider)),
);

// ---------------------------------------------------------------------------
// Period comparison
// ---------------------------------------------------------------------------

/// Days that have at least one logged symptom in [start, end). Days without
/// a log are unknown, not symptom-free.
int daysWithLoggedSymptom(
  Iterable<TrackerRecord> checkins,
  DateTime start,
  DateTime end,
) {
  final days = <DateTime>{};
  for (final c in checkins) {
    final t = c.happenedAt;
    if (t.isBefore(start) || !t.isBefore(end)) continue;
    days.add(DateTime(t.year, t.month, t.day));
  }
  return days.length;
}
