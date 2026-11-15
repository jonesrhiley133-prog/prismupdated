import 'package:prism_plurality/core/constants/fronting_namespaces.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/relationships/utils/relationships.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

// ───────────────────────── Categories & labels ─────────────────────────

/// Built-in categories. Custom ones come from [RelSettings.customCategories].
const relCategories = ['romantic', 'platonic', 'familial', 'other'];

/// Map/edge style groups (each with a default colour and a dash pattern so
/// colour is never the only difference).
const relStyles = ['romantic', 'platonic', 'familial', 'sibling', 'parent', 'mentor', 'protective', 'rival', 'complicated', 'unknown'];

const relStyleDefaultColors = {
  'romantic': 0xFFD98A9B,
  'platonic': 0xFF7FA7D6,
  'familial': 0xFF7FB08A,
  'sibling': 0xFF6FB3AE,
  'parent': 0xFF5E9E6E,
  'mentor': 0xFF9C86C9,
  'protective': 0xFFD4AE5A,
  'rival': 0xFFDB8A4E,
  'complicated': 0xFF9A9A9A,
  'unknown': 0xFFB5ADA5,
};

/// A relationship label. Directional labels read "A is B's <label>" and
/// name their [inverse] (what B is to A).
class RelLabel {
  const RelLabel(this.key, this.category, this.en, this.es, {this.inverse, this.style, this.legacy});
  final String key;
  final String category;
  final String en;
  final String es;
  final String? inverse;
  final String? style;

  /// The value written to the older single `type` field.
  final String? legacy;
  bool get directional => inverse != null && inverse != key;
}

const relLabels = <RelLabel>[
  // Romantic
  RelLabel('partners', 'romantic', 'Romantic partners', 'Pareja romántica', legacy: 'partner'),
  RelLabel('dating', 'romantic', 'Dating', 'Saliendo', legacy: 'partner'),
  RelLabel('married', 'romantic', 'Married', 'Casados', legacy: 'partner'),
  RelLabel('engaged', 'romantic', 'Engaged', 'Comprometidos', legacy: 'partner'),
  RelLabel('crush', 'romantic', 'Crush', 'Flechazo', legacy: 'crush'),
  RelLabel('romantic_interest', 'romantic', 'Romantic interest', 'Interés romántico', legacy: 'crush'),
  RelLabel('ex_partners', 'romantic', 'Ex-partners', 'Ex parejas'),
  RelLabel('queerplatonic', 'romantic', 'Queerplatonic partners', 'Pareja queerplatónica'),
  RelLabel('romantic_other', 'romantic', 'Other romantic connection', 'Otra conexión romántica'),
  // Platonic
  RelLabel('best_friends', 'platonic', 'Best friends', 'Mejores amigos', legacy: 'best_friend'),
  RelLabel('close_friends', 'platonic', 'Close friends', 'Amigos cercanos', legacy: 'friend'),
  RelLabel('friends', 'platonic', 'Friends', 'Amigos', legacy: 'friend'),
  RelLabel('acquaintances', 'platonic', 'Acquaintances', 'Conocidos', legacy: 'acquaintance'),
  RelLabel('best_friend_like', 'platonic', 'Best-friend-like', 'Casi mejores amigos', legacy: 'best_friend'),
  RelLabel('companions', 'platonic', 'Companions', 'Compañeros', legacy: 'friend'),
  RelLabel('trusted', 'platonic', 'Trusted', 'De confianza', legacy: 'friend'),
  // Familial
  RelLabel('parent', 'familial', 'Parent', 'Madre/padre', inverse: 'child', style: 'parent', legacy: 'parent_figure'),
  RelLabel('child', 'familial', 'Child', 'Hija/hijo', inverse: 'parent', style: 'parent', legacy: 'child_figure'),
  RelLabel('sibling', 'familial', 'Siblings', 'Hermanos', style: 'sibling', legacy: 'sibling'),
  RelLabel('half_sibling', 'familial', 'Half-siblings', 'Medio hermanos', style: 'sibling', legacy: 'sibling'),
  RelLabel('step_sibling', 'familial', 'Step-siblings', 'Hermanastros', style: 'sibling', legacy: 'sibling'),
  RelLabel('adoptive_sibling', 'familial', 'Adoptive siblings', 'Hermanos adoptivos', style: 'sibling', legacy: 'sibling'),
  RelLabel('grandparent', 'familial', 'Grandparent', 'Abuela/abuelo', inverse: 'grandchild', style: 'parent', legacy: 'family'),
  RelLabel('grandchild', 'familial', 'Grandchild', 'Nieta/nieto', inverse: 'grandparent', style: 'parent', legacy: 'family'),
  RelLabel('aunt_uncle', 'familial', 'Aunt / uncle', 'Tía / tío', inverse: 'niece_nephew', legacy: 'family'),
  RelLabel('niece_nephew', 'familial', 'Niece / nephew', 'Sobrina / sobrino', inverse: 'aunt_uncle', legacy: 'family'),
  RelLabel('cousin', 'familial', 'Cousins', 'Primos', legacy: 'family'),
  RelLabel('guardian', 'familial', 'Guardian', 'Tutor/a', inverse: 'ward', style: 'parent', legacy: 'parent_figure'),
  RelLabel('ward', 'familial', 'Ward', 'Tutelado/a', inverse: 'guardian', style: 'parent', legacy: 'child_figure'),
  RelLabel('family_other', 'familial', 'Other family', 'Otra familia', legacy: 'family'),
  // Other
  RelLabel('mentor', 'other', 'Mentor', 'Mentor/a', inverse: 'mentee', style: 'mentor', legacy: 'mentor'),
  RelLabel('mentee', 'other', 'Mentee', 'Aprendiz', inverse: 'mentor', style: 'mentor'),
  RelLabel('protector', 'other', 'Protector', 'Protector/a', inverse: 'protected', style: 'protective', legacy: 'protector'),
  RelLabel('protected', 'other', 'Protected', 'Protegido/a', inverse: 'protector', style: 'protective'),
  RelLabel('caregiver', 'other', 'Caregiver', 'Cuidador/a', inverse: 'dependent', style: 'protective', legacy: 'caretaker'),
  RelLabel('dependent', 'other', 'Dependent', 'Dependiente', inverse: 'caregiver', style: 'protective'),
  RelLabel('rival', 'other', 'Rivals', 'Rivales', style: 'rival', legacy: 'rival'),
  RelLabel('enemy', 'other', 'Enemies', 'Enemigos', style: 'rival', legacy: 'rival'),
  RelLabel('colleague', 'other', 'Colleagues', 'Colegas', legacy: 'coworker'),
  RelLabel('classmate', 'other', 'Classmates', 'Compañeros de clase', legacy: 'classmate'),
  RelLabel('teammate', 'other', 'Teammates', 'Compañeros de equipo', legacy: 'coworker'),
  RelLabel('roommate', 'other', 'Roommates', 'Compañeros de cuarto'),
  RelLabel('complicated', 'other', 'Complicated', 'Complicada', style: 'complicated'),
  RelLabel('other', 'other', 'Other', 'Otra', legacy: 'other'),
];

final Map<String, RelLabel> relLabelIndex = {for (final l in relLabels) l.key: l};

/// Older single `type` values → label keys.
const legacyTypeToLabel = {
  'friend': 'friends',
  'best_friend': 'best_friends',
  'partner': 'partners',
  'crush': 'crush',
  'family': 'family_other',
  'sibling': 'sibling',
  'parent_figure': 'parent',
  'child_figure': 'child',
  'caretaker': 'caregiver',
  'protector': 'protector',
  'mentor': 'mentor',
  'classmate': 'classmate',
  'coworker': 'colleague',
  'rival': 'rival',
  'acquaintance': 'acquaintances',
  'other': 'other',
};

const relStatuses = ['active', 'exploring', 'close', 'distant', 'complicated', 'paused', 'ended'];

/// How established a connection is (suggestions are never "confirmed").
const relConfidences = ['confirmed', 'suspected', 'developing', 'uncertain', 'outdated'];

/// Dynamics, each an optional user-set value from 1 to 5.
const relDynamics = ['trust', 'closeness', 'communication', 'understanding', 'comfort', 'reliability', 'conflict', 'affection', 'familiarity', 'satisfaction'];

String relDynamicLabel(BuildContext c, String k) => switch (k) {
  'trust' => tr(c, 'Trust', 'Confianza'),
  'closeness' => tr(c, 'Emotional closeness', 'Cercanía emocional'),
  'communication' => tr(c, 'Communication', 'Comunicación'),
  'understanding' => tr(c, 'Mutual understanding', 'Comprensión mutua'),
  'comfort' => tr(c, 'Comfort', 'Comodidad'),
  'reliability' => tr(c, 'Reliability', 'Fiabilidad'),
  'conflict' => tr(c, 'Conflict frequency', 'Frecuencia de conflicto'),
  'affection' => tr(c, 'Affection', 'Afecto'),
  'familiarity' => tr(c, 'Familiarity', 'Familiaridad'),
  'satisfaction' => tr(c, 'Overall satisfaction', 'Satisfacción general'),
  _ => k,
};

String relCategoryLabel(BuildContext c, String k, [RelSettings? s]) => switch (k) {
  'romantic' => tr(c, 'Romantic', 'Romántica'),
  'platonic' => tr(c, 'Platonic', 'Platónica'),
  'familial' => tr(c, 'Familial', 'Familiar'),
  'other' => tr(c, 'Other', 'Otra'),
  _ => s?.customCategories.where((x) => x.key == k).firstOrNull?.name ?? k,
};

String relStatusText(BuildContext c, String k) => switch (k) {
  'active' => tr(c, 'Active', 'Activa'),
  'exploring' => tr(c, 'Being explored', 'Explorándose'),
  'close' => tr(c, 'Close', 'Cercana'),
  'distant' => tr(c, 'Distant', 'Distante'),
  'complicated' => tr(c, 'Complicated', 'Complicada'),
  'paused' => tr(c, 'Paused', 'En pausa'),
  'ended' => tr(c, 'Ended', 'Terminada'),
  _ => k,
};

String relConfidenceText(BuildContext c, String k) => switch (k) {
  'confirmed' => tr(c, 'Confirmed', 'Confirmada'),
  'suspected' => tr(c, 'Suspected', 'Sospechada'),
  'developing' => tr(c, 'Developing', 'En desarrollo'),
  'uncertain' => tr(c, 'Uncertain', 'Incierta'),
  'outdated' => tr(c, 'Outdated', 'Desactualizada'),
  _ => k,
};

String relStyleText(BuildContext c, String k) => switch (k) {
  'romantic' => tr(c, 'Romantic', 'Romántica'),
  'platonic' => tr(c, 'Platonic', 'Platónica'),
  'familial' => tr(c, 'Family', 'Familia'),
  'sibling' => tr(c, 'Siblings', 'Hermanos'),
  'parent' => tr(c, 'Parent / child', 'Madre/padre e hijos'),
  'mentor' => tr(c, 'Mentor / mentee', 'Mentor / aprendiz'),
  'protective' => tr(c, 'Protective', 'Protectora'),
  'rival' => tr(c, 'Rivalry', 'Rivalidad'),
  'complicated' => tr(c, 'Complicated', 'Complicada'),
  'unknown' => tr(c, 'Unknown', 'Desconocida'),
  _ => k,
};

// ───────────────────────── Settings ─────────────────────────

class RelCustomCategory {
  const RelCustomCategory(this.key, this.name, this.color);
  final String key;
  final String name;
  final int color;
  Map<String, Object?> toJson() => {'key': key, 'name': name, 'color': color};
}

class RelCustomLabel {
  const RelCustomLabel(this.key, this.name, this.category, {this.directional = false, this.inverseName});
  final String key;
  final String name;
  final String category;
  final bool directional;
  final String? inverseName;
  Map<String, Object?> toJson() => {'key': key, 'name': name, 'category': category, 'directional': directional, 'inverseName': ?inverseName};
}

/// Hub settings, stored on one synced `rel.settings` record.
class RelSettings {
  const RelSettings([this.raw = const {}, this.record]);
  final Map<String, Object?> raw;
  final TrackerRecord? record;

  T _get<T>(String k, T fallback) => raw[k] is T ? raw[k] as T : fallback;
  Map<String, Object?> _map(String k) => (raw[k] as Map?)?.cast<String, Object?>() ?? const {};

  int colorOf(String style) => (_map('colors')[style] as num?)?.toInt() ?? relStyleDefaultColors[style] ?? 0xFFB5ADA5;
  String get defaultLayout => _get('layout', 'network');
  bool get showAvatars => _get('avatars', true);
  bool get showLabels => _get('labels', false);
  bool get insightsEnabled => _get('insights', true);
  bool get hidePrivate => _get('hidePrivate', false);
  List<String> get checkinQuestions {
    final l = [for (final q in (raw['questions'] as List?) ?? const []) if (q is String && q.trim().isNotEmpty) q];
    return l.isEmpty ? defaultCheckinQuestions : l;
  }

  Map<String, Object?> get randomizer => _map('randomizer');
  bool rand(String k, [bool fallback = false]) => randomizer[k] is bool ? randomizer[k] as bool : fallback;
  List<String> get randomizerRoles => [for (final r in (randomizer['roles'] as List?) ?? const []) if (r is String) r];

  List<RelCustomCategory> get customCategories => [
    for (final c in (raw['categories'] as List?) ?? const [])
      if (c is Map && c['key'] is String) RelCustomCategory(c['key'] as String, '${c['name'] ?? c['key']}', (c['color'] as num?)?.toInt() ?? 0xFFB5ADA5),
  ];

  List<RelCustomLabel> get customLabels => [
    for (final c in (raw['customLabels'] as List?) ?? const [])
      if (c is Map && c['key'] is String)
        RelCustomLabel(c['key'] as String, '${c['name'] ?? c['key']}', '${c['category'] ?? 'other'}', directional: c['directional'] == true, inverseName: c['inverseName'] as String?),
  ];

  /// Saved node positions per layout: layout → member id → (x, y).
  Map<String, Map<String, (double, double)>> get positions {
    final out = <String, Map<String, (double, double)>>{};
    for (final e in _map('positions').entries) {
      if (e.value is! Map) continue;
      out[e.key] = {
        for (final p in (e.value as Map).entries)
          if (p.value is List && (p.value as List).length == 2) '${p.key}': (((p.value as List)[0] as num).toDouble(), ((p.value as List)[1] as num).toDouble()),
      };
    }
    return out;
  }

  List<String> get categories => [...relCategories, for (final c in customCategories) c.key];
}

const defaultCheckinQuestions = [
  'How does this relationship feel right now?',
  'Have there been any changes?',
  'Do they feel comfortable with each other?',
  'Has there been any conflict?',
  'Is communication going well?',
  'Has anything important happened?',
  'Are there any concerns?',
  'Anything else to document?',
];

final relSettingsProvider = Provider<RelSettings>((ref) {
  final rows = ref.watch(trackerKindProvider(TrackerKind.relationshipSettings)).value ?? const <TrackerRecord>[];
  final r = rows.isEmpty ? null : (rows.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt))).first;
  return RelSettings(r?.fields ?? const {}, r);
});

// ───────────────────────── Relationship view ─────────────────────────

/// A relationship record with its labels, read with backward compatibility
/// (older records only have a single `type`).
class Rel {
  Rel(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String? get a => r.memberId;
  String? get b => isInternal(r) ? r.str(RelField.otherId) : null;
  bool get internal => isInternal(r);
  String? get otherName => r.str(RelField.otherName);
  String get title => r.title;
  String get description => r.body ?? '';
  String get status => r.str(RelField.status) ?? 'active';
  String get confidence => r.str('confidence') ?? 'confirmed';
  bool get private => r.isPrivate;
  DateTime get documented => r.occurredAt ?? r.createdAt;
  DateTime get updated => r.modifiedAt;

  /// Label keys, from A's point of view ("A is B's <label>").
  List<String> get labels {
    final l = r.strings('labels');
    if (l.isNotEmpty) return l;
    final t = r.str(RelField.type);
    return [legacyTypeToLabel[t] ?? 'other'];
  }

  int? dyn(String k) {
    final m = r.fields['dyn'];
    final v = m is Map ? m[k] : null;
    if (v is num) return v.toInt().clamp(1, 5);
    // Older records kept closeness and trust on their own.
    if (k == 'closeness') return r.integer(RelField.closeness);
    if (k == 'trust') return r.integer(RelField.trust);
    return null;
  }

  /// The pair key (order-independent) for alter–alter relationships.
  String? get pairKey => internal && a != null && b != null ? pairOf(a!, b!) : null;
  bool involves(String memberId) => a == memberId || b == memberId;
  String? otherOf(String memberId) => a == memberId ? b : (b == memberId ? a : null);

  /// Labels as seen from [memberId] (directional labels are inverted for B).
  List<String> labelsFor(String memberId) => memberId == b ? [for (final l in labels) invertLabel(l)] : labels;
}

String pairOf(String x, String y) => x.compareTo(y) < 0 ? '$x|$y' : '$y|$x';

String invertLabel(String key, [RelSettings? s]) {
  final l = relLabelIndex[key];
  if (l?.inverse != null) return l!.inverse!;
  final c = s?.customLabels.where((x) => x.key == key).firstOrNull;
  if (c != null && c.directional) return '~$key';
  if (key.startsWith('~')) return key.substring(1);
  return key;
}

/// Category of a label (custom labels included).
String categoryOf(String key, RelSettings s) {
  final base = key.startsWith('~') ? key.substring(1) : key;
  return relLabelIndex[base]?.category ?? s.customLabels.where((c) => c.key == base).firstOrNull?.category ?? 'other';
}

/// Edge style of a label.
String styleOf(String key, RelSettings s) {
  final base = key.startsWith('~') ? key.substring(1) : key;
  final l = relLabelIndex[base];
  if (l?.style != null) return l!.style!;
  return switch (categoryOf(base, s)) { 'romantic' => 'romantic', 'platonic' => 'platonic', 'familial' => 'familial', 'other' => 'unknown', _ => 'unknown' };
}

String labelText(BuildContext c, String key, RelSettings s) {
  final inverse = key.startsWith('~');
  final base = inverse ? key.substring(1) : key;
  final l = relLabelIndex[base];
  if (l != null) return tr(c, l.en, l.es);
  final cl = s.customLabels.where((x) => x.key == base).firstOrNull;
  if (cl == null) return base;
  return inverse ? (cl.inverseName ?? cl.name) : cl.name;
}

/// Categories a relationship belongs to.
Set<String> relCategoriesOf(Rel r, RelSettings s) => {for (final l in r.labels) categoryOf(l, s)};

bool isComplicated(Rel r) => r.status == 'complicated' || r.confidence == 'uncertain' || r.labels.contains('complicated');
bool isExploring(Rel r) => r.status == 'exploring' || r.confidence == 'developing';

// ───────────────────────── Providers ─────────────────────────

/// Alters shown in the hub (no Unknown sentinel, no isolated subsystem
/// members — those stay inside their subsystem).
final relAltersProvider = Provider<List<Member>>((ref) {
  final hidden = ref.watch(isolatedMembersProvider).ids;
  return [
    for (final m in ref.watch(allMemberListProvider).value ?? const <Member>[])
      if (m.id != unknownSentinelMemberId && !hidden.contains(m.id)) m,
  ];
});

final relAlterIndexProvider = Provider<Map<String, Member>>((ref) => {for (final m in ref.watch(relAltersProvider)) m.id: m});

/// Every relationship visible in the hub.
final relsProvider = Provider<List<Rel>>((ref) {
  final hidden = ref.watch(isolatedMembersProvider).ids;
  final rows = ref.watch(trackerKindProvider(TrackerKind.relationship)).value ?? const <TrackerRecord>[];
  return [
    for (final r in rows)
      if (!hidden.contains(r.memberId) && !(isInternal(r) && hidden.contains(r.str(RelField.otherId)))) Rel(r),
  ];
});

final relByIdProvider = Provider.family<Rel?, String>((ref, id) => ref.watch(relsProvider).where((r) => r.id == id).firstOrNull);

/// Children of a relationship (notes, timeline events, check-ins), newest first.
final relChildrenProvider = Provider.family<List<TrackerRecord>, (String, String)>((ref, key) {
  final (kind, relId) = key;
  final rows = ref.watch(trackerKindProvider(kind)).value ?? const <TrackerRecord>[];
  return [for (final r in rows) if (r.parentId == relId) r]..sort((a, b) => (b.occurredAt ?? b.createdAt).compareTo(a.occurredAt ?? a.createdAt));
});

/// Number of notes, events and check-ins per relationship.
final relInteractionCountsProvider = Provider<Map<String, int>>((ref) {
  final out = <String, int>{};
  for (final k in [TrackerKind.relationshipNote, TrackerKind.relationshipEvent, TrackerKind.relationshipCheckin]) {
    for (final r in ref.watch(trackerKindProvider(k)).value ?? const <TrackerRecord>[]) {
      if (r.parentId != null) out[r.parentId!] = (out[r.parentId!] ?? 0) + 1;
    }
  }
  return out;
});

/// Hub statistics, always computed from records.
class RelStats {
  RelStats(List<Rel> rels, RelSettings s)
    : total = rels.length,
      alters = {for (final r in rels) ...[?r.a, ?r.b]}.length,
      romantic = rels.where((r) => relCategoriesOf(r, s).contains('romantic')).length,
      platonic = rels.where((r) => relCategoriesOf(r, s).contains('platonic')).length,
      familial = rels.where((r) => relCategoriesOf(r, s).contains('familial')).length,
      complicated = rels.where(isComplicated).length,
      exploring = rels.where(isExploring).length;
  final int total, alters, romantic, platonic, familial, complicated, exploring;
}

// ───────────────────────── Actions ─────────────────────────

class RelActions {
  RelActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  /// Finds an existing alter–alter relationship for a pair.
  Rel? existingFor(String a, String b) {
    final key = pairOf(a, b);
    return ref.read(relsProvider).where((r) => r.pairKey == key).firstOrNull;
  }

  Map<String, Object?> _fields({
    required String otherType,
    String? otherId,
    String? otherName,
    required List<String> labels,
    required String status,
    required String confidence,
    Map<String, int?> dyn = const {},
    bool mutual = true,
    List<String>? boundaries,
    String? dynamicsNote,
  }) {
    final legacy = labels.map((l) => relLabelIndex[l.startsWith('~') ? l.substring(1) : l]?.legacy).nonNulls.firstOrNull ?? 'other';
    final d = {for (final e in dyn.entries) if (e.value != null) e.key: e.value};
    return {
      RelField.otherType: otherType,
      RelField.otherId: otherId,
      RelField.otherName: otherName,
      RelField.type: legacy,
      'labels': labels,
      RelField.status: status,
      'confidence': confidence,
      'dyn': d.isEmpty ? null : d,
      RelField.closeness: d['closeness'],
      RelField.trust: d['trust'],
      RelField.mutual: otherType == RelOther.member ? mutual : null,
      RelField.boundaries: boundaries == null || boundaries.isEmpty ? null : boundaries,
      RelField.dynamics: dynamicsNote == null || dynamicsNote.trim().isEmpty ? null : dynamicsNote.trim(),
    };
  }

  /// Creates or updates a relationship. For two alters there is only ever
  /// one record: a new relationship for an existing pair adds its labels to
  /// that record instead of creating a duplicate.
  Future<String> save({
    Rel? editing,
    required String memberId,
    required String otherType,
    String? otherId,
    String? otherName,
    String title = '',
    String? description,
    required List<String> labels,
    String status = 'active',
    String confidence = 'confirmed',
    Map<String, int?> dyn = const {},
    bool mutual = true,
    bool private = false,
    List<String>? boundaries,
    String? dynamicsNote,
    DateTime? documented,
  }) async {
    if (otherType == RelOther.member && (otherId == null || otherId == memberId)) {
      throw ArgumentError('A relationship needs two different alters.');
    }
    if (labels.isEmpty) throw ArgumentError('Choose at least one label.');
    final target = editing;
    final myLabels = labels;
    if (target == null && otherType == RelOther.member) {
      final existing = existingFor(memberId, otherId!);
      if (existing != null) {
        // Merge, keeping the existing record's direction.
        final asSeen = existing.a == memberId ? labels : [for (final l in labels) invertLabel(l, ref.read(relSettingsProvider))];
        final merged = [...existing.labels, for (final l in asSeen) if (!existing.labels.contains(l)) l];
        await _t.save(existing.r.withFields({'labels': merged}));
        return existing.id;
      }
    }
    final fields = _fields(otherType: otherType, otherId: otherId, otherName: otherName, labels: myLabels, status: status, confidence: confidence, dyn: dyn, mutual: mutual, boundaries: boundaries, dynamicsNote: dynamicsNote);
    if (target == null) {
      final r = await _t.create(kind: TrackerKind.relationship, memberId: memberId, title: title, body: description, isPrivate: private, occurredAt: documented ?? DateTime.now(), fields: fields);
      return r.id;
    }
    await _t.save(target.r.copyWith(memberId: memberId, title: title, body: description, isPrivate: private, occurredAt: documented ?? target.r.occurredAt).withFields(fields));
    return target.id;
  }

  /// Deletes a relationship with its notes, events and check-ins. Returns
  /// the removed records so the deletion can be undone.
  Future<List<TrackerRecord>> delete(Rel rel) async {
    final all = await ref.read(trackerRecordsProvider.future);
    final removed = [rel.r, for (final r in all) if (r.parentId == rel.id && r.kind.startsWith('rel.')) r];
    for (final r in removed.skip(1)) {
      await _t.delete(r.id, children: false);
    }
    await _t.delete(rel.id, children: false);
    return removed;
  }

  Future<void> restore(List<TrackerRecord> records) async {
    final repo = ref.read(trackerRecordRepositoryProvider);
    for (final r in records) {
      await repo.create(r);
    }
  }

  Future<void> saveSettings(Map<String, Object?> changes) async {
    final s = ref.read(relSettingsProvider);
    if (s.record == null) {
      await _t.create(kind: TrackerKind.relationshipSettings, fields: changes);
    } else {
      await _t.save(s.record!.withFields(changes));
    }
  }

  Future<void> setRandomizer(String key, Object? value) {
    final r = {...ref.read(relSettingsProvider).randomizer, key: value};
    return saveSettings({'randomizer': r});
  }

  Future<void> savePositions(String layout, Map<String, (double, double)> pos) {
    final all = {for (final e in ref.read(relSettingsProvider).positions.entries) e.key: {for (final p in e.value.entries) p.key: [p.value.$1, p.value.$2]}};
    all[layout] = {for (final p in pos.entries) p.key: [double.parse(p.value.$1.toStringAsFixed(1)), double.parse(p.value.$2.toStringAsFixed(1))]};
    return saveSettings({'positions': all});
  }

  Future<void> clearPositions(String layout) {
    final all = {for (final e in ref.read(relSettingsProvider).positions.entries) if (e.key != layout) e.key: {for (final p in e.value.entries) p.key: [p.value.$1, p.value.$2]}};
    return saveSettings({'positions': all});
  }
}

final relActionsProvider = Provider<RelActions>(RelActions.new);


Color relColor(RelSettings s, String style) => Color(s.colorOf(style));
