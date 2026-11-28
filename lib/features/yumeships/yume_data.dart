import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/features/appearance/models/look.dart'
    show BgSpec;
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/fronting_roles/roles_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Yumeships: a creative organiser for fictional relationships (yumeshipping,
/// self-shipping, F/Os), creative sonas and fandom keepsakes. Every piece is
/// a synced, versioned tracker record, so it works offline and comes along
/// with sync, backups and exports like the rest of Prism.
///
/// Fictional others and sonas are never alters: they live only here, never
/// appear in fronting, and never count towards fronting statistics.
const yumeSchemaVersion = 1;

const _uuid = Uuid();
String yumeId() => _uuid.v4();

List<String> _strs(Object? v) => [
  for (final x in (v as List?) ?? const [])
    if (x != null && '$x'.isNotEmpty) '$x',
];
List<Map<String, Object?>> _maps(Object? v) => [
  for (final x in (v as List?) ?? const [])
    if (x is Map) x.cast<String, Object?>(),
];
String _s(Object? v) => v == null ? '' : '$v';
int? _i(Object? v) => (v as num?)?.toInt();
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');

// ── Vocabulary ──────────────────────────────────────────────────────────

/// Relationship types. A ship can have several (and a custom one).
const yumeRelTypes = <String, (String, String, String)>{
  'romantic': ('Romantic', 'Romántica', '💞'),
  'platonic': ('Platonic', 'Platónica', '🤝'),
  'familial': ('Familial', 'Familiar', '🏡'),
  'queerplatonic': ('Queerplatonic', 'Queerplatónica', '🌈'),
  'comfort': ('Comfort character', 'Personaje de consuelo', '🧸'),
  'custom': ('Custom', 'Personalizada', '✨'),
};

/// Sharing boundaries.
const yumeSharing = <String, (String, String, String)>{
  'sharing': ('Sharing', 'Comparte', 'Happy for others to ship them too.'),
  'selective': (
    'Selective sharing',
    'Comparte con algunos',
    'Okay with some people or some kinds of ships.',
  ),
  'nonsharing': (
    'Non-sharing',
    'No comparte',
    'Prefers not to see others ship them.',
  ),
  'undecided': ('Undecided', 'Sin decidir', 'Still figuring it out.'),
  'custom': ('Custom boundary', 'Límite propio', 'Described in your words.'),
};

/// Suggested statuses (any text is allowed).
const yumeStatuses = [
  'Together',
  'Dating',
  'Engaged',
  'Married',
  'Crush',
  'Best friends',
  'Found family',
  'Slow burn',
  'It’s complicated',
  'On a break',
];

/// Suggested tropes for quick tagging.
const yumeTropes = [
  'Slow burn',
  'Enemies to lovers',
  'Friends to lovers',
  'Soulmates',
  'Fake dating',
  'Forbidden love',
  'Childhood friends',
  'Grumpy x sunshine',
  'Protective',
  'Fluff',
  'Hurt/comfort',
  'Domestic',
  'Reincarnation',
  'Time travel',
  'Bodyguard',
  'Found family',
  'Mutual pining',
  'Arranged marriage',
  'Rivals',
  'Second chance',
];

/// Visibility inside the system. Nothing in Yumeships is ever shared outside
/// Prism unless you export it yourself.
const yumeVisibilities = <String, (String, String, String)>{
  'private': (
    'Private',
    'Privado',
    'Only its owners (and collaborators) can open it.',
  ),
  'system': ('System-visible', 'Visible al sistema', 'Anyone in the system.'),
  'selective': (
    'Selected alters',
    'Alters elegidos',
    'Owners plus the alters you choose.',
  ),
};

/// Event types for anniversaries and celebrations.
const yumeEventTypes = <String, (String, String, String)>{
  'anniversary': ('Anniversary', 'Aniversario', '💍'),
  'birthday': ('Character birthday', 'Cumpleaños del personaje', '🎂'),
  'appreciation': ('Appreciation day', 'Día de aprecio', '💐'),
  'challenge': ('Creative challenge', 'Reto creativo', '🎨'),
  'deadline': ('Commission deadline', 'Fecha de encargo', '⏳'),
  'celebration': ('Celebration', 'Celebración', '🎉'),
  'custom': ('Custom', 'Personalizado', '✨'),
};

const yumeRecurrences = <String, String>{
  'none': 'Once',
  'yearly': 'Every year',
  'monthly': 'Every month',
  'weekly': 'Every week',
};

/// When a notification goes out, as calendar alert minutes before the start
/// of an all-day event (negative = later on the day itself).
const yumeAlertLeads = <String, (String, int)>{
  'day': ('On the day (9 am)', -540),
  'dayBefore': ('The day before (9 am)', 900),
  'week': ('A week before (9 am)', 9540),
};

/// Gallery entry types.
const yumeMediaTypes = <String, (String, String, String)>{
  'art': ('Fanart', 'Fanart', '🎨'),
  'commission': ('Commission', 'Encargo', '🖌️'),
  'photo': ('Photo', 'Foto', '📷'),
  'gif': ('GIF', 'GIF', '🎞️'),
  'video': ('Video', 'Vídeo', '🎬'),
  'audio': ('Audio', 'Audio', '🎧'),
  'moodboard': ('Moodboard', 'Moodboard', '🧩'),
  'letter': ('Letter', 'Carta', '💌'),
  'story': ('Story or scenario', 'Historia o escenario', '📖'),
};

/// Sections of a yumeship profile page, in their default order.
const yumeShipSections = <String, (String, String)>{
  'about': ('About', 'Sobre'),
  'fos': ('Fictional others', 'Personajes'),
  'sonas': ('Sonas & self-inserts', 'Sonas'),
  'relationship': ('Relationship', 'Relación'),
  'dates': ('Significant dates', 'Fechas'),
  'boundaries': ('Sharing & boundaries', 'Límites'),
  'dynamics': ('Dynamics & tropes', 'Dinámicas'),
  'headcanons': ('Headcanons', 'Headcanons'),
  'lore': ('Lore & backstory', 'Historia'),
  'aus': ('Alternate universes', 'Universos alternos'),
  'timeline': ('Timeline', 'Cronología'),
  'gallery': ('Gallery & media', 'Galería'),
  'scrapbooks': ('Scrapbooks', 'Álbumes'),
  'songs': ('Songs & playlists', 'Canciones'),
  'events': ('Anniversaries & events', 'Eventos'),
  'creations': ('Creative entries', 'Creaciones'),
  'custom': ('Custom fields', 'Campos propios'),
  'links': ('Connected records', 'Registros conectados'),
};

/// Dashboard sections, in their default order.
const yumeDashSections = <String, (String, String)>{
  'featured': ('Featured', 'Destacados'),
  'upcoming': ('Upcoming dates', 'Próximas fechas'),
  'collections': ('Collections', 'Colecciones'),
  'ships': ('Yumeships', 'Yumeships'),
  'sonas': ('Sonas', 'Sonas'),
  'recent': ('Recent creations', 'Creaciones recientes'),
};

const yumeViews = <String, (String, String)>{
  'gallery': ('Gallery', 'Galería'),
  'scrapbook': ('Scrapbook', 'Álbum'),
  'list': ('Compact list', 'Lista compacta'),
  'cards': ('Detailed cards', 'Tarjetas detalladas'),
  'shelves': ('Collection shelves', 'Estantes'),
};

/// Fields that can appear on an exported or shared profile. Off by default
/// except the basics; everything is reviewed before anything leaves Prism.
const yumeExportFields = <String, String>{
  'names': 'Ship and character names',
  'source': 'Fictional source',
  'relTypes': 'Relationship type',
  'status': 'Status',
  'anniversary': 'Anniversary',
  'sharing': 'Sharing boundary',
  'about': 'About',
  'tropes': 'Tropes',
  'headcanons': 'Headcanons',
  'lore': 'Lore & backstory',
  'sonas': 'Sonas',
  'owners': 'Alter names',
  'pictures': 'Pictures',
};
const yumeDefaultExport = {'names', 'source', 'relTypes', 'status', 'pictures'};

// ── Aesthetic presets ───────────────────────────────────────────────────

/// A look for a yumeship or sona. Presets only tint accents, frames and
/// type: surfaces and text always come from the app's current theme.
@immutable
class YumePreset {
  const YumePreset({
    required this.id,
    required this.name,
    required this.accent,
    required this.card,
    required this.frame,
    required this.ribbon,
    required this.font,
    required this.symbol,
    required this.stickers,
  });
  final String id, name;
  final int? accent;
  final String card, frame, ribbon;
  final String? font;
  final String symbol;
  final List<String> stickers;
}

const yumePresets = <YumePreset>[
  YumePreset(
    id: 'romantic',
    name: 'Romantic Scrapbook',
    accent: 0xFFE26D8A,
    card: 'paper',
    frame: 'tape',
    ribbon: 'bow',
    font: 'g:Caveat',
    symbol: '💞',
    stickers: ['💌', '🌹', '💕'],
  ),
  YumePreset(
    id: 'celestial',
    name: 'Celestial',
    accent: 0xFF7C83FD,
    card: 'glass',
    frame: 'stars',
    ribbon: 'none',
    font: 'g:Cinzel',
    symbol: '🌙',
    stickers: ['✨', '🌙', '⭐'],
  ),
  YumePreset(
    id: 'kawaii',
    name: 'Kawaii Journal',
    accent: 0xFFFF8FBF,
    card: 'soft',
    frame: 'dotted',
    ribbon: 'bow',
    font: 'g:Mochiy Pop One',
    symbol: '🎀',
    stickers: ['🎀', '🍓', '🐰'],
  ),
  YumePreset(
    id: 'vintage',
    name: 'Vintage Letters',
    accent: 0xFFA0785A,
    card: 'paper',
    frame: 'stamp',
    ribbon: 'wax',
    font: 'g:IM Fell English',
    symbol: '✉️',
    stickers: ['✉️', '🪶', '🕯️'],
  ),
  YumePreset(
    id: 'gothic',
    name: 'Gothic Romance',
    accent: 0xFF9E2A4B,
    card: 'outlined',
    frame: 'ornate',
    ribbon: 'rose',
    font: 'g:UnifrakturCook',
    symbol: '🥀',
    stickers: ['🥀', '🦇', '🕯️'],
  ),
  YumePreset(
    id: 'cottage',
    name: 'Cottagecore',
    accent: 0xFF6E9B5C,
    card: 'paper',
    frame: 'leaf',
    ribbon: 'twine',
    font: 'g:Lora',
    symbol: '🌼',
    stickers: ['🌿', '🍄', '🌼'],
  ),
  YumePreset(
    id: 'dreamcore',
    name: 'Dreamcore',
    accent: 0xFFA48BFF,
    card: 'glass',
    frame: 'cloud',
    ribbon: 'none',
    font: 'g:Quicksand',
    symbol: '☁️',
    stickers: ['☁️', '🌈', '🫧'],
  ),
  YumePreset(
    id: 'manga',
    name: 'Manga',
    accent: 0xFFE5484D,
    card: 'outlined',
    frame: 'panel',
    ribbon: 'none',
    font: 'g:Dela Gothic One',
    symbol: '💥',
    stickers: ['💥', '💢', '✨'],
  ),
  YumePreset(
    id: 'minimal',
    name: 'Minimalist',
    accent: null,
    card: 'flat',
    frame: 'none',
    ribbon: 'none',
    font: null,
    symbol: '♡',
    stickers: [],
  ),
];

YumePreset? yumePresetById(String? id) =>
    yumePresets.where((p) => p.id == id).firstOrNull;

const yumeCardStyles = <String, String>{
  'flat': 'Flat',
  'soft': 'Soft',
  'outlined': 'Outlined',
  'paper': 'Paper',
  'glass': 'Glass',
};
const yumeFrames = <String, String>{
  'none': 'None',
  'tape': 'Washi tape',
  'stars': 'Stars',
  'dotted': 'Dotted',
  'stamp': 'Postage stamp',
  'ornate': 'Ornate',
  'leaf': 'Leaves',
  'cloud': 'Clouds',
  'panel': 'Comic panel',
};
const yumeRibbons = <String, (String, String)>{
  'none': ('None', ''),
  'bow': ('Bow', '🎀'),
  'wax': ('Wax seal', '🔴'),
  'rose': ('Rose', '🌹'),
  'twine': ('Twine', '🪢'),
  'heart': ('Heart', '💗'),
  'star': ('Star', '⭐'),
};
const yumeLayouts = <String, String>{
  'classic': 'Classic',
  'magazine': 'Magazine',
  'journal': 'Journal',
};

// ── Shared item helpers ─────────────────────────────────────────────────

/// One fictional other within a ship.
@immutable
class YumeFo {
  const YumeFo({
    required this.id,
    this.name = '',
    this.nicknames = const [],
    this.pronouns = '',
    this.source = '',
    this.bio = '',
    this.avatar,
    this.birthday,
  });
  final String id, name, pronouns, source, bio;
  final List<String> nicknames;
  final String? avatar;
  final DateTime? birthday;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'nicknames': nicknames,
    'pronouns': pronouns,
    'source': source,
    'bio': bio,
    'avatar': avatar,
    'birthday': birthday?.toIso8601String(),
  };
  static YumeFo fromJson(Map<String, Object?> j) => YumeFo(
    id: _s(j['id']).isEmpty ? yumeId() : _s(j['id']),
    name: _s(j['name']),
    nicknames: _strs(j['nicknames']),
    pronouns: _s(j['pronouns']),
    source: _s(j['source']),
    bio: _s(j['bio']),
    avatar: j['avatar'] as String?,
    birthday: _date(j['birthday']),
  );
}

/// Label + value pairs (custom fields, dates, outfits, AUs, timeline...).
@immutable
class YumeEntry {
  const YumeEntry({
    required this.id,
    this.title = '',
    this.text = '',
    this.date,
    this.media,
    this.link = '',
  });
  final String id, title, text, link;
  final DateTime? date;
  final String? media;
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'text': text,
    'date': date?.toIso8601String(),
    'media': media,
    'link': link,
  };
  static YumeEntry fromJson(Map<String, Object?> j) => YumeEntry(
    id: _s(j['id']).isEmpty ? yumeId() : _s(j['id']),
    title: _s(j['title'] ?? j['label'] ?? j['name']),
    text: _s(j['text'] ?? j['value'] ?? j['notes']),
    date: _date(j['date']),
    media: j['media'] as String?,
    link: _s(j['link']),
  );
  YumeEntry copyWith({
    String? title,
    String? text,
    DateTime? date,
    bool clearDate = false,
    String? media,
    bool clearMedia = false,
    String? link,
  }) => YumeEntry(
    id: id,
    title: title ?? this.title,
    text: text ?? this.text,
    date: clearDate ? null : (date ?? this.date),
    media: clearMedia ? null : (media ?? this.media),
    link: link ?? this.link,
  );
}

List<YumeEntry> _entries(Object? v) => [
  for (final m in _maps(v)) YumeEntry.fromJson(m),
];

// ── Privacy ─────────────────────────────────────────────────────────────

/// Whether [viewer] (the alter fronting now, or null) may open an item.
/// Items with no owners belong to the whole system.
bool yumeCanView({
  required String visibility,
  required List<String> owners,
  required List<String> collaborators,
  required List<String> shared,
  required String? viewer,
}) {
  if (owners.isEmpty || visibility == 'system') return true;
  if (viewer == null) return false;
  if (owners.contains(viewer) || collaborators.contains(viewer)) return true;
  return visibility == 'selective' && shared.contains(viewer);
}

/// Common access fields shared by ships, sonas, collections and creations.
mixin YumeAccess {
  TrackerRecord get r;
  List<String> get owners => _strs(r.fields['owners']);
  List<String> get collaborators => _strs(r.fields['collab']);
  List<String> get shared => _strs(r.fields['shared']);
  String get visibility {
    final v = _s(r.fields['visibility']);
    return yumeVisibilities.containsKey(v) ? v : 'system';
  }

  bool get locked => r.flag('locked');
  bool canView(String? viewer) => yumeCanView(
    visibility: visibility,
    owners: owners,
    collaborators: collaborators,
    shared: shared,
    viewer: viewer,
  );

  /// Owners and collaborators can edit; system-owned items anyone can.
  bool canEdit(String? viewer) =>
      owners.isEmpty ||
      (viewer != null &&
          (owners.contains(viewer) || collaborators.contains(viewer)));
}

/// Look fields shared by ships and sonas.
mixin YumeLook {
  TrackerRecord get r;
  String get presetId => _s(r.fields['theme']);
  YumePreset? get preset => yumePresetById(presetId);
  int? get accent => _i(r.fields['accent']) ?? preset?.accent;
  String? get font {
    final f = _s(r.fields['font']);
    return f.isEmpty ? preset?.font : (f == 'default' ? null : f);
  }

  String get symbol {
    final s = _s(r.fields['symbol']);
    return s.isEmpty ? (preset?.symbol ?? '♡') : s;
  }

  String get card {
    final c = _s(r.fields['card']);
    return yumeCardStyles.containsKey(c) ? c : (preset?.card ?? 'soft');
  }

  String get frame {
    final f = _s(r.fields['frame']);
    return yumeFrames.containsKey(f) ? f : (preset?.frame ?? 'none');
  }

  String get ribbon {
    final f = _s(r.fields['ribbon']);
    return yumeRibbons.containsKey(f) ? f : (preset?.ribbon ?? 'none');
  }

  List<String> get stickers {
    final raw = r.fields['stickers'];
    return raw is List ? _strs(raw) : (preset?.stickers ?? const []);
  }

  BgSpec? get background {
    final b = r.fields['bg'];
    return b is Map ? BgSpec.fromJson(b) : null;
  }

  /// A living decoration look (`<genre>.<index>`) shown on the profile.
  String? get living {
    final l = _s(r.fields['living']);
    return l.isEmpty ? null : l;
  }

  String? get avatar => r.fields['avatar'] as String?;
  String? get banner => r.fields['banner'] as String?;
}

// ── Records ─────────────────────────────────────────────────────────────

class YumeShip with YumeAccess, YumeLook {
  YumeShip(this.r);
  @override
  final TrackerRecord r;
  String get id => r.id;
  List<YumeFo> get fos => [
    for (final m in _maps(r.fields['fos'])) YumeFo.fromJson(m),
  ];
  String get name {
    if (r.title.trim().isNotEmpty) return r.title.trim();
    final n = fos.map((f) => f.name).where((n) => n.isNotEmpty).join(' & ');
    return n.isEmpty ? 'Untitled yumeship' : n;
  }

  String get shipName => _s(r.fields['shipName']);
  String get about => r.body ?? '';
  List<String> get sonaIds => _strs(r.fields['sonaIds']);
  List<String> get relTypes => _strs(r.fields['relTypes']);
  String get relCustom => _s(r.fields['relCustom']);
  String get status => _s(r.fields['status']);
  DateTime? get anniversary => _date(r.fields['anniversary']);
  List<YumeEntry> get dates => _entries(r.fields['dates']);
  String get sharing {
    final s = _s(r.fields['sharing']);
    return yumeSharing.containsKey(s) ? s : 'undecided';
  }

  String get sharingNote => _s(r.fields['sharingNote']);
  String get boundaryNotice => _s(r.fields['boundary']);
  String get dynamics => _s(r.fields['dynamics']);
  List<String> get tropes => _strs(r.fields['tropes']);
  List<YumeEntry> get headcanons => _entries(r.fields['headcanons']);
  String get lore => _s(r.fields['lore']);
  String get backstory => _s(r.fields['backstory']);
  List<String> get matchingIcons => _strs(r.fields['icons']);
  List<YumeEntry> get customFields => _entries(r.fields['custom']);
  String get category => _s(r.fields['category']);
  List<String> get labels => _strs(r.fields['labels']);
  List<String> get tags => r.tags;
  List<YumeEntry> get aus => _entries(r.fields['aus']);
  List<YumeEntry> get timeline => _entries(r.fields['timeline']);
  List<YumeEntry> get songs => _entries(r.fields['songs']);
  List<String> get playlists => _strs(r.fields['playlists']);
  bool get favorite => r.flag('favorite');
  bool get pinned => r.isPinned;
  bool get archived => r.flag('archived');
  bool get notify => r.fields['notify'] != false;
  String get layout {
    final l = _s(r.fields['layout']);
    return yumeLayouts.containsKey(l) ? l : 'classic';
  }

  Set<String> get exportFields {
    final raw = r.fields['export'];
    return raw is List ? _strs(raw).toSet() : yumeDefaultExport;
  }

  /// Profile sections in order with their visibility.
  List<(String, bool)> get sections {
    final order = _strs(r.fields['sections']);
    final hidden = _strs(r.fields['hidden']).toSet();
    return [
      for (final id in order)
        if (yumeShipSections.containsKey(id)) (id, !hidden.contains(id)),
      for (final id in yumeShipSections.keys)
        if (!order.contains(id)) (id, !hidden.contains(id)),
    ];
  }

  /// Every source mentioned by this ship's characters.
  Set<String> get sources => {
    for (final f in fos)
      if (f.source.trim().isNotEmpty) f.source.trim(),
  };

  DateTime? get lastOpened => _date(r.fields['opened']);
  int get order => r.sortOrder;

  String searchText() => [
    name,
    shipName,
    status,
    category,
    ...labels,
    ...tags,
    ...tropes,
    for (final f in fos) ...[f.name, f.source, ...f.nicknames],
  ].join(' ').toLowerCase();
}

class YumeSona with YumeAccess, YumeLook {
  YumeSona(this.r);
  @override
  final TrackerRecord r;
  String get id => r.id;
  String get name => r.title.trim().isEmpty ? 'Unnamed sona' : r.title.trim();
  String get bio => r.body ?? '';
  List<String> get nicknames => _strs(r.fields['nicknames']);
  String get pronouns => _s(r.fields['pronouns']);
  String get appearance => _s(r.fields['appearance']);
  String get personality => _s(r.fields['personality']);
  String get lore => _s(r.fields['lore']);
  List<YumeEntry> get outfits => _entries(r.fields['outfits']);
  List<YumeEntry> get aus => _entries(r.fields['aus']);
  List<YumeEntry> get customFields => _entries(r.fields['custom']);
  String? get refSheet => r.fields['ref'] as String?;
  List<String> get gallery => _strs(r.fields['gallery']);
  bool get favorite => r.flag('favorite');
  List<String> get tags => r.tags;
}

/// Collection types. Smart types fill themselves from a rule; every type
/// can also hold hand-picked yumeships in your own order.
const yumeCollectionTypes = <String, (String, String, String)>{
  'romantic': ('Romantic F/Os', 'F/Os románticos', '💞'),
  'platonic': ('Platonic F/Os', 'F/Os platónicos', '🤝'),
  'familial': ('Familial F/Os', 'F/Os familiares', '🏡'),
  'comfort': ('Comfort characters', 'Personajes de consuelo', '🧸'),
  'primary': ('Primary ships', 'Ships principales', '👑'),
  'archived': ('Archived ships', 'Ships archivados', '🗄️'),
  'source': ('From one source', 'De una obra', '📚'),
  'favorites': ('Favorites', 'Favoritos', '⭐'),
  'custom': ('Custom', 'Personalizada', '✨'),
};

class YumeCollection with YumeAccess {
  YumeCollection(this.r);
  @override
  final TrackerRecord r;
  String get id => r.id;
  String get name => r.title.trim().isEmpty
      ? (yumeCollectionTypes[type]?.$1 ?? 'Collection')
      : r.title.trim();
  String get description => r.body ?? '';
  String get type {
    final t = _s(r.fields['type']);
    return yumeCollectionTypes.containsKey(t) ? t : 'custom';
  }

  String get emoji {
    final e = _s(r.fields['emoji']);
    return e.isEmpty ? (yumeCollectionTypes[type]?.$3 ?? '✨') : e;
  }

  String? get cover => r.fields['cover'] as String?;
  int? get accent => _i(r.fields['accent']);
  List<String> get shipIds => _strs(r.fields['shipIds']);

  /// For 'source' collections: which fictional source fills it.
  String get source => _s(r.fields['source']);
  bool get smart => r.fields['smart'] != false && type != 'custom';
  int get order => r.sortOrder;
  bool get pinned => r.isPinned;

  /// Whether [s] belongs here: hand-picked, or by the collection's rule.
  bool includes(YumeShip s) {
    if (shipIds.contains(s.id)) return true;
    if (!smart) return false;
    return switch (type) {
      'romantic' ||
      'platonic' ||
      'familial' ||
      'comfort' => s.relTypes.contains(type) && !s.archived,
      'primary' => s.pinned && !s.archived,
      'archived' => s.archived,
      'favorites' => s.favorite,
      'source' =>
        source.trim().isNotEmpty &&
            s.sources.any(
              (x) => x.toLowerCase() == source.trim().toLowerCase(),
            ),
      _ => false,
    };
  }
}

/// Creative Studio tools.
const yumeTools = <String, (String, String, String, String)>{
  'introCard': (
    'Ship intro card',
    'Tarjeta de presentación',
    '🪪',
    'A shareable card introducing a ship.',
  ),
  'chart': (
    'Relationship chart',
    'Tabla de relación',
    '📊',
    'Dynamics sheets with sliders and notes.',
  ),
  'bingo': (
    'Ship bingo',
    'Bingo de ship',
    '🎯',
    'Mark off the tropes you love.',
  ),
  'questionnaire': (
    'Questionnaire',
    'Cuestionario',
    '📝',
    'Answer yumeship question sets.',
  ),
  'matchingPfp': (
    'Matching icons',
    'Iconos a juego',
    '🖼️',
    'Pair up two pictures with matching frames.',
  ),
  'moodboard': (
    'Moodboard',
    'Moodboard',
    '🧩',
    'An aesthetic board of pictures, words and colours.',
  ),
  'fic': (
    'Fic & scenario organizer',
    'Fics y escenarios',
    '📚',
    'Track stories and scenarios from idea to done.',
  ),
  'timeline': (
    'Development timeline',
    'Cronología',
    '🗓️',
    'How the relationship grew, step by step.',
  ),
  'headcanons': (
    'Headcanon collection',
    'Headcanons',
    '💭',
    'Little truths, sorted by theme.',
  ),
  'wishlist': (
    'Art & commission wishlist',
    'Lista de deseos',
    '🛍️',
    'Pieces you want, who to ask, and deadlines.',
  ),
  'appreciation': (
    'Appreciation journal',
    'Diario de aprecio',
    '💐',
    'Dated notes about what you love.',
  ),
  'prompts': (
    'Prompt collection',
    'Ideas creativas',
    '💡',
    'Creative prompts to draw or write.',
  ),
};

class YumeCreation with YumeAccess {
  YumeCreation(this.r);
  @override
  final TrackerRecord r;
  String get id => r.id;
  String get tool {
    final t = _s(r.fields['tool']);
    return yumeTools.containsKey(t) ? t : 'prompts';
  }

  String get title => r.title.trim().isEmpty
      ? (yumeTools[tool]?.$1 ?? 'Creation')
      : r.title.trim();
  List<String> get shipIds => _strs(r.fields['shipIds']);
  List<String> get sonaIds => _strs(r.fields['sonaIds']);
  Map<String, Object?> get data =>
      (r.fields['data'] as Map?)?.cast<String, Object?>() ?? const {};
  String get folder => _s(r.fields['folder']);
  bool get favorite => r.flag('favorite');
  bool get pinned => r.isPinned;
}

class YumeEvent {
  YumeEvent(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get shipId => r.parentId ?? '';
  String get title => r.title.trim().isEmpty
      ? (yumeEventTypes[type]?.$1 ?? 'Event')
      : r.title.trim();
  String get note => r.body ?? '';
  String get type {
    final t = _s(r.fields['type']);
    return yumeEventTypes.containsKey(t) ? t : 'custom';
  }

  DateTime get date => r.occurredAt ?? r.createdAt;
  String get recurrence {
    final v = _s(r.fields['repeat']);
    return yumeRecurrences.containsKey(v) ? v : 'none';
  }

  bool get onCalendar => r.flag('onCalendar');
  bool get notify => r.flag('notify');
  String get lead {
    final v = _s(r.fields['lead']);
    return yumeAlertLeads.containsKey(v) ? v : 'day';
  }

  bool get countdown => r.flag('countdown');
  String? get calId => r.fields['calId'] as String?;

  /// The next time this happens on or after [from]'s date, or null when a
  /// one-off date has passed.
  DateTime? nextOn(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    final d = DateTime(date.year, date.month, date.day);
    if (!d.isBefore(today)) return d;
    switch (recurrence) {
      case 'yearly':
        var y = today.year;
        DateTime pick(int y) =>
            DateTime(y, d.month, math.min(d.day, _daysIn(y, d.month)));
        var n = pick(y);
        if (n.isBefore(today)) n = pick(++y);
        return n;
      case 'monthly':
        var y = today.year, m = today.month;
        DateTime pick() => DateTime(y, m, math.min(d.day, _daysIn(y, m)));
        var n = pick();
        if (n.isBefore(today)) {
          m++;
          if (m > 12) {
            m = 1;
            y++;
          }
          n = pick();
        }
        return n;
      case 'weekly':
        final diff = today.difference(d).inDays;
        final add = (7 - diff % 7) % 7;
        return today.add(Duration(days: add));
      default:
        return null;
    }
  }
}

int _daysIn(int y, int m) => DateTime(y, m + 1, 0).day;

class YumeMedia {
  YumeMedia(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get shipId => r.parentId ?? '';
  String get type {
    final t = _s(r.fields['type']);
    return yumeMediaTypes.containsKey(t) ? t : 'art';
  }

  String get title => r.title;
  String get caption => r.body ?? '';
  List<String> get media => _strs(r.fields['media']);
  String get artist => _s(r.fields['artist']);
  String get link => _s(r.fields['link']);
  String get credit => _s(r.fields['credit']);
  bool get commissioned => r.flag('commissioned');
  DateTime? get date => r.occurredAt;
}

/// The organiser's own settings (one record for the whole system).
class YumeSettings {
  const YumeSettings(this.r);
  final TrackerRecord? r;
  Map<String, dynamic> get _f => r?.fields ?? const {};

  bool get hasPin => _s(_f['pinHash']).isNotEmpty;
  bool checkPin(String pin) =>
      hasPin && yumeHashPin(pin, _s(_f['pinSalt'])) == _s(_f['pinHash']);

  String get view {
    final v = _s(_f['view']);
    return yumeViews.containsKey(v) ? v : 'gallery';
  }

  String get sort {
    final v = _s(_f['sort']);
    return const {'manual', 'name', 'recent', 'anniversary'}.contains(v)
        ? v
        : 'manual';
  }

  String get defaultVisibility {
    final v = _s(_f['defaultVisibility']);
    return yumeVisibilities.containsKey(v) ? v : 'system';
  }

  bool get calendarDefault => _f['calendarDefault'] != false;
  bool get notifyDefault => _f['notifyDefault'] == true;

  /// Dashboard sections in order with their visibility.
  List<(String, bool)> get dashboard {
    final out = <(String, bool)>[];
    for (final m in _maps(_f['dash'])) {
      final id = _s(m['id']);
      if (yumeDashSections.containsKey(id) && !out.any((e) => e.$1 == id))
        out.add((id, m['visible'] != false));
    }
    for (final id in yumeDashSections.keys) {
      if (!out.any((e) => e.$1 == id)) out.add((id, true));
    }
    return out;
  }

  /// Which alters show a Yumeships section on their profile (opt-in).
  Set<String> get profileMembers => _strs(_f['profile']).toSet();
}

String yumeHashPin(String pin, String salt) =>
    sha256.convert(utf8.encode('prism-yume:$salt:$pin')).toString();

// ── Providers ───────────────────────────────────────────────────────────

List<TrackerRecord> _kind(Ref ref, String kind) =>
    ref.watch(trackerKindProvider(kind)).value ?? const <TrackerRecord>[];

/// The alter whose eyes we're looking through (fronting now), for privacy.
final yumeViewerProvider = Provider<String?>((ref) {
  try {
    final primary = ref.watch(primaryFronterIdProvider);
    if (primary != null) return primary;
  } catch (_) {}
  return ref.watch(currentFronterProvider).value?.id;
});

final yumeAllShipsProvider = Provider<List<YumeShip>>((ref) {
  final list = [for (final r in _kind(ref, TrackerKind.yumeShip)) YumeShip(r)];
  list.sort(
    (a, b) => a.pinned != b.pinned
        ? (a.pinned ? -1 : 1)
        : a.order != b.order
        ? a.order.compareTo(b.order)
        : a.r.createdAt.compareTo(b.r.createdAt),
  );
  return list;
});

/// Ships the current viewer may see (locked ones included, shown locked).
final yumeShipsProvider = Provider<List<YumeShip>>((ref) {
  final viewer = ref.watch(yumeViewerProvider);
  return [
    for (final s in ref.watch(yumeAllShipsProvider))
      if (s.canView(viewer)) s,
  ];
});

final yumeShipByIdProvider = Provider.family<YumeShip?, String>(
  (ref, id) =>
      ref.watch(yumeAllShipsProvider).where((s) => s.id == id).firstOrNull,
);

final yumeAllSonasProvider = Provider<List<YumeSona>>((ref) {
  final list = [for (final r in _kind(ref, TrackerKind.yumeSona)) YumeSona(r)]
    ..sort((a, b) => a.r.sortOrder.compareTo(b.r.sortOrder));
  return list;
});

final yumeSonasProvider = Provider<List<YumeSona>>((ref) {
  final viewer = ref.watch(yumeViewerProvider);
  return [
    for (final s in ref.watch(yumeAllSonasProvider))
      if (s.canView(viewer)) s,
  ];
});

final yumeSonaByIdProvider = Provider.family<YumeSona?, String>(
  (ref, id) =>
      ref.watch(yumeAllSonasProvider).where((s) => s.id == id).firstOrNull,
);

final yumeCollectionsProvider = Provider<List<YumeCollection>>((ref) {
  final viewer = ref.watch(yumeViewerProvider);
  final list = [
    for (final r in _kind(ref, TrackerKind.yumeCollection))
      if (YumeCollection(r).canView(viewer)) YumeCollection(r),
  ];
  list.sort(
    (a, b) =>
        a.pinned != b.pinned ? (a.pinned ? -1 : 1) : a.order.compareTo(b.order),
  );
  return list;
});

final yumeCollectionByIdProvider = Provider.family<YumeCollection?, String>(
  (ref, id) => [
    for (final r in _kind(ref, TrackerKind.yumeCollection)) YumeCollection(r),
  ].where((c) => c.id == id).firstOrNull,
);

/// Ships in a collection: hand-picked ones first in their saved order, then
/// the ones its rule adds.
final yumeCollectionShipsProvider = Provider.family<List<YumeShip>, String>((
  ref,
  id,
) {
  final c = ref.watch(yumeCollectionByIdProvider(id));
  if (c == null) return const [];
  final ships = ref.watch(yumeShipsProvider);
  final byId = {for (final s in ships) s.id: s};
  return [
    for (final sid in c.shipIds) ?byId[sid],
    for (final s in ships)
      if (!c.shipIds.contains(s.id) && c.includes(s)) s,
  ];
});

final yumeCreationsProvider = Provider<List<YumeCreation>>((ref) {
  final viewer = ref.watch(yumeViewerProvider);
  final list = [
    for (final r in _kind(ref, TrackerKind.yumeCreation))
      if (YumeCreation(r).canView(viewer)) YumeCreation(r),
  ];
  list.sort((a, b) => b.r.modifiedAt.compareTo(a.r.modifiedAt));
  return list;
});

final yumeCreationByIdProvider = Provider.family<YumeCreation?, String>(
  (ref, id) => [
    for (final r in _kind(ref, TrackerKind.yumeCreation)) YumeCreation(r),
  ].where((c) => c.id == id).firstOrNull,
);

final yumeEventsProvider = Provider<List<YumeEvent>>(
  (ref) => [for (final r in _kind(ref, TrackerKind.yumeEvent)) YumeEvent(r)],
);

final yumeShipEventsProvider = Provider.family<List<YumeEvent>, String>(
  (ref, shipId) => [
    for (final e in ref.watch(yumeEventsProvider))
      if (e.shipId == shipId) e,
  ]..sort((a, b) => a.date.compareTo(b.date)),
);

final yumeShipMediaProvider = Provider.family<List<YumeMedia>, String>(
  (ref, shipId) => [
    for (final r in _kind(ref, TrackerKind.yumeMedia))
      if (r.parentId == shipId) YumeMedia(r),
  ]..sort((a, b) => b.r.createdAt.compareTo(a.r.createdAt)),
);

final yumeSettingsProvider = Provider<YumeSettings>((ref) {
  final rows = _kind(ref, TrackerKind.yumeSettings);
  return YumeSettings(rows.isEmpty ? null : rows.first);
});

/// An upcoming date on the dashboard.
class YumeUpcoming {
  const YumeUpcoming(this.event, this.ship, this.on);
  final YumeEvent? event;
  final YumeShip ship;
  final DateTime on;
  int daysFrom(DateTime now) =>
      on.difference(DateTime(now.year, now.month, now.day)).inDays;
  String get label => event?.title ?? (yumeEventTypes['anniversary']!.$1);
  String get emoji => yumeEventTypes[event?.type ?? 'anniversary']?.$3 ?? '💞';
}

/// Upcoming anniversaries and events for the ships the viewer can see,
/// soonest first (the next 365 days).
final yumeUpcomingProvider = Provider<List<YumeUpcoming>>((ref) {
  final now = DateTime.now();
  final ships = {for (final s in ref.watch(yumeShipsProvider)) s.id: s};
  final out = <YumeUpcoming>[];
  final covered = <String>{};
  for (final e in ref.watch(yumeEventsProvider)) {
    final s = ships[e.shipId];
    if (s == null || s.archived) continue;
    final n = e.nextOn(now);
    if (n == null || n.difference(now).inDays > 366) continue;
    out.add(YumeUpcoming(e, s, n));
    if (e.type == 'anniversary') covered.add(s.id);
  }
  // A ship's own anniversary date counts even without an event for it.
  for (final s in ships.values) {
    final a = s.anniversary;
    if (a == null || s.archived || covered.contains(s.id)) continue;
    final today = DateTime(now.year, now.month, now.day);
    var n = DateTime(
      now.year,
      a.month,
      math.min(a.day, _daysIn(now.year, a.month)),
    );
    if (n.isBefore(today))
      n = DateTime(
        now.year + 1,
        a.month,
        math.min(a.day, _daysIn(now.year + 1, a.month)),
      );
    out.add(YumeUpcoming(null, s, n));
  }
  out.sort((a, b) => a.on.compareTo(b.on));
  return out;
});

/// Ships connected to an alter (as owner or collaborator).
final yumeShipsForMemberProvider = Provider.family<List<YumeShip>, String>(
  (ref, memberId) => [
    for (final s in ref.watch(yumeShipsProvider))
      if (s.owners.contains(memberId) || s.collaborators.contains(memberId)) s,
  ],
);

/// Items unlocked with the Yumeships PIN during this session.
class YumeUnlocks extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void unlock(String id) => state = {...state, id};
  void unlockAll() => state = {...state, '*'};
  void lockAll() => state = const {};
  bool isOpen(String id) => state.contains('*') || state.contains(id);
}

final yumeUnlocksProvider = NotifierProvider<YumeUnlocks, Set<String>>(
  YumeUnlocks.new,
);

bool yumeIsHidden(WidgetRef ref, bool locked, String id) {
  if (!locked) return false;
  final open = ref.watch(yumeUnlocksProvider);
  return !(open.contains('*') || open.contains(id));
}

// ── Actions ─────────────────────────────────────────────────────────────

class YumeActions {
  YumeActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Map<String, Object?> _base(String? owner) {
    final s = ref.read(yumeSettingsProvider);
    return {
      'v': yumeSchemaVersion,
      'owners': [?owner],
      'visibility': s.defaultVisibility,
    };
  }

  // Ships.
  Future<TrackerRecord> createShip({
    required String name,
    String? owner,
    List<YumeFo> fos = const [],
    String? preset,
    String body = '',
    List<String> tags = const [],
    Map<String, Object?> extra = const {},
  }) {
    final p = yumePresetById(preset);
    final vis =
        '${extra['visibility'] ?? ref.read(yumeSettingsProvider).defaultVisibility}';
    return _t.create(
      kind: TrackerKind.yumeShip,
      title: name,
      body: body,
      tags: tags,
      isPrivate: vis != 'system',
      memberId: owner,
      sortOrder: ref.read(yumeAllShipsProvider).length,
      fields: {
        ..._base(owner),
        'fos': [for (final f in fos) f.toJson()],
        if (p != null) 'theme': p.id,
        ...extra,
      },
    );
  }

  Future<void> saveShip(
    YumeShip s,
    Map<String, Object?> changes, {
    String? title,
    String? body,
    bool? pinned,
    int? order,
    List<String>? tags,
  }) => _save(
    s.r,
    changes,
    title: title,
    body: body,
    pinned: pinned,
    order: order,
    tags: tags,
  );

  /// Saves onto the latest stored copy of [r], so a screen holding an older
  /// copy never overwrites newer changes (another screen, sync, or the
  /// "opened" stamp) with stale values.
  Future<void> _save(
    TrackerRecord r,
    Map<String, Object?> changes, {
    String? title,
    String? body,
    bool? pinned,
    int? order,
    List<String>? tags,
  }) async {
    final latest =
        await ref.read(trackerRecordRepositoryProvider).getById(r.id) ?? r;
    final fields = {...latest.fields, ...changes, 'v': yumeSchemaVersion};
    final vis = '${fields['visibility'] ?? 'system'}';
    await _t.save(
      latest
          .copyWith(
            title: title ?? latest.title,
            body: body ?? latest.body,
            isPinned: pinned ?? latest.isPinned,
            sortOrder: order ?? latest.sortOrder,
            tags: tags ?? latest.tags,
            isPrivate: vis != 'system',
          )
          .replacingFields(fields),
    );
  }

  Future<void> markOpened(YumeShip s) =>
      saveShip(s, {'opened': DateTime.now().toIso8601String()});

  /// Saves a new manual order (drag and drop).
  Future<void> reorderShips(List<YumeShip> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].order != i) await saveShip(ordered[i], const {}, order: i);
    }
  }

  /// Deletes a ship with its media and events (and their calendar entries).
  Future<void> deleteShip(YumeShip s) async {
    for (final e in ref.read(yumeShipEventsProvider(s.id))) {
      await _removeCalendar(e);
    }
    await _t.delete(s.id);
    // Collections and creations keep working without the ship.
    for (final c in ref.read(yumeCollectionsProvider)) {
      if (c.shipIds.contains(s.id))
        await saveCollection(c, {
          'shipIds': [...c.shipIds]..remove(s.id),
        });
    }
  }

  /// Copies a ship to another alter (or makes a twin for the same one).
  /// Gallery entries and events come along; scrapbooks stay linked.
  Future<TrackerRecord> duplicateShip(YumeShip s, {String? toOwner}) async {
    final fields = Map<String, Object?>.of(s.r.fields)
      ..['owners'] = toOwner == null ? s.owners : [toOwner]
      ..['collab'] = const <String>[]
      ..remove('opened');
    final copy = await _t.create(
      kind: TrackerKind.yumeShip,
      title: toOwner == null ? '${s.name} (copy)' : s.r.title,
      body: s.r.body,
      tags: s.r.tags,
      memberId: toOwner ?? s.r.memberId,
      sortOrder: ref.read(yumeAllShipsProvider).length,
      fields: fields,
    );
    for (final m in ref.read(yumeShipMediaProvider(s.id))) {
      await _t.create(
        kind: TrackerKind.yumeMedia,
        parentId: copy.id,
        title: m.r.title,
        body: m.r.body,
        occurredAt: m.r.occurredAt,
        fields: m.r.fields,
      );
    }
    for (final e in ref.read(yumeShipEventsProvider(s.id))) {
      final f = Map<String, Object?>.of(e.r.fields)..remove('calId');
      final made = await _t.create(
        kind: TrackerKind.yumeEvent,
        parentId: copy.id,
        title: e.r.title,
        body: e.r.body,
        occurredAt: e.r.occurredAt,
        fields: f,
      );
      await syncCalendar(YumeEvent(made));
    }
    return copy;
  }

  /// Hands a ship to another alter: they become the owner.
  Future<void> transferShip(YumeShip s, String toOwner) => _t.save(
    s.r.copyWith(memberId: toOwner).withFields({
      'owners': [toOwner],
      'collab': [
        for (final c in s.collaborators)
          if (c != toOwner) c,
      ],
    }),
  );

  // Sonas.
  Future<TrackerRecord> createSona({required String name, String? owner}) =>
      _t.create(
        kind: TrackerKind.yumeSona,
        title: name,
        memberId: owner,
        sortOrder: ref.read(yumeAllSonasProvider).length,
        fields: _base(owner),
      );

  Future<void> saveSona(
    YumeSona s,
    Map<String, Object?> changes, {
    String? title,
    String? body,
    List<String>? tags,
  }) => _save(s.r, changes, title: title, body: body, tags: tags);

  Future<void> deleteSona(YumeSona s) async {
    for (final ship in ref.read(yumeAllShipsProvider)) {
      if (ship.sonaIds.contains(s.id))
        await saveShip(ship, {
          'sonaIds': [...ship.sonaIds]..remove(s.id),
        });
    }
    await _t.delete(s.id);
  }

  /// Links or unlinks a sona and a ship (many-to-many, stored on the ship).
  Future<void> setSonaOnShip(YumeShip ship, String sonaId, bool on) {
    final ids = [...ship.sonaIds]..remove(sonaId);
    if (on) ids.add(sonaId);
    return saveShip(ship, {'sonaIds': ids});
  }

  // Collections.
  Future<TrackerRecord> createCollection({
    required String name,
    required String type,
    String? owner,
    String source = '',
  }) => _t.create(
    kind: TrackerKind.yumeCollection,
    title: name,
    memberId: owner,
    sortOrder: ref.read(yumeCollectionsProvider).length,
    fields: {
      ..._base(owner),
      'visibility': 'system',
      'type': type,
      'source': source,
      'shipIds': const <String>[],
    },
  );

  Future<void> saveCollection(
    YumeCollection c,
    Map<String, Object?> changes, {
    String? title,
    String? body,
    bool? pinned,
    int? order,
  }) => _save(
    c.r,
    changes,
    title: title,
    body: body,
    pinned: pinned,
    order: order,
  );

  Future<void> deleteCollection(YumeCollection c) => _t.delete(c.id);

  Future<void> toggleInCollection(YumeCollection c, String shipId) {
    final ids = [...c.shipIds];
    ids.contains(shipId) ? ids.remove(shipId) : ids.add(shipId);
    return saveCollection(c, {'shipIds': ids});
  }

  Future<void> reorderCollections(List<YumeCollection> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].order != i)
        await saveCollection(ordered[i], const {}, order: i);
    }
  }

  // Creations.
  Future<TrackerRecord> createCreation({
    required String tool,
    String title = '',
    String? owner,
    List<String> shipIds = const [],
    Map<String, Object?> data = const {},
  }) => _t.create(
    kind: TrackerKind.yumeCreation,
    title: title,
    memberId: owner,
    fields: {..._base(owner), 'tool': tool, 'shipIds': shipIds, 'data': data},
  );

  Future<void> saveCreation(
    YumeCreation c,
    Map<String, Object?> changes, {
    String? title,
    bool? pinned,
  }) => _save(c.r, changes, title: title, pinned: pinned);

  Future<TrackerRecord> duplicateCreation(YumeCreation c) => _t.create(
    kind: TrackerKind.yumeCreation,
    title: '${c.title} (copy)',
    memberId: c.r.memberId,
    fields: c.r.fields,
  );

  Future<void> deleteCreation(YumeCreation c) => _t.delete(c.id);

  // Gallery.
  Future<TrackerRecord> addMedia(
    String shipId, {
    required String type,
    List<String> media = const [],
    String title = '',
    String caption = '',
    String artist = '',
    String link = '',
    String credit = '',
    bool commissioned = false,
    DateTime? date,
  }) => _t.create(
    kind: TrackerKind.yumeMedia,
    parentId: shipId,
    title: title,
    body: caption,
    occurredAt: date,
    fields: {
      'v': yumeSchemaVersion,
      'type': type,
      'media': media,
      'artist': artist,
      'link': link,
      'credit': credit,
      'commissioned': commissioned,
    },
  );

  Future<void> saveMedia(
    YumeMedia m,
    Map<String, Object?> changes, {
    String? title,
    String? caption,
    DateTime? date,
  }) => _t.save(
    m.r
        .copyWith(
          title: title ?? m.r.title,
          body: caption ?? m.r.body,
          occurredAt: date ?? m.r.occurredAt,
        )
        .withFields(changes),
  );

  Future<void> deleteMedia(YumeMedia m) => _t.delete(m.id);

  // Events.
  Future<YumeEvent> saveEvent({
    YumeEvent? existing,
    required String shipId,
    required String type,
    required String title,
    required DateTime date,
    String note = '',
    String repeat = 'none',
    required bool onCalendar,
    required bool notify,
    String lead = 'day',
    bool countdown = false,
  }) async {
    final fields = {
      'v': yumeSchemaVersion,
      'type': type,
      'repeat': repeat,
      'onCalendar': onCalendar,
      'notify': notify,
      'lead': lead,
      'countdown': countdown,
    };
    TrackerRecord rec;
    if (existing == null) {
      rec = await _t.create(
        kind: TrackerKind.yumeEvent,
        parentId: shipId,
        title: title,
        body: note,
        occurredAt: DateTime(date.year, date.month, date.day),
        fields: fields,
      );
    } else {
      rec = existing.r
          .copyWith(
            title: title,
            body: note,
            occurredAt: DateTime(date.year, date.month, date.day),
          )
          .withFields(fields);
      await _t.save(rec);
    }
    final e = YumeEvent(rec);
    return syncCalendar(e);
  }

  Future<void> deleteEvent(YumeEvent e) async {
    await _removeCalendar(e);
    await _t.delete(e.id);
  }

  /// Keeps the matching Prism Calendar entry in step with [e]: created,
  /// updated or removed. Notifications ride on the calendar's own alerts,
  /// so quiet hours and the calendar's scheduling rules apply.
  Future<YumeEvent> syncCalendar(YumeEvent e) async {
    final repo = ref.read(calendarRepositoryProvider);
    final ship = ref.read(yumeShipByIdProvider(e.shipId));
    if (!e.onCalendar || ship == null) {
      await _removeCalendar(e);
      if (e.calId == null) return e;
      final cleared = e.r.withFields({'calId': null});
      await _t.save(cleared);
      return YumeEvent(cleared);
    }
    final now = DateTime.now();
    final start = DateTime(e.date.year, e.date.month, e.date.day);
    final alerts = e.notify && ship.notify
        ? [yumeAlertLeads[e.lead]!.$2]
        : const <int>[];
    final accent = ship.accent;
    final ev = CalendarEvent(
      id: e.calId ?? yumeId(),
      title: '${yumeEventTypes[e.type]?.$3 ?? '💞'} ${e.title} · ${ship.name}',
      description: e.note.isEmpty ? null : e.note,
      startAt: start,
      endAt: start.add(const Duration(days: 1)),
      isAllDay: true,
      category: 'Yumeship',
      colorHex: accent == null
          ? null
          : '#${(accent & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      recurrence: switch (e.recurrence) {
        'yearly' => CalendarRecurrence.yearly,
        'monthly' => CalendarRecurrence.monthly,
        'weekly' => CalendarRecurrence.weekly,
        _ => CalendarRecurrence.none,
      },
      alertMinutes: alerts,
      memberIds: ship.owners,
      createdAt: now,
      modifiedAt: now,
    );
    final existing = e.calId == null ? null : await repo.getById(e.calId!);
    if (existing == null) {
      await repo.create(ev);
    } else {
      await repo.update(
        ev.copyWith(
          createdAt: existing.createdAt,
          recurrenceExceptions: existing.recurrenceExceptions,
        ),
      );
    }
    if (e.calId == ev.id) return e;
    final linked = e.r.withFields({'calId': ev.id});
    await _t.save(linked);
    return YumeEvent(linked);
  }

  Future<void> _removeCalendar(YumeEvent e) async {
    final id = e.calId;
    if (id == null) return;
    final repo = ref.read(calendarRepositoryProvider);
    if (await repo.getById(id) != null) await repo.delete(id);
  }

  /// Re-syncs every event of a ship (after its name, colour or notification
  /// preference changes).
  Future<void> resyncShip(String shipId) async {
    for (final e in ref.read(yumeShipEventsProvider(shipId))) {
      await syncCalendar(e);
    }
  }

  // Settings.
  Future<void> saveSettings(Map<String, Object?> changes) async {
    final r = ref.read(yumeSettingsProvider).r;
    if (r == null) {
      await _t.create(
        kind: TrackerKind.yumeSettings,
        fields: {'v': yumeSchemaVersion, ...changes},
      );
    } else {
      await _t.save(r.withFields(changes));
    }
  }

  Future<void> setPin(String? pin) {
    if (pin == null) return saveSettings({'pinHash': null, 'pinSalt': null});
    final salt = yumeId();
    return saveSettings({'pinSalt': salt, 'pinHash': yumeHashPin(pin, salt)});
  }

  Future<void> setProfileSection(String memberId, bool on) {
    final set = {...ref.read(yumeSettingsProvider).profileMembers};
    on ? set.add(memberId) : set.remove(memberId);
    return saveSettings({'profile': set.toList()});
  }
}

final yumeActionsProvider = Provider<YumeActions>(YumeActions.new);
