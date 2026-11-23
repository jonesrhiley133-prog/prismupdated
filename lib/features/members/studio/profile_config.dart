import 'dart:convert';

import 'package:prism_plurality/shared/ui_kit.dart';

/// Profile modules that can be shown, hidden and reordered.
const profileModuleIds = ['about', 'interests', 'personality', 'gallery', 'relationships', 'fronting', 'memories', 'custom', 'music', 'links', 'pinned', 'journal', 'astro'];

String moduleLabel(BuildContext c, String id) => switch (id) {
  'about' => tr(c, 'About me', 'Sobre mí'),
  'interests' => tr(c, 'Interests', 'Intereses'),
  'personality' => tr(c, 'Personality', 'Personalidad'),
  'gallery' => tr(c, 'Gallery', 'Galería'),
  'relationships' => tr(c, 'Relationships', 'Relaciones'),
  'fronting' => tr(c, 'Fronting', 'Frente'),
  'memories' => tr(c, 'Memories', 'Recuerdos'),
  'custom' => tr(c, 'Custom cards', 'Tarjetas personalizadas'),
  'music' => tr(c, 'Music & media', 'Música y medios'),
  'links' => tr(c, 'Links', 'Enlaces'),
  'pinned' => tr(c, 'Pinned note', 'Nota fijada'),
  'journal' => tr(c, 'Journal', 'Diario'),
  'astro' => tr(c, 'Astrology', 'Astrología'),
  _ => id,
};

/// Identity fields whose label, order and privacy can be customised.
const identityFieldIds = ['altNames', 'pronounSets', 'gender', 'age', 'birthday', 'species', 'origin'];

String fieldLabel(BuildContext c, String id, [Map<String, String> custom = const {}]) {
  final v = custom[id];
  if (v != null && v.trim().isNotEmpty) return v;
  return switch (id) {
    'altNames' => tr(c, 'Also known as', 'También conocido como'),
    'pronounSets' => tr(c, 'Pronouns', 'Pronombres'),
    'gender' => tr(c, 'Gender', 'Género'),
    'age' => tr(c, 'Age', 'Edad'),
    'birthday' => tr(c, 'Birthday', 'Cumpleaños'),
    'species' => tr(c, 'Species / identity', 'Especie / identidad'),
    'origin' => tr(c, 'Origin / source', 'Origen / fuente'),
    'traits' => tr(c, 'Traits', 'Rasgos'),
    'likes' => tr(c, 'Likes', 'Le gusta'),
    'dislikes' => tr(c, 'Dislikes', 'No le gusta'),
    'hobbies' => tr(c, 'Hobbies', 'Aficiones'),
    'favMusic' => tr(c, 'Favourite music', 'Música favorita'),
    'favMedia' => tr(c, 'Favourite media', 'Medios favoritos'),
    'favColors' => tr(c, 'Favourite colours', 'Colores favoritos'),
    'favFoods' => tr(c, 'Favourite foods', 'Comidas favoritas'),
    'strengths' => tr(c, 'Strengths', 'Fortalezas'),
    'weaknesses' => tr(c, 'Weaknesses', 'Debilidades'),
    'habits' => tr(c, 'Habits & mannerisms', 'Hábitos y gestos'),
    'communication' => tr(c, 'Communication preferences', 'Preferencias de comunicación'),
    'quotes' => tr(c, 'Quotes', 'Citas'),
    'facts' => tr(c, 'Facts', 'Datos'),
    'boundaries' => tr(c, 'Boundaries', 'Límites'),
    'frontPrefs' => tr(c, 'Fronting preferences', 'Preferencias de frente'),
    'internalRoles' => tr(c, 'Internal roles', 'Roles internos'),
    'tags' => tr(c, 'Tags', 'Etiquetas'),
    'subtitle' => tr(c, 'Subtitle', 'Subtítulo'),
    'status' => tr(c, 'Status', 'Estado'),
    _ => id,
  };
}

/// List-of-text personality fields.
const personalityListIds = ['likes', 'dislikes', 'hobbies', 'favMusic', 'favMedia', 'favColors', 'favFoods', 'strengths', 'weaknesses', 'habits', 'communication', 'quotes', 'facts', 'boundaries'];

/// Keys that hold appearance & layout only (what templates carry).
const appearanceKeys = {'appearance', 'modules', 'labels', 'fieldOrder'};

/// One role pill.
class ProfileRole {
  const ProfileRole({required this.name, this.color, this.style = 'soft', this.visible = true});
  final String name;
  final int? color;
  final String style; // soft, solid, outline, glow
  final bool visible;
  Map<String, Object?> toJson() => {'name': name, 'color': ?color, 'style': style, 'visible': visible};
  static ProfileRole? fromJson(Object? v) {
    if (v is String && v.trim().isNotEmpty) return ProfileRole(name: v.trim());
    if (v is! Map || v['name'] is! String) return null;
    return ProfileRole(name: v['name'] as String, color: (v['color'] as num?)?.toInt(), style: v['style'] as String? ?? 'soft', visible: v['visible'] != false);
  }

  ProfileRole copyWith({String? name, int? color, bool clearColor = false, String? style, bool? visible}) =>
      ProfileRole(name: name ?? this.name, color: clearColor ? null : (color ?? this.color), style: style ?? this.style, visible: visible ?? this.visible);
}

/// Splits role input: spaces separate roles, quotes keep multi-word roles.
List<String> splitRoles(String input) {
  final out = <String>[];
  for (final m in RegExp(r'"([^"]+)"|“([^”]+)”|([^\s,]+)').allMatches(input)) {
    final v = (m.group(1) ?? m.group(2) ?? m.group(3) ?? '').trim();
    if (v.isNotEmpty) out.add(v);
  }
  return out;
}

/// The extended profile (stored as JSON on a `member.profile` record).
/// Unknown keys are kept as-is so newer data is never lost.
class ProfileConfig {
  const ProfileConfig(this.data);
  factory ProfileConfig.empty() => const ProfileConfig({});
  final Map<String, Object?> data;

  static Map<String, Object?> _deep(Map m) => jsonDecode(jsonEncode(m)) as Map<String, Object?>;
  ProfileConfig clone() => ProfileConfig(_deep(data));

  Object? operator [](String k) => data[k];
  String str(String k) => (data[k] as String?) ?? '';
  List<String> list(String k) => [for (final v in (data[k] as List?) ?? const []) if (v is String) v];
  Map<String, Object?> map(String k) => (data[k] as Map?)?.cast<String, Object?>() ?? <String, Object?>{};

  ProfileConfig set(String k, Object? v) {
    final d = _deep(data);
    if (v == null || (v is String && v.isEmpty) || (v is List && v.isEmpty)) {
      d.remove(k);
    } else {
      d[k] = v;
    }
    return ProfileConfig(d);
  }

  ProfileConfig setIn(String group, String k, Object? v) {
    final g = map(group);
    if (v == null) {
      g.remove(k);
    } else {
      g[k] = v;
    }
    return set(group, g.isEmpty ? null : g);
  }

  List<ProfileRole> get roles => [for (final v in (data['roles'] as List?) ?? const []) ?ProfileRole.fromJson(v)];
  ProfileConfig withRoles(List<ProfileRole> r) => set('roles', [for (final x in r) x.toJson()]);

  /// Traits with intensity 1–5.
  List<(String, int)> get traits => [
    for (final v in (data['traits'] as List?) ?? const [])
      if (v is Map && v['name'] is String) (v['name'] as String, ((v['level'] as num?) ?? 3).toInt().clamp(1, 5)),
  ];
  ProfileConfig withTraits(List<(String, int)> t) => set('traits', [for (final (n, l) in t) {'name': n, 'level': l}]);

  List<Map<String, Object?>> records(String k) => [for (final v in (data[k] as List?) ?? const []) if (v is Map) v.cast<String, Object?>()];

  // Appearance
  Map<String, Object?> get appearance => map('appearance');
  Object? look(String k) => appearance[k];
  String lookStr(String k, String fallback) => (appearance[k] as String?) ?? fallback;
  double lookNum(String k, double fallback) => (appearance[k] as num?)?.toDouble() ?? fallback;
  int? lookColor(String k) => (appearance[k] as num?)?.toInt();
  ProfileConfig withLook(String k, Object? v) => setIn('appearance', k, v);

  /// Modules in display order with visibility; new modules are appended.
  List<(String, bool)> get modules {
    final raw = (data['modules'] as List?) ?? const [];
    final out = <(String, bool)>[];
    for (final v in raw) {
      if (v is Map && v['id'] is String && profileModuleIds.contains(v['id'])) out.add((v['id'] as String, v['visible'] != false));
    }
    for (final id in profileModuleIds) {
      if (!out.any((e) => e.$1 == id)) out.add((id, const {'about', 'interests', 'personality', 'custom', 'pinned', 'links', 'music', 'gallery', 'astro'}.contains(id)));
    }
    return out;
  }

  ProfileConfig withModules(List<(String, bool)> m) => set('modules', [for (final (id, v) in m) {'id': id, 'visible': v}]);

  Map<String, String> get labels => map('labels').map((k, v) => MapEntry(k, '$v'));
  List<String> get fieldOrder {
    final o = list('fieldOrder').where(identityFieldIds.contains).toList();
    for (final f in identityFieldIds) {
      if (!o.contains(f)) o.add(f);
    }
    return o;
  }

  /// public / system / private
  String privacyOf(String field) => (map('privacy')[field] as String?) ?? 'public';

  /// Only appearance and layout, no personal information.
  Map<String, Object?> templatePart() => {for (final k in appearanceKeys) if (data.containsKey(k)) k: data[k]};

  ProfileConfig applyTemplate(Map<String, Object?> t) {
    var c = clone();
    for (final k in appearanceKeys) {
      c = c.set(k, t[k]);
    }
    return c;
  }
}

/// Built-in appearance presets.
List<(String, String, String, Map<String, Object?>)> profilePresets = [
  ('starlight', 'Starlight', 'Luz de estrellas', {'appearance': {'bgMode': 'gradient', 'bg1': 0xFF120E2B, 'bg2': 0xFF3A1F5C, 'accent': 0xFFB9A6FF, 'font': 'display', 'border': 'glow', 'avatarShape': 'circle', 'decorations': ['✦', '🌙'], 'layout': 'cards', 'bannerOverlay': 0.35}}),
  ('pastel', 'Soft pastel', 'Pastel suave', {'appearance': {'bgMode': 'gradient', 'bg1': 0xFFFFE3F1, 'bg2': 0xFFE3ECFF, 'accent': 0xFFFF8FD8, 'font': 'rounded', 'border': 'thin', 'avatarShape': 'rounded', 'decorations': ['🌸', '☁️'], 'layout': 'grid', 'bannerOverlay': 0.1}}),
  ('midnight', 'Midnight', 'Medianoche', {'appearance': {'bgMode': 'gradient', 'bg1': 0xFF000000, 'bg2': 0xFF0B1A33, 'accent': 0xFF7FB6FF, 'font': 'standard', 'border': 'none', 'avatarShape': 'circle', 'layout': 'full', 'bannerOverlay': 0.5}}),
  ('forest', 'Forest', 'Bosque', {'appearance': {'bgMode': 'gradient', 'bg1': 0xFF0E1F17, 'bg2': 0xFF22402B, 'accent': 0xFF9EE37F, 'font': 'serif', 'border': 'double', 'avatarShape': 'hexagon', 'decorations': ['🌿', '🍄'], 'layout': 'sidebar', 'bannerOverlay': 0.3}}),
  ('minimal', 'Minimal', 'Minimalista', {'appearance': {'bgMode': 'none', 'font': 'standard', 'border': 'none', 'avatarShape': 'square', 'layout': 'full', 'bannerOverlay': 0.0}}),
];

/// The profile record for a member (null when none was made yet).
final memberProfileRecordProvider = Provider.family<TrackerRecord?, String>((ref, memberId) {
  final rows = ref.watch(trackerKindProvider(TrackerKind.memberProfile)).value ?? const <TrackerRecord>[];
  return rows.where((r) => r.parentId == memberId).firstOrNull;
});

final memberProfileProvider = Provider.family<ProfileConfig?, String>((ref, memberId) {
  final r = ref.watch(memberProfileRecordProvider(memberId));
  if (r == null) return null;
  final raw = r.fields['cfg'];
  return raw is Map ? ProfileConfig(raw.cast<String, Object?>()) : ProfileConfig.empty();
});

final profileTemplatesProvider = Provider<List<TrackerRecord>>((ref) => ref.watch(trackerKindProvider(TrackerKind.profileTemplate)).value ?? const []);

class ProfileStudioActions {
  ProfileStudioActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<void> saveProfile(String memberId, ProfileConfig cfg) async {
    final existing = (await ref.read(trackerRecordsProvider.future)).where((r) => r.kind == TrackerKind.memberProfile && r.parentId == memberId).firstOrNull;
    if (existing == null) {
      await _t.create(kind: TrackerKind.memberProfile, parentId: memberId, memberId: memberId, fields: {'cfg': cfg.data});
    } else {
      await _t.save(existing.withFields({'cfg': cfg.data}));
    }
  }

  Future<void> saveTemplate(String name, ProfileConfig cfg) => _t.create(kind: TrackerKind.profileTemplate, title: name, fields: {'cfg': cfg.templatePart()});

  Future<void> deleteTemplate(String id) => _t.delete(id);
}

final profileStudioActionsProvider = Provider<ProfileStudioActions>(ProfileStudioActions.new);
